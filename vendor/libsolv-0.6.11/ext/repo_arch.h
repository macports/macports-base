/*
 * Copyright (c) 2012, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

#define ARCH_ADD_WITH_PKGID  (1 << 8)

extern Id repo_add_arch_pkg(Repo *repo, const char *fn, int flags);
extern Id repo_add_arch_repo(Repo *repo, FILE *fp, int flags);
extern Id repo_add_arch_local(Repo *repo, const char *dir, int flags);

