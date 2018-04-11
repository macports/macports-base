/*
 * Copyright (c) 2007-2009, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * rules.c
 *
 * SAT based dependency solver
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <assert.h>

#include "solver.h"
#include "solver_private.h"
#include "bitmap.h"
#include "pool.h"
#include "poolarch.h"
#include "util.h"
#include "evr.h"
#include "policy.h"
#include "solverdebug.h"
#include "linkedpkg.h"
#include "cplxdeps.h"

#define RULES_BLOCK 63

static void addpkgruleinfo(Solver *solv, Id p, Id p2, Id d, int type, Id dep);
static void solver_createcleandepsmap(Solver *solv, Map *cleandepsmap, int unneeded);

/*-------------------------------------------------------------------
 * Check if dependency is possible
 *
 * mirrors solver_dep_fulfilled but uses map m instead of the decisionmap.
 * used in solver_addpkgrulesforweak and solver_createcleandepsmap.
 */

static inline int
dep_possible(Solver *solv, Id dep, Map *m)
{
  Pool *pool = solv->pool;
  Id p, pp;

  if (ISRELDEP(dep))
    {
      Reldep *rd = GETRELDEP(pool, dep);
      if (rd->flags >= 8)
	 {
	  if (rd->flags == REL_AND || rd->flags == REL_COND)
	    {
	      if (!dep_possible(solv, rd->name, m))
		return 0;
	      return dep_possible(solv, rd->evr, m);
	    }
	  if (rd->flags == REL_OR)
	    {
	      if (dep_possible(solv, rd->name, m))
		return 1;
	      return dep_possible(solv, rd->evr, m);
	    }
	  if (rd->flags == REL_NAMESPACE && rd->name == NAMESPACE_SPLITPROVIDES)
	    return solver_splitprovides(solv, rd->evr, m);
	}
    }
  FOR_PROVIDES(p, pp, dep)
    {
      if (MAPTST(m, p))
	return 1;
    }
  return 0;
}

static inline int
is_otherproviders_dep(Pool *pool, Id dep)
{
  if (ISRELDEP(dep))
    {
      Reldep *rd = GETRELDEP(pool, dep);
      if (rd->flags == REL_NAMESPACE && rd->name == NAMESPACE_OTHERPROVIDERS)
	return 1;
    }
  return 0;
}

/********************************************************************
 *
 * Rule handling
 *
 * - unify rules, remove duplicates
 */

/*-------------------------------------------------------------------
 *
 * compare rules for unification sort
 *
 */

static int
unifyrules_sortcmp(const void *ap, const void *bp, void *dp)
{
  Pool *pool = dp;
  Rule *a = (Rule *)ap;
  Rule *b = (Rule *)bp;
  Id *ad, *bd;
  int x;

  x = a->p - b->p;
  if (x)
    return x;			       /* p differs */

  /* identical p */
  if (a->d == 0 && b->d == 0)
    return a->w2 - b->w2;	       /* assertion: return w2 diff */

  if (a->d == 0)		       /* a is assertion, b not */
    {
      x = a->w2 - pool->whatprovidesdata[b->d];
      return x ? x : -1;
    }

  if (b->d == 0)		       /* b is assertion, a not */
    {
      x = pool->whatprovidesdata[a->d] - b->w2;
      return x ? x : 1;
    }

  /* compare whatprovidesdata */
  ad = pool->whatprovidesdata + a->d;
  bd = pool->whatprovidesdata + b->d;
  while (*bd)
    if ((x = *ad++ - *bd++) != 0)
      return x;
  return *ad;
}

int
solver_rulecmp(Solver *solv, Rule *r1, Rule *r2)
{
  return unifyrules_sortcmp(r1, r2, solv->pool);
}


/*-------------------------------------------------------------------
 *
 * unify rules
 * go over all rules and remove duplicates
 */

void
solver_unifyrules(Solver *solv)
{
  Pool *pool = solv->pool;
  int i, j;
  Rule *ir, *jr;

  if (solv->nrules <= 2)	       /* nothing to unify */
    return;

  /* sort rules first */
  solv_sort(solv->rules + 1, solv->nrules - 1, sizeof(Rule), unifyrules_sortcmp, solv->pool);

  /* prune rules
   * i = unpruned
   * j = pruned
   */
  jr = 0;
  for (i = j = 1, ir = solv->rules + i; i < solv->nrules; i++, ir++)
    {
      if (jr && !unifyrules_sortcmp(ir, jr, pool))
	continue;		       /* prune! */
      jr = solv->rules + j++;	       /* keep! */
      if (ir != jr)
        *jr = *ir;
    }

  /* reduced count from nrules to j rules */
  POOL_DEBUG(SOLV_DEBUG_STATS, "pruned rules from %d to %d\n", solv->nrules, j);

  /* adapt rule buffer */
  solv->nrules = j;
  solv->rules = solv_extend_resize(solv->rules, solv->nrules, sizeof(Rule), RULES_BLOCK);

  /*
   * debug: log rule statistics
   */
  IF_POOLDEBUG (SOLV_DEBUG_STATS)
    {
      int binr = 0;
      int lits = 0;
      Id *dp;
      Rule *r;

      for (i = 1; i < solv->nrules; i++)
	{
	  r = solv->rules + i;
	  if (r->d == 0)
	    binr++;
	  else
	    {
	      dp = solv->pool->whatprovidesdata + r->d;
	      while (*dp++)
		lits++;
	    }
	}
      POOL_DEBUG(SOLV_DEBUG_STATS, "  binary: %d\n", binr);
      POOL_DEBUG(SOLV_DEBUG_STATS, "  normal: %d, %d literals\n", solv->nrules - 1 - binr, lits);
    }
}

#if 0

/*
 * hash rule
 */

static Hashval
hashrule(Solver *solv, Id p, Id d, int n)
{
  unsigned int x = (unsigned int)p;
  int *dp;

  if (n <= 1)
    return (x * 37) ^ (unsigned int)d;
  dp = solv->pool->whatprovidesdata + d;
  while (*dp)
    x = (x * 37) ^ (unsigned int)*dp++;
  return x;
}
#endif


/*-------------------------------------------------------------------
 *
 */

/*
 * add rule
 *
 * A requires b, b provided by B1,B2,B3 => (-A|B1|B2|B3)
 *
 * p < 0  : pkg id of A
 * d > 0  : Offset in whatprovidesdata (list of providers of b)
 *
 * A conflicts b, b provided by B1,B2,B3 => (-A|-B1), (-A|-B2), (-A|-B3)
 * p < 0  : pkg id of A
 * p2 < 0 : Id of solvable (e.g. B1)
 *
 * d == 0, p2 == 0: unary rule, assertion => (A) or (-A)
 *
 *   Install:    p > 0, d = 0   (A)             user requested install
 *   Remove:     p < 0, d = 0   (-A)            user requested remove (also: uninstallable)
 *   Requires:   p < 0, d > 0   (-A|B1|B2|...)  d: <list of providers for requirement of p>
 *   Updates:    p > 0, d > 0   (A|B1|B2|...)   d: <list of updates for solvable p>
 *   Conflicts:  p < 0, p2 < 0  (-A|-B)         either p (conflict issuer) or d (conflict provider) (binary rule)
 *                                              also used for obsoletes
 *   No-op ?:    p = 0, d = 0   (null)          (used as placeholder in update/feature rules)
 *
 *   resulting watches:
 *   ------------------
 *   Direct assertion (no watch needed) --> d = 0, w1 = p, w2 = 0
 *   Binary rule: p = first literal, d = 0, w2 = second literal, w1 = p
 *   every other : w1 = p, w2 = whatprovidesdata[d];
 *
 *   always returns a rule for non-pkg rules
 */

Rule *
solver_addrule(Solver *solv, Id p, Id p2, Id d)
{
  Pool *pool = solv->pool;
  Rule *r;

  if (d)
    {
      assert(!p2 && d > 0);
      if (!pool->whatprovidesdata[d])
	d = 0;
      else if (!pool->whatprovidesdata[d + 1])
	{
	  p2 = pool->whatprovidesdata[d];
	  d = 0;
	}
    }

  /* now we have two cases:
   * 1 or 2 literals:    d = 0, p, p2 contain the literals
   * 3 or more literals: d > 0, p2 == 0, d is offset into whatprovidesdata
   */

  /* it often happenes that requires lead to adding the same pkg rule
   * multiple times, so we prune those duplicates right away to make
   * the work for unifyrules a bit easier */
  if (!solv->pkgrules_end)		/* we add pkg rules */
    {
      r = solv->rules + solv->nrules - 1;
      if (d)
	{
	  Id *dp;
	  /* check if rule is identical */
	  if (r->p == p)
	    {
	      Id *dp2;
	      if (r->d == d)
		return r;
	      dp2 = pool->whatprovidesdata + r->d;
	      for (dp = pool->whatprovidesdata + d; *dp; dp++, dp2++)
		if (*dp != *dp2)
		  break;
	      if (*dp == *dp2)
		return r;
	    }
	  /* check if rule is self-fulfilling */
	  for (dp = pool->whatprovidesdata + d; *dp; dp++)
	    if (*dp == -p)
	      return 0;			/* rule is self-fulfilling */
	}
      else
	{
	  if (p2 && p > p2)
	    {
	      Id o = p;			/* switch p1 and p2 */
	      p = p2;
	      p2 = o;
	    }
	  if (r->p == p && !r->d && r->w2 == p2)
	    return r;
	  if (p == -p2)
	    return 0;			/* rule is self-fulfilling */
	}
    }

  solv->rules = solv_extend(solv->rules, solv->nrules, 1, sizeof(Rule), RULES_BLOCK);
  r = solv->rules + solv->nrules++;    /* point to rule space */
  r->p = p;
  r->d = d;
  r->w1 = p;
  r->w2 = d ? pool->whatprovidesdata[d] : p2;
  r->n1 = 0;
  r->n2 = 0;
  IF_POOLDEBUG (SOLV_DEBUG_RULE_CREATION)
    {
      POOL_DEBUG(SOLV_DEBUG_RULE_CREATION, "  Add rule: ");
      solver_printrule(solv, SOLV_DEBUG_RULE_CREATION, r);
    }
  return r;
}


void
solver_shrinkrules(Solver *solv, int nrules)
{
  solv->nrules = nrules;
  solv->rules = solv_extend_resize(solv->rules, solv->nrules, sizeof(Rule), RULES_BLOCK);
}

/******************************************************************************
 ***
 *** pkg rule part: create rules representing the package dependencies
 ***
 ***/

/*
 *  special multiversion patch conflict handling:
 *  a patch conflict is also satisfied if some other
 *  version with the same name/arch that doesn't conflict
 *  gets installed. The generated rule is thus:
 *  -patch|-cpack|opack1|opack2|...
 */
static Id
makemultiversionconflict(Solver *solv, Id n, Id con)
{
  Pool *pool = solv->pool;
  Solvable *s, *sn;
  Queue q;
  Id p, pp, qbuf[64];

  sn = pool->solvables + n;
  queue_init_buffer(&q, qbuf, sizeof(qbuf)/sizeof(*qbuf));
  queue_push(&q, -n);
  FOR_PROVIDES(p, pp, sn->name)
    {
      s = pool->solvables + p;
      if (s->name != sn->name || s->arch != sn->arch)
	continue;
      if (!MAPTST(&solv->multiversion, p))
	continue;
      if (pool_match_nevr(pool, pool->solvables + p, con))
	continue;
      /* here we have a multiversion solvable that doesn't conflict */
      /* thus we're not in conflict if it is installed */
      queue_push(&q, p);
    }
  if (q.count == 1)
    n = 0;	/* no other package found, normal conflict handling */
  else
    n = pool_queuetowhatprovides(pool, &q);
  queue_free(&q);
  return n;
}

static inline void
addpkgrule(Solver *solv, Id p, Id p2, Id d, int type, Id dep)
{
  if (!solv->ruleinfoq)
    solver_addrule(solv, p, p2, d);
  else
    addpkgruleinfo(solv, p, p2, d, type, dep);
}

#ifdef ENABLE_LINKED_PKGS

static void
addlinks(Solver *solv, Solvable *s, Id req, Queue *qr, Id prv, Queue *qp, Map *m, Queue *workq)
{
  Pool *pool = solv->pool;
  int i;
  if (!qr->count)
    return;
#if 0
  printf("ADDLINKS %s\n -> %s\n", pool_solvable2str(pool, s), pool_dep2str(pool, req));
  for (i = 0; i < qr->count; i++)
    printf("    - %s\n", pool_solvid2str(pool, qr->elements[i]));
  printf(" <- %s\n", pool_dep2str(pool, prv));
  for (i = 0; i < qp->count; i++)
    printf("    - %s\n", pool_solvid2str(pool, qp->elements[i]));
#endif

  if (qr->count == 1)
    addpkgrule(solv, -(s - pool->solvables), qr->elements[0], 0, SOLVER_RULE_PKG_REQUIRES, req);
  else
    addpkgrule(solv, -(s - pool->solvables), 0, pool_queuetowhatprovides(pool, qr), SOLVER_RULE_PKG_REQUIRES, req);
  if (qp->count > 1)
    {
      Id d = pool_queuetowhatprovides(pool, qp);
      for (i = 0; i < qr->count; i++)
	addpkgrule(solv, -qr->elements[i], 0, d, SOLVER_RULE_PKG_REQUIRES, prv);
    }
  else if (qp->count)
    {
      for (i = 0; i < qr->count; i++)
	addpkgrule(solv, -qr->elements[i], qp->elements[0], 0, SOLVER_RULE_PKG_REQUIRES, prv);
    }
  if (!m)
    return;	/* nothing more to do if called from getpkgruleinfos() */
  for (i = 0; i < qr->count; i++)
    if (!MAPTST(m, qr->elements[i]))
      queue_push(workq, qr->elements[i]);
  for (i = 0; i < qp->count; i++)
    if (!MAPTST(m, qp->elements[i]))
      queue_push(workq, qp->elements[i]);
  if (solv->installed && s->repo == solv->installed)
    {
      Repo *installed = solv->installed;
      /* record installed buddies */
      if (!solv->instbuddy)
        solv->instbuddy = solv_calloc(installed->end - installed->start, sizeof(Id));
      if (qr->count == 1)
        solv->instbuddy[s - pool->solvables - installed->start] = qr->elements[0];
      for (i = 0; i < qr->count; i++)
	{
	  Id p = qr->elements[i];
	  if (pool->solvables[p].repo != installed)
	    continue;	/* huh? */
	  if (qp->count > 1 || (solv->instbuddy[p - installed->start] != 0 && solv->instbuddy[p - installed->start] != s - pool->solvables))
	    solv->instbuddy[p - installed->start] = 1;	/* 1: ambiguous buddy */
	  else
	    solv->instbuddy[p - installed->start] = s - pool->solvables;
	}
    }
}

static void
add_package_link(Solver *solv, Solvable *s, Map *m, Queue *workq)
{
  Queue qr, qp;
  Id req = 0, prv = 0;
  queue_init(&qr);
  queue_init(&qp);
  find_package_link(solv->pool, s, &req, &qr, &prv, &qp);
  if (qr.count)
    addlinks(solv, s, req, &qr, prv, &qp, m, workq);
  queue_free(&qr);
  queue_free(&qp);
}

#endif

#ifdef ENABLE_COMPLEX_DEPS

static void
add_complex_deprules(Solver *solv, Id p, Id dep, int type, int dontfix, Queue *workq, Map *m)
{
  Pool *pool = solv->pool;
  Repo *installed = solv->installed;
  int i, j, flags;
  Queue bq;

  queue_init(&bq);
  flags = dontfix ? CPLXDEPS_DONTFIX : 0;
  /* CNF expansion for requires, DNF + INVERT expansion for conflicts */
  if (type == SOLVER_RULE_PKG_CONFLICTS)
    flags |= CPLXDEPS_TODNF | CPLXDEPS_EXPAND | CPLXDEPS_INVERT;

  i = pool_normalize_complex_dep(pool, dep, &bq, flags);
  /* handle special cases */
  if (i == 0)
    {
      if (dontfix)
	{
	  POOL_DEBUG(SOLV_DEBUG_RULE_CREATION, "ignoring broken dependency %s of installed package %s\n", pool_dep2str(pool, dep), pool_solvid2str(pool, p));
	}
      else
	{
	  POOL_DEBUG(SOLV_DEBUG_RULE_CREATION, "package %s [%d] is not installable (%s)\n", pool_solvid2str(pool, p), p, pool_dep2str(pool, dep));
	  addpkgrule(solv, -p, 0, 0, type == SOLVER_RULE_PKG_REQUIRES ? SOLVER_RULE_PKG_NOTHING_PROVIDES_DEP : type, dep);
	}
      queue_free(&bq);
      return;
    }
  if (i == 1)
    {
      queue_free(&bq);
      return;
    }

  /* go through all blocks and add a rule for each block */
  for (i = 0; i < bq.count; i++)
    {
      if (!bq.elements[i])
	continue;	/* huh? */
      if (bq.elements[i] == pool->nsolvables)
	{
	  /* conventional requires (cannot be a conflicts as they have been expanded) */
	  Id *dp = pool->whatprovidesdata + bq.elements[i + 1];
	  i += 2;
	  if (dontfix)
	    {
	      for (j = 0; dp[j] != 0; j++)
		if (pool->solvables[dp[j]].repo == installed)
		  break;		/* provider was installed */
	      if (!dp[j])
	        continue;
	    }
	  /* check if the rule contains both p and -p */
	  for (j = 0; dp[j] != 0; j++)
	    if (dp[j] == p)
	      break;
	  if (dp[j])
	    continue;
	  addpkgrule(solv, -p, 0, dp - pool->whatprovidesdata, SOLVER_RULE_PKG_REQUIRES, dep);
	  /* push all non-visited providers on the work queue */
	  if (m)
	    for (; *dp; dp++)
	      if (!MAPTST(m, *dp))
		queue_push(workq, *dp);
	  continue;
	}
      if (!bq.elements[i + 1])
	{
	  Id p2 = bq.elements[i++];
	  /* simple rule with just two literals, we'll add a (-p, p2) rule */
	  if (dontfix)
	    {
	      if (p2 < 0 && pool->solvables[-p2].repo == installed)
		continue;
	      if (p2 > 0 && pool->solvables[p2].repo != installed)
		continue;
	    }
	  if (-p == p2)
	    {
	      if (type == SOLVER_RULE_PKG_CONFLICTS)
		{
		  if (pool->forbidselfconflicts && !is_otherproviders_dep(pool, dep))
		    addpkgrule(solv, -p, 0, 0, SOLVER_RULE_PKG_SELF_CONFLICT, dep);
		  continue;
		}
	      addpkgrule(solv, -p, 0, 0, type, dep);
	      continue;
	    }
	  /* check if the rule contains both p and -p */
	  if (p == p2)
	    continue;
	  addpkgrule(solv, -p, p2, 0, type, dep);
	  if (m && p2 > 0 && !MAPTST(m, p2))
	    queue_push(workq, p2);
	}
      else
	{
	  Id *qele;
	  int qcnt;

	  qele = bq.elements + i;
	  qcnt = i;
	  while (bq.elements[i])
	     i++;
	  qcnt = i - qcnt;
	  if (dontfix)
	    {
	      for (j = 0; j < qcnt; j++)
		{
		  if (qele[j] > 0 && pool->solvables[qele[j]].repo == installed)
		    break;
		  if (qele[j] < 0 && pool->solvables[-qele[j]].repo != installed)
		    break;
		}
	      if (j == qcnt)
	        continue;
	    }
	  /* add -p to (ordered) rule (overwriting the trailing zero) */
	  for (j = 0; ; j++)
	    {
	      if (j == qcnt || qele[j] > -p)
		{
		  if (j < qcnt)
		    memmove(qele + j + 1, qele + j, (qcnt - j) * sizeof(Id));
		  qele[j] = -p;
		  qcnt++;
		  break;
		}
	      if (qele[j] == -p)
		break;
	    }
	  /* check if the rule contains both p and -p */
	  for (j = 0; j < qcnt; j++)
	    if (qele[j] == p)
	      break;
	  if (j < qcnt)
	    continue;
	  addpkgrule(solv, qele[0], 0, pool_ids2whatprovides(pool, qele + 1, qcnt - 1), type, dep);
	  if (m)
	    for (j = 0; j < qcnt; j++)
	      if (qele[j] > 0 && !MAPTST(m, qele[j]))
		queue_push(workq, qele[j]);
	}
    }
  queue_free(&bq);
}

