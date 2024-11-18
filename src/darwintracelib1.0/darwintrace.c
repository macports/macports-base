/*
 * Copyright (c) 2005 Apple Inc. All rights reserved.
 * Copyright (c) 2005-2006 Paul Guyot <pguyot@kallisys.net>,
 * Copyright (c) 2006-2018 The MacPorts Project
 * All rights reserved.
 *
 * @APPLE_BSD_LICENSE_HEADER_START@
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 * 3.  Neither the name of Apple Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * @APPLE_BSD_LICENSE_HEADER_END@
 */

#define DARWINTRACE_USE_PRIVATE_API 1
#include "darwintrace.h"
#include "sandbox_actions.h"
#include "strlcpy.h"

#ifdef HAVE_STDATOMIC_H
#include <stdatomic.h>
#endif

#ifdef HAVE_LIBKERN_OSATOMIC_H
#include <libkern/OSAtomic.h>
#endif

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <pthread.h>
#include <string.h>
#include <sys/attr.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/un.h>
#include <unistd.h>

#if __DARWIN_64_BIT_INO_T
#define STATSYSNUM SYS_stat64
#define LSTATSYSNUM SYS_lstat64
#else
#define STATSYSNUM SYS_stat
#define LSTATSYSNUM SYS_lstat
#endif

// Global Variables
/**
 * PID of the process darwintrace was last used in. This is used to detect
 * forking and opening a new connection to the control socket in the child
 * process. Not doing so would potentially cause two processes writing to the
 * same socket.
 */
pid_t __darwintrace_pid = (pid_t) - 1;

/**
 * Helper variable containing the number of the darwintrace socket, iff the
 * close(2) syscall should be allowed to close it. Used by \c
 * __darwintrace_close.
 */
volatile int __darwintrace_close_sock = -1;

/**
 * Debug socket. Will be initialized by a constructor function.
 */
FILE *__darwintrace_stderr = NULL;

static inline void __darwintrace_log_op(const char *op, const char *path);
static char *__send(const char *buf, uint32_t len, int answer);

/**
 * pthread_key_ts for the pthread_t returned by pthread_self() and the
 * darwintrace socket to ensure the socket is only used from a single thread.
 */
static pthread_key_t tid_key;
// The sock key is needed in close(2) and dup2(2)
pthread_key_t sock_key;

/**
 * size of the communication buffer
 */
#define BUFFER_SIZE 4096

/**
 * Variable holding the sandbox bounds in the following format:
 *  <filemap>       :: (<spec> '\0')+ '\0'
 *  <spec>          :: <path> '\0' <operation> <additional_data>?
 *  <operation>     :: '0' | '1' | '2'
 * where
 *  0: allow
 *  1: map the path to the one given in additional_data (currently unsupported)
 *  2: check for a dependency using the socket
 *  3: deny access to the path and stop processing
 */
#ifdef HAVE_STDATOMIC_H
static _Atomic(char *) filemap;
#else
static char *filemap;
#endif


volatile bool __darwintrace_initialized = false;

/**
 * "Constructors" we'd like to run before we do anything. As using
 * __attribute__((constructor)) for these would be unsafe here (as our
 * interposed functions might end up being called first) we'll run them manually
 * before we interpose anything.
 */
static void (*constructors[])(void) = {
	__darwintrace_setup_tls,
	__darwintrace_store_env,
};

void __darwintrace_run_constructors(void) {
	for (size_t i = 0; i < sizeof(constructors) / sizeof(*constructors); ++i) {
		constructors[i]();
	}
	__darwintrace_initialized = true;
}

static void __darwintrace_sock_destructor(FILE *dtsock) {
	__darwintrace_close_sock = fileno(dtsock);
	fclose(dtsock);
	__darwintrace_close_sock = -1;
	__darwintrace_sock_set(NULL);
}

/**
 * Setup method called as constructor to set up thread-local storage for the
 * thread id and the darwintrace socket.
 */
void __darwintrace_setup_tls(void) {
	if (0 != (errno = pthread_key_create(&tid_key, NULL))) {
		perror("darwintrace: pthread_key_create");
		abort();
	}
	if (0 != (errno = pthread_key_create(&sock_key, (void (*)(void *)) __darwintrace_sock_destructor))) {
		perror("darwintrace: pthread_key_create");
		abort();
	}
}

/**
 * Convenience getter function for the thread ID
 */
/*
static inline pthread_t __darwintrace_tid() {
	return (pthread_t) pthread_getspecific(tid_key);
}
*/

/**
 * Convenience setter function for the thread-local darwintrace socket
 */
