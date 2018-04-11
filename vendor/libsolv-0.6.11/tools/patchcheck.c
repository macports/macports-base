/* vim: sw=2 et
 */

/*
 * Copyright (c) 2009, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <zlib.h>

#include "pool.h"
#include "evr.h"
#include "poolarch.h"
#include "repo_solv.h"
#ifdef ENABLE_SUSEREPO
#include "repo_susetags.h"
#endif
#ifdef ENABLE_RPMMD
#include "repo_updateinfoxml.h"
#include "repo_rpmmd.h"
#endif
#include "solver.h"
#include "solverdebug.h"

#include "solv_xfopen.h"

void
showproblems(Solver *solv, Solvable *s, Queue *cand, Queue *badguys)
{
  Pool *pool = solv->pool;
  Queue rids, rinfo;
  Id problem = 0;
  int jj;
  int rerun = 0;

  queue_init(&rids);
  queue_init(&rinfo);
  printf("can't install %s:\n", pool_solvable2str(pool, s));
  while ((problem = solver_next_problem(solv, problem)) != 0)
    {
      solver_findallproblemrules(solv, problem, &rids);
      for (jj = 0; jj < rids.count; jj++)
	{
	  Id probr = rids.elements[jj];
	  int k, l;

	  queue_empty(&rinfo);
	  solver_allruleinfos(solv, probr, &rinfo);
	  for (k = 0; k < rinfo.count; k += 4)
	    {
	      Id dep, source, target;
	      source = rinfo.elements[k + 1];
	      target = rinfo.elements[k + 2];
	      dep = rinfo.elements[k + 3];
	      switch (rinfo.elements[k])
		{
		case SOLVER_RULE_DISTUPGRADE:
		  break;
		case SOLVER_RULE_INFARCH:
		  printf("  %s has inferior architecture\n", pool_solvid2str(pool, source));
		  break;
		case SOLVER_RULE_UPDATE:
		  printf("  update rule for %s\n", pool_solvid2str(pool, source));
		  if (badguys)
		    queue_pushunique(badguys, source);
		  if (!cand)
		    break;
		  /* only drop update problem packages from cand so that we see all problems of this patch */
		  for (l = 0; l < cand->count; l++)
		    if (cand->elements[l] == source || cand->elements[l] == -source)
		      break;
		  if (l == cand->count)
		    break;
		  if (!rerun)
		    {
		      for (l = 0; l < cand->count; l++)
			if (cand->elements[l] < 0)
			  cand->elements[l] = -cand->elements[l];
		      rerun = 1;
		    }
		  for (l = 0; l < cand->count; l++)
		    if (cand->elements[l] == source)
		      {
			cand->elements[l] = -source;
		      }
		  break;
		case SOLVER_RULE_JOB:
		case SOLVER_RULE_JOB_PROVIDED_BY_SYSTEM:
		case SOLVER_RULE_JOB_UNKNOWN_PACKAGE:
		case SOLVER_RULE_JOB_UNSUPPORTED:
		  break;
		case SOLVER_RULE_RPM:
		  printf("  some dependency problem\n");
		  break;
		case SOLVER_RULE_JOB_NOTHING_PROVIDES_DEP:
		  printf("  nothing provides requested %s\n", pool_dep2str(pool, dep));
		  break;
		case SOLVER_RULE_RPM_NOT_INSTALLABLE:
		  printf("  package %s is not installable\n", pool_solvid2str(pool, source));
		  break;
		case SOLVER_RULE_RPM_NOTHING_PROVIDES_DEP:
		  printf("  nothing provides %s needed by %s\n", pool_dep2str(pool, dep), pool_solvid2str(pool, source));
		  if (ISRELDEP(dep))
		    {
		      Reldep *rd = GETRELDEP(pool, dep);
		      if (!ISRELDEP(rd->name))
			{
			  Id rp, rpp;
			  FOR_PROVIDES(rp, rpp, rd->name)
			    printf("    (we have %s)\n", pool_solvid2str(pool, rp));
			}
		    }
		  break;
		case SOLVER_RULE_RPM_SAME_NAME:
		  printf("  cannot install both %s and %s\n", pool_solvid2str(pool, source), pool_solvid2str(pool, target));
		  break;
		case SOLVER_RULE_RPM_PACKAGE_CONFLICT:
		  printf("  package %s conflicts with %s provided by %s\n", pool_solvid2str(pool, source), pool_dep2str(pool, dep), pool_solvid2str(pool, target));
		  break;
		case SOLVER_RULE_RPM_PACKAGE_OBSOLETES:
		  printf("  package %s obsoletes %s provided by %s\n", pool_solvid2str(pool, source), pool_dep2str(pool, dep), pool_solvid2str(pool, target));
		  break;
		case SOLVER_RULE_RPM_PACKAGE_REQUIRES:
		  printf("  package %s requires %s, but none of the providers can be installed\n", pool_solvid2str(pool, source), pool_dep2str(pool, dep));
		  break;
		case SOLVER_RULE_RPM_SELF_CONFLICT:
		  printf("  package %s conflicts with %s provided by itself\n", pool_solvid2str(pool, source), pool_dep2str(pool, dep));
		  break;
		}
	    }
	}
    }
  queue_free(&rids);
  queue_free(&rinfo);
}

