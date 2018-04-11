/*
 * Copyright (c) 2007, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/* read susetags file <fp> into <repo>
 * if <attrname> given, write attributes as '<attrname>.attr'
 */

#define SUSETAGS_EXTEND			(1 << 9)
#define SUSETAGS_RECORD_SHARES		(1 << 10)

extern int repo_add_susetags(Repo *repo, FILE *fp, Id defvendor, const char *language, int flags);
