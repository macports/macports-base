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
size_t strlcpy(char* dst, const char* src, size_t size);
size_t strlcpy(char* dst, const char* src, size_t size)
{
	size_t result = strlen(src);
	if (size > 0)
	{
		size_t copylen = size - 1;
		if (copylen > result)
		{
			copylen = result;
		}
		memcpy(dst, src, copylen);
		dst[copylen] = 0;
	}
	return result;
}
#endif

/*
 * Compile time options:
 * DARWINTRACE_SHOW_PROCESS: show the process id of every access
 * DARWINTRACE_LOG_CREATE: log creation of files as well.
 * DARWINTRACE_SANDBOX: control creation, deletion and writing to files and dirs.
 * DARWINTRACE_LOG_FULL_PATH: use F_GETPATH to log the full path.
 * DARWINTRACE_DEBUG_OUTPUT: verbose output of stuff to debug darwintrace.
 *
 * global variables (only checked when setup is first called)
 * DARWINTRACE_LOG
 *    path to the log file (no logging happens if it's unset).
 * DARWINTRACE_SANDBOX_BOUNDS
 *    : separated allowed paths for the creation of files.
 *    \: -> :
 *    \\ -> \
 */

#ifndef DARWINTRACE_SHOW_PROCESS
#define DARWINTRACE_SHOW_PROCESS 0
#endif
#ifndef DARWINTRACE_LOG_CREATE
#define DARWINTRACE_LOG_CREATE 0
#endif
#ifndef DARWINTRACE_SANDBOX
#define DARWINTRACE_SANDBOX 1
#endif
#ifndef DARWINTRACE_DEBUG_OUTPUT
#define DARWINTRACE_DEBUG_OUTPUT 0
#endif
#ifndef DARWINTRACE_LOG_FULL_PATH
#define DARWINTRACE_LOG_FULL_PATH 1
#endif

#ifndef DEFFILEMODE
#define DEFFILEMODE 0666
#endif

/*
 * Prototypes.
 */
static inline int __darwintrace_strbeginswith(const char* str, const char* prefix);
static inline int __darwintrace_pathbeginswith(const char* str, const char* prefix);
static inline void __darwintrace_log_op(const char* op, const char* path, int fd);
static void __darwintrace_copy_env() __attribute__((constructor));
static inline char* __darwintrace_alloc_env(const char* varName, const char* varValue);
static inline char* const* __darwintrace_restore_env(char* const envp[]);
static inline void __darwintrace_setup();
static inline void __darwintrace_cleanup_path(char *path);
static char * exchange_with_port(const char * buf, size_t len, int answer);

static int __darwintrace_fd = -2;
static FILE *__darwintrace_debug = NULL;
static pid_t __darwintrace_pid = (pid_t) -1;
#define BUFFER_SIZE	1024

/**
 * filemap: path\0whattodo\0path\0whattodo\0\0
 * path: begin of path (for example /opt)
 * whattodo: 
 *   0     -- allow
 *   1PATH -- map 
 *   2     -- ask for allow
**/
static char * filemap=0;

/* copy of the global variables */
static char* __env_dyld_insert_libraries;
static char* __env_dyld_force_flat_namespace;
static char* __env_darwintrace_log;
static char* __env_darwintrace_debug_log;

#if DARWINTRACE_DEBUG_OUTPUT
#if __STDC_VERSION__>=199901L
#define debug_printf(format, ...) fprintf(stderr, "darwintrace[%d]: " format, getpid(), __VA_ARGS__); \
	if (__darwintrace_debug) { \
		fprintf(__darwintrace_debug, "darwintrace: " format, __VA_ARGS__); \
	}
#else
__attribute__ ((format (printf, 1, 2)))
static inline
int debug_printf(const char *format, ...) {
    int ret;
    va_list args;
    va_start(args, format);
    ret = vfprintf(stderr, format, args);
    va_end(args);
    return ret;
}
#endif
#else
#define debug_printf(...)
#endif

/**
 * Return 0 if str doesn't begin with prefix, 1 otherwise. Note that this is
 * not a simple string comparison, but works on a path component level.
 * A prefix of /var/tmp will not match a string of /var/tmpfoo.
 */
static inline int __darwintrace_pathbeginswith(const char* str, const char* prefix) {
	char s;
	char p;
	do {
		s = *str++;
		p = *prefix++;
	} while (p && (p == s));
	return (p == 0 && (s == '/' || s == '\0'));
}

