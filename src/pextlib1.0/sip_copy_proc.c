/* vim: set et sw=4 ts=4 sts=4: */
/*
 * sip_copy_proc.c
 *
 * Copyright (c) 2015 Clemens Lang <cal@macports.org>
 * Copyright (c) 2015 The MacPorts Project
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of The MacPorts Project nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#define _DARWIN_FEATURE_64_BIT_INODE

#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>

#include <config.h>

#ifdef HAVE_COPYFILE
#include <copyfile.h>
#endif

#include "sip_copy_proc.h"

#ifndef DARWINTRACE_SIP_WORKAROUND_PATH
#warning No value for DARWINTRACE_SIP_WORKAROUND_PATH found in config.h, using default of /tmp/macports-sip, which will fail unless you create it with mode 01777
#define DARWINTRACE_SIP_WORKAROUND_PATH "/tmp/macports-sip"
#endif

/**
 * Frees an array of strings and the array itself.
 */
static void free_argv(char *argv[]) {
    char **arg = argv;
    while (arg && *arg) {
        free(*arg);
        *arg = NULL;
        arg++;
    }

    free(argv);
}

typedef enum _copy_needed_return_t {
    copy_needed_error,
    copy_not_needed,
    copy_is_needed
} copy_needed_return_t;

/**
 * Helper function to determine whether the binary indicated by \a path
 * supports library injection using DYLD_INSERT_LIBRARIES directly or needs to
 * be copied to a temporary path to support it.
 *
 * The following conditions must be fulfilled for the copy to be necessary:
 *  - \a environ needs to contain a variable that starts with
 *    DYLD_INSERT_LIBRARIES
 *  - If the file at \a path has a shebang, its shebang line will be read and
 *    the following checks will be done against the interpreter binary.
 *    Additionally, if the copy is necessary, the arguments given in \a argc
 *    (the number of arguments) and \a argv (the arguments itself) will be
 *    prefixed with the command and arguments from the shebang line. The
 *    original first argument will be replaced with \a path to make sure it is
 *    absolute.
 *  - \a path (or the interpreter given in the shebang of path) must have the
 *    \c SF_RESTRICTED flag set.
 *  - \a path (or the interpreter given in the shebang of path) must not be
 *    SUID or SGID.
 *
 * @param path The absolute path of the binary to be executed
 * @param argv The arguments to be passed to the file to be executed
 * @param outargv Pointer to a modified array of arguments. Only valid if \c
 *                copy_is_needed is returned. May be \c NULL, in which case no
 *                modifications to the original \c argv were necessary. If
 *                non-null, a dynamically allocated array of dynamically
 *                allocated elements. The last element of the array is \c NULL,
 *                which makes \c *outargv suitable for passing to execve(2).
 *                Note that instead of the given \c path, you should pass \c
 *                (*outargv)[0] to execve(2) as first argument.
 * @param environ The environment for the program to be started. Will be
 *                checked for the presence of a DYLD_INSERT_LIBRARIES variable.
 * @param st Pointer to struct stat that will contain information about \c
 *           path, or of \c outargv isn't \c NULL, about \c (*outargv)[0]. This
 *           can be used to determine metadata of the file such as modification
 *           time and size to avoid unnecessary copies.
 * @return \c copy_isneeded iff a copy is required. \c copy_not_needed if a copy
 *         is not needed. \c copy_needed_error on error, where errno will be
 *         set.
 */
