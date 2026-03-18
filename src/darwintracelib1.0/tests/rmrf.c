#include <dirent.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static int rmrf(const char *path) {
    struct stat st;

    if (lstat(path, &st) != 0) {
        return errno == ENOENT ? 0 : -1;
    }

    if (S_ISDIR(st.st_mode)) {
        DIR *dir = opendir(path);
        if (dir == NULL) {
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

            size_t child_len = strlen(path) + 1 + strlen(entry->d_name) + 1;
            char *child = malloc(child_len);
            if (child == NULL) {
                int saved_errno = errno;
                closedir(dir);
                errno = saved_errno;
                return -1;
            }
            snprintf(child, child_len, "%s/%s", path, entry->d_name);

            int rc = rmrf(child);
            int saved_errno = errno;
            free(child);

            if (rc != 0) {
                closedir(dir);
                errno = saved_errno;
                return -1;
            }
        }

        return rmdir(path);
    }

    return unlink(path);
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
