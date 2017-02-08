/*
 * Copyright (c) 2007-2008, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

#include "queue.h"
#include "repo.h"

struct headerToken_s;

extern int repo_add_rpmdb(Repo *repo, Repo *ref, int flags);
extern int repo_add_rpmdb_reffp(Repo *repo, FILE *reffp, int flags);
extern Id repo_add_rpm(Repo *repo, const char *rpm, int flags);

#define RPMDB_REPORT_PROGRESS	(1 << 8)
#define RPM_ADD_WITH_PKGID	(1 << 9)
#define RPM_ADD_NO_FILELIST	(1 << 10)
#define RPM_ADD_NO_RPMLIBREQS	(1 << 11)
#define RPM_ADD_WITH_SHA1SUM	(1 << 12)
#define RPM_ADD_WITH_SHA256SUM	(1 << 13)
#define RPM_ADD_TRIGGERS	(1 << 14)
#define RPM_ADD_WITH_HDRID	(1 << 15)
#define RPM_ADD_WITH_LEADSIGID	(1 << 16)
#define RPM_ADD_WITH_CHANGELOG	(1 << 17)
#define RPM_ADD_FILTERED_FILELIST (1 << 18)

#define RPMDB_EMPTY_REFREPO	(1 << 30)	/* internal */

#define RPM_ITERATE_FILELIST_ONLYDIRS	(1 << 0)
#define RPM_ITERATE_FILELIST_WITHMD5	(1 << 1)
#define RPM_ITERATE_FILELIST_WITHCOL	(1 << 2)
#define RPM_ITERATE_FILELIST_NOGHOSTS	(1 << 3)

/* create and free internal state, rootdir is the rootdir of the rpm database */
extern void *rpm_state_create(Pool *pool, const char *rootdir);
extern void *rpm_state_free(void *rpmstate);

/* return all matching rpmdbids */
extern int  rpm_installedrpmdbids(void *rpmstate, const char *index, const char *match, Queue *rpmdbidq);

/* return handles to a rpm header */
extern void *rpm_byrpmdbid(void *rpmstate, Id rpmdbid);
extern void *rpm_byfp(void *rpmstate, FILE *fp, const char *name);
extern void *rpm_byrpmh(void *rpmstate, struct headerToken_s *h);

/* operations on a rpm header handle */

struct filelistinfo {
  unsigned int dirlen;
  unsigned int diridx;
  const char *digest;
  unsigned int mode;
  unsigned int color;
};

extern char *rpm_query(void *rpmhandle, Id what);
extern unsigned long long rpm_query_num(void *rpmhandle, Id what, unsigned long long notfound);
extern void rpm_iterate_filelist(void *rpmhandle, int flags, void (*cb)(void *, const char *, struct filelistinfo *), void *cbdata);
extern Id   repo_add_rpm_handle(Repo *repo, void *rpmhandle, int flags);
