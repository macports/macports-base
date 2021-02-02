/*
 * Copyright (c) 2005 Apple Inc. All rights reserved.
 * Copyright (c) 2005-2006 Paul Guyot <pguyot@kallisys.net>,
 * All rights reserved.
 * Copyright (c) 2006-2013 The MacPorts Project
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

#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>

/**
 * DARWINTRACE_INTERPOSE: provides a way to override standard library functions
 * with your own implementations.
 */
#ifndef DARWINTRACE_INTERPOSE
#define DARWINTRACE_INTERPOSE(_replacement, _replacee) \
__attribute__((used)) static struct { \
	const void *replacement; \
	const void *replacee; \
} _interpose_##_replacee \
__attribute__((section ("__DATA,__interpose"))) = { \
	(const void *) (unsigned long) &_replacement, \
	(const void *) (unsigned long) &_replacee \
}
#endif

/**
 * DARWINTRACE_DEBUG: verbose output of operations to debug darwintrace
 */
#ifndef DARWINTRACE_DEBUG
#define DARWINTRACE_DEBUG (0)
#endif

/**
 * \c debug_printf() is a macro that will print a message prefixed with
 * "darwintrace" and the calling process' PID to stderr, or to the file
 * indicated by the environment variable \c DARWINTRACE_DEBUG, if set.
 */
#if DARWINTRACE_DEBUG
#	define debug_printf(format, ...) \
		if (__darwintrace_stderr != NULL) { \
			fprintf(__darwintrace_stderr, "darwintrace[%d:%p]: " format, getpid(), (void *) pthread_self(), ##__VA_ARGS__); \
			fflush(__darwintrace_stderr); \
		}
#else
#   define debug_printf(...)
#endif

enum {
	DT_REPORT     = 1 << 0,
	DT_ALLOWDIR   = 1 << 1,
	DT_FOLLOWSYMS = 1 << 2
};

/**
 * Debug socket. Will be set by a constructor function in darwintrace.c.
 */
extern FILE *__darwintrace_stderr;

/**
 * Initializer function, ensures darwintrace has been properly set up and check
 * whether this process was fork(2)'d or clone(2)'d since the last call. Call
 * this before calling any other functions from this library.
 */
void __darwintrace_setup();

/**
 * Close the darwintrace socket and set it to \c NULL. Since this uses \c
 * fclose(3), which internally calls \c close(2), which is intercepted by this
 * library and this library prevents closing the socket to MacPorts, we use \c
 * __darwintrace_close_sock to allow closing specific FDs.
 */
void __darwintrace_close();

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
 *                  - DT_FOLLOWSYMS: Check for and expand symlinks, while
 *                    checking both the link name and the link target against
 *                    the sandbox. Set this for all operations that read file
 *                    contents or check file attributes. Omit this flag for
 *                    operations that only list the file (or rather symlink)
 *                    name.
 * \return \c true if the file is within sandbox bounds, \c false if access
 *         should be denied
 */
bool __darwintrace_is_in_sandbox(const char *path, int flags);

/**
 * Whether darwintrace has been fully initialized or not. Do not interpose if
 * this has not been set to true.
 */
extern volatile bool __darwintrace_initialized;

#ifdef DARWINTRACE_USE_PRIVATE_API
#include <errno.h>
#include <stdlib.h>

/**
 * PID of the process darwintrace was last used in. This is used to detect
 * forking and opening a new connection to the control socket in the child
 * process. Not doing so would potentially cause two processes writing to the
 * same socket.
 */
extern pid_t __darwintrace_pid;

/**
 * Copy of the DARWINTRACE_LOG environment variable to restore it in execve(2).
 * Contains the path to the unix socket used for communication with the
 * MacPorts-side of the sandbox.
 */
extern char *__env_darwintrace_log;

/**
 * Helper variable containing the number of the darwintrace socket, iff the
 * close(2) syscall should be allowed to close it. Used by \c
 * __darwintrace_close.
 */
extern volatile int __darwintrace_close_sock;

/**
 * pthread_key_t for the darwintrace socket to ensure the socket is only used
 * from a single thread.
 */
extern pthread_key_t sock_key;

/**
 * Convenience getter function for the thread-local darwintrace socket. Do not
 * consider this part of public API. It is only needed to prevent closing and
 * duplicating over darwintrace's socket FDs.
 */
static inline FILE *__darwintrace_sock() {
	return (FILE *) pthread_getspecific(sock_key);
}

/**
 * Convenience setter function for the thread-local darwintrace socket. Do not
 * consider this part of public API. It is only needed to prevent closing and
 * duplicating over darwintrace's socket FDs.
 */
static inline void __darwintrace_sock_set(FILE *stream) {
	if (0 != (errno = pthread_setspecific(sock_key, stream))) {
		perror("darwintrace: pthread_setspecific");
		abort();
	}
}

/**
 * Initialize TLS variables.
 */
void __darwintrace_setup_tls();

/**
 * Grab environment variables at startup.
 */
void __darwintrace_store_env();

/**
 * Runs our "constructors". By this point all of the system libraries we link
 * against should be fully initialized, so we can call their functions safely.
 * Once our initialization is complete we may begin interposing.
 */
void __darwintrace_run_constructors() __attribute__((constructor));

#endif /* defined(DARWINTRACE_USE_PRIVATE_API) */