#endif

/*-------------------------------------------------------------------
 *
 * add (install) rules for solvable
 *
 * s: Solvable for which to add rules
 * m: m[s] = 1 for solvables which have rules, prevent rule duplication
 *
 * Algorithm: 'visit all nodes of a graph'. The graph nodes are
 *  solvables, the edges their dependencies.
 *  Starting from an installed solvable, this will create all rules
 *  representing the graph created by the solvables dependencies.
 *
 * for unfulfilled requirements, conflicts, obsoletes,....
 * add a negative assertion for solvables that are not installable
 *
 * It will also create rules for all solvables referenced by 's'
 *  i.e. descend to all providers of requirements of 's'
 *
 */

void
solver_addpkgrulesforsolvable(Solver *solv, Solvable *s, Map *m)
{
  Pool *pool = solv->pool;
  Repo *installed = solv->installed;

  Queue workq;	/* list of solvables we still have to work on */
  Id workqbuf[64];

  int i;
  int dontfix;		/* ignore dependency errors for installed solvables */
  Id req, *reqp;
  Id con, *conp;
  Id obs, *obsp;
  Id rec, *recp;
  Id sug, *sugp;
  Id p, pp;		/* whatprovides loops */
  Id *dp;		/* ptr to 'whatprovides' */
  Id n;			/* Id for current solvable 's' */

  queue_init_buffer(&workq, workqbuf, sizeof(workqbuf)/sizeof(*workqbuf));
  queue_push(&workq, s - pool->solvables);	/* push solvable Id to work queue */

  /* loop until there's no more work left */
  while (workq.count)
    {
      /*
       * n: Id of solvable
       * s: Pointer to solvable
       */

      n = queue_shift(&workq);		/* 'pop' next solvable to work on from queue */
      if (m)
	{
	  if (MAPTST(m, n))		/* continue if already visited */
	    continue;
	  MAPSET(m, n);			/* mark as visited */
	}

      s = pool->solvables + n;

      dontfix = 0;
      if (installed			/* Installed system available */
	  && s->repo == installed	/* solvable is installed */
	  && !solv->fixmap_all		/* NOT repair errors in dependency graph */
	  && !(solv->fixmap.size && MAPTST(&solv->fixmap, n - installed->start)))
        {
	  dontfix = 1;			/* dont care about broken deps */
        }

      if (!dontfix)
	{
	  if (s->arch == ARCH_SRC || s->arch == ARCH_NOSRC
		? pool_disabled_solvable(pool, s)
		: !pool_installable(pool, s))
	    {
	      POOL_DEBUG(SOLV_DEBUG_RULE_CREATION, "package %s [%d] is not installable\n", pool_solvid2str(pool, n), n);
	      addpkgrule(solv, -n, 0, 0, SOLVER_RULE_PKG_NOT_INSTALLABLE, 0);
	    }
	}

#ifdef ENABLE_LINKED_PKGS
      /* add pseudo-package <-> real-package links */
      if (has_package_link(pool, s))
        add_package_link(solv, s, m, &workq);
#endif

      /*-----------------------------------------
       * check requires of s
       */

      if (s->requires)
	{
	  reqp = s->repo->idarraydata + s->requires;
	  while ((req = *reqp++) != 0)            /* go through all requires */
	    {
	      if (req == SOLVABLE_PREREQMARKER)   /* skip the marker */
		continue;

#ifdef ENABLE_COMPLEX_DEPS
	      if (pool_is_complex_dep(pool, req))
		{
		  /* we have AND/COND deps, normalize */
		  add_complex_deprules(solv, n, req, SOLVER_RULE_PKG_REQUIRES, dontfix, &workq, m);
		  continue;
		}
#endif

	      /* find list of solvables providing 'req' */
	      dp = pool_whatprovides_ptr(pool, req);

	      if (*dp == SYSTEMSOLVABLE)	  /* always installed */
		continue;

	      if (dontfix)
		{
		  /* the strategy here is to not insist on dependencies
                   * that are already broken. so if we find one provider
                   * that was already installed, we know that the
                   * dependency was not broken before so we enforce it */
		  for (i = 0; (p = dp[i]) != 0; i++)
		    if (pool->solvables[p].repo == installed)
		      break;		/* found installed provider */
		  if (!p)
		    {
		      /* didn't find an installed provider: previously broken dependency */
		      POOL_DEBUG(SOLV_DEBUG_RULE_CREATION, "ignoring broken requires %s of installed package %s\n", pool_dep2str(pool, req), pool_solvable2str(pool, s));
		      continue;
		    }
		}

	      if (!*dp)
		{
		  POOL_DEBUG(SOLV_DEBUG_RULE_CREATION, "package %s [%d] is not installable (%s)\n", pool_solvid2str(pool, n), n, pool_dep2str(pool, req));
		  addpkgrule(solv, -n, 0, 0, SOLVER_RULE_PKG_NOTHING_PROVIDES_DEP, req);
		  continue;
		}

	      for (i = 0; dp[i] != 0; i++)
	        if (n == dp[i])
		  break;
	      if (dp[i])
		continue;		/* provided by itself, no need to add rule */

	      IF_POOLDEBUG (SOLV_DEBUG_RULE_CREATION)
	        {
		  POOL_DEBUG(SOLV_DEBUG_RULE_CREATION,"  %s requires %s\n", pool_solvable2str(pool, s), pool_dep2str(pool, req));
		  for (i = 0; dp[i]; i++)
		    POOL_DEBUG(SOLV_DEBUG_RULE_CREATION, "   provided by %s\n", pool_solvid2str(pool, dp[i]));
	        }

	      /* add 'requires' dependency */
              /* rule: (-requestor|provider1|provider2|...|providerN) */
	      addpkgrule(solv, -n, 0, dp - pool->whatprovidesdata, SOLVER_RULE_PKG_REQUIRES, req);

	      /* push all non-visited providers on the work queue */
	      if (m)
	        for (; *dp; dp++)
		  if (!MAPTST(m, *dp))
		    queue_push(&workq, *dp);
	    }
	}

      /* that's all we check for src packages */
      if (s->arch == ARCH_SRC || s->arch == ARCH_NOSRC)
	continue;

      /*-----------------------------------------
       * check conflicts of s
       */

      if (s->conflicts)
	{
	  int ispatch = 0;

	  /* we treat conflicts in patches a bit differen:
	   * - nevr matching
	   * - multiversion handling
	   * XXX: we should really handle this different, looking
	   * at the name is a bad hack
	   */
	  if (!strncmp("patch:", pool_id2str(pool, s->name), 6))
	    ispatch = 1;
	  conp = s->repo->idarraydata + s->conflicts;
	  /* foreach conflicts of 's' */
	  while ((con = *conp++) != 0)
	    {
#ifdef ENABLE_COMPLEX_DEPS
	      if (!ispatch && pool_is_complex_dep(pool, con))
		{
		  /* we have AND/COND deps, normalize */
		  add_complex_deprules(solv, n, con, SOLVER_RULE_PKG_CONFLICTS, dontfix, &workq, m);
		  continue;
		}
#endif
	      /* foreach providers of a conflict of 's' */
	      FOR_PROVIDES(p, pp, con)
		{
		  if (ispatch && !pool_match_nevr(pool, pool->solvables + p, con))
		    continue;
		  /* dontfix: dont care about conflicts with already installed packs */
		  if (dontfix && pool->solvables[p].repo == installed)
		    continue;
		  if (p == n)		/* p == n: self conflict */
		    {
		      if (!pool->forbidselfconflicts || is_otherproviders_dep(pool, con))
			continue;
		      addpkgrule(solv, -n, 0, 0, SOLVER_RULE_PKG_SELF_CONFLICT, con);
		      continue;
		    }
		  if (ispatch && solv->multiversion.size && MAPTST(&solv->multiversion, p) && ISRELDEP(con))
		    {
		      /* our patch conflicts with a multiversion package */
		      Id d = makemultiversionconflict(solv, p, con);
		      if (d)
			{
			  addpkgrule(solv, -n, 0, d, SOLVER_RULE_PKG_CONFLICTS, con);
			  continue;
			}
		    }
		  if (p == SYSTEMSOLVABLE)
		    p = 0;
                  /* rule: -n|-p: either solvable _or_ provider of conflict */
		  addpkgrule(solv, -n, -p, 0, SOLVER_RULE_PKG_CONFLICTS, con);
		}
	    }
	}

      /*-----------------------------------------
       * check obsoletes and implicit obsoletes of a package
       * if ignoreinstalledsobsoletes is not set, we're also checking
       * obsoletes of installed packages (like newer rpm versions)
       */
      if ((!installed || s->repo != installed) || !pool->noinstalledobsoletes)
	{
	  int multi = solv->multiversion.size && MAPTST(&solv->multiversion, n);
	  int isinstalled = (installed && s->repo == installed);
	  if (s->obsoletes && (!multi || solv->keepexplicitobsoletes))
	    {
	      obsp = s->repo->idarraydata + s->obsoletes;
	      /* foreach obsoletes */
	      while ((obs = *obsp++) != 0)
		{
		  /* foreach provider of an obsoletes of 's' */
		  FOR_PROVIDES(p, pp, obs)
		    {
		      Solvable *ps = pool->solvables + p;
		      if (p == n)
			continue;
		      if (isinstalled && dontfix && ps->repo == installed)
			continue;	/* don't repair installed/installed problems */
		      if (!pool->obsoleteusesprovides /* obsoletes are matched names, not provides */
			  && !pool_match_nevr(pool, ps, obs))
			continue;
		      if (pool->obsoleteusescolors && !pool_colormatch(pool, s, ps))
			continue;
		      if (p == SYSTEMSOLVABLE)
			p = 0;
		      if (!isinstalled)
			addpkgrule(solv, -n, -p, 0, SOLVER_RULE_PKG_OBSOLETES, obs);
		      else
			addpkgrule(solv, -n, -p, 0, SOLVER_RULE_PKG_INSTALLED_OBSOLETES, obs);
		    }
		}
	    }
	  /* check implicit obsoletes
           * for installed packages we only need to check installed/installed problems (and
           * only when dontfix is not set), as the others are picked up when looking at the
           * uninstalled package.
           */
	  if (!isinstalled || !dontfix)
	    {
	      FOR_PROVIDES(p, pp, s->name)
		{
		  Solvable *ps = pool->solvables + p;
		  if (p == n)
		    continue;
		  if (isinstalled && ps->repo != installed)
		    continue;
		  /* we still obsolete packages with same nevra, like rpm does */
		  /* (actually, rpm mixes those packages. yuck...) */
		  if (multi && (s->name != ps->name || s->evr != ps->evr || s->arch != ps->arch))
		    continue;
		  if (!pool->implicitobsoleteusesprovides && s->name != ps->name)
		    continue;
		  if (pool->implicitobsoleteusescolors && !pool_colormatch(pool, s, ps))
		    continue;
		  if (p == SYSTEMSOLVABLE)
		    p = 0;
		  if (s->name == ps->name)
		    {
		      /* optimization: do not add the same-name conflict rule if it was
		       * already added when we looket at the other package.
		       * (this assumes pool_colormatch is symmetric) */
		      if (p && m && ps->repo != installed && MAPTST(m, p) &&
			  (ps->arch != ARCH_SRC && ps->arch != ARCH_NOSRC) &&
			  !(solv->multiversion.size && MAPTST(&solv->multiversion, p)))
			continue;
		      addpkgrule(solv, -n, -p, 0, SOLVER_RULE_PKG_SAME_NAME, 0);
		    }
		  else
		    addpkgrule(solv, -n, -p, 0, SOLVER_RULE_PKG_IMPLICIT_OBSOLETES, s->name);
		}
	    }
	}

      if (m && pool->implicitobsoleteusescolors && (s->arch > pool->lastarch || pool->id2arch[s->arch] != 1))
	{
	  int a = pool->id2arch[s->arch];
	  /* check lock-step candidates */
	  FOR_PROVIDES(p, pp, s->name)
	    {
	      Solvable *ps = pool->solvables + p;
	      if (s->name != ps->name || s->evr != ps->evr || MAPTST(m, p))
		continue;
	      if (ps->arch > pool->lastarch || pool->id2arch[ps->arch] == 1 || pool->id2arch[ps->arch] >= a)
		continue;
	      queue_push(&workq, p);
	    }
	}

      /*-----------------------------------------
       * add recommends to the work queue
       */
      if (s->recommends && m)
	{
	  recp = s->repo->idarraydata + s->recommends;
	  while ((rec = *recp++) != 0)
	    {
	      FOR_PROVIDES(p, pp, rec)
		if (!MAPTST(m, p))
		  queue_push(&workq, p);
	    }
	}
      if (s->suggests && m)
	{
	  sugp = s->repo->idarraydata + s->suggests;
	  while ((sug = *sugp++) != 0)
	    {
	      FOR_PROVIDES(p, pp, sug)
		if (!MAPTST(m, p))
		  queue_push(&workq, p);
	    }
	}
    }
  queue_free(&workq);
}

#ifdef ENABLE_LINKED_PKGS
void
solver_addpkgrulesforlinked(Solver *solv, Map *m)
{
  Pool *pool = solv->pool;
  Solvable *s;
  int i, j;
  Queue qr;

  queue_init(&qr);
  for (i = 1; i < pool->nsolvables; i++)
    {
      if (MAPTST(m, i))
	continue;
      s = pool->solvables + i;
      if (!s->repo || s->repo == solv->installed)
	continue;
      if (!strchr(pool_id2str(pool, s->name), ':'))
	continue;
      if (!pool_installable(pool, s))
	continue;
      find_package_link(pool, s, 0, &qr, 0, 0);
      if (qr.count)
	{
	  for (j = 0; j < qr.count; j++)
	    if (MAPTST(m, qr.elements[j]))
	      {
	        solver_addpkgrulesforsolvable(solv, s, m);
	        break;
	      }
	  queue_empty(&qr);
	}
    }
  queue_free(&qr);
}
#endif

/*-------------------------------------------------------------------
 *
 * Add rules for packages possibly selected in by weak dependencies
 *
 * m: already added solvables
 */

void
solver_addpkgrulesforweak(Solver *solv, Map *m)
{
  Pool *pool = solv->pool;
  Solvable *s;
  Id sup, *supp;
  int i, n;

  /* foreach solvable in pool */
  for (i = n = 1; n < pool->nsolvables; i++, n++)
    {
      if (i == pool->nsolvables)		/* wrap i */
	i = 1;
      if (MAPTST(m, i))				/* already added that one */
	continue;

      s = pool->solvables + i;
      if (!s->repo)
	continue;
      if (s->repo != pool->installed && !pool_installable(pool, s))
	continue;	/* only look at installable ones */

      sup = 0;
      if (s->supplements)
	{
	  /* find possible supplements */
	  supp = s->repo->idarraydata + s->supplements;
	  while ((sup = *supp++) != 0)
	    if (dep_possible(solv, sup, m))
	      break;
	}

      /* if nothing found, check for enhances */
      if (!sup && s->enhances)
	{
	  supp = s->repo->idarraydata + s->enhances;
	  while ((sup = *supp++) != 0)
	    if (dep_possible(solv, sup, m))
	      break;
	}
      /* if nothing found, goto next solvables */
      if (!sup)
	continue;
      solver_addpkgrulesforsolvable(solv, s, m);
      n = 0;			/* check all solvables again because we added solvables to m */
    }
}


/*-------------------------------------------------------------------
 *
 * add package rules for possible updates
 *
 * s: solvable
 * m: map of already visited solvables
 * allow_all: 0 = dont allow downgrades, 1 = allow all candidates
 */

void
solver_addpkgrulesforupdaters(Solver *solv, Solvable *s, Map *m, int allow_all)
{
  Pool *pool = solv->pool;
  int i;
    /* queue and buffer for it */
  Queue qs;
  Id qsbuf[64];

  queue_init_buffer(&qs, qsbuf, sizeof(qsbuf)/sizeof(*qsbuf));
    /* find update candidates for 's' */
  policy_findupdatepackages(solv, s, &qs, allow_all);
    /* add rule for 's' if not already done */
  if (!MAPTST(m, s - pool->solvables))
    solver_addpkgrulesforsolvable(solv, s, m);
    /* foreach update candidate, add rule if not already done */
  for (i = 0; i < qs.count; i++)
    if (!MAPTST(m, qs.elements[i]))
      solver_addpkgrulesforsolvable(solv, pool->solvables + qs.elements[i], m);
  queue_free(&qs);
}


/***********************************************************************
 ***
 ***  Update/Feature rule part
 ***
 ***  Those rules make sure an installed package isn't silently deleted
 ***
 ***/

static Id
finddistupgradepackages(Solver *solv, Solvable *s, Queue *qs, int allow_all)
{
  Pool *pool = solv->pool;
  int i;

  policy_findupdatepackages(solv, s, qs, allow_all ? allow_all : 2);
  if (!qs->count)
    {
      if (allow_all)
        return 0;	/* orphaned, don't create feature rule */
      /* check if this is an orphaned package */
      policy_findupdatepackages(solv, s, qs, 1);
      if (!qs->count)
	return 0;	/* orphaned, don't create update rule */
      qs->count = 0;
      return -SYSTEMSOLVABLE;	/* supported but not installable */
    }
  if (allow_all)
    return s - pool->solvables;
  /* check if it is ok to keep the installed package */
  for (i = 0; i < qs->count; i++)
    {
      Solvable *ns = pool->solvables + qs->elements[i];
      if (s->evr == ns->evr && solvable_identical(s, ns))
        return s - pool->solvables;
    }
  /* nope, it must be some other package */
  return -SYSTEMSOLVABLE;
}

/* add packages from the dup repositories to the update candidates
 * this isn't needed for the global dup mode as all packages are
 * from dup repos in that case */
