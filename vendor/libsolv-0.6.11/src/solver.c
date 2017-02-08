/*
 * Copyright (c) 2007-2008, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * solver.c
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
#include "util.h"
#include "policy.h"
#include "poolarch.h"
#include "solverdebug.h"
#include "cplxdeps.h"
#include "linkedpkg.h"

#define RULES_BLOCK 63


/********************************************************************
 *
 * dependency check helpers
 *
 */

/*-------------------------------------------------------------------
 * handle split provides
 *
 * a splitprovides dep looks like
 *     namespace:splitprovides(pkg REL_WITH path)
 * and is only true if pkg is installed and contains the specified path.
 * we also make sure that pkg is selected for an update, otherwise the
 * update would always be forced onto the user.
 * Map m is the map used when called from dep_possible.
 */

static int
solver_is_updating(Solver *solv, Id p)
{
  /* check if the update rule is true */
  Pool *pool = solv->pool;
  Rule *r;
  Id l, pp;
  if (solv->decisionmap[p] >= 0)
    return 0;	/* old package stayed */
  r = solv->rules + solv->updaterules + (p - solv->installed->start);
  FOR_RULELITERALS(l, pp, r)
    if (l > 0 && l != p && solv->decisionmap[l] > 0)
      return 1;
  return 0;
}

int
solver_splitprovides(Solver *solv, Id dep, Map *m)
{
  Pool *pool = solv->pool;
  Id p, pp;
  Reldep *rd;
  Solvable *s;

  if (!solv->dosplitprovides || !solv->installed)
    return 0;
  if (!ISRELDEP(dep))
    return 0;
  rd = GETRELDEP(pool, dep);
  if (rd->flags != REL_WITH)
    return 0;
  /*
   * things are a bit tricky here if pool->addedprovides == 1, because most split-provides are in
   * a non-standard location. If we simply call pool_whatprovides, we'll drag in the complete
   * file list. Instead we rely on pool_addfileprovides ignoring the addfileprovidesfiltered flag
   * for installed packages and check the lazywhatprovidesq (ignoring the REL_WITH part, but
   * we filter the package name further down anyway).
   */
  if (pool->addedfileprovides == 1 && !ISRELDEP(rd->evr) && !pool->whatprovides[rd->evr])
    pp = pool_searchlazywhatprovidesq(pool, rd->evr);
  else
    pp = pool_whatprovides(pool, dep);
  while ((p = pool->whatprovidesdata[pp++]) != 0)
    {
      /* here we have packages that provide the correct name and contain the path,
       * now do extra filtering */
      s = pool->solvables + p;
      if (s->repo != solv->installed || s->name != rd->name)
	continue;
      /* check if the package is updated. if m is set, we're called from dep_possible */
      if (m || solver_is_updating(solv, p))
	return 1;
    }
  return 0;
}


/* mirrors solver_dep_fulfilled, but returns 2 if a new package
 * was involved */
static int
solver_dep_fulfilled_alreadyinstalled(Solver *solv, Id dep)
{
  Pool *pool = solv->pool;
  Id p, pp;
  int r;

  if (ISRELDEP(dep))
    {
      Reldep *rd = GETRELDEP(pool, dep);
      if (rd->flags == REL_AND)
        {
	  int r2, r1 = solver_dep_fulfilled_alreadyinstalled(solv, rd->name);
          if (!r1)
            return 0;
	  r2 = solver_dep_fulfilled_alreadyinstalled(solv, rd->evr);
	  if (!r2)
	    return 0;
          return r1 == 2 || r2 == 2 ? 2 : 1;
        }
      if (rd->flags == REL_OR)
	{
	  int r2, r1 = solver_dep_fulfilled_alreadyinstalled(solv, rd->name);
	  r2 = solver_dep_fulfilled_alreadyinstalled(solv, rd->evr);
	  if (!r1 && !r2)
	    return 0;
          return r1 == 2 || r2 == 2 ? 2 : 1;
	}
      if (rd->flags == REL_NAMESPACE && rd->name == NAMESPACE_SPLITPROVIDES)
        return solver_splitprovides(solv, rd->evr, 0);
      if (rd->flags == REL_NAMESPACE && solv->installsuppdepq)
	{
	  Queue *q = solv->installsuppdepq;
	  int i;
	  for (i = 0; i < q->count; i++)
	    if (q->elements[i] == dep || q->elements[i] == rd->name)
	      return 2;
	}
    }
  r = 0;
  FOR_PROVIDES(p, pp, dep)
    if (solv->decisionmap[p] > 0)
      {
	Solvable *s = pool->solvables + p;
	if (s->repo && s->repo != solv->installed)
	  return 2;
        r = 1;
      }
  return r;
}

static int
solver_is_supplementing_alreadyinstalled(Solver *solv, Solvable *s)
{
  Id sup, *supp;
  supp = s->repo->idarraydata + s->supplements;
  while ((sup = *supp++) != 0)
    if (solver_dep_fulfilled_alreadyinstalled(solv, sup) == 2)
      return 1;
  return 0;
}

static Id
autouninstall(Solver *solv, Id *problem)
{
  Pool *pool = solv->pool;
  int i;
  int lastfeature = 0, lastupdate = 0;
  Id v;
  Id extraflags = -1;

  for (i = 0; (v = problem[i]) != 0; i++)
    {
      if (v < 0)
	extraflags &= solv->job.elements[-v - 1];
      if (v >= solv->updaterules && v < solv->updaterules_end)
	{
	  /* check if identical to feature rule, we don't like that */
	  Rule *r = solv->rules + solv->featurerules + (v - solv->updaterules);
	  if (!r->p)
	    {
	      /* update rule == feature rule */
	      if (v > lastfeature)
		lastfeature = v;
	      continue;
	    }
	  if (v > lastupdate)
	    lastupdate = v;
	}
    }
  if (!lastupdate && !lastfeature)
    return 0;
  v = lastupdate ? lastupdate : lastfeature;
  POOL_DEBUG(SOLV_DEBUG_UNSOLVABLE, "allowuninstall disabling ");
  solver_printruleclass(solv, SOLV_DEBUG_UNSOLVABLE, solv->rules + v);
  solver_disableproblem(solv, v);
  if (extraflags != -1 && (extraflags & SOLVER_CLEANDEPS) != 0 && solv->cleandepsmap.size)
    {
      /* add the package to the updatepkgs list, this will automatically turn
       * on cleandeps mode */
      Id p = solv->rules[v].p;
      if (!solv->cleandeps_updatepkgs)
	{
	  solv->cleandeps_updatepkgs = solv_calloc(1, sizeof(Queue));
	  queue_init(solv->cleandeps_updatepkgs);
	}
      if (p > 0)
	{
	  int oldupdatepkgscnt = solv->cleandeps_updatepkgs->count;
          queue_pushunique(solv->cleandeps_updatepkgs, p);
	  if (solv->cleandeps_updatepkgs->count != oldupdatepkgscnt)
	    solver_disablepolicyrules(solv);
	}
    }
  return v;
}

/************************************************************************/

/*
 * enable/disable learnt rules
 *
 * we have enabled or disabled some of our rules. We now reenable all
 * of our learnt rules except the ones that were learnt from rules that
 * are now disabled.
 */
static void
enabledisablelearntrules(Solver *solv)
{
  Pool *pool = solv->pool;
  Rule *r;
  Id why, *whyp;
  int i;

  POOL_DEBUG(SOLV_DEBUG_SOLUTIONS, "enabledisablelearntrules called\n");
  for (i = solv->learntrules, r = solv->rules + i; i < solv->nrules; i++, r++)
    {
      whyp = solv->learnt_pool.elements + solv->learnt_why.elements[i - solv->learntrules];
      while ((why = *whyp++) != 0)
	{
	  assert(why > 0 && why < i);
	  if (solv->rules[why].d < 0)
	    break;
	}
      /* why != 0: we found a disabled rule, disable the learnt rule */
      if (why && r->d >= 0)
	{
	  IF_POOLDEBUG (SOLV_DEBUG_SOLUTIONS)
	    {
	      POOL_DEBUG(SOLV_DEBUG_SOLUTIONS, "disabling ");
	      solver_printruleclass(solv, SOLV_DEBUG_SOLUTIONS, r);
	    }
          solver_disablerule(solv, r);
	}
      else if (!why && r->d < 0)
	{
	  IF_POOLDEBUG (SOLV_DEBUG_SOLUTIONS)
	    {
	      POOL_DEBUG(SOLV_DEBUG_SOLUTIONS, "re-enabling ");
	      solver_printruleclass(solv, SOLV_DEBUG_SOLUTIONS, r);
	    }
          solver_enablerule(solv, r);
	}
    }
}


/*
 * make assertion rules into decisions
 *
 * Go through rules and add direct assertions to the decisionqueue.
 * If we find a conflict, disable rules and add them to problem queue.
 */

static void
makeruledecisions(Solver *solv)
{
  Pool *pool = solv->pool;
  int i, ri, ii;
  Rule *r, *rr;
  Id v, vv;
  int decisionstart;
  int record_proof = 1;
  int oldproblemcount;
  int havedisabled = 0;

  /* The system solvable is always installed first */
  assert(solv->decisionq.count == 0);
  queue_push(&solv->decisionq, SYSTEMSOLVABLE);
  queue_push(&solv->decisionq_why, 0);
  solv->decisionmap[SYSTEMSOLVABLE] = 1;	/* installed at level '1' */

  decisionstart = solv->decisionq.count;
  for (;;)
    {
      /* if we needed to re-run, back up decisions to decisionstart */
      while (solv->decisionq.count > decisionstart)
	{
	  v = solv->decisionq.elements[--solv->decisionq.count];
	  --solv->decisionq_why.count;
	  vv = v > 0 ? v : -v;
	  solv->decisionmap[vv] = 0;
	}

      /* note that the ruleassertions queue is ordered */
      for (ii = 0; ii < solv->ruleassertions.count; ii++)
	{
	  ri = solv->ruleassertions.elements[ii];
	  r = solv->rules + ri;

          if (havedisabled && ri >= solv->learntrules)
	    {
	      /* just started with learnt rule assertions. If we have disabled
               * some rules, adapt the learnt rule status */
	      enabledisablelearntrules(solv);
	      havedisabled = 0;
	    }

	  if (r->d < 0 || !r->p || r->w2)	/* disabled, dummy or no assertion */
	    continue;

	  /* do weak rules in phase 2 */
	  if (ri < solv->learntrules && solv->weakrulemap.size && MAPTST(&solv->weakrulemap, ri))
	    continue;

	  v = r->p;
	  vv = v > 0 ? v : -v;

	  if (!solv->decisionmap[vv])          /* if not yet decided */
	    {
	      queue_push(&solv->decisionq, v);
	      queue_push(&solv->decisionq_why, r - solv->rules);
	      solv->decisionmap[vv] = v > 0 ? 1 : -1;
	      IF_POOLDEBUG (SOLV_DEBUG_PROPAGATE)
		{
		  Solvable *s = solv->pool->solvables + vv;
		  if (v < 0)
		    POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "conflicting %s (assertion)\n", pool_solvable2str(solv->pool, s));
		  else
		    POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "installing  %s (assertion)\n", pool_solvable2str(solv->pool, s));
		}
	      continue;
	    }

	  /* check against previous decision: is there a conflict? */
	  if (v > 0 && solv->decisionmap[vv] > 0)    /* ok to install */
	    continue;
	  if (v < 0 && solv->decisionmap[vv] < 0)    /* ok to remove */
	    continue;

	  /*
	   * found a conflict!
	   *
	   * The rule (r) we're currently processing says something
	   * different (v = r->p) than a previous decision (decisionmap[abs(v)])
	   * on this literal
	   */

	  if (ri >= solv->learntrules)
	    {
	      /* conflict with a learnt rule */
	      /* can happen when packages cannot be installed for multiple reasons. */
	      /* we disable the learnt rule in this case */
	      /* (XXX: we should really call analyze_unsolvable_rule here!) */
	      solver_disablerule(solv, r);
	      continue;
	    }

	  /*
	   * find the decision which is the "opposite" of the rule
	   */
	  for (i = 0; i < solv->decisionq.count; i++)
	    if (solv->decisionq.elements[i] == -v)
	      break;
	  assert(i < solv->decisionq.count);         /* assert that we found it */
	  oldproblemcount = solv->problems.count;

	  /*
	   * conflict with system solvable ?
	   */
	  if (v == -SYSTEMSOLVABLE)
	    {
	      if (record_proof)
		{
		  queue_push(&solv->problems, solv->learnt_pool.count);
		  queue_push(&solv->learnt_pool, ri);
		  queue_push(&solv->learnt_pool, 0);
		}
	      else
		queue_push(&solv->problems, 0);
	      POOL_DEBUG(SOLV_DEBUG_UNSOLVABLE, "conflict with system solvable, disabling rule #%d\n", ri);
	      if  (ri >= solv->jobrules && ri < solv->jobrules_end)
		v = -(solv->ruletojob.elements[ri - solv->jobrules] + 1);
	      else
		v = ri;
	      queue_push(&solv->problems, v);
	      queue_push(&solv->problems, 0);
	      if (solv->allowuninstall && v >= solv->featurerules && v < solv->updaterules_end)
		solv->problems.count = oldproblemcount;
	      solver_disableproblem(solv, v);
	      havedisabled = 1;
	      break;	/* start over */
	    }

	  assert(solv->decisionq_why.elements[i] > 0);

	  /*
	   * conflict with a pkg rule ?
	   */
	  if (solv->decisionq_why.elements[i] < solv->pkgrules_end)
	    {
	      if (record_proof)
		{
		  queue_push(&solv->problems, solv->learnt_pool.count);
		  queue_push(&solv->learnt_pool, ri);
		  queue_push(&solv->learnt_pool, solv->decisionq_why.elements[i]);
		  queue_push(&solv->learnt_pool, 0);
		}
	      else
		queue_push(&solv->problems, 0);
	      assert(v > 0 || v == -SYSTEMSOLVABLE);
	      POOL_DEBUG(SOLV_DEBUG_UNSOLVABLE, "conflict with pkg rule, disabling rule #%d\n", ri);
	      if (ri >= solv->jobrules && ri < solv->jobrules_end)
		v = -(solv->ruletojob.elements[ri - solv->jobrules] + 1);
	      else
		v = ri;
	      queue_push(&solv->problems, v);
	      queue_push(&solv->problems, 0);
	      if (solv->allowuninstall && v >= solv->featurerules && v < solv->updaterules_end)
		solv->problems.count = oldproblemcount;
	      solver_disableproblem(solv, v);
	      havedisabled = 1;
	      break;	/* start over */
	    }

	  /*
	   * conflict with another job or update/feature rule
	   */

	  /* record proof */
	  if (record_proof)
	    {
	      queue_push(&solv->problems, solv->learnt_pool.count);
	      queue_push(&solv->learnt_pool, ri);
	      queue_push(&solv->learnt_pool, solv->decisionq_why.elements[i]);
	      queue_push(&solv->learnt_pool, 0);
	    }
	  else
	    queue_push(&solv->problems, 0);

	  POOL_DEBUG(SOLV_DEBUG_UNSOLVABLE, "conflicting update/job assertions over literal %d\n", vv);

	  /*
	   * push all of our rules (can only be feature or job rules)
	   * asserting this literal on the problem stack
	   */
	  for (i = solv->featurerules, rr = solv->rules + i; i < solv->learntrules; i++, rr++)
	    {
	      if (rr->d < 0                          /* disabled */
		  || rr->w2)                         /*  or no assertion */
		continue;
	      if (rr->p != vv                        /* not affecting the literal */
		  && rr->p != -vv)
		continue;
	      if (solv->weakrulemap.size && MAPTST(&solv->weakrulemap, i))     /* weak: silently ignore */
		continue;
		
	      POOL_DEBUG(SOLV_DEBUG_UNSOLVABLE, " - disabling rule #%d\n", i);
	      solver_printruleclass(solv, SOLV_DEBUG_UNSOLVABLE, solv->rules + i);
		
	      v = i;
	      if (i >= solv->jobrules && i < solv->jobrules_end)
		v = -(solv->ruletojob.elements[i - solv->jobrules] + 1);
	      queue_push(&solv->problems, v);
	    }
	  queue_push(&solv->problems, 0);

	  if (solv->allowuninstall && (v = autouninstall(solv, solv->problems.elements + oldproblemcount + 1)) != 0)
	    solv->problems.count = oldproblemcount;

	  for (i = oldproblemcount + 1; i < solv->problems.count - 1; i++)
	    solver_disableproblem(solv, solv->problems.elements[i]);
	  havedisabled = 1;
	  break;	/* start over */
	}
      if (ii < solv->ruleassertions.count)
	continue;

      /*
       * phase 2: now do the weak assertions
       */
      if (!solv->weakrulemap.size)
	break;				/* no weak rules, no phase 2 */
      for (ii = 0; ii < solv->ruleassertions.count; ii++)
	{
	  ri = solv->ruleassertions.elements[ii];
	  r = solv->rules + ri;
	  if (r->d < 0 || r->w2)	                 /* disabled or no assertion */
	    continue;
	  if (ri >= solv->learntrules || !MAPTST(&solv->weakrulemap, ri))       /* skip non-weak */
	    continue;
	  v = r->p;
	  vv = v > 0 ? v : -v;

	  if (!solv->decisionmap[vv])          /* if not yet decided */
	    {
	      queue_push(&solv->decisionq, v);
	      queue_push(&solv->decisionq_why, r - solv->rules);
	      solv->decisionmap[vv] = v > 0 ? 1 : -1;
	      IF_POOLDEBUG (SOLV_DEBUG_PROPAGATE)
		{
		  Solvable *s = solv->pool->solvables + vv;
		  if (v < 0)
		    POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "conflicting %s (weak assertion)\n", pool_solvable2str(solv->pool, s));
		  else
		    POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "installing  %s (weak assertion)\n", pool_solvable2str(solv->pool, s));
		}
	      continue;
	    }
	  /* check against previous decision: is there a conflict? */
	  if (v > 0 && solv->decisionmap[vv] > 0)
	    continue;
	  if (v < 0 && solv->decisionmap[vv] < 0)
	    continue;

	  POOL_DEBUG(SOLV_DEBUG_UNSOLVABLE, "assertion conflict, but I am weak, disabling ");
	  solver_printrule(solv, SOLV_DEBUG_UNSOLVABLE, r);

	  if (ri >= solv->jobrules && ri < solv->jobrules_end)
	    v = -(solv->ruletojob.elements[ri - solv->jobrules] + 1);
	  else
	    v = ri;
	  solver_disableproblem(solv, v);
	  if (v < 0)
	    solver_reenablepolicyrules(solv, -v);
	  havedisabled = 1;
	  break;	/* start over */
	}
      if (ii == solv->ruleassertions.count)
	break;	/* finished! */
    }
}


/********************************************************************/
/* watches */


/*-------------------------------------------------------------------
 * makewatches
 *
 * initial setup for all watches
 */

static void
makewatches(Solver *solv)
{
  Rule *r;
  int i;
  int nsolvables = solv->pool->nsolvables;

  solv_free(solv->watches);
  /* lower half for removals, upper half for installs */
  solv->watches = solv_calloc(2 * nsolvables, sizeof(Id));
  for (i = 1, r = solv->rules + solv->nrules - 1; i < solv->nrules; i++, r--)
    {
      if (!r->w2)		/* assertions do not need watches */
	continue;

      /* see addwatches_rule(solv, r) */
      r->n1 = solv->watches[nsolvables + r->w1];
      solv->watches[nsolvables + r->w1] = r - solv->rules;

      r->n2 = solv->watches[nsolvables + r->w2];
      solv->watches[nsolvables + r->w2] = r - solv->rules;
    }
}


/*-------------------------------------------------------------------
 *
 * add watches (for a new learned rule)
 * sets up watches for a single rule
 *
 * see also makewatches() above.
 */

static inline void
addwatches_rule(Solver *solv, Rule *r)
{
  int nsolvables = solv->pool->nsolvables;

  r->n1 = solv->watches[nsolvables + r->w1];
  solv->watches[nsolvables + r->w1] = r - solv->rules;

  r->n2 = solv->watches[nsolvables + r->w2];
  solv->watches[nsolvables + r->w2] = r - solv->rules;
}


/********************************************************************/
/*
 * rule propagation
 */


/* shortcuts to check if a literal (positive or negative) assignment
 * evaluates to 'true' or 'false'
 */
#define DECISIONMAP_TRUE(p) ((p) > 0 ? (decisionmap[p] > 0) : (decisionmap[-p] < 0))
#define DECISIONMAP_FALSE(p) ((p) > 0 ? (decisionmap[p] < 0) : (decisionmap[-p] > 0))
#define DECISIONMAP_UNDEF(p) (decisionmap[(p) > 0 ? (p) : -(p)] == 0)

/*-------------------------------------------------------------------
 *
 * propagate
 *
 * make decision and propagate to all rules
 *
 * Evaluate each term affected by the decision (linked through watches).
 * If we find unit rules we make new decisions based on them.
 *
 * return : 0 = everything is OK
 *          rule = conflict found in this rule
 */

