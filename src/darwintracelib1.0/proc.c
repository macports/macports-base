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
#include "sip_copy_proc.h"

#include <ctype.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>

#if defined(HAVE_SPAWN_H) && defined(HAVE_POSIX_SPAWN)
#include <spawn.h>
#endif

/**
 * Copy of the DYLD_INSERT_LIBRARIES environment variable to restore it in
 * execve(2). DYLD_INSERT_LIBRARIES is needed to preload this library into any
 * process' address space.
 */
static char *__env_dyld_insert_libraries;
static char *__env_full_dyld_insert_libraries;

/**
 * Copy of the DYLD_FORCE_FLAT_NAMESPACE environment variable to restore it in
 * execve(2). DYLD_FORCE_FLAT_NAMESPACE=1 is needed for the preload-based
 * sandbox to work.
 */
static char *__env_dyld_force_flat_namespace;
static char *__env_full_dyld_force_flat_namespace;

/**
 * Copy of the DARWINTRACE_LOG environment variable to restore it in execve(2).
 * Contains the path to the unix socket used for communication with the
 * MacPorts-side of the sandbox. Since this variable is also used from
 * darwintrace.c, is can not be static.
 */
char *__env_darwintrace_log;
static char *__env_full_darwintrace_log;

/**
 * Copy the environment variables, if they're defined. This is run as
 * a constructor at startup.
 */