/**
 * Return 0 if str doesn't begin with prefix, 1 otherwise.
 */
inline int __darwintrace_strbeginswith(const char* str, const char* prefix) {
	char s;
	char p;
	do {
		s = *str++;
		p = *prefix++;
	} while (p && (p == s));
	return (p == 0);
}

/*
 * Copy the environment variables, if they're defined.
 */
void __darwintrace_copy_env() {
	char* theValue;
	theValue = getenv("DYLD_INSERT_LIBRARIES");
	if (theValue != NULL) {
		__env_dyld_insert_libraries = strdup(theValue);
	} else {
		__env_dyld_insert_libraries = NULL;
	}
	theValue = getenv("DYLD_FORCE_FLAT_NAMESPACE");
	if (theValue != NULL) {
		__env_dyld_force_flat_namespace = strdup(theValue);
	} else {
		__env_dyld_force_flat_namespace = NULL;
	}
	theValue = getenv("DARWINTRACE_LOG");
	if (theValue != NULL) {
		__env_darwintrace_log = strdup(theValue);
	} else {
		__env_darwintrace_log = NULL;
	}
	theValue = getenv("DARWINTRACE_DEBUG_LOG");
	if (theValue != NULL) {
		__env_darwintrace_debug_log = strdup(theValue);
	} else {
		__env_darwintrace_debug_log = NULL;
	}
}

/*
 * Allocate a X=Y string where X is the variable name and Y its value.
 * Return the new string.
 *
 * If the value is NULL, return NULL.
 */
static inline char* __darwintrace_alloc_env(const char* varName, const char* varValue) {
	char* theResult = NULL;
	if (varValue) {
		int theSize = strlen(varName) + strlen(varValue) + 2;
		theResult = (char*) malloc(theSize);
		if (theResult) {
		    snprintf(theResult, theSize, "%s=%s", varName, varValue);
		    theResult[theSize - 1] = 0;
		}
	}
	
	return theResult;
}

/*
 * This function checks that envp contains the global variables we had when the
 * library was loaded and modifies it if it doesn't.
 */
__attribute__((always_inline))
static inline char* const* __darwintrace_restore_env(char* const envp[]) {
	/* allocate the strings. */
	/* we don't care about the leak here because we're going to call execve,
     * which, if it succeeds, will get rid of our heap */
	char* dyld_insert_libraries_ptr =	
		__darwintrace_alloc_env(
			"DYLD_INSERT_LIBRARIES",
			__env_dyld_insert_libraries);
	char* dyld_force_flat_namespace_ptr =	
		__darwintrace_alloc_env(
			"DYLD_FORCE_FLAT_NAMESPACE",
			__env_dyld_force_flat_namespace);
	char* darwintrace_log_ptr =	
		__darwintrace_alloc_env(
			"DARWINTRACE_LOG",
			__env_darwintrace_log);
	char* darwintrace_debug_log_ptr =	
		__darwintrace_alloc_env(
			"DARWINTRACE_DEBUG_LOG",
			__env_darwintrace_debug_log);

	char* const * theEnvIter = envp;
	int theEnvLength = 0;
	char** theCopy;
	char** theCopyIter;

	while (*theEnvIter != NULL) {
		theEnvLength++;
		theEnvIter++;
	}

	/* 5 is sufficient for the four variables we copy and the terminator */
	theCopy = (char**) malloc(sizeof(char*) * (theEnvLength + 5));
	theEnvIter = envp;
	theCopyIter = theCopy;

	while (*theEnvIter != NULL) {
		char* theValue = *theEnvIter;
		if (__darwintrace_strbeginswith(theValue, "DYLD_INSERT_LIBRARIES=")) {
			theValue = dyld_insert_libraries_ptr;
			dyld_insert_libraries_ptr = NULL;
		} else if (__darwintrace_strbeginswith(theValue, "DYLD_FORCE_FLAT_NAMESPACE=")) {
			theValue = dyld_force_flat_namespace_ptr;
			dyld_force_flat_namespace_ptr = NULL;
		} else if (__darwintrace_strbeginswith(theValue, "DARWINTRACE_LOG=")) {
			theValue = darwintrace_log_ptr;
			darwintrace_log_ptr = NULL;
		} else if (__darwintrace_strbeginswith(theValue, "DARWINTRACE_DEBUG_LOG=")) {
			theValue = darwintrace_debug_log_ptr;
			darwintrace_debug_log_ptr = NULL;
		}
		
		if (theValue) {
			*theCopyIter++ = theValue;
		}

		theEnvIter++;
	}
	
	if (dyld_insert_libraries_ptr) {
		*theCopyIter++ = dyld_insert_libraries_ptr;
	}
	if (dyld_force_flat_namespace_ptr) {
		*theCopyIter++ = dyld_force_flat_namespace_ptr;
	}
	if (darwintrace_log_ptr) {
		*theCopyIter++ = darwintrace_log_ptr;
	}
	if (darwintrace_debug_log_ptr) {
		*theCopyIter++ = darwintrace_debug_log_ptr;
	}

	*theCopyIter = 0;
	
	return theCopy;
}

