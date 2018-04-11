/*
 * Copyright (c) 2009, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

extern int repo_add_debpackages(Repo *repo, FILE *fp, int flags);
extern int repo_add_debdb(Repo *repo, int flags);
extern Id repo_add_deb(Repo *repo, const char *deb, int flags);
extern void pool_deb_get_autoinstalled(Pool *pool, FILE *fp, Queue *q, int flags);

#define DEBS_ADD_WITH_PKGID	(1 << 8)