static inline void __darwintrace_tid_set(void) {
	if (0 != (errno = pthread_setspecific(tid_key, (const void *) pthread_self()))) {
		perror("darwintrace: pthread_setspecific");
		abort();
	}
}

/**
 * Return false if str doesn't begin with prefix, true otherwise. Note that
 * this is not a simple string comparison, but works on a path component level.
 * A prefix of /var/tmp will not match a string of /var/tmpfoo.
 */
static inline bool __darwintrace_pathbeginswith(const char *str, const char *prefix) {
	char s;
	char p;

	/* '/' is the allow all wildcard */
	if (prefix[0] == '\0' || (prefix[0] == '/' && prefix[1] == '\0')) {
		return 1;
	}

	do {
		s = *str++;
		p = *prefix++;
	} while (p && (p == s));
	return (p == '\0' && (s == '/' || s == '\0'));
}

/*
 * Data structures and functions to iterate over the filemap received from
 * tracelib code.
 */

/**
 * \c filemap_iterator_t is an (opaque) iterator type that keeps the state
 * required to iterate through the filemap. Create a new filemap_iterator_t on
 * stack, initialize it using \c __darwintrace_filemap_iterator_init and pass
 * it to \c __darwintrace_filemap_iter to iterate over the filemap.
 */
typedef struct filemap_iterator {
	char *next;
} filemap_iterator_t;

/**
 * Initialize a given \c filemap_iterator_t. Calling this function again will
 * rewind the iterator.
 *
 * \param[in] it pointer to the iterator to be initialized
 */
static inline void __darwintrace_filemap_iterator_init(filemap_iterator_t *it) {
	it->next = filemap;
}

/**
 * Iterate through the filemap passed from tracelib code. Call this multiple
 * times with the same iterator object until it returns \c NULL to iterate
 * through the filemap.
 *
 * \param[out] command location for the command specified for this filemap
 *                     entry
 * \param[in]  it pointer to a \c filemap_iterator_t keeping the state of this
 *                iteration
 * \return string containing the path this filemap entry corresponds to, or \c
 *         NULL if the end of the filemap was reached
 */
static inline char *__darwintrace_filemap_iter(char *command, filemap_iterator_t *it) {
	enum { PATH, COMMAND, DONE } state = PATH;
	char *t;
	char *path;

	if (it == NULL || it->next == NULL || *it->next == '\0') {
		return NULL;
	}

	path = t = it->next;

	/* advance the cursor: if the number after the string is not 1, there's no
	 * path behind it and we can advance by strlen(t) + 3. If it is 1, make
	 * sure to skip the path, too.
	 */
	state = PATH;
	while (state != DONE) {
		switch (state) {
			case DONE:
				/* unreachable */
				break;
			case PATH:
				if (*t == '\0') {
					state = COMMAND;
				}
				break;
			case COMMAND:
				*command = *t;
				if (*t == 1) {
					fprintf(stderr, "darwintrace: unsupported state REPLACEPATH in dfa in " __FILE__ ":%d\n", __LINE__);
					abort();
				}
				state = DONE;
				/* the byte after the status code is '\0', if the status code
				 * isn't 1 (which is no longer supported) */
				t++;
				break;
		}
		t++;
	}

	it->next = t;
	return path;
}

/**
 * Request sandbox boundaries from tracelib (the MacPorts base-controlled side
 * of the trace setup) and store it.
 */
static void __darwintrace_get_filemap(void) {
	char *newfilemap;
#if DARWINTRACE_DEBUG && 0
	filemap_iterator_t it;
	char *path, command;
#endif

#if HAVE_DECL_ATOMIC_COMPARE_EXCHANGE_STRONG_EXPLICIT   /* HAVE_DECL_* is always defined and set to 1 or 0 */
#	define CAS(old, new, mem) atomic_compare_exchange_strong_explicit(mem, old, new, memory_order_relaxed, memory_order_relaxed)
#elif defined(HAVE_OSATOMICCOMPAREANDSWAPPTR)
#	define CAS(old, new, mem) OSAtomicCompareAndSwapPtr(*old, new, (void * volatile *) (mem))
#elif defined(__LP64__)
#	ifdef HAVE_OSATOMICCOMPAREANDSWAP64
#		define CAS(old, new, mem) OSAtomicCompareAndSwap64((int64_t) (*old), (int64_t) (new), (volatile int64_t *) (mem))
#	else
#		error "No 64-bit compare and swap primitive available on 64-bit OS."
#	endif
#else
#	ifdef HAVE_OSATOMICCOMPAREANDSWAP32
#		define CAS(old, new, mem) OSAtomicCompareAndSwap32((int32_t) (*old), (int32_t) (new), (volatile int32_t *) (mem))
#	else
#		error "No 32-bit compare and swap primitive available."
#	endif
#endif

	/*
	 * ensure we have a filemap present; this might be called simultaneously
	 * from multiple threads and needs to work without leaking and in a way
	 * that ensures a filemap has been set before any of the calls return. We
	 * achieve that by using non-blocking synchronization. Blocking
	 * synchronization might be a bad idea, because we never know where this
	 * code is actually called in an application.
	 */
	newfilemap = NULL;
	char *nullpointer = NULL;
	do {
		free(newfilemap);
		if (filemap != NULL)
			break;
		newfilemap = __send("filemap\t", 8, 1);
	} while (!CAS(&nullpointer, newfilemap, &filemap));

#if DARWINTRACE_DEBUG && 0
	for (__darwintrace_filemap_iterator_init(&it);
	        (path = __darwintrace_filemap_iter(&command, &it));) {
		debug_printf("filemap: {cmd=%d, path=%s}\n", command, path);
	}
#endif
}

