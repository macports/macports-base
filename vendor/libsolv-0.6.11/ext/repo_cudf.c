/*
 * Copyright (c) 2012, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <zlib.h>
#include <errno.h>

#include "pool.h"
#include "repo.h"
#include "util.h"
#include "chksum.h"
#include "solver.h"
#include "repo_cudf.h"

static Id
parseonedep(Pool *pool, char *p)
{
  char *n, *ne, *e, *ee;
  Id name, evr;
  int flags;

  while (*p == ' ' || *p == '\t' || *p == '\n')
    p++;
  if (!*p)
    return 0;
  if (!strcmp(p, "!true"))
    return 0;
  if (!strcmp(p, "!false"))
    return pool_str2id(pool, p, 1);
  n = p;
  /* find end of name */
  while (*p && *p != ' ' && *p != '\t' && *p != '\n' && *p != '|')
    p++;
  ne = p;
  while (*p == ' ' || *p == '\t' || *p == '\n')
    p++;
  evr = 0;
  flags = 0;
  e = ee = 0;
  if (*p == '>' || *p == '<' || *p == '=' || *p == '!')
    {
      if (*p == '>')
	flags |= REL_GT;
      else if (*p == '=')
	flags |= REL_EQ;
      else if (*p == '<')
	flags |= REL_LT;
      else if (*p == '!')
	flags |= REL_LT | REL_GT | REL_EQ;
      p++;
      if (flags && *p == '=')
	{
	  if (p[-1] != '=')
	    flags ^= REL_EQ;
	  p++;
	}
      while (*p == ' ' || *p == '\t' || *p == '\n')
	p++;
      e = p;
      while (*p && *p != ' ' && *p != '\t' && *p != '\n' && *p != '|')
	p++;
      ee = p;
      while (*p == ' ' || *p == '\t' || *p == '\n')
	p++;
    }
  name = pool_strn2id(pool, n, ne - n, 1);
  if (e)
    {
      evr = pool_strn2id(pool, e, ee - e, 1);
      name = pool_rel2id(pool, name, evr, flags, 1);
    }
  if (*p == '|')
    {
      Id id = parseonedep(pool, p + 1);
      if (id)
	name = pool_rel2id(pool, name, id, REL_OR, 1);
    }
  return name;
}
static unsigned int
makedeps(Repo *repo, char *deps, unsigned int olddeps, Id marker)
{
  Pool *pool = repo->pool;
  char *p;
  Id id;

  while ((p = strchr(deps, ',')) != 0)
    {
      *p = 0;
      olddeps = makedeps(repo, deps, olddeps, marker);
      *p = ',';
      deps = p + 1;
    }
  id = parseonedep(pool, deps);
  if (!id)
    return olddeps;
  return repo_addid_dep(repo, olddeps, id, marker);
}

static Offset
copydeps(Pool *pool, Repo *repo, Offset fromoff, Repo *fromrepo)
{
  Id *ida, *from;
  int cc;
  Offset off;

  if (!fromoff)
    return 0;
  from = fromrepo->idarraydata + fromoff;
  for (ida = from, cc = 0; *ida; ida++, cc++)
    ;
  if (cc == 0)
    return 0;
  off = repo_reserve_ids(repo, 0, cc);
  memcpy(repo->idarraydata + off, from, (cc + 1) * sizeof(Id));
  repo->idarraysize += cc + 1;
  return off;
}

static void
copysolvabledata(Pool *pool, Solvable *s, Repo *repo)
{
  Repo *srepo = s->repo;
  if (srepo == repo)
    return;
  s->provides = copydeps(pool, repo, s->provides, srepo);
  s->requires = copydeps(pool, repo, s->requires, srepo);
  s->conflicts = copydeps(pool, repo, s->conflicts, srepo);
  s->obsoletes = copydeps(pool, repo, s->obsoletes, srepo);
  s->recommends = copydeps(pool, repo, s->recommends, srepo);
  s->suggests = copydeps(pool, repo, s->suggests, srepo);
  s->supplements = copydeps(pool, repo, s->supplements, srepo);
  s->enhances  = copydeps(pool, repo, s->enhances, srepo);
}

#define KEEP_VERSION 1
#define KEEP_PACKAGE 2
#define KEEP_FEATURE 3

static void
finishpackage(Pool *pool, Solvable *s, int keep, Queue *job)
{
  Id *idp, id, sid;
  if (!s)
    return;
  if (!s->arch)
    s->arch = ARCH_ANY;
  if (!s->evr)
    s->evr = ID_EMPTY;
  sid = pool_rel2id(pool, s->name, s->evr, REL_EQ, 1);
  s->provides = repo_addid_dep(s->repo, s->provides, sid, 0);
  if (!job || !pool->installed || s->repo != pool->installed)
    return;
  if (keep == KEEP_VERSION)
    queue_push2(job, SOLVER_INSTALL|SOLVER_SOLVABLE_NAME, sid);
  else if (keep == KEEP_PACKAGE)
    queue_push2(job, SOLVER_INSTALL|SOLVER_SOLVABLE_NAME, s->name);
  else if (keep == KEEP_FEATURE)
    {
      for (idp = s->repo->idarraydata + s->provides; (id = *idp) != 0; idp++)
	{
	  if (id != sid)	/* skip self-provides */
	    queue_push2(job, SOLVER_INSTALL|SOLVER_SOLVABLE_PROVIDES, id);
	}
    }
}

