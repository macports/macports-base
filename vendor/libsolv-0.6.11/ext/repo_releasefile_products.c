/*
 * repo_products.c
 *
 * Parses all files below 'proddir'
 * See http://en.opensuse.org/Product_Management/Code11
 *
 *
 * Copyright (c) 2008, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

#include <sys/types.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <dirent.h>
#include <ctype.h>
#include <errno.h>

#include "pool.h"
#include "repo.h"
#include "util.h"
#define DISABLE_SPLIT
#include "tools_util.h"
#include "repo_releasefile_products.h"

#define BUFF_SIZE 8192

struct parsedata {
  Repo *repo;
  struct joindata jd;
};

static void
add_releasefile_product(struct parsedata *pd, FILE *fp)
{
  Repo *repo = pd->repo;
  Pool *pool = repo->pool;
  char buf[BUFF_SIZE];
  Id name = 0;
  Id arch = 0;
  Id version = 0;
  int lnum = 0; /* line number */
  char *ptr, *ptr1;

  /* parse /etc/<xyz>-release file */
  while (fgets(buf, sizeof(buf), fp))
    {
      /* remove trailing \n */
      int l = strlen(buf);
      if (l && buf[l - 1] == '\n')
	buf[--l] = 0;
      ++lnum;

      if (lnum == 1)
	{
	  /* 1st line, <name> [(<arch>)] */
	  ptr = strchr(buf, '(');
	  if (ptr)
	    {
	      ptr1 = ptr - 1;
	      *ptr++ = 0;
	    }
	  else
	    ptr1 = buf + l - 1;

	  /* track back until non-blank, non-digit */
	  while (ptr1 > buf
		 && (*ptr1 == ' ' || isdigit(*ptr1) || *ptr1 == '.'))
	    --ptr1;
	  *(++ptr1) = 0;
	  name = pool_str2id(pool, join2(&pd->jd, "product", ":", buf), 1);

	  if (ptr)
	    {
	      /* have arch */
	      char *ptr1 = strchr(ptr, ')');
	      if (ptr1)
		{
		  *ptr1 = 0;
		  /* downcase arch */
		  ptr1 = ptr;
		  while (*ptr1)
		    {
		      if (isupper(*ptr1))
			 *ptr1 = tolower(*ptr1);
		      ++ptr1;
		    }
		  arch = pool_str2id(pool, ptr, 1);
		}
	    }
	}
      else if (strncmp(buf, "VERSION", 7) == 0)
	{
	  ptr = strchr(buf + 7, '=');
	  if (ptr)
	    {
	      while (*++ptr == ' ')
		;
	      version = makeevr(pool, ptr);
	    }
	}
    }
  if (name)
    {
      Solvable *s = pool_id2solvable(pool, repo_add_solvable(repo));
      s->name = name;
      s->evr = version ? version : ID_EMPTY;
      s->arch = arch ? arch : ARCH_NOARCH;
      if (s->name && s->arch != ARCH_SRC && s->arch != ARCH_NOSRC)
	s->provides = repo_addid_dep(repo, s->provides, pool_rel2id(pool, s->name, s->evr, REL_EQ, 1), 0);
    }
}


int
repo_add_releasefile_products(Repo *repo, const char *dirpath, int flags)
{
  DIR *dir;
  struct dirent *entry;
  FILE *fp;
  char *fullpath;
  struct parsedata pd;

  if (!dirpath)
    dirpath = "/etc";
  if (flags & REPO_USE_ROOTDIR)
    dirpath = pool_prepend_rootdir(repo->pool, dirpath);
  dir = opendir(dirpath);
  if (!dir)
    {
      if (flags & REPO_USE_ROOTDIR)
        solv_free((char *)dirpath);
      return 0;
    }

  memset(&pd, 0, sizeof(pd));
  pd.repo = repo;
  while ((entry = readdir(dir)))
    {
      int len = strlen(entry->d_name);
      if (len > 8 && !strcmp(entry->d_name + len - 8, "-release"))
        {
	  /* skip /etc/lsb-release, thats not a product per-se */
	  if (strcmp(entry->d_name, "lsb-release") == 0)
	    continue;
	  fullpath = join2(&pd.jd, dirpath, "/", entry->d_name);
	  if ((fp = fopen(fullpath, "r")) == 0)
	    {
	      pool_error(repo->pool, 0, "%s: %s", fullpath, strerror(errno));
	      continue;
	    }
	  add_releasefile_product(&pd, fp);
	  fclose(fp);
	}
    }
  closedir(dir);
  join_freemem(&pd.jd);
  if (flags & REPO_USE_ROOTDIR)
    solv_free((char *)dirpath);

  if (!(flags & REPO_NO_INTERNALIZE) && (flags & REPO_REUSE_REPODATA) != 0)
    repodata_internalize(repo_last_repodata(repo));
  return 0;
}

