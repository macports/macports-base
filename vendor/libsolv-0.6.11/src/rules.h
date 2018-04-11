/*
 * Copyright (c) 2007-2009, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * rules.h
 *
 */

#ifndef LIBSOLV_RULES_H
#define LIBSOLV_RULES_H

#ifdef __cplusplus
extern "C" {
#endif

/* ----------------------------------------------
 * Rule
 *
 *   providerN(B) == Package Id of package providing tag B
 *   N = 1, 2, 3, in case of multiple providers
 *
 * A requires B : !A | provider1(B) | provider2(B)
 *
 * A conflicts B : (!A | !provider1(B)) & (!A | !provider2(B)) ...
 *
 * 'not' is encoded as a negative Id
 *
 * Binary rule: p = first literal, d = 0, w2 = second literal, w1 = p
 *
 * There are a lot of rules, so the struct is kept as small as
 * possible. Do not add new members unless there is no other way.
 */

typedef struct _Rule {
  Id p;		/* first literal in rule */
  Id d;		/* Id offset into 'list of providers terminated by 0' as used by whatprovides; pool->whatprovides + d */
		/* in case of binary rules, d == 0, w1 == p, w2 == other literal */
		/* in case of disabled rules: ~d, aka -d - 1 */
  Id w1, w2;	/* watches, literals not-yet-decided */
		/* if !w2, assertion, not rule */
  Id n1, n2;	/* next rules in linked list, corresponding to w1, w2 */
} Rule;


typedef enum {
  SOLVER_RULE_UNKNOWN = 0,
  SOLVER_RULE_PKG = 0x100,
  SOLVER_RULE_PKG_NOT_INSTALLABLE,
  SOLVER_RULE_PKG_NOTHING_PROVIDES_DEP,
  SOLVER_RULE_PKG_REQUIRES,
  SOLVER_RULE_PKG_SELF_CONFLICT,
  SOLVER_RULE_PKG_CONFLICTS,
  SOLVER_RULE_PKG_SAME_NAME,
  SOLVER_RULE_PKG_OBSOLETES,
  SOLVER_RULE_PKG_IMPLICIT_OBSOLETES,
  SOLVER_RULE_PKG_INSTALLED_OBSOLETES,
  SOLVER_RULE_UPDATE = 0x200,
  SOLVER_RULE_FEATURE = 0x300,
  SOLVER_RULE_JOB = 0x400,
  SOLVER_RULE_JOB_NOTHING_PROVIDES_DEP,
  SOLVER_RULE_JOB_PROVIDED_BY_SYSTEM,
  SOLVER_RULE_JOB_UNKNOWN_PACKAGE,
  SOLVER_RULE_JOB_UNSUPPORTED,
  SOLVER_RULE_DISTUPGRADE = 0x500,
  SOLVER_RULE_INFARCH = 0x600,
  SOLVER_RULE_CHOICE = 0x700,
  SOLVER_RULE_LEARNT = 0x800,
  SOLVER_RULE_BEST = 0x900,
  SOLVER_RULE_YUMOBS = 0xa00
} SolverRuleinfo;

#define SOLVER_RULE_TYPEMASK    0xff00

struct _Solver;

/*-------------------------------------------------------------------
 * disable rule
 */

static inline void
solver_disablerule(struct _Solver *solv, Rule *r)
{
  if (r->d >= 0)
    r->d = -r->d - 1;
}

/*-------------------------------------------------------------------
 * enable rule
 */

static inline void
solver_enablerule(struct _Solver *solv, Rule *r)
{
  if (r->d < 0)
    r->d = -r->d - 1;
}

extern Rule *solver_addrule(struct _Solver *solv, Id p, Id p2, Id d);
extern void solver_unifyrules(struct _Solver *solv);
extern int solver_rulecmp(struct _Solver *solv, Rule *r1, Rule *r2);
extern void solver_shrinkrules(struct _Solver *solv, int nrules);

/* pkg rules */
extern void solver_addpkgrulesforsolvable(struct _Solver *solv, Solvable *s, Map *m);
extern void solver_addpkgrulesforweak(struct _Solver *solv, Map *m);
extern void solver_addpkgrulesforlinked(struct _Solver *solv, Map *m);
extern void solver_addpkgrulesforupdaters(struct _Solver *solv, Solvable *s, Map *m, int allow_all);

/* update/feature rules */
extern void solver_addupdaterule(struct _Solver *solv, Solvable *s, int allow_all);

/* infarch rules */
extern void solver_addinfarchrules(struct _Solver *solv, Map *addedmap);

/* dup rules */
extern void solver_createdupmaps(struct _Solver *solv);
extern void solver_freedupmaps(struct _Solver *solv);
extern void solver_addduprules(struct _Solver *solv, Map *addedmap);

/* choice rules */
extern void solver_addchoicerules(struct _Solver *solv);
extern void solver_disablechoicerules(struct _Solver *solv, Rule *r);

/* best rules */
extern void solver_addbestrules(struct _Solver *solv, int havebestinstalljobs);

/* yumobs rules */
extern void solver_addyumobsrules(struct _Solver *solv);

/* policy rule disabling/reenabling */
extern void solver_disablepolicyrules(struct _Solver *solv);
extern void solver_reenablepolicyrules(struct _Solver *solv, int jobidx);
extern void solver_reenablepolicyrules_cleandeps(struct _Solver *solv, Id pkg);

/* rule info */
extern int solver_allruleinfos(struct _Solver *solv, Id rid, Queue *rq);
extern SolverRuleinfo solver_ruleinfo(struct _Solver *solv, Id rid, Id *fromp, Id *top, Id *depp);
extern SolverRuleinfo solver_ruleclass(struct _Solver *solv, Id rid);
extern void solver_ruleliterals(struct _Solver *solv, Id rid, Queue *q);
extern int  solver_rule2jobidx(struct _Solver *solv, Id rid);
extern Id   solver_rule2job(struct _Solver *solv, Id rid, Id *whatp);
extern Id   solver_rule2solvable(struct _Solver *solv, Id rid);
extern void solver_rule2rules(struct _Solver *solv, Id rid, Queue *q, int recursive);
extern Id   solver_rule2pkgrule(struct _Solver *solv, Id rid);

/* orphan handling */
extern void solver_breakorphans(struct _Solver *solv);
extern void solver_check_brokenorphanrules(struct _Solver *solv, Queue *dq);


/* legacy */
#define SOLVER_RULE_RPM SOLVER_RULE_PKG
#define SOLVER_RULE_RPM_NOT_INSTALLABLE SOLVER_RULE_PKG_NOT_INSTALLABLE
#define SOLVER_RULE_RPM_NOTHING_PROVIDES_DEP SOLVER_RULE_PKG_NOTHING_PROVIDES_DEP
#define SOLVER_RULE_RPM_PACKAGE_REQUIRES SOLVER_RULE_PKG_REQUIRES
#define SOLVER_RULE_RPM_SELF_CONFLICT SOLVER_RULE_PKG_SELF_CONFLICT
#define SOLVER_RULE_RPM_PACKAGE_CONFLICT SOLVER_RULE_PKG_CONFLICTS
#define SOLVER_RULE_RPM_SAME_NAME SOLVER_RULE_PKG_SAME_NAME
#define SOLVER_RULE_RPM_PACKAGE_OBSOLETES SOLVER_RULE_PKG_OBSOLETES
#define SOLVER_RULE_RPM_IMPLICIT_OBSOLETES SOLVER_RULE_PKG_IMPLICIT_OBSOLETES
#define SOLVER_RULE_RPM_INSTALLEDPKG_OBSOLETES SOLVER_RULE_PKG_INSTALLED_OBSOLETES

#ifdef __cplusplus
}
#endif

#endif

