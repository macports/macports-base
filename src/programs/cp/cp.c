/* cp wrapper to add -c (clone) option */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/errno.h>

extern char **environ;

int main(int argc, char *argv[])
{
    const char *cp_path = "/bin/cp";
    const char *clone_arg = "-c";
    const char **new_argv = malloc(sizeof(char *) * (argc+1));
    if (new_argv) {
        new_argv[0] = cp_path;
        new_argv[1] = clone_arg;
        for (int i = 1; i < argc; i++) {
            new_argv[i+1] = argv[i];
        }
        execve(cp_path, new_argv, environ);
    }
    /* something failed */
    perror("cp");
    return errno;
}