int
repo_add_cudf(Repo *repo, Repo *installedrepo, FILE *fp, Queue *job, int flags)
{
  Pool *pool;
  char *buf, *p;
  int bufa, bufl, c;
  Solvable *s;
  int instanza = 0;
  int inrequest = 0;
  int isinstalled = 0;
  int keep = 0;
  Repo *xrepo;

  xrepo = repo ? repo : installedrepo;
  if (!xrepo)
    return -1;
  pool = xrepo->pool;

  buf = solv_malloc(4096);
  bufa = 4096;
  bufl = 0;
  s = 0;

  while (fgets(buf + bufl, bufa - bufl, fp) > 0)
    {
      bufl += strlen(buf + bufl);
      if (bufl && buf[bufl - 1] != '\n')
	{
	  if (bufa - bufl < 256)
	    {
	      bufa += 4096;
	      buf = solv_realloc(buf, bufa);
	    }
	  continue;
	}
      buf[--bufl] = 0;
      c = getc(fp);
      if (c == ' ' || c == '\t')
	{
	  /* continuation line */
	  buf[bufl++] = ' ';
	  continue;
	}
      if (c != EOF)
	ungetc(c, fp);
      bufl = 0;
      if (*buf == '#')
	continue;
      if (!*buf)
	{
	  if (s && !repo && !isinstalled)
	    {
	      repo_free_solvable(repo, s - pool->solvables, 1);
	      s = 0;
	    }
	  if (s)
	    finishpackage(pool, s, keep, job);
	  s = 0;
	  keep = 0;
	  instanza = 0;
	  inrequest = 0;
	  continue;
	}
      p = strchr(buf, ':');
      if (!p)
	continue;	/* hmm */
      *p++ = 0;
      while (*p == ' ' || *p == '\t')
	p++;
      if (!instanza)
	{
	  instanza = 1;
	  inrequest = 0;
	  if (!strcmp(buf, "request"))
	    {
	      inrequest = 1;
	      continue;
	    }
	  if (!strcmp(buf, "package"))
	    {
	      s = pool_id2solvable(pool, repo_add_solvable(xrepo));
	      isinstalled = 0;
	      keep = 0;
	    }
	}
      if (inrequest)
	{
	  if (!job)
	    continue;
	  if (!strcmp(buf, "install"))
	    {
	      Id id, *idp;
	      Offset off = makedeps(xrepo, p, 0, 0);
	      for (idp = xrepo->idarraydata + off; (id = *idp) != 0; idp++)
		queue_push2(job, SOLVER_INSTALL|SOLVER_SOLVABLE_PROVIDES, id);
	    }
	  else if (!strcmp(buf, "remove"))
	    {
	      Id id, *idp;
	      Offset off = makedeps(xrepo, p, 0, 0);
	      for (idp = xrepo->idarraydata + off; (id = *idp) != 0; idp++)
		queue_push2(job, SOLVER_ERASE|SOLVER_SOLVABLE_PROVIDES, id);
	    }
	  else if (!strcmp(buf, "upgrade"))
	    {
	      Id id, *idp;
	      Offset off = makedeps(xrepo, p, 0, 0);
	      for (idp = xrepo->idarraydata + off; (id = *idp) != 0; idp++)
		queue_push2(job, SOLVER_INSTALL|SOLVER_ORUPDATE|SOLVER_SOLVABLE_PROVIDES, id);
	    }
	  continue;
	}
      if (!s)
	continue;	/* we ignore the preamble for now */
      switch (buf[0])
	{
	case 'c':
	  if (!strcmp(buf, "conflicts"))
	    {
	      s->conflicts = makedeps(s->repo, p, s->conflicts, 0);
	      continue;
	    }
	case 'd':
	  if (!strcmp(buf, "depends"))
	    {
	      s->requires = makedeps(s->repo, p, s->requires, 0);
	      continue;
	    }
	  break;
	case 'k':
	  if (!strcmp(buf, "keep"))
	    {
	      if (!job)
		continue;
	      if (!strcmp(p, "version"))
		keep = KEEP_VERSION;
	      else if (!strcmp(p, "package"))
		keep = KEEP_PACKAGE;
	      else if (!strcmp(p, "feature"))
		keep = KEEP_FEATURE;
	      continue;
	    }
	  break;
	case 'i':
	  if (!strcmp(buf, "installed"))
	    {
	      if (!strcmp(p, "true"))
		{
		  isinstalled = 1;
		  if (!installedrepo)
		    {
		      repo_free_solvable(repo, s - pool->solvables, 1);
		      s = 0;
		    }
		  else if (s->repo != installedrepo)
		    {
		      copysolvabledata(pool, s, installedrepo);
		      s->repo->nsolvables--;
		      s->repo = installedrepo;
		      if (s - pool->solvables < s->repo->start)
			s->repo->start = s - pool->solvables;
		      if (s - pool->solvables >= s->repo->end)
			s->repo->end = s - pool->solvables + 1;
		      s->repo->nsolvables++;
		    }
		}
	      continue;
	    }
	  break;
	case 'p':
	  if (!strcmp(buf, "package"))
	    {
	      s->name = pool_str2id(pool, p, 1);
	      continue;
	    }
	  if (!strcmp(buf, "provides"))
	    {
	      s->provides = makedeps(s->repo, p, s->provides, 0);
	      continue;
	    }
	  break;
	case 'r':
	  if (!strcmp(buf, "depends"))
	    {
	      s->recommends = makedeps(s->repo, p, s->recommends, 0);
	      continue;
	    }
	  break;
	case 'v':
	  if (!strcmp(buf, "version"))
	    {
	      s->evr = pool_str2id(pool, p, 1);
	      continue;
	    }
	  break;
	}
    }
  if (s && !repo && !isinstalled)
    {
      repo_free_solvable(repo, s - pool->solvables, 1);
      s = 0;
    }
  if (s)
    finishpackage(pool, s, keep, job);
  solv_free(buf);
  return 0;
}

