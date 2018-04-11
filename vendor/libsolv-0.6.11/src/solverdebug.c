/*
 * Copyright (c) 2008, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * solverdebug.c
 *
 * debug functions for the SAT solver
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <assert.h>

#include "solver.h"
#include "solver_private.h"
#include "solverdebug.h"
#include "bitmap.h"
#include "pool.h"
#include "poolarch.h"
#include "util.h"
#include "evr.h"
#include "policy.h"


void
solver_printruleelement(Solver *solv, int type, Rule *r, Id v)
{
  Pool *pool = solv->pool;
  Solvable *s;
  if (v < 0)
    {
      s = pool->solvables + -v;
      POOL_DEBUG(type, "    !%s [%d]", pool_solvable2str(pool, s), -v);
    }
  else
    {
      s = pool->solvables + v;
      POOL_DEBUG(type, "    %s [%d]", pool_solvable2str(pool, s), v);
    }
  if (pool->installed && s->repo == pool->installed)
    POOL_DEBUG(type, "I");
  if (r)
    {
      if (r->w1 == v)
	POOL_DEBUG(type, " (w1)");
      if (r->w2 == v)
	POOL_DEBUG(type, " (w2)");
    }
  if (solv->decisionmap[s - pool->solvables] > 0)
    POOL_DEBUG(type, " Install.level%d", solv->decisionmap[s - pool->solvables]);
  if (solv->decisionmap[s - pool->solvables] < 0)
    POOL_DEBUG(type, " Conflict.level%d", -solv->decisionmap[s - pool->solvables]);
  POOL_DEBUG(type, "\n");
}


/*
 * print rule
 */

void
solver_printrule(Solver *solv, int type, Rule *r)
{
  Pool *pool = solv->pool;
  int i;
  Id d, v;

  if (r >= solv->rules && r < solv->rules + solv->nrules)   /* r is a solver rule */
    POOL_DEBUG(type, "Rule #%d:", (int)(r - solv->rules));
  else
    POOL_DEBUG(type, "Rule:");		       /* r is any rule */
  if (r->d < 0)
    POOL_DEBUG(type, " (disabled)");
  POOL_DEBUG(type, "\n");
  d = r->d < 0 ? -r->d - 1 : r->d;
  for (i = 0; ; i++)
    {
      if (i == 0)
	  /* print direct literal */
	v = r->p;
      else if (!d)
	{
	  if (i == 2)
	    break;
	  /* binary rule --> print w2 as second literal */
	  v = r->w2;
	}
      else
	  /* every other which is in d */
	v = solv->pool->whatprovidesdata[d + i - 1];
      if (v == ID_NULL)
	break;
      solver_printruleelement(solv, type, r, v);
    }
  POOL_DEBUG(type, "    next rules: %d %d\n", r->n1, r->n2);
}

void
solver_printruleclass(Solver *solv, int type, Rule *r)
{
  Pool *pool = solv->pool;
  Id p = r - solv->rules;
  assert(p >= 0);
  if (p < solv->learntrules)
    if (solv->weakrulemap.size && MAPTST(&solv->weakrulemap, p))
      POOL_DEBUG(type, "WEAK ");
  if (solv->learntrules && p >= solv->learntrules)
    POOL_DEBUG(type, "LEARNT ");
  else if (p >= solv->bestrules && p < solv->bestrules_end)
    POOL_DEBUG(type, "BEST ");
  else if (p >= solv->choicerules && p < solv->choicerules_end)
    POOL_DEBUG(type, "CHOICE ");
  else if (p >= solv->infarchrules && p < solv->infarchrules_end)
    POOL_DEBUG(type, "INFARCH ");
  else if (p >= solv->duprules && p < solv->duprules_end)
    POOL_DEBUG(type, "DUP ");
  else if (p >= solv->jobrules && p < solv->jobrules_end)
    POOL_DEBUG(type, "JOB ");
  else if (p >= solv->updaterules && p < solv->updaterules_end)
    POOL_DEBUG(type, "UPDATE ");
  else if (p >= solv->featurerules && p < solv->featurerules_end)
    POOL_DEBUG(type, "FEATURE ");
  else if (p >= solv->yumobsrules && p < solv->yumobsrules_end)
    POOL_DEBUG(type, "YUMOBS ");
  solver_printrule(solv, type, r);
}