/**
 * Close the darwintrace socket and set it to \c NULL. Since this uses \c
 * fclose(3), which internally calls \c close(2), which is intercepted by this
 * library and this library prevents closing the socket to MacPorts, we use \c
 * __darwintrace_close_sock to allow closing specific FDs.
 */
void __darwintrace_close(void) {
	FILE *dtsock = __darwintrace_sock();
	if (dtsock) {
		__darwintrace_close_sock = fileno(dtsock);
		fclose(dtsock);
		__darwintrace_close_sock = -1;
		__darwintrace_sock_set(NULL);
	}
}

/**
 * Ensures darwintrace is correctly set up by opening a socket connection to
 * the MacPorts-side of trace mode. Will close and re-open this connection when
 * called after \c fork(2), i.e. when the current PID doesn't match the one
 * stored when the function was called last.
 */
void __darwintrace_setup(void) {
	/*
	 * Check whether this is a child process and we've inherited the socket. We
	 * want to avoid race conditions with our parent process when communicating
	 * with tracelib and thus re-open all sockets, if that's the case. Note
	 * this also applies to threads within the same process, since we really
	 * want to avoid mixing up the results from two calls in different threads
	 * when reading from the socket.
	 */

	/*
	 * if the PID changed, close the current socket (which will force the
	 * following code to re-open it).
	 */
	if (__darwintrace_pid != (pid_t) -1 && __darwintrace_pid != getpid()) {
		__darwintrace_close();
		__darwintrace_pid = (pid_t) -1;
	}

	/*
	 * We don't need to watch for TID changes, because each thread has thread
	 * local storage for the socket that will contain NULL when the socket has
	 * not been initialized.
	 */

	if (__darwintrace_sock() == NULL) {
		int sock;
		int sockflags;
		FILE *stream;
		struct sockaddr_un sun;

		__darwintrace_pid = getpid();
		__darwintrace_tid_set();
		if (__env_darwintrace_log == NULL) {
			fprintf(stderr, "darwintrace: trace library loaded, but DARWINTRACE_LOG not set\n");
			abort();
		}

		if (-1 == (sock = socket(PF_LOCAL, SOCK_STREAM, 0))) {
			perror("darwintrace: socket");
			abort();
		}

		/* Set the close-on-exec flag as early as possible after the socket
		 * creation. On macOS, there is no way to do this race-condition free
		 * unless you synchronize around creation and fork(2) -- however,
		 * blocking in this function is not acceptable for darwintrace, because
		 * it could possibly run in a signal handler, leading to a deadlock.
		 *
		 * The close-on-exec flag is needed because we're using a thread-local
		 * variable to hold a reference to this socket, but multi-threaded
		 * programs that fork will only clone the thread that calls fork(2),
		 * which leaves us with no reference to the other sockets (which are
		 * inherited, because FDs are process-wide). Consequently, this can
		 * lead to a resource leak.
		 */
		if (-1 == (sockflags = fcntl(sock, F_GETFD))) {
			perror("darwintrace: fcntl(F_GETFD)");
			abort();
		}
		sockflags |= FD_CLOEXEC;
		if (-1 == fcntl(sock, F_SETFD, sockflags)) {
			perror("darwintrace: fcntl(F_SETFD, flags | FD_CLOEXEC)");
			abort();
		}

		if (strlen(__env_darwintrace_log) > sizeof(sun.sun_path) - 1) {
			fprintf(stderr, "darwintrace: Can't connect to socket %s: name too long\n", __env_darwintrace_log);
			abort();
		}
		sun.sun_family = AF_UNIX;
		strlcpy(sun.sun_path, __env_darwintrace_log, sizeof(sun.sun_path));

		if (-1 == (connect(sock, (struct sockaddr *) &sun, sizeof(sun)))) {
			perror("darwintrace: connect");
			abort();
		}

		if (NULL == (stream = fdopen(sock, "a+"))) {
			perror("darwintrace: fdopen");
			abort();
		}

		/* store FILE * into thread local storage for the socket */
		__darwintrace_sock_set(stream);

		/* request sandbox bounds */
		__darwintrace_get_filemap();
	}
}