void __darwintrace_store_env() {
#define COPYENV(name, variable, valuevar) do {\
		char *val;\
		if (NULL != (val = getenv(#name))) {\
			size_t lenName = strlen(#name);\
			size_t lenVal  = strlen(val);\
			if (NULL == (variable = malloc(lenName + 1 + lenVal + 1))) {\
				perror("darwintrace: malloc");\
				abort();\
			}\
			strcpy(variable, #name);\
			strcat(variable, "=");\
			strcat(variable, val);\
			valuevar = variable + lenName + 1;\
		} else {\
			variable = NULL;\
			valuevar = NULL;\
		}\
	} while (0)

	COPYENV(DYLD_INSERT_LIBRARIES, __env_full_dyld_insert_libraries, __env_dyld_insert_libraries);
	COPYENV(DYLD_FORCE_FLAT_NAMESPACE, __env_full_dyld_force_flat_namespace, __env_dyld_force_flat_namespace);
	COPYENV(DARWINTRACE_LOG, __env_full_darwintrace_log, __env_darwintrace_log);
#undef COPYENV

	char *debugpath = getenv("DARWINTRACE_DEBUG");
	if (debugpath) {
		__darwintrace_stderr = fopen(debugpath, "a+");
	} else {
		__darwintrace_stderr = stderr;
	}
}

/**
 * Return false if str doesn't begin with prefix, true otherwise.
 */
static inline bool __darwintrace_strbeginswith(const char *str, const char *prefix) {
	char s;
	char p;
	do {
		s = *str++;
		p = *prefix++;
	} while (p && (p == s));
	return (p == '\0');
}

/**
 * This function checks that envp contains the global variables we had when the
 * library was loaded and modifies it if it doesn't. Returns a malloc(3)'d copy
 * of envp where the appropriate values have been restored. The caller should
 * pass the returned pointer to free(3) if necessary to avoid leaks.
 */
static inline char **restore_env(char *const envp[]) {
	// we can re-use pre-allocated strings from store_env
	char *dyld_insert_libraries_ptr     = __env_full_dyld_insert_libraries;
	char *dyld_force_flat_namespace_ptr = __env_full_dyld_force_flat_namespace;
	char *darwintrace_log_ptr           = __env_full_darwintrace_log;

	char *const *enviter = envp;
	size_t envlen = 0;
	char **copy;
	char **copyiter;

	while (enviter != NULL && *enviter != NULL) {
		envlen++;
		enviter++;
	}

	// 4 is sufficient for the three variables we copy and the terminator
	copy = malloc(sizeof(char *) * (envlen + 4));

	enviter  = envp;
	copyiter = copy;

	while (enviter != NULL && *enviter != NULL) {
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

/**
 * Helper function that opens the file indicated by \a path, checks whether it
 * is a script (i.e., contains a shebang line) and verifies the interpreter is
 * within the sandbox bounds.
 *
 * \param[in] path The path of the file to be executed
 * \return 0, if access should be granted, a non-zero error code to be stored
 *         in \c errno otherwise
 */
static inline int check_interpreter(const char *restrict path) {
	int fd = open(path, O_RDONLY, 0);
	if (fd <= 0) {
		return errno;
	}

	char buffer[MAXPATHLEN + 1 + 2];
	ssize_t bytes_read;

	/* Read the file for the interpreter. Fortunately, on macOS:
	 *   The system guarantees to read the number of bytes requested if
	 *   the descriptor references a normal file that has that many
	 *   bytes left before the end-of-file, but in no other case.
	 * That _does_ save us another ugly loop to get things right. */
	bytes_read = read(fd, buffer, sizeof(buffer) - 1);
	if (bytes_read < 0) {
		return errno;
	}
	buffer[bytes_read] = '\0';
	close(fd);

	const char *buffer_end = buffer + bytes_read;
	if (bytes_read > 2 && buffer[0] == '#' && buffer[1] == '!') {
		char *interp = buffer + 2;

		/* skip past leading whitespace */
		while (interp < buffer_end && isblank(*interp)) {
			++interp;
		}
		/* found interpreter (or ran out of data); skip until next
		 * whitespace, then terminate the string */
		if (interp < buffer_end) {
			char *interp_end = interp;
			strsep(&interp_end, " \t");
		}

		/* check the iterpreter against the sandbox */
		if (!__darwintrace_is_in_sandbox(interp, DT_REPORT | DT_ALLOWDIR | DT_FOLLOWSYMS)) {
			return ENOENT;
		}
	}

	return 0;
}

/**
 * Wrapper for \c execve(2). Denies access and simulates the file does not
 * exist, if it's outside the sandbox. Also checks for potential interpreters
 * using \c check_interpreter.
 */
static int _dt_execve(const char *path, char *const argv[], char *const envp[]) {
	if (!__darwintrace_initialized) {
		return execve(path, argv, envp);
	}

	__darwintrace_setup();

	int result = 0;

	if (!__darwintrace_is_in_sandbox(path, DT_REPORT | DT_ALLOWDIR | DT_FOLLOWSYMS)) {
		errno = ENOENT;
		result = -1;
	} else {
		int interp_result = check_interpreter(path);
		if (interp_result != 0) {
			errno = interp_result;
			result = -1;
		} else {
			// Since \c execve(2) will likely not return, log before calling
			debug_printf("execve(%s) = ?\n", path);

			// Our variables won't survive exec, clean up
			__darwintrace_close();
			__darwintrace_pid = (pid_t) -1;

			// Call the original execve function, but restore environment
			char **newenv = restore_env(envp);
			result = sip_copy_execve(path, argv, newenv);
			free(newenv);
		}
	}

	debug_printf("execve(%s) = %d\n", path, result);

	return result;
}

DARWINTRACE_INTERPOSE(_dt_execve, execve);

#if defined(HAVE_SPAWN_H) && defined(HAVE_POSIX_SPAWN)
/**
 * Wrapper for \c posix_spawn(2). Denies access and simulates the file does not
 * exist, if it's outside the sandbox. Also checks for potential interpreters
 * using \c check_interpreter.
 */
static int _dt_posix_spawn(pid_t *restrict pid, const char *restrict path, const posix_spawn_file_actions_t *file_actions,
		const posix_spawnattr_t *restrict attrp, char *const argv[restrict], char *const envp[restrict]) {
	if (!__darwintrace_initialized) {
		return posix_spawn(pid, path, file_actions, attrp, argv, envp);
	}

	__darwintrace_setup();

	int result = 0;

	if (!__darwintrace_is_in_sandbox(path, DT_REPORT | DT_ALLOWDIR | DT_FOLLOWSYMS)) {
		result = ENOENT;
	} else {
		int interp_result = check_interpreter(path);
		if (interp_result != 0) {
			result = interp_result;
		} else {
			short attrflags;
			if (   attrp != NULL
				&& posix_spawnattr_getflags(attrp, &attrflags) == 0
				&& (attrflags & POSIX_SPAWN_SETEXEC) > 0) {
				// Apple-specific extension: This call will not return, but
				// behave like execve(2). Since our variables won't survive
				// that, clean up. Also log the call, because we likely won't
				// be able to after the call.
				debug_printf("execve(%s) = ?\n", path);

				__darwintrace_close();
				__darwintrace_pid = (pid_t) - 1;
			}

			// call the original posix_spawn function, but restore environment
			char **newenv = restore_env(envp);
			result = sip_copy_posix_spawn(pid, path, file_actions, attrp, argv, newenv);
			free(newenv);
		}
	}

	debug_printf("posix_spawn(%s) = %d\n", path, result);

	return result;
}

DARWINTRACE_INTERPOSE(_dt_posix_spawn, posix_spawn);
#endif
