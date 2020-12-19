#define DARWINTRACE_USE_PRIVATE_API
#include "../darwintrace.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char* argv[]) {
	if (argc != 3) {
		fprintf(stderr, "Usage: rename SRC TGT\n");
		exit(EXIT_FAILURE);
	}

	if (getenv("DARWINTRACE_UNINITIALIZE") != NULL) {
		__darwintrace_initialized = false;
	}

	if (-1 == rename(argv[1], argv[2])) {
		fprintf(stderr, "rename(%s, %s): %s\n", argv[1], argv[2], strerror(errno));
	}

	exit(EXIT_SUCCESS);
}