static void
addduppackages(Solver *solv, Solvable *s, Queue *qs)
{
  Queue dupqs;
  Id p, dupqsbuf[64];
  int i;
  int oldnoupdateprovide = solv->noupdateprovide;

  queue_init_buffer(&dupqs, dupqsbuf, sizeof(dupqsbuf)/sizeof(*dupqsbuf));
  solv->noupdateprovide = 1;
  policy_findupdatepackages(solv, s, &dupqs, 2);
  solv->noupdateprovide = oldnoupdateprovide;
  for (i = 0; i < dupqs.count; i++)
    {
      p = dupqs.elements[i];
      if (MAPTST(&solv->dupmap, p))
        queue_pushunique(qs, p);
    }
  queue_free(&dupqs);
}

/*-------------------------------------------------------------------
 *
 * add rule for update
 *   (A|A1|A2|A3...)  An = update candidates for A
 *
 * s = (installed) solvable
 */

void
solver_addupdaterule(Solver *solv, Solvable *s, int allow_all)
{
  /* installed packages get a special upgrade allowed rule */
  Pool *pool = solv->pool;
  Id p, d;
  Queue qs;
  Id qsbuf[64];

  queue_init_buffer(&qs, qsbuf, sizeof(qsbuf)/sizeof(*qsbuf));
  p = s - pool->solvables;
  /* find update candidates for 's' */
  if (solv->dupmap_all)
    p = finddistupgradepackages(solv, s, &qs, allow_all);
  else
    {
      policy_findupdatepackages(solv, s, &qs, allow_all);
      if (!allow_all && solv->dupinvolvedmap.size && MAPTST(&solv->dupinvolvedmap, p))
        addduppackages(solv, s, &qs);
    }

#ifdef ENABLE_LINKED_PKGS
  if (solv->instbuddy && solv->instbuddy[s - pool->solvables - solv->installed->start])
    {
      const char *name = pool_id2str(pool, s->name);
      if (strncmp(name, "pattern:", 8) == 0 || strncmp(name, "application:", 12) == 0)
	{
	  /* a linked pseudo package. As it is linked, we do not need an update rule */
	  /* nevertheless we set specialupdaters so we can update */
	  solver_addrule(solv, 0, 0, 0);
	  if (!allow_all && qs.count)
	    {
	      if (p != -SYSTEMSOLVABLE)
	        queue_unshift(&qs, p);
	      if (!solv->specialupdaters)
		solv->specialupdaters = solv_calloc(solv->installed->end - solv->installed->start, sizeof(Id));
	      solv->specialupdaters[s - pool->solvables - solv->installed->start] = pool_queuetowhatprovides(pool, &qs);
	    }
	  queue_free(&qs);
	  return;
	}
    }
#endif

  if (!allow_all && !p && solv->dupmap_all)
    {
      queue_push(&solv->orphaned, s - pool->solvables);		/* an orphaned package */
      if (solv->keep_orphans && !(solv->droporphanedmap_all || (solv->droporphanedmap.size && MAPTST(&solv->droporphanedmap, s - pool->solvables - solv->installed->start))))
	p = s - pool->solvables;	/* keep this orphaned package installed */
    }

  if (!allow_all && qs.count && solv->multiversion.size)
    {
      int i, j;

      for (i = 0; i < qs.count; i++)
	if (MAPTST(&solv->multiversion, qs.elements[i]))
	  break;
      if (i < qs.count)
	{
	  /* filter out all multiversion packages as they don't update */
	  d = pool_queuetowhatprovides(pool, &qs);
	  for (j = i; i < qs.count; i++)
	     {
	      if (MAPTST(&solv->multiversion, qs.elements[i]))
		{
		  Solvable *ps = pool->solvables + qs.elements[i];
		  /* if keepexplicitobsoletes is set and the name is different,
		   * we assume that there is an obsoletes. XXX: not 100% correct */
		  if (solv->keepexplicitobsoletes && ps->name != s->name)
		    {
		      qs.elements[j++] = qs.elements[i];
		      continue;
		    }
		  /* it's ok if they have same nevra */
		  if (ps->name != s->name || ps->evr != s->evr || ps->arch != s->arch)
		    continue;
		}
	      qs.elements[j++] = qs.elements[i];
	    }
	  if (j < qs.count)
	    {
	      if (d && solv->installed && s->repo == solv->installed &&
		  (solv->updatemap_all || (solv->updatemap.size && MAPTST(&solv->updatemap, s - pool->solvables - solv->installed->start))))
		{
		  if (!solv->specialupdaters)
		    solv->specialupdaters = solv_calloc(solv->installed->end - solv->installed->start, sizeof(Id));
		  solv->specialupdaters[s - pool->solvables - solv->installed->start] = d;
		}
	      if (j == 0 && p == -SYSTEMSOLVABLE && solv->dupmap_all)
		{
		  queue_push(&solv->orphaned, s - pool->solvables);	/* also treat as orphaned */
		  j = qs.count;
		}
	      qs.count = j;
	    }
	  else if (p != -SYSTEMSOLVABLE)
	    {
	      /* could fallthrough, but then we would do pool_queuetowhatprovides twice */
	      queue_free(&qs);
	      solver_addrule(solv, p, 0, d);	/* allow update of s */
	      return;
	    }
	}
    }
  if (qs.count && p == -SYSTEMSOLVABLE)
    p = queue_shift(&qs);
  if (qs.count > 1)
    {
      d = pool_queuetowhatprovides(pool, &qs);
      queue_free(&qs);
      solver_addrule(solv, p, 0, d);	/* allow update of s */
    }
  else
    {
      d = qs.count ? qs.elements[0] : 0;
      queue_free(&qs);
      solver_addrule(solv, p, d, 0);	/* allow update of s */
    }
}

static inline void
disableupdaterule(Solver *solv, Id p)
{
  Rule *r;

  MAPSET(&solv->noupdate, p - solv->installed->start);
  r = solv->rules + solv->updaterules + (p - solv->installed->start);
  if (r->p && r->d >= 0)
    solver_disablerule(solv, r);
  r = solv->rules + solv->featurerules + (p - solv->installed->start);
  if (r->p && r->d >= 0)
    solver_disablerule(solv, r);
  if (solv->bestrules_pkg)
    {
      int i, ni;
      ni = solv->bestrules_end - solv->bestrules;
      for (i = 0; i < ni; i++)
	if (solv->bestrules_pkg[i] == p)
	  solver_disablerule(solv, solv->rules + solv->bestrules + i);
    }
}

static inline void
reenableupdaterule(Solver *solv, Id p)
{
  Pool *pool = solv->pool;
  Rule *r;

  MAPCLR(&solv->noupdate, p - solv->installed->start);
  r = solv->rules + solv->updaterules + (p - solv->installed->start);
  if (r->p)
    {
      if (r->d < 0)
	{
	  solver_enablerule(solv, r);
	  IF_POOLDEBUG (SOLV_DEBUG_SOLUTIONS)
	    {
	      POOL_DEBUG(SOLV_DEBUG_SOLUTIONS, "@@@ re-enabling ");
	      solver_printruleclass(solv, SOLV_DEBUG_SOLUTIONS, r);
	    }
	}
    }
  else
    {
      r = solv->rules + solv->featurerules + (p - solv->installed->start);
      if (r->p && r->d < 0)
	{
	  solver_enablerule(solv, r);
	  IF_POOLDEBUG (SOLV_DEBUG_SOLUTIONS)
	    {
	      POOL_DEBUG(SOLV_DEBUG_SOLUTIONS, "@@@ re-enabling ");
	      solver_printruleclass(solv, SOLV_DEBUG_SOLUTIONS, r);
	    }
	}
    }
  if (solv->bestrules_pkg)
    {
      int i, ni;
      ni = solv->bestrules_end - solv->bestrules;
      for (i = 0; i < ni; i++)
	if (solv->bestrules_pkg[i] == p)
	  solver_enablerule(solv, solv->rules + solv->bestrules + i);
    }
}


/***********************************************************************
 ***
 ***  Infarch rule part
 ***
 ***  Infarch rules make sure the solver uses the best architecture of
 ***  a package if multiple archetectures are available
 ***
 ***/

void
solver_addinfarchrules(Solver *solv, Map *addedmap)
{
  Pool *pool = solv->pool;
  Repo *installed = pool->installed;
  int first, i, j;
  Id p, pp, a, aa, bestarch;
  Solvable *s, *ps, *bests;
  Queue badq, allowedarchs;
  Queue lsq;

  queue_init(&badq);
  queue_init(&allowedarchs);
  queue_init(&lsq);
  solv->infarchrules = solv->nrules;
  for (i = 1; i < pool->nsolvables; i++)
    {
      if (i == SYSTEMSOLVABLE || !MAPTST(addedmap, i))
	continue;
      s = pool->solvables + i;
      first = i;
      bestarch = 0;
      bests = 0;
      queue_empty(&allowedarchs);
      FOR_PROVIDES(p, pp, s->name)
	{
	  ps = pool->solvables + p;
	  if (ps->name != s->name || !MAPTST(addedmap, p))
	    continue;
	  if (p == i)
	    first = 0;
	  if (first)
	    break;
	  a = ps->arch;
	  a = (a <= pool->lastarch) ? pool->id2arch[a] : 0;
	  if (a != 1 && installed && ps->repo == installed)
	    {
	      if (!solv->dupmap_all && !(solv->dupinvolvedmap.size && MAPTST(&solv->dupinvolvedmap, p)))
	        queue_pushunique(&allowedarchs, ps->arch);	/* also ok to keep this architecture */
	      continue;		/* ignore installed solvables when calculating the best arch */
	    }
	  if (a && a != 1 && (!bestarch || a < bestarch))
	    {
	      bestarch = a;
	      bests = ps;
	    }
	}
      if (first)
	continue;

      /* speed up common case where installed package already has best arch */
      if (allowedarchs.count == 1 && bests && allowedarchs.elements[0] == bests->arch)
	allowedarchs.count--;	/* installed arch is best */

      if (allowedarchs.count && pool->implicitobsoleteusescolors && installed && bestarch)
	{
	  /* need an extra pass for lockstep checking: we only allow to keep an inferior arch
	   * if the corresponding installed package is not lock-stepped */
	  queue_empty(&allowedarchs);
	  FOR_PROVIDES(p, pp, s->name)
	    {
	      Id p2, pp2;
	      ps = pool->solvables + p;
	      if (ps->name != s->name || ps->repo != installed || !MAPTST(addedmap, p))
		continue;
	      if (solv->dupmap_all || (solv->dupinvolvedmap.size && MAPTST(&solv->dupinvolvedmap, p)))
		continue;
	      a = ps->arch;
	      a = (a <= pool->lastarch) ? pool->id2arch[a] : 0;
	      if (!a)
		{
		  queue_pushunique(&allowedarchs, ps->arch);	/* strange arch, allow */
		  continue;
		}
	      if (a == 1 || ((a ^ bestarch) & 0xffff0000) == 0)
		continue;
	      /* have installed package with inferior arch, check if lock-stepped */
	      FOR_PROVIDES(p2, pp2, s->name)
		{
		  Solvable *s2 = pool->solvables + p2;
		  Id a2;
		  if (p2 == p || s2->name != s->name || s2->evr != pool->solvables[p].evr || s2->arch == pool->solvables[p].arch)
		    continue;
		  a2 = s2->arch;
		  a2 = (a2 <= pool->lastarch) ? pool->id2arch[a2] : 0;
		  if (a2 && (a2 == 1 || ((a2 ^ bestarch) & 0xffff0000) == 0))
		    break;
		}
	      if (!p2)
		queue_pushunique(&allowedarchs, ps->arch);
	    }
	}

      /* find all bad packages */
      queue_empty(&badq);
      FOR_PROVIDES(p, pp, s->name)
	{
	  ps = pool->solvables + p;
	  if (ps->name != s->name || !MAPTST(addedmap, p))
	    continue;
	  a = ps->arch;
	  a = (a <= pool->lastarch) ? pool->id2arch[a] : 0;
	  if (a != 1 && bestarch && ((a ^ bestarch) & 0xffff0000) != 0)
	    {
	      if (installed && ps->repo == installed)
		{
		  if (pool->implicitobsoleteusescolors)
		    queue_push(&badq, p);		/* special lock-step handling, see below */
		  continue;	/* always ok to keep an installed package */
		}
	      for (j = 0; j < allowedarchs.count; j++)
		{
		  aa = allowedarchs.elements[j];
		  if (ps->arch == aa)
		    break;
		  aa = (aa <= pool->lastarch) ? pool->id2arch[aa] : 0;
		  if (aa && ((a ^ aa) & 0xffff0000) == 0)
		    break;	/* compatible */
		}
	      if (j == allowedarchs.count)
		queue_push(&badq, p);
	    }
	}

      /* block all solvables in the badq! */
      for (j = 0; j < badq.count; j++)
	{
	  p = badq.elements[j];
	  /* lock-step */
	  if (pool->implicitobsoleteusescolors)
	    {
	      Id p2;
	      int haveinstalled = 0;
	      queue_empty(&lsq);
	      FOR_PROVIDES(p2, pp, s->name)
		{
		  Solvable *s2 = pool->solvables + p2;
		  if (p2 == p || s2->name != s->name || s2->evr != pool->solvables[p].evr || s2->arch == pool->solvables[p].arch)
		    continue;
		  a = s2->arch;
		  a = (a <= pool->lastarch) ? pool->id2arch[a] : 0;
		  if (a && (a == 1 || ((a ^ bestarch) & 0xffff000) == 0))
		    {
		      queue_push(&lsq, p2);
		      if (installed && s2->repo == installed)
			haveinstalled = 1;
		    }
		}
	      if (installed && pool->solvables[p].repo == installed && !haveinstalled)
		continue;	/* installed package not in lock-step */
	    }
	  if (lsq.count < 2)
	    solver_addrule(solv, -p, lsq.count ? lsq.elements[0] : 0, 0);
	  else
	    solver_addrule(solv, -p, 0, pool_queuetowhatprovides(pool, &lsq));
	}
    }
  queue_free(&lsq);
  queue_free(&badq);
  queue_free(&allowedarchs);
  solv->infarchrules_end = solv->nrules;
}

static inline void
disableinfarchrule(Solver *solv, Id name)
{
  Pool *pool = solv->pool;
  Rule *r;
  int i;
  for (i = solv->infarchrules, r = solv->rules + i; i < solv->infarchrules_end; i++, r++)
    {
      if (r->p < 0 && r->d >= 0 && pool->solvables[-r->p].name == name)
        solver_disablerule(solv, r);
    }
}

static inline void
reenableinfarchrule(Solver *solv, Id name)
{
  Pool *pool = solv->pool;
  Rule *r;
  int i;
  for (i = solv->infarchrules, r = solv->rules + i; i < solv->infarchrules_end; i++, r++)
    {
      if (r->p < 0 && r->d < 0 && pool->solvables[-r->p].name == name)
        {
          solver_enablerule(solv, r);
          IF_POOLDEBUG (SOLV_DEBUG_SOLUTIONS)
            {
              POOL_DEBUG(SOLV_DEBUG_SOLUTIONS, "@@@ re-enabling ");
              solver_printruleclass(solv, SOLV_DEBUG_SOLUTIONS, r);
            }
        }
    }
}


/***********************************************************************
 ***
 ***  Dup rule part
 ***
 ***  Dup rules make sure a package is selected from the specified dup
 ***  repositories if an update candidate is included in one of them.
 ***
 ***/

static inline void
add_cleandeps_package(Solver *solv, Id p)
{
  if (!solv->cleandeps_updatepkgs)
    {
      solv->cleandeps_updatepkgs = solv_calloc(1, sizeof(Queue));
      queue_init(solv->cleandeps_updatepkgs);
    }
  queue_pushunique(solv->cleandeps_updatepkgs, p);
}

static inline void
solver_addtodupmaps(Solver *solv, Id p, Id how, int targeted)
{
  Pool *pool = solv->pool;
  Solvable *ps, *s = pool->solvables + p;
  Repo *installed = solv->installed;
  Id pi, pip, obs, *obsp;

  MAPSET(&solv->dupinvolvedmap, p);
  if (targeted)
    MAPSET(&solv->dupmap, p);
  FOR_PROVIDES(pi, pip, s->name)
    {
      ps = pool->solvables + pi;
      if (ps->name != s->name)
	continue;
      MAPSET(&solv->dupinvolvedmap, pi);
      if (targeted && ps->repo == installed && solv->obsoletes && solv->obsoletes[pi - installed->start])
	{
	  Id *opp, pi2;
	  for (opp = solv->obsoletes_data + solv->obsoletes[pi - installed->start]; (pi2 = *opp++) != 0;)
	    if (pool->solvables[pi2].repo != installed)
	      MAPSET(&solv->dupinvolvedmap, pi2);
	}
      if (ps->repo == installed && (how & SOLVER_FORCEBEST) != 0)
	{
	  if (!solv->bestupdatemap.size)
	    map_grow(&solv->bestupdatemap, installed->end - installed->start);
	  MAPSET(&solv->bestupdatemap, pi - installed->start);
	}
      if (ps->repo == installed && (how & SOLVER_CLEANDEPS) != 0)
	add_cleandeps_package(solv, pi);
      if (!targeted && ps->repo != installed)
	MAPSET(&solv->dupmap, pi);
    }
  if (s->repo == installed && solv->obsoletes && solv->obsoletes[p - installed->start])
    {
      Id *opp;
      for (opp = solv->obsoletes_data + solv->obsoletes[p - installed->start]; (pi = *opp++) != 0;)
	{
	  ps = pool->solvables + pi;
	  if (ps->repo == installed)
	    continue;
	  MAPSET(&solv->dupinvolvedmap, pi);
	  if (!targeted)
	    MAPSET(&solv->dupmap, pi);
	}
    }
  if (targeted && s->repo != installed && s->obsoletes)
    {
      /* XXX: check obsoletes/provides combination */
      obsp = s->repo->idarraydata + s->obsoletes;
      while ((obs = *obsp++) != 0)
	{
	  FOR_PROVIDES(pi, pip, obs)
	    {
	      Solvable *ps = pool->solvables + pi;
	      if (!pool->obsoleteusesprovides && !pool_match_nevr(pool, ps, obs))
		continue;
	      if (pool->obsoleteusescolors && !pool_colormatch(pool, s, ps))
		continue;
	      MAPSET(&solv->dupinvolvedmap, pi);
	      if (targeted && ps->repo == installed && solv->obsoletes && solv->obsoletes[pi - installed->start])
		{
		  Id *opp, pi2;
		  for (opp = solv->obsoletes_data + solv->obsoletes[pi - installed->start]; (pi2 = *opp++) != 0;)
		    if (pool->solvables[pi2].repo != installed)
		      MAPSET(&solv->dupinvolvedmap, pi2);
		}
	      if (ps->repo == installed && (how & SOLVER_FORCEBEST) != 0)
		{
		  if (!solv->bestupdatemap.size)
		    map_grow(&solv->bestupdatemap, installed->end - installed->start);
		  MAPSET(&solv->bestupdatemap, pi - installed->start);
		}
	      if (ps->repo == installed && (how & SOLVER_CLEANDEPS) != 0)
		add_cleandeps_package(solv, pi);
	    }
	}
    }
}