static Rule *
propagate(Solver *solv, int level)
{
  Pool *pool = solv->pool;
  Id *rp, *next_rp;           /* rule pointer, next rule pointer in linked list */
  Rule *r;                    /* rule */
  Id p, pkg, other_watch;
  Id *dp;
  Id *decisionmap = solv->decisionmap;
  Id *watches = solv->watches + pool->nsolvables;   /* place ptr in middle */

  POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "----- propagate -----\n");

  /* foreach non-propagated decision */
  while (solv->propagate_index < solv->decisionq.count)
    {
      /*
       * 'pkg' was just decided
       * negate because our watches trigger if literal goes FALSE
       */
      pkg = -solv->decisionq.elements[solv->propagate_index++];
	
      IF_POOLDEBUG (SOLV_DEBUG_PROPAGATE)
        {
	  POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "propagate for decision %d level %d\n", -pkg, level);
	  solver_printruleelement(solv, SOLV_DEBUG_PROPAGATE, 0, -pkg);
        }

      /* foreach rule where 'pkg' is now FALSE */
      for (rp = watches + pkg; *rp; rp = next_rp)
	{
	  r = solv->rules + *rp;
	  if (r->d < 0)
	    {
	      /* rule is disabled, goto next */
	      if (pkg == r->w1)
	        next_rp = &r->n1;
	      else
	        next_rp = &r->n2;
	      continue;
	    }

	  IF_POOLDEBUG (SOLV_DEBUG_PROPAGATE)
	    {
	      POOL_DEBUG(SOLV_DEBUG_PROPAGATE,"  watch triggered ");
	      solver_printrule(solv, SOLV_DEBUG_PROPAGATE, r);
	    }

	  /*
           * 'pkg' was just decided (was set to FALSE), so this rule
	   * may now be unit.
	   */
	  /* find the other watch */
	  if (pkg == r->w1)
	    {
	      other_watch = r->w2;
	      next_rp = &r->n1;
	    }
	  else
	    {
	      other_watch = r->w1;
	      next_rp = &r->n2;
	    }

	  /*
	   * if the other watch is true we have nothing to do
	   */
	  if (DECISIONMAP_TRUE(other_watch))
	    continue;

	  /*
	   * The other literal is FALSE or UNDEF
	   *
	   */

          if (r->d)
	    {
	      /* Not a binary clause, try to move our watch.
	       *
	       * Go over all literals and find one that is
	       *   not other_watch
	       *   and not FALSE
	       *
	       * (TRUE is also ok, in that case the rule is fulfilled)
	       * As speed matters here we do not use the FOR_RULELITERALS
	       * macro.
	       */
	      if (r->p                                /* we have a 'p' */
		  && r->p != other_watch              /* which is not watched */
		  && !DECISIONMAP_FALSE(r->p))        /* and not FALSE */
		{
		  p = r->p;
		}
	      else                                    /* go find a 'd' to make 'true' */
		{
		  /* foreach p in 'd'
		     we just iterate sequentially, doing it in another order just changes the order of decisions, not the decisions itself
		   */
		  for (dp = pool->whatprovidesdata + r->d; (p = *dp++) != 0;)
		    {
		      if (p != other_watch              /* which is not watched */
		          && !DECISIONMAP_FALSE(p))     /* and not FALSE */
		        break;
		    }
		}

	      if (p)
		{
		  /*
		   * if we found some p that is UNDEF or TRUE, move
		   * watch to it
		   */
		  IF_POOLDEBUG (SOLV_DEBUG_PROPAGATE)
		    {
		      if (p > 0)
			POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "    -> move w%d to %s\n", (pkg == r->w1 ? 1 : 2), pool_solvid2str(pool, p));
		      else
			POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "    -> move w%d to !%s\n", (pkg == r->w1 ? 1 : 2), pool_solvid2str(pool, -p));
		    }

		  *rp = *next_rp;
		  next_rp = rp;

		  if (pkg == r->w1)
		    {
		      r->w1 = p;
		      r->n1 = watches[p];
		    }
		  else
		    {
		      r->w2 = p;
		      r->n2 = watches[p];
		    }
		  watches[p] = r - solv->rules;
		  continue;
		}
	      /* search failed, thus all unwatched literals are FALSE */
		
	    } /* not binary */

          /*
	   * unit clause found, set literal other_watch to TRUE
	   */

	  if (DECISIONMAP_FALSE(other_watch))	   /* check if literal is FALSE */
	    return r;  		                   /* eek, a conflict! */

	  IF_POOLDEBUG (SOLV_DEBUG_PROPAGATE)
	    {
	      POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "  unit ");
	      solver_printrule(solv, SOLV_DEBUG_PROPAGATE, r);
	    }

	  if (other_watch > 0)
            decisionmap[other_watch] = level;    /* install! */
	  else
	    decisionmap[-other_watch] = -level;  /* remove! */

	  queue_push(&solv->decisionq, other_watch);
	  queue_push(&solv->decisionq_why, r - solv->rules);

	  IF_POOLDEBUG (SOLV_DEBUG_PROPAGATE)
	    {
	      if (other_watch > 0)
		POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "    -> decided to install %s\n", pool_solvid2str(pool, other_watch));
	      else
		POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "    -> decided to conflict %s\n", pool_solvid2str(pool, -other_watch));
	    }

	} /* foreach rule involving 'pkg' */
	
    } /* while we have non-decided decisions */

  POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "----- propagate end-----\n");

  return 0;	/* all is well */
}


/********************************************************************/
/* Analysis */

/*-------------------------------------------------------------------
 *
 * revert
 * revert decisionq to a level
 */

static void
revert(Solver *solv, int level)
{
  Pool *pool = solv->pool;
  Id v, vv;
  while (solv->decisionq.count)
    {
      v = solv->decisionq.elements[solv->decisionq.count - 1];
      vv = v > 0 ? v : -v;
      if (solv->decisionmap[vv] <= level && solv->decisionmap[vv] >= -level)
        break;
      POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "reverting decision %d at %d\n", v, solv->decisionmap[vv]);
      solv->decisionmap[vv] = 0;
      solv->decisionq.count--;
      solv->decisionq_why.count--;
      solv->propagate_index = solv->decisionq.count;
    }
  while (solv->branches.count && solv->branches.elements[solv->branches.count - 1] >= level)
    solv->branches.count -= solv->branches.elements[solv->branches.count - 2];
  if (solv->recommends_index > solv->decisionq.count)
    solv->recommends_index = -1;	/* rebuild recommends/suggests maps */
  if (solv->decisionq.count < solv->decisioncnt_jobs)
    solv->decisioncnt_jobs = 0;
  if (solv->decisionq.count < solv->decisioncnt_update)
    solv->decisioncnt_update = 0;
  if (solv->decisionq.count < solv->decisioncnt_keep)
    solv->decisioncnt_keep = 0;
  if (solv->decisionq.count < solv->decisioncnt_resolve)
    solv->decisioncnt_resolve = 0;
  if (solv->decisionq.count < solv->decisioncnt_weak)
    solv->decisioncnt_weak= 0;
  if (solv->decisionq.count < solv->decisioncnt_orphan)
    solv->decisioncnt_orphan = 0;
}

/*-------------------------------------------------------------------
 *
 * watch2onhighest - put watch2 on literal with highest level
 */

static inline void
watch2onhighest(Solver *solv, Rule *r)
{
  int l, wl = 0;
  Id d, v, *dp;

  d = r->d < 0 ? -r->d - 1 : r->d;
  if (!d)
    return;	/* binary rule, both watches are set */
  dp = solv->pool->whatprovidesdata + d;
  while ((v = *dp++) != 0)
    {
      l = solv->decisionmap[v < 0 ? -v : v];
      if (l < 0)
	l = -l;
      if (l > wl)
	{
	  r->w2 = dp[-1];
	  wl = l;
	}
    }
}


/*-------------------------------------------------------------------
 *
 * analyze
 *   and learn
 */

static int
analyze(Solver *solv, int level, Rule *c, Rule **lrp)
{
  Pool *pool = solv->pool;
  Queue q;
  Rule *r;
  Id q_buf[8];
  int rlevel = 1;
  Map seen;		/* global? */
  Id p = 0, pp, v, vv, why;
  int l, i, idx;
  int num = 0, l1num = 0;
  int learnt_why = solv->learnt_pool.count;
  Id *decisionmap = solv->decisionmap;

  queue_init_buffer(&q, q_buf, sizeof(q_buf)/sizeof(*q_buf));

  POOL_DEBUG(SOLV_DEBUG_ANALYZE, "ANALYZE at %d ----------------------\n", level);
  map_init(&seen, pool->nsolvables);
  idx = solv->decisionq.count;
  for (;;)
    {
      IF_POOLDEBUG (SOLV_DEBUG_ANALYZE)
	solver_printruleclass(solv, SOLV_DEBUG_ANALYZE, c);
      queue_push(&solv->learnt_pool, c - solv->rules);
      FOR_RULELITERALS(v, pp, c)
	{
	  if (DECISIONMAP_TRUE(v))	/* the one true literal */
	    continue;
	  vv = v > 0 ? v : -v;
	  if (MAPTST(&seen, vv))
	    continue;
	  MAPSET(&seen, vv);		/* mark that we also need to look at this literal */
	  l = solv->decisionmap[vv];
	  if (l < 0)
	    l = -l;
	  if (l == 1)
	    l1num++;			/* need to do this one in level1 pass */
	  else if (l == level)
	    num++;			/* need to do this one as well */
	  else
	    {
	      queue_push(&q, v);	/* not level1 or conflict level, add to new rule */
	      if (l > rlevel)
		rlevel = l;
	    }
	}
l1retry:
      if (!num && !--l1num)
	break;	/* all literals done */

      /* find the next literal to investigate */
      /* (as num + l1num > 0, we know that we'll always find one) */
      for (;;)
	{
	  assert(idx > 0);
	  v = solv->decisionq.elements[--idx];
	  vv = v > 0 ? v : -v;
	  if (MAPTST(&seen, vv))
	    break;
	}
      MAPCLR(&seen, vv);

      if (num && --num == 0)
	{
	  /* done with normal literals, now start level 1 literal processing */
	  p = -v;	/* so that v doesn't get lost */
	  if (!l1num)
	    break;
	  POOL_DEBUG(SOLV_DEBUG_ANALYZE, "got %d involved level 1 decisions\n", l1num);
	  /* clear non-l1 bits from seen map */
	  for (i = 0; i < q.count; i++)
	    {
	      v = q.elements[i];
	      MAPCLR(&seen, v > 0 ? v : -v);
	    }
	  /* only level 1 marks left in seen map */
	  l1num++;	/* as l1retry decrements it */
	  goto l1retry;
	}

      why = solv->decisionq_why.elements[idx];
      if (why <= 0)	/* just in case, maybe for SYSTEMSOLVABLE */
	goto l1retry;
      c = solv->rules + why;
    }
  map_free(&seen);
  assert(p != 0);
  assert(rlevel > 0 && rlevel < level);
  IF_POOLDEBUG (SOLV_DEBUG_ANALYZE)
    {
      POOL_DEBUG(SOLV_DEBUG_ANALYZE, "learned rule for level %d (am %d)\n", rlevel, level);
      solver_printruleelement(solv, SOLV_DEBUG_ANALYZE, 0, p);
      for (i = 0; i < q.count; i++)
        solver_printruleelement(solv, SOLV_DEBUG_ANALYZE, 0, q.elements[i]);
    }
  /* push end marker on learnt reasons stack */
  queue_push(&solv->learnt_pool, 0);
  solv->stats_learned++;

  POOL_DEBUG(SOLV_DEBUG_ANALYZE, "reverting decisions (level %d -> %d)\n", level, rlevel);
  level = rlevel;
  revert(solv, level);
  if (q.count < 2)
    {
      Id d = q.count ? q.elements[0] : 0;
      queue_free(&q);
      r = solver_addrule(solv, p, d, 0);
    }
  else
    {
      Id d = pool_queuetowhatprovides(pool, &q);
      queue_free(&q);
      r = solver_addrule(solv, p, 0, d);
    }
  assert(solv->learnt_why.count == (r - solv->rules) - solv->learntrules);
  queue_push(&solv->learnt_why, learnt_why);
  if (r->w2)
    {
      /* needs watches */
      watch2onhighest(solv, r);
      addwatches_rule(solv, r);
    }
  else
    {
      /* rule is an assertion */
      queue_push(&solv->ruleassertions, r - solv->rules);
    }
  *lrp = r;
  return level;
}


/*-------------------------------------------------------------------
 *
 * solver_reset
 *
 * reset all solver decisions
 * called after rules have been enabled/disabled
 */

void
solver_reset(Solver *solv)
{
  int i;
  Id v;

  /* rewind all decisions */
  for (i = solv->decisionq.count - 1; i >= 0; i--)
    {
      v = solv->decisionq.elements[i];
      solv->decisionmap[v > 0 ? v : -v] = 0;
    }
  queue_empty(&solv->decisionq_why);
  queue_empty(&solv->decisionq);
  solv->recommends_index = -1;
  solv->propagate_index = 0;
  solv->decisioncnt_update = solv->decisioncnt_keep = solv->decisioncnt_resolve = solv->decisioncnt_weak = solv->decisioncnt_orphan = 0;
  queue_empty(&solv->branches);

  /* adapt learnt rule status to new set of enabled/disabled rules */
  enabledisablelearntrules(solv);
}


/*-------------------------------------------------------------------
 *
 * analyze_unsolvable_rule
 *
 * recursion helper used by analyze_unsolvable
 */

static void
analyze_unsolvable_rule(Solver *solv, Rule *r, Id *lastweakp, Map *rseen)
{
  Pool *pool = solv->pool;
  int i;
  Id why = r - solv->rules;

  IF_POOLDEBUG (SOLV_DEBUG_UNSOLVABLE)
    solver_printruleclass(solv, SOLV_DEBUG_UNSOLVABLE, r);
  if (solv->learntrules && why >= solv->learntrules)
    {
      if (MAPTST(rseen, why - solv->learntrules))
	return;
      MAPSET(rseen, why - solv->learntrules);
      for (i = solv->learnt_why.elements[why - solv->learntrules]; solv->learnt_pool.elements[i]; i++)
	if (solv->learnt_pool.elements[i] > 0)
	  analyze_unsolvable_rule(solv, solv->rules + solv->learnt_pool.elements[i], lastweakp, rseen);
      return;
    }
  if (solv->weakrulemap.size && MAPTST(&solv->weakrulemap, why))
    if (!*lastweakp || why > *lastweakp)
      *lastweakp = why;
  /* do not add pkg rules to problem */
  if (why < solv->pkgrules_end)
    return;
  /* turn rule into problem */
  if (why >= solv->jobrules && why < solv->jobrules_end)
    why = -(solv->ruletojob.elements[why - solv->jobrules] + 1);
  /* normalize dup/infarch rules */
  if (why > solv->infarchrules && why < solv->infarchrules_end)
    {
      Id name = pool->solvables[-solv->rules[why].p].name;
      while (why > solv->infarchrules && pool->solvables[-solv->rules[why - 1].p].name == name)
	why--;
    }
  if (why > solv->duprules && why < solv->duprules_end)
    {
      Id name = pool->solvables[-solv->rules[why].p].name;
      while (why > solv->duprules && pool->solvables[-solv->rules[why - 1].p].name == name)
	why--;
    }

  /* return if problem already countains our rule */
  if (solv->problems.count)
    {
      for (i = solv->problems.count - 1; i >= 0; i--)
	if (solv->problems.elements[i] == 0)	/* end of last problem reached? */
	  break;
	else if (solv->problems.elements[i] == why)
	  return;
    }
  queue_push(&solv->problems, why);
}


/*-------------------------------------------------------------------
 *
 * analyze_unsolvable (called from setpropagatelearn)
 *
 * We know that the problem is not solvable. Record all involved
 * rules (i.e. the "proof") into solv->learnt_pool.
 * Record the learnt pool index and all non-pkg rules into
 * solv->problems. (Our solutions to fix the problems are to
 * disable those rules.)
 *
 * If the proof contains at least one weak rule, we disable the
 * last of them.
 *
 * Otherwise we return -1 if disablerules is not set or disable
 * _all_ of the problem rules and return 0.
 *
 * return:  0 - disabled some rules, try again
 *         -1 - hopeless
 */

static int
analyze_unsolvable(Solver *solv, Rule *cr, int disablerules)
{
  Pool *pool = solv->pool;
  Rule *r;
  Map involved;		/* global to speed things up? */
  Map rseen;
  Id pp, v, vv, why;
  int i, idx;
  Id *decisionmap = solv->decisionmap;
  int oldproblemcount;
  int oldlearntpoolcount;
  Id lastweak;
  int record_proof = 1;

  POOL_DEBUG(SOLV_DEBUG_UNSOLVABLE, "ANALYZE UNSOLVABLE ----------------------\n");
  solv->stats_unsolvable++;
  oldproblemcount = solv->problems.count;
  oldlearntpoolcount = solv->learnt_pool.count;

  /* make room for proof index */
  /* must update it later, as analyze_unsolvable_rule would confuse
   * it with a rule index if we put the real value in already */
  queue_push(&solv->problems, 0);

  r = cr;
  map_init(&involved, pool->nsolvables);
  map_init(&rseen, solv->learntrules ? solv->nrules - solv->learntrules : 0);
  if (record_proof)
    queue_push(&solv->learnt_pool, r - solv->rules);
  lastweak = 0;
  analyze_unsolvable_rule(solv, r, &lastweak, &rseen);
  FOR_RULELITERALS(v, pp, r)
    {
      if (DECISIONMAP_TRUE(v))	/* the one true literal */
	  continue;
      vv = v > 0 ? v : -v;
      MAPSET(&involved, vv);
    }
  idx = solv->decisionq.count;
  while (idx > 0)
    {
      v = solv->decisionq.elements[--idx];
      vv = v > 0 ? v : -v;
      if (!MAPTST(&involved, vv) || vv == SYSTEMSOLVABLE)
	continue;
      why = solv->decisionq_why.elements[idx];
      assert(why > 0);
      if (record_proof)
        queue_push(&solv->learnt_pool, why);
      r = solv->rules + why;
      analyze_unsolvable_rule(solv, r, &lastweak, &rseen);
      FOR_RULELITERALS(v, pp, r)
	{
	  if (DECISIONMAP_TRUE(v))	/* the one true literal */
	      continue;
	  vv = v > 0 ? v : -v;
	  MAPSET(&involved, vv);
	}
    }
  map_free(&involved);
  map_free(&rseen);
  queue_push(&solv->problems, 0);	/* mark end of this problem */

  if (lastweak)
    {
      /* disable last weak rule */
      solv->problems.count = oldproblemcount;
      solv->learnt_pool.count = oldlearntpoolcount;
      if (lastweak >= solv->jobrules && lastweak < solv->jobrules_end)
	v = -(solv->ruletojob.elements[lastweak - solv->jobrules] + 1);
      else
        v = lastweak;
      POOL_DEBUG(SOLV_DEBUG_UNSOLVABLE, "disabling ");
      solver_printruleclass(solv, SOLV_DEBUG_UNSOLVABLE, solv->rules + lastweak);
      if (lastweak >= solv->choicerules && lastweak < solv->choicerules_end)
	solver_disablechoicerules(solv, solv->rules + lastweak);
      solver_disableproblem(solv, v);
      if (v < 0)
	solver_reenablepolicyrules(solv, -v);
      solver_reset(solv);
      return 0;
    }

  if (solv->allowuninstall && (v = autouninstall(solv, solv->problems.elements + oldproblemcount + 1)) != 0)
    {
      solv->problems.count = oldproblemcount;
      solv->learnt_pool.count = oldlearntpoolcount;
      solver_reset(solv);
      return 0;
    }

  /* finish proof */
  if (record_proof)
    {
      queue_push(&solv->learnt_pool, 0);
      solv->problems.elements[oldproblemcount] = oldlearntpoolcount;
    }

  /* + 2: index + trailing zero */
  if (disablerules && oldproblemcount + 2 < solv->problems.count)
    {
      for (i = oldproblemcount + 1; i < solv->problems.count - 1; i++)
        solver_disableproblem(solv, solv->problems.elements[i]);
      /* XXX: might want to enable all weak rules again */
      solver_reset(solv);
      return 0;
    }
  POOL_DEBUG(SOLV_DEBUG_UNSOLVABLE, "UNSOLVABLE\n");
  return -1;
}


/*-------------------------------------------------------------------
 *
 * setpropagatelearn
 *
 * add free decision (solvable to install) to decisionq
 * increase level and propagate decision
 * return if no conflict.
 *
 * in conflict case, analyze conflict rule, add resulting
 * rule to learnt rule set, make decision from learnt
 * rule (always unit) and re-propagate.
 *
 * returns the new solver level or -1 if unsolvable
 *
 */

static int
setpropagatelearn(Solver *solv, int level, Id decision, int disablerules, Id ruleid)
{
  Pool *pool = solv->pool;
  Rule *r, *lr;

  if (decision)
    {
      level++;
      if (decision > 0)
        solv->decisionmap[decision] = level;
      else
        solv->decisionmap[-decision] = -level;
      queue_push(&solv->decisionq, decision);
      queue_push(&solv->decisionq_why, -ruleid);	/* <= 0 -> free decision */
    }
  assert(ruleid >= 0 && level > 0);
  for (;;)
    {
      r = propagate(solv, level);
      if (!r)
	break;
      if (level == 1)
	return analyze_unsolvable(solv, r, disablerules);
      POOL_DEBUG(SOLV_DEBUG_ANALYZE, "conflict with rule #%d\n", (int)(r - solv->rules));
      level = analyze(solv, level, r, &lr);
      /* the new rule is unit by design */
      decision = lr->p;
      solv->decisionmap[decision > 0 ? decision : -decision] = decision > 0 ? level : -level;
      queue_push(&solv->decisionq, decision);
      queue_push(&solv->decisionq_why, lr - solv->rules);
      IF_POOLDEBUG (SOLV_DEBUG_ANALYZE)
	{
	  POOL_DEBUG(SOLV_DEBUG_ANALYZE, "decision: ");
	  solver_printruleelement(solv, SOLV_DEBUG_ANALYZE, 0, decision);
	  POOL_DEBUG(SOLV_DEBUG_ANALYZE, "new rule: ");
	  solver_printrule(solv, SOLV_DEBUG_ANALYZE, lr);
	}
    }
  return level;
}

