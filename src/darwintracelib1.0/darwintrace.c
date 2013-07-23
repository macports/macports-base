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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#if HAVE_SYS_CDEFS_H
#include <sys/cdefs.h>
#endif

#include <stdint.h>

#if defined(_DARWIN_FEATURE_64_BIT_INODE) && !defined(_DARWIN_FEATURE_ONLY_64_BIT_INODE)
/* The architecture we're building for has multiple versions of stat.
   We need to undo sys/cdefs.h changes for _DARWIN_FEATURE_64_BIT_INODE */
#undef  __DARWIN_64_BIT_INO_T
#define __DARWIN_64_BIT_INO_T 0
#undef  __DARWIN_SUF_64_BIT_INO_T
#define __DARWIN_SUF_64_BIT_INO_T ""
#undef _DARWIN_FEATURE_64_BIT_INODE
#endif

#ifdef HAVE_CRT_EXTERNS_H
#include <crt_externs.h>
#endif

#ifdef HAVE_SYS_PATHS_H
#include <sys/paths.h>
#endif

#include <dirent.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/un.h>
#include <unistd.h>

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

/* global variables (only checked when setup is first called)
 * DARWINTRACE_LOG
 *    path to the log file (no logging happens if it's unset).
 * DARWINTRACE_SANDBOX_BOUNDS
 *    : separated allowed paths for the creation of files.
 *    \: -> :
 *    \\ -> \
 */

/*
 * DARWINTRACE_DEBUG: verbose output of operations to debug darwintrace
 */
#ifndef DARWINTRACE_DEBUG
#define DARWINTRACE_DEBUG (0)
#endif

static inline int __darwintrace_strbeginswith(const char *str, const char *prefix);
static inline int __darwintrace_pathbeginswith(const char *str, const char *prefix);
static inline void __darwintrace_log_op(const char *op, const char *path, int fd);
static void __darwintrace_copy_env() __attribute__((constructor));
static void __darwintrace_setup_tls() __attribute__((constructor));
static inline char *__darwintrace_alloc_env(const char *varName, const char *varValue);
static inline char *const *__darwintrace_restore_env(char *const envp[]);
static inline void __darwintrace_setup();
static inline void __darwintrace_cleanup_path(char *path);
static char *__send(const char *buf, uint32_t len, int answer);

/**
 * PID of the process darwintrace was last used in. This is used to detect
 * forking and opening a new connection to the control socket in the child
 * process. Not doing so would potentially cause two processes writing to the
 * same socket.
 */
static pid_t __darwintrace_pid = (pid_t) - 1;

/**
 * pthread_key_ts for the pthread_t returned by pthread_self() and the
 * darwintrace socket to ensure the socket is only used from a single thread.
 */
static pthread_key_t tid_key;
static pthread_key_t sock_key;

/**
 * Helper variable containing the number of the darwintrace socket, iff the
 * close(2) syscall should be allowed to close it. Used by \c
 * __darwintrace_close.
 */
static volatile int __darwintrace_close_sock = -1;

/**
 * size of the communication buffer
 */
#define BUFFER_SIZE 1024

/**
 * Variable holding the sandbox bounds in the following format:
 *  <filemap>       :: (<spec> '\0')+ '\0'
 *  <spec>          :: <path> '\0' <operation> <additional_data>?
 *  <operation>     :: '0' | '1' | '2'
 * where
 *  0: allow
 *  1: map the path to the one given in additional_data
 *  2: check for a dependency using the socket
 */
static char *filemap;

enum {
    FILEMAP_ALLOW = 0,
    FILEMAP_REDIR = 1,
    FILEMAP_ASK   = 2
};

/**
 * Copy of the DYLD_INSERT_LIBRARIES environment variable to restore it in
 * execve(2). DYLD_INSERT_LIBRARIES is needed to preload this library into any
 * process' address space.
 */
static char *__env_dyld_insert_libraries;

/**
 * Copy of the DYLD_FORCE_FLAT_NAMESPACE environment variable to restore it in
 * execve(2). DYLD_FORCE_FLAT_NAMESPACE=1 is needed for the preload-based
 * sandbox to work.
 */
static char *__env_dyld_force_flat_namespace;

/**
 * Copy of the DARWINTRACE_LOG environment variable to restore it in execve(2).
 * Contains the path to the unix socket used for communication with the
 * MacPorts-side of the sandbox.
 */