void
solver_createdupmaps(Solver *solv)
{
  Queue *job = &solv->job;
  Pool *pool = solv->pool;
  Repo *installed = solv->installed;
  Id select, how, what, p, pp;
  Solvable *s;
  int i, targeted;

  map_init(&solv->dupmap, pool->nsolvables);
  map_init(&solv->dupinvolvedmap, pool->nsolvables);
  for (i = 0; i < job->count; i += 2)
    {
      how = job->elements[i];
      select = job->elements[i] & SOLVER_SELECTMASK;
      what = job->elements[i + 1];
      switch (how & SOLVER_JOBMASK)
	{
	case SOLVER_DISTUPGRADE:
	  if (select == SOLVER_SOLVABLE_REPO)
	    {
	      Repo *repo;
	      if (what <= 0 || what > pool->nrepos)
		break;
	      repo = pool_id2repo(pool, what);
	      if (!repo)
		break;
	      if (repo != installed && !(how & SOLVER_TARGETED) && solv->noautotarget)
		break;
	      targeted = repo != installed || (how & SOLVER_TARGETED) != 0;
	      FOR_REPO_SOLVABLES(repo, p, s)
		{
		  if (repo != installed && !pool_installable(pool, s))
		    continue;
		  solver_addtodupmaps(solv, p, how, targeted);
		}
	    }
	  else if (select == SOLVER_SOLVABLE_ALL)
	    {
	      FOR_POOL_SOLVABLES(p)
		{
		  MAPSET(&solv->dupinvolvedmap, p);
		  if (installed && pool->solvables[p].repo != installed)
		    MAPSET(&solv->dupmap, p);
		}
	    }
	  else
	    {
	      targeted = how & SOLVER_TARGETED ? 1 : 0;
	      if (installed && !targeted && !solv->noautotarget)
		{
		  FOR_JOB_SELECT(p, pp, select, what)
		    if (pool->solvables[p].repo == installed)
		      break;
		  targeted = p == 0;
		}
	      else if (!installed && !solv->noautotarget)
		targeted = 1;
	      FOR_JOB_SELECT(p, pp, select, what)
		{
		  Solvable *s = pool->solvables + p;
		  if (!s->repo)
		    continue;
		  if (s->repo != installed && !targeted)
		    continue;
		  if (s->repo != installed && !pool_installable(pool, s))
		    continue;
		  solver_addtodupmaps(solv, p, how, targeted);
		}
	    }
	  break;
	default:
	  break;
	}
    }
  MAPCLR(&solv->dupinvolvedmap, SYSTEMSOLVABLE);
}

void
solver_freedupmaps(Solver *solv)
{
  map_free(&solv->dupmap);
  /* we no longer free solv->dupinvolvedmap as we need it in
   * policy's priority pruning code. sigh. */
}

void
solver_addduprules(Solver *solv, Map *addedmap)
{
  Pool *pool = solv->pool;
  Id p, pp;
  Solvable *s, *ps;
  int first, i;

  solv->duprules = solv->nrules;
  for (i = 1; i < pool->nsolvables; i++)
    {
      if (i == SYSTEMSOLVABLE || !MAPTST(addedmap, i))
	continue;
      s = pool->solvables + i;
      first = i;
      FOR_PROVIDES(p, pp, s->name)
	{
	  ps = pool->solvables + p;
	  if (ps->name != s->name || !MAPTST(addedmap, p))
	    continue;
	  if (p == i)
	    first = 0;
	  if (first)
	    break;
	  if (!MAPTST(&solv->dupinvolvedmap, p))
	    continue;
	  if (solv->installed && ps->repo == solv->installed)
	    {
	      if (!solv->updatemap.size)
		map_grow(&solv->updatemap, solv->installed->end - solv->installed->start);
	      MAPSET(&solv->updatemap, p - solv->installed->start);
	      if (!MAPTST(&solv->dupmap, p))
		{
		  Id ip, ipp;
		  /* is installed identical to a good one? */
		  FOR_PROVIDES(ip, ipp, ps->name)
		    {
		      Solvable *is = pool->solvables + ip;
		      if (!MAPTST(&solv->dupmap, ip))
			continue;
		      if (is->evr == ps->evr && solvable_identical(ps, is))
			break;
		    }
		  if (!ip)
		    solver_addrule(solv, -p, 0, 0);	/* no match, sorry */
		  else
		    MAPSET(&solv->dupmap, p);		/* for best rules processing */
		}
	    }
	  else if (!MAPTST(&solv->dupmap, p))
	    solver_addrule(solv, -p, 0, 0);
	}
    }
  solv->duprules_end = solv->nrules;
}


static inline void
disableduprule(Solver *solv, Id name)
{
  Pool *pool = solv->pool;
  Rule *r;
  int i;
  for (i = solv->duprules, r = solv->rules + i; i < solv->duprules_end; i++, r++)
    {
      if (r->p < 0 && r->d >= 0 && pool->solvables[-r->p].name == name)
	solver_disablerule(solv, r);
    }
}

static inline void
reenableduprule(Solver *solv, Id name)
{
  Pool *pool = solv->pool;
  Rule *r;
  int i;
  for (i = solv->duprules, r = solv->rules + i; i < solv->duprules_end; i++, r++)
    {
      if (r->p < 0 && r->d < 0 && pool->solvables[-r->p].name == name)
	{
	  solver_enablerule(solv, r);
	  IF_POOLDEBUG (SOLV_DEBUG_SOLUTIONS)
	    {
	      POOL_DEBUG(SOLV_DEBUG_SOLUTIONS, "@@@ re-enabling ");
	      solver_printruleclass(solv, SOLV_DEBUG_SOLUTIONS, r);
	    }
	}
    }
}


/***********************************************************************
 ***
 ***  Policy rule disabling/reenabling
 ***
 ***  Disable all policy rules that conflict with our jobs. If a job
 ***  gets disabled later on, reenable the involved policy rules again.
 ***
 ***/

#define DISABLE_UPDATE	1
#define DISABLE_INFARCH	2
#define DISABLE_DUP	3

/*
 * add all installed packages that package p obsoletes to Queue q.
 * Package p is not installed. Also, we know that if
 * solv->keepexplicitobsoletes is not set, p is not in the multiversion map.
 * Entries may get added multiple times.
 */
static void
add_obsoletes(Solver *solv, Id p, Queue *q)
{
  Pool *pool = solv->pool;
  Repo *installed = solv->installed;
  Id p2, pp2;
  Solvable *s = pool->solvables + p;
  Id obs, *obsp;
  Id lastp2 = 0;

  if (!solv->keepexplicitobsoletes || !(solv->multiversion.size && MAPTST(&solv->multiversion, p)))
    {
      FOR_PROVIDES(p2, pp2, s->name)
	{
	  Solvable *ps = pool->solvables + p2;
	  if (ps->repo != installed)
	    continue;
	  if (!pool->implicitobsoleteusesprovides && ps->name != s->name)
	    continue;
	  if (pool->implicitobsoleteusescolors && !pool_colormatch(pool, s, ps))
	    continue;
	  queue_push(q, p2);
	  lastp2 = p2;
	}
    }
  if (!s->obsoletes)
    return;
  obsp = s->repo->idarraydata + s->obsoletes;
  while ((obs = *obsp++) != 0)
    FOR_PROVIDES(p2, pp2, obs)
      {
	Solvable *ps = pool->solvables + p2;
	if (ps->repo != installed)
	  continue;
	if (!pool->obsoleteusesprovides && !pool_match_nevr(pool, ps, obs))
	  continue;
	if (pool->obsoleteusescolors && !pool_colormatch(pool, s, ps))
	  continue;
	if (p2 == lastp2)
	  continue;
	queue_push(q, p2);
	lastp2 = p2;
      }
}

/*
 * Call add_obsoletes and intersect the result with the
 * elements in Queue q starting at qstart.
 * Assumes that it's the first call if qstart == q->count.
 * May use auxillary map m for the intersection process, all
 * elements of q starting at qstart must have their bit cleared.
 * (This is also true after the function returns.)
 */
static void
intersect_obsoletes(Solver *solv, Id p, Queue *q, int qstart, Map *m)
{
  int i, j;
  int qcount = q->count;

  add_obsoletes(solv, p, q);
  if (qcount == qstart)
    return;	/* first call */
  if (qcount == q->count)
    j = qstart;	
  else if (qcount == qstart + 1)
    {
      /* easy if there's just one element */
      j = qstart;
      for (i = qcount; i < q->count; i++)
	if (q->elements[i] == q->elements[qstart])
	  {
	    j++;	/* keep the element */
	    break;
	  }
    }
  else if (!m->size && q->count - qstart <= 8)
    {
      /* faster than a map most of the time */
      int k;
      for (i = j = qstart; i < qcount; i++)
	{
	  Id ip = q->elements[i];
	  for (k = qcount; k < q->count; k++)
	    if (q->elements[k] == ip)
	      {
		q->elements[j++] = ip;
		break;
	      }
	}
    }
  else
    {
      /* for the really pathologic cases we use the map */
      Repo *installed = solv->installed;
      if (!m->size)
	map_init(m, installed->end - installed->start);
      for (i = qcount; i < q->count; i++)
	MAPSET(m, q->elements[i] - installed->start);
      for (i = j = qstart; i < qcount; i++)
	if (MAPTST(m, q->elements[i] - installed->start))
	  {
	    MAPCLR(m, q->elements[i] - installed->start);
	    q->elements[j++] = q->elements[i];
	  }
    }
  queue_truncate(q, j);
}

static void
jobtodisablelist(Solver *solv, Id how, Id what, Queue *q)
{
  Pool *pool = solv->pool;
  Id select, p, pp;
  Repo *installed;
  Solvable *s;
  int i, j, set, qstart;
  Map omap;

  installed = solv->installed;
  select = how & SOLVER_SELECTMASK;
  switch (how & SOLVER_JOBMASK)
    {
    case SOLVER_INSTALL:
      set = how & SOLVER_SETMASK;
      if (!(set & SOLVER_NOAUTOSET))
	{
	  /* automatically add set bits by analysing the job */
	  if (select == SOLVER_SOLVABLE_NAME)
	    set |= SOLVER_SETNAME;
	  if (select == SOLVER_SOLVABLE)
	    set |= SOLVER_SETNAME | SOLVER_SETARCH | SOLVER_SETVENDOR | SOLVER_SETREPO | SOLVER_SETEVR;
	  else if ((select == SOLVER_SOLVABLE_NAME || select == SOLVER_SOLVABLE_PROVIDES) && ISRELDEP(what))
	    {
	      Reldep *rd = GETRELDEP(pool, what);
	      if (rd->flags == REL_EQ && select == SOLVER_SOLVABLE_NAME)
		{
		  if (pool->disttype != DISTTYPE_DEB)
		    {
		      const char *rel = strrchr(pool_id2str(pool, rd->evr), '-');
		      set |= rel ? SOLVER_SETEVR : SOLVER_SETEV;
		    }
		  else
		    set |= SOLVER_SETEVR;
		}
	      if (rd->flags <= 7 && ISRELDEP(rd->name))
		rd = GETRELDEP(pool, rd->name);
	      if (rd->flags == REL_ARCH)
		set |= SOLVER_SETARCH;
	    }
	}
      else
	set &= ~SOLVER_NOAUTOSET;
      if (!set)
	return;
      if ((set & SOLVER_SETARCH) != 0 && solv->infarchrules != solv->infarchrules_end)
	{
	  if (select == SOLVER_SOLVABLE)
	    queue_push2(q, DISABLE_INFARCH, pool->solvables[what].name);
	  else
	    {
	      int qcnt = q->count;
	      /* does not work for SOLVER_SOLVABLE_ALL and SOLVER_SOLVABLE_REPO, but
		 they are not useful for SOLVER_INSTALL jobs anyway */
	      FOR_JOB_SELECT(p, pp, select, what)
		{
		  s = pool->solvables + p;
		  /* unify names */
		  for (i = qcnt; i < q->count; i += 2)
		    if (q->elements[i + 1] == s->name)
		      break;
		  if (i < q->count)
		    continue;
		  queue_push2(q, DISABLE_INFARCH, s->name);
		}
	    }
	}
      if ((set & SOLVER_SETREPO) != 0 && solv->duprules != solv->duprules_end)
	{
	  if (select == SOLVER_SOLVABLE)
	    queue_push2(q, DISABLE_DUP, pool->solvables[what].name);
	  else
	    {
	      int qcnt = q->count;
	      FOR_JOB_SELECT(p, pp, select, what)
		{
		  s = pool->solvables + p;
		  /* unify names */
		  for (i = qcnt; i < q->count; i += 2)
		    if (q->elements[i + 1] == s->name)
		      break;
		  if (i < q->count)
		    continue;
		  queue_push2(q, DISABLE_DUP, s->name);
		}
	    }
	}
      if (!installed || installed->end == installed->start)
	return;
      /* now the hard part: disable some update rules */

      /* first check if we have multiversion or installed packages in the job */
      i = j = 0;
      FOR_JOB_SELECT(p, pp, select, what)
	{
	  if (pool->solvables[p].repo == installed)
	    j = p;
	  else if (solv->multiversion.size && MAPTST(&solv->multiversion, p) && !solv->keepexplicitobsoletes)
	    return;
	  i++;
	}
      if (j)	/* have installed packages */
	{
	  /* this is for dupmap_all jobs, it can go away if we create
	   * duprules for them */
	  if (i == 1 && (set & SOLVER_SETREPO) != 0)
	    queue_push2(q, DISABLE_UPDATE, j);
	  return;
	}

      omap.size = 0;
      qstart = q->count;
      FOR_JOB_SELECT(p, pp, select, what)
	{
	  intersect_obsoletes(solv, p, q, qstart, &omap);
	  if (q->count == qstart)
	    break;
	}
      if (omap.size)
        map_free(&omap);

      if (qstart == q->count)
	return;		/* nothing to prune */

      /* convert result to (DISABLE_UPDATE, p) pairs */
      i = q->count;
      for (j = qstart; j < i; j++)
	queue_push(q, q->elements[j]);
      for (j = qstart; j < q->count; j += 2)
	{
	  q->elements[j] = DISABLE_UPDATE;
	  q->elements[j + 1] = q->elements[i++];
	}

      /* now that we know which installed packages are obsoleted check each of them */
      if ((set & (SOLVER_SETEVR | SOLVER_SETARCH | SOLVER_SETVENDOR)) == (SOLVER_SETEVR | SOLVER_SETARCH | SOLVER_SETVENDOR))
	return;		/* all is set, nothing to do */

      for (i = j = qstart; i < q->count; i += 2)
	{
	  Solvable *is = pool->solvables + q->elements[i + 1];
	  FOR_JOB_SELECT(p, pp, select, what)
	    {
	      int illegal = 0;
	      s = pool->solvables + p;
	      if ((set & SOLVER_SETEVR) != 0)
		illegal |= POLICY_ILLEGAL_DOWNGRADE;	/* ignore */
	      if ((set & SOLVER_SETNAME) != 0)
		illegal |= POLICY_ILLEGAL_NAMECHANGE;	/* ignore */
	      if ((set & SOLVER_SETARCH) != 0)
		illegal |= POLICY_ILLEGAL_ARCHCHANGE;	/* ignore */
	      if ((set & SOLVER_SETVENDOR) != 0)
		illegal |= POLICY_ILLEGAL_VENDORCHANGE;	/* ignore */
	      illegal = policy_is_illegal(solv, is, s, illegal);
	      if (illegal && illegal == POLICY_ILLEGAL_DOWNGRADE && (set & SOLVER_SETEV) != 0)
		{
		  /* it's ok if the EV is different */
		  if (pool_evrcmp(pool, is->evr, s->evr, EVRCMP_COMPARE_EVONLY) != 0)
		    illegal = 0;
		}
	      if (illegal)
		break;
	    }
	  if (!p)
	    {	
	      /* no package conflicts with the update rule */
	      /* thus keep the DISABLE_UPDATE */
	      q->elements[j + 1] = q->elements[i + 1];
	      j += 2;
	    }
	}
      queue_truncate(q, j);
      return;

    case SOLVER_ERASE:
      if (!installed)
	break;
      if (select == SOLVER_SOLVABLE_ALL || (select == SOLVER_SOLVABLE_REPO && what == installed->repoid))
	FOR_REPO_SOLVABLES(installed, p, s)
	  queue_push2(q, DISABLE_UPDATE, p);
      FOR_JOB_SELECT(p, pp, select, what)
	if (pool->solvables[p].repo == installed)
	  {
	    queue_push2(q, DISABLE_UPDATE, p);
#ifdef ENABLE_LINKED_PKGS
	    if (solv->instbuddy && solv->instbuddy[p - installed->start] > 1)
	      queue_push2(q, DISABLE_UPDATE, solv->instbuddy[p - installed->start]);
#endif
	  }
      return;
    default:
      return;
    }
}

/* disable all policy rules that are in conflict with our job list */
void
solver_disablepolicyrules(Solver *solv)
{
  Queue *job = &solv->job;
  int i, j;
  Queue allq;
  Rule *r;
  Id lastjob = -1;
  Id allqbuf[128];

  queue_init_buffer(&allq, allqbuf, sizeof(allqbuf)/sizeof(*allqbuf));

  for (i = solv->jobrules; i < solv->jobrules_end; i++)
    {
      r = solv->rules + i;
      if (r->d < 0)	/* disabled? */
	continue;
      j = solv->ruletojob.elements[i - solv->jobrules];
      if (j == lastjob)
	continue;
      lastjob = j;
      jobtodisablelist(solv, job->elements[j], job->elements[j + 1], &allq);
    }
  if (solv->cleandepsmap.size)
    {
      solver_createcleandepsmap(solv, &solv->cleandepsmap, 0);
      for (i = solv->installed->start; i < solv->installed->end; i++)
	if (MAPTST(&solv->cleandepsmap, i - solv->installed->start))
	  queue_push2(&allq, DISABLE_UPDATE, i);
    }
  MAPZERO(&solv->noupdate);
  for (i = 0; i < allq.count; i += 2)
    {
      Id type = allq.elements[i], arg = allq.elements[i + 1];
      switch(type)
	{
	case DISABLE_UPDATE:
	  disableupdaterule(solv, arg);
	  break;
	case DISABLE_INFARCH:
	  disableinfarchrule(solv, arg);
	  break;
	case DISABLE_DUP:
	  disableduprule(solv, arg);
	  break;
	default:
	  break;
	}
    }
  queue_free(&allq);
}

/* we just disabled job #jobidx, now reenable all policy rules that were
 * disabled because of this job */
