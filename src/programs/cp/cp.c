/* cp wrapper to add -c (clone) option */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
    char cp_path[] = "/bin/cp";
    char clone_arg[] = "-c";
    char **new_argv = malloc(sizeof(char *) * (argc+2));
    if (new_argv) {
        new_argv[0] = cp_path;
        new_argv[1] = clone_arg;
        for (int i = 1; i <= argc; i++) {
            new_argv[i+1] = argv[i];
        }
        execv(cp_path, new_argv);
    }
    /* something failed */
    perror("cp");
    return errno;
}
