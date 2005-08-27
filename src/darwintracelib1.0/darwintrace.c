/*
 * Copyright (c) 2005 Apple Computer, Inc. All rights reserved.
 * $Id: darwintrace.c,v 1.7 2005/08/27 00:07:27 pguyot Exp $
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

#include <crt_externs.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/syscall.h>

/*
 * Compile time options:
 * DARWINTRACE_SHOW_PROCESS: show the process id of every access
 * DARWINTRACE_LOG_CREATE: log creation of files as well.
 */

/*
 * Prototypes.
 */
void log_op(const char* op, const char* path, int fd);
void __darwintrace_setup();

int __darwintrace_fd = -2;
#define BUFFER_SIZE	1024
char __darwintrace_buf[BUFFER_SIZE];
#if DARWINTRACE_SHOW_PROCESS
char __darwintrace_progname[BUFFER_SIZE];
pid_t __darwintrace_pid = -1;
#endif

inline void __darwintrace_setup() {
#define open(x,y,z) syscall(SYS_open, (x), (y), (z))
	if (__darwintrace_fd == -2) {
	  char* path = getenv("DARWINTRACE_LOG");
	  if (path != NULL) {
		__darwintrace_fd = open(path,
		O_CREAT | O_WRONLY | O_APPEND,
		0666);
		fcntl(__darwintrace_fd, F_SETFD, 1); /* close-on-exec */
	  }
	}
#if DARWINTRACE_SHOW_PROCESS
	if (__darwintrace_pid == -1) {
		__darwintrace_pid = getpid();
		char** progname = _NSGetProgname();
		if (progname && *progname) {
			strcpy(__darwintrace_progname, *progname);
		}
	}
#endif
#undef open
}

/* log a call and optionally get the real path from the fd if it's not 0.
 */
void log_op(const char* op, const char* path, int fd) {
	int size;
	char somepath[MAXPATHLEN];
	if((fd > 0) && (strncmp(path, "/.vol/", 6) == 0)) {
		if(0 == fcntl(fd, F_GETPATH, somepath)) {
#if DARWINTRACE_SHOW_PROCESS
			size = snprintf(__darwintrace_buf, BUFFER_SIZE, "%s[%d]\t%s\t%s\n", __darwintrace_progname, __darwintrace_pid, op, somepath );
			/* printf("resolved %s to %s\n", path, realpath); */
#else
	  		size = snprintf(__darwintrace_buf, BUFFER_SIZE, "%s\t%s\n", op, somepath );
#endif
		} else {
			/* if we can't resolve it, ignore the volfs path */
			size = 0;
		}
	} else {
		/* append cwd to the path if required */
		if (path[0] != '/') {
			(void) getcwd(somepath, sizeof(somepath));
#if DARWINTRACE_SHOW_PROCESS
			size = snprintf(__darwintrace_buf,
						BUFFER_SIZE, "%s[%d]\t%s\t%s/%s\n",
						__darwintrace_progname, __darwintrace_pid,
						op, somepath, path );
#else
			size = snprintf(__darwintrace_buf,
						BUFFER_SIZE, "%s\t%s/%s\n", op, somepath, path );
#endif
		} else {
#if DARWINTRACE_SHOW_PROCESS
			size = snprintf(__darwintrace_buf,
						BUFFER_SIZE, "%s[%d]\t%s\t%s\n",
						__darwintrace_progname, __darwintrace_pid,
						op, path );
#else
			size = snprintf(__darwintrace_buf,
						BUFFER_SIZE, "%s\t%s\n", op, path );
#endif
		}
	}
	write(__darwintrace_fd, __darwintrace_buf, size);
	fsync(__darwintrace_fd);
}

/* Log calls to open(2) into the file specified by DARWINTRACE_LOG.
   Only logs if the DARWINTRACE_LOG environment variable is set.
   Only logs files (or rather, do not logs directories)
   Only logs files where the open succeeds.
   Only logs files opened for read access, without the O_CREAT flag set
   	(except if DARWINTRACE_LOG_CREATE is set).
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
	result = open(path, flags, mode);
	if (result >= 0) {
		/* check that it's a file */
		struct stat sb;
		fstat(result, &sb);
		if ((sb.st_mode & S_IFDIR) == 0) {
			if ((flags & (O_CREAT | O_WRONLY /*O_RDWR*/)) == 0 ) {
				__darwintrace_setup();
				if (__darwintrace_fd >= 0) {
					log_op("open", path, result);
				}
#if DARWINTRACE_LOG_CREATE
			} else if (flags & O_CREAT) {
				__darwintrace_setup();
				if (__darwintrace_fd >= 0) {
					log_op("create", path, result);
				}
#endif
			}
		}
	}
	return result;
#undef open
}

int execve(const char* path, char* const argv[], char* const envp[]) {
#define execve(x,y,z) syscall(SYS_execve, (x), (y), (z))
	int result;
	
	__darwintrace_setup();
	if (__darwintrace_fd >= 0) {
	  struct stat sb;
	  if (stat(path, &sb) == 0) {
	  	int fd;
	  	
		log_op("execve", path, 0);
		
		fd = open(path, O_RDONLY, 0);
		if (fd != -1) {
			char buffer[MAXPATHLEN];
			(void) read(fd, buffer, MAXPATHLEN);
			if (buffer[0] == '#' && buffer[1] == '!') {
				const char* interp = &buffer[2];
				int i;
				/* skip past leading whitespace */
				for (i = 2; i < (MAXPATHLEN-1); ++i) {
					if (buffer[i] != ' ' && buffer[i] != '\t') {
						interp = &buffer[i];
						break;
					}
				}
				/* found interpreter (or ran out of data)
				 skip until next whitespace, then terminate the string */
				for (; i < (MAXPATHLEN-1); ++i) {
					if (buffer[i] == ' ' || buffer[i] == '\t' || buffer[i] == '\n') {
						buffer[i] = 0;
					}
				}
				/* we have liftoff */
				if (interp) {
					log_op("execve", interp, 0);
				}
			}
			close(fd);
		}
	  }
	}
	
	result = execve(path, argv, envp);
	if (__darwintrace_fd >= 0) {
	  /* Here, execve failed.
	  
	     I noticed that darwin 8.2.0 closes the file.
	  
	     I suspect the usefulness of the close-on-exec flag is to close files
	     that are required to remain open if execve failed and therefore, the
	     system should not close them should execve fail.
	     
	     I cannot access the SUSv2 standard right now, so I cannot tell if
	     this is a bug in darwin 8.2.0 or not. AFAICT, BSD man pages are
	     ambiguous and so are Solaris man pages.
	     
	     In case the ambiguous behavior changes, I (try to) close the file
	     anyway */
	  close(__darwintrace_fd);
	  /* and of course, the fd should be reset to -2 to reopen it next time the
	     process tries to call one of the functions we use to trace open files
	     */
	  __darwintrace_fd = -2;
	}
	return result;
}
