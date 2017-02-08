/*
 * Copyright (c) 2013, SUSE Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

#define _GNU_SOURCE
#define _XOPEN_SOURCE
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#include "pool.h"
#include "repo.h"
#include "util.h"
#include "repo_autopattern.h"

static void
unescape(char *p)
{
  char *q = p;
  while (*p)
    {
      if (*p == '%' && p[1] && p[2])
	{
	  int d1 = p[1], d2 = p[2];
	  if (d1 >= '0' && d1 <= '9')
	    d1 -= '0';
	  else if (d1 >= 'a' && d1 <= 'f')
	    d1 -= 'a' - 10;
	  else if (d1 >= 'A' && d1 <= 'F')
	    d1 -= 'A' - 10;
	  else
	    d1 = -1;
	  if (d2 >= '0' && d2 <= '9')
	    d2 -= '0';
	  else if (d2 >= 'a' && d2 <= 'f')
	    d2 -= 'a' - 10;
	  else if (d2 >= 'A' && d2 <= 'F')
	    d2 -= 'A' - 10;
	  else
	    d2 = -1;
	  if (d1 != -1 && d2 != -1)
	    {
	      *q++ = d1 << 4 | d2;
	      p += 3;
	      continue;
	    }
	}
      *q++ = *p++;
    }
  *q = 0;
}

static time_t
datestr2timestamp(const char *date)
{
  const char *p; 
  struct tm tm; 

  if (!date || !*date)
    return 0;
  for (p = date; *p >= '0' && *p <= '9'; p++)
    ;   
  if (!*p)
    return atoi(date);
  memset(&tm, 0, sizeof(tm));
  p = strptime(date, "%F%T", &tm);
  if (!p)
    {   
      memset(&tm, 0, sizeof(tm));
      p = strptime(date, "%F", &tm);
      if (!p || *p) 
        return 0;
    }   
  return timegm(&tm);
}

int
repo_add_autopattern(Repo *repo, int flags)
{
  Pool *pool = repo->pool;
  Repodata *data = 0;
  Solvable *s, *s2;
  Queue patq, patq2;
  Queue prdq, prdq2;
  Id p;
  Id pattern_id, product_id;
  Id autopattern_id = 0, autoproduct_id = 0;
  int i, j;

  queue_init(&patq);
  queue_init(&patq2);
  queue_init(&prdq);
  queue_init(&prdq2);

  if (repo == pool->installed)
    flags |= ADD_NO_AUTOPRODUCTS;	/* no auto products for installed repos */

  pattern_id = pool_str2id(pool, "pattern()", 9);
  product_id = pool_str2id(pool, "product()", 9);
  FOR_REPO_SOLVABLES(repo, p, s)
    {
      const char *n = pool_id2str(pool, s->name);
      if (*n == 'p')
	{
	  if (!strncmp("pattern:", n, 8))
	    {
	      queue_push(&patq, p);
	      continue;
	    }
	  else if (!strncmp("product:", n, 8))
	    {
	      queue_push(&prdq, p);
	      continue;
	    }
	}
      if (s->provides)
	{
	  Id prv, *prvp = repo->idarraydata + s->provides;
	  while ((prv = *prvp++) != 0)            /* go through all provides */
	    if (ISRELDEP(prv))
	      {
	        Reldep *rd = GETRELDEP(pool, prv);
		if (rd->flags != REL_EQ)
		  continue;
		if (rd->name == pattern_id)
		  {
		    const char *evrstr = pool_id2str(pool, rd->evr);
		    if (evrstr[0] == '.')	/* hack to allow provides that do not create a pattern */
		      continue;
		    if (patq2.count && patq2.elements[patq2.count - 2] == p)
		      {
			/* hmm, two provides. choose by evrstr */
			if (strcmp(evrstr, pool_id2str(pool, patq2.elements[patq2.count - 1])) >= 0)
			  continue;
			patq2.count -= 2;
		      }
		    queue_push2(&patq2, p, rd->evr);
		  }
		if (rd->name == product_id)
		  {
		    const char *evrstr = pool_id2str(pool, rd->evr);
		    if (prdq2.count && prdq2.elements[prdq2.count - 2] == p)
		      {
			/* hmm, two provides. choose by evrstr */
			if (strcmp(evrstr, pool_id2str(pool, prdq2.elements[prdq2.count - 1])) >= 0)
			  continue;
			prdq2.count -= 2;
		      }
		    queue_push2(&prdq2, p, rd->evr);
		  }
	      }
	}
    }
  for (i = 0; i < patq2.count; i += 2)
    {
      const char *pn = 0;
      char *newname;
      Id name, prv, *prvp;
      const char *str;
      unsigned long long num;

      s = pool->solvables + patq2.elements[i];
      /* construct new name */
      newname = pool_tmpjoin(pool, "pattern:", pool_id2str(pool, patq2.elements[i + 1]), 0);
      unescape(newname);
      name = pool_str2id(pool, newname, 0);
      if (name)
	{
	  /* check if we already have that pattern */
	  for (j = 0; j < patq.count; j++)
	    {
	      s2 = pool->solvables + patq.elements[j];
	      if (s2->name == name && s2->arch == s->arch && s2->evr == s->evr)
		break;
	    }
	  if (j < patq.count)
	    continue;	/* yes, do not add again */
	}
      /* new pattern */
      if (!name)
        name = pool_str2id(pool, newname, 1);
      if (!data)
	{
	  repo_internalize(repo);	/* to make that the lookups work */
	  data = repo_add_repodata(repo, flags);
	}
      s2 = pool_id2solvable(pool, repo_add_solvable(repo));
      s = pool->solvables + patq2.elements[i];	/* re-calc pointer */
      s2->name = name;
      s2->arch = s->arch;
      s2->evr = s->evr;
      s2->vendor = s->vendor;
      /* add link requires */
      s2->requires = repo_addid_dep(repo, s2->requires, pool_rel2id(pool, s->name, s->evr, REL_EQ, 1) , 0);
      /* add autopattern provides */
      if (!autopattern_id)
	autopattern_id = pool_str2id(pool, "autopattern()", 1);
      s2->provides = repo_addid_dep(repo, s2->provides, pool_rel2id(pool, autopattern_id, s->name, REL_EQ, 1), 0);
      /* add self provides */
      s2->provides = repo_addid_dep(repo, s2->provides, pool_rel2id(pool, s2->name, s2->evr, REL_EQ, 1), 0);
      if ((num = solvable_lookup_num(s, SOLVABLE_INSTALLTIME, 0)) != 0)
	repodata_set_num(data, s2 - pool->solvables, SOLVABLE_INSTALLTIME, num);
      if ((num = solvable_lookup_num(s, SOLVABLE_BUILDTIME, 0)) != 0)
	repodata_set_num(data, s2 - pool->solvables, SOLVABLE_BUILDTIME, num);
      if ((str = solvable_lookup_str(s, SOLVABLE_SUMMARY)) != 0)
	repodata_set_str(data, s2 - pool->solvables, SOLVABLE_SUMMARY, str);
      if ((str = solvable_lookup_str(s, SOLVABLE_DESCRIPTION)) != 0)
	repodata_set_str(data, s2 - pool->solvables, SOLVABLE_DESCRIPTION, str);
      /* fill in stuff from provides */
      prvp = repo->idarraydata + s->provides;
      while ((prv = *prvp++) != 0)            /* go through all provides */
	{
	  Id evr = 0;
	  if (ISRELDEP(prv))
	    {
	      Reldep *rd = GETRELDEP(pool, prv);
	      if (rd->flags != REL_EQ)
	        continue;
	      prv = rd->name;
	      evr = rd->evr;
	    }
	  pn = pool_id2str(pool, prv);
	  if (strncmp("pattern-", pn, 8) != 0)
	    continue;
	  newname = 0;
	  if (evr)
	    {
	      newname = pool_tmpjoin(pool, pool_id2str(pool, evr), 0, 0);
	      unescape(newname);
	    }
	  if (!strncmp(pn, "pattern-category(", 17) && evr)
	    {
	      char lang[9];
	      int l = strlen(pn);
	      Id langtag;
	      if (l > 17 + 9 || pn[l - 1] != ')')
		continue;
              strncpy(lang, pn + 17, l - 17 - 1);
	      lang[l - 17 - 1] = 0;
	      langtag = SOLVABLE_CATEGORY;
	      if (*lang && strcmp(lang, "en") != 0)
		langtag = pool_id2langid(pool, SOLVABLE_CATEGORY, lang, 1);
	      if (newname[solv_validutf8(newname)] == 0)
	        repodata_set_str(data, s2 - pool->solvables, langtag, newname);
	      else
		{
		  char *ustr = solv_latin1toutf8(newname);
	          repodata_set_str(data, s2 - pool->solvables, langtag, ustr);
		  solv_free(ustr);
		}
	    }
	  else if (!strcmp(pn, "pattern-includes()") && evr)
	    repodata_add_poolstr_array(data, s2 - pool->solvables, SOLVABLE_INCLUDES, pool_tmpjoin(pool, "pattern:", newname, 0));
	  else if (!strcmp(pn, "pattern-extends()") && evr)
	    repodata_add_poolstr_array(data, s2 - pool->solvables, SOLVABLE_EXTENDS, pool_tmpjoin(pool, "pattern:", newname, 0));
	  else if (!strcmp(pn, "pattern-icon()") && evr)
	    repodata_set_str(data, s2 - pool->solvables, SOLVABLE_ICON, newname);
	  else if (!strcmp(pn, "pattern-order()") && evr)
	    repodata_set_str(data, s2 - pool->solvables, SOLVABLE_ORDER, newname);
	  else if (!strcmp(pn, "pattern-visible()") && !evr)
	    repodata_set_void(data, s2 - pool->solvables, SOLVABLE_ISVISIBLE);
	}
    }
  queue_free(&patq);
  queue_free(&patq2);

  if ((flags & ADD_NO_AUTOPRODUCTS) != 0)
    queue_empty(&prdq2);

  for (i = 0; i < prdq2.count; i += 2)
    {
      const char *pn = 0;
      char *newname;
      Id name, evr = 0, prv, *prvp;
      const char *str;
      unsigned long long num;

      s = pool->solvables + prdq2.elements[i];
      /* construct new name */
      newname = pool_tmpjoin(pool, "product(", pool_id2str(pool, prdq2.elements[i + 1]), ")");
      unescape(newname);
      name = pool_str2id(pool, newname, 0);
      if (!name)
	continue;	/* must have it in provides! */
      prvp = repo->idarraydata + s->provides;
      while ((prv = *prvp++) != 0)            /* go through all provides */
	{
	  if (ISRELDEP(prv))
	    {
	      Reldep *rd = GETRELDEP(pool, prv);
	      if (rd->name == name && rd->flags == REL_EQ)
		{
		  evr = rd->evr;
		  break;
		}
	    }
	}
      if (!prv)
	continue;	/* not found in provides */
      newname = pool_tmpjoin(pool, "product:", pool_id2str(pool, prdq2.elements[i + 1]), 0);
      unescape(newname);
      name = pool_str2id(pool, newname, 0);
      if (name)
	{
	  /* check if we already have that product */
	  for (j = 0; j < prdq.count; j++)
	    {
	      s2 = pool->solvables + prdq.elements[j];
	      if (s2->name == name && s2->arch == s->arch && s2->evr == evr)
		break;
	    }
	  if (j < prdq.count)
	    continue;	/* yes, do not add again */
	}
      /* new product */
      if (!name)
        name = pool_str2id(pool, newname, 1);
      if (!data)
	{
	  repo_internalize(repo);	/* to make that the lookups work */
	  data = repo_add_repodata(repo, flags);
	}
      if ((num = solvable_lookup_num(s, SOLVABLE_INSTALLTIME, 0)) != 0)
	continue;		/* eek, not for installed packages, please! */
      s2 = pool_id2solvable(pool, repo_add_solvable(repo));
      s = pool->solvables + prdq2.elements[i];	/* re-calc pointer */
      s2->name = name;
      s2->arch = s->arch;
      s2->evr = evr;
      s2->vendor = s->vendor;
      /* add link requires */
      s2->requires = repo_addid_dep(repo, s2->requires, prv, 0);
      if (!autoproduct_id)
	autoproduct_id = pool_str2id(pool, "autoproduct()", 1);
      s2->provides = repo_addid_dep(repo, s2->provides, pool_rel2id(pool, autoproduct_id, s->name, REL_EQ, 1), 0);
      /* add self provides */
      s2->provides = repo_addid_dep(repo, s2->provides, pool_rel2id(pool, s2->name, s2->evr, REL_EQ, 1), 0);
      if ((num = solvable_lookup_num(s, SOLVABLE_BUILDTIME, 0)) != 0)
	repodata_set_num(data, s2 - pool->solvables, SOLVABLE_BUILDTIME, num);
      if ((str = solvable_lookup_str(s, SOLVABLE_SUMMARY)) != 0)
	repodata_set_str(data, s2 - pool->solvables, SOLVABLE_SUMMARY, str);
      if ((str = solvable_lookup_str(s, SOLVABLE_DESCRIPTION)) != 0)
	repodata_set_str(data, s2 - pool->solvables, SOLVABLE_DESCRIPTION, str);
      if ((str = solvable_lookup_str(s, SOLVABLE_DISTRIBUTION)) != 0)
	repodata_set_str(data, s2 - pool->solvables, SOLVABLE_DISTRIBUTION, str);
      /* fill in stuff from provides */
      prvp = repo->idarraydata + s->provides;
      while ((prv = *prvp++) != 0)            /* go through all provides */
	{
	  Id evr = 0;
	  if (ISRELDEP(prv))
	    {
	      Reldep *rd = GETRELDEP(pool, prv);
	      if (rd->flags != REL_EQ)
	        continue;
	      prv = rd->name;
	      evr = rd->evr;
	    }
	  pn = pool_id2str(pool, prv);
	  if (strncmp("product-", pn, 8) != 0)
	    continue;
	  newname = 0;
	  if (evr)
	    {
	      newname = pool_tmpjoin(pool, pool_id2str(pool, evr), 0, 0);
	      unescape(newname);
	    }
	  if (!strcmp(pn, "product-label()") && evr)
	    repodata_set_str(data, s2 - pool->solvables, PRODUCT_SHORTLABEL, newname);
	  else if (!strcmp(pn, "product-register-target()") && evr)
	    repodata_set_str(data, s2 - pool->solvables, PRODUCT_REGISTER_TARGET, newname);
	  else if (!strcmp(pn, "product-register-flavor()") && evr)
	    repodata_set_str(data, s2 - pool->solvables, PRODUCT_REGISTER_FLAVOR, newname);
	  else if (!strcmp(pn, "product-type()") && evr)
	    repodata_set_str(data, s2 - pool->solvables, PRODUCT_TYPE, newname);
	  else if (!strcmp(pn, "product-cpeid()") && evr)
	    repodata_set_str(data, s2 - pool->solvables, SOLVABLE_CPEID, newname);
	  else if (!strcmp(pn, "product-flags()") && evr)
	    repodata_add_poolstr_array(data, s2 - pool->solvables, PRODUCT_FLAGS, newname);
	  else if (!strcmp(pn, "product-updates-repoid()") && evr)
	    {
	      Id h = repodata_new_handle(data);
	      repodata_set_str(data, h, PRODUCT_UPDATES_REPOID, newname);
	      repodata_add_flexarray(data, s2 - pool->solvables, PRODUCT_UPDATES, h);
	    }
	  else if (!strcmp(pn, "product-endoflife()") && evr)
	    {
	      time_t t = datestr2timestamp(newname);
	      if (t)
		repodata_set_num(data, s2 - pool->solvables, PRODUCT_ENDOFLIFE, t);
	    }
	  else if (!strncmp(pn, "product-url(", 12) && evr && pn[12] && pn[13] && strlen(pn + 12) < 32)
	    {
	      char type[34];
	      strcpy(type, pn + 12);
	      type[strlen(type) - 1] = 0;	/* closing ) */
	      repodata_add_poolstr_array(data, s2 - pool->solvables, PRODUCT_URL_TYPE, type);
	      repodata_add_poolstr_array(data, s2 - pool->solvables, PRODUCT_URL, newname);
	    }
	}
    }
  queue_free(&prdq);
  queue_free(&prdq2);

  if (data && !(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  else if (!data && !(flags & REPO_NO_INTERNALIZE))
    repo_internalize(repo);
  return 0;
}