static void ask_for_filemap()
{
	filemap=exchange_with_port("filemap\t", sizeof("filemap\t"), 1);
	if(filemap==(char*)-1)
		filemap=0;
}

__attribute__((always_inline))
static inline void __darwintrace_setup() {
#define open(x,y,z) syscall(SYS_open, (x), (y), (z))
#define close(x) syscall(SYS_close, (x))
	pid_t oldpid = __darwintrace_pid;
	if (__darwintrace_pid != (pid_t) -1 && __darwintrace_pid != getpid()) {
		if (__darwintrace_fd != -2) {
			close(__darwintrace_fd);
			__darwintrace_fd = -2;
		}
		if (__darwintrace_debug) {
			fclose(__darwintrace_debug);
			__darwintrace_debug = NULL;
		}
		__darwintrace_pid = (pid_t) -1;
	}
	if (__darwintrace_pid == (pid_t) -1) {
		__darwintrace_pid = getpid();
		if (__env_darwintrace_log != NULL) {
			int olderrno = errno;
			int sock = socket(AF_UNIX, SOCK_STREAM, 0);
			struct sockaddr_un sun;
			sun.sun_family = AF_UNIX;
			strncpy(sun.sun_path, __env_darwintrace_log, sizeof(sun.sun_path));
			if (connect(sock, (struct sockaddr*)&sun, strlen(__env_darwintrace_log) + 1 + sizeof(sun.sun_family)) != -1) {
				__darwintrace_fd = sock;
				ask_for_filemap();
			} else {
				debug_printf("connect failed: %s\n", strerror(errno));
				abort();
			}
			errno = olderrno;
		}
		if (__darwintrace_debug == NULL) {
			if (__env_darwintrace_debug_log != NULL) {
				char logpath[MAXPATHLEN];
				snprintf(logpath, MAXPATHLEN, __env_darwintrace_debug_log, getpid());
				if (NULL == (__darwintrace_debug = fopen(logpath, "w"))) {
					fprintf(stderr, "failed to open logfile: %s\n", strerror(errno));
					abort();
				}
				fprintf(__darwintrace_debug, "pid %d is process %s\n", getpid(), getenv("_"));
				debug_printf("logging socket communication to: %s\n", logpath);
			}
		}
		if (oldpid != (pid_t) -1) {
			debug_printf("seems to have forked from %d, re-opened files\n", oldpid);
		}
	}
#undef close
#undef open
}

/* log a call and optionally get the real path from the fd if it's not 0.
 * op:			the operation (open, readlink, execve)
 * path:		the path of the file
 * fd:			a fd to the file, or 0 if we don't have any.
 */
__attribute__((always_inline))
static inline void __darwintrace_log_op(const char* op, const char* path, int fd) {
	int size;
	char somepath[MAXPATHLEN];
	char logbuffer[BUFFER_SIZE];

	do {
#ifdef __APPLE__ /* Only Darwin has volfs and F_GETPATH */
		if ((fd > 0) && (DARWINTRACE_LOG_FULL_PATH
			|| (strncmp(path, "/.vol/", 6) == 0))) {
			if(fcntl(fd, F_GETPATH, somepath) == -1) {
				/* getpath failed. use somepath instead */
				strlcpy(somepath, path, sizeof(somepath));
				break;
			}
		}
#endif
		if (path[0] != '/') {
			int len;
			(void) getcwd(somepath, sizeof(somepath));
			len = strlen(somepath);
			somepath[len++] = '/';
			strlcpy(&somepath[len], path, sizeof(somepath) - len);
			break;
		}

		/* otherwise, just copy the original path. */
		strlcpy(somepath, path, sizeof(somepath));
	} while (0);

	/* clean the path. */
	__darwintrace_cleanup_path(somepath);

	size = snprintf(logbuffer, sizeof(logbuffer), "%s\t%s", op, somepath);

	exchange_with_port(logbuffer, size + 1, 0);
	
	return;
}

