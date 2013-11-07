/*
 * Copyright (c) 2005 Apple Inc. All rights reserved.
 * Copyright (c) 2005-2006 Paul Guyot <pguyot@kallisys.net>,
 * All rights reserved.
 * Copyright (c) 2006-2013 The MacPorts Project
 *
 * $Id$
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

#ifdef HAVE_LIBKERN_OSATOMIC_H
#include <libkern/OSAtomic.h>
#endif

#include <errno.h>
#include <pthread.h>
#include <string.h>
#include <sys/attr.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/syscall.h>
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

#ifndef HAVE_STRLCPY
/* Define strlcpy if it's not available. */
size_t strlcpy(char *dst, const char *src, size_t size) {
	size_t result = strlen(src);
	if (size > 0) {
		size_t copylen = size - 1;
		if (copylen > result) {
			copylen = result;
		}
		memcpy(dst, src, copylen);
		dst[copylen] = 0;
	}
	return result;
}
#endif

#include "../pextlib1.0/strlcat.c"

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
static void __darwintrace_setup_tls() __attribute__((constructor));
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
 */
static char *filemap;

enum {
    FILEMAP_ALLOW = 0,
    // FILEMAP_REDIR = 1,
    FILEMAP_ASK   = 2
};

/**
 * Setup method called as constructor to set up thread-local storage for the
 * thread id and the darwintrace socket.
 */
static void __darwintrace_setup_tls() {
	if (0 != (errno = pthread_key_create(&tid_key, NULL))) {
		perror("darwintrace: pthread_key_create");
		abort();
	}
	if (0 != (errno = pthread_key_create(&sock_key, NULL))) {
		perror("darwintrace: pthread_key_create");
		abort();
	}
}

/**
 * Convenience getter function for the thread ID
 */