void
solver_printproblem(Solver *solv, Id v)
{
  Pool *pool = solv->pool;
  int i;
  Rule *r;
  Id *jp;

  if (v > 0)
    solver_printruleclass(solv, SOLV_DEBUG_SOLUTIONS, solv->rules + v);
  else
    {
      v = -(v + 1);
      POOL_DEBUG(SOLV_DEBUG_SOLUTIONS, "JOB %d\n", v);
      jp = solv->ruletojob.elements;
      for (i = solv->jobrules, r = solv->rules + i; i < solv->jobrules_end; i++, r++, jp++)
	if (*jp == v)
	  {
	    POOL_DEBUG(SOLV_DEBUG_SOLUTIONS, "- ");
	    solver_printrule(solv, SOLV_DEBUG_SOLUTIONS, r);
	  }
      POOL_DEBUG(SOLV_DEBUG_SOLUTIONS, "ENDJOB\n");
    }
}

void
solver_printwatches(Solver *solv, int type)
{
  Pool *pool = solv->pool;
  int counter;

  POOL_DEBUG(type, "Watches: \n");
  for (counter = -(pool->nsolvables - 1); counter < pool->nsolvables; counter++)
    POOL_DEBUG(type, "    solvable [%d] -- rule [%d]\n", counter, solv->watches[counter + pool->nsolvables]);
}

void
solver_printdecisionq(Solver *solv, int type)
{
  Pool *pool = solv->pool;
  int i;
  Id p, why;

  POOL_DEBUG(type, "Decisions:\n");
  for (i = 0; i < solv->decisionq.count; i++)
    {
      p = solv->decisionq.elements[i];
      if (p > 0)
        POOL_DEBUG(type, "%d %d install  %s, ", i, solv->decisionmap[p], pool_solvid2str(pool, p));
      else
        POOL_DEBUG(type, "%d %d conflict %s, ", i, -solv->decisionmap[-p], pool_solvid2str(pool, -p));
      why = solv->decisionq_why.elements[i];
      if (why > 0)
	{
	  POOL_DEBUG(type, "forced by ");
	  solver_printruleclass(solv, type, solv->rules + why);
	}
      else if (why < 0)
	{
	  POOL_DEBUG(type, "chosen from ");
	  solver_printruleclass(solv, type, solv->rules - why);
	}
      else
        POOL_DEBUG(type, "picked for some unknown reason.\n");
    }
}

/*
 * printdecisions
 */

