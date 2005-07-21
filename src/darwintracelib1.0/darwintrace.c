#include <crt_externs.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <stdio.h>
#include <sys/syscall.h>

int __darwintrace_fd = -2;
#define BUFFER_SIZE	1024
char __darwintrace_buf[BUFFER_SIZE];

/* Log calls to open(2) into the file specified by DARWINTRACE_LOG.
   Only logs if the DARWINTRACE_LOG environment variable is set.
   Only logs files where the open succeeds.
   Only logs files opened for read access, without the O_CREAT flag set.
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
	if (result >= 0 && (flags & (O_CREAT | O_WRONLY /*O_RDWR*/)) == 0 ) {
		if (__darwintrace_fd == -2) {
		  char* path = getenv("DARWINTRACE_LOG");
		  if (path != NULL) {
			__darwintrace_fd = open(path,
			O_CREAT | O_WRONLY | O_APPEND,
			0666);
			fcntl(__darwintrace_fd, F_SETFD, 1); /* close-on-exec */
		  }
		}
		if (__darwintrace_fd >= 0) {
		  int size = snprintf(__darwintrace_buf, BUFFER_SIZE, "open\t%s\n", path );
		  write(__darwintrace_fd, __darwintrace_buf, size);
		  fsync(__darwintrace_fd);
		}
	}
	return result;
}

int execve(const char* path, char* const argv[], char* const envp[]) {
#define execve(x,y,z) syscall(SYS_execve, (x), (y), (z))
	int result;
	
	if (__darwintrace_fd == -2) {
	  char* path = getenv("DARWINTRACE_LOG");
	  if (path != NULL) {
		__darwintrace_fd = open(path,
		O_CREAT | O_WRONLY | O_APPEND,
		0666);
		fcntl(__darwintrace_fd, F_SETFD, 1); /* close-on-exec */
	  }
	}
	if (__darwintrace_fd >= 0) {
	  struct stat sb;
	  if (stat(path, &sb) == 0) {
		int size = snprintf(__darwintrace_buf, BUFFER_SIZE, "execve\t%s\n", path );
		write(__darwintrace_fd, __darwintrace_buf, size);
		fsync(__darwintrace_fd);
	  }
	}
	result = execve(path, argv, envp);
	return result;
}
