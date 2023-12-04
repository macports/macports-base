#define DARWINTRACE_USE_PRIVATE_API
#include "../darwintrace.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

int main(int argc, char* argv[]) {
	if (argc < 2) {
		fprintf(stderr, "Usage: mkdir PATH...\n");
		exit(EXIT_FAILURE);
	}

	if (getenv("DARWINTRACE_UNINITIALIZE") != NULL) {
		__darwintrace_initialized = false;
	}

	for (int idx = 1; idx < argc; ++idx) {
		if (-1 == mkdir(argv[idx], 0777)) {
			fprintf(stderr, "mkdir(%s): %s\n", argv[idx], strerror(errno));
		}
	}
	exit(EXIT_SUCCESS);
}