void
solver_printdecisions(Solver *solv)
{
  Pool *pool = solv->pool;
  Repo *installed = solv->installed;
  Transaction *trans = solver_create_transaction(solv);
  Id p, type;
  int i, j;
  Solvable *s;
  Queue iq;
  Queue recommendations;
  Queue suggestions;
  Queue orphaned;

  POOL_DEBUG(SOLV_DEBUG_RESULT, "\n");
  POOL_DEBUG(SOLV_DEBUG_RESULT, "transaction:\n");

  queue_init(&iq);
  for (i = 0; i < trans->steps.count; i++)
    {
      p = trans->steps.elements[i];
      s = pool->solvables + p;
      type = transaction_type(trans, p, SOLVER_TRANSACTION_SHOW_ACTIVE|SOLVER_TRANSACTION_SHOW_ALL|SOLVER_TRANSACTION_SHOW_OBSOLETES|SOLVER_TRANSACTION_SHOW_MULTIINSTALL);
      switch(type)
        {
	case SOLVER_TRANSACTION_MULTIINSTALL:
          POOL_DEBUG(SOLV_DEBUG_RESULT, "  multi install %s", pool_solvable2str(pool, s));
	  break;
	case SOLVER_TRANSACTION_MULTIREINSTALL:
          POOL_DEBUG(SOLV_DEBUG_RESULT, "  multi reinstall %s", pool_solvable2str(pool, s));
	  break;
	case SOLVER_TRANSACTION_INSTALL:
          POOL_DEBUG(SOLV_DEBUG_RESULT, "  install   %s", pool_solvable2str(pool, s));
	  break;
	case SOLVER_TRANSACTION_REINSTALL:
          POOL_DEBUG(SOLV_DEBUG_RESULT, "  reinstall %s", pool_solvable2str(pool, s));
	  break;
	case SOLVER_TRANSACTION_DOWNGRADE:
          POOL_DEBUG(SOLV_DEBUG_RESULT, "  downgrade %s", pool_solvable2str(pool, s));
	  break;
	case SOLVER_TRANSACTION_CHANGE:
          POOL_DEBUG(SOLV_DEBUG_RESULT, "  change    %s", pool_solvable2str(pool, s));
	  break;
	case SOLVER_TRANSACTION_UPGRADE:
	case SOLVER_TRANSACTION_OBSOLETES:
          POOL_DEBUG(SOLV_DEBUG_RESULT, "  upgrade   %s", pool_solvable2str(pool, s));
	  break;
	case SOLVER_TRANSACTION_ERASE:
          POOL_DEBUG(SOLV_DEBUG_RESULT, "  erase     %s", pool_solvable2str(pool, s));
	  break;
	default:
	  break;
        }
      switch(type)
        {
	case SOLVER_TRANSACTION_INSTALL:
	case SOLVER_TRANSACTION_ERASE:
	case SOLVER_TRANSACTION_MULTIINSTALL:
	case SOLVER_TRANSACTION_MULTIREINSTALL:
	  POOL_DEBUG(SOLV_DEBUG_RESULT, "\n");
	  break;
	case SOLVER_TRANSACTION_REINSTALL:
	case SOLVER_TRANSACTION_DOWNGRADE:
	case SOLVER_TRANSACTION_CHANGE:
	case SOLVER_TRANSACTION_UPGRADE:
	case SOLVER_TRANSACTION_OBSOLETES:
	  transaction_all_obs_pkgs(trans, p, &iq);
	  if (iq.count)
	    {
	      POOL_DEBUG(SOLV_DEBUG_RESULT, "  (obsoletes");
	      for (j = 0; j < iq.count; j++)
		POOL_DEBUG(SOLV_DEBUG_RESULT, " %s", pool_solvid2str(pool, iq.elements[j]));
	      POOL_DEBUG(SOLV_DEBUG_RESULT, ")");
	    }
	  POOL_DEBUG(SOLV_DEBUG_RESULT, "\n");
	  break;
	default:
	  break;
	}
    }
  queue_free(&iq);

  POOL_DEBUG(SOLV_DEBUG_RESULT, "\n");

  queue_init(&recommendations);
  queue_init(&suggestions);
  queue_init(&orphaned);
  solver_get_recommendations(solv, &recommendations, &suggestions, 0);
  solver_get_orphaned(solv, &orphaned);
  if (recommendations.count)
    {
      POOL_DEBUG(SOLV_DEBUG_RESULT, "recommended packages:\n");
      for (i = 0; i < recommendations.count; i++)
	{
	  s = pool->solvables + recommendations.elements[i];
          if (solv->decisionmap[recommendations.elements[i]] > 0)
	    {
	      if (installed && s->repo == installed)
	        POOL_DEBUG(SOLV_DEBUG_RESULT, "  %s (installed)\n", pool_solvable2str(pool, s));
	      else
	        POOL_DEBUG(SOLV_DEBUG_RESULT, "  %s (selected)\n", pool_solvable2str(pool, s));
	    }
          else
	    POOL_DEBUG(SOLV_DEBUG_RESULT, "  %s\n", pool_solvable2str(pool, s));
	}
      POOL_DEBUG(SOLV_DEBUG_RESULT, "\n");
    }

  if (suggestions.count)
    {
      POOL_DEBUG(SOLV_DEBUG_RESULT, "suggested packages:\n");
      for (i = 0; i < suggestions.count; i++)
	{
	  s = pool->solvables + suggestions.elements[i];
          if (solv->decisionmap[suggestions.elements[i]] > 0)
	    {
	      if (installed && s->repo == installed)
	        POOL_DEBUG(SOLV_DEBUG_RESULT, "  %s (installed)\n", pool_solvable2str(pool, s));
	      else
	        POOL_DEBUG(SOLV_DEBUG_RESULT, "  %s (selected)\n", pool_solvable2str(pool, s));
	    }
	  else
	    POOL_DEBUG(SOLV_DEBUG_RESULT, "  %s\n", pool_solvable2str(pool, s));
	}
      POOL_DEBUG(SOLV_DEBUG_RESULT, "\n");
    }
  if (orphaned.count)
    {
      POOL_DEBUG(SOLV_DEBUG_RESULT, "orphaned packages:\n");
      for (i = 0; i < orphaned.count; i++)
	{
	  s = pool->solvables + orphaned.elements[i];
          if (solv->decisionmap[solv->orphaned.elements[i]] > 0)
	    POOL_DEBUG(SOLV_DEBUG_RESULT, "  %s (kept)\n", pool_solvable2str(pool, s));
	  else
	    POOL_DEBUG(SOLV_DEBUG_RESULT, "  %s (erased)\n", pool_solvable2str(pool, s));
	}
      POOL_DEBUG(SOLV_DEBUG_RESULT, "\n");
    }
  queue_free(&recommendations);
  queue_free(&suggestions);
  queue_free(&orphaned);
  transaction_free(trans);
}