static void
reorder_dq_for_jobrules(Solver *solv, int level, Queue *dq)
{
  Pool *pool = solv->pool;
  int i, j, haveone = 0, dqcount = dq->count;
  int decisionqcount = solv->decisionq.count;
  Id p;
  Solvable *s;

  /* at the time we process jobrules the installed packages are not kept yet */
  /* reorder so that "future-supplemented" packages come first */
  FOR_REPO_SOLVABLES(solv->installed, p, s)
    {
      if (MAPTST(&solv->noupdate, p - solv->installed->start))
	continue;
      if (solv->decisionmap[p] == 0)
	{
	  if (s->recommends || s->suggests)
	    queue_push(&solv->decisionq, p);
	  solv->decisionmap[p] = level + 1;
	  haveone = 1;
	}
    }
  if (!haveone)
    return;
  policy_update_recommendsmap(solv);
  for (i = 0; i < dqcount; i++)
    {
      p = dq->elements[i];
      if (!(pool->solvables[p].repo == solv->installed || MAPTST(&solv->suggestsmap, p) || solver_is_enhancing(solv, pool->solvables + p)))
        {
	  queue_push(dq, p);
	  dq->elements[i] = 0;
        }
    }
  dqcount = dq->count;
  for (i = 0; i < dqcount; i++)
    {
      p = dq->elements[i];
      if (p && !(pool->solvables[p].repo == solv->installed || MAPTST(&solv->recommendsmap, p) || solver_is_supplementing(solv, pool->solvables + p)))
        {
	  queue_push(dq, p);
	  dq->elements[i] = 0;
        }
    }
  for (i = j = 0; i < dq->count; i++)
    if (dq->elements[i])
      dq->elements[j++] = dq->elements[i];
  queue_truncate(dq, j);
  FOR_REPO_SOLVABLES(solv->installed, p, s)
    if (solv->decisionmap[p] == level + 1)
      solv->decisionmap[p] = 0;
  if (solv->decisionq.count != decisionqcount)
    {
      solv->recommends_index = -1;
      queue_truncate(&solv->decisionq, decisionqcount);
    }
}

/*-------------------------------------------------------------------
 *
 * branch handling
 */

static void
createbranch(Solver *solv, int level, Queue *dq, Id p, Id data)
{
  Pool *pool = solv->pool;
  int i;
  IF_POOLDEBUG (SOLV_DEBUG_POLICY)
    {
      POOL_DEBUG (SOLV_DEBUG_POLICY, "creating a branch:\n");
      for (i = 0; i < dq->count; i++)
	POOL_DEBUG (SOLV_DEBUG_POLICY, "  - %s\n", pool_solvid2str(pool, dq->elements[i]));
    }
  queue_push(&solv->branches, -dq->elements[0]);
  for (i = 1; i < dq->count; i++)
    queue_push(&solv->branches, dq->elements[i]);
  queue_push2(&solv->branches, p, data);
  queue_push2(&solv->branches, dq->count + 4, level);
}

static int
takebranch(Solver *solv, int pos, int end, const char *msg, int disablerules)
{
  Pool *pool = solv->pool;
  int level;
  Id p, why;
#if 0
  {
    int i;
    printf("branch group level %d [%d-%d] %d %d:\n", solv->branches.elements[end - 1], start, end, solv->branches.elements[end - 4], solv->branches.elements[end - 3]);
    for (i = end - solv->branches.elements[end - 2]; i < end - 4; i++)
      printf("%c %c%s\n", i == pos ? 'x' : ' ', solv->branches.elements[i] >= 0 ? ' ' : '-', pool_solvid2str(pool, solv->branches.elements[i] >= 0 ? solv->branches.elements[i] : -solv->branches.elements[i]));
  }
#endif
  level = solv->branches.elements[end - 1];
  p = solv->branches.elements[pos];
  solv->branches.elements[pos] = -p;
  POOL_DEBUG(SOLV_DEBUG_SOLVER, "%s %d -> %d with %s\n", msg, solv->decisionmap[p], level, pool_solvid2str(pool, p));
  /* hack: set level to zero so that revert does not remove the branch */
  solv->branches.elements[end - 1] = 0;
  revert(solv, level);
  solv->branches.elements[end - 1] = level;
  /* hack: revert simply sets the count, so we can still access the reverted elements */
  why = -solv->decisionq_why.elements[solv->decisionq_why.count];
  assert(why >= 0);
  return setpropagatelearn(solv, level, p, disablerules, why);
}

/*-------------------------------------------------------------------
 *
 * select and install
 *
 * install best package from the queue. We add an extra package, inst, if
 * provided. See comment in weak install section.
 *
 * returns the new solver level or -1 if unsolvable
 *
 */

static int
selectandinstall(Solver *solv, int level, Queue *dq, int disablerules, Id ruleid)
{
  Pool *pool = solv->pool;
  Id p;

  if (dq->count > 1)
    policy_filter_unwanted(solv, dq, POLICY_MODE_CHOOSE);
  /* if we're resolving job rules and didn't resolve the installed packages yet,
   * do some special supplements ordering */
  if (dq->count > 1 && ruleid >= solv->jobrules && ruleid < solv->jobrules_end && solv->installed && !solv->focus_installed)
    reorder_dq_for_jobrules(solv, level, dq);
  /* if we have multiple candidates we open a branch */
  if (dq->count > 1)
    createbranch(solv, level, dq, 0, ruleid);
  p = dq->elements[0];
  POOL_DEBUG(SOLV_DEBUG_POLICY, "installing %s\n", pool_solvid2str(pool, p));
  return setpropagatelearn(solv, level, p, disablerules, ruleid);
}


/********************************************************************/
/* Main solver interface */


/*-------------------------------------------------------------------
 *
 * solver_create
 * create solver structure
 *
 * pool: all available solvables
 * installed: installed Solvables
 *
 *
 * Upon solving, rules are created to flag the Solvables
 * of the 'installed' Repo as installed.
 */

Solver *
solver_create(Pool *pool)
{
  Solver *solv;
  solv = (Solver *)solv_calloc(1, sizeof(Solver));
  solv->pool = pool;
  solv->installed = pool->installed;

  solv->allownamechange = 1;

  solv->dup_allowdowngrade = 1;
  solv->dup_allownamechange = 1;
  solv->dup_allowarchchange = 1;
  solv->dup_allowvendorchange = 1;

  solv->keepexplicitobsoletes = pool->noobsoletesmultiversion ? 0 : 1;

  queue_init(&solv->ruletojob);
  queue_init(&solv->decisionq);
  queue_init(&solv->decisionq_why);
  queue_init(&solv->problems);
  queue_init(&solv->orphaned);
  queue_init(&solv->learnt_why);
  queue_init(&solv->learnt_pool);
  queue_init(&solv->branches);
  queue_init(&solv->weakruleq);
  queue_init(&solv->ruleassertions);
  queue_init(&solv->addedmap_deduceq);

  queue_push(&solv->learnt_pool, 0);	/* so that 0 does not describe a proof */

  map_init(&solv->recommendsmap, pool->nsolvables);
  map_init(&solv->suggestsmap, pool->nsolvables);
  map_init(&solv->noupdate, solv->installed ? solv->installed->end - solv->installed->start : 0);
  solv->recommends_index = 0;

  solv->decisionmap = (Id *)solv_calloc(pool->nsolvables, sizeof(Id));
  solv->nrules = 1;
  solv->rules = solv_extend_resize(solv->rules, solv->nrules, sizeof(Rule), RULES_BLOCK);
  memset(solv->rules, 0, sizeof(Rule));

  return solv;
}


static int
resolve_jobrules(Solver *solv, int level, int disablerules, Queue *dq)
{
  Pool *pool = solv->pool;
  int oldlevel = level;
  int i, olevel;
  Rule *r;

  POOL_DEBUG(SOLV_DEBUG_SOLVER, "resolving job rules\n");
  if (!solv->decisioncnt_jobs)
    solv->decisioncnt_jobs = solv->decisionq.count;
  for (i = solv->jobrules, r = solv->rules + i; i < solv->jobrules_end; i++, r++)
    {
      Id l, pp;
      if (r->d < 0)		/* ignore disabled rules */
	continue;
      queue_empty(dq);
      FOR_RULELITERALS(l, pp, r)
	{
	  if (l < 0)
	    {
	      if (solv->decisionmap[-l] <= 0)
		break;
	    }
	  else
	    {
	      if (solv->decisionmap[l] > 0)
		break;
	      if (solv->decisionmap[l] == 0)
		queue_push(dq, l);
	    }
	}
      if (l || !dq->count)
	continue;
      /* prune to installed if not updating */
      if (dq->count > 1 && solv->installed && !solv->updatemap_all &&
	  !(solv->job.elements[solv->ruletojob.elements[i - solv->jobrules]] & SOLVER_ORUPDATE))
	{
	  int j, k;
	  for (j = k = 0; j < dq->count; j++)
	    {
	      Solvable *s = pool->solvables + dq->elements[j];
	      if (s->repo == solv->installed)
		{
		  dq->elements[k++] = dq->elements[j];
		  if (solv->updatemap.size && MAPTST(&solv->updatemap, dq->elements[j] - solv->installed->start))
		    {
		      k = 0;	/* package wants to be updated, do not prune */
		      break;
		    }
		}
	    }
	  if (k)
	    dq->count = k;
	}
      olevel = level;
      level = selectandinstall(solv, level, dq, disablerules, i);
      if (level <= olevel)
	{
	  if (level == olevel)
	    {
	      i--;
	      r--;
	      continue;	/* try something else */
	    }
	  if (level < oldlevel)
	    return level;
	  /* redo from start of jobrules */
	  i = solv->jobrules - 1;
	  r = solv->rules + i;
	}
    }
  return level;
}

/*-------------------------------------------------------------------
 *
 * solver_free
 */

static inline void
queuep_free(Queue **qp)
{
  if (!*qp)
    return;
  queue_free(*qp);
  *qp = solv_free(*qp);
}

static inline void
map_zerosize(Map *m)
{
  if (m->size)
    {
      map_free(m);
      map_init(m, 0);
    }
}

void
solver_free(Solver *solv)
{
  queue_free(&solv->job);
  queue_free(&solv->ruletojob);
  queue_free(&solv->decisionq);
  queue_free(&solv->decisionq_why);
  queue_free(&solv->learnt_why);
  queue_free(&solv->learnt_pool);
  queue_free(&solv->problems);
  queue_free(&solv->solutions);
  queue_free(&solv->orphaned);
  queue_free(&solv->branches);
  queue_free(&solv->weakruleq);
  queue_free(&solv->ruleassertions);
  queue_free(&solv->addedmap_deduceq);
  queuep_free(&solv->cleandeps_updatepkgs);
  queuep_free(&solv->cleandeps_mistakes);
  queuep_free(&solv->update_targets);
  queuep_free(&solv->installsuppdepq);
  queuep_free(&solv->recommendscplxq);
  queuep_free(&solv->suggestscplxq);
  queuep_free(&solv->brokenorphanrules);

  map_free(&solv->recommendsmap);
  map_free(&solv->suggestsmap);
  map_free(&solv->noupdate);
  map_free(&solv->weakrulemap);
  map_free(&solv->multiversion);

  map_free(&solv->updatemap);
  map_free(&solv->bestupdatemap);
  map_free(&solv->fixmap);
  map_free(&solv->dupmap);
  map_free(&solv->dupinvolvedmap);
  map_free(&solv->droporphanedmap);
  map_free(&solv->cleandepsmap);

  solv_free(solv->decisionmap);
  solv_free(solv->rules);
  solv_free(solv->watches);
  solv_free(solv->obsoletes);
  solv_free(solv->obsoletes_data);
  solv_free(solv->specialupdaters);
  solv_free(solv->choicerules_ref);
  solv_free(solv->bestrules_pkg);
  solv_free(solv->yumobsrules_info);
  solv_free(solv->instbuddy);
  solv_free(solv);
}

int
solver_get_flag(Solver *solv, int flag)
{
  switch (flag)
  {
  case SOLVER_FLAG_ALLOW_DOWNGRADE:
    return solv->allowdowngrade;
  case SOLVER_FLAG_ALLOW_NAMECHANGE:
    return solv->allownamechange;
  case SOLVER_FLAG_ALLOW_ARCHCHANGE:
    return solv->allowarchchange;
  case SOLVER_FLAG_ALLOW_VENDORCHANGE:
    return solv->allowvendorchange;
  case SOLVER_FLAG_ALLOW_UNINSTALL:
    return solv->allowuninstall;
  case SOLVER_FLAG_NO_UPDATEPROVIDE:
    return solv->noupdateprovide;
  case SOLVER_FLAG_SPLITPROVIDES:
    return solv->dosplitprovides;
  case SOLVER_FLAG_IGNORE_RECOMMENDED:
    return solv->dontinstallrecommended;
  case SOLVER_FLAG_ADD_ALREADY_RECOMMENDED:
    return solv->addalreadyrecommended;
  case SOLVER_FLAG_NO_INFARCHCHECK:
    return solv->noinfarchcheck;
  case SOLVER_FLAG_KEEP_EXPLICIT_OBSOLETES:
    return solv->keepexplicitobsoletes;
  case SOLVER_FLAG_BEST_OBEY_POLICY:
    return solv->bestobeypolicy;
  case SOLVER_FLAG_NO_AUTOTARGET:
    return solv->noautotarget;
  case SOLVER_FLAG_DUP_ALLOW_DOWNGRADE:
    return solv->dup_allowdowngrade;
  case SOLVER_FLAG_DUP_ALLOW_NAMECHANGE:
    return solv->dup_allownamechange;
  case SOLVER_FLAG_DUP_ALLOW_ARCHCHANGE:
    return solv->dup_allowarchchange;
  case SOLVER_FLAG_DUP_ALLOW_VENDORCHANGE:
    return solv->dup_allowvendorchange;
  case SOLVER_FLAG_KEEP_ORPHANS:
    return solv->keep_orphans;
  case SOLVER_FLAG_BREAK_ORPHANS:
    return solv->break_orphans;
  case SOLVER_FLAG_FOCUS_INSTALLED:
    return solv->focus_installed;
  case SOLVER_FLAG_YUM_OBSOLETES:
    return solv->do_yum_obsoletes;
  case SOLVER_FLAG_NEED_UPDATEPROVIDE:
    return solv->needupdateprovide;
  default:
    break;
  }
  return -1;
}

int
solver_set_flag(Solver *solv, int flag, int value)
{
  int old = solver_get_flag(solv, flag);
  switch (flag)
  {
  case SOLVER_FLAG_ALLOW_DOWNGRADE:
    solv->allowdowngrade = value;
    break;
  case SOLVER_FLAG_ALLOW_NAMECHANGE:
    solv->allownamechange = value;
    break;
  case SOLVER_FLAG_ALLOW_ARCHCHANGE:
    solv->allowarchchange = value;
    break;
  case SOLVER_FLAG_ALLOW_VENDORCHANGE:
    solv->allowvendorchange = value;
    break;
  case SOLVER_FLAG_ALLOW_UNINSTALL:
    solv->allowuninstall = value;
    break;
  case SOLVER_FLAG_NO_UPDATEPROVIDE:
    solv->noupdateprovide = value;
    break;
  case SOLVER_FLAG_SPLITPROVIDES:
    solv->dosplitprovides = value;
    break;
  case SOLVER_FLAG_IGNORE_RECOMMENDED:
    solv->dontinstallrecommended = value;
    break;
  case SOLVER_FLAG_ADD_ALREADY_RECOMMENDED:
    solv->addalreadyrecommended = value;
    break;
  case SOLVER_FLAG_NO_INFARCHCHECK:
    solv->noinfarchcheck = value;
    break;
  case SOLVER_FLAG_KEEP_EXPLICIT_OBSOLETES:
    solv->keepexplicitobsoletes = value;
    break;
  case SOLVER_FLAG_BEST_OBEY_POLICY:
    solv->bestobeypolicy = value;
    break;
  case SOLVER_FLAG_NO_AUTOTARGET:
    solv->noautotarget = value;
    break;
  case SOLVER_FLAG_DUP_ALLOW_DOWNGRADE:
    solv->dup_allowdowngrade = value;
    break;
  case SOLVER_FLAG_DUP_ALLOW_NAMECHANGE:
    solv->dup_allownamechange = value;
    break;
  case SOLVER_FLAG_DUP_ALLOW_ARCHCHANGE:
    solv->dup_allowarchchange = value;
    break;
  case SOLVER_FLAG_DUP_ALLOW_VENDORCHANGE:
    solv->dup_allowvendorchange = value;
    break;
  case SOLVER_FLAG_KEEP_ORPHANS:
    solv->keep_orphans = value;
    break;
  case SOLVER_FLAG_BREAK_ORPHANS:
    solv->break_orphans = value;
    break;
  case SOLVER_FLAG_FOCUS_INSTALLED:
    solv->focus_installed = value;
    break;
  case SOLVER_FLAG_YUM_OBSOLETES:
    solv->do_yum_obsoletes = value;
    break;
  case SOLVER_FLAG_NEED_UPDATEPROVIDE:
    solv->needupdateprovide = value;
    break;
  default:
    break;
  }
  return old;
}

static int
cleandeps_check_mistakes(Solver *solv)
{
  Pool *pool = solv->pool;
  Rule *r;
  Id p, pp;
  int i;
  int mademistake = 0;

  if (!solv->cleandepsmap.size)
    return 0;
  /* check for mistakes */
  for (i = solv->installed->start; i < solv->installed->end; i++)
    {
      if (!MAPTST(&solv->cleandepsmap, i - solv->installed->start))
	continue;
      r = solv->rules + solv->featurerules + (i - solv->installed->start);
      /* a mistake is when the featurerule is true but the updaterule is false */
      if (!r->p)
	continue;
      FOR_RULELITERALS(p, pp, r)
	if (p > 0 && solv->decisionmap[p] > 0)
	  break;
      if (!p)
	continue;	/* feature rule is not true */
      r = solv->rules + solv->updaterules + (i - solv->installed->start);
      if (!r->p)
	continue;
      FOR_RULELITERALS(p, pp, r)
	if (p > 0 && solv->decisionmap[p] > 0)
	  break;
      if (p)
	continue;	/* update rule is true */
      POOL_DEBUG(SOLV_DEBUG_SOLVER, "cleandeps mistake: ");
      solver_printruleclass(solv, SOLV_DEBUG_SOLVER, r);
      POOL_DEBUG(SOLV_DEBUG_SOLVER, "feature rule: ");
      solver_printruleclass(solv, SOLV_DEBUG_SOLVER, solv->rules + solv->featurerules + (i - solv->installed->start));
      if (!solv->cleandeps_mistakes)
	{
	  solv->cleandeps_mistakes = solv_calloc(1, sizeof(Queue));
	  queue_init(solv->cleandeps_mistakes);
	}
      queue_push(solv->cleandeps_mistakes, i);
      MAPCLR(&solv->cleandepsmap, i - solv->installed->start);
      solver_reenablepolicyrules_cleandeps(solv, i);
      mademistake = 1;
    }
  return mademistake;
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

#ifdef ENABLE_COMPLEX_DEPS

static void
add_complex_recommends(Solver *solv, Id rec, Queue *dq, Map *dqmap)
{
  Pool *pool = solv->pool;
  int oldcnt = dq->count;
  int cutcnt, blkcnt;
  Id p;
  int i, j;

#if 0
  printf("ADD_COMPLEX_RECOMMENDS %s\n", pool_dep2str(pool, rec));
#endif
  i = pool_normalize_complex_dep(pool, rec, dq, CPLXDEPS_EXPAND);
  if (i == 0 || i == 1)
    return;
  cutcnt = dq->count;
  for (i = oldcnt; i < cutcnt; i++)
    {
      blkcnt = dq->count;
      for (; (p = dq->elements[i]) != 0; i++)
	{
	  if (p < 0)
	    {
	      if (solv->decisionmap[-p] <= 0)
		break;
	      continue;
	    }
	  if (solv->decisionmap[p] > 0)
	    {
	      queue_truncate(dq, blkcnt);
	      break;
	    }
	  if (dqmap)
	    {
	      if (!MAPTST(dqmap, p))
		continue;
	    }
	  else
	    {
	      if (solv->decisionmap[p] < 0)
		continue;
	      if (solv->dupmap_all && solv->installed && pool->solvables[p].repo == solv->installed && (solv->droporphanedmap_all || (solv->droporphanedmap.size && MAPTST(&solv->droporphanedmap, p - solv->installed->start))))
		continue;
	    }
	  queue_push(dq, p);
	}
      while (dq->elements[i])
	i++;
    }
  queue_deleten(dq, oldcnt, cutcnt - oldcnt);
  /* unify */
  if (dq->count != oldcnt)
    {
      for (j = oldcnt; j < dq->count; j++)
	{
	  p = dq->elements[j];
	  for (i = 0; i < j; i++)
	    if (dq->elements[i] == p)
	      {
		dq->elements[j] = 0;
		break;
	      }
	}
      for (i = j = oldcnt; j < dq->count; j++)
	if (dq->elements[j])
	  dq->elements[i++] = dq->elements[j];
      queue_truncate(dq, i);
    }
#if 0
  printf("RETURN:\n");
  for (i = oldcnt; i < dq->count; i++)
    printf("  - %s\n", pool_solvid2str(pool, dq->elements[i]));
#endif
}

static void
do_complex_recommendations(Solver *solv, Id rec, Map *m, int noselected)
{
  Pool *pool = solv->pool;
  Queue dq;
  Id p;
  int i, blk;

#if 0
  printf("DO_COMPLEX_RECOMMENDATIONS %s\n", pool_dep2str(pool, rec));
#endif
  queue_init(&dq);
  i = pool_normalize_complex_dep(pool, rec, &dq, CPLXDEPS_EXPAND);
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
	      if (solv->decisionmap[-p] <= 0)
		break;
	      continue;
	    }
	  if (solv->decisionmap[p] > 0)
	    {
	      if (noselected)
		break;
	      MAPSET(m, p);
	      for (i++; (p = dq.elements[i]) != 0; i++)
		if (p > 0 && solv->decisionmap[p] > 0)
		  MAPSET(m, p);
	      p = 1;
	      break;
	    }
	}
      if (!p)
	{
	  for (i = blk; (p = dq.elements[i]) != 0; i++)
	    if (p > 0)
	      MAPSET(m, p);
	}
      while (dq.elements[i])
	i++;
    }
  queue_free(&dq);
}

