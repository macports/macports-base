#include <dirent.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

/*
 * Recursively remove a file or directory. Uses chdir() to descend into
 * directories so that all syscalls operate on short, relative names.
 * This avoids ENAMETOOLONG on deeply nested trees that exceed PATH_MAX.
 * Uses chdir("..") to return rather than fchdir() to avoid accumulating
 * open file descriptors during deep recursion.
 */
static int rmrf(const char *path) {
    struct stat st;

    if (lstat(path, &st) != 0) {
        return errno == ENOENT ? 0 : -1;
    }

    if (!S_ISDIR(st.st_mode)) {
        return unlink(path);
    }

    if (chdir(path) != 0) {
        return -1;
    }

    DIR *dir = opendir(".");
    if (dir == NULL) {
        int saved_errno = errno;
        chdir("..");
        errno = saved_errno;
        return -1;
    }

    int ret = 0;
    for (;;) {
        errno = 0;
        struct dirent *entry = readdir(dir);
        if (entry == NULL) {
            if (errno != 0) {
                ret = -1;
            }
            break;
        }

        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        if (rmrf(entry->d_name) != 0) {
            ret = -1;
            break;
        }
    }

    int saved_errno = errno;
    closedir(dir);

    /* Return to the parent directory before rmdir. */
    chdir("..");

    if (ret != 0) {
        errno = saved_errno;
        return ret;
    }

    return rmdir(path);
}

int main(int argc, char *argv[]) {
    bool failed = false;

    if (argc < 2) {
        fprintf(stderr, "usage: %s path...\n", argv[0]);
        return 1;
    }

    for (int i = 1; i < argc; i++) {
        if (rmrf(argv[i]) != 0) {
            fprintf(stderr, "%s: %s: %s\n", argv[0], argv[i], strerror(errno));
            failed = true;
        }
    }

    return failed ? 1 : 0;
}
