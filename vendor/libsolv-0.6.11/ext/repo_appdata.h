/*
 * Copyright (c) 2013, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

int repo_add_appdata(Repo *repo, FILE *fp, int flags);
int repo_add_appdata_dir(Repo *repo, const char *appdatadir, int flags);

#define APPDATA_CHECK_DESKTOP_FILE	(1 << 30)	/* internal */
