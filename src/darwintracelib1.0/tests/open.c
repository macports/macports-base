#define DARWINTRACE_USE_PRIVATE_API
#include "../darwintrace.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char* argv[]) {
	if (argc < 3) {
		fprintf(stderr, "Usage: open {-create|-read} PATH...\n");
		exit(EXIT_FAILURE);
	}

	if (getenv("DARWINTRACE_UNINITIALIZE") != NULL) {
		__darwintrace_initialized = false;
	}

	int flags = 0;
	mode_t mode = 0666;
	if (strcmp(argv[1], "-create") == 0) {
		flags |= O_RDWR | O_CREAT;
	} else if (strcmp(argv[1], "-read") == 0) {
		flags |= O_RDONLY;
	} else {
		fprintf(stderr, "open: unsupported mode '%s'. Choose one of '-create', '-read'.\n", argv[1]);
		exit(EXIT_FAILURE);
	}

	for (int idx = 2; idx < argc; ++idx) {
		int fd = open(argv[idx], flags, mode);
		if (-1 == fd) {
			fprintf(stderr, "open(%s): %s\n", argv[idx], strerror(errno));
		} else {
			close(fd);
		}
	}
	exit(EXIT_SUCCESS);
}