static copy_needed_return_t copy_needed(const char *path, char *const argv[],
        char **outargv[], char *const environ[], struct stat *st) {
#ifndef SF_RESTRICTED /* no system integrity protection */
    (void) path;
    (void) argv;
    (void) outargv;
    (void) environ;
    (void) st;
    return copy_not_needed;
#else /* defined(SF_RESTRICTED) */
    // check whether DYLD_INSERT_LIBRARIES is set
    bool dyld_insert_libraries_present = false;
    char *const *env = environ;
    while (env && *env) {
        if (strncmp("DYLD_INSERT_LIBRARIES=", *env, strlen("DYLD_INSERT_LIBRARIES=")) == 0) {
            dyld_insert_libraries_present = true;
            break;
        }
        env++;
    }
    // if we didn't find DYLD_INSERT_LIBRARIES, a copy isn't needed
    if (!dyld_insert_libraries_present) {
        return copy_not_needed;
    }

    // open file to check for shebangs
    const char *realpath = path;
    size_t new_argc = 0;
    char **new_argv = NULL;
    FILE *f = fopen(path, "r");
    if (!f) {
        // if opening fails we won't be able to copy anyway
        return copy_not_needed;
    }

    /* no error checking for fgetc(3) here, because this isn't a shebang if an
     * error occurs */
    if (fgetc(f) == '#' && fgetc(f) == '!') {
        /* This is an interpreted script. The interpreter's flags are what
         * affects whether DYLD_* is stripped, so read the interpreter's path
         * from the file to check that instead. Additionally, read any flags
         * that may be passed to the interpreter, since we'll have to do the
         * shebang expansion in user space if we move the interpreter. */
        char *linep = NULL;
        size_t linecapp = 0;
        // read first line to get the interpreter and its arguments
        if (getline(&linep, &linecapp, f) > 0) {
            char *ctxt;
            char *word;
            size_t idx;
            fclose(f);
            // do word splitting on the interpreter line and store it in new_argv
            for (idx = 0, word = strtok_r(linep, " \t\n", &ctxt);
                    word != NULL;
                    idx++, word = strtok_r(NULL, " \t\n", &ctxt)) {
                // make sure we have enough space allocated
                if (new_argv == NULL) {
                    if ((new_argv = malloc(2 * sizeof(*new_argv))) == NULL) {
                        free(linep);
                        return copy_needed_error;
                    }
                    new_argc = 1;

                    // new_argv[0] will be overwritten in a second
                    // new_argv[1] is the terminating NULL
                    new_argv[0] = NULL;
                    new_argv[1] = NULL;
                } else if (idx >= new_argc) {
                    // realloc to increase the size
                    char **oldargv = new_argv;
                    if ((new_argv = realloc(oldargv, (idx + 2) * sizeof(*new_argv))) == NULL) {
                        free_argv(oldargv);
                        free(linep);
                        return copy_needed_error;
                    }
                    new_argc = idx + 1;
                }

                // store a copy of the word in new_argv
                new_argv[idx] = strdup(word);
                if (!new_argv[idx]) {
                    free_argv(new_argv);
                    free(linep);
                    return copy_needed_error;
                }
                new_argv[idx + 1] = NULL;
            }

            free(linep);

            if (new_argv && *new_argv) {
                // interpreter found, check that instead of given path
                realpath = *new_argv;
            }
        } else {
            fclose(f);
        }
    } else {
        fclose(f);
    }

    // check whether the binary has SF_RESTRICTED and isn't SUID/SGID
    if (-1 == stat(realpath, st)) {
        // on error, return and let execve(2) deal with it
        free_argv(new_argv);
        return copy_not_needed;
    } else {
        if (!(st->st_flags & SF_RESTRICTED)) {
            // no SIP on this binary
            free_argv(new_argv);
            return copy_not_needed;
        }
        if ((st->st_flags & (S_ISUID | S_ISGID)) > 0) {
            // the binary is SUID/SGID, which would get lost when copying;
            // DYLD_ variables are stripped for SUID/SGID binaries anyway
            free_argv(new_argv);
            return copy_not_needed;
        }
    }

    // prefix the shebang line to the original argv
    if (new_argv != NULL) {
        size_t argc = 0;
        for (char *const *argvwalk = argv; argvwalk && *argvwalk; ++argvwalk) {
            argc++;
        }

        // realloc to increase the size
        char **oldargv = new_argv;
        if ((new_argv = realloc(oldargv, (new_argc + argc + 1) * sizeof(*new_argv))) == NULL) {
            free_argv(oldargv);
            return copy_needed_error;
        }

        new_argv[new_argc] = strdup(path);
        if (!new_argv[new_argc]) {
            free_argv(new_argv);
            return copy_needed_error;
        }
        new_argv[new_argc + 1] = NULL;

        for (size_t idx = 1; idx < argc; ++idx) {
            new_argv[new_argc + idx] = strdup(argv[idx]);
            if (!new_argv[new_argc + idx]) {
                free_argv(new_argv);
                return copy_needed_error;
            }
            new_argv[new_argc + idx + 1] = NULL;
        }

        new_argc = new_argc + argc;

        *outargv = new_argv;
    }

    return copy_is_needed;
#endif /* defined(SF_RESTRICTED) */
}