#endif

/*-------------------------------------------------------------------
 *
 * solver_run_sat
 *
 * all rules have been set up, now actually run the solver
 *
 */

void
solver_run_sat(Solver *solv, int disablerules, int doweak)
{
  Queue dq;		/* local decisionqueue */
  Queue dqs;		/* local decisionqueue for supplements */
  int systemlevel;
  int level, olevel;
  Rule *r;
  int i, j, n;
  Solvable *s;
  Pool *pool = solv->pool;
  Id p, pp, *dp, postponed;
  int minimizationsteps;
  int installedpos = solv->installed ? solv->installed->start : 0;

  IF_POOLDEBUG (SOLV_DEBUG_RULE_CREATION)
    {
      POOL_DEBUG (SOLV_DEBUG_RULE_CREATION, "number of rules: %d\n", solv->nrules);
      for (i = 1; i < solv->nrules; i++)
	solver_printruleclass(solv, SOLV_DEBUG_RULE_CREATION, solv->rules + i);
    }

  /* start SAT algorithm */
  level = 0;
  systemlevel = level + 1;
  POOL_DEBUG(SOLV_DEBUG_SOLVER, "solving...\n");

  queue_init(&dq);
  queue_init(&dqs);

  /*
   * here's the main loop:
   * 1) decide assertion rules and propagate
   * 2) fulfill jobs
   * 3) try to keep installed packages
   * 4) fulfill all unresolved rules
   * 5) install recommended packages
   * 6) minimalize solution if we had choices
   * if we encounter a problem, we rewind to a safe level and restart
   * with step 1
   */

  minimizationsteps = 0;
  for (;;)
    {
      /*
       * initial propagation of the assertions
       */
      if (level <= 0)
	{
	  if (level < 0)
	    break;
	  makeruledecisions(solv);
	  level = 1;
	  if (!disablerules && solv->problems.count)
	    {
	      level = -1;
	      break;
	    }
	  POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "initial propagate (propagate_index: %d;  size decisionq: %d)...\n", solv->propagate_index, solv->decisionq.count);
	  if ((r = propagate(solv, level)) != 0)
	    {
	      level = analyze_unsolvable(solv, r, disablerules);
	      continue;
	    }
	  systemlevel = level + 1;
	}

      /*
       * resolve jobs first (unless focus_installed is set)
       */
     if (level < systemlevel && !solv->focus_installed)
	{
	  olevel = level;
	  level = resolve_jobrules(solv, level, disablerules, &dq);
	  if (level < olevel)
	    continue;
	  systemlevel = level + 1;
	}


      /*
       * installed packages
       */
      if (!solv->decisioncnt_update)
	solv->decisioncnt_update = solv->decisionq.count;
      if (level < systemlevel && solv->installed && solv->installed->nsolvables && !solv->installed->disabled)
	{
	  Repo *installed = solv->installed;
	  int pass;

	  POOL_DEBUG(SOLV_DEBUG_SOLVER, "resolving installed packages\n");
	  /* we use two passes if we need to update packages
           * to create a better user experience */
	  for (pass = solv->updatemap.size ? 0 : 1; pass < 2; pass++)
	    {
	      int passlevel = level;
	      Id *specialupdaters = solv->specialupdaters;
	      if (pass == 1 && !solv->decisioncnt_keep)
		solv->decisioncnt_keep = solv->decisionq.count;
	      /* start with installedpos, the position that gave us problems the last time */
	      for (i = installedpos, n = installed->start; n < installed->end; i++, n++)
		{
		  Rule *rr;
		  Id d;

		  if (i == installed->end)
		    i = installed->start;
		  s = pool->solvables + i;
		  if (s->repo != installed)
		    continue;

		  if (solv->decisionmap[i] > 0 && (!specialupdaters || !specialupdaters[i - installed->start]))
		    continue;		/* already decided */
		  if (!pass && solv->updatemap.size && !MAPTST(&solv->updatemap, i - installed->start))
		    continue;		/* updates first */
		  r = solv->rules + solv->updaterules + (i - installed->start);
		  rr = r;
		  if (!rr->p || rr->d < 0)	/* disabled -> look at feature rule */
		    rr -= solv->installed->end - solv->installed->start;
		  if (!rr->p)		/* identical to update rule? */
		    rr = r;
		  if (!rr->p && !(specialupdaters && specialupdaters[i - installed->start]))
		    continue;		/* orpaned package */

		  /* check if we should update this package to the latest version
		   * noupdate is set for erase jobs, in that case we want to deinstall
		   * the installed package and not replace it with a newer version
		   * rr->p != i is for dup jobs where the installed package cannot be kept */
		  queue_empty(&dq);
		  if (!MAPTST(&solv->noupdate, i - installed->start) && (solv->decisionmap[i] < 0 || solv->updatemap_all || (solv->updatemap.size && MAPTST(&solv->updatemap, i - installed->start)) || (rr->p && rr->p != i)))
		    {
		      if (!rr->p)
			{
			  /* specialupdater with no update/feature rule */
			  for (d = specialupdaters[i - installed->start]; (p = pool->whatprovidesdata[d++]) != 0; )
			    {
			      if (solv->decisionmap[p] > 0)
			        {
				  dq.count = 0;
			          break;
			        }
			      if (!solv->decisionmap[p])
				queue_push(&dq, p);
			    }
			}
		      else if (specialupdaters && (d = specialupdaters[i - installed->start]) != 0)
			{
			  /* special multiversion handling, make sure best version is chosen */
			  if (rr->p == i && solv->decisionmap[i] >= 0)
			    queue_push(&dq, i);
			  while ((p = pool->whatprovidesdata[d++]) != 0)
			    if (solv->decisionmap[p] >= 0)
			      queue_push(&dq, p);
			  if (dq.count && solv->update_targets && solv->update_targets->elements[i - installed->start])
			    prune_to_update_targets(solv, solv->update_targets->elements + solv->update_targets->elements[i - installed->start], &dq);
			  if (dq.count)
			    {
			      policy_filter_unwanted(solv, &dq, POLICY_MODE_CHOOSE);
			      p = dq.elements[0];
			      if (p != i && solv->decisionmap[p] == 0)
				{
				  rr = solv->rules + solv->featurerules + (i - solv->installed->start);
				  if (!rr->p)		/* update rule == feature rule? */
				    rr = rr - solv->featurerules + solv->updaterules;
				  dq.count = 1;
				}
			      else
				dq.count = 0;
			    }
			}
		      else
			{
			  /* update to best package of the update rule */
			  FOR_RULELITERALS(p, pp, rr)
			    {
			      if (solv->decisionmap[p] > 0)
				{
				  dq.count = 0;		/* already fulfilled */
				  break;
				}
			      if (!solv->decisionmap[p])
				queue_push(&dq, p);
			    }
			}
		    }
		  if (dq.count && solv->update_targets && solv->update_targets->elements[i - installed->start])
		    prune_to_update_targets(solv, solv->update_targets->elements + solv->update_targets->elements[i - installed->start], &dq);
		  /* install best version */
		  if (dq.count)
		    {
		      olevel = level;
		      level = selectandinstall(solv, level, &dq, disablerules, rr - solv->rules);
		      if (level <= olevel)
			{
			  if (level < passlevel)
			    break;	/* trouble */
			  if (level < olevel)
			    n = installed->start;	/* redo all */
			  i--;
			  n--;
			  continue;
			}
		    }
		  /* if still undecided keep package */
		  if (solv->decisionmap[i] == 0)
		    {
		      olevel = level;
		      if (solv->cleandepsmap.size && MAPTST(&solv->cleandepsmap, i - installed->start))
			{
#if 0
			  POOL_DEBUG(SOLV_DEBUG_POLICY, "cleandeps erasing %s\n", pool_solvid2str(pool, i));
			  level = setpropagatelearn(solv, level, -i, disablerules, 0);
#else
			  continue;
#endif
			}
		      else
			{
			  POOL_DEBUG(SOLV_DEBUG_POLICY, "keeping %s\n", pool_solvid2str(pool, i));
			  level = setpropagatelearn(solv, level, i, disablerules, r - solv->rules);
			}
		      if (level <= olevel)
			{
			  if (level < passlevel)
			    break;	/* trouble */
			  if (level < olevel)
			    n = installed->start;	/* redo all */
			  i--;
			  n--;
			  continue;	/* retry with learnt rule */
			}
		    }
		}
	      if (n < installed->end)
		{
		  installedpos = i;	/* retry problem solvable next time */
		  break;		/* ran into trouble */
		}
	      installedpos = installed->start;	/* reset installedpos */
	    }
	  systemlevel = level + 1;
	  if (pass < 2)
	    continue;		/* had trouble, retry */
	}
      if (!solv->decisioncnt_keep)
	solv->decisioncnt_keep = solv->decisionq.count;

     if (level < systemlevel && solv->focus_installed)
	{
	  olevel = level;
	  level = resolve_jobrules(solv, level, disablerules, &dq);
	  if (level < olevel)
	    continue;
	  systemlevel = level + 1;
	}

      if (level < systemlevel)
        systemlevel = level;

      /*
       * decide
       */
      if (!solv->decisioncnt_resolve)
        solv->decisioncnt_resolve = solv->decisionq.count;
      POOL_DEBUG(SOLV_DEBUG_POLICY, "deciding unresolved rules\n");
      postponed = 0;
      for (i = 1, n = 1; ; i++, n++)
	{
	  if (n >= solv->nrules)
	    {
	      if (postponed <= 0)
		break;
	      i = postponed;
	      postponed = -1;
	      n = 1;
	    }
	  if (i == solv->nrules)
	    i = 1;
	  r = solv->rules + i;
	  if (r->d < 0)		/* ignore disabled rules */
	    continue;
	  if (r->p < 0)		/* most common cases first */
	    {
	      if (r->d == 0 || solv->decisionmap[-r->p] <= 0)
		continue;
	    }
	  if (dq.count)
	    queue_empty(&dq);
	  if (r->d == 0)
	    {
	      /* binary or unary rule */
	      /* need two positive undecided literals, r->p already checked above */
	      if (r->w2 <= 0)
		continue;
	      if (solv->decisionmap[r->p] || solv->decisionmap[r->w2])
		continue;
	      queue_push(&dq, r->p);
	      queue_push(&dq, r->w2);
	    }
	  else
	    {
	      /* make sure that
               * all negative literals are installed
               * no positive literal is installed
	       * i.e. the rule is not fulfilled and we
               * just need to decide on the positive literals
	       * (decisionmap[-r->p] for the r->p < 0 case is already checked above)
               */
	      if (r->p >= 0)
		{
		  if (solv->decisionmap[r->p] > 0)
		    continue;
		  if (solv->decisionmap[r->p] == 0)
		    queue_push(&dq, r->p);
		}
	      dp = pool->whatprovidesdata + r->d;
	      while ((p = *dp++) != 0)
		{
		  if (p < 0)
		    {
		      if (solv->decisionmap[-p] <= 0)
			break;
		    }
		  else
		    {
		      if (solv->decisionmap[p] > 0)
			break;
		      if (solv->decisionmap[p] == 0)
			queue_push(&dq, p);
		    }
		}
	      if (p)
		continue;
	    }
	  IF_POOLDEBUG (SOLV_DEBUG_PROPAGATE)
	    {
	      POOL_DEBUG(SOLV_DEBUG_PROPAGATE, "unfulfilled ");
	      solver_printruleclass(solv, SOLV_DEBUG_PROPAGATE, r);
	    }
	  /* dq.count < 2 cannot happen as this means that
	   * the rule is unit */
	  assert(dq.count > 1);

	  /* prune to cleandeps packages */
	  if (solv->cleandepsmap.size && solv->installed)
	    {
	      Repo *installed = solv->installed;
	      for (j = 0; j < dq.count; j++)
		if (pool->solvables[dq.elements[j]].repo == installed && MAPTST(&solv->cleandepsmap, dq.elements[j] - installed->start))
		  break;
	      if (j < dq.count)
		{
		  dq.elements[0] = dq.elements[j];
		  queue_truncate(&dq, 1);
		}
	    }

	  if (dq.count > 1 && postponed >= 0)
	    {
	      policy_filter_unwanted(solv, &dq, POLICY_MODE_CHOOSE_NOREORDER);
	      if (dq.count > 1)
		{
		  if (!postponed)
		    postponed = i;
		  continue;
		}
	    }

	  olevel = level;
	  level = selectandinstall(solv, level, &dq, disablerules, r - solv->rules);
	  if (level < systemlevel)
	    break;		/* trouble */
	  /* something changed, so look at all rules again */
	  n = 0;
	}

      if (n < solv->nrules)	/* ran into trouble? */
        continue;		/* start over */

      /* decide leftover cleandeps packages */
      if (solv->cleandepsmap.size && solv->installed)
	{
	  for (p = solv->installed->start; p < solv->installed->end; p++)
	    {
	      s = pool->solvables + p;
	      if (s->repo != solv->installed)
		continue;
	      if (solv->decisionmap[p] == 0 && MAPTST(&solv->cleandepsmap, p - solv->installed->start))
		{
		  POOL_DEBUG(SOLV_DEBUG_POLICY, "cleandeps erasing %s\n", pool_solvid2str(pool, p));
		  olevel = level;
		  level = setpropagatelearn(solv, level, -p, 0, 0);
		  if (level < olevel)
		    break;
		}
	    }
	  if (p < solv->installed->end)
	    continue;
	}

      /* at this point we have a consistent system. now do the extras... */

      if (!solv->decisioncnt_weak)
        solv->decisioncnt_weak = solv->decisionq.count;
      if (doweak)
	{
	  int qcount;

	  POOL_DEBUG(SOLV_DEBUG_POLICY, "installing recommended packages\n");
	  queue_empty(&dq);	/* recommended packages */
	  queue_empty(&dqs);	/* supplemented packages */
	  for (i = 1; i < pool->nsolvables; i++)
	    {
	      if (solv->decisionmap[i] < 0)
		continue;
	      if (solv->decisionmap[i] > 0)
		{
		  /* installed, check for recommends */
		  Id *recp, rec, pp, p;
		  s = pool->solvables + i;
		  if (!solv->addalreadyrecommended && s->repo == solv->installed)
		    continue;
		  /* XXX need to special case AND ? */
		  if (s->recommends)
		    {
		      recp = s->repo->idarraydata + s->recommends;
		      while ((rec = *recp++) != 0)
			{
#ifdef ENABLE_COMPLEX_DEPS
			  if (pool_is_complex_dep(pool, rec))
			    {
			      add_complex_recommends(solv, rec, &dq, 0);
			      continue;
			    }
#endif
			  qcount = dq.count;
			  FOR_PROVIDES(p, pp, rec)
			    {
			      if (solv->decisionmap[p] > 0)
				{
				  dq.count = qcount;
				  break;
				}
			      else if (solv->decisionmap[p] == 0)
				{
				  if (solv->dupmap_all && solv->installed && pool->solvables[p].repo == solv->installed && (solv->droporphanedmap_all || (solv->droporphanedmap.size && MAPTST(&solv->droporphanedmap, p - solv->installed->start))))
				    continue;
				  queue_pushunique(&dq, p);
				}
			    }
			}
		    }
		}
	      else
		{
		  s = pool->solvables + i;
		  if (!s->supplements)
		    continue;
		  if (!pool_installable(pool, s))
		    continue;
		  if (!solver_is_supplementing(solv, s))
		    continue;
		  if (solv->dupmap_all && solv->installed && s->repo == solv->installed && (solv->droporphanedmap_all || (solv->droporphanedmap.size && MAPTST(&solv->droporphanedmap, i - solv->installed->start))))
		    continue;
		  queue_push(&dqs, i);
		}
	    }

	  /* filter out all packages obsoleted by installed packages */
	  /* this is no longer needed if we have reverse obsoletes */
          if ((dqs.count || dq.count) && solv->installed)
	    {
	      Map obsmap;
	      Id obs, *obsp, po, ppo;

	      map_init(&obsmap, pool->nsolvables);
	      for (p = solv->installed->start; p < solv->installed->end; p++)
		{
		  s = pool->solvables + p;
		  if (s->repo != solv->installed || !s->obsoletes)
		    continue;
		  if (solv->decisionmap[p] <= 0)
		    continue;
		  if (solv->multiversion.size && MAPTST(&solv->multiversion, p))
		    continue;
		  obsp = s->repo->idarraydata + s->obsoletes;
		  /* foreach obsoletes */
		  while ((obs = *obsp++) != 0)
		    FOR_PROVIDES(po, ppo, obs)
		      MAPSET(&obsmap, po);
		}
	      for (i = j = 0; i < dqs.count; i++)
		if (!MAPTST(&obsmap, dqs.elements[i]))
		  dqs.elements[j++] = dqs.elements[i];
	      dqs.count = j;
	      for (i = j = 0; i < dq.count; i++)
		if (!MAPTST(&obsmap, dq.elements[i]))
		  dq.elements[j++] = dq.elements[i];
	      dq.count = j;
	      map_free(&obsmap);
	    }

          /* filter out all already supplemented packages if requested */
          if (!solv->addalreadyrecommended && dqs.count)
	    {
	      /* filter out old supplements */
	      for (i = j = 0; i < dqs.count; i++)
		{
		  p = dqs.elements[i];
		  s = pool->solvables + p;
		  if (s->supplements && solver_is_supplementing_alreadyinstalled(solv, s))
		    dqs.elements[j++] = p;
		}
	      dqs.count = j;
	    }

	  /* multiversion doesn't mix well with supplements.
	   * filter supplemented packages where we already decided
	   * to install a different version (see bnc#501088) */
          if (dqs.count && solv->multiversion.size)
	    {
	      for (i = j = 0; i < dqs.count; i++)
		{
		  p = dqs.elements[i];
		  if (MAPTST(&solv->multiversion, p))
		    {
		      Id p2, pp2;
		      s = pool->solvables + p;
		      FOR_PROVIDES(p2, pp2, s->name)
			if (solv->decisionmap[p2] > 0 && pool->solvables[p2].name == s->name)
			  break;
		      if (p2)
			continue;	/* ignore this package */
		    }
		  dqs.elements[j++] = p;
		}
	      dqs.count = j;
	    }

          /* make dq contain both recommended and supplemented pkgs */
	  if (dqs.count)
	    {
	      for (i = 0; i < dqs.count; i++)
		queue_pushunique(&dq, dqs.elements[i]);
	    }

	  if (dq.count)
	    {
	      Map dqmap;
	      int decisioncount = solv->decisionq.count;

	      if (dq.count == 1)
		{
		  /* simple case, just one package. no need to choose to best version */
		  p = dq.elements[0];
		  if (dqs.count)
		    POOL_DEBUG(SOLV_DEBUG_POLICY, "installing supplemented %s\n", pool_solvid2str(pool, p));
		  else
		    POOL_DEBUG(SOLV_DEBUG_POLICY, "installing recommended %s\n", pool_solvid2str(pool, p));
		  level = setpropagatelearn(solv, level, p, 0, 0);
		  continue;	/* back to main loop */
		}

	      /* filter packages, this gives us the best versions */
	      policy_filter_unwanted(solv, &dq, POLICY_MODE_RECOMMEND);

	      /* create map of result */
	      map_init(&dqmap, pool->nsolvables);
	      for (i = 0; i < dq.count; i++)
		MAPSET(&dqmap, dq.elements[i]);

	      /* install all supplemented packages */
	      for (i = 0; i < dqs.count; i++)
		{
		  p = dqs.elements[i];
		  if (solv->decisionmap[p] || !MAPTST(&dqmap, p))
		    continue;
		  POOL_DEBUG(SOLV_DEBUG_POLICY, "installing supplemented %s\n", pool_solvid2str(pool, p));
		  olevel = level;
		  level = setpropagatelearn(solv, level, p, 0, 0);
		  if (level <= olevel)
		    break;
		}
	      if (i < dqs.count || solv->decisionq.count < decisioncount)
		{
		  map_free(&dqmap);
		  continue;
		}

	      /* install all recommended packages */
	      /* more work as we want to created branches if multiple
               * choices are valid */
	      for (i = 0; i < decisioncount; i++)
		{
		  Id rec, *recp, pp;
		  p = solv->decisionq.elements[i];
		  if (p < 0)
		    continue;
		  s = pool->solvables + p;
		  if (!s->repo || (!solv->addalreadyrecommended && s->repo == solv->installed))
		    continue;
		  if (!s->recommends)
		    continue;
		  recp = s->repo->idarraydata + s->recommends;
		  while ((rec = *recp++) != 0)
		    {
		      queue_empty(&dq);
#ifdef ENABLE_COMPLEX_DEPS
		      if (pool_is_complex_dep(pool, rec))
			  add_complex_recommends(solv, rec, &dq, &dqmap);
		      else
#endif
		      FOR_PROVIDES(p, pp, rec)
			{
			  if (solv->decisionmap[p] > 0)
			    {
			      dq.count = 0;
			      break;
			    }
			  else if (solv->decisionmap[p] == 0 && MAPTST(&dqmap, p))
			    queue_push(&dq, p);
			}
		      if (!dq.count)
			continue;
		      if (dq.count > 1)
		        policy_filter_unwanted(solv, &dq, POLICY_MODE_CHOOSE);
		      /* if we have multiple candidates we open a branch */
		      if (dq.count > 1)
			  createbranch(solv, level, &dq, s - pool->solvables, rec);
		      p = dq.elements[0];
		      POOL_DEBUG(SOLV_DEBUG_POLICY, "installing recommended %s\n", pool_solvid2str(pool, p));
		      olevel = level;
		      level = setpropagatelearn(solv, level, p, 0, 0);
		      if (level <= olevel || solv->decisionq.count < decisioncount)
			break;	/* we had to revert some decisions */
		    }
		  if (rec)
		    break;	/* had a problem above, quit loop */
		}
	      map_free(&dqmap);
	      continue;		/* back to main loop so that all deps are checked */
	    }
	}

      if (!solv->decisioncnt_orphan)
        solv->decisioncnt_orphan = solv->decisionq.count;
      if (solv->dupmap_all && solv->installed)
	{
	  int installedone = 0;

	  /* let's see if we can install some unsupported package */
	  POOL_DEBUG(SOLV_DEBUG_SOLVER, "deciding orphaned packages\n");
	  for (i = 0; i < solv->orphaned.count; i++)
	    {
	      p = solv->orphaned.elements[i];
	      if (solv->decisionmap[p])
		continue;	/* already decided */
	      if (solv->droporphanedmap_all)
		continue;
	      if (solv->droporphanedmap.size && MAPTST(&solv->droporphanedmap, p - solv->installed->start))
		continue;
	      POOL_DEBUG(SOLV_DEBUG_SOLVER, "keeping orphaned %s\n", pool_solvid2str(pool, p));
	      olevel = level;
	      level = setpropagatelearn(solv, level, p, 0, 0);
	      installedone = 1;
	      if (level < olevel)
		break;
	    }
	  if (installedone || i < solv->orphaned.count)
	    continue;		/* back to main loop */
	  for (i = 0; i < solv->orphaned.count; i++)
	    {
	      p = solv->orphaned.elements[i];
	      if (solv->decisionmap[p])
		continue;	/* already decided */
	      POOL_DEBUG(SOLV_DEBUG_SOLVER, "removing orphaned %s\n", pool_solvid2str(pool, p));
	      olevel = level;
	      level = setpropagatelearn(solv, level, -p, 0, 0);
	      if (level < olevel)
		break;
	    }
	  if (i < solv->orphaned.count)
	    continue;		/* back to main loop */
          if (solv->brokenorphanrules)
	    {
	      solver_check_brokenorphanrules(solv, &dq);
	      if (dq.count)
		{
	          policy_filter_unwanted(solv, &dq, POLICY_MODE_CHOOSE);
		  for (i = 0; i < dq.count; i++)
		    {
		      p = dq.elements[i];
		      POOL_DEBUG(SOLV_DEBUG_POLICY, "installing orphaned dep %s\n", pool_solvid2str(pool, p));
		      olevel = level;
		      level = setpropagatelearn(solv, level, p, 0, 0);
		      if (level < olevel)
			break;
		    }
		  continue;
		}
	    }
	}

     /* one final pass to make sure we decided all installed packages */
      if (solv->installed)
	{
	  for (p = solv->installed->start; p < solv->installed->end; p++)
	    {
	      if (solv->decisionmap[p])
		continue;	/* already decided */
	      s = pool->solvables + p;
	      if (s->repo != solv->installed)
		continue;
	      POOL_DEBUG(SOLV_DEBUG_SOLVER, "removing unwanted %s\n", pool_solvid2str(pool, p));
	      olevel = level;
	      level = setpropagatelearn(solv, level, -p, 0, 0);
	      if (level < olevel)
		break;
	    }
	  if (p < solv->installed->end)
	    continue;		/* back to main loop */
	}

      if (solv->installed && solv->cleandepsmap.size && cleandeps_check_mistakes(solv))
	{
	  solver_reset(solv);
	  level = 0;	/* restart from scratch */
	  continue;
	}

      if (solv->solution_callback)
	{
	  solv->solution_callback(solv, solv->solution_callback_data);
	  if (solv->branches.count)
	    {
	      int l, endi = 0;
	      p = l = 0;
	      for (i = solv->branches.count - 1; i >= 0; i--)
		{
		  p = solv->branches.elements[i];
		  if (p > 0 && !l)
		    {
		      endi = i + 1;
		      l = p;
		      i -= 3;	/* skip: p data count */
		    }
		  else if (p > 0)
		    break;
		  else if (p < 0)
		    l = 0;
		}
	      if (i >= 0)
		{
		  while (i > 0 && solv->branches.elements[i - 1] > 0)
		    i--;
		  level = takebranch(solv, i, endi, "branching", disablerules);
		  continue;
		}
	    }
	  /* all branches done, we're finally finished */
	  break;
	}

      /* auto-minimization step */
      if (solv->branches.count)
	{
	  int endi, lasti = -1, lastiend = -1;
	  if (solv->recommends_index < solv->decisionq.count)
	    policy_update_recommendsmap(solv);
	  for (endi = solv->branches.count; endi > 0;)
	    {
	      int l, lastsi = -1, starti = endi - solv->branches.elements[endi - 2];
	      l = solv->branches.elements[endi - 1];
	      for (i = starti; i < endi - 4; i++)
		{
		  p = solv->branches.elements[i];
		  if (p <= 0)
		    continue;
		  if (solv->decisionmap[p] > l)
		    {
		      lasti = i;
		      lastiend = endi;
		      lastsi = -1;
		      break;
		    }
		  if (lastsi < 0 && (MAPTST(&solv->recommendsmap, p) || solver_is_supplementing(solv, pool->solvables + p)))
		    lastsi = i;
		}
	      if (lastsi >= 0)
		{
		  /* we have a recommended package that could not be installed */
		  /* take it if our current selection is not recommended */
		  for (i = starti; i < endi - 4; i++)
		    {
		      p = -solv->branches.elements[i];
		      if (p <= 0 || solv->decisionmap[p] != l + 1)
			continue;
		      if (!(MAPTST(&solv->recommendsmap, p) || solver_is_supplementing(solv, pool->solvables + p)))
			{
			  lasti = lastsi;
			  lastiend = endi;
			  break;
			}
		    }
		}
	      endi = starti;
	    }
	  if (lasti >= 0)
	    {
	      minimizationsteps++;
	      level = takebranch(solv, lasti, lastiend, "minimizing", disablerules);
	      continue;		/* back to main loop */
	    }
	}
      /* no minimization found, we're finally finished! */
      break;
    }

  POOL_DEBUG(SOLV_DEBUG_STATS, "solver statistics: %d learned rules, %d unsolvable, %d minimization steps\n", solv->stats_learned, solv->stats_unsolvable, minimizationsteps);

  POOL_DEBUG(SOLV_DEBUG_STATS, "done solving.\n\n");
  queue_free(&dq);
  queue_free(&dqs);
  if (level < 0)
    {
      /* unsolvable */
      solv->decisioncnt_jobs = solv->decisionq.count;
      solv->decisioncnt_update = solv->decisionq.count;
      solv->decisioncnt_keep = solv->decisionq.count;
      solv->decisioncnt_resolve = solv->decisionq.count;
      solv->decisioncnt_weak = solv->decisionq.count;
      solv->decisioncnt_orphan = solv->decisionq.count;
    }