static inline
const char *id2strnone(Pool *pool, Id id)
{
  return !id || id == 1 ? "(none)" : pool_id2str(pool, id);
}

void
transaction_print(Transaction *trans)
{
  Pool *pool = trans->pool;
  Queue classes, pkgs;
  int i, j, mode, l, linel;
  char line[76];
  const char *n;

  queue_init(&classes);
  queue_init(&pkgs);
  mode = SOLVER_TRANSACTION_SHOW_OBSOLETES | SOLVER_TRANSACTION_OBSOLETE_IS_UPGRADE;
  transaction_classify(trans, mode, &classes);
  for (i = 0; i < classes.count; i += 4)
    {
      Id class = classes.elements[i];
      Id cnt = classes.elements[i + 1];
      switch(class)
	{
	case SOLVER_TRANSACTION_ERASE:
	  POOL_DEBUG(SOLV_DEBUG_RESULT, "%d erased packages:\n", cnt);
	  break;
	case SOLVER_TRANSACTION_INSTALL:
	  POOL_DEBUG(SOLV_DEBUG_RESULT, "%d installed packages:\n", cnt);
	  break;
	case SOLVER_TRANSACTION_REINSTALLED:
	  POOL_DEBUG(SOLV_DEBUG_RESULT, "%d reinstalled packages:\n", cnt);
	  break;
	case SOLVER_TRANSACTION_DOWNGRADED:
	  POOL_DEBUG(SOLV_DEBUG_RESULT, "%d downgraded packages:\n", cnt);
	  break;
	case SOLVER_TRANSACTION_CHANGED:
	  POOL_DEBUG(SOLV_DEBUG_RESULT, "%d changed packages:\n", cnt);
	  break;
	case SOLVER_TRANSACTION_UPGRADED:
	  POOL_DEBUG(SOLV_DEBUG_RESULT, "%d upgraded packages:\n", cnt);
	  break;
	case SOLVER_TRANSACTION_VENDORCHANGE:
	  POOL_DEBUG(SOLV_DEBUG_RESULT, "%d vendor changes from '%s' to '%s':\n", cnt, id2strnone(pool, classes.elements[i + 2]), id2strnone(pool, classes.elements[i + 3]));
	  break;
	case SOLVER_TRANSACTION_ARCHCHANGE:
	  POOL_DEBUG(SOLV_DEBUG_RESULT, "%d arch changes from %s to %s:\n", cnt, pool_id2str(pool, classes.elements[i + 2]), pool_id2str(pool, classes.elements[i + 3]));
	  break;
	default:
	  class = SOLVER_TRANSACTION_IGNORE;
	  break;
	}
      if (class == SOLVER_TRANSACTION_IGNORE)
	continue;
      transaction_classify_pkgs(trans, mode, class, classes.elements[i + 2], classes.elements[i + 3], &pkgs);
      *line = 0;
      linel = 0;
      for (j = 0; j < pkgs.count; j++)
	{
	  Id p = pkgs.elements[j];
	  Solvable *s = pool->solvables + p;
	  Solvable *s2;

	  switch(class)
	    {
	    case SOLVER_TRANSACTION_DOWNGRADED:
	    case SOLVER_TRANSACTION_UPGRADED:
	      s2 = pool->solvables + transaction_obs_pkg(trans, p);
	      POOL_DEBUG(SOLV_DEBUG_RESULT, "  - %s -> %s\n", pool_solvable2str(pool, s), pool_solvable2str(pool, s2));
	      break;
	    case SOLVER_TRANSACTION_VENDORCHANGE:
	    case SOLVER_TRANSACTION_ARCHCHANGE:
	      n = pool_id2str(pool, s->name);
	      l = strlen(n);
	      if (l + linel > sizeof(line) - 3)
		{
		  if (*line)
		    POOL_DEBUG(SOLV_DEBUG_RESULT, "    %s\n", line);
		  *line = 0;
		  linel = 0;
		}
	      if (l + linel > sizeof(line) - 3)
	        POOL_DEBUG(SOLV_DEBUG_RESULT, "    %s\n", n);
	      else
		{
		  if (*line)
		    {
		      strcpy(line + linel, ", ");
		      linel += 2;
		    }
		  strcpy(line + linel, n);
		  linel += l;
		}
	      break;
	    default:
	      POOL_DEBUG(SOLV_DEBUG_RESULT, "  - %s\n", pool_solvable2str(pool, s));
	      break;
	    }
	}
      if (*line)
	POOL_DEBUG(SOLV_DEBUG_RESULT, "    %s\n", line);
      POOL_DEBUG(SOLV_DEBUG_RESULT, "\n");
    }
  queue_free(&classes);
  queue_free(&pkgs);
}