void
toinst(Solver *solv, Repo *repo, Repo *instrepo)
{
  Pool *pool = solv->pool;
  Queue q;
  int k;
  Id p;

  queue_init(&q);
  solver_get_decisionqueue(solv, &q);
  for (k = 0; k < q.count; k++)
    {
      p = q.elements[k];
      if (p < 0 || p == SYSTEMSOLVABLE)
	continue;

     /* printf(" toinstall %s\n", pool_solvid2str(pool, p));*/
      /* oh my! */
      pool->solvables[p].repo = instrepo;
    }
  queue_free(&q);
}

void
dump_instrepo(Repo *instrepo, Pool *pool)
{
  Solvable *s;
  Id p;

  printf("instrepo..\n");
  FOR_REPO_SOLVABLES(instrepo, p, s)
    printf("  %s\n", pool_solvable2str(pool, s));
  printf("done.\n");
}

void
frominst(Solver *solv, Repo *repo, Repo *instrepo)
{
  Pool *pool = solv->pool;
  int k;

  for (k = 1; k < pool->nsolvables; k++)
    if (pool->solvables[k].repo == instrepo)
      pool->solvables[k].repo = repo;
}

void
usage(char** argv)
{

  printf("%s: <arch> <patchnameprefix>  [--install-available] [repos] [--updaterepos] [repos]...\n"
      "\t --install-available: installation repository is available during update\n"
      "\t repos: repository ending in\n"
      "\t\tpackages, packages.gz, primary.xml.gz, updateinfo.xml.gz or .solv\n",
      argv[0]);

  exit(1);
}

typedef struct {
  int updatestart;
  int shown;
  int status;
  int install_available;
  Repo *repo;
  Repo *instrepo;
} context_t;

#define SHOW_PATCH(c) if (!(c)->shown++) printf("%s:\n", pool_solvable2str(pool, s));
#define PERF_DEBUGGING 0
 
static Pool *pool;

void
test_all_old_patches_included(context_t *c, Id pid)
{
  Id p, pp;
  Id con, *conp;
  Solvable *s = pool->solvables + pid;
  /* Test 1: are all old patches included */
  FOR_PROVIDES(p, pp, s->name)
    {
      Solvable *s2 = pool->solvables + p;
      Id con2, *conp2;

      if (!s2->conflicts)
        continue;
      if (pool_evrcmp(pool, s->evr, s2->evr, EVRCMP_COMPARE) <= 0)
        continue;
      conp2 = s2->repo->idarraydata + s2->conflicts;
      while ((con2 = *conp2++) != 0)
        {
          Reldep *rd2, *rd;
          if (!ISRELDEP(con2))
            continue;
          rd2 = GETRELDEP(pool, con2);
          conp = s->repo->idarraydata + s->conflicts;
          while ((con = *conp++) != 0)
            {
              if (!ISRELDEP(con))
                continue;
              rd = GETRELDEP(pool, con);
              if (rd->name == rd2->name)
                break;
            }
          if (!con)
            {
              SHOW_PATCH(c);
              printf("  %s contained %s\n", pool_solvable2str(pool, s2), pool_dep2str(pool, rd2->name));
            }
          else
           {
             if (pool_evrcmp(pool, rd->evr, rd2->evr, EVRCMP_COMPARE) < 0)
               {
                 SHOW_PATCH(c);
                 printf("  %s required newer version %s-%s of %s-%s\n",
                     pool_solvable2str(pool, s2), pool_dep2str(pool, rd2->name), pool_dep2str(pool, rd2->evr),
                     pool_dep2str(pool, rd->name), pool_dep2str(pool, rd->evr));
               }
           }

        }
    }
}

