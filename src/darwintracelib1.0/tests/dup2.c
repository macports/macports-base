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

	// dup2 non-dt socket
	if (-1 == dup2(STDOUT_FILENO, 255)) {
		fprintf(stderr, "dup2(STDOUT_FILENO, 255): %s\n", strerror(errno));
	}

	FILE *stream = __darwintrace_sock();
	if (stream == NULL) {
		fprintf(stderr, "__darwintrace_sock() returned NULL\n");
		exit(EXIT_FAILURE);
	}

	int fd = fileno(stream);
	if (-1 == dup2(STDOUT_FILENO, fd)) {
		fprintf(stderr, "dup2(STDOUT_FILENO, %d): %s\n", fd, strerror(errno));
		exit(EXIT_FAILURE);
	}

	FILE *newstream = __darwintrace_sock();
	if (newstream == NULL) {
		fprintf(stderr, "__darwintrace_sock() returned NULL after dup2(2)\n");
		exit(EXIT_FAILURE);
	}
	int newfd = fileno(newstream);

	if (fd == newfd) {
		fprintf(stderr, "__darwintrace_sock() fd did not change from %d, even though we dup(2)'d over it\n", fd);
		exit(EXIT_FAILURE);
	}

	__darwintrace_initialized = false;
	if (-1 == dup2(STDOUT_FILENO, newfd)) {
		fprintf(stderr, "uninitialized dup2(STDOUT_FILENO, %d): %s\n", newfd, strerror(errno));
		exit(EXIT_FAILURE);
	}

	exit(EXIT_SUCCESS);
}