void
solver_printproblemruleinfo(Solver *solv, Id probr)
{
  Pool *pool = solv->pool;
  Id dep, source, target;
  SolverRuleinfo type = solver_ruleinfo(solv, probr, &source, &target, &dep);

  POOL_DEBUG(SOLV_DEBUG_RESULT, "%s\n", solver_problemruleinfo2str(solv, type, source, target, dep));
}

void
solver_printprobleminfo(Solver *solv, Id problem)
{
  solver_printproblemruleinfo(solv, solver_findproblemrule(solv, problem));
}

void
solver_printcompleteprobleminfo(Solver *solv, Id problem)
{
  Queue q;
  Id probr;
  int i, nobad = 0;

  queue_init(&q);
  solver_findallproblemrules(solv, problem, &q);
  for (i = 0; i < q.count; i++)
    {
      probr = q.elements[i];
      if (!(probr >= solv->updaterules && probr < solv->updaterules_end) && !(probr >= solv->jobrules && probr < solv->jobrules_end))
	{
	  nobad = 1;
	  break;
	}
    }
  for (i = 0; i < q.count; i++)
    {
      probr = q.elements[i];
      if (nobad && ((probr >= solv->updaterules && probr < solv->updaterules_end) || (probr >= solv->jobrules && probr < solv->jobrules_end)))
	continue;
      solver_printproblemruleinfo(solv, probr);
    }
  queue_free(&q);
}