void
test_all_packages_installable(context_t *c, Id pid)
{
  Solver *solv;
  Queue job;
  Id p, pp;
  Id con, *conp;
  unsigned int now, solver_runs;
  int i;
  Solvable *s = pool->solvables + pid;

  queue_init(&job);

  now = solv_timems(0);
  solver_runs = 0;

  conp = s->repo->idarraydata + s->conflicts;
  while ((con = *conp++) != 0)
    {
      FOR_PROVIDES(p, pp, con)
        {
          queue_empty(&job);
          queue_push(&job, SOLVER_INSTALL|SOLVER_SOLVABLE|SOLVER_WEAK);
          queue_push(&job, p);

          /* also set up some minimal system */
          queue_push(&job, SOLVER_INSTALL|SOLVER_SOLVABLE_PROVIDES|SOLVER_WEAK);
          queue_push(&job, pool_str2id(pool, "rpm", 1));
          queue_push(&job, SOLVER_INSTALL|SOLVER_SOLVABLE_PROVIDES|SOLVER_WEAK);
          queue_push(&job, pool_str2id(pool, "aaa_base", 1));

          solv = solver_create(pool);
          /* solver_set_flag(solv, SOLVER_FLAG_IGNORE_RECOMMENDED, 1); */
          ++solver_runs;
          if (solver_solve(solv, &job))
            {
              c->status = 1;
              printf("error installing original package\n");
              showproblems(solv, s, 0, 0);
            }
          toinst(solv, c->repo, c->instrepo);
          solver_free(solv);

#if 0
          dump_instrepo(instrepo, pool);

#endif
          if (!c->install_available)
            {
              queue_empty(&job);
              for (i = 1; i < c->updatestart; i++)
                {
                  if (pool->solvables[i].repo != c->repo || i == pid)
                    continue;
                  queue_push(&job, SOLVER_ERASE|SOLVER_SOLVABLE);
                  queue_push(&job, i);
                }
            }
          queue_push(&job, SOLVER_INSTALL|SOLVER_SOLVABLE);
          queue_push(&job, pid);
          solv = solver_create(pool);
          /* solver_set_flag(solv, SOLVER_FLAG_IGNORE_RECOMMENDED, 1); */
          ++solver_runs;
          if (solver_solve(solv, &job))
            {
              c->status = 1;
              showproblems(solv, s, 0, 0);
            }
          frominst(solv, c->repo, c->instrepo);
          solver_free(solv);
        }
    }

  if (PERF_DEBUGGING)
    printf("  test_all_packages_installable took %d ms in %d runs\n", solv_timems(now), solver_runs);
}