/**
 * Send a path to tracelib either given a path, or an FD (where
 * fcntl(F_GETPATH) will be used).
 *
 * \param[in] op the operation (sent as-is to tracelib, should be interpreted
 *               as command)
 * \param[in] path the (not necessarily absolute) path to send to tracelib
 */
static inline void __darwintrace_log_op(const char *op, const char *path) {
	uint32_t size;
	char logbuffer[BUFFER_SIZE];

	size = snprintf(logbuffer, sizeof(logbuffer), "%s\t%s", op, path);
	// Check if the buffer was short. If it was, discard the message silently,
	// assuming it isn't important enough to error out.
	if (size < BUFFER_SIZE) {
		__send(logbuffer, size, 0);
	}
}

/**
 * Check whether the port currently being installed declares a dependency on
 * a given file. Communicates with MacPorts tracelib, which uses the registry
 * database to answer this question. Returns 1, if a dependency was declared,
 * 0, if the file belongs to a port and no dependency was declared and -1 if
 * the file isnt't registered to any port.
 *
 * \param[in] path the path to send to MacPorts for dependency info
 * \return 1, if access should be granted, 0, if access should be denied, and
 *         -1 if MacPorts doesn't know about the file.
 */
static int dependency_check(const char *path) {
	char buffer[BUFFER_SIZE], *p;
	uint32_t len;
	int result = 0;
	struct stat st;

	if (-1 == lstat(path, &st)) {
		return 1;
	}
	if (S_ISDIR(st.st_mode)) {
		debug_printf("%s is directory\n", path);
		return 1;
	}

	len = snprintf(buffer, sizeof(buffer), "dep_check\t%s", path);
	if (len >= sizeof(buffer)) {
		fprintf(stderr, "darwintrace: truncating buffer length from %" PRIu32 " to %zu.", len, sizeof(buffer) - 1);
		len = sizeof(buffer) - 1;
	}
	p = __send(buffer, len, 1);
	if (!p) {
		fprintf(stderr, "darwintrace: dependency check failed for %s\n", path);
		abort();
	}

	switch (*p) {
		case '+':
			result = 1;
			break;
		case '!':
			result = 0;
			break;
		case '?':
			result = -1;
			break;
		default:
			fprintf(stderr, "darwintrace: unexpected answer from tracelib: '%c' (0x%x)\n", *p, *p);
			abort();
			/*NOTREACHED*/
	}

	debug_printf("dependency_check: %s returned %d\n", path, result);

	free(p);
	return result;
}

/**
 * Helper function to receive a number of bytes from the tracelib communication
 * socket and deal with any errors that might occur.
 *
 * \param[out] buf buffer to hold received data
 * \param[in]  size number of bytes to read from the socket
 */
static void frecv(void *restrict buf, size_t size) {
	/* We cannot safely use fread(3) here, because we're not in control of the
	 * application's signal handling settings (which means we must assume
	 * SA_RESTART isn't set) and fread(3) may return short without giving us
	 * a way to know how many bytes have actually been read, i.e. without a way
	 * to do the call again. Because of this great API design and
	 * implementation on macOS, we'll just use read(2) here. */
	int fd = fileno(__darwintrace_sock());
	size_t count = 0;
	while (count < size) {
		ssize_t res = read(fd, buf + count, size - count);
		if (res < 0) {
			if (errno == EINTR) {
				continue;
			}
			perror("darwintrace: read");
			abort();
		}

		if (res == 0) {
			fprintf(stderr, "darwintrace: read: end-of-file\n");
			abort();
		}

		count += res;
	}
}

/**
 * Helper function to send a buffer to MacPorts using the tracelib
 * communication socket and deal with any errors that might occur.
 *
 * \param[in] buf buffer to send
 * \param[in] size number of bytes in the buffer
 */
static void fsend(const void *restrict buf, size_t size) {
	/* We cannot safely use fwrite(3) here, because we're not in control of the
	 * application's signal handling settings (which means we must assume
	 * SA_RESTART isn't set) and fwrite(3) may return short without giving us
	 * a way to know how many bytes have actually been written, i.e. without
	 * a way to do the call again. Because of this great API design and
	 * implementation on macOS, we'll just use write(2) here. */
	int fd = fileno(__darwintrace_sock());
	size_t count = 0;
	while (count < size) {
		ssize_t res = write(fd, buf + count, size - count);
		if (res < 0) {
			if (errno == EINTR) {
				continue;
			}
			perror("darwintrace: write");
			abort();
		}

		count += res;
	}
}