static int illegals[] = {
  POLICY_ILLEGAL_DOWNGRADE,
  POLICY_ILLEGAL_NAMECHANGE,
  POLICY_ILLEGAL_ARCHCHANGE,
  POLICY_ILLEGAL_VENDORCHANGE,
  0
};

void
solver_printsolution(Solver *solv, Id problem, Id solution)
{
  Pool *pool = solv->pool;
  Id p, rp, element;

  element = 0;
  while ((element = solver_next_solutionelement(solv, problem, solution, element, &p, &rp)) != 0)
    {
      if (p > 0 && rp > 0)
	{
	  /* for replacements we want to know why it was illegal */
	  Solvable *s = pool->solvables + p, *rs = pool->solvables + rp;
	  int illegal = policy_is_illegal(solv, s, rs, 0);
	  if (illegal)
	    {
	      int i;
	      for (i = 0; illegals[i]; i++)
	        if ((illegal & illegals[i]) != 0)
		  {
		    POOL_DEBUG(SOLV_DEBUG_RESULT, "  - allow %s\n", policy_illegal2str(solv, illegals[i], s, rs));
		    illegal ^= illegals[i];
		  }
	      if (!illegal)
	        continue;
	    }
	}
      POOL_DEBUG(SOLV_DEBUG_RESULT, "  - %s\n", solver_solutionelement2str(solv, p, rp));
    }
}

void
solver_printallsolutions(Solver *solv)
{
  Pool *pool = solv->pool;
  int pcnt;
  Id problem, solution;

  POOL_DEBUG(SOLV_DEBUG_RESULT, "Encountered problems! Here are the solutions:\n\n");
  pcnt = 0;
  problem = 0;
  while ((problem = solver_next_problem(solv, problem)) != 0)
    {
      pcnt++;
      POOL_DEBUG(SOLV_DEBUG_RESULT, "Problem %d:\n", pcnt);
      POOL_DEBUG(SOLV_DEBUG_RESULT, "====================================\n");
#if 1
      solver_printprobleminfo(solv, problem);
#else
      solver_printcompleteprobleminfo(solv, problem);
#endif
      POOL_DEBUG(SOLV_DEBUG_RESULT, "\n");
      solution = 0;
      while ((solution = solver_next_solution(solv, problem, solution)) != 0)
        {
	  solver_printsolution(solv, problem, solution);
          POOL_DEBUG(SOLV_DEBUG_RESULT, "\n");
        }
    }
}

void
solver_printtrivial(Solver *solv)
{
  Pool *pool = solv->pool;
  Queue in, out;
  Id p;
  const char *n;
  Solvable *s;
  int i;

  queue_init(&in);
  for (p = 1, s = pool->solvables + p; p < solv->pool->nsolvables; p++, s++)
    {
      n = pool_id2str(pool, s->name);
      if (strncmp(n, "patch:", 6) != 0 && strncmp(n, "pattern:", 8) != 0)
        continue;
      queue_push(&in, p);
    }
  if (!in.count)
    {
      queue_free(&in);
      return;
    }
  queue_init(&out);
  solver_trivial_installable(solv, &in, &out);
  POOL_DEBUG(SOLV_DEBUG_RESULT, "trivial installable status:\n");
  for (i = 0; i < in.count; i++)
    POOL_DEBUG(SOLV_DEBUG_RESULT, "  %s: %d\n", pool_solvid2str(pool, in.elements[i]), out.elements[i]);
  POOL_DEBUG(SOLV_DEBUG_RESULT, "\n");
  queue_free(&in);
  queue_free(&out);
}

