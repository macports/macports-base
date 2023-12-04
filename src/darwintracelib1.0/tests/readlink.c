#define DARWINTRACE_USE_PRIVATE_API
#include "../darwintrace.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <unistd.h>

int main(int argc, char* argv[]) {
	if (argc != 2) {
		fprintf(stderr, "Usage: readlink PATH\n");
		exit(EXIT_FAILURE);
	}

	if (getenv("DARWINTRACE_UNINITIALIZE") != NULL) {
		__darwintrace_initialized = false;
	}

	char buf[MAXPATHLEN];
	ssize_t len = readlink(argv[1], buf, sizeof(buf) - 1);
	if (-1 == len) {
		fprintf(stderr, "readlink(%s): %s\n", argv[1], strerror(errno));
	} else {
		buf[len] = '\0';
		printf("%s\n", buf);
	}

	exit(EXIT_SUCCESS);
}