/**
 * Communication wrapper targeting tracelib. Automatically enforces the on-wire
 * protocol and supports reading and returning an answer.
 *
 * \param[in] buf buffer to send to tracelib
 * \param[in] len size of the buffer to send
 * \param[in] answer boolean indicating whether an answer is expected and
 *                   should be returned
 * \return allocated answer buffer. Callers should free this buffer. If an
 *         answer was not requested, \c NULL.
 */
static char *__send(const char *buf, uint32_t len, int answer) {
	fsend(&len, sizeof(len));
	fsend(buf, len);

	if (!answer) {
		return NULL;
	}

	uint32_t recv_len = 0;
	char *recv_buf;

	frecv(&recv_len, sizeof(recv_len));
	if (recv_len == 0) {
		return 0;
	}

	recv_buf = malloc(recv_len + 1);
	if (recv_buf == NULL) {
		return NULL;
	}
	recv_buf[recv_len] = '\0';
	frecv(recv_buf, recv_len);

	return recv_buf;
}

/**
 * Check a fully normalized path against the current sandbox. Helper function
 * for __darwintrace_is_in_sandbox; do not use directly.
 *
 * \param[in] path the path to be checked; must be absolute and normalized.
 * \param[in] flags A binary or combination of the following flags:
 *                  - DT_REPORT: If access to this path is being denied, report
 *                    it as sandbox violation. Set this for all operations that
 *                    read file contents or check file attributes. Omit this
 *                    flag for operations that might only attempt to access
 *                    a file by chance, such as readdir(3).
 *                  - DT_ALLOWDIR: Whether to always allow access if the given
 *                    path references an existing directory. Set this for
 *                    read operations such as stat(2), omit this for operations
 *                    that modify directories like rmdir(2) and mkdir(2).
 * \return \c true if the file is within sandbox bounds, \c false if access
 *         should be denied
 */
static inline bool __darwintrace_sandbox_check(const char *path, int flags) {
	filemap_iterator_t filemap_it;

	char command = -1;
	char *t;

	if (path[0] == '/' && path[1] == '\0') {
		// Always allow access to /. Strange things start to happen if you deny this.
		return true;
	}

	if ((flags & DT_ALLOWDIR) > 0) {
		struct stat st;
		if (-1 != lstat(path, &st) && S_ISDIR(st.st_mode)) {
			return true;
		}
	}

	// Iterate over the sandbox bounds and try to find a directive matching this path
	for (__darwintrace_filemap_iterator_init(&filemap_it);
	        (t = __darwintrace_filemap_iter(&command, &filemap_it));) {
		if (__darwintrace_pathbeginswith(path, t)) {
			switch (command) {
				case FILEMAP_ALLOW:
					return true;
				case FILEMAP_ASK:
					// ask the socket whether this file is OK
					switch (dependency_check(path)) {
						case 1:
							return true;
						case -1:
							// if the file isn't known to MacPorts, allow
							// access anyway, but report a sandbox violation.
							// TODO find a better solution
							if ((flags & DT_REPORT) > 0) {
								__darwintrace_log_op("sandbox_unknown", path);
							}
							return true;
						case 0:
							// file belongs to a foreign port, deny access
							if ((flags & DT_REPORT) > 0) {
								__darwintrace_log_op("sandbox_violation", path);
							}
							return false;
					}
				case FILEMAP_DENY:
					if ((flags & DT_REPORT) > 0) {
						__darwintrace_log_op("sandbox_violation", path);
					}
					return false;
				default:
					fprintf(stderr, "darwintrace: error: unexpected byte in file map: `%x'\n", *t);
					abort();
			}
		}
	}

	if ((flags & DT_REPORT) > 0) {
		__darwintrace_log_op("sandbox_violation", path);
	}
	return false;
}


/**
 * Structure to represent a filesystem path component, i.e., a single level of a path.
 */
typedef struct {
	char *path;
	size_t len;
} path_component_t;

/**
 * Structure to represent a normalized filesystem path.
 */
typedef struct {
	size_t num;
	size_t capacity;
	path_component_t *components;
} path_t;

#define PATH_INITIAL_CAPACITY (PATH_MAX / 4 + 2)

/**
 * Allocate a new filesystem path structure.
 *
 * @return Pointer to the new path_t on success, NULL on error.
 */