#if 0
  solver_printdecisionq(solv, SOLV_DEBUG_RESULT);
#endif
}


/*-------------------------------------------------------------------
 *
 * remove disabled conflicts
 *
 * purpose: update the decisionmap after some rules were disabled.
 * this is used to calculate the suggested/recommended package list.
 * Also returns a "removed" list to undo the discisionmap changes.
 */

static void
removedisabledconflicts(Solver *solv, Queue *removed)
{
  Pool *pool = solv->pool;
  int i, n;
  Id p, why, *dp;
  Id new;
  Rule *r;
  Id *decisionmap = solv->decisionmap;

  queue_empty(removed);
  for (i = 0; i < solv->decisionq.count; i++)
    {
      p = solv->decisionq.elements[i];
      if (p > 0)
	continue;	/* conflicts only, please */
      why = solv->decisionq_why.elements[i];
      if (why == 0)
	{
	  /* no rule involved, must be a orphan package drop */
	  continue;
	}
      /* we never do conflicts on free decisions, so there
       * must have been an unit rule */
      assert(why > 0);
      r = solv->rules + why;
      if (r->d < 0 && decisionmap[-p])
	{
	  /* rule is now disabled, remove from decisionmap */
	  POOL_DEBUG(SOLV_DEBUG_SOLVER, "removing conflict for package %s[%d]\n", pool_solvid2str(pool, -p), -p);
	  queue_push(removed, -p);
	  queue_push(removed, decisionmap[-p]);
	  decisionmap[-p] = 0;
	}
    }
  if (!removed->count)
    return;
  /* we removed some confliced packages. some of them might still
   * be in conflict, so search for unit rules and re-conflict */
  new = 0;
  for (i = n = 1, r = solv->rules + i; n < solv->nrules; i++, r++, n++)
    {
      if (i == solv->nrules)
	{
	  i = 1;
	  r = solv->rules + i;
	}
      if (r->d < 0)
	continue;
      if (!r->w2)
	{
	  if (r->p < 0 && !decisionmap[-r->p])
	    new = r->p;
	}
      else if (!r->d)
	{
	  /* binary rule */
	  if (r->p < 0 && decisionmap[-r->p] == 0 && DECISIONMAP_FALSE(r->w2))
	    new = r->p;
	  else if (r->w2 < 0 && decisionmap[-r->w2] == 0 && DECISIONMAP_FALSE(r->p))
	    new = r->w2;
	}
      else
	{
	  if (r->p < 0 && decisionmap[-r->p] == 0)
	    new = r->p;
	  if (new || DECISIONMAP_FALSE(r->p))
	    {
	      dp = pool->whatprovidesdata + r->d;
	      while ((p = *dp++) != 0)
		{
		  if (new && p == new)
		    continue;
		  if (p < 0 && decisionmap[-p] == 0)
		    {
		      if (new)
			{
			  new = 0;
			  break;
			}
		      new = p;
		    }
		  else if (!DECISIONMAP_FALSE(p))
		    {
		      new = 0;
		      break;
		    }
		}
	    }
	}
      if (new)
	{
	  POOL_DEBUG(SOLV_DEBUG_SOLVER, "re-conflicting package %s[%d]\n", pool_solvid2str(pool, -new), -new);
	  decisionmap[-new] = -1;
	  new = 0;
	  n = 0;	/* redo all rules */
	}
    }
}

static inline void
undo_removedisabledconflicts(Solver *solv, Queue *removed)
{
  int i;
  for (i = 0; i < removed->count; i += 2)
    solv->decisionmap[removed->elements[i]] = removed->elements[i + 1];
}


/*-------------------------------------------------------------------
 *
 * weaken solvable dependencies
 */

static void
weaken_solvable_deps(Solver *solv, Id p)
{
  int i;
  Rule *r;

  for (i = 1, r = solv->rules + i; i < solv->pkgrules_end; i++, r++)
    {
      if (r->p != -p)
	continue;
      if ((r->d == 0 || r->d == -1) && r->w2 < 0)
	continue;	/* conflict */
      queue_push(&solv->weakruleq, i);
    }
}


/********************************************************************/
/* main() */


void
solver_calculate_multiversionmap(Pool *pool, Queue *job, Map *multiversionmap)
{
  int i;
  Id how, what, select;
  Id p, pp;
  for (i = 0; i < job->count; i += 2)
    {
      how = job->elements[i];
      if ((how & SOLVER_JOBMASK) != SOLVER_MULTIVERSION)
	continue;
      what = job->elements[i + 1];
      select = how & SOLVER_SELECTMASK;
      if (!multiversionmap->size)
	map_grow(multiversionmap, pool->nsolvables);
      if (select == SOLVER_SOLVABLE_ALL)
	{
	  FOR_POOL_SOLVABLES(p)
	    MAPSET(multiversionmap, p);
	}
      else if (select == SOLVER_SOLVABLE_REPO)
	{
	  Solvable *s;
	  Repo *repo = pool_id2repo(pool, what);
	  if (repo)
	    FOR_REPO_SOLVABLES(repo, p, s)
	      MAPSET(multiversionmap, p);
	}
      FOR_JOB_SELECT(p, pp, select, what)
        MAPSET(multiversionmap, p);
    }
}

void
solver_calculate_noobsmap(Pool *pool, Queue *job, Map *multiversionmap)
{
  solver_calculate_multiversionmap(pool, job, multiversionmap);
}

/*
 * add a rule created by a job, record job number and weak flag
 */
static inline void
solver_addjobrule(Solver *solv, Id p, Id p2, Id d, Id job, int weak)
{
  solver_addrule(solv, p, p2, d);
  queue_push(&solv->ruletojob, job);
  if (weak)
    queue_push(&solv->weakruleq, solv->nrules - 1);
}

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

static void
add_update_target(Solver *solv, Id p, Id how)
{
  Pool *pool = solv->pool;
  Solvable *s = pool->solvables + p;
  Repo *installed = solv->installed;
  Id pi, pip;
  if (!solv->update_targets)
    {
      solv->update_targets = solv_calloc(1, sizeof(Queue));
      queue_init(solv->update_targets);
    }
  if (s->repo == installed)
    {
      queue_push2(solv->update_targets, p, p);
      return;
    }
  FOR_PROVIDES(pi, pip, s->name)
    {
      Solvable *si = pool->solvables + pi;
      if (si->repo != installed || si->name != s->name)
	continue;
      if (how & SOLVER_FORCEBEST)
	{
	  if (!solv->bestupdatemap.size)
	    map_grow(&solv->bestupdatemap, installed->end - installed->start);
	  MAPSET(&solv->bestupdatemap, pi - installed->start);
	}
      if (how & SOLVER_CLEANDEPS)
	add_cleandeps_package(solv, pi);
      queue_push2(solv->update_targets, pi, p);
      /* check if it's ok to keep the installed package */
      if (s->evr == si->evr && solvable_identical(s, si))
        queue_push2(solv->update_targets, pi, pi);
    }
  if (s->obsoletes)
    {
      Id obs, *obsp = s->repo->idarraydata + s->obsoletes;
      while ((obs = *obsp++) != 0)
	{
	  FOR_PROVIDES(pi, pip, obs)
	    {
	      Solvable *si = pool->solvables + pi;
	      if (si->repo != installed)
		continue;
	      if (si->name == s->name)
		continue;	/* already handled above */
	      if (!pool->obsoleteusesprovides && !pool_match_nevr(pool, si, obs))
		continue;
	      if (pool->obsoleteusescolors && !pool_colormatch(pool, s, si))
		continue;
	      if (how & SOLVER_FORCEBEST)
		{
		  if (!solv->bestupdatemap.size)
		    map_grow(&solv->bestupdatemap, installed->end - installed->start);
		  MAPSET(&solv->bestupdatemap, pi - installed->start);
		}
	      if (how & SOLVER_CLEANDEPS)
		add_cleandeps_package(solv, pi);
	      queue_push2(solv->update_targets, pi, p);
	    }
	}
    }
}

static int
transform_update_targets_sortfn(const void *ap, const void *bp, void *dp)
{
  const Id *a = ap;
  const Id *b = bp;
  if (a[0] - b[0])
    return a[0] - b[0];
  return a[1] - b[1];
}

static void
transform_update_targets(Solver *solv)
{
  Repo *installed = solv->installed;
  Queue *update_targets = solv->update_targets;
  int i, j;
  Id p, q, lastp, lastq;

  if (!update_targets->count)
    {
      queue_free(update_targets);
      solv->update_targets = solv_free(update_targets);
      return;
    }
  if (update_targets->count > 2)
    solv_sort(update_targets->elements, update_targets->count >> 1, 2 * sizeof(Id), transform_update_targets_sortfn, solv);
  queue_insertn(update_targets, 0, installed->end - installed->start, 0);
  lastp = lastq = 0;
  for (i = j = installed->end - installed->start; i < update_targets->count; i += 2)
    {
      if ((p = update_targets->elements[i]) != lastp)
	{
	  if (!solv->updatemap.size)
	    map_grow(&solv->updatemap, installed->end - installed->start);
	  MAPSET(&solv->updatemap, p - installed->start);
	  update_targets->elements[j++] = 0;			/* finish old set */
	  update_targets->elements[p - installed->start] = j;	/* start new set */
	  lastp = p;
	  lastq = 0;
	}
      if ((q = update_targets->elements[i + 1]) != lastq)
	{
          update_targets->elements[j++] = q;
	  lastq = q;
	}
    }
  queue_truncate(update_targets, j);
  queue_push(update_targets, 0);	/* finish last set */
}


static void
addedmap2deduceq(Solver *solv, Map *addedmap)
{
  Pool *pool = solv->pool;
  int i, j;
  Id p;
  Rule *r;

  queue_empty(&solv->addedmap_deduceq);
  for (i = 2, j = solv->pkgrules_end - 1; i < pool->nsolvables && j > 0; j--)
    {
      r = solv->rules + j;
      if (r->p >= 0)
	continue;
      if ((r->d == 0 || r->d == -1) && r->w2 < 0)
	continue;
      p = -r->p;
      if (!MAPTST(addedmap, p))
	{
	  /* should never happen, but... */
	  if (!solv->addedmap_deduceq.count || solv->addedmap_deduceq.elements[solv->addedmap_deduceq.count - 1] != -p)
            queue_push(&solv->addedmap_deduceq, -p);
	  continue;
	}
      for (; i < p; i++)
        if (MAPTST(addedmap, i))
          queue_push(&solv->addedmap_deduceq, i);
      if (i == p)
        i++;
    }
  for (; i < pool->nsolvables; i++)
    if (MAPTST(addedmap, i))
      queue_push(&solv->addedmap_deduceq, i);
  j = 0;
  for (i = 2; i < pool->nsolvables; i++)
    if (MAPTST(addedmap, i))
      j++;
}

static void
deduceq2addedmap(Solver *solv, Map *addedmap)
{
  int j;
  Id p;
  Rule *r;
  for (j = solv->pkgrules_end - 1; j > 0; j--)
    {
      r = solv->rules + j;
      if (r->d < 0 && r->p)
	solver_enablerule(solv, r);
      if (r->p >= 0)
	continue;
      if ((r->d == 0 || r->d == -1) && r->w2 < 0)
	continue;
      p = -r->p;
      MAPSET(addedmap, p);
    }
  for (j = 0; j < solv->addedmap_deduceq.count; j++)
    {
      p = solv->addedmap_deduceq.elements[j];
      if (p > 0)
	MAPSET(addedmap, p);
      else
	MAPCLR(addedmap, p);
    }
}

#ifdef ENABLE_COMPLEX_DEPS
static int
add_complex_jobrules(Solver *solv, Id dep, int flags, int jobidx, int weak)
{
  Pool *pool = solv->pool;
  Queue bq;
  int i, j;

  queue_init(&bq);
  i = pool_normalize_complex_dep(pool, dep, &bq, flags | CPLXDEPS_EXPAND);
  if (i == 0 || i == 1)
    {
      queue_free(&bq);
      if (i == 0)
        solver_addjobrule(solv, -SYSTEMSOLVABLE, 0, 0, jobidx, weak);
      return 0;
    }
  for (i = 0; i < bq.count; i++)
    {
      if (!bq.elements[i])
	continue;
      for (j = 0; bq.elements[i + j + 1]; j++)
        ;
      if (j > 1)
        solver_addjobrule(solv, bq.elements[i], 0, pool_ids2whatprovides(pool, bq.elements + i + 1, j), jobidx, weak);
      else
        solver_addjobrule(solv, bq.elements[i], bq.elements[i + 1], 0, jobidx, weak);
      i += j + 1;
    }
  queue_free(&bq);
  return 1;
}
#endif

/*
 *
 * solve job queue
 *
 */

