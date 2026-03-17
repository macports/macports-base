#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static int rmrf_at(int parentfd, const char *name) {
    struct stat st;

    if (fstatat(parentfd, name, &st, AT_SYMLINK_NOFOLLOW) != 0) {
        return errno == ENOENT ? 0 : -1;
    }

    if (S_ISDIR(st.st_mode)) {
        int fd = openat(parentfd, name, O_RDONLY | O_DIRECTORY);
        if (fd == -1) {
            return -1;
        }

        DIR *dir = fdopendir(fd);
        if (dir == NULL) {
            int saved_errno = errno;
            close(fd);
            errno = saved_errno;
            return -1;
        }

        for (;;) {
            errno = 0;
            struct dirent *entry = readdir(dir);
            if (entry == NULL) {
                int saved_errno = errno;
                closedir(dir);
                if (saved_errno != 0) {
                    errno = saved_errno;
                    return -1;
                }
                break;
            }

            if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
                continue;
            }

            if (rmrf_at(fd, entry->d_name) != 0) {
                int saved_errno = errno;
                closedir(dir);
                errno = saved_errno;
                return -1;
            }
        }

        if (unlinkat(parentfd, name, AT_REMOVEDIR) != 0) {
            return -1;
        }
        return 0;
    }

    return unlinkat(parentfd, name, 0);
}

int main(int argc, char *argv[]) {
    bool failed = false;

    if (argc < 2) {
        fprintf(stderr, "usage: %s path...\n", argv[0]);
        return 1;
    }

    for (int i = 1; i < argc; i++) {
        if (rmrf_at(AT_FDCWD, argv[i]) != 0) {
            fprintf(stderr, "%s: %s: %s\n", argv[0], argv[i], strerror(errno));
            failed = true;
        }
    }

    return failed ? 1 : 0;
}