void
solver_reenablepolicyrules(Solver *solv, int jobidx)
{
  Queue *job = &solv->job;
  int i, j, k, ai;
  Queue q, allq;
  Rule *r;
  Id lastjob = -1;
  Id qbuf[32], allqbuf[32];

  queue_init_buffer(&q, qbuf, sizeof(qbuf)/sizeof(*qbuf));
  jobtodisablelist(solv, job->elements[jobidx - 1], job->elements[jobidx], &q);
  if (!q.count)
    {
      queue_free(&q);
      return;
    }
  /* now remove everything from q that is disabled by other jobs */

  /* first remove cleandeps packages, they count as DISABLE_UPDATE */
  if (solv->cleandepsmap.size)
    {
      solver_createcleandepsmap(solv, &solv->cleandepsmap, 0);
      for (j = k = 0; j < q.count; j += 2)
	{
	  if (q.elements[j] == DISABLE_UPDATE)
	    {
	      Id p = q.elements[j + 1];
	      if (p >= solv->installed->start && p < solv->installed->end && MAPTST(&solv->cleandepsmap, p - solv->installed->start))
		continue;	/* remove element from q */
	    }
	  q.elements[k++] = q.elements[j];
	  q.elements[k++] = q.elements[j + 1];
	}
      q.count = k;
      if (!q.count)
	{
	  queue_free(&q);
	  return;
	}
    }

  /* now go through the disable list of all other jobs */
  queue_init_buffer(&allq, allqbuf, sizeof(allqbuf)/sizeof(*allqbuf));
  for (i = solv->jobrules; i < solv->jobrules_end; i++)
    {
      r = solv->rules + i;
      if (r->d < 0)	/* disabled? */
	continue;
      j = solv->ruletojob.elements[i - solv->jobrules];
      if (j == lastjob)
	continue;
      lastjob = j;
      jobtodisablelist(solv, job->elements[j], job->elements[j + 1], &allq);
      if (!allq.count)
	continue;
      /* remove all elements in allq from q */
      for (j = k = 0; j < q.count; j += 2)
	{
	  Id type = q.elements[j], arg = q.elements[j + 1];
	  for (ai = 0; ai < allq.count; ai += 2)
	    if (allq.elements[ai] == type && allq.elements[ai + 1] == arg)
	      break;
	  if (ai < allq.count)
	    continue;	/* found it in allq, remove element from q */
	  q.elements[k++] = q.elements[j];
	  q.elements[k++] = q.elements[j + 1];
	}
      q.count = k;
      if (!q.count)
	{
	  queue_free(&q);
	  queue_free(&allq);
	  return;
	}
      queue_empty(&allq);
    }
  queue_free(&allq);

  /* now re-enable anything that's left in q */
  for (j = 0; j < q.count; j += 2)
    {
      Id type = q.elements[j], arg = q.elements[j + 1];
      switch(type)
	{
	case DISABLE_UPDATE:
	  reenableupdaterule(solv, arg);
	  break;
	case DISABLE_INFARCH:
	  reenableinfarchrule(solv, arg);
	  break;
	case DISABLE_DUP:
	  reenableduprule(solv, arg);
	  break;
	}
    }
  queue_free(&q);
}

/* we just removed a package from the cleandeps map, now reenable all policy rules that were
 * disabled because of this */
void
solver_reenablepolicyrules_cleandeps(Solver *solv, Id pkg)
{
  Queue *job = &solv->job;
  int i, j;
  Queue allq;
  Rule *r;
  Id lastjob = -1;
  Id allqbuf[128];

  queue_init_buffer(&allq, allqbuf, sizeof(allqbuf)/sizeof(*allqbuf));
  for (i = solv->jobrules; i < solv->jobrules_end; i++)
    {
      r = solv->rules + i;
      if (r->d < 0)	/* disabled? */
	continue;
      j = solv->ruletojob.elements[i - solv->jobrules];
      if (j == lastjob)
	continue;
      lastjob = j;
      jobtodisablelist(solv, job->elements[j], job->elements[j + 1], &allq);
    }
  for (i = 0; i < allq.count; i += 2)
    if (allq.elements[i] == DISABLE_UPDATE && allq.elements[i + 1] == pkg)
      break;
  if (i == allq.count)
    reenableupdaterule(solv, pkg);
  queue_free(&allq);
}


/***********************************************************************
 ***
 ***  Rule info part, tell the user what the rule is about.
 ***
 ***/

static void
addpkgruleinfo(Solver *solv, Id p, Id p2, Id d, int type, Id dep)
{
  Pool *pool = solv->pool;
  Rule *r;

  if (d)
    {
      assert(!p2 && d > 0);
      if (!pool->whatprovidesdata[d])
	d = 0;
      else if (!pool->whatprovidesdata[d + 1])
	{
	  p2 = pool->whatprovidesdata[d];
	  d = 0;
	}
    }

  /* check if this creates the rule we're searching for */
  r = solv->rules + solv->ruleinfoq->elements[0];
  if (d)
    {
      /* three or more literals */
      Id od = r->d < 0 ? -r->d - 1 : r->d;
      if (p != r->p && !od)
	return;
      if (d != od)
	{
	  Id *dp = pool->whatprovidesdata + d;
	  Id *odp = pool->whatprovidesdata + od;
	  while (*dp)
	    if (*dp++ != *odp++)
	      return;
	  if (*odp)
	    return;
	}
      if (p < 0 && pool->whatprovidesdata[d] < 0 && type == SOLVER_RULE_PKG_CONFLICTS)
	p2 = pool->whatprovidesdata[d];
    }
  else
    {
      /* one or two literals */
      Id op = p, op2 = p2;
      if (op2 && op > op2)	/* normalize */
	{
	  Id o = op;
	  op = op2;
	  op2 = o;
	}
      if (r->p != op || r->w2 != op2 || (r->d && r->d != -1))
	return;
      if (type == SOLVER_RULE_PKG_CONFLICTS && !p2)
	p2 = -SYSTEMSOLVABLE;
      if (type == SOLVER_RULE_PKG_SAME_NAME)
	{
	  p = op;	/* we normalize same name order */
	  p2 = op2;
	}
    }
  /* yep, rule matches. record info */
  queue_push(solv->ruleinfoq, type);
  queue_push(solv->ruleinfoq, p < 0 ? -p : 0);
  queue_push(solv->ruleinfoq, p2 < 0 ? -p2 : 0);
  queue_push(solv->ruleinfoq, dep);
}

static int
solver_allruleinfos_cmp(const void *ap, const void *bp, void *dp)
{
  const Id *a = ap, *b = bp;
  int r;

  r = a[0] - b[0];
  if (r)
    return r;
  r = a[1] - b[1];
  if (r)
    return r;
  r = a[2] - b[2];
  if (r)
    return r;
  r = a[3] - b[3];
  if (r)
    return r;
  return 0;
}

static void
getpkgruleinfos(Solver *solv, Rule *r, Queue *rq)
{
  Pool *pool = solv->pool;
  Id l, pp;
  if (r->p >= 0)
    return;
  queue_push(rq, r - solv->rules);	/* push the rule we're interested in */
  solv->ruleinfoq = rq;
  FOR_RULELITERALS(l, pp, r)
    {
      if (l >= 0)
	break;
      solver_addpkgrulesforsolvable(solv, pool->solvables - l, 0);
    }
#ifdef ENABLE_LINKED_PKGS
  FOR_RULELITERALS(l, pp, r)
    {
      if (l < 0)
	{
	  if (l == r->p)
	    continue;
	  break;
	}
      if (!strchr(pool_id2str(pool, pool->solvables[l].name), ':') || !has_package_link(pool, pool->solvables + l))
	break;
      add_package_link(solv, pool->solvables + l, 0, 0);
    }
#endif
  solv->ruleinfoq = 0;
  queue_shift(rq);
}

int
solver_allruleinfos(Solver *solv, Id rid, Queue *rq)
{
  Rule *r = solv->rules + rid;
  int i, j;

  queue_empty(rq);
  if (rid <= 0 || rid >= solv->pkgrules_end)
    {
      Id type, from, to, dep;
      type = solver_ruleinfo(solv, rid, &from, &to, &dep);
      queue_push(rq, type);
      queue_push(rq, from);
      queue_push(rq, to);
      queue_push(rq, dep);
      return 1;
    }
  getpkgruleinfos(solv, r, rq);
  /* now sort & unify em */
  if (!rq->count)
    return 0;
  solv_sort(rq->elements, rq->count / 4, 4 * sizeof(Id), solver_allruleinfos_cmp, 0);
  /* throw out identical entries */
  for (i = j = 0; i < rq->count; i += 4)
    {
      if (j)
	{
	  if (rq->elements[i] == rq->elements[j - 4] &&
	      rq->elements[i + 1] == rq->elements[j - 3] &&
	      rq->elements[i + 2] == rq->elements[j - 2] &&
	      rq->elements[i + 3] == rq->elements[j - 1])
	    continue;
	}
      rq->elements[j++] = rq->elements[i];
      rq->elements[j++] = rq->elements[i + 1];
      rq->elements[j++] = rq->elements[i + 2];
      rq->elements[j++] = rq->elements[i + 3];
    }
  rq->count = j;
  return j / 4;
}

SolverRuleinfo
solver_ruleinfo(Solver *solv, Id rid, Id *fromp, Id *top, Id *depp)
{
  Pool *pool = solv->pool;
  Rule *r = solv->rules + rid;
  SolverRuleinfo type = SOLVER_RULE_UNKNOWN;

  if (fromp)
    *fromp = 0;
  if (top)
    *top = 0;
  if (depp)
    *depp = 0;
  if (rid > 0 && rid < solv->pkgrules_end)
    {
      Queue rq;
      int i;

      if (r->p >= 0)
	return SOLVER_RULE_PKG;
      if (fromp)
	*fromp = -r->p;
      queue_init(&rq);
      getpkgruleinfos(solv, r, &rq);
      type = SOLVER_RULE_PKG;
      for (i = 0; i < rq.count; i += 4)
	{
	  Id qt, qo, qp, qd;
	  qt = rq.elements[i];
	  qp = rq.elements[i + 1];
	  qo = rq.elements[i + 2];
	  qd = rq.elements[i + 3];
	  if (type == SOLVER_RULE_PKG || type > qt)
	    {
	      type = qt;
	      if (fromp)
		*fromp = qp;
	      if (top)
		*top = qo;
	      if (depp)
		*depp = qd;
	    }
	}
      queue_free(&rq);
      return type;
    }
  if (rid >= solv->jobrules && rid < solv->jobrules_end)
    {
      Id jidx = solv->ruletojob.elements[rid - solv->jobrules];
      if (fromp)
	*fromp = jidx;
      if (top)
	*top = solv->job.elements[jidx];
      if (depp)
	*depp = solv->job.elements[jidx + 1];
      if ((r->d == 0 || r->d == -1) && r->w2 == 0 && r->p == -SYSTEMSOLVABLE)
	{
	  Id how = solv->job.elements[jidx];
	  if ((how & (SOLVER_JOBMASK|SOLVER_SELECTMASK)) == (SOLVER_INSTALL|SOLVER_SOLVABLE_NAME))
	    return SOLVER_RULE_JOB_UNKNOWN_PACKAGE;
	  if ((how & (SOLVER_JOBMASK|SOLVER_SELECTMASK)) == (SOLVER_INSTALL|SOLVER_SOLVABLE_PROVIDES))
	    return SOLVER_RULE_JOB_NOTHING_PROVIDES_DEP;
	  if ((how & (SOLVER_JOBMASK|SOLVER_SELECTMASK)) == (SOLVER_ERASE|SOLVER_SOLVABLE_NAME))
	    return SOLVER_RULE_JOB_PROVIDED_BY_SYSTEM;
	  if ((how & (SOLVER_JOBMASK|SOLVER_SELECTMASK)) == (SOLVER_ERASE|SOLVER_SOLVABLE_PROVIDES))
	    return SOLVER_RULE_JOB_PROVIDED_BY_SYSTEM;
	  return SOLVER_RULE_JOB_UNSUPPORTED;
	}
      return SOLVER_RULE_JOB;
    }
  if (rid >= solv->updaterules && rid < solv->updaterules_end)
    {
      if (fromp)
	*fromp = solv->installed->start + (rid - solv->updaterules);
      return SOLVER_RULE_UPDATE;
    }
  if (rid >= solv->featurerules && rid < solv->featurerules_end)
    {
      if (fromp)
	*fromp = solv->installed->start + (rid - solv->featurerules);
      return SOLVER_RULE_FEATURE;
    }
  if (rid >= solv->duprules && rid < solv->duprules_end)
    {
      if (fromp)
	*fromp = -r->p;
      if (depp)
	*depp = pool->solvables[-r->p].name;
      return SOLVER_RULE_DISTUPGRADE;
    }
  if (rid >= solv->infarchrules && rid < solv->infarchrules_end)
    {
      if (fromp)
	*fromp = -r->p;
      if (depp)
	*depp = pool->solvables[-r->p].name;
      return SOLVER_RULE_INFARCH;
    }
  if (rid >= solv->bestrules && rid < solv->bestrules_end)
    {
      if (fromp && solv->bestrules_pkg[rid - solv->bestrules] > 0)
	*fromp = solv->bestrules_pkg[rid - solv->bestrules];
      return SOLVER_RULE_BEST;
    }
  if (rid >= solv->yumobsrules && rid < solv->yumobsrules_end)
    {
      if (fromp)
	*fromp = -r->p;
      if (top)
	{
	  /* first solvable is enough, we just need it for the name */
	  if (!r->d || r->d == -1)
	    *top = r->w2;
	  else
	    *top = pool->whatprovidesdata[r->d < 0 ? -r->d : r->d];
	}
      if (depp)
	*depp = solv->yumobsrules_info[rid - solv->yumobsrules];
      return SOLVER_RULE_YUMOBS;
    }
  if (rid >= solv->choicerules && rid < solv->choicerules_end)
    {
      return SOLVER_RULE_CHOICE;
    }
  if (rid >= solv->learntrules)
    {
      return SOLVER_RULE_LEARNT;
    }
  return SOLVER_RULE_UNKNOWN;
}

SolverRuleinfo
solver_ruleclass(Solver *solv, Id rid)
{
  if (rid <= 0)
    return SOLVER_RULE_UNKNOWN;
  if (rid > 0 && rid < solv->pkgrules_end)
    return SOLVER_RULE_PKG;
  if (rid >= solv->jobrules && rid < solv->jobrules_end)
    return SOLVER_RULE_JOB;
  if (rid >= solv->updaterules && rid < solv->updaterules_end)
    return SOLVER_RULE_UPDATE;
  if (rid >= solv->featurerules && rid < solv->featurerules_end)
    return SOLVER_RULE_FEATURE;
  if (rid >= solv->duprules && rid < solv->duprules_end)
    return SOLVER_RULE_DISTUPGRADE;
  if (rid >= solv->infarchrules && rid < solv->infarchrules_end)
    return SOLVER_RULE_INFARCH;
  if (rid >= solv->bestrules && rid < solv->bestrules_end)
    return SOLVER_RULE_BEST;
  if (rid >= solv->yumobsrules && rid < solv->yumobsrules_end)
    return SOLVER_RULE_YUMOBS;
  if (rid >= solv->choicerules && rid < solv->choicerules_end)
    return SOLVER_RULE_CHOICE;
  if (rid >= solv->learntrules && rid < solv->nrules)
    return SOLVER_RULE_LEARNT;
  return SOLVER_RULE_UNKNOWN;
}

void
solver_ruleliterals(Solver *solv, Id rid, Queue *q)
{
  Pool *pool = solv->pool;
  Id p, pp;
  Rule *r;

  queue_empty(q);
  r = solv->rules + rid;
  FOR_RULELITERALS(p, pp, r)
    if (p != -SYSTEMSOLVABLE)
      queue_push(q, p);
  if (!q->count)
    queue_push(q, -SYSTEMSOLVABLE);	/* hmm, better to return an empty result? */
}

int
solver_rule2jobidx(Solver *solv, Id rid)
{
  if (rid < solv->jobrules || rid >= solv->jobrules_end)
    return 0;
  return solv->ruletojob.elements[rid - solv->jobrules] + 1;
}

/* job rule introspection */
Id
solver_rule2job(Solver *solv, Id rid, Id *whatp)
{
  int idx;
  if (rid < solv->jobrules || rid >= solv->jobrules_end)
    {
      if (whatp)
	*whatp = 0;
      return 0;
    }
  idx = solv->ruletojob.elements[rid - solv->jobrules];
  if (whatp)
    *whatp = solv->job.elements[idx + 1];
  return solv->job.elements[idx];
}

/* update/feature rule introspection */
Id
solver_rule2solvable(Solver *solv, Id rid)
{
  if (rid >= solv->updaterules && rid < solv->updaterules_end)
    return rid - solv->updaterules;
  if (rid >= solv->featurerules && rid < solv->featurerules_end)
    return rid - solv->featurerules;
  return 0;
}

Id
solver_rule2pkgrule(Solver *solv, Id rid)
{
  if (rid >= solv->choicerules && rid < solv->choicerules_end)
    return solv->choicerules_ref[rid - solv->choicerules];
  return 0;
}

static void
solver_rule2rules_rec(Solver *solv, Id rid, Queue *q, Map *seen)
{
  int i;
  Id rid2;

  if (seen)
    MAPSET(seen, rid);
  for (i = solv->learnt_why.elements[rid - solv->learntrules]; (rid2 = solv->learnt_pool.elements[i]) != 0; i++)
    {
      if (seen)
	{
	  if (MAPTST(seen, rid2))
	    continue;
	  if (rid2 >= solv->learntrules)
	    solver_rule2rules_rec(solv, rid2, q, seen);
	  continue;
	}
      queue_push(q, rid2);
    }
}

/* learnt rule introspection */
void
solver_rule2rules(Solver *solv, Id rid, Queue *q, int recursive)
{
  queue_empty(q);
  if (rid < solv->learntrules || rid >= solv->nrules)
    return;
  if (recursive)
    {
      Map seen;
      map_init(&seen, solv->nrules);
      solver_rule2rules_rec(solv, rid, q, &seen);
      map_free(&seen);
    }
  else
    solver_rule2rules_rec(solv, rid, q, 0);
}


/* check if the newest versions of pi still provides the dependency we're looking for */
static int
solver_choicerulecheck(Solver *solv, Id pi, Rule *r, Map *m)
{
  Pool *pool = solv->pool;
  Rule *ur;
  Queue q;
  Id p, pp, qbuf[32];
  int i;

  ur = solv->rules + solv->updaterules + (pi - pool->installed->start);
  if (!ur->p)
    ur = solv->rules + solv->featurerules + (pi - pool->installed->start);
  if (!ur->p)
    return 0;
  queue_init_buffer(&q, qbuf, sizeof(qbuf)/sizeof(*qbuf));
  FOR_RULELITERALS(p, pp, ur)
    if (p > 0)
      queue_push(&q, p);
  if (q.count > 1)
    policy_filter_unwanted(solv, &q, POLICY_MODE_CHOOSE);
  for (i = 0; i < q.count; i++)
    if (MAPTST(m, q.elements[i]))
      break;
  /* 1: none of the newest versions provide it */
  i = i == q.count ? 1 : 0;
  queue_free(&q);
  return i;
}

static inline void
queue_removeelement(Queue *q, Id el)
{
  int i, j;
  for (i = 0; i < q->count; i++)
    if (q->elements[i] == el)
      break;
  if (i < q->count)
    {
      for (j = i++; i < q->count; i++)
	if (q->elements[i] != el)
	  q->elements[j++] = q->elements[i];
      queue_truncate(q, j);
    }
}