int
solver_solve(Solver *solv, Queue *job)
{
  Pool *pool = solv->pool;
  Repo *installed = solv->installed;
  int i;
  int oldnrules, initialnrules;
  Map addedmap;		       /* '1' == have pkg-rules for solvable */
  Map installcandidatemap;
  Id how, what, select, name, weak, p, pp, d;
  Queue q;
  Solvable *s;
  Rule *r;
  int now, solve_start;
  int hasdupjob = 0;
  int hasbestinstalljob = 0;

  solve_start = solv_timems(0);

  /* log solver options */
  POOL_DEBUG(SOLV_DEBUG_STATS, "solver started\n");
  POOL_DEBUG(SOLV_DEBUG_STATS, "dosplitprovides=%d, noupdateprovide=%d, noinfarchcheck=%d\n", solv->dosplitprovides, solv->noupdateprovide, solv->noinfarchcheck);
  POOL_DEBUG(SOLV_DEBUG_STATS, "allowuninstall=%d, allowdowngrade=%d, allownamechange=%d, allowarchchange=%d, allowvendorchange=%d\n", solv->allowuninstall, solv->allowdowngrade, solv->allownamechange, solv->allowarchchange, solv->allowvendorchange);
  POOL_DEBUG(SOLV_DEBUG_STATS, "promoteepoch=%d, forbidselfconflicts=%d\n", pool->promoteepoch, pool->forbidselfconflicts);
  POOL_DEBUG(SOLV_DEBUG_STATS, "obsoleteusesprovides=%d, implicitobsoleteusesprovides=%d, obsoleteusescolors=%d, implicitobsoleteusescolors=%d\n", pool->obsoleteusesprovides, pool->implicitobsoleteusesprovides, pool->obsoleteusescolors, pool->implicitobsoleteusescolors);
  POOL_DEBUG(SOLV_DEBUG_STATS, "dontinstallrecommended=%d, addalreadyrecommended=%d\n", solv->dontinstallrecommended, solv->addalreadyrecommended);

  /* create whatprovides if not already there */
  if (!pool->whatprovides)
    pool_createwhatprovides(pool);

  /* create obsolete index */
  policy_create_obsolete_index(solv);

  /* remember job */
  queue_free(&solv->job);
  queue_init_clone(&solv->job, job);
  solv->pooljobcnt = pool->pooljobs.count;
  if (pool->pooljobs.count)
    queue_insertn(&solv->job, 0, pool->pooljobs.count, pool->pooljobs.elements);
  job = &solv->job;

  /* free old stuff in jase we re-run a solver */
  queuep_free(&solv->update_targets);
  queuep_free(&solv->cleandeps_updatepkgs);
  queue_empty(&solv->ruleassertions);
  solv->bestrules_pkg = solv_free(solv->bestrules_pkg);
  solv->yumobsrules_info = solv_free(solv->yumobsrules_info);
  solv->choicerules_ref = solv_free(solv->choicerules_ref);
  if (solv->noupdate.size)
    map_empty(&solv->noupdate);
  map_zerosize(&solv->multiversion);
  solv->updatemap_all = 0;
  map_zerosize(&solv->updatemap);
  solv->bestupdatemap_all = 0;
  map_zerosize(&solv->bestupdatemap);
  solv->fixmap_all = 0;
  map_zerosize(&solv->fixmap);
  solv->dupmap_all = 0;
  map_zerosize(&solv->dupmap);
  map_zerosize(&solv->dupinvolvedmap);
  solv->droporphanedmap_all = 0;
  map_zerosize(&solv->droporphanedmap);
  map_zerosize(&solv->cleandepsmap);
  map_zerosize(&solv->weakrulemap);
  queue_empty(&solv->weakruleq);
  solv->watches = solv_free(solv->watches);
  queue_empty(&solv->ruletojob);
  if (solv->decisionq.count)
    memset(solv->decisionmap, 0, pool->nsolvables * sizeof(Id));
  queue_empty(&solv->decisionq);
  queue_empty(&solv->decisionq_why);
  solv->decisioncnt_jobs = solv->decisioncnt_update = solv->decisioncnt_keep = solv->decisioncnt_resolve = solv->decisioncnt_weak = solv->decisioncnt_orphan = 0;
  queue_empty(&solv->learnt_why);
  queue_empty(&solv->learnt_pool);
  queue_empty(&solv->branches);
  solv->propagate_index = 0;
  queue_empty(&solv->problems);
  queue_empty(&solv->solutions);
  queue_empty(&solv->orphaned);
  solv->stats_learned = solv->stats_unsolvable = 0;
  if (solv->recommends_index)
    {
      map_empty(&solv->recommendsmap);
      map_empty(&solv->suggestsmap);
      queuep_free(&solv->recommendscplxq);
      queuep_free(&solv->suggestscplxq);
      solv->recommends_index = 0;
    }
  queuep_free(&solv->brokenorphanrules);
  solv->specialupdaters = solv_free(solv->specialupdaters);


  /*
   * create basic rule set of all involved packages
   * use addedmap bitmap to make sure we don't create rules twice
   */

  /* create multiversion map if needed */
  solver_calculate_multiversionmap(pool, job, &solv->multiversion);

  map_init(&addedmap, pool->nsolvables);
  MAPSET(&addedmap, SYSTEMSOLVABLE);

  map_init(&installcandidatemap, pool->nsolvables);
  queue_init(&q);

  now = solv_timems(0);
  /*
   * create rules for all package that could be involved with the solving
   * so called: pkg rules
   *
   */
  initialnrules = solv->pkgrules_end ? solv->pkgrules_end : 1;
  if (initialnrules > 1)
    deduceq2addedmap(solv, &addedmap);
  if (solv->nrules != initialnrules)
    solver_shrinkrules(solv, initialnrules);
  solv->nrules = initialnrules;
  solv->pkgrules_end = 0;

  if (installed)
    {
      /* check for update/verify jobs as they need to be known early */
      /* also setup the droporphaned map, we need it when creating update rules */
      for (i = 0; i < job->count; i += 2)
	{
	  how = job->elements[i];
	  what = job->elements[i + 1];
	  select = how & SOLVER_SELECTMASK;
	  switch (how & SOLVER_JOBMASK)
	    {
	    case SOLVER_VERIFY:
	      if (select == SOLVER_SOLVABLE_ALL || (select == SOLVER_SOLVABLE_REPO && installed && what == installed->repoid))
	        solv->fixmap_all = 1;
	      FOR_JOB_SELECT(p, pp, select, what)
		{
		  s = pool->solvables + p;
		  if (s->repo != installed)
		    continue;
		  if (!solv->fixmap.size)
		    map_grow(&solv->fixmap, installed->end - installed->start);
		  MAPSET(&solv->fixmap, p - installed->start);
		}
	      break;
	    case SOLVER_UPDATE:
	      if (select == SOLVER_SOLVABLE_ALL)
		{
		  solv->updatemap_all = 1;
		  if (how & SOLVER_FORCEBEST)
		    solv->bestupdatemap_all = 1;
		  if (how & SOLVER_CLEANDEPS)
		    {
		      FOR_REPO_SOLVABLES(installed, p, s)
			add_cleandeps_package(solv, p);
		    }
		}
	      else if (select == SOLVER_SOLVABLE_REPO)
		{
		  Repo *repo = pool_id2repo(pool, what);
		  if (!repo)
		    break;
		  if (repo == installed && !(how & SOLVER_TARGETED))
		    {
		      solv->updatemap_all = 1;
		      if (how & SOLVER_FORCEBEST)
			solv->bestupdatemap_all = 1;
		      if (how & SOLVER_CLEANDEPS)
			{
			  FOR_REPO_SOLVABLES(installed, p, s)
			    add_cleandeps_package(solv, p);
			}
		      break;
		    }
		  if (solv->noautotarget && !(how & SOLVER_TARGETED))
		    break;
		  /* targeted update */
		  FOR_REPO_SOLVABLES(repo, p, s)
		    add_update_target(solv, p, how);
		}
	      else
		{
		  if (!(how & SOLVER_TARGETED))
		    {
		      int targeted = 1;
		      FOR_JOB_SELECT(p, pp, select, what)
			{
			  s = pool->solvables + p;
			  if (s->repo != installed)
			    continue;
			  if (!solv->updatemap.size)
			    map_grow(&solv->updatemap, installed->end - installed->start);
			  MAPSET(&solv->updatemap, p - installed->start);
			  if (how & SOLVER_FORCEBEST)
			    {
			      if (!solv->bestupdatemap.size)
				map_grow(&solv->bestupdatemap, installed->end - installed->start);
			      MAPSET(&solv->bestupdatemap, p - installed->start);
			    }
			  if (how & SOLVER_CLEANDEPS)
			    add_cleandeps_package(solv, p);
			  targeted = 0;
			}
		      if (!targeted || solv->noautotarget)
			break;
		    }
		  FOR_JOB_SELECT(p, pp, select, what)
		    add_update_target(solv, p, how);
		}
	      break;
	    case SOLVER_DROP_ORPHANED:
	      if (select == SOLVER_SOLVABLE_ALL || (select == SOLVER_SOLVABLE_REPO && what == installed->repoid))
		solv->droporphanedmap_all = 1;
	      FOR_JOB_SELECT(p, pp, select, what)
		{
		  s = pool->solvables + p;
		  if (s->repo != installed)
		    continue;
		  if (!solv->droporphanedmap.size)
		    map_grow(&solv->droporphanedmap, installed->end - installed->start);
		  MAPSET(&solv->droporphanedmap, p - installed->start);
		}
	      break;
	    default:
	      break;
	    }
	}

      if (solv->update_targets)
	transform_update_targets(solv);

      oldnrules = solv->nrules;
      FOR_REPO_SOLVABLES(installed, p, s)
	solver_addpkgrulesforsolvable(solv, s, &addedmap);
      POOL_DEBUG(SOLV_DEBUG_STATS, "added %d pkg rules for installed solvables\n", solv->nrules - oldnrules);
      oldnrules = solv->nrules;
      FOR_REPO_SOLVABLES(installed, p, s)
	solver_addpkgrulesforupdaters(solv, s, &addedmap, 1);
      POOL_DEBUG(SOLV_DEBUG_STATS, "added %d pkg rules for updaters of installed solvables\n", solv->nrules - oldnrules);
    }

  /*
   * create rules for all packages involved in the job
   * (to be installed or removed)
   */

  oldnrules = solv->nrules;
  for (i = 0; i < job->count; i += 2)
    {
      how = job->elements[i];
      what = job->elements[i + 1];
      select = how & SOLVER_SELECTMASK;

      switch (how & SOLVER_JOBMASK)
	{
	case SOLVER_INSTALL:
	  FOR_JOB_SELECT(p, pp, select, what)
	    {
	      MAPSET(&installcandidatemap, p);
	      solver_addpkgrulesforsolvable(solv, pool->solvables + p, &addedmap);
	    }
	  break;
	case SOLVER_DISTUPGRADE:
	  if (select == SOLVER_SOLVABLE_ALL)
	    {
	      solv->dupmap_all = 1;
	      solv->updatemap_all = 1;
	      if (how & SOLVER_FORCEBEST)
		solv->bestupdatemap_all = 1;
	    }
	  if (!solv->dupmap_all || solv->allowuninstall)
	    hasdupjob = 1;
	  break;
	default:
	  break;
	}
    }
  POOL_DEBUG(SOLV_DEBUG_STATS, "added %d pkg rules for packages involved in a job\n", solv->nrules - oldnrules);


  /*
   * add rules for suggests, enhances
   */
  oldnrules = solv->nrules;
  solver_addpkgrulesforweak(solv, &addedmap);
  POOL_DEBUG(SOLV_DEBUG_STATS, "added %d pkg rules because of weak dependencies\n", solv->nrules - oldnrules);

#ifdef ENABLE_LINKED_PKGS
  oldnrules = solv->nrules;
  solver_addpkgrulesforlinked(solv, &addedmap);
  POOL_DEBUG(SOLV_DEBUG_STATS, "added %d pkg rules because of linked packages\n", solv->nrules - oldnrules);
#endif

  /*
   * first pass done, we now have all the pkg rules we need.
   * unify existing rules before going over all job rules and
   * policy rules.
   * at this point the system is always solvable,
   * as an empty system (remove all packages) is a valid solution
   */

  IF_POOLDEBUG (SOLV_DEBUG_STATS)
    {
      int possible = 0, installable = 0;
      for (i = 1; i < pool->nsolvables; i++)
	{
	  if (pool_installable(pool, pool->solvables + i))
	    installable++;
	  if (MAPTST(&addedmap, i))
	    possible++;
	}
      POOL_DEBUG(SOLV_DEBUG_STATS, "%d of %d installable solvables considered for solving\n", possible, installable);
    }

  if (solv->nrules > initialnrules)
    solver_unifyrules(solv);			/* remove duplicate pkg rules */
  solv->pkgrules_end = solv->nrules;		/* mark end of pkg rules */

  if (solv->nrules > initialnrules)
    addedmap2deduceq(solv, &addedmap);		/* so that we can recreate the addedmap */

  POOL_DEBUG(SOLV_DEBUG_STATS, "pkg rule memory used: %d K\n", solv->nrules * (int)sizeof(Rule) / 1024);
  POOL_DEBUG(SOLV_DEBUG_STATS, "pkg rule creation took %d ms\n", solv_timems(now));

  /* create dup maps if needed. We need the maps early to create our
   * update rules */
  if (hasdupjob)
    solver_createdupmaps(solv);

  /*
   * create feature rules
   *
   * foreach installed:
   *   create assertion (keep installed, if no update available)
   *   or
   *   create update rule (A|update1(A)|update2(A)|...)
   *
   * those are used later on to keep a version of the installed packages in
   * best effort mode
   */

  solv->featurerules = solv->nrules;              /* mark start of feature rules */
  if (installed)
    {
      /* foreach possibly installed solvable */
      for (i = installed->start, s = pool->solvables + i; i < installed->end; i++, s++)
	{
	  if (s->repo != installed)
	    {
	      solver_addrule(solv, 0, 0, 0);	/* create dummy rule */
	      continue;
	    }
	  solver_addupdaterule(solv, s, 1);    /* allow s to be updated */
	}
      /* make sure we accounted for all rules */
      assert(solv->nrules - solv->featurerules == installed->end - installed->start);
    }
  solv->featurerules_end = solv->nrules;

    /*
     * Add update rules for installed solvables
     *
     * almost identical to feature rules
     * except that downgrades/archchanges/vendorchanges are not allowed
     */

  solv->updaterules = solv->nrules;

  if (installed)
    { /* foreach installed solvables */
      /* we create all update rules, but disable some later on depending on the job */
      for (i = installed->start, s = pool->solvables + i; i < installed->end; i++, s++)
	{
	  Rule *sr;

	  if (s->repo != installed)
	    {
	      solver_addrule(solv, 0, 0, 0);	/* create dummy rule */
	      continue;
	    }
	  solver_addupdaterule(solv, s, 0);	/* allowall = 0: downgrades not allowed */
	  /*
	   * check for and remove duplicate
	   */
	  r = solv->rules + solv->nrules - 1;           /* r: update rule */
          if (!r->p)
	    continue;
	  sr = r - (installed->end - installed->start); /* sr: feature rule */
	  /* it's also orphaned if the feature rule consists just of the installed package */
	  if (!solv->dupmap_all && sr->p == i && !sr->d && !sr->w2)
	    queue_push(&solv->orphaned, i);
	  if (!solver_rulecmp(solv, r, sr))
	    memset(sr, 0, sizeof(*sr));		/* delete unneeded feature rule */
	  else
	    solver_disablerule(solv, sr);	/* disable feature rule for now */
	}
      /* consistency check: we added a rule for _every_ installed solvable */
      assert(solv->nrules - solv->updaterules == installed->end - installed->start);
    }
  solv->updaterules_end = solv->nrules;


  /*
   * now add all job rules
   */

  solv->jobrules = solv->nrules;
  for (i = 0; i < job->count; i += 2)
    {
      oldnrules = solv->nrules;

      if (i && i == solv->pooljobcnt)
        POOL_DEBUG(SOLV_DEBUG_JOB, "end of pool jobs\n");
      how = job->elements[i];
      what = job->elements[i + 1];
      weak = how & SOLVER_WEAK;
      select = how & SOLVER_SELECTMASK;
      switch (how & SOLVER_JOBMASK)
	{
	case SOLVER_INSTALL:
	  POOL_DEBUG(SOLV_DEBUG_JOB, "job: %sinstall %s\n", weak ? "weak " : "", solver_select2str(pool, select, what));
	  if ((how & SOLVER_CLEANDEPS) != 0 && !solv->cleandepsmap.size && installed)
	    map_grow(&solv->cleandepsmap, installed->end - installed->start);
	  if (select == SOLVER_SOLVABLE)
	    {
	      p = what;
	      d = 0;
	    }
#ifdef ENABLE_COMPLEX_DEPS
	  else if ((select == SOLVER_SOLVABLE_PROVIDES || select == SOLVER_SOLVABLE_NAME) && pool_is_complex_dep(pool, what))
	    {
	      if (add_complex_jobrules(solv, what, select == SOLVER_SOLVABLE_NAME ? CPLXDEPS_NAME : 0, i, weak))
	        if (how & SOLVER_FORCEBEST)
		  hasbestinstalljob = 1;
	      break;
	    }
#endif
	  else
	    {
	      queue_empty(&q);
	      FOR_JOB_SELECT(p, pp, select, what)
		queue_push(&q, p);
	      if (!q.count)
		{
		  if (select == SOLVER_SOLVABLE_ONE_OF)
		    break;	/* ignore empty installs */
		  /* no candidate found or unsupported, make this an impossible rule */
		  queue_push(&q, -SYSTEMSOLVABLE);
		}
	      p = queue_shift(&q);	/* get first candidate */
	      d = !q.count ? 0 : pool_queuetowhatprovides(pool, &q);	/* internalize */
	    }
	  /* force install of namespace supplements hack */
	  if (select == SOLVER_SOLVABLE_PROVIDES && !d && (p == SYSTEMSOLVABLE || p == -SYSTEMSOLVABLE) && ISRELDEP(what))
	    {
	      Reldep *rd = GETRELDEP(pool, what);
	      if (rd->flags == REL_NAMESPACE)
		{
		  p = SYSTEMSOLVABLE;
		  if (!solv->installsuppdepq)
		    {
		      solv->installsuppdepq = solv_calloc(1, sizeof(Queue));
		      queue_init(solv->installsuppdepq);
		    }
		  queue_pushunique(solv->installsuppdepq, rd->evr == 0 ? rd->name : what);
		}
	    }
	  solver_addjobrule(solv, p, 0, d, i, weak);
          if (how & SOLVER_FORCEBEST)
	    hasbestinstalljob = 1;
	  break;
	case SOLVER_ERASE:
	  POOL_DEBUG(SOLV_DEBUG_JOB, "job: %s%serase %s\n", weak ? "weak " : "", how & SOLVER_CLEANDEPS ? "clean deps " : "", solver_select2str(pool, select, what));
	  if ((how & SOLVER_CLEANDEPS) != 0 && !solv->cleandepsmap.size && installed)
	    map_grow(&solv->cleandepsmap, installed->end - installed->start);
	  /* specific solvable: by id or by nevra */
	  name = (select == SOLVER_SOLVABLE || (select == SOLVER_SOLVABLE_NAME && ISRELDEP(what))) ? 0 : -1;
	  if (select == SOLVER_SOLVABLE_ALL)	/* hmmm ;) */
	    {
	      FOR_POOL_SOLVABLES(p)
	        solver_addjobrule(solv, -p, 0, 0, i, weak);
	    }
	  else if (select == SOLVER_SOLVABLE_REPO)
	    {
	      Repo *repo = pool_id2repo(pool, what);
	      if (repo)
		FOR_REPO_SOLVABLES(repo, p, s)
		  solver_addjobrule(solv, -p, 0, 0, i, weak);
	    }
#ifdef ENABLE_COMPLEX_DEPS
	  else if ((select == SOLVER_SOLVABLE_PROVIDES || select == SOLVER_SOLVABLE_NAME) && pool_is_complex_dep(pool, what))
	    {
	      /* no special "erase a specific solvable" handling? */
	      add_complex_jobrules(solv, what, select == SOLVER_SOLVABLE_NAME ? (CPLXDEPS_NAME | CPLXDEPS_TODNF | CPLXDEPS_INVERT) : (CPLXDEPS_TODNF | CPLXDEPS_INVERT), i, weak);
	      break;
	    }
#endif
	  FOR_JOB_SELECT(p, pp, select, what)
	    {
	      s = pool->solvables + p;
	      if (installed && s->repo == installed)
		name = !name ? s->name : -1;
	      solver_addjobrule(solv, -p, 0, 0, i, weak);
	    }
	  /* special case for "erase a specific solvable": we also
	   * erase all other solvables with that name, so that they
	   * don't get picked up as replacement.
	   * name is > 0 if exactly one installed solvable matched.
	   */
	  /* XXX: look also at packages that obsolete this package? */
	  if (name > 0)
	    {
	      int j, k;
	      k = solv->nrules;
	      FOR_PROVIDES(p, pp, name)
		{
		  s = pool->solvables + p;
		  if (s->name != name)
		    continue;
		  /* keep other versions installed */
		  if (s->repo == installed)
		    continue;
		  /* keep installcandidates of other jobs */
		  if (MAPTST(&installcandidatemap, p))
		    continue;
		  /* don't add the same rule twice */
		  for (j = oldnrules; j < k; j++)
		    if (solv->rules[j].p == -p)
		      break;
		  if (j == k)
		    solver_addjobrule(solv, -p, 0, 0, i, weak);	/* remove by id */
		}
	    }
	  break;

	case SOLVER_UPDATE:
	  POOL_DEBUG(SOLV_DEBUG_JOB, "job: %supdate %s\n", weak ? "weak " : "", solver_select2str(pool, select, what));
	  break;
	case SOLVER_VERIFY:
	  POOL_DEBUG(SOLV_DEBUG_JOB, "job: %sverify %s\n", weak ? "weak " : "", solver_select2str(pool, select, what));
	  break;
	case SOLVER_WEAKENDEPS:
	  POOL_DEBUG(SOLV_DEBUG_JOB, "job: %sweaken deps %s\n", weak ? "weak " : "", solver_select2str(pool, select, what));
	  if (select != SOLVER_SOLVABLE)
	    break;
	  s = pool->solvables + what;
	  weaken_solvable_deps(solv, what);
	  break;
	case SOLVER_MULTIVERSION:
	  POOL_DEBUG(SOLV_DEBUG_JOB, "job: %smultiversion %s\n", weak ? "weak " : "", solver_select2str(pool, select, what));
	  break;
	case SOLVER_LOCK:
	  POOL_DEBUG(SOLV_DEBUG_JOB, "job: %slock %s\n", weak ? "weak " : "", solver_select2str(pool, select, what));
	  if (select == SOLVER_SOLVABLE_ALL)
	    {
	      FOR_POOL_SOLVABLES(p)
	        solver_addjobrule(solv, installed && pool->solvables[p].repo == installed ? p : -p, 0, 0, i, weak);
	    }
          else if (select == SOLVER_SOLVABLE_REPO)
	    {
	      Repo *repo = pool_id2repo(pool, what);
	      if (repo)
	        FOR_REPO_SOLVABLES(repo, p, s)
	          solver_addjobrule(solv, installed && pool->solvables[p].repo == installed ? p : -p, 0, 0, i, weak);
	    }
	  FOR_JOB_SELECT(p, pp, select, what)
	    solver_addjobrule(solv, installed && pool->solvables[p].repo == installed ? p : -p, 0, 0, i, weak);
	  break;
	case SOLVER_DISTUPGRADE:
	  POOL_DEBUG(SOLV_DEBUG_JOB, "job: distupgrade %s\n", solver_select2str(pool, select, what));
	  break;
	case SOLVER_DROP_ORPHANED:
	  POOL_DEBUG(SOLV_DEBUG_JOB, "job: drop orphaned %s\n", solver_select2str(pool, select, what));
	  break;
	case SOLVER_USERINSTALLED:
	  POOL_DEBUG(SOLV_DEBUG_JOB, "job: user installed %s\n", solver_select2str(pool, select, what));
	  break;
	default:
	  POOL_DEBUG(SOLV_DEBUG_JOB, "job: unknown job\n");
	  break;
	}
	
      IF_POOLDEBUG (SOLV_DEBUG_JOB)
	{
	  int j;
	  if (solv->nrules == oldnrules)
	    POOL_DEBUG(SOLV_DEBUG_JOB, "  - no rule created\n");
	  for (j = oldnrules; j < solv->nrules; j++)
	    {
	      POOL_DEBUG(SOLV_DEBUG_JOB, "  - job ");
	      solver_printrule(solv, SOLV_DEBUG_JOB, solv->rules + j);
	    }
	}
    }
  assert(solv->ruletojob.count == solv->nrules - solv->jobrules);
  solv->jobrules_end = solv->nrules;

  /* now create infarch and dup rules */
  if (!solv->noinfarchcheck)
    {
      solver_addinfarchrules(solv, &addedmap);
#if 0
      if (pool->implicitobsoleteusescolors)
	{
	  /* currently doesn't work well with infarch rules, so make
           * them weak */
	  for (i = solv->infarchrules; i < solv->infarchrules_end; i++)
	    queue_push(&solv->weakruleq, i);
	}
#endif
    }
  else
    solv->infarchrules = solv->infarchrules_end = solv->nrules;

  if (hasdupjob)
    solver_addduprules(solv, &addedmap);
  else
    solv->duprules = solv->duprules_end = solv->nrules;

  if (solv->bestupdatemap_all || solv->bestupdatemap.size || hasbestinstalljob)
    solver_addbestrules(solv, hasbestinstalljob);
  else
    solv->bestrules = solv->bestrules_end = solv->nrules;

  if (hasdupjob)
    solver_freedupmaps(solv);	/* no longer needed */

  if (solv->do_yum_obsoletes)
    solver_addyumobsrules(solv);
  else
    solv->yumobsrules = solv->yumobsrules_end = solv->nrules;

  if (1)
    solver_addchoicerules(solv);
  else
    solv->choicerules = solv->choicerules_end = solv->nrules;

  if (0)
    {
      for (i = solv->featurerules; i < solv->nrules; i++)
        solver_printruleclass(solv, SOLV_DEBUG_RESULT, solv->rules + i);
    }
  /* all rules created
   * --------------------------------------------------------------
   * prepare for solving
   */

  /* free unneeded memory */
  map_free(&addedmap);
  map_free(&installcandidatemap);
  queue_free(&q);

  POOL_DEBUG(SOLV_DEBUG_STATS, "%d pkg rules, 2 * %d update rules, %d job rules, %d infarch rules, %d dup rules, %d choice rules, %d best rules\n", solv->pkgrules_end - 1, solv->updaterules_end - solv->updaterules, solv->jobrules_end - solv->jobrules, solv->infarchrules_end - solv->infarchrules, solv->duprules_end - solv->duprules, solv->choicerules_end - solv->choicerules, solv->bestrules_end - solv->bestrules);
  POOL_DEBUG(SOLV_DEBUG_STATS, "overall rule memory used: %d K\n", solv->nrules * (int)sizeof(Rule) / 1024);

  /* create weak map */
  if (solv->weakruleq.count)
    {
      map_grow(&solv->weakrulemap, solv->nrules);
      for (i = 0; i < solv->weakruleq.count; i++)
	{
	  p = solv->weakruleq.elements[i];
	  MAPSET(&solv->weakrulemap, p);
	}
    }

  /* enable cleandepsmap creation if we have updatepkgs */
  if (solv->cleandeps_updatepkgs && !solv->cleandepsmap.size)
    map_grow(&solv->cleandepsmap, installed->end - installed->start);
  /* no mistakes */
  if (solv->cleandeps_mistakes)
    {
      queue_free(solv->cleandeps_mistakes);
      solv->cleandeps_mistakes = solv_free(solv->cleandeps_mistakes);
    }

  /* all new rules are learnt after this point */
  solv->learntrules = solv->nrules;

  /* create watches chains */
  makewatches(solv);

  /* create assertion index. it is only used to speed up
   * makeruledecsions() a bit */
  for (i = 1, r = solv->rules + i; i < solv->nrules; i++, r++)
    if (r->p && !r->w2 && (r->d == 0 || r->d == -1))
      queue_push(&solv->ruleassertions, i);

  /* disable update rules that conflict with our job */
  solver_disablepolicyrules(solv);

  /* break orphans if requested */
  if (solv->dupmap_all && solv->orphaned.count && solv->break_orphans)
    solver_breakorphans(solv);

  /*
   * ********************************************
   * solve!
   * ********************************************
   */

  now = solv_timems(0);
  solver_run_sat(solv, 1, solv->dontinstallrecommended ? 0 : 1);
  POOL_DEBUG(SOLV_DEBUG_STATS, "solver took %d ms\n", solv_timems(now));

  /*
   * prepare solution queue if there were problems
   */
  solver_prepare_solutions(solv);

  POOL_DEBUG(SOLV_DEBUG_STATS, "final solver statistics: %d problems, %d learned rules, %d unsolvable\n", solv->problems.count / 2, solv->stats_learned, solv->stats_unsolvable);
  POOL_DEBUG(SOLV_DEBUG_STATS, "solver_solve took %d ms\n", solv_timems(solve_start));

  /* return number of problems */
  return solv->problems.count ? solv->problems.count / 2 : 0;
}