static char *__env_darwintrace_log;

#if DARWINTRACE_DEBUG
#   if __STDC_VERSION__>=199901L
#       define debug_printf(format, ...) \
	fprintf(stderr, "darwintrace[%d]: " format, getpid(), __VA_ARGS__);
#   else
__attribute__((format(printf, 1, 2))) static inline void debug_printf(const char *format, ...) {
	va_list args;
	va_start(args, format);
	vfprintf(stderr, format, args);
	va_end(args);
}
#   endif
#else
#   define debug_printf(...)
#endif

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
 * Convenience getter function for the thread-local darwintrace socket
 */
static inline FILE *__darwintrace_sock() {
	return (FILE *) pthread_getspecific(sock_key);
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
static inline void __darwintrace_sock_set(FILE *stream) {
	if (0 != (errno = pthread_setspecific(sock_key, stream))) {
		perror("darwintrace: pthread_setspecific");
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
 * Return 0 if str doesn't begin with prefix, 1 otherwise. Note that this is
 * not a simple string comparison, but works on a path component level.
 * A prefix of /var/tmp will not match a string of /var/tmpfoo.
 */
static inline int __darwintrace_pathbeginswith(const char *str, const char *prefix) {
	char s;
	char p;

	/* '/' is the allow all wildcard */
	if (strcmp(prefix, "/") == 0) {
		return 1;
	}

	do {
		s = *str++;
		p = *prefix++;
	} while (p && (p == s));
	return (p == 0 && (s == '/' || s == '\0'));
}

/**
 * Return 0 if str doesn't begin with prefix, 1 otherwise.
 */
static inline int __darwintrace_strbeginswith(const char *str, const char *prefix) {
	char s;
	char p;
	do {
		s = *str++;
		p = *prefix++;
	} while (p && (p == s));
	return (p == 0);
}

/*
 * Copy the environment variables, if they're defined. This is run as
 * a constructor at startup.
 */
static void __darwintrace_copy_env() {
#define COPYENV(name, variable) \
	if (NULL != (val = getenv(#name))) {\
		if (NULL == (variable = strdup(val))) {\
			perror("darwintrace: strdup");\
			abort();\
		}\
	} else {\
		variable = NULL;\
	}

	char *val;
	COPYENV(DYLD_INSERT_LIBRARIES,     __env_dyld_insert_libraries)
	COPYENV(DYLD_FORCE_FLAT_NAMESPACE, __env_dyld_force_flat_namespace)
	COPYENV(DARWINTRACE_LOG,           __env_darwintrace_log)
#undef COPYENV
}

/**
 * Allocate a X=Y string where X is the variable name and Y its value.
 * Return the new string.
 *
 * If the value is NULL, return NULL.
 */
static inline char *__darwintrace_alloc_env(const char *name, const char *val) {
	char *result = NULL;

	if (val) {
		size_t size = strlen(name) + strlen(val) + 2;
		if (NULL == (result = malloc(size))) {
			perror("darwintrace: malloc");
			abort();
		}
		snprintf(result, size, "%s=%s", name, val);
		if (size > 0) {
			result[size - 1] = '\0';
		}
	}

	return result;
}

/**
 * This function checks that envp contains the global variables we had when the
 * library was loaded and modifies it if it doesn't.
 */
static inline char *const *__darwintrace_restore_env(char *const envp[]) {
	/* allocate the strings. */
	/* we don't care about the leak here because we're going to call execve,
	 * which, if it succeeds, will get rid of our heap */
	char *dyld_insert_libraries_ptr     = __darwintrace_alloc_env("DYLD_INSERT_LIBRARIES",     __env_dyld_insert_libraries);
	char *dyld_force_flat_namespace_ptr = __darwintrace_alloc_env("DYLD_FORCE_FLAT_NAMESPACE", __env_dyld_force_flat_namespace);
	char *darwintrace_log_ptr           = __darwintrace_alloc_env("DARWINTRACE_LOG",           __env_darwintrace_log);

	char *const *enviter = envp;
	size_t envlen = 0;
	char **copy;
	char **copyiter;

	while (*enviter != NULL) {
		envlen++;
		enviter++;
	}

	/* 4 is sufficient for the three variables we copy and the terminator */
	copy = malloc(sizeof(char *) * (envlen + 5));

	enviter  = envp;
	copyiter = copy;

	while (*enviter != NULL) {
		char *val = *enviter;
		if (__darwintrace_strbeginswith(val, "DYLD_INSERT_LIBRARIES=")) {
			val = dyld_insert_libraries_ptr;
			dyld_insert_libraries_ptr = NULL;
		} else if (__darwintrace_strbeginswith(val, "DYLD_FORCE_FLAT_NAMESPACE=")) {
			val = dyld_force_flat_namespace_ptr;
			dyld_force_flat_namespace_ptr = NULL;
		} else if (__darwintrace_strbeginswith(val, "DARWINTRACE_LOG=")) {
			val = darwintrace_log_ptr;
			darwintrace_log_ptr = NULL;
		}

		if (val) {
			*copyiter++ = val;
		}

		enviter++;
	}

	if (dyld_insert_libraries_ptr) {
		*copyiter++ = dyld_insert_libraries_ptr;
	}
	if (dyld_force_flat_namespace_ptr) {
		*copyiter++ = dyld_force_flat_namespace_ptr;
	}
	if (darwintrace_log_ptr) {
		*copyiter++ = darwintrace_log_ptr;
	}

	*copyiter = 0;

	return copy;
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
 * \param[out] replacement location for a replacement path, if any. This field
 *                         is only valid if the command field indicates
 *                         a replacement path is being used.
 * \param[in]  it pointer to a \c filemap_iterator_t keeping the state of this
 *                iteration
 * \return string containing the path this filemap entry corresponds to, or \c
 *         NULL if the end of the filemap was reached
 */
static inline char *__darwintrace_filemap_iter(char *command, char **replacement, filemap_iterator_t *it) {
	enum { PATH, COMMAND, REPLACEPATH, DONE } state = PATH;
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
				fprintf(stderr, "darwintrace: illegal state in dfa in " __FILE__ ":%d\n", __LINE__);
				abort();
				break;
			case PATH:
				if (!*t) {
					state = COMMAND;
				}
				break;
			case COMMAND:
				*command = *t;
				if (*t == 1) {
					state = REPLACEPATH;
					*replacement = t + 1;
				} else {
					state = DONE;
					/* the byte after the status code is 0, if the status
					 * code isn't 1 */
					t++;
				}
				break;
			case REPLACEPATH:
				if (!*t) {
					state = DONE;
				}
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
	char *path, *replacement, command;
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
	} while (!__sync_bool_compare_and_swap(&filemap, NULL, newfilemap));

#if DARWINTRACE_DEBUG && 0
	for (__darwintrace_filemap_iterator_init(&it);
	        (path = __darwintrace_filemap_iter(&command, &replacement, &it));) {
		debug_printf("filemap: {cmd=%d, path=%-120s, replacement=%s}\n", command, path, (command == 1) ? replacement : "-");
	}
#endif
}

/**
 * Close the darwintrace socket and set it to \c NULL. Since this uses \c
 * fclose(3), which internally calls \c close(2), which is intercepted by this
 * library and this library prevents closing the socket to MacPorts, we use \c
 * __darwintrace_close_sock to allow closing specific FDs.
 */
static inline void __darwintrace_close() {
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
static inline void __darwintrace_setup() {
	/**
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
 * Send a path to tracelib either form a given path, or from an FD.
 *
 * \param[in] op the operation (sent as-is to tracelib, should be interpreted
 *               as command)
 * \param[in] path the (not necessarily absolute) path to send to tracelib
 * \param[in] fd a FD to the file, or 0, if none available
 */
static inline void __darwintrace_log_op(const char *op, const char *path, int fd) {
	uint32_t size;
	char somepath[MAXPATHLEN];
	char logbuffer[BUFFER_SIZE];

	do {
#       ifdef __APPLE__ /* Only Darwin has volfs and F_GETPATH */
		if ((fd > 0) && (strncmp(path, "/.vol/", 6) == 0)) {
			if (fcntl(fd, F_GETPATH, somepath) != -1) {
				break;
			}
		}
#       endif

		if (*path != '/') {
			if (!getcwd(somepath, sizeof(somepath))) {
				perror("darwintrace: getcwd");
				abort();
			}

			strlcat(somepath, "/", sizeof(somepath));
			strlcat(somepath, path, sizeof(somepath));
			break;
		}

		/* otherwise, just copy the original path. */
		strlcpy(somepath, path, sizeof(somepath));
	} while (0);

	/* clean the path. */
	__darwintrace_cleanup_path(somepath);

	size = snprintf(logbuffer, sizeof(logbuffer), "%s\t%s", op, somepath);
	__send(logbuffer, size, 0);
}

/**
 * remap resource fork access to the data fork.
 * do a partial realpath(3) to fix "foo//bar" to "foo/bar"
 */
static inline void __darwintrace_cleanup_path(char *path) {
	size_t pathlen;
#   ifdef __APPLE__
	size_t rsrclen;
#   endif
	char *dst, *src;
	enum { SAWSLASH, NOTHING } state = NOTHING;

	/* if this is a foo/..namedfork/rsrc, strip it off */
	pathlen = strlen(path);
	/* ..namedfork/rsrc is only on OS X */
#   ifdef __APPLE__
	rsrclen = strlen(_PATH_RSRCFORKSPEC);
	if (pathlen > rsrclen && 0 == strcmp(path + pathlen - rsrclen, _PATH_RSRCFORKSPEC)) {
		path[pathlen - rsrclen] = '\0';
		pathlen -= rsrclen;
	}
#   endif

	/* for each position in string, check if we're in a run of multiple
	 * slashes, and only emit the first one */
	for (src = path, dst = path; *src; src++) {
		if (state == SAWSLASH) {
			if (*src == '/') {
				/* consume it */
				continue;
			}
			state = NOTHING;
		} else {
			if (*src == '/') {
				state = SAWSLASH;
			}
		}
		if (dst != src) {
			// if dst == src, avoid the copy operation
			*dst = *src;
		}
		dst++;
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
static int dependency_check(char *path) {
#define stat(y, z) syscall(SYS_stat, (y), (z))
	char buffer[BUFFER_SIZE], *p;
	uint32_t len;
	int result = 0;
	struct stat st;

	if (-1 == stat(path, &st)) {
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
#undef stat
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
 * Check a path against the current sandbox
 *
 * \param[in] path the path to be checked; not necessarily absolute
 * \param[out] newpath buffer for a replacement path when redirection should
 *                     occur. Initialize the first byte with 0 before calling
 *                     this function. The buffer should be at least MAXPATHLEN
 *                     bytes large. If newpath[0] isn't 0 after the call,
 *                     redirection should occur and the path from newpath
 *                     should be used for the syscall instead.
 * \return 1, if the file is within sandbox bounds, 0, if access should be denied
 */
static inline int __darwintrace_is_in_sandbox(const char *path, char *newpath) {
	char *t, *_;
	char *strpos, *normpos;
	char lpath[MAXPATHLEN];
	char normalizedpath[MAXPATHLEN];
	filemap_iterator_t filemap_it;
	char command;
	char *replacementpath;

	__darwintrace_setup();

	if (!filemap) {
		return 1;
	}

	if (*path == '/') {
		strcpy(lpath, path);
	} else {
		if (getcwd(lpath, MAXPATHLEN - 1) == NULL) {
			perror("darwintrace: getcwd");
			abort();
		}
		strlcat(lpath, "/", MAXPATHLEN);
		strlcat(lpath, path, MAXPATHLEN);
	}

	normalizedpath[0] = '\0';
	strpos = lpath + 1;
	normpos = normalizedpath;
	for (;;) {
		char *curpos = strsep(&strpos, "/");
		if (curpos == NULL) {
			/* reached the end of the path */
			break;
		} else if (*curpos == '\0') {
			/* empty entry, ignore */
			continue;
		} else if (strcmp(curpos, ".") == 0) {
			/* no-op directory, ignore */
			continue;
		} else if (strcmp(curpos, "..") == 0) {
			/* walk up one directory */
			char *lastSep = strrchr(normalizedpath, '/');
			if (lastSep == NULL) {
				/* path is completely empty */
				normpos = normalizedpath;
				*normpos = '\0';
				continue;
			}
			/* remove last component by overwriting the slash with \0, update normpos */
			*lastSep = '\0';
			normpos = lastSep;
			continue;
		}
		/* default case: standard path, copy */
		strcat(normpos, "/");
		normpos++;
		strcat(normpos, curpos);
	}
	if (*normalizedpath == '\0') {
		strcat(normalizedpath, "/");
	}

	for (__darwintrace_filemap_iterator_init(&filemap_it);
	        (t = __darwintrace_filemap_iter(&command, &replacementpath, &filemap_it));) {
		if (__darwintrace_pathbeginswith(normalizedpath, t)) {
			/* move t to the integer describing how to handle this match */
			t += strlen(t) + 1;
			switch (*t) {
				case FILEMAP_ALLOW:
					return 1;
				case FILEMAP_REDIR:
					if (!newpath) {
						return 0;
					}
					/* the redirected path starts right after the byte telling
					 * us we should redirect */
					strcpy(newpath, t + 1);
					_ = newpath + strlen(newpath);
					/* append '/' if it's missing */
					if (_[-1] != '/') {
						*_++ = '/';
					}
					strcpy(_, normalizedpath);
					return 1;
				case FILEMAP_ASK:
					/* ask the socket whether this file is OK */
					switch (dependency_check(normalizedpath)) {
						case 1:
						case -1:
							/* if the file isn't known to MacPorts, allow
							 * access anyway. TODO find a better solution */
							return 1;
						case 0:
							/* file belongs to a foreign port, deny access */
							return 0;
					}
				default:
					fprintf(stderr, "darwintrace: error: unexpected byte in file map: `%x'\n", *t);
					abort();
			}
		}
	}

	__darwintrace_log_op("sandbox_violation", normalizedpath, 0);
	return 0;
}

/* wrapper for open(2) preventing opening files outside the sandbox */
int open(const char *path, int flags, ...) {
#define open(x,y,z) syscall(SYS_open, (x), (y), (z))
	mode_t mode;
	va_list args;
	char newpath[MAXPATHLEN];

	debug_printf("open(%s)\n", path);

	*newpath = '\0';
	if (!__darwintrace_is_in_sandbox(path, newpath)) {
		debug_printf("open %s was forbidden\n", path);
		errno = ((flags & O_CREAT) > 0) ? EACCES : ENOENT;
		return -1;
	}

	if (*newpath) {
		path = newpath;
	}

	/* Why mode here ? */
	va_start(args, flags);
	mode = va_arg(args, int);
	va_end(args);

	return open(path, flags, mode);
#undef open
}

/* Log calls to readlink(2) into the file specified by DARWINTRACE_LOG.
   Only logs if the DARWINTRACE_LOG environment variable is set.
   Only logs files where the readlink succeeds.
*/
#ifdef READLINK_IS_NOT_P1003_1A
int readlink(const char *path, char *buf, int bufsiz) {
#else
ssize_t readlink(const char *path, char *buf, size_t bufsiz) {
#endif
#define readlink(x,y,z) syscall(SYS_readlink, (x), (y), (z))
	char newpath[MAXPATHLEN];

	debug_printf("readlink(%s)\n", path);

	*newpath = '\0';
	if (!__darwintrace_is_in_sandbox(path, newpath)) {
		errno = ENOENT;
		return -1;
	}

	if (*newpath) {
		path = newpath;
	}

	return readlink(path, buf, bufsiz);
#undef readlink
}

int execve(const char *path, char *const argv[], char *const envp[]) {
#define __execve(x,y,z) syscall(SYS_execve, (x), (y), (z))
#define open(x,y,z) syscall(SYS_open, (x), (y), (z))
#define close(x) syscall(SYS_close, (x))
#define lstat(x, y) syscall(SYS_lstat, (x), (y))
	debug_printf("execve(%s)\n", path);
	__darwintrace_setup();
	struct stat sb;
	/* for symlinks, we want to capture both the original path and the
	 * modified one, since for /usr/bin/gcc -> gcc-4.0, both "gcc_select"
	 * and "gcc" are contributors
	 */
	if (lstat(path, &sb) == 0) {
		if (!__darwintrace_is_in_sandbox(path, NULL)) {
			errno = ENOENT;
			return -1;
		}

#if		0
		int fd = open(path, O_RDONLY, 0);
		if (fd > 0) {
			char buffer[MAXPATHLEN + 1];
			ssize_t bytes_read;

			/* read the file for the interpreter */
			bytes_read = read(fd, buffer, MAXPATHLEN);
			buffer[bytes_read] = 0;
			if (bytes_read > 2 && buffer[0] == '#' && buffer[1] == '!') {
				const char *interp = &buffer[2];
				int i;
				/* skip past leading whitespace */
				for (i = 2; i < bytes_read; ++i) {
					if (buffer[i] != ' ' && buffer[i] != '\t') {
						interp = &buffer[i];
						break;
					}
				}
				/* found interpreter (or ran out of data); skip until next
				 * whitespace, then terminate the string */
				for (; i < bytes_read; ++i) {
					if (buffer[i] == ' ' || buffer[i] == '\t' || buffer[i] == '\n') {
						buffer[i] = 0;
						break;
					}
				}
			}

			/* TODO check the iterpreter against the sandbox */
			close(fd);
		}
#endif
	}

	/* our variables won't survive exec, clean up */
	__darwintrace_close();
	__darwintrace_pid = (pid_t) - 1;

	/* call the original execve function, but fix the environment if required. */
	return __execve(path, argv, __darwintrace_restore_env(envp));
#undef lstat
#undef close
#undef open
#undef execve
}

/* if darwintrace has been initialized, trap attempts to close our file
 * descriptor */
int close(int fd) {
#define close(x) syscall(SYS_close, (x))
	FILE *stream = __darwintrace_sock();
	if (stream) {
		int dtsock = fileno(stream);
		if (fd == dtsock && dtsock != __darwintrace_close_sock) {
			errno = EBADF;
			return -1;
		}
	}

	return close(fd);
#undef close
}

/* if darwintrace has been initialized, trap attempts to dup2 over our file descriptor */
int dup2(int filedes, int filedes2) {
#define dup2(x, y) syscall(SYS_dup2, (x), (y))
	FILE *stream = __darwintrace_sock();

	debug_printf("dup2(%d, %d)\n", filedes, filedes2);
	if (stream && filedes2 == fileno(stream)) {
		/* if somebody tries to close our file descriptor, just move it out of
		 * the way. Make sure it doesn't end up as stdin/stdout/stderr, though!
		 * */
		int new_darwintrace_fd;
		FILE *new_stream;

		if (-1 == (new_darwintrace_fd = fcntl(fileno(stream), F_DUPFD, STDOUT_FILENO + 1))) {
			/* if duplicating fails, do not allow overwriting either! */
			return -1;
		}

		debug_printf("moving __darwintrace FD from %d to %d\n", fileno(stream), new_darwintrace_fd);
		__darwintrace_close();
		if (NULL == (new_stream = fdopen(new_darwintrace_fd, "a+"))) {
			perror("darwintrace: fdopen");
			abort();
		}
		__darwintrace_sock_set(new_stream);
	}

	return dup2(filedes, filedes2);
#undef dup2
}

/* Trap attempts to unlink a file outside the sandbox. */
int unlink(const char *path) {
#define __unlink(x) syscall(SYS_unlink, (x))
	char newpath[MAXPATHLEN];

	*newpath = '\0';
	if (!__darwintrace_is_in_sandbox(path, newpath)) {
		debug_printf("unlink %s was forbidden\n", path);
		errno = ENOENT;
		return -1;
	}

	if (*newpath) {
		path = newpath;
	}

	debug_printf("unlink %s was allowed\n", path);

	return __unlink(path);
}

/* Trap attempts to create directories outside the sandbox.
 */
int mkdir(const char *path, mode_t mode) {
#define __mkdir(x,y) syscall(SYS_mkdir, (x), (y))
	char newpath[MAXPATHLEN];

	*newpath = '\0';
	if (!__darwintrace_is_in_sandbox(path, newpath)) {
		struct stat st;
		if (-1 == lstat(path, &st)) {
			if (errno == ENOENT) {
				/* directory doesn't exist yet */
				debug_printf("mkdir was forbidden at %s\n", path);
				errno = EACCES;
				return -1;
			}
		}
		/* otherwise, mkdir will do nothing or fail with a hopefully meaningful
		 * error */
	} else {
		if (*newpath) {
			path = newpath;
		}

		debug_printf("mkdir was allowed at %s\n", path);
	}

	return __mkdir(path, mode);
}

/* Trap attempts to remove directories outside the sandbox.
 */
int rmdir(const char *path) {
#define __rmdir(x) syscall(SYS_rmdir, (x))
	if (!__darwintrace_is_in_sandbox(path, NULL)) {
		debug_printf("removing directory %s was forbidden\n", path);
		errno = ENOENT;
		return -1;
	}

	debug_printf("rmdir %s was allowed\n", path);

	return __rmdir(path);
}

/* Trap attempts to rename files/directories outside the sandbox.
 */
int rename(const char *from, const char *to) {
#define __rename(x,y) syscall(SYS_rename, (x), (y))
	if (!__darwintrace_is_in_sandbox(from, NULL)) {
		/* outside sandbox, forbid */
		debug_printf("renaming from %s was forbidden\n", from);
		errno = ENOENT;
		return -1;
	}
	if (!__darwintrace_is_in_sandbox(to, NULL)) {
		debug_printf("renaming to %s was forbidden\n", to);
		errno = EACCES;
		return -1;
	}

	debug_printf("renaming from %s to %s was allowed\n", from, to);

	return __rename(from, to);
}

int stat(const char *path, struct stat *sb) {
#define stat(path, sb) syscall(SYS_stat, path, sb)
	int result = 0;
	char newpath[MAXPATHLEN];

	debug_printf("stat(%s)\n", path);
	if (-1 == (result = stat(path, sb))) {
		return -1;
	}

	if (S_ISDIR(sb->st_mode)) {
		return result;
	}

	*newpath = '\0';
	if (!__darwintrace_is_in_sandbox(path, newpath)) {
		errno = ENOENT;
		return -1;
	}

	if (*newpath) {
		result = stat(newpath, sb);
	}

	return result;
#undef stat
}

#if defined(__DARWIN_64_BIT_INO_T) && !defined(_DARWIN_FEATURE_ONLY_64_BIT_INODE)

int stat64(const char *path, struct stat64 *sb) {
#define stat64(path, sb) syscall(SYS_stat64, path, sb)
	int result = 0;
	char newpath[MAXPATHLEN];

	debug_printf("stat64(%s)\n", path);
	if (-1 == (result = stat64(path, sb))) {
		return -1;
	}

	if (S_ISDIR(sb->st_mode)) {
		return result;
	}

	*newpath = '\0';
	if (!__darwintrace_is_in_sandbox(path, newpath)) {
		errno = ENOENT;
		return -1;
	}

	if (*newpath) {
		result = stat64(newpath, sb);
	}

	return result;
#undef stat64
}

int stat$INODE64(const char *path, struct stat64 *sb) {
	return stat64(path, sb);
}

#endif /* defined(__DARWIN_64_BIT_INO_T) && !defined(_DARWIN_FEATURE_ONLY_64_BIT_INODE) */


int lstat(const char *path, struct stat *sb) {
#define lstat(path, sb) syscall(SYS_lstat, path, sb)
	int result = 0;
	char newpath[MAXPATHLEN];

	debug_printf("lstat(%s)\n", path);
	if (-1 == (result = lstat(path, sb))) {
		return -1;
	}

	if (S_ISDIR(sb->st_mode)) {
		return result;
	}

	*newpath = '\0';
	if (!__darwintrace_is_in_sandbox(path, newpath)) {
		errno = ENOENT;
		return -1;
	}

	if (*newpath) {
		result = lstat(newpath, sb);
	}

	return result;
#undef lstat
}

#if defined(__DARWIN_64_BIT_INO_T) && !defined(_DARWIN_FEATURE_ONLY_64_BIT_INODE)

int lstat64(const char *path, struct stat64 *sb) {
#define lstat64(path, sb) syscall(SYS_lstat64, path, sb)
	int result = 0;
	char newpath[MAXPATHLEN];

	debug_printf("lstat64(%s)\n", path);
	if (-1 == (result = lstat64(path, sb))) {
		return -1;
	}

	if (S_ISDIR(sb->st_mode)) {
		return result;
	}

	*newpath = '\0';
	if (!__darwintrace_is_in_sandbox(path, newpath)) {
		errno = ENOENT;
		return -1;
	}

	if (*newpath) {
		result = lstat64(newpath, sb);
	}

	return result;
#undef lstat64
}

int lstat$INODE64(const char *path, struct stat64 *sb) {
	return lstat64(path, sb);
}

#endif /* defined(__DARWIN_64_BIT_INO_T) && !defined(_DARWIN_FEATURE_ONLY_64_BIT_INODE) */

/**
 * re-implementation of getdirent(2) and __getdirent64(2) preventing paths
 * outside the sandbox to show up when reading the contents of a directory.
 * Unfortunately, since we need to access the contents of the buffer, but the
 * contents differ by architecture, we can not rely on the dirent structure
 * defined by the header included by this program, because we don't know
 * whether darwintrace.dylib has been compiled for 64bit or 32bit inodes. We
 * thus copy both structs and decide at runtime.
 */

#ifdef __APPLE__
/* only do this on mac, because fcntl(fd, F_GETPATH) might not be available on
 * other systems, and because other system's syscall names are probably
 * different anyway */

#if defined(__DARWIN_64_BIT_INO_T)

struct dirent64  {
	__uint64_t  d_ino;      /* file number of entry */
	__uint64_t  d_seekoff;  /* seek offset */
	__uint16_t  d_reclen;   /* length of this record */
	__uint16_t  d_namlen;   /* length of string in d_name */
	__uint8_t   d_type;     /* file type */
	char      d_name[__DARWIN_MAXPATHLEN]; /* entry name (up to MAXPATHLEN bytes) */
};

size_t __getdirentries64(int fd, void *buf, size_t bufsize, __darwin_off_t *basep) {
#define __getdirentries64(w,x,y,z) syscall(SYS_getdirentries64, (w), (x), (y), (z))
	size_t sz = __getdirentries64(fd, buf, bufsize, basep);
	char dirname[MAXPATHLEN];
	size_t dnamelen;

	if (-1 == fcntl(fd, F_GETPATH, dirname)) {
		errno = EBADF;
		return -1;
	}

	dnamelen = strlen(dirname);
	if (dirname[dnamelen - 1] != '/') {
		dirname[dnamelen] = '/';
		dirname[dnamelen + 1] = '\0';
		dnamelen++;
	}

	dnamelen = strlen(dirname);
	size_t offset;
	for (offset = 0; offset < sz;) {
		struct dirent64 *dent = (struct dirent64 *)(((char *) buf) + offset);
		dirname[dnamelen] = '\0';
		strcat(dirname, dent->d_name);
		if (!__darwintrace_is_in_sandbox(dirname, NULL)) {
			debug_printf("__getdirentries64: filtered %s\n", dirname);
			dent->d_ino = 0;
		} else {
			debug_printf("__getdirentries64:  allowed %s\n", dirname);
		}
		offset += dent->d_reclen;
	}

	return sz;
#undef __getdirentries64
}

#endif /* defined(__DARWIN_64_BIT_INO_T) */

#pragma pack(4)
struct dirent32 {
	ino_t d_ino;            /* file number of entry */
	__uint16_t d_reclen;    /* length of this record */
	__uint8_t  d_type;      /* file type */
	__uint8_t  d_namlen;    /* length of string in d_name */
	char d_name[__DARWIN_MAXNAMLEN + 1]; /* name must be no longer than this */
};
#pragma pack()

int getdirentries(int fd, char *buf, int nbytes, long *basep) {
#define getdirentries(w,x,y,z) syscall(SYS_getdirentries, (w), (x), (y), (z))
	size_t sz = getdirentries(fd, buf, nbytes, basep);
	char dirname[MAXPATHLEN];
	size_t dnamelen;

	if (-1 == fcntl(fd, F_GETPATH, dirname)) {
		errno = EBADF;
		return 0;
	}

	dnamelen = strlen(dirname);
	if (dirname[dnamelen - 1] != '/') {
		dirname[dnamelen] = '/';
		dirname[dnamelen + 1] = '\0';
		dnamelen++;
	}

	size_t offset;
	for (offset = 0; offset < sz;) {
		struct dirent32 *dent = (struct dirent32 *)(buf + offset);
		dirname[dnamelen] = '\0';
		strcat(dirname, dent->d_name);
		if (!__darwintrace_is_in_sandbox(dirname, NULL)) {
			debug_printf("getdirentries: filtered %s\n", dirname);
			dent->d_ino = 0;
		} else {
			debug_printf("getdirentries:  allowed %s\n", dirname);
		}
		offset += dent->d_reclen;
	}

	return sz;
#undef getdirentries
}

int access(const char *path, int amode) {
#define access(x, y) syscall(SYS_access, (x), (y))
#define lstat(path, sb) syscall(SYS_lstat, path, sb)
	struct stat st;
	char newpath[MAXPATHLEN];

	debug_printf("access(%s, %d)\n", path, amode);

	if (-1 == (result = lstat(path, &st))) {
		return -1;
	}

	if (S_ISDIR(st.st_mode)) {
		return access(path, amode);
	}

	*newpath = '\0';
	if (!__darwintrace_is_in_sandbox(path, newpath)) {
		errno = ENOENT;
		return -1;
	}

	if (*newpath) {
		return access(newpath, amode);
	}

	return access(path, amode);
#undef lstat
#undef access
}

#endif /* __APPLE__ */
