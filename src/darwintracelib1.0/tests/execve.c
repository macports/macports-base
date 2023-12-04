#define DARWINTRACE_USE_PRIVATE_API
#include "../darwintrace.h"

#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

int main(int argc, char* argv[], char* envp[]) {
	if (argc < 2) {
		fprintf(stderr, "Usage: execve PROGRAM ARGS...\n");
		exit(EXIT_FAILURE);
	}

	if (getenv("DARWINTRACE_UNINITIALIZE") != NULL) {
		__darwintrace_initialized = false;
	}

	pid_t pid = fork();
	int status = 0;
	switch (pid) {
		case -1:
			perror("fork");
			exit(EXIT_FAILURE);
		case 0:
			execve(argv[1], argv + 1, envp);
			perror("execve");
			exit(EXIT_SUCCESS);
		default:
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
	}
	fprintf(stderr, "%s: unexpected exit status %d\n", argv[1], status);
	exit(EXIT_FAILURE);
}