static inline pthread_t __darwintrace_tid() {
	return (pthread_t) pthread_getspecific(tid_key);
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
static void __darwintrace_get_filemap() {
	char *newfilemap;
#if DARWINTRACE_DEBUG && 0
	filemap_iterator_t it;
	char *path, command;
#endif

#if defined(HAVE_OSATOMICCOMPAREANDSWAPPTR)
#	define CAS(old, new, mem) OSAtomicCompareAndSwapPtr(old, new, (void * volatile *) (mem))
#elif defined(__LP64__)
#	ifdef HAVE_OSATOMICCOMPAREANDSWAP64
#		define CAS(old, new, mem) OSAtomicCompareAndSwap64((int64_t) (old), (int64_t) (new), (volatile int64_t *) (mem))
#	else
#		error "No 64-bit compare and swap primitive available on 64-bit OS."
#	endif
#else
#	ifdef HAVE_OSATOMICCOMPAREANDSWAP32
#		define CAS(old, new, mem) OSAtomicCompareAndSwap32((int32_t) (old), (int32_t) (new), (volatile int32_t *) (mem))
#	else
#		error "No 32-bit compare and swap primitive available."
#	endif
#endif

	/*
	 * ensure we have a filemap present; this might be called simultanously
	 * from multiple threads and needs to work without leaking and in a way
	 * that ensures a filemap has been set before any of the calls return. We
	 * achieve that by using non-blocking synchronization. Blocking
	 * synchronization might be a bad idea, because we never know where this
	 * code is actually called in an application.
	 */
	newfilemap = NULL;
	do {
		free(newfilemap);
		if (filemap != NULL)
			break;
		newfilemap = __send("filemap\t", (uint32_t) strlen("filemap\t"), 1);
	} while (!CAS(NULL, newfilemap, &filemap));

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
void __darwintrace_close() {
	FILE *dtsock = __darwintrace_sock();
	if (dtsock) {
		__darwintrace_close_sock = fileno(dtsock);
		fclose(dtsock);
		__darwintrace_close_sock = -1;
		pthread_setspecific(sock_key, NULL);
	}
}

/**
 * Ensures darwintrace is correctly set up by opening a socket connection to
 * the MacPorts-side of trace mode. Will close an re-open this connection when
 * called after \c fork(2), i.e. when the current PID doesn't match the one
 * stored when the function was called last.
 */
void __darwintrace_setup() {
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
 * \param[in] fd a FD to the file, or 0, if none available
 */
static inline void __darwintrace_log_op(const char *op, const char *path) {
	uint32_t size;
	char pathbuf[MAXPATHLEN];
	char logbuffer[BUFFER_SIZE];
	const char *realpath;

	do {
		if (false && strncmp(path, "/.vol/", 6) == 0) {
			// path in VOLFS, try to get inode -> name lookup from
			// getattrlist(2).
			struct attrlist attrlist;
			attrlist.bitmapcount = ATTR_BIT_MAP_COUNT;
			attrlist.reserved = 0;
			attrlist.commonattr = ATTR_CMN_FULLPATH;
			attrlist.volattr = 0;
			attrlist.dirattr = 0;
			attrlist.fileattr = 0;
			attrlist.forkattr = 0;

			char attrbuf[sizeof(uint32_t) + sizeof(attrreference_t) + (PATH_MAX)];
			/*           attrlength         attrref_t for the name     UTF-8 name up to PATH_MAX chars */
			if (-1 == (getattrlist(path, &attrlist, attrbuf, sizeof(attrbuf), FSOPT_NOFOLLOW))) {
				perror("darwintrace: getattrlist");
				// ignore and just print the /.vol/ path
			} else {
				attrreference_t *nameAttrRef = (attrreference_t *) (attrbuf + sizeof(uint32_t));
				strlcpy(pathbuf, ((char *) nameAttrRef) + nameAttrRef->attr_dataoffset, sizeof(pathbuf));
				realpath = pathbuf;
				break;
			}
		}

		if (*path != '/') {
			if (!getcwd(pathbuf, sizeof(pathbuf))) {
				perror("darwintrace: getcwd");
				abort();
			}

			strlcat(pathbuf, "/", sizeof(pathbuf));
			strlcat(pathbuf, path, sizeof(pathbuf));
			realpath = pathbuf;
			break;
		}

		/* otherwise, just copy the original path. */
		realpath = path;
	} while (0);

	size = snprintf(logbuffer, sizeof(logbuffer), "%s\t%s", op, realpath);
	__send(logbuffer, size, 0);
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
#define lstat(y, z) syscall(LSTATSYSNUM, (y), (z))
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
	if (len > sizeof(buffer)) {
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
			break;
	}

	debug_printf("dependency_check: %s returned %d\n", path, result);

	free(p);
	return result;
#undef lstat
}

/**
 * Helper function to recieve a number of bytes from the tracelib communication
 * socket and deal with any errors that might occur.
 *
 * \param[out] buf buffer to hold received data
 * \param[in]  size number of bytes to read from the socket
 */
static void frecv(void *restrict buf, size_t size) {
	FILE *stream = __darwintrace_sock();
	if (1 != fread(buf, size, 1, stream)) {
		if (ferror(stream)) {
			perror("darwintrace: fread");
		} else {
			fprintf(stderr, "darwintrace: fread: end-of-file\n");
		}
		abort();
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
	FILE *stream = __darwintrace_sock();
	if (1 != fwrite(buf, size, 1, stream)) {
		if (ferror(stream)) {
			perror("darwintrace: fwrite");
		} else {
			fprintf(stderr, "darwintrace: fwrite: end-of-file\n");
		}
		abort();
	}
	fflush(stream);
}

/**
 * Communication wrapper targeting tracelib. Automatically enforces the on-wire
 * protocol and supports reading and returning an answer.
 *
 * \param[in] buf buffer to send to tracelib
 * \param[in] size size of the buffer to send
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
#define lstat(x,y) syscall(LSTATSYSNUM, (x), (y))
	filemap_iterator_t filemap_it;

	char command;
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
								__darwintrace_log_op("sandbox_violation", path);
							}
							return true;
						case 0:
							// file belongs to a foreign port, deny access
							if ((flags & DT_REPORT) > 0) {
								__darwintrace_log_op("sandbox_violation", path);
							}
							return false;
					}
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
#undef lstat
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
#define lstat(x, y) syscall(LSTATSYSNUM, (x), (y))
#define readlink(x,y,z) syscall(SYS_readlink, (x), (y), (z))
	if (!filemap) {
		return true;
	}

	char *pathComponents[MAXPATHLEN / 2 + 2];
	size_t componentIdx = 0;

	// Make sure the path is absolute.
	char cwd[MAXPATHLEN];
	if (path == NULL) {
		// this is most certainly invalid, let the syscall deal with it
		return true;
	}
	if (*path != '/') {
		// The path isn't absolute, start by populating pathcomponents with the
		// current working directory
		if (getcwd(cwd, sizeof(cwd)) == NULL) {
			perror("darwintrace: getcwd");
			abort();
		}

		char *lastToken = cwd + 1;
		char *token = NULL;
		while (NULL != (token = strsep(&lastToken, "/"))) {
			pathComponents[componentIdx++] = token;
		}
	}

	// Copy path to a writable buffer
	char lpath[strlen(path) + 1];
	strcpy(lpath, path);

	/* Make sure the path is normalized. NOTE: Do _not_ use realpath(3) here.
	 * Doing so _will_ lead to problems. This is essentially a very simple
	 * re-implementation of realpath(3). */
	char *lastToken = lpath;
	char *token = NULL;
	while (NULL != (token = strsep(&lastToken, "/"))) {
		if (token[0] == '\0') {
			// empty entry, ignore
		} else if (token[0] == '.' && token[1] == '\0') {
			// reference to current directory, ignore
		} else if (token[0] == '.' && token[1] == '.' && token[2] == '\0') {
			// walk up one directory, but not if it's the last one, because /.. -> /
			if (componentIdx > 0) {
				componentIdx--;
			}
		} else {
			// default case: standard path
			pathComponents[componentIdx++] = token;
		}
	}

	char link[MAXPATHLEN];
	char normPath[MAXPATHLEN];
	bool pathIsSymlink;
	size_t loopCount = 0;
	do {
		pathIsSymlink = false;

		if (++loopCount >= 10) {
			// assume cylce and let the OS deal with that (yes, this actually
			// happens in software!)
			break;
		}

		char *normPathPos = normPath;
		*normPathPos = '\0';

		// Build a canonical representation of the path
		for (size_t i = 0; i < componentIdx; ++i) {
			*normPathPos++ = '/';
			normPathPos = stpcpy(normPathPos, pathComponents[i]);
		}
		if (componentIdx == 0) {
			// path is "/"
			*normPathPos++ = '/';
			*normPathPos = '\0';
		}

		// Check whether the last component is a symlink; if it is, check
		// whether it is in the sandbox, expand it and do the same thing again.
		struct stat st;
		if (lstat(normPath, &st) != -1 && S_ISLNK(st.st_mode)) {
			if (!__darwintrace_sandbox_check(normPath, flags)) {
				return false;
			}

			pathIsSymlink = true;

			ssize_t linksize;
			if (-1 == (linksize = readlink(normPath, link, sizeof(link)))) {
				perror("darwintrace: readlink");
				abort();
			}
			link[linksize] = '\0';

			if (*link == '/') {
				// symlink is absolute, start fresh
				componentIdx = 0;
			} else {
				// symlink is relative, remove last component
				if (componentIdx > 0) {
					componentIdx--;
				}
			}

			lastToken = link;
			token = NULL;
			while (NULL != (token = strsep(&lastToken, "/"))) {
				if (token[0] == '\0') {
					// empty entry, ignore
				} else if (token[0] == '.' && token[1] == '\0') {
					// reference to current directory, ignore
				} else if (token[0] == '.' && token[1] == '.' && token[2] == '\0') {
					// walk up one directory, but not if it's the last one, because /.. -> /
					if (componentIdx > 0) {
						componentIdx--;
					}
				} else {
					// default case: standard path
					pathComponents[componentIdx++] = token;
				}
			}
		}
	} while (pathIsSymlink);

	return __darwintrace_sandbox_check(normPath, flags);
#undef readlink
#undef lstat
}