/* remap resource fork access to the data fork.
 * do a partial realpath(3) to fix "foo//bar" to "foo/bar"
 */
static inline void __darwintrace_cleanup_path(char *path) {
	size_t pathlen;
#	ifdef __APPLE__
	size_t rsrclen;
#	endif
	size_t i, shiftamount;
	enum { SAWSLASH, NOTHING } state = NOTHING;

	/* if this is a foo/..namedfork/rsrc, strip it off */
	pathlen = strlen(path);
	/* ..namedfork/rsrc is only on OS X */
#	ifdef __APPLE__
	rsrclen = strlen(_PATH_RSRCFORKSPEC);
	if (pathlen > rsrclen && 0 == strcmp(path + pathlen - rsrclen, _PATH_RSRCFORKSPEC)) {
		path[pathlen - rsrclen] = '\0';
		pathlen -= rsrclen;
	}
#	endif

	/* for each position in string (including terminal \0), check if we're in
	 * a run of multiple slashes, and only emit the first one */
	for(i = 0, shiftamount = 0; i <= pathlen; i++) {
		if (state == SAWSLASH) {
			if (path[i] == '/') {
				/* consume it */
				shiftamount++;
				continue;
			} else {
				state = NOTHING;
			}
		} else {
			if (path[i] == '/') {
				state = SAWSLASH;
			}
		}
		path[i - shiftamount] = path[i];
	}
}

/*
 * return 1 if path allowed, 0 otherwise
 */
static int ask_for_dependency(char * path) {
#define stat(y, z) syscall(SYS_stat, (y), (z))
	char buffer[BUFFER_SIZE], *p;
	int result = 0;
	struct stat st;

	debug_printf("ask_for_dependency: %s\n", path);

	if (-1 == stat(path, &st)) {
		return 1;
	}
	if (S_ISDIR(st.st_mode)) {
		debug_printf("%s is directory\n", path);
		return 1;
	}
	
	strncpy(buffer, "dep_check\t", sizeof(buffer));
	strncpy(buffer+10, path, sizeof(buffer)-10);
	p=exchange_with_port(buffer, strlen(buffer)+1, 1);
	if(p==(char*)-1||!p)
		return 0;
	
	if(*p=='+')
		result=1;
	
	free(p);
	return result;
#undef stat
}

/*
 * exchange_with_port - routine to send/recv from/to socket
 * Parameters:
 *   buf      -- buffer with data to send
 *   len      -- length of data
 *   answer   -- 1 (yes, I want to receive answer) and 0 (no, thanks, just send)
 *   failures -- should be setted 0 on external calls (avoid infinite recursion)
 * Return value:
 *    -1     -- something went wrong
 *    0      -- data successfully sent
 *    string -- answer (caller shoud free it)
 */