Transaction *
solver_create_transaction(Solver *solv)
{
  return transaction_create_decisionq(solv->pool, &solv->decisionq, &solv->multiversion);
}

void solver_get_orphaned(Solver *solv, Queue *orphanedq)
{
  queue_free(orphanedq);
  queue_init_clone(orphanedq, &solv->orphaned);
}

void solver_get_recommendations(Solver *solv, Queue *recommendationsq, Queue *suggestionsq, int noselected)
{
  Pool *pool = solv->pool;
  Queue redoq, disabledq;
  int goterase, i;
  Solvable *s;
  Rule *r;
  Map obsmap;

  if (!recommendationsq && !suggestionsq)
    return;

  map_init(&obsmap, pool->nsolvables);
  if (solv->installed)
    {
      Id obs, *obsp, p, po, ppo;
      for (p = solv->installed->start; p < solv->installed->end; p++)
	{
	  s = pool->solvables + p;
	  if (s->repo != solv->installed || !s->obsoletes)
	    continue;
	  if (solv->decisionmap[p] <= 0)
	    continue;
	  if (solv->multiversion.size && MAPTST(&solv->multiversion, p))
	    continue;
	  obsp = s->repo->idarraydata + s->obsoletes;
	  /* foreach obsoletes */
	  while ((obs = *obsp++) != 0)
	    FOR_PROVIDES(po, ppo, obs)
	      MAPSET(&obsmap, po);
	}
    }

  queue_init(&redoq);
  queue_init(&disabledq);
  goterase = 0;
  /* disable all erase jobs (including weak "keep uninstalled" rules) */
  for (i = solv->jobrules, r = solv->rules + i; i < solv->jobrules_end; i++, r++)
    {
      if (r->d < 0)	/* disabled ? */
	continue;
      if (r->p >= 0)	/* install job? */
	continue;
      queue_push(&disabledq, i);
      solver_disablerule(solv, r);
      goterase++;
    }

  if (goterase)
    {
      enabledisablelearntrules(solv);
      removedisabledconflicts(solv, &redoq);
    }

  /*
   * find recommended packages
   */
  if (recommendationsq)
    {
      Id rec, *recp, p, pp;

      queue_empty(recommendationsq);
      /* create map of all recommened packages */
      solv->recommends_index = -1;
      MAPZERO(&solv->recommendsmap);

      /* put all packages the solver already chose in the map */
      if (solv->decisioncnt_weak)
	{
	  for (i = solv->decisioncnt_weak; i < solv->decisioncnt_orphan; i++)
	    {
	      Id why;
	      why = solv->decisionq_why.elements[i];
	      if (why)
		continue;	/* forced by unit rule or dep resolving */
	      p = solv->decisionq.elements[i];
	      if (p < 0)
		continue;
	      MAPSET(&solv->recommendsmap, p);
	    }
	}

      for (i = 0; i < solv->decisionq.count; i++)
	{
	  p = solv->decisionq.elements[i];
	  if (p < 0)
	    continue;
	  s = pool->solvables + p;
	  if (s->recommends)
	    {
	      recp = s->repo->idarraydata + s->recommends;
	      while ((rec = *recp++) != 0)
		{
#ifdef ENABLE_COMPLEX_DEPS
		  if (pool_is_complex_dep(pool, rec))
		    {
		      do_complex_recommendations(solv, rec, &solv->recommendsmap, noselected);
		      continue;
		    }
#endif
		  FOR_PROVIDES(p, pp, rec)
		    if (solv->decisionmap[p] > 0)
		      break;
		  if (p)
		    {
		      if (!noselected)
			{
			  FOR_PROVIDES(p, pp, rec)
			    if (solv->decisionmap[p] > 0)
			      MAPSET(&solv->recommendsmap, p);
			}
		      continue;	/* p != 0: already fulfilled */
		    }
		  FOR_PROVIDES(p, pp, rec)
		    MAPSET(&solv->recommendsmap, p);
		}
	    }
	}
      for (i = 1; i < pool->nsolvables; i++)
	{
	  if (solv->decisionmap[i] < 0)
	    continue;
	  if (solv->decisionmap[i] > 0 && noselected)
	    continue;
          if (MAPTST(&obsmap, i))
	    continue;
	  s = pool->solvables + i;
	  if (!MAPTST(&solv->recommendsmap, i))
	    {
	      if (!s->supplements)
		continue;
	      if (!pool_installable(pool, s))
		continue;
	      if (!solver_is_supplementing(solv, s))
		continue;
	    }
	  queue_push(recommendationsq, i);
	}
      /* we use MODE_SUGGEST here so that repo prio is ignored */
      policy_filter_unwanted(solv, recommendationsq, POLICY_MODE_SUGGEST);
    }

  /*
   * find suggested packages
   */

  if (suggestionsq)
    {
      Id sug, *sugp, p, pp;

      queue_empty(suggestionsq);
      /* create map of all suggests that are still open */
      solv->recommends_index = -1;
      MAPZERO(&solv->suggestsmap);
      for (i = 0; i < solv->decisionq.count; i++)
	{
	  p = solv->decisionq.elements[i];
	  if (p < 0)
	    continue;
	  s = pool->solvables + p;
	  if (s->suggests)
	    {
	      sugp = s->repo->idarraydata + s->suggests;
	      while ((sug = *sugp++) != 0)
		{
#ifdef ENABLE_COMPLEX_DEPS
		  if (pool_is_complex_dep(pool, sug))
		    {
		      do_complex_recommendations(solv, sug, &solv->suggestsmap, noselected);
		      continue;
		    }
#endif
		  FOR_PROVIDES(p, pp, sug)
		    if (solv->decisionmap[p] > 0)
		      break;
		  if (p)
		    {
		      if (!noselected)
			{
			  FOR_PROVIDES(p, pp, sug)
			    if (solv->decisionmap[p] > 0)
			      MAPSET(&solv->suggestsmap, p);
			}
		      continue;	/* already fulfilled */
		    }
		  FOR_PROVIDES(p, pp, sug)
		    MAPSET(&solv->suggestsmap, p);
		}
	    }
	}
      for (i = 1; i < pool->nsolvables; i++)
	{
	  if (solv->decisionmap[i] < 0)
	    continue;
	  if (solv->decisionmap[i] > 0 && noselected)
	    continue;
          if (MAPTST(&obsmap, i))
	    continue;
	  s = pool->solvables + i;
	  if (!MAPTST(&solv->suggestsmap, i))
	    {
	      if (!s->enhances)
		continue;
	      if (!pool_installable(pool, s))
		continue;
	      if (!solver_is_enhancing(solv, s))
		continue;
	    }
	  queue_push(suggestionsq, i);
	}
      policy_filter_unwanted(solv, suggestionsq, POLICY_MODE_SUGGEST);
    }

  /* undo removedisabledconflicts */
  if (redoq.count)
    undo_removedisabledconflicts(solv, &redoq);
  queue_free(&redoq);

  /* undo job rule disabling */
  for (i = 0; i < disabledq.count; i++)
    solver_enablerule(solv, solv->rules + disabledq.elements[i]);
  queue_free(&disabledq);
  map_free(&obsmap);
}


/***********************************************************************/
/* disk usage computations */

/*-------------------------------------------------------------------
 *
 * calculate DU changes
 */

void
solver_calc_duchanges(Solver *solv, DUChanges *mps, int nmps)
{
  Map installedmap;

  solver_create_state_maps(solv, &installedmap, 0);
  pool_calc_duchanges(solv->pool, &installedmap, mps, nmps);
  map_free(&installedmap);
}


/*-------------------------------------------------------------------
 *
 * calculate changes in install size
 */

int
solver_calc_installsizechange(Solver *solv)
{
  Map installedmap;
  int change;

  solver_create_state_maps(solv, &installedmap, 0);
  change = pool_calc_installsizechange(solv->pool, &installedmap);
  map_free(&installedmap);
  return change;
}

void
solver_create_state_maps(Solver *solv, Map *installedmap, Map *conflictsmap)
{
  pool_create_state_maps(solv->pool, &solv->decisionq, installedmap, conflictsmap);
}

void
solver_trivial_installable(Solver *solv, Queue *pkgs, Queue *res)
{
  Pool *pool = solv->pool;
  Map installedmap;
  int i;
  pool_create_state_maps(pool,  &solv->decisionq, &installedmap, 0);
  pool_trivial_installable_multiversionmap(pool, &installedmap, pkgs, res, solv->multiversion.size ? &solv->multiversion : 0);
  for (i = 0; i < res->count; i++)
    if (res->elements[i] != -1)
      {
	Solvable *s = pool->solvables + pkgs->elements[i];
	if (!strncmp("patch:", pool_id2str(pool, s->name), 6) && solvable_is_irrelevant_patch(s, &installedmap))
	  res->elements[i] = -1;
      }
  map_free(&installedmap);
}

/*-------------------------------------------------------------------
 *
 * decision introspection
 */

int
solver_get_decisionlevel(Solver *solv, Id p)
{
  return solv->decisionmap[p];
}

void
solver_get_decisionqueue(Solver *solv, Queue *decisionq)
{
  queue_free(decisionq);
  queue_init_clone(decisionq, &solv->decisionq);
}

int
solver_get_lastdecisionblocklevel(Solver *solv)
{
  Id p;
  if (solv->decisionq.count == 0)
    return 0;
  p = solv->decisionq.elements[solv->decisionq.count - 1];
  if (p < 0)
    p = -p;
  return solv->decisionmap[p] < 0 ? -solv->decisionmap[p] : solv->decisionmap[p];
}

void
solver_get_decisionblock(Solver *solv, int level, Queue *decisionq)
{
  Id p;
  int i;

  queue_empty(decisionq);
  for (i = 0; i < solv->decisionq.count; i++)
    {
      p = solv->decisionq.elements[i];
      if (p < 0)
	p = -p;
      if (solv->decisionmap[p] == level || solv->decisionmap[p] == -level)
        break;
    }
  if (i == solv->decisionq.count)
    return;
  for (i = 0; i < solv->decisionq.count; i++)
    {
      p = solv->decisionq.elements[i];
      if (p < 0)
	p = -p;
      if (solv->decisionmap[p] == level || solv->decisionmap[p] == -level)
        queue_push(decisionq, p);
      else
        break;
    }
}

int
solver_describe_decision(Solver *solv, Id p, Id *infop)
{
  int i;
  Id pp, why;

  if (infop)
    *infop = 0;
  if (!solv->decisionmap[p])
    return SOLVER_REASON_UNRELATED;
  pp = solv->decisionmap[p] < 0 ? -p : p;
  for (i = 0; i < solv->decisionq.count; i++)
    if (solv->decisionq.elements[i] == pp)
      break;
  if (i == solv->decisionq.count)	/* just in case... */
    return SOLVER_REASON_UNRELATED;
  why = solv->decisionq_why.elements[i];
  if (infop)
    *infop = why > 0 ? why : -why;
  if (why > 0)
    return SOLVER_REASON_UNIT_RULE;
  why = -why;
  if (i == 0)
    return SOLVER_REASON_KEEP_INSTALLED;	/* the systemsolvable */
  if (i < solv->decisioncnt_update)
    return SOLVER_REASON_RESOLVE_JOB;
  if (i < solv->decisioncnt_keep)
    {
      if (why == 0 && pp < 0)
	return SOLVER_REASON_CLEANDEPS_ERASE;
      return SOLVER_REASON_UPDATE_INSTALLED;
    }
  if (i < solv->decisioncnt_resolve)
    {
      if (solv->focus_installed && i >= solv->decisioncnt_jobs)
	return SOLVER_REASON_RESOLVE_JOB;
      if (why == 0 && pp < 0)
	return SOLVER_REASON_CLEANDEPS_ERASE;
      return SOLVER_REASON_KEEP_INSTALLED;
    }
  if (why > 0)
    return SOLVER_REASON_RESOLVE;
  /* weak or orphaned */
  if (i < solv->decisioncnt_orphan)
    return SOLVER_REASON_WEAKDEP;
  return SOLVER_REASON_RESOLVE_ORPHAN;
}


void
solver_describe_weakdep_decision(Solver *solv, Id p, Queue *whyq)
{
  Pool *pool = solv->pool;
  int i;
  int level = solv->decisionmap[p];
  int decisionno;
  Solvable *s;

  queue_empty(whyq);
  if (level < 0)
    return;	/* huh? */
  for (decisionno = 0; decisionno < solv->decisionq.count; decisionno++)
    if (solv->decisionq.elements[decisionno] == p)
      break;
  if (decisionno == solv->decisionq.count)
    return;	/* huh? */
  if (decisionno < solv->decisioncnt_weak || decisionno >= solv->decisioncnt_orphan)
    return;	/* huh? */

  /* 1) list all packages that recommend us */
  for (i = 1; i < pool->nsolvables; i++)
    {
      Id *recp, rec, pp2, p2;
      if (solv->decisionmap[i] < 0 || solv->decisionmap[i] >= level)
	continue;
      s = pool->solvables + i;
      if (!s->recommends)
	continue;
      if (!solv->addalreadyrecommended && s->repo == solv->installed)
	continue;
      recp = s->repo->idarraydata + s->recommends;
      while ((rec = *recp++) != 0)
	{
	  int found = 0;
	  FOR_PROVIDES(p2, pp2, rec)
	    {
	      if (p2 == p)
		found = 1;
	      else
		{
		  /* if p2 is already installed, this recommends is ignored */
		  if (solv->decisionmap[p2] > 0 && solv->decisionmap[p2] < level)
		    break;
		}
	    }
	  if (!p2 && found)
	    {
	      queue_push(whyq, SOLVER_REASON_RECOMMENDED);
	      queue_push2(whyq, i, rec);
	    }
	}
    }
  /* 2) list all supplements */
  s = pool->solvables + p;
  if (s->supplements && level > 0)
    {
      Id *supp, sup, pp2, p2;
      /* this is a hack. to use solver_dep_fulfilled we temporarily clear
       * everything above our level in the decisionmap */
      for (i = decisionno; i < solv->decisionq.count; i++ )
	{
	  p2 = solv->decisionq.elements[i];
	  if (p2 > 0)
	    solv->decisionmap[p2] = -solv->decisionmap[p2];
	}
      supp = s->repo->idarraydata + s->supplements;
      while ((sup = *supp++) != 0)
	if (solver_dep_fulfilled(solv, sup))
	  {
	    int found = 0;
	    /* let's see if this is an easy supp */
	    FOR_PROVIDES(p2, pp2, sup)
	      {
		if (!solv->addalreadyrecommended && solv->installed)
		  {
		    if (pool->solvables[p2].repo == solv->installed)
		      continue;
		  }
	        if (solv->decisionmap[p2] > 0 && solv->decisionmap[p2] < level)
		  {
		    queue_push(whyq, SOLVER_REASON_SUPPLEMENTED);
		    queue_push2(whyq, p2, sup);
		    found = 1;
		  }
	      }
	    if (!found)
	      {
		/* hard case, just note dependency with no package */
		queue_push(whyq, SOLVER_REASON_SUPPLEMENTED);
	        queue_push2(whyq, 0, sup);
	      }
	  }
      for (i = decisionno; i < solv->decisionq.count; i++)
	{
	  p2 = solv->decisionq.elements[i];
	  if (p2 > 0)
	    solv->decisionmap[p2] = -solv->decisionmap[p2];
	}
    }
}

void
pool_job2solvables(Pool *pool, Queue *pkgs, Id how, Id what)
{
  Id p, pp;
  how &= SOLVER_SELECTMASK;
  queue_empty(pkgs);
  if (how == SOLVER_SOLVABLE_ALL)
    {
      FOR_POOL_SOLVABLES(p)
        queue_push(pkgs, p);
    }
  else if (how == SOLVER_SOLVABLE_REPO)
    {
      Repo *repo = pool_id2repo(pool, what);
      Solvable *s;
      if (repo)
	FOR_REPO_SOLVABLES(repo, p, s)
	  queue_push(pkgs, p);
    }
  else
    {
      FOR_JOB_SELECT(p, pp, how, what)
	queue_push(pkgs, p);
    }
}

