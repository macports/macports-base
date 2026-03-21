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
 *
 * Collects directory entries before closing the DIR handle, then recurses.
 * This keeps at most one file descriptor open at any recursion depth,
 * avoiding EMFILE ("Too many open files") on deep trees.
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

    /* Collect entry names first so we can close the DIR before recursing. */
    char **names = NULL;
    size_t count = 0;
    size_t capacity = 0;
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

        if (count == capacity) {
            size_t new_cap = capacity == 0 ? 8 : capacity * 2;
            char **tmp = realloc(names, new_cap * sizeof(*names));
            if (tmp == NULL) {
                ret = -1;
                break;
            }
            names = tmp;
            capacity = new_cap;
        }

        names[count] = strdup(entry->d_name);
        if (names[count] == NULL) {
            ret = -1;
            break;
        }
        count++;
    }

    closedir(dir);

    /* Now recurse over collected entries with the DIR closed. */
    for (size_t i = 0; i < count && ret == 0; i++) {
        if (rmrf(names[i]) != 0) {
            ret = -1;
        }
    }

    for (size_t i = 0; i < count; i++) {
        free(names[i]);
    }
    free(names);

    /* Return to the parent directory before rmdir. */
    chdir("..");

    if (ret != 0) {
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
