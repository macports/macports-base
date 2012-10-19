/*
 * Copyright (c) 2005 Apple Inc. All rights reserved.
 * Copyright (c) 2005-2006 Paul Guyot <pguyot@kallisys.net>,
 * All rights reserved.
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

#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/syscall.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>

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
inline int __darwintrace_strbeginswith(const char* str, const char* prefix);
inline void __darwintrace_log_op(const char* op, const char* path, int fd);
void __darwintrace_copy_env() __attribute__((constructor));
inline char* __darwintrace_alloc_env(const char* varName, const char* varValue);
inline char* const* __darwintrace_restore_env(char* const envp[]);
inline void __darwintrace_setup();
inline void __darwintrace_cleanup_path(char *path);
static char * exchange_with_port(const char * buf, size_t len, int answer, char failures);

#define START_FD 81
static int __darwintrace_fd = -1;
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

#if __STDC_VERSION__>=199901L
#if DARWINTRACE_DEBUG_OUTPUT
#define debug_printf(...) fprintf(stderr, __VA_ARGS__)
#else
#define debug_printf(...)
#endif
#else
#if DARWINTRACE_DEBUG_OUTPUT
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
#else
#define debug_printf(format, param)
#endif
#endif

/*
 * char wait_for_socket(int sock, char w)
 * Function used for read/write operation to socket...
 * Args:
 *  sock - socket 
 *  w - what should socket do in next operation. 1 for write, 0 for read
 * Return value: 
 *  1 - everything is ok, we can read/write to/from it
 *  0 - something's went wrong
 */
static int wait_for_socket(int sock, char w)
{
	struct timeval tv;
	fd_set fds;
	
	if(sock==-1)
		return 0;
	
	tv.tv_sec=10;
	tv.tv_usec=0;
	FD_ZERO(&fds);
	FD_SET(sock, &fds);
	if(select(sock+1, (w==0 ? &fds : 0), (w==1 ? &fds : 0), 0, &tv)<1)
		return 0;
	return FD_ISSET(sock, &fds)!=0;
}


/*
 * return 0 if str doesn't begin with prefix, 1 otherwise.
 */
inline int __darwintrace_strbeginswith(const char* str, const char* prefix) {
	char theCharS;
	char theCharP;
	do {
		theCharS = *str++;
		theCharP = *prefix++;
	} while(theCharP && (theCharP == theCharS));
	return (theCharP == 0);
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
}

/*
 * Allocate a X=Y string where X is the variable name and Y its value.
 * Return the new string.
 *
 * If the value is NULL, return NULL.
 */
