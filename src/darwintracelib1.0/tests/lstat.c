#define DARWINTRACE_USE_PRIVATE_API
#include "../darwintrace.h"

#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

int main(int argc, char* argv[]) {
	if (argc < 2) {
		fprintf(stderr, "Usage: lstat PATH\n");
		exit(EXIT_FAILURE);
	}

	if (getenv("DARWINTRACE_UNINITIALIZE") != NULL) {
		__darwintrace_initialized = false;
	}

	struct stat st;
	if (-1 == lstat(argv[1], &st)) {
		perror("lstat");
	}
	exit(EXIT_SUCCESS);
}