static char * exchange_with_port(const char * buf, size_t len, int answer) {
	size_t sent = 0;

	if (__darwintrace_debug) {
		fprintf(__darwintrace_debug, "> %s\n", buf);
	}
	while (sent < len) {
		ssize_t local_sent = send(__darwintrace_fd, buf + sent, len - sent, 0);
		if (local_sent == -1) {
			debug_printf("error communicating with socket %d: %s\n", __darwintrace_fd, strerror(errno));
			if (__darwintrace_debug)
				fprintf(__darwintrace_debug, "darwintrace: error communicating with socket %d: %s\n", __darwintrace_fd, strerror(errno));
			abort();
		}
		sent += local_sent;
	}
	if (!answer) {
		return 0;
	} else {
		size_t recv_len = 0, received;
		char *recv_buf;
		
		received = 0;
		while (received < sizeof(recv_len)) {
			ssize_t local_received = recv(__darwintrace_fd, ((char *) &recv_len) + received, sizeof(recv_len) - received, 0);
			if (local_received == -1) {
				debug_printf("error reading data from socket %d: %s\n", __darwintrace_fd, strerror(errno));
				if (__darwintrace_debug)
					fprintf(__darwintrace_debug, "darwintrace: error reading data from socket %d: %s\n", __darwintrace_fd, strerror(errno));
				abort();
			}
			received += local_received;
		}
		if (recv_len == 0) {
			return 0;
		}

		recv_buf = malloc(recv_len + 1);
		recv_buf[recv_len] = '\0';

		received = 0;
		while (received < recv_len) {
			ssize_t local_received = recv(__darwintrace_fd, recv_buf + received, recv_len - received, 0);
			if (local_received == -1) {
				debug_printf("error reading data from socket %d: %s\n", __darwintrace_fd, strerror(errno));
				if (__darwintrace_debug)
					fprintf(__darwintrace_debug, "darwintrace: error reading data from socket %d: %s\n", __darwintrace_fd, strerror(errno));
				abort();
			}
			received += local_received;
		}
		if (__darwintrace_debug) {
			fprintf(__darwintrace_debug, "< %s\n", recv_buf);
		}
		return recv_buf;
	}
}

#define DARWINTRACE_STATUS_PATH    ((char) 0)
#define DARWINTRACE_STATUS_COMMAND ((char) 1)
#define DARWINTRACE_STATUS_DONE    ((char) 2)

/*
 * return 1 if path (once normalized) is in sandbox or redirected, 0 otherwise.
 */
__attribute__((always_inline))
static inline int __darwintrace_is_in_sandbox(const char* path, char * newpath) {
	char *t, *p, *_;
	char *strpos, *normpos;
	char lpath[MAXPATHLEN];
	char normalizedpath[MAXPATHLEN];
	
	__darwintrace_setup();
	
	if (!filemap)
		return 1;
	
	if (*path=='/') {
		p = strcpy(lpath, path);
	} else {
		if (getcwd(lpath, MAXPATHLEN - 1) == NULL) {
			fprintf(stderr, "darwintrace: getcwd: %s, path was: %s\n", strerror(errno), path);
			abort();
		}
		strcat(lpath, "/");
		strcat(lpath, path);
	}
	p = lpath;

	normalizedpath[0] = '\0';
	strpos = p + 1;
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
		}
		/* default case: standard path, copy */
		strcat(normpos, "/");
		normpos++;
		strcat(normpos, curpos);
	}
	if (*normalizedpath == '\0') {
		strcat(normalizedpath, "/");
	}

	for (t = filemap; *t;) {
		char state;
		
		if (__darwintrace_pathbeginswith(normalizedpath, t)) {
			/* move t to the integer describing how to handle this match */
			t += strlen(t) + 1;
			switch (*t) {
				case 0:
					return 1;
				case 1:
					if (!newpath) {
						return 0;
					}
					/* the redirected path starts right after the byte telling
					 * us we should redirect */
					strcpy(newpath, t + 1);
					_ = newpath + strlen(newpath);
					/* append '/' if it's missing */
					if (_[-1] != '/') {
						*_ = '/';
					}
					strcpy(_, normalizedpath);
					return 1;
				case 2:
					/* ask the socket whether this file is OK */
					return ask_for_dependency(normalizedpath);
				default:
					fprintf(stderr, "darwintrace: error: unexpected byte in file map: `%x'\n", *t);
					abort();
			}
		}

		/* advance the cursor: if the number after the string is not 1, there's
		 * no path behind it and we can advance by strlen(t) + 3. If it is 1,
		 * make sure to skip the path, too.
		 */
		state = DARWINTRACE_STATUS_PATH;
		while (state != DARWINTRACE_STATUS_DONE) {
			switch (state) {
				case DARWINTRACE_STATUS_PATH:
					if (!*t) {
						state = DARWINTRACE_STATUS_COMMAND;
					}
					break;
				case DARWINTRACE_STATUS_COMMAND:
					if (*t == 1) {
						state = DARWINTRACE_STATUS_PATH;
						t++;
					} else {
						state = DARWINTRACE_STATUS_DONE;
					}
					break;
			}
			t++;
		}
		t++;
	}

	__darwintrace_log_op("sandbox_violation", normalizedpath, 0);
	return 0;
}