void
solver_addchoicerules(Solver *solv)
{
  Pool *pool = solv->pool;
  Map m, mneg;
  Rule *r;
  Queue q, qi;
  int i, j, rid, havechoice;
  Id p, d, pp;
  Id p2, pp2;
  Solvable *s, *s2;
  Id lastaddedp, lastaddedd;
  int lastaddedcnt;
  unsigned int now;

  solv->choicerules = solv->nrules;
  if (!pool->installed)
    {
      solv->choicerules_end = solv->nrules;
      return;
    }
  now = solv_timems(0);
  solv->choicerules_ref = solv_calloc(solv->pkgrules_end, sizeof(Id));
  queue_init(&q);
  queue_init(&qi);
  map_init(&m, pool->nsolvables);
  map_init(&mneg, pool->nsolvables);
  /* set up negative assertion map from infarch and dup rules */
  for (rid = solv->infarchrules, r = solv->rules + rid; rid < solv->infarchrules_end; rid++, r++)
    if (r->p < 0 && !r->w2 && (r->d == 0 || r->d == -1))
      MAPSET(&mneg, -r->p);
  for (rid = solv->duprules, r = solv->rules + rid; rid < solv->duprules_end; rid++, r++)
    if (r->p < 0 && !r->w2 && (r->d == 0 || r->d == -1))
      MAPSET(&mneg, -r->p);
  lastaddedp = 0;
  lastaddedd = 0;
  lastaddedcnt = 0;
  for (rid = 1; rid < solv->pkgrules_end ; rid++)
    {
      r = solv->rules + rid;
      if (r->p >= 0 || ((r->d == 0 || r->d == -1) && r->w2 <= 0))
	continue;	/* only look at requires rules */
      /* solver_printrule(solv, SOLV_DEBUG_RESULT, r); */
      queue_empty(&q);
      queue_empty(&qi);
      havechoice = 0;
      FOR_RULELITERALS(p, pp, r)
	{
	  if (p < 0)
	    continue;
	  s = pool->solvables + p;
	  if (!s->repo)
	    continue;
	  if (s->repo == pool->installed)
	    {
	      queue_push(&q, p);
	      continue;
	    }
	  /* check if this package is "blocked" by a installed package */
	  s2 = 0;
	  FOR_PROVIDES(p2, pp2, s->name)
	    {
	      s2 = pool->solvables + p2;
	      if (s2->repo != pool->installed)
		continue;
	      if (!pool->implicitobsoleteusesprovides && s->name != s2->name)
	        continue;
	      if (pool->implicitobsoleteusescolors && !pool_colormatch(pool, s, s2))
	        continue;
	      break;
	    }
	  if (p2)
	    {
	      /* found installed package p2 that we can update to p */
	      if (MAPTST(&mneg, p))
		continue;
	      if (policy_is_illegal(solv, s2, s, 0))
		continue;
#if 0
	      if (solver_choicerulecheck(solv, p2, r, &m))
		continue;
	      queue_push(&qi, p2);
#else
	      queue_push2(&qi, p2, p);
#endif
	      queue_push(&q, p);
	      continue;
	    }
	  if (s->obsoletes)
	    {
	      Id obs, *obsp = s->repo->idarraydata + s->obsoletes;
	      s2 = 0;
	      while ((obs = *obsp++) != 0)
		{
		  FOR_PROVIDES(p2, pp2, obs)
		    {
		      s2 = pool->solvables + p2;
		      if (s2->repo != pool->installed)
			continue;
		      if (!pool->obsoleteusesprovides && !pool_match_nevr(pool, pool->solvables + p2, obs))
			continue;
		      if (pool->obsoleteusescolors && !pool_colormatch(pool, s, s2))
			continue;
		      break;
		    }
		  if (p2)
		    break;
		}
	      if (obs)
		{
		  /* found installed package p2 that we can update to p */
		  if (MAPTST(&mneg, p))
		    continue;
		  if (policy_is_illegal(solv, s2, s, 0))
		    continue;
#if 0
		  if (solver_choicerulecheck(solv, p2, r, &m))
		    continue;
		  queue_push(&qi, p2);
#else
		  queue_push2(&qi, p2, p);
#endif
		  queue_push(&q, p);
		  continue;
		}
	    }
	  /* package p is independent of the installed ones */
	  havechoice = 1;
	}
      if (!havechoice || !q.count || !qi.count)
	continue;	/* no choice */

      FOR_RULELITERALS(p, pp, r)
        if (p > 0)
	  MAPSET(&m, p);

      /* do extra checking */
      for (i = j = 0; i < qi.count; i += 2)
	{
	  p2 = qi.elements[i];
	  if (!p2)
	    continue;
	  if (solver_choicerulecheck(solv, p2, r, &m))
	    {
	      /* oops, remove element p from q */
	      queue_removeelement(&q, qi.elements[i + 1]);
	      continue;
	    }
	  qi.elements[j++] = p2;
	}
      queue_truncate(&qi, j);
      if (!q.count || !qi.count)
	{
	  FOR_RULELITERALS(p, pp, r)
	    if (p > 0)
	      MAPCLR(&m, p);
	  continue;
	}


      /* now check the update rules of the installed package.
       * if all packages of the update rules are contained in
       * the dependency rules, there's no need to set up the choice rule */
      for (i = 0; i < qi.count; i++)
	{
	  Rule *ur;
	  if (!qi.elements[i])
	    continue;
	  ur = solv->rules + solv->updaterules + (qi.elements[i] - pool->installed->start);
	  if (!ur->p)
	    ur = solv->rules + solv->featurerules + (qi.elements[i] - pool->installed->start);
	  if (!ur->p)
	    continue;
	  FOR_RULELITERALS(p, pp, ur)
	    if (!MAPTST(&m, p))
	      break;
	  if (p)
	    break;
	  for (j = i + 1; j < qi.count; j++)
	    if (qi.elements[i] == qi.elements[j])
	      qi.elements[j] = 0;
	}
      /* empty map again */
      FOR_RULELITERALS(p, pp, r)
        if (p > 0)
	  MAPCLR(&m, p);
      if (i == qi.count)
	{
#if 0
	  printf("skipping choice ");
	  solver_printrule(solv, SOLV_DEBUG_RESULT, solv->rules + rid);
#endif
	  continue;
	}

      /* don't add identical rules */
      if (lastaddedp == r->p && lastaddedcnt == q.count)
	{
	  for (i = 0; i < q.count; i++)
	    if (q.elements[i] != pool->whatprovidesdata[lastaddedd + i])
	      break;
	  if (i == q.count)
	    continue;	/* already added that one */
	}
      d = q.count ? pool_queuetowhatprovides(pool, &q) : 0;

      lastaddedp = r->p;
      lastaddedd = d;
      lastaddedcnt = q.count;

      solver_addrule(solv, r->p, 0, d);
      queue_push(&solv->weakruleq, solv->nrules - 1);
      solv->choicerules_ref[solv->nrules - 1 - solv->choicerules] = rid;
#if 0
      printf("OLD ");
      solver_printrule(solv, SOLV_DEBUG_RESULT, solv->rules + rid);
      printf("WEAK CHOICE ");
      solver_printrule(solv, SOLV_DEBUG_RESULT, solv->rules + solv->nrules - 1);
#endif
    }
  queue_free(&q);
  queue_free(&qi);
  map_free(&m);
  map_free(&mneg);
  solv->choicerules_end = solv->nrules;
  /* shrink choicerules_ref */
  solv->choicerules_ref = solv_realloc2(solv->choicerules_ref, solv->choicerules_end - solv->choicerules, sizeof(Id));
  POOL_DEBUG(SOLV_DEBUG_STATS, "choice rule creation took %d ms\n", solv_timems(now));
}

/* called when a choice rule is disabled by analyze_unsolvable. We also
 * have to disable all other choice rules so that the best packages get
 * picked */
void
solver_disablechoicerules(Solver *solv, Rule *r)
{
  Id rid, p, pp;
  Pool *pool = solv->pool;
  Map m;
  Rule *or;

  or = solv->rules + solv->choicerules_ref[(r - solv->rules) - solv->choicerules];
  map_init(&m, pool->nsolvables);
  FOR_RULELITERALS(p, pp, or)
    if (p > 0)
      MAPSET(&m, p);
  FOR_RULELITERALS(p, pp, r)
    if (p > 0)
      MAPCLR(&m, p);
  for (rid = solv->choicerules; rid < solv->choicerules_end; rid++)
    {
      r = solv->rules + rid;
      if (r->d < 0)
	continue;
      or = solv->rules + solv->choicerules_ref[(r - solv->rules) - solv->choicerules];
      FOR_RULELITERALS(p, pp, or)
        if (p > 0 && MAPTST(&m, p))
	  break;
      if (p)
	solver_disablerule(solv, r);
    }
}

static void
prune_to_update_targets(Solver *solv, Id *cp, Queue *q)
{
  int i, j;
  Id p, *cp2;
  for (i = j = 0; i < q->count; i++)
    {
      p = q->elements[i];
      for (cp2 = cp; *cp2; cp2++)
        if (*cp2 == p)
          {
            q->elements[j++] = p;
            break;
          }
    }
  queue_truncate(q, j);
}

static void
prune_to_dup_packages(Solver *solv, Id p, Queue *q)
{
  int i, j;
  for (i = j = 0; i < q->count; i++)
    {
      Id p = q->elements[i];
      if (MAPTST(&solv->dupmap, p))
	q->elements[j++] = p;
    }
  queue_truncate(q, j);
}

void
solver_addbestrules(Solver *solv, int havebestinstalljobs)
{
  Pool *pool = solv->pool;
  Id p;
  Solvable *s;
  Repo *installed = solv->installed;
  Queue q, q2;
  Rule *r;
  Queue r2pkg;
  int i, oldcnt;

  solv->bestrules = solv->nrules;
  if (!installed)
    {
      solv->bestrules_end = solv->nrules;
      return;
    }
  queue_init(&q);
  queue_init(&q2);
  queue_init(&r2pkg);

  if (havebestinstalljobs)
    {
      for (i = 0; i < solv->job.count; i += 2)
	{
	  if ((solv->job.elements[i] & (SOLVER_JOBMASK | SOLVER_FORCEBEST)) == (SOLVER_INSTALL | SOLVER_FORCEBEST))
	    {
	      int j;
	      Id p2, pp2;
	      for (j = 0; j < solv->ruletojob.count; j++)
		if (solv->ruletojob.elements[j] == i)
		  break;
	      if (j == solv->ruletojob.count)
		continue;
	      r = solv->rules + solv->jobrules + j;
	      queue_empty(&q);
	      FOR_RULELITERALS(p2, pp2, r)
		if (p2 > 0)
		  queue_push(&q, p2);
	      if (!q.count)
		continue;	/* orphaned */
	      /* select best packages, just look at prio and version */
	      oldcnt = q.count;
	      policy_filter_unwanted(solv, &q, POLICY_MODE_RECOMMEND);
	      if (q.count == oldcnt)
		continue;	/* nothing filtered */
	      p2 = queue_shift(&q);
	      if (q.count < 2)
	        solver_addrule(solv, p2, q.count ? q.elements[0] : 0, 0);
	      else
	        solver_addrule(solv, p2, 0, pool_queuetowhatprovides(pool, &q));
	      queue_push(&r2pkg, -(solv->jobrules + j));
	    }
	}
    }

  if (solv->bestupdatemap_all || solv->bestupdatemap.size)
    {
      FOR_REPO_SOLVABLES(installed, p, s)
	{
	  Id d, p2, pp2;
	  if (!solv->updatemap_all && (!solv->updatemap.size || !MAPTST(&solv->updatemap, p - installed->start)))
	    continue;
	  if (!solv->bestupdatemap_all && (!solv->bestupdatemap.size || !MAPTST(&solv->bestupdatemap, p - installed->start)))
	    continue;
	  queue_empty(&q);
	  if (solv->bestobeypolicy)
	    r = solv->rules + solv->updaterules + (p - installed->start);
	  else
	    {
	      r = solv->rules + solv->featurerules + (p - installed->start);
	      if (!r->p)	/* identical to update rule? */
		r = solv->rules + solv->updaterules + (p - installed->start);
	    }
	  if (solv->specialupdaters && (d = solv->specialupdaters[p - installed->start]) != 0 && r == solv->rules + solv->updaterules + (p - installed->start))
	    {
	      /* need to check specialupdaters */
	      if (r->p == p)	/* be careful with the dup case */
		queue_push(&q, p);
	      while ((p2 = pool->whatprovidesdata[d++]) != 0)
		queue_push(&q, p2);
	    }
	  else
	    {
	      FOR_RULELITERALS(p2, pp2, r)
		if (p2 > 0)
		  queue_push(&q, p2);
	    }
	  if (solv->update_targets && solv->update_targets->elements[p - installed->start])
	    prune_to_update_targets(solv, solv->update_targets->elements + solv->update_targets->elements[p - installed->start], &q);
	  if (solv->dupinvolvedmap.size && MAPTST(&solv->dupinvolvedmap, p))
	    prune_to_dup_packages(solv, p, &q);
	  /* select best packages, just look at prio and version */
	  policy_filter_unwanted(solv, &q, POLICY_MODE_RECOMMEND);
	  if (!q.count)
	    continue;	/* orphaned */
	  if (solv->bestobeypolicy)
	    {
	      /* also filter the best of the feature rule packages and add them */
	      r = solv->rules + solv->featurerules + (p - installed->start);
	      if (r->p)
		{
		  int j;
		  queue_empty(&q2);
		  FOR_RULELITERALS(p2, pp2, r)
		    if (p2 > 0)
		      queue_push(&q2, p2);
		  if (solv->update_targets && solv->update_targets->elements[p - installed->start])
		    prune_to_update_targets(solv, solv->update_targets->elements + solv->update_targets->elements[p - installed->start], &q2);
		  if (solv->dupinvolvedmap.size && MAPTST(&solv->dupinvolvedmap, p))
		    prune_to_dup_packages(solv, p, &q2);
		  policy_filter_unwanted(solv, &q2, POLICY_MODE_RECOMMEND);
		  for (j = 0; j < q2.count; j++)
		    queue_pushunique(&q, q2.elements[j]);
		}
	    }
	  p2 = queue_shift(&q);
	  if (q.count < 2)
	    solver_addrule(solv, p2, q.count ? q.elements[0] : 0, 0);
	  else
	    solver_addrule(solv, p2, 0, pool_queuetowhatprovides(pool, &q));
	  queue_push(&r2pkg, p);
	}
    }
  if (r2pkg.count)
    solv->bestrules_pkg = solv_memdup2(r2pkg.elements, r2pkg.count, sizeof(Id));
  solv->bestrules_end = solv->nrules;
  queue_free(&q);
  queue_free(&q2);
  queue_free(&r2pkg);
}




/* yumobs rule handling */

static void
find_obsolete_group(Solver *solv, Id obs, Queue *q)
{
  Pool *pool = solv->pool;
  Queue qn;
  Id p2, pp2, op, *opp, opp2;
  int i, j, qnc, ncnt;

  queue_empty(q);
  FOR_PROVIDES(p2, pp2, obs)
    {
      Solvable *s2 = pool->solvables + p2;
      if (s2->repo != pool->installed)
	continue;
      if (!pool->obsoleteusesprovides && !pool_match_nevr(pool, pool->solvables + p2, obs))
	continue;
      /* we obsolete installed package s2 with obs. now find all other packages that have the same dep  */
      for (opp = solv->obsoletes_data + solv->obsoletes[p2 - solv->installed->start]; (op = *opp++) != 0;)
	{
	  Solvable *os = pool->solvables + op;
	  Id obs2, *obsp2;
	  if (!os->obsoletes)
	    continue;
	  if (pool->obsoleteusescolors && !pool_colormatch(pool, s2, os))
	    continue;
	  obsp2 = os->repo->idarraydata + os->obsoletes; 
	  while ((obs2 = *obsp2++) != 0)
	    if (obs2 == obs)
	      break;
	  if (obs2)
	    queue_pushunique(q, op);
	}
      /* also search packages with the same name */
      FOR_PROVIDES(op, opp2, s2->name)
	{
	  Solvable *os = pool->solvables + op;
	  Id obs2, *obsp2;
	  if (os->name != s2->name)
	    continue;
	  if (!os->obsoletes)
	    continue;
	  if (pool->obsoleteusescolors && !pool_colormatch(pool, s2, os))
	    continue;
	  obsp2 = os->repo->idarraydata + os->obsoletes; 
	  while ((obs2 = *obsp2++) != 0)
	    if (obs2 == obs)
	      break;
	  if (obs2)
	    queue_pushunique(q, op);
	}
    }
  /* find names so that we can build groups */
  queue_init_clone(&qn, q);
  prune_to_best_version(solv->pool, &qn);
#if 0
{
  for (i = 0; i < qn.count; i++)
    printf(" + %s\n", pool_solvid2str(pool, qn.elements[i]));
}
#endif
  /* filter into name groups */
  qnc = qn.count;
  if (qnc == 1)
    {
      queue_free(&qn);
      queue_empty(q);
      return;
    }
  ncnt = 0;
  for (i = 0; i < qnc; i++)
    {
      Id n = pool->solvables[qn.elements[i]].name;
      int got = 0;
      for (j = 0; j < q->count; j++)
	{
	  Id p = q->elements[j];
	  if (pool->solvables[p].name == n)
	    {
	      queue_push(&qn, p);
	      got = 1;
	    }
	}
      if (got)
	{
	  queue_push(&qn, 0);
	  ncnt++;
	}
    }
  if (ncnt <= 1)
    {
      queue_empty(q);
    }
  else
    {
      queue_empty(q);
      queue_insertn(q, 0, qn.count - qnc, qn.elements + qnc);
    }
  queue_free(&qn);
}

void
solver_addyumobsrules(Solver *solv)
{
  Pool *pool = solv->pool;
  Repo *installed = solv->installed;
  Id p, op, *opp;
  Solvable *s;
  Queue qo, qq, yumobsinfoq;
  int i, j, k;
  unsigned int now;

  solv->yumobsrules = solv->nrules;
  if (!installed || !solv->obsoletes)
    {
      solv->yumobsrules_end = solv->nrules;
      return;
    }
  now = solv_timems(0);
  queue_init(&qo);
  FOR_REPO_SOLVABLES(installed, p, s)
    {
      if (!solv->obsoletes[p - installed->start])
	continue;
#if 0
printf("checking yumobs for %s\n", pool_solvable2str(pool, s));
#endif
      queue_empty(&qo);
      for (opp = solv->obsoletes_data + solv->obsoletes[p - installed->start]; (op = *opp++) != 0;)
	{
	  Solvable *os = pool->solvables + op;
          Id obs, *obsp = os->repo->idarraydata + os->obsoletes;
	  Id p2, pp2;
	  while ((obs = *obsp++) != 0)
	    {
	      FOR_PROVIDES(p2, pp2, obs)
		{
		  Solvable *s2 = pool->solvables + p2;
		  if (s2->repo != installed)
		    continue;
		  if (!pool->obsoleteusesprovides && !pool_match_nevr(pool, pool->solvables + p2, obs))
		    continue;
		  if (pool->obsoleteusescolors && !pool_colormatch(pool, s, s2))
		    continue;
		  queue_pushunique(&qo, obs);
		  break;
		}
	    }
	}
    }
  if (!qo.count)
    {
      queue_free(&qo);
      return;
    }
  queue_init(&yumobsinfoq);
  queue_init(&qq);
  for (i = 0; i < qo.count; i++)
    {
      int group, groupk, groupstart;
      queue_empty(&qq);
#if 0
printf("investigating %s\n", pool_dep2str(pool, qo.elements[i]));
#endif
      find_obsolete_group(solv, qo.elements[i], &qq);
#if 0
printf("result:\n");
for (j = 0; j < qq.count; j++)
  if (qq.elements[j] == 0)
    printf("---\n");
  else
    printf("%s\n", pool_solvid2str(pool, qq.elements[j]));
#endif
  
      if (!qq.count)
	continue;
      /* at least two goups, build rules */
      group = 0;
      for (j = 0; j < qq.count; j++)
	{
	  p = qq.elements[j];
	  if (!p)
	    {
	      group++;
	      continue;
	    }
	  if (pool->solvables[p].repo == installed)
	    continue;
	  groupk = 0;
	  groupstart = 0;
	  for (k = 0; k < qq.count; k++)
	    {
	      Id pk = qq.elements[k];
	      if (pk)
		continue;
	      if (group != groupk && k > groupstart)
		{
		  /* add the rule */
		  if (k - groupstart == 1)
		    solver_addrule(solv, -p, qq.elements[groupstart], 0);
		  else
		    solver_addrule(solv, -p, 0, pool_ids2whatprovides(pool, qq.elements + groupstart, k - groupstart));
		  queue_push(&yumobsinfoq, qo.elements[i]);
		}
	      groupstart = k + 1;
	      groupk++;
	    }
	}
    }
  if (yumobsinfoq.count)
    solv->yumobsrules_info = solv_memdup2(yumobsinfoq.elements, yumobsinfoq.count, sizeof(Id));
  queue_free(&yumobsinfoq);
  queue_free(&qq);
  queue_free(&qo);
  solv->yumobsrules_end = solv->nrules;
  POOL_DEBUG(SOLV_DEBUG_STATS, "yumobs rule creation took %d ms\n", solv_timems(now));
}

