#define DARWINTRACE_USE_PRIVATE_API
#include "../darwintrace.h"

#include <spawn.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

int main(int argc, char* argv[], char* envp[]) {
	if (argc < 2) {
		fprintf(stderr, "Usage: posix_spawn PROGRAM ARGS...\n");
		exit(EXIT_FAILURE);
	}

	if (getenv("DARWINTRACE_UNINITIALIZE") != NULL) {
		__darwintrace_initialized = false;
	}

	bool use_spawn_setexec = false;
	if (getenv("DARWINTRACE_SPAWN_SETEXEC") != NULL) {
		use_spawn_setexec = true;
	}

	pid_t pid;
	posix_spawnattr_t attr;
	if (0 != (errno = posix_spawnattr_init(&attr))) {
		perror("posix_spawnattr_init");
		exit(EXIT_FAILURE);
	}
	if (0 != (errno = posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETEXEC))) {
		perror("posix_spawnattr_setflags");
		exit(EXIT_FAILURE);
	}

	if (0 != (errno = posix_spawn(&pid, argv[1], NULL, use_spawn_setexec ? &attr : NULL, argv + 1, envp))) {
		perror("posix_spawn");
		exit(EXIT_SUCCESS);
	} else {
		int status;
		if (pid != waitpid(pid, &status, 0)) {
			perror("waitpid");
			exit(EXIT_FAILURE);
		}
		if (WIFEXITED(status)) {
			exit(WEXITSTATUS(status));
		} else if (WIFSIGNALED(status)) {
			fprintf(stderr, "%s killed with signal %d\n", argv[1], WTERMSIG(status));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr, "%s: unexpected exit status %d\n", argv[1], status);
		exit(EXIT_FAILURE);
	}
}
