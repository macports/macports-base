#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

int main(int argc, char* argv[]) {
	if (argc < 2) {
		fprintf(stderr, "Usage: fork PATH\n");
		exit(EXIT_FAILURE);
	}

	if (access(argv[1], F_OK) == -1) {
		fprintf(stderr, "access(%s): %s\n", argv[1], strerror(errno));
	}

	pid_t pid = fork();
	int status = 0;
	switch (pid) {
		case -1:
			perror("fork");
			exit(EXIT_FAILURE);
		case 0:
			if (access(argv[1], F_OK) == -1) {
				fprintf(stderr, "access(%s): %s\n", argv[1], strerror(errno));
			}
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
