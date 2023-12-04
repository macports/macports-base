#define DARWINTRACE_USE_PRIVATE_API
#include "../darwintrace.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char* argv[]) {
	(void) argc;
	(void) argv;

	__darwintrace_setup();

	// close non-dt socket
	close(255);

	FILE *stream = __darwintrace_sock();
	if (stream == NULL) {
		fprintf(stderr, "__darwintrace_sock() returned NULL\n");
		exit(EXIT_FAILURE);
	}

	int fd = fileno(stream);
	if (-1 == close(fd)) {
		fprintf(stderr, "close(%d): %s\n", fd, strerror(errno));
	}

	__darwintrace_initialized = false;
	if (-1 == close(fd)) {
		fprintf(stderr, "uninitialized close(%d): %s\n", fd, strerror(errno));
		exit(EXIT_FAILURE);
	}

	exit(EXIT_SUCCESS);
}