void
test_can_upgrade_all_packages(context_t *c, Id pid)
{
  Solver *solv;
  Id p;
  Id con, *conp;
  Queue job;
  Queue cand;
  Queue badguys;
  int i, j;
  unsigned int now, solver_runs;
  Solvable *s = pool->solvables + pid;

  queue_init(&job);
  queue_init(&cand);
  queue_init(&badguys);

  now = solv_timems(0);
  solver_runs = 0;

  /* Test 3: can we upgrade all packages? */
  for (p = 1; p < pool->nsolvables; p++)
    {
      Solvable *s = pool->solvables + p;
      if (!s->repo)
        continue;
      if (strchr(pool_id2str(pool, s->name), ':'))
        continue;	/* only packages, please */
      if (!pool_installable(pool, s))
        continue;
      queue_push(&cand, p);
    }
  while (cand.count)
    {
      solv = solver_create(pool);
      queue_empty(&job);
      for (i = 0; i < badguys.count; i++)
        {
          queue_push(&job, SOLVER_ERASE|SOLVER_SOLVABLE|SOLVER_WEAK);
          queue_push(&job, badguys.elements[i]);
        }
      conp = s->repo->idarraydata + s->conflicts;
      while ((con = *conp++) != 0)
        {
          queue_push(&job, SOLVER_INSTALL|SOLVER_SOLVABLE_PROVIDES|SOLVER_WEAK);
          queue_push(&job, con);
        }
      for (i = 0; i < cand.count; i++)
        {
          p = cand.elements[i];
          queue_push(&job, SOLVER_INSTALL|SOLVER_SOLVABLE|SOLVER_WEAK);
          queue_push(&job, p);
        }
      ++solver_runs;
      solver_solve(solv, &job);
#if 0
      solver_printdecisions(solv);
#endif
      /* put packages into installed repo and prune them from cand */
      toinst(solv, c->repo, c->instrepo);
      for (i = 0; i < cand.count; i++)
        {
          p = cand.elements[i];
          if (p > 0 && solver_get_decisionlevel(solv, p) > 0)
            cand.elements[i] = -p;	/* drop candidate */
        }
      solver_free(solv);

      /* now the interesting part: test patch */
      queue_empty(&job);
      if (!c->install_available)
        {
          for (i = 1; i < c->updatestart; i++)
            {
              if (pool->solvables[i].repo != c->repo || i == pid)
                continue;
              queue_push(&job, SOLVER_ERASE|SOLVER_SOLVABLE);
              queue_push(&job, i);
            }
        }
      queue_push(&job, SOLVER_INSTALL|SOLVER_SOLVABLE);
      queue_push(&job, pid);
      solv = solver_create(pool);
      solver_set_flag(solv, SOLVER_FLAG_IGNORE_RECOMMENDED, 1);
      ++solver_runs;
      if (solver_solve(solv, &job))
        {
          c->status = 1;
          showproblems(solv, s, &cand, &badguys);
        }
      frominst(solv, c->repo, c->instrepo);
      solver_free(solv);
      /* now drop all negative elements from cand */
      for (i = j = 0; i < cand.count; i++)
        {
          if (cand.elements[i] < 0)
            continue;
          cand.elements[j++] = cand.elements[i];
        }
      if (i == j)
        break;	/* no progress */
      cand.count = j;
    }
  if (PERF_DEBUGGING)
    printf("  test_can_upgrade_all_packages took %d ms in %d runs\n", solv_timems(now), solver_runs);
}

void
test_no_ga_package_fulfills_dependency(context_t *c, Id pid)
{
  Id con, *conp;
  Solvable *s = pool->solvables + pid;

  /* Test 4: no GA package fulfills patch dependency */
  conp = s->repo->idarraydata + s->conflicts;
  while ((con = *conp++) != 0)
    {
      Reldep *rd;
      Id rp, rpp;

      if (!ISRELDEP(con))
        continue;
      rd = GETRELDEP(pool, con);
      FOR_PROVIDES(rp, rpp, rd->name)
        {
          Solvable *s2 = pool_id2solvable(pool, rp);
          if (rp < c->updatestart
              && pool_evrcmp(pool, rd->evr, s2->evr, EVRCMP_COMPARE) < 0
              && pool_match_nevr_rel(pool, s2, rd->name)
             )
            {
              SHOW_PATCH(c);
              printf("  conflict %s < %s satisfied by non-updated package %s\n",
                  pool_dep2str(pool, rd->name), pool_dep2str(pool, rd->evr), pool_solvable2str(pool, s2));
              break;
            }
        }
    }
}