static path_t *path_new(void) {
	path_t *path = NULL;

	path = malloc(sizeof(path_t));
	if (!path) {
		goto out;
	}

	path->num = 0;
	path->capacity = PATH_INITIAL_CAPACITY;
	path->components = malloc(sizeof(path_component_t) * path->capacity);

	if (!path->components) {
		free(path);
		path = NULL;
	}

out:
	return path;
}

/**
 * Free a filesystem path structure.
 *
 * @param[in] path The path to release.
 */
static void path_free(path_t *path) {
	for (size_t idx = 0; idx < path->num; ++idx) {
		free(path->components[idx].path);
	}

	free(path->components);
	free(path);
}

/**
 * Append a component (given as string) to an existing filesystem path while
 * preserving normality.
 *
 * If the given component is empty, or ".", the path will remain unmodified. If
 * the given component is "..", the last component of the path is deleted.
 * Otherwise, the new component is appended to the end of the path. Note that
 * component must NOT contain slashes.
 *
 * @param[in] path The path to which the component should be appended.
 * @param[in] component The path component to append.
 * @return true on success, false when memory allocation fails.
 */
static bool path_append(path_t *path, const char *component) {
	if (*component == '\0') {
		// ignore empty path components, i.e., consecutive slashes
		return true;
	} else if (component[0] == '.' && component[1] == '\0') {
		// ignore self-referencing path components
		return true;
	} else if (component[0] == '.' && component[1] == '.' && component[2] == '\0') {
		// walk up one path component, if possible
		if (path->num > 0) {
			free(path->components[path->num - 1].path);
			path->num--;
		}
	} else {
		if (path->num >= path->capacity) {
			// need more space for components, realloc to make that space
			size_t new_capacity = path->capacity + (PATH_INITIAL_CAPACITY / 2);
			path_component_t *new_components = realloc(path->components, sizeof(path_component_t) * new_capacity);
			if (!new_components) {
				return false;
			}

			path->capacity = new_capacity;
			path->components = new_components;
		}

		// initialize new path_component_t
		size_t len = strlen(component);
		path_component_t *new_component = &path->components[path->num];
		new_component->len = len;
		new_component->path = malloc(len + 1);
		if (!new_component->path) {
			return false;
		}
		strlcpy(new_component->path, component, len + 1);
		path->num++;
	}

	return true;
}

/**
 * Take the given input path as string, tokenize it into separate path
 * components, then append them to the given path, normalizing the path in the
 * process. Modifies the given inpath string.
 *
 * @param[in] path The path to which the new components should be appended.
 * @param[in] inpath The string input path which will be tokenized and normalized.
 * @return true on success, false on memory allocation failure.
 */
static bool path_tokenize(path_t *path, char *inpath) {
	char *pos = inpath;
	const char *token;

	while ((token = strsep(&pos, "/")) != NULL) {
		if (!path_append(path, token)) {
			return false;
		}
	}

	return true;
}

/**
 * The the given symbolic link as string, tokenize it into separate path
 * components and normalize it in the context of the given path. If the
 * symbolic link is absolute, this will replace the entire path, otherwise
 * normalize the symlink relative to the current path. Modifies the given link.
 *
 * @param[in] path The path relative to which the symlink should be interpreted.
 * @param[in] link The symbolic link contents obtained from readlink(2).
 * @return true on success, false on memory allocation failure.
 */
static bool path_tokenize_symlink(path_t *path, char *link) {
	if (*link == '/') {
		// symlink is absolute, start fresh
		for (size_t idx = 0; idx < path->num; idx++) {
			free(path->components[idx].path);
		}
		path->num = 0;

		return path_tokenize(path, link + 1);
	}

	// symlink is relative, remove last component
	if (path->num > 0) {
		free(path->components[path->num - 1].path);
		path->num--;
	}

	return path_tokenize(path, link);
}

/**
 * Strip a resource fork from the end of the path, if present.
 *
 * @param[in] path The path which should be checked for resource forks
 */
static void path_strip_resource_fork(path_t *path) {
	if (path->num >= 2) {
		if (   strcmp(path->components[path->num - 2].path, "..namedfork") == 0
			&& strcmp(path->components[path->num - 1].path, "rsrc") == 0) {
			free(path->components[path->num - 2].path);
			free(path->components[path->num - 1].path);
			path->num -= 2;
		}
	}
}

/**
 * Return the length of the given path when represented as a native filesystem
 * path with "/" separators, excluding the terminating \0 byte.
 *
 * @param[in] path The path whose length should be determined.
 * @return The length of the path.
 */
static size_t path_len(const path_t *path) {
	// One slash for each component
	size_t len = path->num;

	// Plus the length for each component
	for (size_t idx = 0; idx < path->num; ++idx) {
		len += path->components[idx].len;
	}

	return len;
}

