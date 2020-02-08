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

#include <sys/mman.h>

#define DARWINTRACE_USE_PRIVATE_API 1
#include "darwintrace.h"

#include <assert.h>
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

#include "darwintrace_share/darwintrace_share.h"

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

static void __darwintrace_setup_shared_memory() __attribute__((constructor));
static void __darwintrace_setup_tls() __attribute__((constructor));
static char *__send(const char *buf, uint32_t len, int answer);

/**
 * pthread_key_ts for the pthread_t returned by pthread_self() and the
 * darwintrace socket to ensure the socket is only used from a single thread.
 */
static pthread_key_t tid_key;
// The sock key is needed in close(2) and dup2(2)
pthread_key_t sock_key;

static shm_offt trace_sandbox = SHM_NULL;

/*
 * Flags associates with every path being checked
 */
enum path_flags_t {
	EMPTY                         = 1 << 0,
	DARWINTRACE_ALLOW_PATH        = 1 << 1,
	DARWINTRACE_DENY_PATH         = 1 << 2,
	DARWINTRACE_DO_LOGGING        = 1 << 3,
	DARWINTRACE_SANDBOX_VIOLATION = 1 << 4,
	DARWINTRACE_SANDBOX_UNKNOWN   = 1 << 5
};

/**
 * size of the communication buffer
 */