/* wrapper for open(2) preventing opening files outside the sandbox */
int open(const char* path, int flags, ...) {
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
int readlink(const char * path, char * buf, int bufsiz) {
#else
ssize_t readlink(const char * path, char * buf, size_t bufsiz) {
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

int execve(const char* path, char* const argv[], char* const envp[]) {
#define __execve(x,y,z) syscall(SYS_execve, (x), (y), (z))
#define open(x,y,z) syscall(SYS_open, (x), (y), (z))
#define close(x) syscall(SYS_close, (x))
#define lstat(x, y) syscall(SYS_lstat, (x), (y))
	debug_printf("execve(%s)\n", path);
	__darwintrace_setup();
	if (__darwintrace_fd >= 0) {
		struct stat sb;
		/* for symlinks, we want to capture both the original path and the
		 * modified one, since for /usr/bin/gcc -> gcc-4.0, both "gcc_select"
		 * and "gcc" are contributors
		 */
		if (lstat(path, &sb) == 0) {
			int fd;
			if (S_ISLNK(sb.st_mode)) {
				/* for symlinks, print both */
				__darwintrace_log_op("execve", path, 0);
			}

			fd = open(path, O_RDONLY, 0);
			if (fd > 0) {
				char buffer[MAXPATHLEN+1];
				ssize_t bytes_read;

				if(!__darwintrace_is_in_sandbox(path, NULL)) {
					close(fd);
					errno = ENOENT;
					return -1;
				}
	
				/* once we have an open fd, if a full path was requested, do it */
				__darwintrace_log_op("execve", path, fd);
	
				/* read the file for the interpreter */
				bytes_read = read(fd, buffer, MAXPATHLEN);
				buffer[bytes_read] = 0;
				if (bytes_read > 2 && buffer[0] == '#' && buffer[1] == '!') {
					const char* interp = &buffer[2];
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
					/* we have liftoff */
					if (interp && interp[0] != '\0') {
						__darwintrace_log_op("execve", interp, 0);
					}
				}
				close(fd);
			}
		}
	}
	/* our variables won't survive exec, clean up */
	if (__darwintrace_fd != -2) {
		close(__darwintrace_fd);
		__darwintrace_fd = -2;
	}
	if (__darwintrace_debug) {
		fclose(__darwintrace_debug);
		__darwintrace_debug = NULL;
	}
	__darwintrace_pid = (pid_t) -1;

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
	if (__darwintrace_fd != -2 && fd == __darwintrace_fd) {
		errno = EBADF;
		return -1;
	}

	return close(fd);
#undef close
}

/* if darwintrace has been initialized, trap attempts to dup2 over our file descriptor */
int dup2(int filedes, int filedes2) {
#define dup2(x, y) syscall(SYS_dup2, (x), (y))

	debug_printf("dup2(%d, %d)\n", filedes, filedes2);
	if (__darwintrace_fd != -2 && filedes2 == __darwintrace_fd) {
		/* if somebody tries to close our file descriptor, just move it out of
		 * the way. Make sure it doesn't end up as stdin/stdout/stderr, though!
		 * */
		int new_darwintrace_fd;

		if (-1 == (new_darwintrace_fd = fcntl(__darwintrace_fd, F_DUPFD, STDOUT_FILENO + 1))) {
			/* if duplicating fails, do not allow overwriting either! */
			return -1;
		}

		debug_printf("moving __darwintrace_fd from %d to %d\n", __darwintrace_fd, new_darwintrace_fd);
		__darwintrace_fd = new_darwintrace_fd;
	}

	return dup2(filedes, filedes2);
#undef dup2
}


/* Trap attempts to unlink a file outside the sandbox. */
int unlink(const char* path) {
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
int mkdir(const char* path, mode_t mode) {
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
int rmdir(const char* path) {
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
int rename(const char* from, const char* to) {
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

int stat(const char * path, struct stat * sb) {
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

int stat64(const char * path, struct stat64 * sb) {
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

int stat$INODE64(const char * path, struct stat64 * sb) {
    return stat64(path, sb);
}

#endif /* defined(__DARWIN_64_BIT_INO_T) && !defined(_DARWIN_FEATURE_ONLY_64_BIT_INODE) */


int lstat(const char * path, struct stat * sb) {
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

int lstat64(const char * path, struct stat64 * sb) {
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

int lstat$INODE64(const char * path, struct stat64 * sb) {
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
#endif /* __APPLE__ */
