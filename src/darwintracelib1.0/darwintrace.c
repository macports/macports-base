/*
 * Copyright (c) 2005 Apple Computer, Inc. All rights reserved.
 * Copyright (c) 2005-2006 Paul Guyot <pguyot@kallisys.net>,
 * All rights reserved.
 *
 * $Id: darwintrace.c,v 1.16.2.2 2006/07/29 06:45:01 pguyot Exp $
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
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
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
inline void __darwintrace_log_op(const char* op, const char* procname, const char* path, int fd);
inline void __darwintrace_setup();
inline void __darwintrace_cleanup_path(char *path);

#define START_FD 81
static int __darwintrace_fd = -2;
#define BUFFER_SIZE	1024
#if DARWINTRACE_SHOW_PROCESS
static char __darwintrace_progname[BUFFER_SIZE];
static pid_t __darwintrace_pid = -1;
#endif
#if DARWINTRACE_SANDBOX
static char** __darwintrace_sandbox_bounds = NULL;
#endif

#if __STDC_VERSION__==199901L
#if DARWINTRACE_DEBUG_OUTPUT
#define dprintf(...) fprintf(stderr, __VA_ARGS__)
#else
#define dprintf(...)
#endif
#else
#if DARWINTRACE_DEBUG_OUTPUT
#define dprintf(format, param) fprintf(stderr, format, param)
#else
#define dprintf(format, param)
#endif
#endif

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

inline void __darwintrace_setup() {
#define open(x,y,z) syscall(SYS_open, (x), (y), (z))
#define close(x) syscall(SYS_close, (x))
	if (__darwintrace_fd == -2) {
		char* path = getenv("DARWINTRACE_LOG");
		if (path != NULL) {
			int olderrno = errno;
			int fd = open(path, O_CREAT | O_WRONLY | O_APPEND, DEFFILEMODE);
			int newfd;
			for(newfd = START_FD; newfd < START_FD + 21; newfd++) {
				if(-1 == write(newfd, "", 0) && errno == EBADF) {
					if(-1 != dup2(fd, newfd)) {
						__darwintrace_fd = newfd;
					}
					close(fd);
					fcntl(__darwintrace_fd, F_SETFD, 1); /* close-on-exec */
					break;
				}
			}
			errno = olderrno;
		}
	}
#if DARWINTRACE_SHOW_PROCESS
	if (__darwintrace_pid == -1) {
		char** progname = _NSGetProgname();
		__darwintrace_pid = getpid();
		if (progname && *progname) {
			strcpy(__darwintrace_progname, *progname);
		}
	}
#endif
#if DARWINTRACE_SANDBOX
	if (__darwintrace_sandbox_bounds == NULL) {
		char* paths = getenv("DARWINTRACE_SANDBOX_BOUNDS");
		if (paths != NULL) {
			/* copy the string */
			char* copy = strdup(paths);
			if (copy != NULL) {
				int nbPaths = 1;
				int nbAllocatedPaths = 5;
				char** paths = (char**) malloc(sizeof(char*) * nbAllocatedPaths);
				char* crsr = copy;
				char** pathsCrsr = paths;
				/* first path */
				*pathsCrsr++ = crsr;
				/* parse the paths (modify the copy) */
				do {
					char theChar = *crsr;
					if (theChar == '\0') {
						/* the end of the paths */
						break;
					}
					if (theChar == ':') {
						/* the end of this path */
						*crsr = 0;
						nbPaths++;
						if (nbPaths == nbAllocatedPaths) {
							nbAllocatedPaths += 5;
							paths = (char**) realloc(paths, sizeof(char*) * nbAllocatedPaths);
							/* reset the cursor in case paths pointer was moved */
							pathsCrsr = paths + (nbPaths - 1);
						}
						*pathsCrsr++ = crsr + 1;
					}
					if (theChar == '\\') {
						/* escape character. test next char */
						char nextChar = crsr[1];
						if (nextChar == '\\') {
							/* rewrite the string */
							char* rewriteCrsr = crsr + 1;
							do {
								char theChar = *rewriteCrsr;
								rewriteCrsr[-1] = theChar;
								rewriteCrsr++;
							} while (theChar != 0);
						} else if (nextChar == ':') {
							crsr++;
						}
						/* otherwise, ignore (keep the backslash) */
					}
					
					/* next char */
					crsr++;
				} while (1);
				/* null terminate the array */
				*pathsCrsr = 0;
				/* resize and save it */
				__darwintrace_sandbox_bounds = (char**) realloc(paths, sizeof(char*) * (nbPaths + 1));
			}
		}
	}
