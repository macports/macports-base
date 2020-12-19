#define DARWINTRACE_USE_PRIVATE_API
#include "../darwintrace.h"

#include <dirent.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char* argv[]) {
	if (argc < 2) {
		fprintf(stderr, "Usage: readdir PATH\n");
		exit(EXIT_FAILURE);
	}

	if (getenv("DARWINTRACE_UNINITIALIZE") != NULL) {
		__darwintrace_initialized = false;
	}

	DIR* dir = opendir(argv[1]);
	if (dir == NULL) {
		perror("opendir");
		exit(EXIT_FAILURE);
	}

	struct dirent *d;
	while (errno = 0, (d = readdir(dir)) != NULL) {
		printf("%s\n", d->d_name);
	}
	if (errno != 0) {
		perror("readdir");
		exit(EXIT_FAILURE);
	}

	exit(EXIT_SUCCESS);
}
