#define DARWINTRACE_USE_PRIVATE_API
#include "../darwintrace.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char* argv[]) {
	if (argc < 2) {
		fprintf(stderr, "Usage: rmdir PATH\n");
		exit(EXIT_FAILURE);
	}

	if (getenv("DARWINTRACE_UNINITIALIZE") != NULL) {
		__darwintrace_initialized = false;
	}

	if (-1 == rmdir(argv[1])) {
		perror("rmdir");
	}
	exit(EXIT_SUCCESS);
}