/**
 * Convert the given path into a string. The returned pointer is allocated and
 * must be released with free(3).
 *
 * @param[in] path The path to convert to a string.
 * @return An allocated string representation of the path on success, NULL on error.
 */
static char *path_str(const path_t *path) {
	size_t len = path_len(path);

	char *out = malloc(len + 1);
	if (!out) {
		return NULL;
	}

	out[0] = '/';
	out[1] = '\0';
	char *pos = out;
	for (size_t idx = 0; idx < path->num; idx++) {
		*pos = '/';
		pos++;

		path_component_t *component = &path->components[idx];
		strlcpy(pos, component->path, component->len + 1);
		pos += component->len;
	}

	return out;
}

/**
 * Check whether the given path is a volfs path (i.e., /.vol/$fsnum/$inode),
 * and return a non-volfs path if possible.
 *
 * If the return value is not the argument, the argument was correctly freed.
 * Always use this function as
 *
 *   path = path_resolve_volfs(path);
 *
 * for this reason.
 *
 * @param[in] path The path to check for volfs paths
 * @return The orginal path if no modification was required or expansion
 *         failed. A fresh path if the path was a volfs path and was expanded.
 */
static path_t *path_resolve_volfs(path_t *path) {
#ifdef ATTR_CMN_FULLPATH
	if (path->num >= 3 && strcmp(path->components[0].path, ".vol") == 0) {
		struct attrlist attrlist;
		attrlist.bitmapcount = ATTR_BIT_MAP_COUNT;
		attrlist.reserved = 0;
		attrlist.commonattr = ATTR_CMN_FULLPATH;
		attrlist.volattr = 0;
		attrlist.dirattr = 0;
		attrlist.fileattr = 0;
		attrlist.forkattr = 0;

		char attrbuf[sizeof(uint32_t) + sizeof(attrreference_t) + (PATH_MAX + 1)];
		/*           attrlength         attrref_t for the name     UTF-8 name up to PATH_MAX chars */

		char *path_native = path_str(path);
		if (!path_native) {
			goto out;
		}

		if (-1 == (getattrlist(path_native, &attrlist, attrbuf, sizeof(attrbuf), FSOPT_NOFOLLOW))) {
			perror("darwintrace: getattrlist");
			// ignore and just return the /.vol/ path
		} else {
			path_t *newpath = path_new();
			if (!newpath) {
				goto out;
			}

			attrreference_t *nameAttrRef = (attrreference_t *) (attrbuf + sizeof(uint32_t));
			if (!path_tokenize(newpath, ((char *) nameAttrRef) + nameAttrRef->attr_dataoffset)) {
				path_free(newpath);
				goto out;
			}

			path_free(path);
			path = newpath;
		}

out:
		free(path_native);
	}
#endif /* defined(ATTR_CMN_FULLPATH) */

	return path;
}


/**
 * Check a path against the current sandbox
 *
 * \param[in] path the path to be checked; not necessarily absolute
 * \param[in] flags A binary or combination of the following flags:
 *                  - DT_REPORT: If access to this path is being denied, report
 *                    it as sandbox violation. Set this for all operations that
 *                    read file contents or check file attributes. Omit this
 *                    flag for operations that might only attempt to access
 *                    a file by chance, such as readdir(3).
 *                  - DT_ALLOWDIR: Whether to always allow access if the given
 *                    path references an existing directory. Set this for
 *                    read operations such as stat(2), omit this for operations
 *                    that modify directories like rmdir(2) and mkdir(2).
 * \return \c true if the file is within sandbox bounds, \c false if access
 *         should be denied
 */