static char *lazy_copy(const char *path, struct stat *in_st) {
    char *retval = NULL;
    uid_t euid = geteuid();
    int outfd = -1;
    int infd = -1;

    char *target_folder = NULL;
    char *target_path = NULL;
    char *target_path_temp = NULL;
    char *dir = strdup(path);
    if (!dir) {
        goto lazy_copy_out;
    }
    char *endslash = strrchr(dir, '/');
    if (endslash) {
        *endslash = '\0';
    }

    if (-1 == asprintf(&target_folder, "%s/%lu%s", DARWINTRACE_SIP_WORKAROUND_PATH, (unsigned long) euid, dir)) {
        goto lazy_copy_out;
    }

    if (-1 == asprintf(&target_path, "%s/%lu%s", DARWINTRACE_SIP_WORKAROUND_PATH, (unsigned long) euid, path)) {
        goto lazy_copy_out;
    }

    if (-1 == asprintf(&target_path_temp, "%s/%lu/.XXXXXXXXXXXXXX", DARWINTRACE_SIP_WORKAROUND_PATH, (unsigned long) euid)) {
        goto lazy_copy_out;
    }

    // ensure directory exists
    char *pos = target_folder + strlen(DARWINTRACE_SIP_WORKAROUND_PATH);
    while (pos && *pos) {
        *pos = '\0';
        if (-1 == mkdir(target_folder, 0755) && errno != EEXIST) {
            fprintf(stderr, "sip_copy_proc: mkdir(%s): %s\n", target_folder, strerror(errno));
            goto lazy_copy_out;
        }
        *pos = '/';
        pos++;
        pos = strchr(pos, '/');
    }
    if (-1 == mkdir(target_folder, 0755) && errno != EEXIST) {
        fprintf(stderr, "sip_copy_proc: mkdir(%s): %s\n", target_folder, strerror(errno));
        goto lazy_copy_out;
    }

    // check whether copying is needed; it isn't if the file exists and the
    // modification times match
    struct stat out_st;
    if (   -1 != stat(target_path, &out_st)
        && in_st->st_mtimespec.tv_sec == out_st.st_mtimespec.tv_sec
        && in_st->st_mtimespec.tv_nsec == out_st.st_mtimespec.tv_nsec) {
        // copying not needed
        retval = target_path;
        goto lazy_copy_out;
    }

#ifdef HAVE_COPYFILE
    // as copyfile(3) is not guaranteed to be atomic, copy to a temporary file first
    if (mktemp(target_path_temp) == NULL) {
        fprintf(stderr, "sip_copy_proc: mktemp(%s): %s\n", target_path_temp, strerror(errno));
        goto lazy_copy_out;
    }

    // copyfile(3) will not preserve SF_RESTRICTED,
    // we can safely copy the source file with all metadata.
    // This cannot use COPYFILE_CLONE as it does not follow symlinks,
    // see https://trac.macports.org/ticket/55575
    if (copyfile(path, target_path_temp, NULL, COPYFILE_ACL | COPYFILE_XATTR | COPYFILE_DATA | COPYFILE_EXCL) != 0) {
        fprintf(stderr, "sip_copy_proc: copyfile(%s, %s): %s\n", path, target_path_temp, strerror(errno));
        goto lazy_copy_out;
    }

    // Re-open the copied file in outfd, because copyfile(3) with COPYFILE_ALL
    // (or COPYFILE_STAT, for that matter) does not seem to copy the file
    // creation time correctly, so we need another futimes(2) to fix that.
#ifdef O_CLOEXEC
    if (-1 == (outfd = open(target_path_temp, O_RDWR | O_CLOEXEC))) {
        fprintf(stderr, "sip_copy_proc: open(%s, O_RDWR | O_CLOEXEC): %s\n", target_path_temp, strerror(errno));
#else
    if (-1 == (outfd = open(target_path_temp, O_RDWR))) {
        fprintf(stderr, "sip_copy_proc: open(%s, O_RDWR): %s\n", target_path_temp, strerror(errno));
#endif
        goto lazy_copy_out;
    }

    // Since we removed COPYFILE_STAT from the copyfile(3) invocation above, we
    // need to restore the permissions on the copy. Note that the futimes(2)
    // later on should still succeed even if we remove write permissions here,
    // because we already have a file descriptor open.
    if (-1 == fchmod(outfd, in_st->st_mode)) {
        fprintf(stderr, "sip_copy_proc: fchmod(%s, %o): %s\n", target_path_temp, in_st->st_mode, strerror(errno));
        goto lazy_copy_out;
    }
#else /* !HAVE_COPYFILE */
    // create temporary file to copy into and then later atomically replace
    // target file
    if (-1 == (outfd = mkstemp(target_path_temp))) {
        fprintf(stderr, "sip_copy_proc: mkstemp(%s): %s\n", target_path_temp, strerror(errno));
        goto lazy_copy_out;
    }

#ifdef O_CLOEXEC
    if (-1 == (infd = open(path, O_RDONLY | O_CLOEXEC))) {
        fprintf(stderr, "sip_copy_proc: open(%s, O_RDONLY | O_CLOEXEC): %s\n", path, strerror(errno));
#else
    if (-1 == (infd = open(path, O_RDONLY))) {
        fprintf(stderr, "sip_copy_proc: open(%s, O_RDONLY): %s\n", path, strerror(errno));
#endif
        goto lazy_copy_out;
    }

    // ensure mode is copied
    if (-1 == fchmod(outfd, in_st->st_mode)) {
        fprintf(stderr, "sip_copy_proc: fchmod(%s, %o): %s\n", target_path_temp, in_st->st_mode, strerror(errno));
        goto lazy_copy_out;
    }

    char *buf = malloc(in_st->st_blksize);
    ssize_t bytes_read = 0;
    ssize_t bytes_written = 0;
    bool error = false;
    do {
        bytes_read = read(infd, buf, in_st->st_blksize);
        if (bytes_read < 0) {
            if (errno == EINTR || errno == EAGAIN) {
                continue;
            } else {
                error = true;
                break;
            }
        }
        if (bytes_read == 0) {
            // EOF
            break;
        }

        bytes_written = 0;
        while (bytes_written < bytes_read) {
            ssize_t written = write(outfd, buf + bytes_written, bytes_read - bytes_written);
            if (written < 0) {
                if (errno == EINTR || errno == EAGAIN) {
                    continue;
                }
                error = true;
                break;
            }

            bytes_written += written;
        }
    } while (!error);
    if (bytes_read < 0 || bytes_written < 0) {
        goto lazy_copy_out;
    }
#endif /* HAVE_COPYFILE */

    struct timeval times[2];
    TIMESPEC_TO_TIMEVAL(&times[0], &in_st->st_mtimespec);
    TIMESPEC_TO_TIMEVAL(&times[1], &in_st->st_mtimespec);
    if (-1 == futimes(outfd, times)) {
        fprintf(stderr, "sip_copy_proc: futimes(%s): %s\n", target_path_temp, strerror(errno));
        goto lazy_copy_out;
    }

    if (-1 == rename(target_path_temp, target_path)) {
        fprintf(stderr, "sip_copy_proc: rename(%s, %s): %s\n", target_path_temp, target_path, strerror(errno));
        goto lazy_copy_out;
    }

    retval = target_path;

lazy_copy_out:
    {
        int errno_save = errno;
        close(outfd);
        close(infd);
        if (target_path_temp != NULL && -1 == unlink(target_path_temp) && errno != ENOENT) {
            fprintf(stderr, "sip_copy_proc: unlink(%s): %s\n", target_path_temp, strerror(errno));
            retval = NULL;
        } else {
            errno = errno_save;
        }
    }
    free(dir);
    free(target_path_temp);
    free(target_folder);
    if (retval != target_path) {
        free(target_path);
    }
    return retval;
}

/**
 * Behaves like execve(2), but checks whether trace mode is enabled (by
 * checking for DYLD_INSERT_LIBRARIES in the environment) and the binary is
 * covered by 10.11's new system integrity protection. If it is, the binary
 * will be copied to a separate folder (or updated if already there and
 * modification time differs) and executed from there.
 */
int sip_copy_execve(const char *path, char *const argv[], char *const envp[]) {
    char **outargv = NULL;
    struct stat st;

    copy_needed_return_t need_copy = copy_needed(path, argv, &outargv, envp, &st);
    switch (need_copy) {
        case copy_needed_error:
            return -1;
            break;
        case copy_not_needed:
            return execve(path, argv, envp);
            break;
        case copy_is_needed: {
                const char *to_be_copied = path;
                char *const *to_be_argv = argv;
                if (outargv) {
                    to_be_copied = outargv[0];
                    to_be_argv = outargv;
                }

                char *new_path = lazy_copy(to_be_copied, &st);
                if (!new_path) {
                    free_argv(outargv);
                    return -1;
                }

                int ret = execve(new_path, to_be_argv, envp);
                free_argv(outargv);
                free(new_path);
                return ret;
            }
            break;
    }

    return -1;
}

/**
 * Behaves like posix_spawn(2), but checks whether trace mode is enabled (by
 * checking for DYLD_INSERT_LIBRARIES in the environment) and the binary is
 * covered by 10.11's new system integrity protection. If it is, the binary
 * will be copied to a separate folder (or updated if already there and
 * modification time differs) and executed from there.
 */
int sip_copy_posix_spawn(
        pid_t *restrict pid,
        const char *restrict path,
        const posix_spawn_file_actions_t *file_actions,
        const posix_spawnattr_t *restrict attrp,
        char *const argv[restrict],
        char *const envp[restrict]) {
    char **outargv = NULL;
    struct stat st;

    copy_needed_return_t need_copy = copy_needed(path, argv, &outargv, envp, &st);
    switch (need_copy) {
        case copy_needed_error:
            return -1;
            break;
        case copy_not_needed:
            return posix_spawn(pid, path, file_actions, attrp, argv, envp);
            break;
        case copy_is_needed: {
                const char *to_be_copied = path;
                char *const *to_be_argv = argv;
                if (outargv) {
                    to_be_copied = outargv[0];
                    to_be_argv = outargv;
                }

                char *new_path = lazy_copy(to_be_copied, &st);
                if (!new_path) {
                    free_argv(outargv);
                    return -1;
                }

                int ret = posix_spawn(pid, new_path, file_actions, attrp, to_be_argv, envp);
                free_argv(outargv);
                free(new_path);
                return ret;
            }
            break;
    }

    return -1;
}