#endif
#undef close
#undef open
}

/* log a call and optionally get the real path from the fd if it's not 0.
 * op:			the operation (open, readlink, execve)
 * procname:	the name of the process (can be NULL)
 * path:		the path of the file
 * fd:			a fd to the file, or 0 if we don't have any.
 */
inline void __darwintrace_log_op(const char* op, const char* procname, const char* path, int fd) {
#if !DARWINTRACE_SHOW_PROCESS
	#pragma unused(procname)
#endif
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
#if DARWINTRACE_SHOW_PROCESS
		"%s[%d]\t"
#endif
		"%s\t%s\n",
#if DARWINTRACE_SHOW_PROCESS
		procname ? procname : __darwintrace_progname, __darwintrace_pid,
#endif
		op, somepath );

	write(__darwintrace_fd, logbuffer, size);
	fsync(__darwintrace_fd);
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

  dprintf("darwintrace: cleanup resulted in %s\n", path);
}

#if DARWINTRACE_SANDBOX
/*
 * return 1 if path (once normalized) is in sandbox, 0 otherwise.
 * return -1 if no sandbox is defined or if the path couldn't be normalized.
 */
inline int __darwintrace_is_in_sandbox(const char* path) {
	int result = -1; /* no sandbox is defined */
	__darwintrace_setup();
	if (__darwintrace_sandbox_bounds != NULL) {
		/* check the path */
		char** basePathsCrsr = __darwintrace_sandbox_bounds;
		char* basepath = *basePathsCrsr++;
		/* normalize the path */
		char createpath[MAXPATHLEN];
		if (realpath(path, createpath) != NULL) {
			__darwintrace_cleanup_path(createpath);
			/* say it's outside unless it's proved inside */
			result = 0;
			while (basepath != NULL) {
				if (__darwintrace_strbeginswith(createpath, basepath)) {
					result = 1;
					break;
				}
				basepath = *basePathsCrsr++;;
			}
		} /* otherwise, operation will fail anyway */
	}
	return result;
}
#endif

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

	va_start(args, flags);
	mode = va_arg(args, int);
	va_end(args);
#if DARWINTRACE_SANDBOX
	result = 0;
	if (flags & (O_CREAT | O_APPEND | O_RDWR | O_WRONLY | O_TRUNC)) {
		int isInSandbox = __darwintrace_is_in_sandbox(path);
		if (isInSandbox == 1) {
			dprintf("darwintrace: creation/writing was allowed at %s\n", path);
		} else if (isInSandbox == 0) {
			/* outside sandbox, but sandbox is defined: forbid */
			dprintf("darwintrace: creation/writing was forbidden at %s\n", path);
			__darwintrace_log_op("sandbox_violation", NULL, path, 0);
			errno = EACCES;
			result = -1;
		}
	}
	if (result == 0) {
		result = open(path, flags, mode);
	}
#else
	result = open(path, flags, mode);