bool __darwintrace_is_in_sandbox(const char *path, int flags) {
	if (!filemap) {
		return true;
	}

	if (path == NULL || *path == '\0') {
		// this is most certainly invalid, let the syscall deal with it
		return true;
	}

	path_t *normPath = path_new();
	if (!normPath) {
		perror("darwintrace: path_new");
		abort();
	}

	size_t offset = 0;

	if (*path != '/') {
		/*
		 * The path isn't absolute, start by populating pathcomponents with the
		 * current working directory.
		 *
		 * However, we avoid getcwd(3) if we can and use getattrlist(2) with
		 * ATTR_CMN_FULLPATH instead, because getcwd(3) will open all parent
		 * directories, read them, search for the current component using its
		 * inode obtained from lstat(., .., ../.., etc.) and build the path
		 * this way, which is inefficient and will also call back into
		 * darwintrace code.
		 */
#		ifdef ATTR_CMN_FULLPATH
		struct attrlist attrlist;
		attrlist.bitmapcount = ATTR_BIT_MAP_COUNT;
		attrlist.reserved = 0;
		attrlist.commonattr = ATTR_CMN_FULLPATH;
		attrlist.volattr = 0;
		attrlist.dirattr = 0;
		attrlist.fileattr = 0;
		attrlist.forkattr = 0;

		size_t attrbufSize = sizeof(uint32_t) + sizeof(attrreference_t) + (PATH_MAX + 1);
		/*                   attrlength         attrref_t for the name     UTF-8 name up to PATH_MAX chars */
		char *attrbuf = malloc(attrbufSize);
		if (attrbuf == NULL) {
			perror("darwintrace: malloc");
			abort();
		}

		// FIXME This sometimes violates the stack canary
		if (-1 == (getattrlist(".", &attrlist, attrbuf, attrbufSize, FSOPT_NOFOLLOW))) {
			perror("darwintrace: getattrlist");
			abort();
		}
		attrreference_t *nameAttrRef = (attrreference_t *) (attrbuf + sizeof(uint32_t));
		if (!path_tokenize(normPath, ((char *) nameAttrRef) + nameAttrRef->attr_dataoffset)) {
			perror("darwintrace: path_tokenize");
			abort();
		}
#		else /* defined(ATTR_CMN_FULLPATH) */
		char *cwd = getcwd(NULL, 0);
		if (cwd == NULL) {
			perror("darwintrace: getcwd");
			abort();
		}
		if (!path_tokenize(normPath, cwd)) {
			perror("darwintrace: path_tokenize");
			abort();
		}
		free(cwd);
#		endif /* defined(ATTR_CMN_FULLPATH) */
	} else {
		// skip leading '/'
		offset = 1;
	}

	char *pathcopy = strdup(path + offset);
	if (!pathcopy) {
		perror("darwintrace: strdup");
		abort();
	}
	if (!path_tokenize(normPath, pathcopy)) {
		perror("darwintrace: path_tokenize");
		abort();
	}
	free(pathcopy);

	// Handle resource forks (we ignore them)
	path_strip_resource_fork(normPath);

	// Handle /.vol/$devid/$inode volfs paths
	normPath = path_resolve_volfs(normPath);

	bool pathIsSymlink;
	size_t loopCount = 0;
	char *path_native = path_str(normPath);
	if (!path_native) {
		perror("darwintrace: path_str");
		abort();
	}
	do {
		pathIsSymlink = false;

		if ((flags & DT_FOLLOWSYMS) == 0) {
			// only expand symlinks when the DT_FOLLOWSYMS flags is set;
			// otherwise just ignore whether this path is a symlink or not to
			// speed up readdir(3).
			break;
		}

		if (++loopCount >= 10) {
			// assume cylce and let the OS deal with that (yes, this actually
			// happens in software!)
			break;
		}

		// Check whether the last component is a symlink; if it is, check
		// whether it is in the sandbox, expand it and do the same thing again.
		struct stat st;
		//debug_printf("checking for symlink: %s\n", normPath);
		if (lstat(path_native, &st) != -1 && S_ISLNK(st.st_mode)) {
			if (!__darwintrace_sandbox_check(path_native, flags)) {
				free(path_native);
				return false;
			}

			size_t maxLinkLength = MAXPATHLEN / 2;
			char *link = malloc(maxLinkLength);
			if (link == NULL) {
				free(path_native);
				perror("darwintrace: malloc");
				abort();
			}
			pathIsSymlink = true;

			while (true) {
				ssize_t linksize;
				if (-1 == (linksize = readlink(path_native, link, maxLinkLength - 1))) {
					/* If we can't read the link, don't error out, but jsut continue as if the path
					 * wasn't a link. The build will later on have to deal with the same error and
					 * will likely either gracefully handle it, or return a useful error message. */
					free(link);
					link = strdup(path_native);
					if (!link) {
						perror("darwintrace: strdup");
						abort();
					}

					pathIsSymlink = false;
					break;
				}
				link[linksize] = '\0';
				if ((size_t) linksize < maxLinkLength - 1) {
					// The link did fit the buffer
					break;
				}

				maxLinkLength += MAXPATHLEN;
				char *newlink = realloc(link, maxLinkLength);
				if (!newlink) {
					free(path_native);
					free(link);
					perror("darwintrace: realloc");
					abort();
				}
				link = newlink;
			}

			if (!path_tokenize_symlink(normPath, link)) {
				perror("darwintrace: path_tokenize_symlink");
				abort();
			}

			free(link);
			free(path_native);
			path_native = path_str(normPath);
			if (!path_native) {
				perror("darwintrace: path_str");
				abort();
			}
		}
	} while (pathIsSymlink);

	bool result = __darwintrace_sandbox_check(path_native, flags);
	free(path_native);
	path_free(normPath);
	return result;
}