int
main(int argc, char **argv)
{
  char *arch, *mypatch;
  const char *pname;
  int l, r;
  FILE *fp;
  int i;
  Id pid, p, pp;
  int tests = 0;
  context_t c;
  static const char* langs[] = {"en"};

  c.install_available = 0;
  c.updatestart = 0;
  c.status = 0;

  if (argc <= 3)
    usage(argv);

  arch = argv[1];
  pool = pool_create();
  pool_setarch(pool, arch);
  pool_set_languages(pool, langs, 1);

#if 0
  pool_setdebuglevel(pool, 2);
#endif

  mypatch = argv[2];

  c.repo = repo_create(pool, 0);
  c.instrepo = repo_create(pool, 0);
  for (i = 3; i < argc; i++)
    {
      if (!strcmp(argv[i], "--updaterepos"))
	{
	  c.updatestart = pool->nsolvables;
	  continue;
	}

      if (!strcmp(argv[i], "--install-available"))
	{
	  c.install_available = 1;
	  continue;
	}
 
      l = strlen(argv[i]);
      if (!strcmp(argv[i], "-"))
        fp = stdin;
      else if ((fp = solv_xfopen(argv[i], 0)) == 0)
        {
          perror(argv[i]);
          exit(1);
        }
      r = 0;
      if (0)
	{
	}
#ifdef ENABLE_SUSEREPO
      else if (l >= 8 && !strcmp(argv[i] + l - 8, "packages"))
        {
          r = repo_add_susetags(c.repo, fp, 0, 0, 0);
        }
      else if (l >= 11 && !strcmp(argv[i] + l - 11, "packages.gz"))
        {
          r = repo_add_susetags(c.repo, fp, 0, 0, 0);
        }
#endif
#ifdef ENABLE_RPMMD
      else if (l >= 14 && !strcmp(argv[i] + l - 14, "primary.xml.gz"))
        {
          r = repo_add_rpmmd(c.repo, fp, 0, 0);
        }
      else if (l >= 17 && !strcmp(argv[i] + l - 17, "updateinfo.xml.gz"))
	{
          r = repo_add_updateinfoxml(c.repo, fp, 0);
	}
#endif
      else
	r = repo_add_solv(c.repo, fp, 0);
      if (r)
        {
          fprintf(stderr, "could not add repo %s: %s\n", argv[i], pool_errstr(pool));
          exit(1);
        }
      if (fp != stdin)
        fclose(fp);
    }

  pool_addfileprovides(pool);

  /* bad hack ahead: clone repo */
  c.instrepo->idarraydata = c.repo->idarraydata;
  c.instrepo->idarraysize = c.repo->idarraysize;
  c.instrepo->start = c.repo->start;
  c.instrepo->end = c.repo->end;
  c.instrepo->nsolvables = c.repo->nsolvables;	/* sic! */
  pool_set_installed(pool, c.instrepo);
  pool_createwhatprovides(pool);

  for (pid = 1; pid < pool->nsolvables; pid++)
    {
      Solvable *s;
      c.shown = 0;
      s = pool->solvables + pid;
      if (!s->repo)
        continue;
      if (!pool_installable(pool, s))
        continue;
      pname = pool_id2str(pool, s->name);
      if (strncmp(pname, "patch:", 6) != 0)
	continue;

      if (*mypatch)
	{
	  if (strncmp(mypatch, pname + 6, strlen(pname + 6)) != 0)
	    continue;
	  if (strcmp(mypatch, pname + 6) != 0)
	    {
	      l = strlen(pname + 6);
	      if (mypatch[l] != '-')
		continue;
	      if (strcmp(mypatch + l + 1, pool_id2str(pool, s->evr)) != 0)
		continue;
	    }
	}
      else
	{
	  FOR_PROVIDES(p, pp, s->name)
	    {
	      Solvable *s2 = pool->solvables + p;
	      if (pool_evrcmp(pool, s->evr, s2->evr, EVRCMP_COMPARE) < 0)
		break;
	    }
	  if (p) {
            /* printf("found a newer one for %s\n", pname+6); */
	    continue;	/* found a newer one */
          }
	}
      tests++;
      if (!s->conflicts)
	continue;

#if 0
      printf("testing patch %s-%s\n", pname + 6, pool_id2str(pool, s->evr));
#endif

      test_all_old_patches_included(&c, pid);
      test_all_packages_installable(&c, pid);
      test_can_upgrade_all_packages(&c, pid);
      test_no_ga_package_fulfills_dependency(&c, pid);
    }

  exit(c.status);
}