#endif
	if (result >= 0) {
		/* check that it's a file */
		struct stat sb;
		fstat(result, &sb);
		if ((sb.st_mode & S_IFDIR) == 0) {
			if ((flags & (O_CREAT | O_WRONLY /*O_RDWR*/)) == 0 ) {
				__darwintrace_setup();
				if (__darwintrace_fd >= 0) {
				    dprintf("darwintrace: original open path is %s\n", path);
					__darwintrace_log_op("open", NULL, path, result);
				}
#if DARWINTRACE_LOG_CREATE
			} else if (flags & O_CREAT) {
				__darwintrace_setup();
				if (__darwintrace_fd >= 0) {
				    dprintf("darwintrace: original create path is %s\n", path);
					__darwintrace_log_op("create", NULL, path, result);
				}
#endif
			}
		}
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

	result = readlink(path, buf, bufsiz);
	if (result >= 0) {
	  __darwintrace_setup();
	  if (__darwintrace_fd >= 0) {
	    dprintf("darwintrace: original readlink path is %s\n", path);
		__darwintrace_log_op("readlink", NULL, path, 0);
	  }
	}
	return result;
#undef readlink
}

int execve(const char* path, char* const argv[], char* const envp[]) {
#define execve(x,y,z) syscall(SYS_execve, (x), (y), (z))
#define open(x,y,z) syscall(SYS_open, (x), (y), (z))
#define close(x) syscall(SYS_close, (x))
	int result;
#if DARWINTRACE_SHOW_PROCESS
	int saved_pid;
#endif
	__darwintrace_setup();
	if (__darwintrace_fd >= 0) {
	  struct stat sb;
	  /* for symlinks, we wan't to capture
	   * both the original path and the modified one,
	   * since for /usr/bin/gcc -> gcc-4.0,
	   * both "gcc_select" and "gcc" are contributors
	   */
	  if (lstat(path, &sb) == 0) {
	  	int fd;

	    if(S_ISLNK(sb.st_mode)) {
	      /* for symlinks, print both */
		  __darwintrace_log_op("execve", NULL, path, 0);
	    }
		
		fd = open(path, O_RDONLY, 0);
		if (fd > 0) {
		  char buffer[MAXPATHLEN+1];
		  ssize_t bytes_read;
	
		  /* once we have an open fd, if a full path was requested, do it */
		  __darwintrace_log_op("execve", NULL, path, fd);

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
			  const char* procname = NULL;
#if DARWINTRACE_SHOW_PROCESS
			  procname = strrchr(argv[0], '/') + 1;
			  if (procname == NULL) {
				procname = argv[0];
			  }
#endif
			  __darwintrace_log_op("execve", procname, interp, 0);
			}
		  }
		  close(fd);
		}
	  }
	}
	
	result = execve(path, argv, envp);
	return result;
#undef close
#undef open
#undef execve
}

/* if darwintrace has  been initialized, trap
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

#if DARWINTRACE_SANDBOX
/* Trap attempts to unlink a file outside the sandbox.
 */
int unlink(const char* path) {
#define __unlink(x) syscall(SYS_unlink, (x))
	int result = 0;
	int isInSandbox = __darwintrace_is_in_sandbox(path);
	if (isInSandbox == 1) {
		dprintf("darwintrace: unlink was allowed at %s\n", path);
	} else if (isInSandbox == 0) {
		/* outside sandbox, but sandbox is defined: forbid */
		dprintf("darwintrace: unlink was forbidden at %s\n", path);
		__darwintrace_log_op("sandbox_violation", NULL, path, 0);
		errno = EACCES;
		result = -1;
	}
	
	if (result == 0) {
		result = __unlink(path);
	}
	
	return result;
}
#endif

#if DARWINTRACE_SANDBOX
/* Trap attempts to create directories outside the sandbox.
 */
int mkdir(const char* path, mode_t mode) {
#define __mkdir(x,y) syscall(SYS_mkdir, (x), (y))
	int result = 0;
	int isInSandbox = __darwintrace_is_in_sandbox(path);
	if (isInSandbox == 1) {
		dprintf("darwintrace: mkdir was allowed at %s\n", path);
	} else if (isInSandbox == 0) {
		/* outside sandbox, but sandbox is defined: forbid */
		/* only consider directories that do not exist. */
		struct stat theInfo;
		int err;
		err = lstat(path, &theInfo);
		if ((err == -1) && (errno == ENOENT))
		{
			dprintf("darwintrace: mkdir was forbidden at %s\n", path);
			__darwintrace_log_op("sandbox_violation", NULL, path, 0);
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
#endif
