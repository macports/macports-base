/* vim: sw=2 et cino=>4,n-2,{1s
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
#include "poolarch.h"
#include "repo_solv.h"
#ifdef ENABLE_SUSEREPO
#include "repo_susetags.h"
#endif
#ifdef ENABLE_RPMMD
#include "repo_rpmmd.h"
#endif
#ifdef ENABLE_DEBIAN
#include "repo_deb.h"
#endif
#ifdef ENABLE_ARCHREPO
#include "repo_arch.h"
#endif
#include "solver.h"
#include "solv_xfopen.h"


void
usage(char** argv)
{
  printf("Usage:\n%s: <arch> [options..] repo [--nocheck repo]...\n"
         "\t--exclude <pattern>\twhitespace-separated list of (sub-)"
         "packagenames to ignore\n"
         "\t--withobsoletes\t\tCheck for obsoletes on packages contained in repos\n"
         "\t--nocheck\t\tDo not warn about all following repos (only use them to fulfill dependencies)\n"
         "\t--withsrc\t\tAlso check dependencies of src.rpm\n\n"
         , argv[0]);
  exit(1);
}


int
main(int argc, char **argv)
{
  Pool *pool;
  Solver *solv;
  Repo *repo;
  Queue job;
  Queue rids;
  Queue cand;
  char *arch, *exclude_pat;
  int i, j;
  Id p;
  Id archid, noarchid;
  Id rpmrel;
#ifndef DEBIAN
  Id rpmid;
#endif
  int status = 0;
  int nocheck = 0;
  int withsrc = 0;
  int obsoletepkgcheck = 0;

  exclude_pat = 0;
  if (argc < 3)
    usage(argv);

  arch = argv[1];
  pool = pool_create();
  pool_setarch(pool, arch);
  noarchid = pool->solvables[SYSTEMSOLVABLE].arch;
  for (i = 2; i < argc; i++)
    {
      FILE *fp;
      int r, l;

      if (!strcmp(argv[i], "--withsrc"))
	{
	  withsrc++;
	  continue;
	}
      if (!strcmp(argv[i], "--withobsoletes"))
        {
          obsoletepkgcheck++;
          continue;
        }
      if (!strcmp(argv[i], "--nocheck"))
	{
	  if (!nocheck)
	    nocheck = pool->nsolvables;
	  continue;
	}
      if (!strcmp(argv[i], "--exclude"))
        {
          if (i + 1 >= argc)
            {
              printf("--exclude needs a whitespace separated list of substrings as parameter\n");
              exit(1);
            }
          exclude_pat = argv[i + 1];
          ++i;
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
      repo = repo_create(pool, argv[i]);
      r = 0;
      if (0)
        {
        }
#ifdef ENABLE_SUSEREPO
      else if (l >= 8 && !strcmp(argv[i] + l - 8, "packages"))
	{
	  r = repo_add_susetags(repo, fp, 0, 0, 0);
	}
      else if (l >= 11 && !strcmp(argv[i] + l - 11, "packages.gz"))
	{
	  r = repo_add_susetags(repo, fp, 0, 0, 0);
	}
#endif
#ifdef ENABLE_RPMMD
      else if (l >= 14 && !strcmp(argv[i] + l - 14, "primary.xml.gz"))
	{
	  r = repo_add_rpmmd(repo, fp, 0, 0);
	}
#endif
#ifdef ENABLE_DEBIAN
      else if (l >= 8 && !strcmp(argv[i] + l - 8, "Packages"))
	{
	  r = repo_add_debpackages(repo, fp, 0);
	}
      else if (l >= 11 && !strcmp(argv[i] + l - 11, "Packages.gz"))
	{
	  r = repo_add_debpackages(repo, fp, 0);
	}
#endif
#ifdef ENABLE_ARCHREPO
      else if (l >= 10 && (!strcmp(argv[i] + l - 10, ".db.tar.gz") || !strcmp(argv[i] + l - 10, ".db.tar.xz")))
        {
	  r = repo_add_arch_repo(repo, fp, 0);
        }
#endif
      else
	r = repo_add_solv(repo, fp, 0);
      if (r)
	{
	  fprintf(stderr, "could not add repo %s: %s\n", argv[i], pool_errstr(pool));
	  exit(1);
	}
      if (fp != stdin)
        fclose(fp);
    }
  pool_addfileprovides(pool);
  pool_createwhatprovides(pool);
  archid = pool_str2id(pool, arch, 0);
#ifndef DEBIAN
  rpmid = pool_str2id(pool, "rpm", 0);
  rpmrel = 0;
  if (rpmid && archid)
    {
      for (p = 1; p < pool->nsolvables; p++)
	{
	  Solvable *s = pool->solvables + p;
	  if (s->name == rpmid && s->arch == archid && pool_installable(pool, s))
	    break;
	}
      if (p < pool->nsolvables)
        rpmrel = pool_rel2id(pool, rpmid, archid, REL_ARCH, 1);
    }
#else
  rpmrel = 0;
#endif
  
  queue_init(&job);
  queue_init(&rids);
  queue_init(&cand);
  for (p = 1; p < (nocheck ? nocheck : pool->nsolvables); p++)
    {
      Solvable *s = pool->solvables + p;
      if (!s->repo)
	continue;
      if (withsrc && (s->arch == ARCH_SRC || s->arch == ARCH_NOSRC))
	{
	  queue_push(&cand, p);
	  continue;
	}
      if (!pool_installable(pool, s))
	continue;
      if (archid && s->arch != archid && s->arch != noarchid)
	{
	  /* check if we will conflict with a infarch rule, if yes,
	   * don't bother checking the package */
	  Id rp, rpp;
	  FOR_PROVIDES(rp, rpp, s->name)
	    {
	      if (pool->solvables[rp].name != s->name)
		continue;
	      if (pool->solvables[rp].arch == archid)
		break;
	    }
	  if (rp)
	    continue;
	}
      queue_push(&cand, p);
    }
  if (obsoletepkgcheck)
    {
      int obsoleteusesprovides = pool_get_flag(pool, POOL_FLAG_OBSOLETEUSESPROVIDES);
      int obsoleteusescolors = pool_get_flag(pool, POOL_FLAG_OBSOLETEUSESCOLORS);

      for (i = 0; i < cand.count; i++)
	{
	  Solvable *s;
	  s = pool->solvables + cand.elements[i];

	  if (s->obsoletes)
	    {
	      Id obs, *obsp = s->repo->idarraydata + s->obsoletes;

	      while ((obs = *obsp++) != 0)
		{
		  Id op, opp;
		  FOR_PROVIDES(op, opp, obs)
		    {
		      Solvable *os = pool->solvables + op;
		      if (nocheck && op >= nocheck)
			continue;
		      if (solvable_identical(s, os))
			continue;
		      if (!obsoleteusesprovides && !pool_match_nevr(pool, os, obs))
			continue;
		      if (obsoleteusescolors && !pool_colormatch(pool, s, os))
			continue;
		      status = 2;
		      printf("can't install %s:\n", pool_solvid2str(pool, op));
		      printf("  package is obsoleted by %s\n", pool_solvable2str(pool, s));
		    }
		}
	    }
	}
    }

  solv = solver_create(pool);

  /* prune cand by doing weak installs */
  while (cand.count)
    {
      queue_empty(&job);
      for (i = 0; i < cand.count; i++)
	{
	  p = cand.elements[i];
	  queue_push2(&job, SOLVER_INSTALL|SOLVER_SOLVABLE|SOLVER_WEAK, p);
	}
      if (rpmrel)
	queue_push2(&job, SOLVER_INSTALL|SOLVER_SOLVABLE_NAME, rpmrel);
      solver_set_flag(solv, SOLVER_FLAG_IGNORE_RECOMMENDED, 1);
      solver_solve(solv, &job);
      /* prune... */
      for (i = j = 0; i < cand.count; i++)
	{
	  p = cand.elements[i];
	  if (solver_get_decisionlevel(solv, p) <= 0)
	    {
	      cand.elements[j++] = p;
	      continue;
	    }
#if 0
	  Solvable *s = pool->solvables + p;
	  if (!strcmp(pool_id2str(pool, s->name), "libusb-compat-devel"))
	    {
	      cand.elements[j++] = p;
	      continue;
	    }
#endif
	}
      cand.count = j;
      if (i == j)
	break;
    }

  /* now check every candidate */
  for (i = 0; i < cand.count; i++)
    {
      Solvable *s;
      int problemcount;

      p = cand.elements[i];
      if (exclude_pat)
        {
          char *ptr, *save = 0, *pattern;
          int match = 0;
          pattern = solv_strdup(exclude_pat);

          for (ptr = strtok_r(pattern, " ", &save);
              ptr;
              ptr = strtok_r(NULL, " ", &save))
            {
              if (*ptr && strstr(pool_solvid2str(pool, p), ptr))
                {
                  match = 1;
                  break;
                }
            }
          solv_free(pattern);
          if (match)
            continue;
        }
      s = pool->solvables + p;
      queue_empty(&job);
      queue_push2(&job, SOLVER_INSTALL|SOLVER_SOLVABLE, p);
      if (rpmrel)
	queue_push2(&job, SOLVER_INSTALL|SOLVER_SOLVABLE_NAME, rpmrel);
      solver_set_flag(solv, SOLVER_FLAG_IGNORE_RECOMMENDED, 1);
      problemcount = solver_solve(solv, &job);
      if (problemcount)
	{
	  Id problem = 0;
	  Solvable *s2;

	  status = 1;
	  printf("can't install %s:\n", pool_solvable2str(pool, s));
	  while ((problem = solver_next_problem(solv, problem)) != 0)
	    {
	      solver_findallproblemrules(solv, problem, &rids);
	      for (j = 0; j < rids.count; j++)
		{
		  Id probr = rids.elements[j];
		  int k;
		  Queue rinfo;
		  queue_init(&rinfo);

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
			  s = pool_id2solvable(pool, source);
			  printf("  %s has inferior architecture\n", pool_solvable2str(pool, s));
			  break;
			case SOLVER_RULE_UPDATE:
			  s = pool_id2solvable(pool, source);
			  printf("  %s can not be updated\n", pool_solvable2str(pool, s));
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
			  s = pool_id2solvable(pool, source);
			  printf("  package %s is not installable\n", pool_solvable2str(pool, s));
			  break;
			case SOLVER_RULE_RPM_NOTHING_PROVIDES_DEP:
			  s = pool_id2solvable(pool, source);
			  printf("  nothing provides %s needed by %s\n", pool_dep2str(pool, dep), pool_solvable2str(pool, s));
			  if (ISRELDEP(dep))
			    {
			      Reldep *rd = GETRELDEP(pool, dep);
			      if (!ISRELDEP(rd->name))
				{
				  Id rp, rpp;
				  FOR_PROVIDES(rp, rpp, rd->name)
				    printf("    (we have %s)\n", pool_solvable2str(pool, pool->solvables + rp));
				}
			    }
			  break;
			case SOLVER_RULE_RPM_SAME_NAME:
			  s = pool_id2solvable(pool, source);
			  s2 = pool_id2solvable(pool, target);
			  printf("  cannot install both %s and %s\n", pool_solvable2str(pool, s), pool_solvable2str(pool, s2));
			  break;
			case SOLVER_RULE_RPM_PACKAGE_CONFLICT:
			  s = pool_id2solvable(pool, source);
			  s2 = pool_id2solvable(pool, target);
			  printf("  package %s conflicts with %s provided by %s\n", pool_solvable2str(pool, s), pool_dep2str(pool, dep), pool_solvable2str(pool, s2));
			  break;
			case SOLVER_RULE_RPM_PACKAGE_OBSOLETES:
			  s = pool_id2solvable(pool, source);
			  s2 = pool_id2solvable(pool, target);
			  printf("  package %s obsoletes %s provided by %s\n", pool_solvable2str(pool, s), pool_dep2str(pool, dep), pool_solvable2str(pool, s2));
			  break;
			case SOLVER_RULE_RPM_PACKAGE_REQUIRES:
			  s = pool_id2solvable(pool, source);
			  printf("  package %s requires %s, but none of the providers can be installed\n", pool_solvable2str(pool, s), pool_dep2str(pool, dep));
			  break;
			case SOLVER_RULE_RPM_SELF_CONFLICT:
			  s = pool_id2solvable(pool, source);
			  printf("  package %s conflicts with %s provided by itself\n", pool_solvable2str(pool, s), pool_dep2str(pool, dep));
			  break;
			}
		    }
		}
	    }
	}
#if 0
      else
	{
	  if (!strcmp(pool_id2str(pool, s->name), "libusb-compat-devel"))
	    {
	      solver_printdecisions(solv);
	    }
	}
#endif
    }
  solver_free(solv);
  exit(status);
}