int
pool_isemptyupdatejob(Pool *pool, Id how, Id what)
{
  Id p, pp, pi, pip;
  Id select = how & SOLVER_SELECTMASK;
  if ((how & SOLVER_JOBMASK) != SOLVER_UPDATE)
    return 0;
  if (select == SOLVER_SOLVABLE_ALL || select == SOLVER_SOLVABLE_REPO)
    return 0;
  if (!pool->installed)
    return 1;
  FOR_JOB_SELECT(p, pp, select, what)
    if (pool->solvables[p].repo == pool->installed)
      return 0;
  /* hard work */
  FOR_JOB_SELECT(p, pp, select, what)
    {
      Solvable *s = pool->solvables + p;
      FOR_PROVIDES(pi, pip, s->name)
	{
	  Solvable *si = pool->solvables + pi;
	  if (si->repo != pool->installed || si->name != s->name)
	    continue;
	  return 0;
	}
      if (s->obsoletes)
	{
	  Id obs, *obsp = s->repo->idarraydata + s->obsoletes;
	  while ((obs = *obsp++) != 0)
	    {
	      FOR_PROVIDES(pi, pip, obs)
		{
		  Solvable *si = pool->solvables + pi;
		  if (si->repo != pool->installed)
		    continue;
		  if (!pool->obsoleteusesprovides && !pool_match_nevr(pool, si, obs))
		    continue;
		  if (pool->obsoleteusescolors && !pool_colormatch(pool, s, si))
		    continue;
		  return 0;
		}
	    }
	}
    }
  return 1;
}

static int
get_userinstalled_cmp(const void *ap, const void *bp, void *dp)
{
  return *(Id *)ap - *(Id *)bp;
}

static int
get_userinstalled_cmp_names(const void *ap, const void *bp, void *dp)
{
  Pool *pool = dp;
  return strcmp(pool_id2str(pool, *(Id *)ap), pool_id2str(pool, *(Id *)bp));
}

static int
get_userinstalled_cmp_namearch(const void *ap, const void *bp, void *dp)
{
  Pool *pool = dp;
  int r;
  r = strcmp(pool_id2str(pool, ((Id *)ap)[0]), pool_id2str(pool, ((Id *)bp)[0]));
  if (r)
    return r;
  return strcmp(pool_id2str(pool, ((Id *)ap)[1]), pool_id2str(pool, ((Id *)bp)[1]));
}

static void
get_userinstalled_sort_uniq(Pool *pool, Queue *q, int flags)
{
  Id lastp = -1, lasta = -1;
  int i, j;
  if (q->count < ((flags & GET_USERINSTALLED_NAMEARCH) ? 4 : 2))
    return;
  if ((flags & GET_USERINSTALLED_NAMEARCH) != 0)
    solv_sort(q->elements, q->count / 2, 2 * sizeof(Id), get_userinstalled_cmp_namearch, pool);
  else if ((flags & GET_USERINSTALLED_NAMES) != 0)
    solv_sort(q->elements, q->count, sizeof(Id), get_userinstalled_cmp_names, pool);
  else
    solv_sort(q->elements, q->count, sizeof(Id), get_userinstalled_cmp, 0);
  if ((flags & GET_USERINSTALLED_NAMEARCH) != 0)
    {
      for (i = j = 0; i < q->count; i += 2)
	if (q->elements[i] != lastp || q->elements[i + 1] != lasta)
	  {
	    q->elements[j++] = lastp = q->elements[i];
	    q->elements[j++] = lasta = q->elements[i + 1];
	  }
    }
  else
    {
      for (i = j = 0; i < q->count; i++)
	if (q->elements[i] != lastp)
	  q->elements[j++] = lastp = q->elements[i];
    }
  queue_truncate(q, j);
}

static void
namearch2solvables(Pool *pool, Queue *q, Queue *qout, int job)
{
  int i;
  if (!pool->installed)
    return;
  for (i = 0; i < q->count; i += 2)
    {
      Id p, pp, name = q->elements[i], arch = q->elements[i + 1];
      FOR_PROVIDES(p, pp, name)
	{
	  Solvable *s = pool->solvables + p;
	  if (s->repo != pool->installed || s->name != name || (arch && s->arch != arch))
	    continue;
	  if (job)
	    queue_push(qout, job);
	  queue_push(qout, p);
	}
    }
}

void
solver_get_userinstalled(Solver *solv, Queue *q, int flags)
{
  Pool *pool = solv->pool;
  Id p, p2, pp;
  Solvable *s;
  Repo *installed = solv->installed;
  int i, j;
  Map userinstalled;
  
  map_init(&userinstalled, 0);
  queue_empty(q);
  /* first process jobs */
  for (i = 0; i < solv->job.count; i += 2)
    {
      Id how = solv->job.elements[i];
      Id what, select;
      if (installed && (how & SOLVER_JOBMASK) == SOLVER_USERINSTALLED)
	{
	  if (!userinstalled.size)
	    map_grow(&userinstalled, installed->end - installed->start);
	  what = solv->job.elements[i + 1];
	  select = how & SOLVER_SELECTMASK;
	  if (select == SOLVER_SOLVABLE_ALL || (select == SOLVER_SOLVABLE_REPO && what == installed->repoid))
	    FOR_REPO_SOLVABLES(installed, p, s)
	      MAPSET(&userinstalled, p - installed->start);
	  FOR_JOB_SELECT(p, pp, select, what)
	    if (pool->solvables[p].repo == installed)
	      MAPSET(&userinstalled, p - installed->start);
	  continue;
	}
      if ((how & SOLVER_JOBMASK) != SOLVER_INSTALL)
	continue;
      if ((how & SOLVER_NOTBYUSER) != 0)
	continue;
      what = solv->job.elements[i + 1];
      select = how & SOLVER_SELECTMASK;
      FOR_JOB_SELECT(p, pp, select, what)
        if (solv->decisionmap[p] > 0)
	  {
	    queue_push(q, p);
#ifdef ENABLE_LINKED_PKGS
	    if (has_package_link(pool, pool->solvables + p))
	      {
		int j;
		Queue lq;
		queue_init(&lq);
		find_package_link(pool, pool->solvables + p, 0, &lq, 0, 0);
		for (j = 0; j < lq.count; j++)
		  if (solv->decisionmap[lq.elements[j]] > 0)
		    queue_push(q, lq.elements[j]);
	      }
#endif
	  }
    }
  /* now process updates of userinstalled packages */
  if (installed && userinstalled.size)
    {
      for (i = 1; i < solv->decisionq.count; i++)
	{
	  p = solv->decisionq.elements[i];
	  if (p <= 0)
	    continue;
	  s = pool->solvables + p;
	  if (!s->repo)
	    continue;
	  if (s->repo == installed)
	    {
	      if (MAPTST(&userinstalled, p - installed->start))
		queue_push(q, p);
	      continue;
	    }
	  /* new package, check if we replace a userinstalled one */
	  FOR_PROVIDES(p2, pp, s->name)
	    {
	      Solvable *ps = pool->solvables + p2;
	      if (p2 == p || ps->repo != installed || !MAPTST(&userinstalled, p2 - installed->start))
		continue;
	      if (!pool->implicitobsoleteusesprovides && s->name != ps->name)
		continue;
	      if (pool->implicitobsoleteusescolors && !pool_colormatch(pool, s, ps))
		continue;
	      queue_push(q, p);
	      break;
	    }
	  if (!p2 && s->repo != installed && s->obsoletes)
	    {
	      Id obs, *obsp = s->repo->idarraydata + s->obsoletes;
	      while ((obs = *obsp++) != 0)
		{
		  FOR_PROVIDES(p2, pp, obs)
		    {
		      Solvable *ps = pool->solvables + p2;
		      if (p2 == p || ps->repo != installed || !MAPTST(&userinstalled, p2 - installed->start))
			continue;
		      if (!pool->obsoleteusesprovides && !pool_match_nevr(pool, ps, obs))
			continue;
		      if (pool->obsoleteusescolors && !pool_colormatch(pool, s, ps)) 
			continue;
		      queue_push(q, p); 
		      break;
		    }
		  if (p2)
		    break;
		}
	    }
	}
    }
  map_free(&userinstalled);

  /* convert to desired output format */
  if ((flags & GET_USERINSTALLED_NAMEARCH) != 0)
    {
      int qcount = q->count;
      queue_insertn(q, 0, qcount, 0);
      for (i = j = 0; i < qcount; i++)
	{
	  s = pool->solvables + q->elements[i + qcount];
	  q->elements[j++] = s->name;
	  q->elements[j++] = s->arch;
	}
    }
  else if ((flags & GET_USERINSTALLED_NAMES) != 0)
    {
      for (i = 0; i < q->count; i++)
	{
	  s = pool->solvables + q->elements[i];
	  q->elements[i] = s->name;
	}
    }
  /* sort and unify */
  get_userinstalled_sort_uniq(pool, q, flags);

  /* invert if asked for */
  if ((flags & GET_USERINSTALLED_INVERTED) != 0)
    {
      /* first generate queue with all installed packages */
      Queue invq;
      queue_init(&invq);
      for (i = 1; i < solv->decisionq.count; i++)
	{
	  p = solv->decisionq.elements[i];
	  if (p <= 0)
	    continue;
	  s = pool->solvables + p;
	  if (!s->repo)
	    continue;
	  if ((flags & GET_USERINSTALLED_NAMEARCH) != 0)
	    queue_push2(&invq, s->name, s->arch);
	  else if ((flags & GET_USERINSTALLED_NAMES) != 0)
	    queue_push(&invq, s->name);
	  else
	    queue_push(&invq, p);
	}
      /* push q on invq, just in case... */
      queue_insertn(&invq, invq.count, q->count, q->elements);
      get_userinstalled_sort_uniq(pool, &invq, flags);
      /* subtract queues (easy as they are sorted and invq is a superset of q) */
      if ((flags & GET_USERINSTALLED_NAMEARCH) != 0)
	{
	  if (q->count)
	    {
	      for (i = j = 0; i < invq.count; i += 2)
		if (invq.elements[i] == q->elements[j] && invq.elements[i + 1] == q->elements[j + 1])
		  {
		    invq.elements[i] = invq.elements[i + 1] = 0;
		    j += 2;
		    if (j >= q->count)
		      break;
		  }
	      queue_empty(q);
	    }
	  for (i = 0; i < invq.count; i += 2)
	    if (invq.elements[i])
	      queue_push2(q, invq.elements[i], invq.elements[i + 1]);
	}
      else
	{
	  if (q->count)
	    {
	      for (i = j = 0; i < invq.count; i++)
		if (invq.elements[i] == q->elements[j])
		  {
		    invq.elements[i] = 0;
		    if (++j >= q->count)
		      break;
		  }
	      queue_empty(q);
	    }
	  for (i = 0; i < invq.count; i++)
	    if (invq.elements[i])
	      queue_push(q, invq.elements[i]);
	}
      queue_free(&invq);
    }
}

void
pool_add_userinstalled_jobs(Pool *pool, Queue *q, Queue *job, int flags)
{
  int i;

  if ((flags & GET_USERINSTALLED_INVERTED) != 0)
    {
      Queue invq;
      Id p, lastid;
      Solvable *s;
      int bad;
      if (!pool->installed)
	return;
      queue_init(&invq);
      if ((flags & GET_USERINSTALLED_NAMEARCH) != 0)
	flags &= ~GET_USERINSTALLED_NAMES;	/* just in case */
      FOR_REPO_SOLVABLES(pool->installed, p, s)
	queue_push(&invq, flags & GET_USERINSTALLED_NAMES ? s->name : p);
      if ((flags & GET_USERINSTALLED_NAMEARCH) != 0)
	{
	  /* for namearch we convert to packages */
	  namearch2solvables(pool, q, &invq, 0);
	  get_userinstalled_sort_uniq(pool, &invq, flags);
	  namearch2solvables(pool, q, &invq, 0);
	  flags = 0;
	}
      else
	{
	  queue_insertn(&invq, invq.count, q->count, q->elements);
	  get_userinstalled_sort_uniq(pool, &invq, flags);
	  /* now the fun part, add q again, sort, and remove all dups */
	  queue_insertn(&invq, invq.count, q->count, q->elements);
	}
      if (invq.count > 1)
	{
	  if ((flags & GET_USERINSTALLED_NAMES) != 0)
	    solv_sort(invq.elements, invq.count, sizeof(Id), get_userinstalled_cmp_names, pool);
	  else
	    solv_sort(invq.elements, invq.count, sizeof(Id), get_userinstalled_cmp, 0);
	}
      lastid = -1;
      bad = 1;
      for (i = 0; i < invq.count; i++)
	{
	  if (invq.elements[i] == lastid)
	    {
	      bad = 1;
	      continue;
	    }
	  if (!bad)
	    queue_push2(job, SOLVER_USERINSTALLED | (flags & GET_USERINSTALLED_NAMES ? SOLVER_SOLVABLE_NAME : SOLVER_SOLVABLE), lastid);
	  bad = 0;
	  lastid = invq.elements[i];
	}
      if (!bad)
	queue_push2(job, SOLVER_USERINSTALLED | (flags & GET_USERINSTALLED_NAMES ? SOLVER_SOLVABLE_NAME : SOLVER_SOLVABLE), lastid);
      queue_free(&invq);
    }
  else
    {
      if (flags & GET_USERINSTALLED_NAMEARCH)
	namearch2solvables(pool, q, job, SOLVER_USERINSTALLED | SOLVER_SOLVABLE);
      else
	{
	  for (i = 0; i < q->count; i++)
	    queue_push2(job, SOLVER_USERINSTALLED | (flags & GET_USERINSTALLED_NAMES ? SOLVER_SOLVABLE_NAME : SOLVER_SOLVABLE), q->elements[i]);
	}
    }
}

int
solver_alternatives_count(Solver *solv)
{
  Id *elements = solv->branches.elements;
  int res, count;
  for (res = 0, count = solv->branches.count; count; res++)
    count -= elements[count - 2];
  return res;
}

int
solver_get_alternative(Solver *solv, Id alternative, Id *idp, Id *fromp, Id *chosenp, Queue *choices, int *levelp)
{
  int cnt = solver_alternatives_count(solv);
  int count = solv->branches.count;
  Id *elements = solv->branches.elements;
  if (choices)
    queue_empty(choices);
  if (alternative <= 0 || alternative > cnt)
    return 0;
  elements += count;
  for (; cnt > alternative; cnt--)
    elements -= elements[-2];
  if (levelp)
    *levelp = elements[-1];
  if (fromp)
    *fromp = elements[-4];
  if (idp)
    *idp = elements[-3];
  if (chosenp)
    {
      int i;
      *chosenp = 0;
      for (i = elements[-2]; i > 4; i--)
	{
	  Id p = -elements[-i];
	  if (p > 0 && solv->decisionmap[p] == elements[-1] + 1)
	    {
	      *chosenp = p;
	      break;
	    }
	}
    }
  if (choices)
    queue_insertn(choices, 0, elements[-2] - 4, elements - elements[-2]);
  return elements[-4] ? SOLVER_ALTERNATIVE_TYPE_RECOMMENDS : SOLVER_ALTERNATIVE_TYPE_RULE;
}

const char *
solver_select2str(Pool *pool, Id select, Id what)
{
  const char *s;
  char *b;
  select &= SOLVER_SELECTMASK;
  if (select == SOLVER_SOLVABLE)
    return pool_solvid2str(pool, what);
  if (select == SOLVER_SOLVABLE_NAME)
    return pool_dep2str(pool, what);
  if (select == SOLVER_SOLVABLE_PROVIDES)
    {
      s = pool_dep2str(pool, what);
      b = pool_alloctmpspace(pool, 11 + strlen(s));
      sprintf(b, "providing %s", s);
      return b;
    }
  if (select == SOLVER_SOLVABLE_ONE_OF)
    {
      Id p;
      b = 0;
      while ((p = pool->whatprovidesdata[what++]) != 0)
	{
	  s = pool_solvid2str(pool, p);
	  if (b)
	    b = pool_tmpappend(pool, b, ", ", s);
	  else
	    b = pool_tmpjoin(pool, s, 0, 0);
	  pool_freetmpspace(pool, s);
	}
      return b ? b : "nothing";
    }
  if (select == SOLVER_SOLVABLE_REPO)
    {
      b = pool_alloctmpspace(pool, 20);
      sprintf(b, "repo #%d", what);
      return b;
    }
  if (select == SOLVER_SOLVABLE_ALL)
    return "all packages";
  return "unknown job select";
}

const char *
pool_job2str(Pool *pool, Id how, Id what, Id flagmask)
{
  Id select = how & SOLVER_SELECTMASK;
  const char *strstart = 0, *strend = 0;
  char *s;
  int o;

  switch (how & SOLVER_JOBMASK)
    {
    case SOLVER_NOOP:
      return "do nothing";
    case SOLVER_INSTALL:
      if (select == SOLVER_SOLVABLE && pool->installed && pool->solvables[what].repo == pool->installed)
	strstart = "keep ", strend = " installed";
      else if (select == SOLVER_SOLVABLE || select == SOLVER_SOLVABLE_NAME)
	strstart = "install ";
      else if (select == SOLVER_SOLVABLE_PROVIDES)
	strstart = "install a package ";
      else
	strstart = "install one of ";
      break;
    case SOLVER_ERASE:
      if (select == SOLVER_SOLVABLE && !(pool->installed && pool->solvables[what].repo == pool->installed))
	strstart = "keep ", strend = " uninstalled";
      else if (select == SOLVER_SOLVABLE_PROVIDES)
	strstart = "deinstall all packages ";
      else
	strstart = "deinstall ";
      break;
    case SOLVER_UPDATE:
      strstart = "update ";
      break;
    case SOLVER_WEAKENDEPS:
      strstart = "weaken deps of ";
      break;
    case SOLVER_MULTIVERSION:
      strstart = "multi version ";
      break;
    case SOLVER_LOCK:
      strstart = "lock ";
      break;
    case SOLVER_DISTUPGRADE:
      strstart = "dist upgrade ";
      break;
    case SOLVER_VERIFY:
      strstart = "verify ";
      break;
    case SOLVER_DROP_ORPHANED:
      strstart = "deinstall ", strend = " if orphaned";
      break;
    case SOLVER_USERINSTALLED:
      strstart = "regard ", strend = " as userinstalled";
      break;
    default:
      strstart = "unknown job ";
      break;
    }
  s = pool_tmpjoin(pool, strstart, solver_select2str(pool, select, what), strend);
  how &= flagmask;
  if ((how & ~(SOLVER_SELECTMASK|SOLVER_JOBMASK)) == 0)
    return s;
  o = strlen(s);
  s = pool_tmpappend(pool, s, " ", 0);
  if (how & SOLVER_WEAK)
    s = pool_tmpappend(pool, s, ",weak", 0);
  if (how & SOLVER_ESSENTIAL)
    s = pool_tmpappend(pool, s, ",essential", 0);
  if (how & SOLVER_CLEANDEPS)
    s = pool_tmpappend(pool, s, ",cleandeps", 0);
  if (how & SOLVER_ORUPDATE)
    s = pool_tmpappend(pool, s, ",orupdate", 0);
  if (how & SOLVER_FORCEBEST)
    s = pool_tmpappend(pool, s, ",forcebest", 0);
  if (how & SOLVER_TARGETED)
    s = pool_tmpappend(pool, s, ",targeted", 0);
  if (how & SOLVER_SETEV)
    s = pool_tmpappend(pool, s, ",setev", 0);
  if (how & SOLVER_SETEVR)
    s = pool_tmpappend(pool, s, ",setevr", 0);
  if (how & SOLVER_SETARCH)
    s = pool_tmpappend(pool, s, ",setarch", 0);
  if (how & SOLVER_SETVENDOR)
    s = pool_tmpappend(pool, s, ",setvendor", 0);
  if (how & SOLVER_SETREPO)
    s = pool_tmpappend(pool, s, ",setrepo", 0);
  if (how & SOLVER_SETNAME)
    s = pool_tmpappend(pool, s, ",setname", 0);
  if (how & SOLVER_NOAUTOSET)
    s = pool_tmpappend(pool, s, ",noautoset", 0);
  if (s[o + 1] != ',')
    s = pool_tmpappend(pool, s, ",?", 0);
  s[o + 1] = '[';
  return pool_tmpappend(pool, s, "]", 0);
}

const char *
solver_alternative2str(Solver *solv, int type, Id id, Id from)
{
  Pool *pool = solv->pool;
  if (type == SOLVER_ALTERNATIVE_TYPE_RECOMMENDS)
    {
      const char *s = pool_dep2str(pool, id);
      return pool_tmpappend(pool, s, ", recommended by ", pool_solvid2str(pool, from));
    }
  if (type == SOLVER_ALTERNATIVE_TYPE_RULE)
    {
      int rtype;
      Id depfrom, depto, dep;
      char buf[64];
      if (solver_ruleclass(solv, id) == SOLVER_RULE_CHOICE)
	id = solver_rule2pkgrule(solv, id);
      rtype = solver_ruleinfo(solv, id, &depfrom, &depto, &dep);
      if ((rtype & SOLVER_RULE_TYPEMASK) == SOLVER_RULE_JOB)
	{
	  if ((depto & SOLVER_SELECTMASK) == SOLVER_SOLVABLE_PROVIDES)
	    return pool_dep2str(pool, dep);
	  return solver_select2str(pool, depto & SOLVER_SELECTMASK, dep);
	}
      if (rtype == SOLVER_RULE_PKG_REQUIRES)
	{
	  const char *s = pool_dep2str(pool, dep);
	  return pool_tmpappend(pool, s, ", required by ", pool_solvid2str(pool, depfrom));
	}
      sprintf(buf, "Rule #%d", id);
      return pool_tmpjoin(pool, buf, 0, 0);
    }
  return "unknown alternative type";
}