#undef CLEANDEPSDEBUG

/*
 * This functions collects all packages that are looked at
 * when a dependency is checked. We need it to "pin" installed
 * packages when removing a supplemented package in createcleandepsmap.
 * Here's an not uncommon example:
 *   A contains "Supplements: packageand(B, C)"
 *   B contains "Requires: A"
 * Now if we remove C, the supplements is no longer true,
 * thus we also remove A. Without the dep_pkgcheck function, we
 * would now also remove B, but this is wrong, as adding back
 * C doesn't make the supplements true again. Thus we "pin" B
 * when we remove A.
 * There's probably a better way to do this, but I haven't come
 * up with it yet ;)
 */
static inline void
dep_pkgcheck(Solver *solv, Id dep, Map *m, Queue *q)
{
  Pool *pool = solv->pool;
  Id p, pp;

  if (ISRELDEP(dep))
    {
      Reldep *rd = GETRELDEP(pool, dep);
      if (rd->flags >= 8)
	{
	  if (rd->flags == REL_AND)
	    {
	      dep_pkgcheck(solv, rd->name, m, q);
	      dep_pkgcheck(solv, rd->evr, m, q);
	      return;
	    }
	  if (rd->flags == REL_NAMESPACE && rd->name == NAMESPACE_SPLITPROVIDES)
	    return;
	}
    }
  FOR_PROVIDES(p, pp, dep)
    if (!m || MAPTST(m, p))
      queue_push(q, p);
}

static int
check_xsupp(Solver *solv, Queue *depq, Id dep)
{
  Pool *pool = solv->pool;
  Id p, pp;

  if (ISRELDEP(dep))
    {
      Reldep *rd = GETRELDEP(pool, dep);
      if (rd->flags >= 8)
	{
	  if (rd->flags == REL_AND)
	    {
	      if (!check_xsupp(solv, depq, rd->name))
		return 0;
	      return check_xsupp(solv, depq, rd->evr);
	    }
	  if (rd->flags == REL_OR)
	    {
	      if (check_xsupp(solv, depq, rd->name))
		return 1;
	      return check_xsupp(solv, depq, rd->evr);
	    }
	  if (rd->flags == REL_NAMESPACE && rd->name == NAMESPACE_SPLITPROVIDES)
#if 0
	    return solver_splitprovides(solv, rd->evr);
#else
	    return 0;
#endif
	}
      if (depq && rd->flags == REL_NAMESPACE)
	{
	  int i;
	  for (i = 0; i < depq->count; i++)
	    if (depq->elements[i] == dep || depq->elements[i] == rd->name)
	     return 1;
	}
    }
  FOR_PROVIDES(p, pp, dep)
    if (p == SYSTEMSOLVABLE || pool->solvables[p].repo == solv->installed)
      return 1;
  return 0;
}

static inline int
queue_contains(Queue *q, Id id)
{
  int i;
  for (i = 0; i < q->count; i++)
    if (q->elements[i] == id)
      return 1;
  return 0;
}

#ifdef ENABLE_COMPLEX_DEPS
static void
complex_cleandeps_remove(Pool *pool, Id ip, Id req, Map *im, Map *installedm, Queue *iq)
{
  int i;
  Queue dq;
  Id p;

  queue_init(&dq);
  i = pool_normalize_complex_dep(pool, req, &dq, CPLXDEPS_EXPAND);
  if (i == 0 || i == 1)
    {
      queue_free(&dq);
      return;
    }
  for (i = 0; i < dq.count; i++)
    {
      for (; (p = dq.elements[i]) != 0; i++)
	{
	  if (p < 0)
	    {
	      if (!MAPTST(installedm, -p))
	        break;
	      continue;
	    }
	  if (p != SYSTEMSOLVABLE && MAPTST(im, p))
	    {
#ifdef CLEANDEPSDEBUG
	      printf("%s requires/recommends %s\n", pool_solvid2str(pool, ip), pool_solvid2str(pool, p));
#endif
	      queue_push(iq, p);
	    }
	}
      while (dq.elements[i])
	i++;
    }
  queue_free(&dq);
}

static void
complex_cleandeps_addback(Pool *pool, Id ip, Id req, Map *im, Map *installedm, Queue *iq, Map *userinstalled)
{
  int i, blk;
  Queue dq;
  Id p;

  queue_init(&dq);
  i = pool_normalize_complex_dep(pool, req, &dq, CPLXDEPS_EXPAND);
  if (i == 0 || i == 1)
    {
      queue_free(&dq);
      return;
    }
  for (i = 0; i < dq.count; i++)
    {
      blk = i;
      for (; (p = dq.elements[i]) != 0; i++)
	{
	  if (p < 0)
	    {
	      if (!MAPTST(installedm, -p))
	        break;
	      continue;
	    }
	  if (MAPTST(im, p))
	    break;
	}
      if (!p)
	{
	  for (i = blk; (p = dq.elements[i]) != 0; i++)
	    {
	      if (p < 0)
		continue;
	      if (!MAPTST(installedm, p))
		continue;
	      if (p == ip || MAPTST(userinstalled, p - pool->installed->start))
		continue;
#ifdef CLEANDEPSDEBUG
	      printf("%s requires/recommends %s\n", pool_solvid2str(pool, ip), pool_solvid2str(pool, p));
#endif
	      MAPSET(im, p);
	      queue_push(iq, p);
	    }
	}
      while (dq.elements[i])
	i++;
    }
  queue_free(&dq);
}

#endif

/*
 * Find all installed packages that are no longer
 * needed regarding the current solver job.
 *
 * The algorithm is:
 * - remove pass: remove all packages that could have
 *   been dragged in by the obsoleted packages.
 *   i.e. if package A is obsolete and contains "Requires: B",
 *   also remove B, as installing A will have pulled in B.
 *   after this pass, we have a set of still installed packages
 *   with broken dependencies.
 * - add back pass:
 *   now add back all packages that the still installed packages
 *   require.
 *
 * The cleandeps packages are the packages removed in the first
 * pass and not added back in the second pass.
 *
 * If we search for unneeded packages (unneeded is true), we
 * simply remove all packages except the userinstalled ones in
 * the first pass.
 */
static void
solver_createcleandepsmap(Solver *solv, Map *cleandepsmap, int unneeded)
{
  Pool *pool = solv->pool;
  Repo *installed = solv->installed;
  Queue *job = &solv->job;
  Map userinstalled;
  Map im;
  Map installedm;
  Rule *r;
  Id rid, how, what, select;
  Id p, pp, ip, jp;
  Id req, *reqp, sup, *supp;
  Solvable *s;
  Queue iq, iqcopy, xsuppq;
  int i;

  map_empty(cleandepsmap);
  if (!installed || installed->end == installed->start)
    return;
  map_init(&userinstalled, installed->end - installed->start);
  map_init(&im, pool->nsolvables);
  map_init(&installedm, pool->nsolvables);
  queue_init(&iq);
  queue_init(&xsuppq);

  for (i = 0; i < job->count; i += 2)
    {
      how = job->elements[i];
      if ((how & SOLVER_JOBMASK) == SOLVER_USERINSTALLED)
	{
	  what = job->elements[i + 1];
	  select = how & SOLVER_SELECTMASK;
	  if (select == SOLVER_SOLVABLE_ALL || (select == SOLVER_SOLVABLE_REPO && what == installed->repoid))
	    FOR_REPO_SOLVABLES(installed, p, s)
	      MAPSET(&userinstalled, p - installed->start);
	  FOR_JOB_SELECT(p, pp, select, what)
	    if (pool->solvables[p].repo == installed)
	      MAPSET(&userinstalled, p - installed->start);
	}
      if ((how & (SOLVER_JOBMASK | SOLVER_SELECTMASK)) == (SOLVER_ERASE | SOLVER_SOLVABLE_PROVIDES))
	{
	  what = job->elements[i + 1];
	  if (ISRELDEP(what))
	    {
	      Reldep *rd = GETRELDEP(pool, what);
	      if (rd->flags != REL_NAMESPACE)
		continue;
	      if (rd->evr == 0)
		{
		  queue_pushunique(&iq, rd->name);
		  continue;
		}
	      FOR_PROVIDES(p, pp, what)
		if (p)
		  break;
	      if (p)
		continue;
	      queue_pushunique(&iq, what);
	    }
	}
    }

  /* have special namespace cleandeps erases */
  if (iq.count)
    {
      for (ip = installed->start; ip < installed->end; ip++)
	{
	  s = pool->solvables + ip;
	  if (s->repo != installed)
	    continue;
	  if (!s->supplements)
	    continue;
	  supp = s->repo->idarraydata + s->supplements;
	  while ((sup = *supp++) != 0)
	    if (ISRELDEP(sup) && check_xsupp(solv, &iq, sup) && !check_xsupp(solv, 0, sup))
	      {
#ifdef CLEANDEPSDEBUG
		printf("xsupp %s from %s\n", pool_dep2str(pool, sup), pool_solvid2str(pool, ip));
#endif
	        queue_pushunique(&xsuppq, sup);
	      }
	}
      queue_empty(&iq);
    }

  /* also add visible patterns to userinstalled for openSUSE */
  if (1)
    {
      Dataiterator di;
      dataiterator_init(&di, pool, 0, 0, SOLVABLE_ISVISIBLE, 0, 0);
      while (dataiterator_step(&di))
	{
	  Id *dp;
	  if (di.solvid <= 0)
	    continue;
	  s = pool->solvables + di.solvid;
	  if (!s->repo || !s->requires)
	    continue;
	  if (s->repo != installed && !pool_installable(pool, s))
	    continue;
	  if (strncmp(pool_id2str(pool, s->name), "pattern:", 8) != 0)
	    continue;
	  dp = s->repo->idarraydata + s->requires;
	  for (dp = s->repo->idarraydata + s->requires; *dp; dp++)
	    FOR_PROVIDES(p, pp, *dp)
	      if (pool->solvables[p].repo == installed)
		{
		  if (strncmp(pool_id2str(pool, pool->solvables[p].name), "pattern", 7) != 0)
		    continue;
		  MAPSET(&userinstalled, p - installed->start);
		}
	}
      dataiterator_free(&di);
    }
  if (1)
    {
      /* all products and their buddies are userinstalled */
      for (p = installed->start; p < installed->end; p++)
	{
	  Solvable *s = pool->solvables + p;
	  if (s->repo != installed)
	    continue;
	  if (!strncmp("product:", pool_id2str(pool, s->name), 8))
	    {
	      MAPSET(&userinstalled, p - installed->start);
#ifdef ENABLE_LINKED_PKGS
	      if (solv->instbuddy && solv->instbuddy[p - installed->start] > 1)
		{
		  Id buddy = solv->instbuddy[p - installed->start];
		  if (buddy >= installed->start && buddy < installed->end)
		    MAPSET(&userinstalled, buddy - installed->start);
		}
#endif
	    }
	}
    }

  /* add all positive elements (e.g. locks) to "userinstalled" */
  for (rid = solv->jobrules; rid < solv->jobrules_end; rid++)
    {
      r = solv->rules + rid;
      if (r->d < 0)
	continue;
      i = solv->ruletojob.elements[rid - solv->jobrules];
      if ((job->elements[i] & SOLVER_CLEANDEPS) == SOLVER_CLEANDEPS)
	continue;
      FOR_RULELITERALS(p, jp, r)
	if (p > 0 && pool->solvables[p].repo == installed)
	  MAPSET(&userinstalled, p - installed->start);
    }

  /* add all cleandeps candidates to iq */
  for (rid = solv->jobrules; rid < solv->jobrules_end; rid++)
    {
      r = solv->rules + rid;
      if (r->d < 0)				/* disabled? */
	continue;
      if (r->d == 0 && r->p < 0 && r->w2 == 0)	/* negative assertion (erase job)? */
	{
	  p = -r->p;
	  if (pool->solvables[p].repo != installed)
	    continue;
	  MAPCLR(&userinstalled, p - installed->start);
	  if (unneeded)
	    continue;
	  i = solv->ruletojob.elements[rid - solv->jobrules];
	  how = job->elements[i];
	  if ((how & (SOLVER_JOBMASK|SOLVER_CLEANDEPS)) == (SOLVER_ERASE|SOLVER_CLEANDEPS))
	    queue_push(&iq, p);
	}
      else if (r->p > 0)			/* install job */
	{
	  if (unneeded)
	    continue;
	  i = solv->ruletojob.elements[rid - solv->jobrules];
	  if ((job->elements[i] & SOLVER_CLEANDEPS) == SOLVER_CLEANDEPS)
	    {
	      /* check if the literals all obsolete some installed package */
	      Map om;
	      int iqstart;

	      /* just one installed literal */
	      if (r->d == 0 && r->w2 == 0 && pool->solvables[r->p].repo == installed)
		continue;
	      /* multiversion is bad */
	      if (solv->multiversion.size && !solv->keepexplicitobsoletes)
		{
		  FOR_RULELITERALS(p, jp, r)
		    if (MAPTST(&solv->multiversion, p))
		      break;
		  if (p)
		    continue;
		}

	      om.size = 0;
	      iqstart = iq.count;
	      FOR_RULELITERALS(p, jp, r)
		{
		  if (p < 0)
		    {
		      queue_truncate(&iq, iqstart);	/* abort */
		      break;
		    }
		  if (pool->solvables[p].repo == installed)
		    {
		      if (iq.count == iqstart)
			queue_push(&iq, p);
		      else
			{
			  for (i = iqstart; i < iq.count; i++)
			    if (iq.elements[i] == p)
			      break;
			  queue_truncate(&iq, iqstart);
			  if (i < iq.count)
			    queue_push(&iq, p);
			}
		    }
		  else
		    intersect_obsoletes(solv, p, &iq, iqstart, &om);
		  if (iq.count == iqstart)
		    break;
		}
	      if (om.size)
	        map_free(&om);
	    }
	}
    }
  queue_init_clone(&iqcopy, &iq);

  if (!unneeded)
    {
      if (solv->cleandeps_updatepkgs)
	for (i = 0; i < solv->cleandeps_updatepkgs->count; i++)
	  queue_push(&iq, solv->cleandeps_updatepkgs->elements[i]);
    }

  if (unneeded)
    queue_empty(&iq);	/* just in case... */

  /* clear userinstalled bit for the packages we really want to delete/update */
  for (i = 0; i < iq.count; i++)
    {
      p = iq.elements[i];
      if (pool->solvables[p].repo != installed)
	continue;
      MAPCLR(&userinstalled, p - installed->start);
    }

  for (p = installed->start; p < installed->end; p++)
    {
      if (pool->solvables[p].repo != installed)
	continue;
      MAPSET(&installedm, p);
      if (unneeded && !MAPTST(&userinstalled, p - installed->start))
	continue;
      MAPSET(&im, p);
    }
  MAPSET(&installedm, SYSTEMSOLVABLE);
  MAPSET(&im, SYSTEMSOLVABLE);

#ifdef CLEANDEPSDEBUG
  printf("REMOVE PASS\n");
#endif

  for (;;)
    {
      if (!iq.count)
	{
	  if (unneeded)
	    break;
	  /* supplements pass */
	  for (ip = installed->start; ip < installed->end; ip++)
	    {
	      if (!MAPTST(&installedm, ip))
		continue;
	      s = pool->solvables + ip;
	      if (!s->supplements)
		continue;
	      if (!MAPTST(&im, ip))
		continue;
	      if (MAPTST(&userinstalled, ip - installed->start))
		continue;
	      supp = s->repo->idarraydata + s->supplements;
	      while ((sup = *supp++) != 0)
		if (dep_possible(solv, sup, &im))
		  break;
	      if (!sup)
		{
		  supp = s->repo->idarraydata + s->supplements;
		  while ((sup = *supp++) != 0)
		    if (dep_possible(solv, sup, &installedm) || (xsuppq.count && queue_contains(&xsuppq, sup)))
		      {
		        /* no longer supplemented, also erase */
			int iqcount = iq.count;
			/* pin packages, see comment above dep_pkgcheck */
			dep_pkgcheck(solv, sup, &im, &iq);
			for (i = iqcount; i < iq.count; i++)
			  {
			    Id pqp = iq.elements[i];
			    if (pool->solvables[pqp].repo == installed)
			      MAPSET(&userinstalled, pqp - installed->start);
			  }
			queue_truncate(&iq, iqcount);
#ifdef CLEANDEPSDEBUG
		        printf("%s supplemented [%s]\n", pool_solvid2str(pool, ip), pool_dep2str(pool, sup));
#endif
		        queue_push(&iq, ip);
		      }
		}
	    }
	  if (!iq.count)
	    break;	/* no supplementing package found, we're done */
	}
      ip = queue_shift(&iq);
      s = pool->solvables + ip;
      if (!MAPTST(&im, ip))
	continue;
      if (!MAPTST(&installedm, ip))
	continue;
      if (s->repo == installed && MAPTST(&userinstalled, ip - installed->start))
	continue;
      MAPCLR(&im, ip);
#ifdef CLEANDEPSDEBUG
      printf("removing %s\n", pool_solvable2str(pool, s));
#endif
      if (s->requires)
	{
	  reqp = s->repo->idarraydata + s->requires;
	  while ((req = *reqp++) != 0)
	    {
	      if (req == SOLVABLE_PREREQMARKER)
		continue;
#ifdef ENABLE_COMPLEX_DEPS
	      if (pool_is_complex_dep(pool, req))
		{
		  complex_cleandeps_remove(pool, ip, req, &im, &installedm, &iq);
		  continue;
		}
#endif
	      FOR_PROVIDES(p, pp, req)
		{
		  if (p != SYSTEMSOLVABLE && MAPTST(&im, p))
		    {
#ifdef CLEANDEPSDEBUG
		      printf("%s requires %s\n", pool_solvid2str(pool, ip), pool_solvid2str(pool, p));
#endif
		      queue_push(&iq, p);
		    }
		}
	    }
	}
      if (s->recommends)
	{
	  reqp = s->repo->idarraydata + s->recommends;
	  while ((req = *reqp++) != 0)
	    {
#ifdef ENABLE_COMPLEX_DEPS
	      if (pool_is_complex_dep(pool, req))
		{
		  complex_cleandeps_remove(pool, ip, req, &im, &installedm, &iq);
		  continue;
		}
#endif
	      FOR_PROVIDES(p, pp, req)
		{
		  if (p != SYSTEMSOLVABLE && MAPTST(&im, p))
		    {
#ifdef CLEANDEPSDEBUG
		      printf("%s recommends %s\n", pool_solvid2str(pool, ip), pool_solvid2str(pool, p));
#endif
		      queue_push(&iq, p);
		    }
		}
	    }
	}
    }

  /* turn userinstalled into remove set for pruning */
  map_empty(&userinstalled);
  for (rid = solv->jobrules; rid < solv->jobrules_end; rid++)
    {
      r = solv->rules + rid;
      if (r->p >= 0 || r->d != 0 || r->w2 != 0)
	continue;	/* disabled or not erase */
      p = -r->p;
      MAPCLR(&im, p);
      if (pool->solvables[p].repo == installed)
        MAPSET(&userinstalled, p - installed->start);
    }
  if (!unneeded && solv->cleandeps_updatepkgs)
    {
      for (i = 0; i < solv->cleandeps_updatepkgs->count; i++)
	{
	  p = solv->cleandeps_updatepkgs->elements[i];
	  if (pool->solvables[p].repo == installed)
	    MAPSET(&userinstalled, p - installed->start);
	}
    }
  MAPSET(&im, SYSTEMSOLVABLE);	/* in case we cleared it above */
  for (p = installed->start; p < installed->end; p++)
    if (MAPTST(&im, p))
      queue_push(&iq, p);
  for (rid = solv->jobrules; rid < solv->jobrules_end; rid++)
    {
      r = solv->rules + rid;
      if (r->d < 0)
	continue;
      FOR_RULELITERALS(p, jp, r)
	if (p > 0)
          queue_push(&iq, p);
    }
  /* also put directly addressed packages on the install queue
   * so we can mark patterns as installed */
  for (i = 0; i < job->count; i += 2)
    {
      how = job->elements[i];
      if ((how & SOLVER_JOBMASK) == SOLVER_USERINSTALLED)
	{
	  what = job->elements[i + 1];
	  select = how & SOLVER_SELECTMASK;
	  if (select == SOLVER_SOLVABLE && pool->solvables[what].repo != installed)
            queue_push(&iq, what);
	}
    }

#ifdef CLEANDEPSDEBUG
  printf("ADDBACK PASS\n");
#endif
  for (;;)
    {
      if (!iq.count)
	{
	  /* supplements pass */
	  for (ip = installed->start; ip < installed->end; ip++)
	    {
	      if (!MAPTST(&installedm, ip))
		continue;
	      if (MAPTST(&userinstalled, ip - installed->start))
	        continue;
	      s = pool->solvables + ip;
	      if (!s->supplements)
		continue;
	      if (MAPTST(&im, ip))
		continue;
	      supp = s->repo->idarraydata + s->supplements;
	      while ((sup = *supp++) != 0)
		if (dep_possible(solv, sup, &im))
		  break;
	      if (sup)
		{
#ifdef CLEANDEPSDEBUG
		  printf("%s supplemented\n", pool_solvid2str(pool, ip));
#endif
		  MAPSET(&im, ip);
		  queue_push(&iq, ip);
		}
	    }
	  if (!iq.count)
	    break;
	}
      ip = queue_shift(&iq);
      s = pool->solvables + ip;
#ifdef CLEANDEPSDEBUG
      printf("adding back %s\n", pool_solvable2str(pool, s));
#endif
      if (s->requires)
	{
	  reqp = s->repo->idarraydata + s->requires;
	  while ((req = *reqp++) != 0)
	    {
#ifdef ENABLE_COMPLEX_DEPS
	      if (pool_is_complex_dep(pool, req))
		{
		  complex_cleandeps_addback(pool, ip, req, &im, &installedm, &iq, &userinstalled);
		  continue;
		}
#endif
	      FOR_PROVIDES(p, pp, req)
		if (MAPTST(&im, p))
		  break;
	      if (p)
		continue;
	      FOR_PROVIDES(p, pp, req)
		{
		  if (MAPTST(&installedm, p))
		    {
		      if (p == ip)
			continue;
		      if (MAPTST(&userinstalled, p - installed->start))
			continue;
#ifdef CLEANDEPSDEBUG
		      printf("%s requires %s\n", pool_solvid2str(pool, ip), pool_solvid2str(pool, p));
#endif
		      MAPSET(&im, p);
		      queue_push(&iq, p);
		    }
		}
	    }
	}
      if (s->recommends)
	{
	  reqp = s->repo->idarraydata + s->recommends;
	  while ((req = *reqp++) != 0)
	    {
#ifdef ENABLE_COMPLEX_DEPS
	      if (pool_is_complex_dep(pool, req))
		{
		  complex_cleandeps_addback(pool, ip, req, &im, &installedm, &iq, &userinstalled);
		  continue;
		}
#endif
	      FOR_PROVIDES(p, pp, req)
		if (MAPTST(&im, p))
		  break;
	      if (p)
		continue;
	      FOR_PROVIDES(p, pp, req)
		{
		  if (MAPTST(&installedm, p))
		    {
		      if (p == ip)
			continue;
		      if (MAPTST(&userinstalled, p - installed->start))
			continue;
#ifdef CLEANDEPSDEBUG
		      printf("%s recommends %s\n", pool_solvid2str(pool, ip), pool_solvid2str(pool, p));
#endif
		      MAPSET(&im, p);
		      queue_push(&iq, p);
		    }
		}
	    }
	}
    }

  queue_free(&iq);
  /* make sure the updatepkgs and mistakes are not in the cleandeps map */
  if (solv->cleandeps_updatepkgs)
    for (i = 0; i < solv->cleandeps_updatepkgs->count; i++)
      MAPSET(&im, solv->cleandeps_updatepkgs->elements[i]);
  if (solv->cleandeps_mistakes)
    for (i = 0; i < solv->cleandeps_mistakes->count; i++)
      MAPSET(&im, solv->cleandeps_mistakes->elements[i]);
  /* also remove original iq packages */
  for (i = 0; i < iqcopy.count; i++)
    MAPSET(&im, iqcopy.elements[i]);
  queue_free(&iqcopy);
  for (p = installed->start; p < installed->end; p++)
    {
      if (pool->solvables[p].repo != installed)
	continue;
      if (!MAPTST(&im, p))
        MAPSET(cleandepsmap, p - installed->start);
    }
  map_free(&im);
  map_free(&installedm);
  map_free(&userinstalled);
  queue_free(&xsuppq);
#ifdef CLEANDEPSDEBUG
  printf("=== final cleandeps map:\n");
  for (p = installed->start; p < installed->end; p++)
    if (MAPTST(cleandepsmap, p - installed->start))
      printf("  - %s\n", pool_solvid2str(pool, p));
#endif
}