#define BUFFER_SIZE 4096

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
static void __darwintrace_setup_tls() {
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
 * set_shared_memory() can handle being called between multiple threads,
 * but it makes a call to shm_init() which calls mmap(2) which is not defined async-safe.
 * So it is called as a constructor.
 */
static void __darwintrace_setup_shared_memory() {
	bool retval;

	retval = set_shared_memory(getenv("SHM_FILE"));

	if (retval == false) {
		fprintf(stderr, "darwintrace: set_shared_memory() failed\n");
		abort();
	}
}


/**
 * Convenience setter function for the thread-local darwintrace socket
 */
static inline void __darwintrace_tid_set() {
	if (0 != (errno = pthread_setspecific(tid_key, (const void *) pthread_self()))) {
		perror("darwintrace: pthread_setspecific");
		abort();
	}
}

/**
 * Close the darwintrace socket and set it to \c NULL. Since this uses \c
 * fclose(3), which internally calls \c close(2), which is intercepted by this
 * library and this library prevents closing the socket to MacPorts, we use \c
 * __darwintrace_close_sock to allow closing specific FDs.
 */
void __darwintrace_close() {
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
 * the MacPorts-side of trace mode. Will close an re-open this connection when
 * called after \c fork(2), i.e. when the current PID doesn't match the one
 * stored when the function was called last.
 */
void __darwintrace_socket_setup() {
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

	__darwintrace_socket_setup();

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
 * database to answer this question. tracelib Returns '+', if a dependency was declared,
 * '!', if the file belongs to a port and no dependency was declared and '?' if
 * the file isnt't registered to any port.
 *
 * \param[in] path the path to send to MacPorts for dependency info
 * \return a path_flags_t type after setting appropriate flags
 */
static enum path_flags_t dependency_check(const char *path) {
	char buffer[BUFFER_SIZE], *p;
	uint32_t len;
	enum path_flags_t path_flags;
	struct stat st;

	path_flags = EMPTY;

	if (-1 == lstat(path, &st)) {
		path_flags |= DARWINTRACE_ALLOW_PATH;
		return (path_flags);
	}
	if (S_ISDIR(st.st_mode)) {
		debug_printf("%s is directory\n", path);
		path_flags |= DARWINTRACE_ALLOW_PATH;
		return (path_flags);
	}

	__darwintrace_socket_setup();

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
			path_flags |= DARWINTRACE_ALLOW_PATH;
			break;

		case '?':
			// if the file isn't known to MacPorts, allow
			// access anyway, but report a sandbox violation.
			// TODO find a better solution
			path_flags |= DARWINTRACE_ALLOW_PATH;
			path_flags |= DARWINTRACE_SANDBOX_UNKNOWN;

			break;
		case '!':
			path_flags |= DARWINTRACE_DENY_PATH;
			path_flags |= DARWINTRACE_SANDBOX_VIOLATION;
			break;

		default:
			fprintf(stderr, "darwintrace: unexpected answer from tracelib: '%c' (0x%x)\n", *p, *p);
			abort();
			/*NOTREACHED*/
	}

	debug_printf("dependency_check: %s returned %d\n", path, path_flags);

	free(p);
	return (path_flags);
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
	recv_buf[recv_len] = '\0';
	frecv(recv_buf, recv_len);

	return recv_buf;
}

void __darwintrace_do_logging(const char *path, enum path_flags_t path_flags)
{
	if (path_flags & DARWINTRACE_DO_LOGGING) {

		if (path_flags & DARWINTRACE_SANDBOX_UNKNOWN) {
			__darwintrace_log_op("sandbox_unknown", path);
		}

		if (path_flags & DARWINTRACE_SANDBOX_VIOLATION) {
			__darwintrace_log_op("sandbox_violation", path);
		}
	}
}


enum path_flags_t __darwintrace_ask_server(const char *path)
{
	enum path_flags_t path_flags;

	path_flags = EMPTY;

	/* the actual server calling func */
	path_flags = dependency_check(path);

	return (path_flags);
}

static inline bool __darwintrace_sandbox_check(const char *path, int flags) {

	uint8_t permission;
	enum path_flags_t path_flags;

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

	path_flags = EMPTY;

	if (is_path_in_sandbox(trace_sandbox, path, &permission)) {

		switch (permission) {

			case TRACE_SANDBOX_ALLOW:

				path_flags |= DARWINTRACE_ALLOW_PATH;
				break;

			case TRACE_SANDBOX_ASK_SERVER:

				path_flags |= __darwintrace_ask_server(path);
				break;

			case TRACE_SANDBOX_DENY:

				path_flags |= DARWINTRACE_DENY_PATH;
				path_flags |= DARWINTRACE_SANDBOX_VIOLATION;
				break;

			default:
				fprintf(stderr, "darwintrace: error: invalid permission\n");
				abort();
		}
	} else {
		path_flags |= DARWINTRACE_DENY_PATH;
		path_flags |= DARWINTRACE_SANDBOX_VIOLATION;
	}

	if ((flags & DT_REPORT) > 0) {
		path_flags |= DARWINTRACE_DO_LOGGING;
	}

	__darwintrace_do_logging(path, path_flags);

	if (path_flags & DARWINTRACE_ALLOW_PATH) {
		return (true);
	}

	return (false);
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

	if (trace_sandbox == SHM_NULL) {
		if (__env_tracesandbox_tree_root != NULL) {
			trace_sandbox = ( shm_offt )strtoumax(__env_tracesandbox_tree_root, NULL, 10);
		} else {
			DT_PRINT("__env_tracesandbox_tree_root NULL %s", path);
			return true;
		}
	}

	if (trace_sandbox_is_fence_set(trace_sandbox) == false) {
		DT_PRINT("FENCE NOT SET %s", path);
		return true;
	}

	typedef struct {
		char *start;
		size_t len;
	} path_component_t;

	char normPath[MAXPATHLEN];
	normPath[0] = '/';
	normPath[1] = '\0';

	path_component_t pathComponents[MAXPATHLEN / 2 + 2];
	size_t numComponents = 0;

	// Make sure the path is absolute.
	if (path == NULL || *path == '\0') {
		// this is most certainly invalid, let the syscall deal with it
		return true;
	}

	char *dst = NULL;
	const char *token = NULL;
	size_t idx;
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

		char attrbuf[sizeof(uint32_t) + sizeof(attrreference_t) + (PATH_MAX + 1)];
		/*           attrlength         attrref_t for the name     UTF-8 name up to PATH_MAX chars */

		// FIXME This sometimes violates the stack canary
		if (-1 == (getattrlist(".", &attrlist, attrbuf, sizeof(attrbuf), FSOPT_NOFOLLOW))) {
			perror("darwintrace: getattrlist");
			abort();
		}
		attrreference_t *nameAttrRef = (attrreference_t *) (attrbuf + sizeof(uint32_t));
		strlcpy(normPath, ((char *) nameAttrRef) + nameAttrRef->attr_dataoffset, sizeof(normPath));
#		else /* defined(ATTR_CMN_FULLPATH) */
		if (getcwd(normPath, sizeof(normPath)) == NULL) {
			perror("darwintrace: getcwd");
			abort();
		}
#		endif /* defined(ATTR_CMN_FULLPATH) */

		char *writableToken = normPath + 1;
		while ((idx = strcspn(writableToken, "/")) > 0) {
			// found a token, tokenize and store it
			pathComponents[numComponents].start = writableToken;
			pathComponents[numComponents].len   = idx;
			numComponents++;

			bool final = writableToken[idx] == '\0';
			writableToken[idx] = '\0';
			if (final) {
				break;
			}
			// advance token
			writableToken += idx + 1;
		}

		// copy path after the CWD into the buffer and normalize it
		if (numComponents > 0) {
			path_component_t *lastComponent = pathComponents + (numComponents - 1);
			dst = lastComponent->start + lastComponent->len + 1;
		} else {
			dst = normPath + 1;
		}

		// continue parsing at the begin of path
		token = path;
	} else {
		// skip leading '/'
		dst = normPath + 1;
		*dst = '\0';
		token = path + 1;
	}

	/* Make sure the path is normalized. NOTE: Do _not_ use realpath(3) here.
	 * Doing so _will_ lead to problems. This is essentially a very simple
	 * re-implementation of realpath(3). */
	while ((idx = strcspn(token, "/")) > 0) {
		// found a token, process it

		if (token[0] == '\0' || token[0] == '/') {
			// empty entry, ignore
		} else if (token[0] == '.' && (token[1] == '\0' || token[1] == '/')) {
			// reference to current directory, ignore
		} else if (token[0] == '.' && token[1] == '.' && (token[2] == '\0' || token[2] == '/')) {
			// walk up one directory, but not if it's the last one, because /.. -> /
			if (numComponents > 0) {
				numComponents--;
				if (numComponents > 0) {
					// move dst back to the previous entry
					path_component_t *lastComponent = pathComponents + (numComponents - 1);
					dst = lastComponent->start + lastComponent->len + 1;
				} else {
					// we're at the top, move dst back to the beginning
					dst = normPath + 1;
				}
			}
		} else {
			// copy token to normPath buffer (and null-terminate it)
			strlcpy(dst, token, idx + 1);
			dst[idx] = '\0';
			// add descriptor entry for new token
			pathComponents[numComponents].start = dst;
			pathComponents[numComponents].len   = idx;
			numComponents++;

			// advance destination
			dst += idx + 1;
		}

		if (token[idx] == '\0') {
			break;
		}
		token += idx + 1;
	}

	// strip off resource forks
	if (numComponents >= 2 &&
		strcmp("..namedfork", pathComponents[numComponents - 2].start) == 0 &&
		strcmp("rsrc", pathComponents[numComponents - 1].start) == 0) {
		numComponents -= 2;
	}

#	ifdef ATTR_CMN_FULLPATH
	if (numComponents >= 3 && strncmp(".vol", pathComponents[0].start, pathComponents[0].len) == 0) {
		// path in VOLFS, try to get inode -> name lookup from getattrlist(2).

		// Add the slashes and the terminating \0
		for (size_t i = 0; i < numComponents; ++i) {
			if (i == numComponents - 1) {
				pathComponents[i].start[pathComponents[i].len] = '\0';
			} else {
				pathComponents[i].start[pathComponents[i].len] = '/';
			}
		}

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

		if (-1 == (getattrlist(normPath, &attrlist, attrbuf, sizeof(attrbuf), FSOPT_NOFOLLOW))) {
			perror("darwintrace: getattrlist");
			// ignore and just return the /.vol/ path
		} else {
			attrreference_t *nameAttrRef = (attrreference_t *) (attrbuf + sizeof(uint32_t));
			strlcpy(normPath, ((char *) nameAttrRef) + nameAttrRef->attr_dataoffset, sizeof(normPath));

			numComponents = 0;
			char *writableToken = normPath + 1;
			while ((idx = strcspn(writableToken, "/")) > 0) {
				// found a token, tokenize and store it
				pathComponents[numComponents].start = writableToken;
				pathComponents[numComponents].len   = idx;
				numComponents++;

				bool final = writableToken[idx] == '\0';
				writableToken[idx] = '\0';
				if (final) {
					break;
				}
				// advance token
				writableToken += idx + 1;
			}
		}
	}
#	endif

	bool pathIsSymlink;
	size_t loopCount = 0;
	do {
		pathIsSymlink = false;

		// Add the slashes and the terminating \0
		for (size_t i = 0; i < numComponents; ++i) {
			if (i == numComponents - 1) {
				pathComponents[i].start[pathComponents[i].len] = '\0';
			} else {
				pathComponents[i].start[pathComponents[i].len] = '/';
			}
		}

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
		if (lstat(normPath, &st) != -1 && S_ISLNK(st.st_mode)) {
			if (!__darwintrace_sandbox_check(normPath, flags)) {
				return false;
			}

			char link[MAXPATHLEN];
			pathIsSymlink = true;

			ssize_t linksize;
			if (-1 == (linksize = readlink(normPath, link, sizeof(link)))) {
				perror("darwintrace: readlink");
				abort();
			}
			link[linksize] = '\0';
			//debug_printf("readlink(%s) = %s\n", normPath, link);

			if (*link == '/') {
				// symlink is absolute, start fresh
				numComponents = 0;
				token = link + 1;
				dst = normPath + 1;
			} else {
				// symlink is relative, remove last component
				token = link;
				if (numComponents > 0) {
					numComponents--;
					if (numComponents > 0) {
						// move dst back to the previous entry
						path_component_t *lastComponent = pathComponents + (numComponents - 1);
						dst = lastComponent->start + lastComponent->len + 1;
					} else {
						// we're at the top, move dst back to the beginning
						dst = normPath + 1;
					}
				}
			}

			while ((idx = strcspn(token, "/")) > 0) {
				// found a token, process it

				if (token[0] == '\0' || token[0] == '/') {
					// empty entry, ignore
				} else if (token[0] == '.' && (token[1] == '\0' || token[1] == '/')) {
					// reference to current directory, ignore
				} else if (token[0] == '.' && token[1] == '.' && (token[2] == '\0' || token[2] == '/')) {
					// walk up one directory, but not if it's the last one, because /.. -> /
					if (numComponents > 0) {
						numComponents--;
						if (numComponents > 0) {
							// move dst back to the previous entry
							path_component_t *lastComponent = pathComponents + (numComponents - 1);
							dst = lastComponent->start + lastComponent->len + 1;
						} else {
							// we're at the top, move dst back to the beginning
							dst = normPath + 1;
						}
					}
				} else {
					// copy token to normPath buffer
					strlcpy(dst, token, idx + 1);
					dst[idx] = '\0';
					// add descriptor entry for new token
					pathComponents[numComponents].start = dst;
					pathComponents[numComponents].len   = idx;
					numComponents++;

					// advance destination
					dst += idx + 1;
				}

				if (token[idx] == '\0') {
					break;
				}
				token += idx + 1;
			}
		}
	} while (pathIsSymlink);

	return __darwintrace_sandbox_check(normPath, flags);
}