inline char* __darwintrace_alloc_env(const char* varName, const char* varValue) {
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
inline char* const* __darwintrace_restore_env(char* const envp[]) {
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

	*theCopyIter = 0;
	
	return theCopy;
}

static void ask_for_filemap()
{
	filemap=exchange_with_port("filemap\t", sizeof("filemap\t"), 1, 0);
	if(filemap==(char*)-1)
		filemap=0;
}

__attribute__((always_inline))
inline void __darwintrace_setup() {
#define open(x,y,z) syscall(SYS_open, (x), (y), (z))
#define close(x) syscall(SYS_close, (x))
	if (__darwintrace_fd == -1) {
		if (__env_darwintrace_log != NULL) {
			int olderrno = errno;
			int sock=socket(AF_UNIX, SOCK_STREAM, 0);
			struct sockaddr_un sun;
			sun.sun_family=AF_UNIX;
			strncpy(sun.sun_path, __env_darwintrace_log, sizeof(sun.sun_path));
			if(connect(sock, (struct sockaddr*)&sun, strlen(__env_darwintrace_log)+1+sizeof(sun.sun_family))!=-1)
			{
				debug_printf("darwintrace: connect successful. socket %d\n", sock);
				__darwintrace_fd=sock;
				ask_for_filemap();
			} else {
				debug_printf("connect failed: %s\n", strerror(errno));
				abort();
			}
			errno = olderrno;
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
inline void __darwintrace_log_op(const char* op, const char* path, int fd) {
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

	size = snprintf(logbuffer, sizeof(logbuffer),
		"%s\t%s",
		op, somepath );

	exchange_with_port(logbuffer, size+1, 0, 0);
	
	return;
}

/* remap resource fork access to the data fork.
 * do a partial realpath(3) to fix "foo//bar" to "foo/bar"
 */
inline void __darwintrace_cleanup_path(char *path) {
  size_t pathlen;
#ifdef __APPLE__
  size_t rsrclen;
#endif
  size_t i, shiftamount;
  enum { SAWSLASH, NOTHING } state = NOTHING;

  /* if this is a foo/..namedfork/rsrc, strip it off */
  pathlen = strlen(path);
  /* ..namedfork/rsrc is only on OS X */
#ifdef __APPLE__ 
  rsrclen = strlen(_PATH_RSRCFORKSPEC);
  if(pathlen > rsrclen
     && 0 == strcmp(path + pathlen - rsrclen,
		    _PATH_RSRCFORKSPEC)) {
    path[pathlen - rsrclen] = '\0';
    pathlen -= rsrclen;
  }
#endif

  /* for each position in string (including
     terminal \0), check if we're in a run of
     multiple slashes, and only emit the
     first one
  */
  for(i=0, shiftamount=0; i <= pathlen; i++) {
    if(state == SAWSLASH) {
      if(path[i] == '/') {
	/* consume it */
	shiftamount++;
      } else {
	state = NOTHING;
	path[i - shiftamount] = path[i];
      }
    } else {
      if(path[i] == '/') {
	state = SAWSLASH;
      }
      path[i - shiftamount] = path[i];
    }
  }

  debug_printf("darwintrace: cleanup resulted in %s\n", path);
}

/*
 * return 1 if path is directory or not exists
 * return 0 otherwise
 */
static int is_directory(const char * path)
{
#define stat(path, sb) syscall(SYS_stat, path, sb)
	struct stat s;
	if(stat(path, &s)==-1)
		/* Actually is not directory, but anyway, we shouldn't test a dependency unless file exists */
		return 1;
	
	return S_ISDIR(s.st_mode);
#undef stat
}


/*
 * return 1 if path allowed, 0 otherwise
 */
static int ask_for_dependency(char * path)
{
	char buffer[BUFFER_SIZE], *p;
	int result=0;
	
	if(is_directory(path))
		return 1;
	
	strncpy(buffer, "dep_check\t", sizeof(buffer));
	strncpy(buffer+10, path, sizeof(buffer)-10);
	p=exchange_with_port(buffer, strlen(buffer)+1, 1, 0);
	if(p==(char*)-1||!p)
		return 0;
	
	if(*p=='+')
		result=1;
	
	free(p);
	return result;
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
static char * exchange_with_port(const char * buf, size_t len, int answer, char failures)
{
	wait_for_socket(__darwintrace_fd, 1);
	if(send(__darwintrace_fd, buf, len, 0)==-1)
	{
		if(errno==ENOTSOCK && failures<3)
		{
			__darwintrace_fd=-1;
			__darwintrace_setup();
			return exchange_with_port(buf, len, answer, failures+1);
		}
		return (char*)-1;
	}
	if(!answer)
		return 0;
	{
		size_t l=0;
		char * b;
		
		wait_for_socket(__darwintrace_fd, 0);
		recv(__darwintrace_fd, &l, sizeof(l),0);
		if(!l)
			return 0;
		b=(char*)malloc(l+1);
		b[l]=0;
		recv(__darwintrace_fd, b, l, 0);
		return b;
	}
}

/*
 * return 1 if path (once normalized) is in sandbox or redirected, 0 otherwise.
 */
__attribute__((always_inline))
inline int __darwintrace_is_in_sandbox(const char* path, char * newpath) {
	char * t, * p, * _;
	int result=-1;
	
	__darwintrace_setup();
	
	if(!filemap)
		return 1;
	
	if(*path=='/')
		p=strdup(path);
	else
	{
		p=(char*)malloc(MAXPATHLEN);
		if (getcwd(p, MAXPATHLEN-1) == NULL) {
			fprintf(stderr, "darwintrace: getcwd: %s, path was: %s\n", strerror(errno), path);
			abort();
		}
		if (p[strlen(p)-1] != '/')
			strcat(p, "/");
		strcat(p, path);
	}
	__darwintrace_cleanup_path(p);
			
	do
	{
		for(t=filemap; *t;)
		{
			if(__darwintrace_strbeginswith(p, t))
			{
				t+=strlen(t)+1;
				switch(*t)
				{
				case 0:
					result=1;
					break;
				case 1:
					if(!newpath)
					{
						result=0;
						break;
					}
					strcpy(newpath, t+1);
					_=newpath+strlen(newpath);
					if(_[-1]!='/')
						*_++='/';
					strcpy(_, p);
					result=1;
					break;
				case 2:
					result=ask_for_dependency(p);
					break;
				}
			}
			if(result!=-1)
				break;
			t+=strlen(t)+1;
			if(*t==1)
				t+=strlen(t)+1;
			else
				t+=2;
		}
		if(result!=-1)
			break;
		__darwintrace_log_op("sandbox_violation", path, 0);
		result=0;
	}
	while(0);
	free(p);
	return result;
}

/* Log calls to open(2) into the file specified by DARWINTRACE_LOG.
   Only logs if the DARWINTRACE_LOG environment variable is set.
   Only logs files (or rather, do not logs directories)
   Only logs files where the open succeeds.
   Only logs files opened for read access, without the O_CREAT flag set
   	(unless DARWINTRACE_LOG_CREATE is set).
   The assumption is that any file that can be created isn't necessary
   to build the project.
*/

int open(const char* path, int flags, ...) {
#define open(x,y,z) syscall(SYS_open, (x), (y), (z))
	mode_t mode;
	int result;
	va_list args;
	struct stat sb;
	char newpath[MAXPATHLEN];
	int isInSandbox;	

	/* Why mode here ? */
	va_start(args, flags);
	mode = va_arg(args, int);
	va_end(args);
	
	result = 0;
	
	if((stat(path, &sb)!=-1 && !(sb.st_mode&S_IFDIR)) || flags & O_CREAT )
	{
		*newpath=0;
		__darwintrace_setup();
		isInSandbox = __darwintrace_is_in_sandbox(path, newpath);
		if (isInSandbox == 0) {
			debug_printf("darwintrace: creation/writing was forbidden at %s\n", path);
			errno = EACCES;
			result = -1;
		}
		if(*newpath)
			path=newpath;
	}
	if (result == 0) {
		result = open(path, flags, mode);
	}
	return result;
#undef open
}

/* Log calls to readlink(2) into the file specified by DARWINTRACE_LOG.
   Only logs if the DARWINTRACE_LOG environment variable is set.
   Only logs files where the readlink succeeds.
*/
#ifdef READLINK_IS_NOT_P1003_1A
int  readlink(const char * path, char * buf, int bufsiz) {
#else
ssize_t  readlink(const char * path, char * buf, size_t bufsiz) {
#endif
#define readlink(x,y,z) syscall(SYS_readlink, (x), (y), (z))
	ssize_t result;
	int isInSandbox;

	result = readlink(path, buf, bufsiz);
	if (result >= 0) {
		__darwintrace_setup();
		isInSandbox = __darwintrace_is_in_sandbox(path, 0);
		if (!isInSandbox)
		{
			errno=EACCES;
			result=-1;
		}
	}
	return result;
#undef readlink
}

int execve(const char* path, char* const argv[], char* const envp[]) {
#define __execve(x,y,z) syscall(SYS_execve, (x), (y), (z))
#define open(x,y,z) syscall(SYS_open, (x), (y), (z))
#define close(x) syscall(SYS_close, (x))
#define lstat(x, y) syscall(SYS_lstat, (x), (y))
	int result;
	__darwintrace_setup();
	if (__darwintrace_fd >= 0) {
	  struct stat sb;
	  /* for symlinks, we want to capture
	   * both the original path and the modified one,
	   * since for /usr/bin/gcc -> gcc-4.0,
	   * both "gcc_select" and "gcc" are contributors
	   */
	  if (lstat(path, &sb) == 0) {
	  	int fd;

	    if(S_ISLNK(sb.st_mode)) {
	      /* for symlinks, print both */
		  __darwintrace_log_op("execve", path, 0);
	    }
		
		fd = open(path, O_RDONLY, 0);
		if (fd > 0) {
		  char buffer[MAXPATHLEN+1], newpath[MAXPATHLEN+1];
		  ssize_t bytes_read;
		
		  *newpath=0;
		  if(__darwintrace_is_in_sandbox(path, newpath)==0)
		  {
			close(fd);
			errno=ENOENT;
		    return -1;
		  }
		  if(*newpath)
		    path=newpath;
	
		  /* once we have an open fd, if a full path was requested, do it */
		  __darwintrace_log_op("execve", path, fd);

		  /* read the file for the interpreter */
		  bytes_read = read(fd, buffer, MAXPATHLEN);
		  buffer[bytes_read] = 0;
		  if (bytes_read > 2 &&
			buffer[0] == '#' && buffer[1] == '!') {
			const char* interp = &buffer[2];
			int i;
			/* skip past leading whitespace */
			for (i = 2; i < bytes_read; ++i) {
			  if (buffer[i] != ' ' && buffer[i] != '\t') {
				interp = &buffer[i];
				break;
			  }
			}
			/* found interpreter (or ran out of data)
			   skip until next whitespace, then terminate the string */
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
	close(__darwintrace_fd);
	__darwintrace_fd=-1;
	}
	
	/* call the original execve function, but fix the environment if required. */
	result = __execve(path, argv, __darwintrace_restore_env(envp));
	return result;
#undef lstat
#undef close
#undef open
#undef execve
}

/* if darwintrace has been initialized, trap
   attempts to close our file descriptor
*/
int close(int fd) {
#define close(x) syscall(SYS_close, (x))

  if(__darwintrace_fd != -2 && fd == __darwintrace_fd) {
    errno = EBADF;
    return -1;
  }

  return close(fd);
#undef close
}

/* Trap attempts to unlink a file outside the sandbox.
 */
int unlink(const char* path) {
#define __unlink(x) syscall(SYS_unlink, (x))
	int result = 0;
	int isInSandbox = __darwintrace_is_in_sandbox(path, 0);
	if (isInSandbox == 1) {
		debug_printf("darwintrace: unlink was allowed at %s\n", path);
	} else if (isInSandbox == 0) {
		/* outside sandbox, but sandbox is defined: forbid */
		debug_printf("darwintrace: unlink was forbidden at %s\n", path);
		errno = EACCES;
		result = -1;
	}
	
	if (result == 0) {
		result = __unlink(path);
	}
	
	return result;
}

/* Trap attempts to create directories outside the sandbox.
 */
int mkdir(const char* path, mode_t mode) {
#define __mkdir(x,y) syscall(SYS_mkdir, (x), (y))
	int result = 0;
	int isInSandbox = __darwintrace_is_in_sandbox(path, 0);
	if (isInSandbox == 1) {
		debug_printf("darwintrace: mkdir was allowed at %s\n", path);
	} else if (isInSandbox == 0) {
		/* outside sandbox, but sandbox is defined: forbid */
		/* only consider directories that do not exist. */
		struct stat theInfo;
		int err;
		err = lstat(path, &theInfo);
		if ((err == -1) && (errno == ENOENT))
		{
			debug_printf("darwintrace: mkdir was forbidden at %s\n", path);
			errno = EACCES;
			result = -1;
		} /* otherwise, mkdir will do nothing (directory exists) or fail
		     (another error) */
	}
	
	if (result == 0) {
		result = __mkdir(path, mode);
	}
	
	return result;
}

/* Trap attempts to remove directories outside the sandbox.
 */
int rmdir(const char* path) {
#define __rmdir(x) syscall(SYS_rmdir, (x))
	int result = 0;
	int isInSandbox = __darwintrace_is_in_sandbox(path, 0);
	if (isInSandbox == 1) {
		debug_printf("darwintrace: rmdir was allowed at %s\n", path);
	} else if (isInSandbox == 0) {
		/* outside sandbox, but sandbox is defined: forbid */
		debug_printf("darwintrace: removing directory %s was forbidden\n", path);
		errno = EACCES;
		result = -1;
	}
	
	if (result == 0) {
		result = __rmdir(path);
	}
	
	return result;
}

/* Trap attempts to rename files/directories outside the sandbox.
 */
int rename(const char* from, const char* to) {
#define __rename(x,y) syscall(SYS_rename, (x), (y))
	int result = 0;
	int isInSandbox = __darwintrace_is_in_sandbox(from, 0);
	if (isInSandbox == 1) {
		debug_printf("darwintrace: rename was allowed at %s\n", from);
	} else if (isInSandbox == 0) {
		/* outside sandbox, but sandbox is defined: forbid */
		debug_printf("darwintrace: renaming from %s was forbidden\n", from);
		errno = EACCES;
		result = -1;
	}

	if (result == 0) {
		isInSandbox = __darwintrace_is_in_sandbox(to, 0);
		if (isInSandbox == 1) {
			debug_printf("darwintrace: rename was allowed at %s\n", to);
		} else if (isInSandbox == 0) {
			/* outside sandbox, but sandbox is defined: forbid */
			debug_printf("darwintrace: renaming to %s was forbidden\n", to);
			errno = EACCES;
			result = -1;
		}
	}
	
	if (result == 0) {
		result = __rename(from, to);
	}
	
	return result;
}

int stat(const char * path, struct stat * sb)
{
#define stat(path, sb) syscall(SYS_stat, path, sb)
	int result=0;
	char newpath[260];
		
	*newpath=0;
	if(!is_directory(path)&&__darwintrace_is_in_sandbox(path, newpath)==0)
	{
		errno=ENOENT;
		result=-1;
	}else
	{
		if(*newpath)
			path=newpath;
			
		result=stat(path, sb);
	}
	
	return result;
#undef stat
}

#if defined(__DARWIN_64_BIT_INO_T) && !defined(_DARWIN_FEATURE_ONLY_64_BIT_INODE)

int stat64(const char * path, struct stat64 * sb)
{
#define stat64(path, sb) syscall(SYS_stat64, path, sb)
	int result=0;
	char newpath[260];
		
	*newpath=0;
	if(!is_directory(path)&&__darwintrace_is_in_sandbox(path, newpath)==0)
	{
		errno=ENOENT;
		result=-1;
	}else
	{
		if(*newpath)
			path=newpath;
			
		result=stat64(path, sb);
	}
	
	return result;
#undef stat64
}

int stat$INODE64(const char * path, struct stat64 * sb)
{
    return stat64(path, sb);
}

#endif /* defined(__DARWIN_64_BIT_INO_T) && !defined(_DARWIN_FEATURE_ONLY_64_BIT_INODE) */


int lstat(const char * path, struct stat * sb)
{
#define lstat(path, sb) syscall(SYS_lstat, path, sb)
	int result=0;
	char newpath[260];
	
	*newpath=0;
	if(!is_directory(path)&&__darwintrace_is_in_sandbox(path, newpath)==0)
	{
		errno=ENOENT;
		result=-1;
	}else
	{
		if(*newpath)
			path=newpath;
			
		result=lstat(path, sb);
	}
	
	return result;
#undef lstat
}

#if defined(__DARWIN_64_BIT_INO_T) && !defined(_DARWIN_FEATURE_ONLY_64_BIT_INODE)

int lstat64(const char * path, struct stat64 * sb)
{
#define lstat64(path, sb) syscall(SYS_lstat64, path, sb)
	int result=0;
	char newpath[260];
	
	*newpath=0;
	if(!is_directory(path)&&__darwintrace_is_in_sandbox(path, newpath)==0)
	{
		errno=ENOENT;
		result=-1;
	}else
	{
		if(*newpath)
			path=newpath;
			
		result=lstat64(path, sb);
	}
	
	return result;
#undef lstat64
}

int lstat$INODE64(const char * path, struct stat64 * sb)
{
    return lstat64(path, sb);
}

#endif /* defined(__DARWIN_64_BIT_INO_T) && !defined(_DARWIN_FEATURE_ONLY_64_BIT_INODE) */