struct trj_data {
  Queue *edges;
  Id *low;
  Id idx;
  Id nstack;
  Id firstidx;
};

/* Tarjan's SCC algorithm, slightly modifed */
static void
trj_visit(struct trj_data *trj, Id node)
{
  Id *low = trj->low;
  Queue *edges = trj->edges;
  Id nnode, myidx, stackstart;
  int i;

  low[node] = myidx = trj->idx++;
  low[(stackstart = trj->nstack++)] = node;
  for (i = edges->elements[node]; (nnode = edges->elements[i]) != 0; i++)
    {
      Id l = low[nnode];
      if (!l)
	{
	  if (!edges->elements[edges->elements[nnode]])
	    {
	      trj->idx++;
	      low[nnode] = -1;
	      continue;
	    }
	  trj_visit(trj, nnode);
	  l = low[nnode];
	}
      if (l < 0)
	continue;
      if (l < trj->firstidx)
	{
	  int k;
	  for (k = l; low[low[k]] == l; k++)
	    low[low[k]] = -1;
	}
      else if (l < low[node])
	low[node] = l;
    }
  if (low[node] == myidx)
    {
      if (myidx != trj->firstidx)
	myidx = -1;
      for (i = stackstart; i < trj->nstack; i++)
	low[low[i]] = myidx;
      trj->nstack = stackstart;
    }
}

#ifdef ENABLE_COMPLEX_DEPS
static void
complex_unneeded(Pool *pool, Id ip, Id req, Queue *edges, Map *cleandepsmap, Queue *unneededq)
{
  int i, j;
  Queue dq;
  Id p;

  queue_init(&dq);
  i = pool_normalize_complex_dep(pool, req, &dq, CPLXDEPS_EXPAND);
  if (i == 0 || i == 1)
    {
      queue_free(&dq);
      return;
    }
  for (i = 0; i < dq.count; i++)
    {
      for (; (p = dq.elements[i]) != 0; i++)
	{
	  if (p < 0)
	    {
	      if (pool->solvables[-p].repo != pool->installed)
	        break;
	      continue;
	    }
	  if (p == ip || pool->solvables[p].repo != pool->installed || !MAPTST(cleandepsmap, p - pool->installed->start))
	    continue;
	  for (j = 0; j < unneededq->count; j++)
	    if (p == unneededq->elements[j])
	      {
		if (edges->elements[edges->count - 1] != j + 1)
		  queue_push(edges, j + 1);
	        break;
	      }
	}
      while (dq.elements[i])
	i++;
    }
  queue_free(&dq);
}
#endif

void
solver_get_unneeded(Solver *solv, Queue *unneededq, int filtered)
{
  Repo *installed = solv->installed;
  int i;
  Map cleandepsmap;

  queue_empty(unneededq);
  if (!installed || installed->end == installed->start)
    return;

  map_init(&cleandepsmap, installed->end - installed->start);
  solver_createcleandepsmap(solv, &cleandepsmap, 1);
  for (i = installed->start; i < installed->end; i++)
    if (MAPTST(&cleandepsmap, i - installed->start))
      queue_push(unneededq, i);

  if (filtered && unneededq->count > 1)
    {
      Pool *pool = solv->pool;
      Queue edges;
      Id *nrequires;
      Map installedm;
      int j, pass, count = unneededq->count;
      Id *low;

      map_init(&installedm, pool->nsolvables);
      for (i = installed->start; i < installed->end; i++)
	if (pool->solvables[i].repo == installed)
	  MAPSET(&installedm, i);

      nrequires = solv_calloc(count, sizeof(Id));
      queue_init(&edges);
      queue_prealloc(&edges, count * 4 + 10);	/* pre-size */

      /*
       * Go through the solvables in the nodes queue and create edges for
       * all requires/recommends/supplements between the nodes.
       * The edges are stored in the edges queue, we add 1 to the node
       * index so that nodes in the edges queue are != 0 and we can
       * terminate the edge list with 0.
       * Thus for node element 5, the edges are stored starting at
       * edges.elements[6] and are 0-terminated.
       */
      /* leave first element zero to make things easier */
      /* also add trailing zero */
      queue_insertn(&edges, 0, 1 + count + 1, 0);

      /* first requires and recommends */
      for (i = 0; i < count; i++)
	{
	  Solvable *s = pool->solvables + unneededq->elements[i];
	  int oldcount = edges.count;
	  edges.elements[i + 1] = oldcount;
	  for (pass = 0; pass < 2; pass++)
	    {
	      unsigned int off = pass == 0 ? s->requires : s->recommends;
	      Id p, pp, dep, *dp;
	      if (off)
		for (dp = s->repo->idarraydata + off; (dep = *dp) != 0; dp++)
		  {
#ifdef ENABLE_COMPLEX_DEPS
		    if (pool_is_complex_dep(pool, dep))
		      {
			complex_unneeded(pool, s - pool->solvables, dep, &edges, &cleandepsmap, unneededq);
			continue;
		      }
#endif
		    FOR_PROVIDES(p, pp, dep)
		      {
			Solvable *sp = pool->solvables + p;
			if (s == sp || sp->repo != installed || !MAPTST(&cleandepsmap, p - installed->start))
			  continue;
			for (j = 0; j < count; j++)
			  if (p == unneededq->elements[j])
			    {
			      if (edges.elements[edges.count - 1] != j + 1)
			        queue_push(&edges, j + 1);
			    }
		      }
		  }
	      if (pass == 0)
	        nrequires[i] = edges.count - oldcount;
	    }
	  queue_push(&edges, 0);
	}
#if 0
      printf("requires + recommends\n");
      for (i = 0; i < count; i++)
	{
	  int j;
	  printf("  %s (%d requires):\n", pool_solvid2str(pool, unneededq->elements[i]), nrequires[i]);
	  for (j = edges.elements[i + 1]; edges.elements[j]; j++)
	    printf("    - %s\n", pool_solvid2str(pool, unneededq->elements[edges.elements[j] - 1]));
	}
#endif

      /* then add supplements */
      for (i = 0; i < count; i++)
	{
	  Solvable *s = pool->solvables + unneededq->elements[i];
	  if (s->supplements)
	    {
	      Id *dp;
	      int k;
	      for (dp = s->repo->idarraydata + s->supplements; *dp; dp++)
		if (dep_possible(solv, *dp, &installedm))
		  {
		    Queue iq;
		    Id iqbuf[16];
		    queue_init_buffer(&iq, iqbuf, sizeof(iqbuf)/sizeof(*iqbuf));
		    dep_pkgcheck(solv, *dp, 0, &iq);
		    for (k = 0; k < iq.count; k++)
		      {
			Id p = iq.elements[k];
			Solvable *sp = pool->solvables + p;
			if (p == unneededq->elements[i] || sp->repo != installed || !MAPTST(&cleandepsmap, p - installed->start))
			  continue;
			for (j = 0; j < count; j++)
			  if (p == unneededq->elements[j])
			    break;
			/* now add edge from j + 1 to i + 1 */
			queue_insert(&edges, edges.elements[j + 1] + nrequires[j], i + 1);
			/* addapt following edge pointers */
			for (j = j + 2; j < count + 1; j++)
			  edges.elements[j]++;
		      }
		    queue_free(&iq);
		  }
	    }
	}
#if 0
      /* print result */
      printf("+ supplements\n");
      for (i = 0; i < count; i++)
	{
	  int j;
	  printf("  %s (%d requires):\n", pool_solvid2str(pool, unneededq->elements[i]), nrequires[i]);
	  for (j = edges.elements[i + 1]; edges.elements[j]; j++)
	    printf("    - %s\n", pool_solvid2str(pool, unneededq->elements[edges.elements[j] - 1]));
        }
#endif
      map_free(&installedm);

      /* now run SCC algo two times, first with requires+recommends+supplements,
       * then again without the requires. We run it the second time to get rid
       * of packages that got dragged in via recommends/supplements */
      /*
       * low will contain the result of the SCC search.
       * it must be of at least size 2 * (count + 1) and
       * must be zero initialized.
       * The layout is:
       *    0  low low ... low stack stack ...stack 0
       *            count              count
       */
      low = solv_calloc(count + 1, 2 * sizeof(Id));
      for (pass = 0; pass < 2; pass++)
	{
	  struct trj_data trj;
	  if (pass)
	    {
	      memset(low, 0, (count + 1) * (2 * sizeof(Id)));
	      for (i = 0; i < count; i++)
		{
	          edges.elements[i + 1] += nrequires[i];
		  if (!unneededq->elements[i])
		    low[i + 1] = -1;	/* ignore this node */
		}
	    }
	  trj.edges = &edges;
	  trj.low = low;
	  trj.idx = count + 1;	/* stack starts here */
	  for (i = 1; i <= count; i++)
	    {
	      if (low[i])
		continue;
	      if (edges.elements[edges.elements[i]])
		{
		  trj.firstidx = trj.nstack = trj.idx;
		  trj_visit(&trj, i);
		}
	      else
		{
		  Id myidx = trj.idx++;
		  low[i] = myidx;
		  low[myidx] = i;
		}
	    }
	  /* prune packages */
	  for (i = 0; i < count; i++)
	    if (low[i + 1] <= 0)
	      unneededq->elements[i] = 0;
	}
      solv_free(low);
      solv_free(nrequires);
      queue_free(&edges);

      /* finally remove all pruned entries from unneededq */
      for (i = j = 0; i < count; i++)
	if (unneededq->elements[i])
	  unneededq->elements[j++] = unneededq->elements[i];
      queue_truncate(unneededq, j);
    }
  map_free(&cleandepsmap);
}


void
solver_breakorphans(Solver *solv)
{
  Pool *pool = solv->pool;
  Repo *installed = solv->installed;
  int i, rid;
  Map m;

  if (!installed || solv->droporphanedmap_all)
    return;
  solv->brokenorphanrules = solv_calloc(1, sizeof(Queue));
  queue_init(solv->brokenorphanrules);
  map_init(&m, installed->end - installed->start);
  for (i = 0; i < solv->orphaned.count; i++)
    {
      Id p = solv->orphaned.elements[i];
      if (pool->solvables[p].repo != installed)
	continue;
      if (solv->droporphanedmap.size && MAPTST(&solv->droporphanedmap, p - installed->start))
	continue;
      MAPSET(&m, p - installed->start);
    }
  for (rid = 1; rid < solv->pkgrules_end ; rid++)
    {
      Id p, *dp;
      Rule *r = solv->rules + rid;
      /* ignore non-deps and simple conflicts */
      if (r->p >= 0 || ((r->d == 0 || r->d == -1) && r->w2 < 0))
	continue;
      p = -r->p;
      if (p < installed->start || p >= installed->end || !MAPTST(&m, p - installed->start))
	{
	  /* need to check other literals */
	  if (r->d == 0 || r->d == -1)
	    continue;
	  for (dp = pool->whatprovidesdata + (r->d < 0 ? -r->d - 1 : r->d); *dp < 0; dp++)
	    {
	      p = -*dp;
	      if (p >= installed->start && p < installed->end && MAPTST(&m, p - installed->start))
		break;
	    }
	  if (*dp >= 0)
	    continue;
	}
      /* ok, disable this rule */
      queue_push(solv->brokenorphanrules, rid);
      if (r->d >= 0)
	solver_disablerule(solv, r);
    }
  map_free(&m);
  if (!solv->brokenorphanrules->count)
    {
      queue_free(solv->brokenorphanrules);
      solv->brokenorphanrules = solv_free(solv->brokenorphanrules);
    }
}

void
solver_check_brokenorphanrules(Solver *solv, Queue *dq)
{
  Pool *pool = solv->pool;
  int i;
  Id l, pp;
  
  queue_empty(dq);
  if (!solv->brokenorphanrules)
    return;
  for (i = 0; i < solv->brokenorphanrules->count; i++)
    {
      int rid = solv->brokenorphanrules->elements[i];
      Rule *r = solv->rules + rid;
      FOR_RULELITERALS(l, pp, r)
	{
	  if (l < 0)
	    {
	      if (solv->decisionmap[-l] <= 0)
		break;
	    }
	  else
	    {
	      if (solv->decisionmap[l] > 0 && pool->solvables[l].repo != solv->installed)
		break;
	    }
	}
      if (l)
	continue;
      FOR_RULELITERALS(l, pp, r)
        if (l > 0 && solv->decisionmap[l] == 0 && pool->solvables[l].repo != solv->installed)
	  queue_pushunique(dq, l);
    }
}

