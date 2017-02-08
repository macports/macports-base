/*
 * Copyright (c) 2007, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

#define _GNU_SOURCE

#include <sys/types.h>
#include <limits.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <zlib.h>
#include <getopt.h>

#include "pool.h"
#include "repo.h"
#include "repo_solv.h"
#include "repo_susetags.h"
#include "repo_content.h"
#ifdef SUSE
#include "repo_autopattern.h"
#endif
#include "common_write.h"
#include "solv_xfopen.h"

static void
usage(int status)
{
  fprintf(stderr, "\nUsage:\n"
          "susetags2solv [-b <base>][-c <content>][-d <descrdir>][-h][-n <name>]\n"
	  "  reads a 'susetags' repository from <stdin> and writes a .solv file to <stdout>\n"
	  "  -b <base>: save as multiple files starting with <base>\n"
	  "  -c <contentfile> : parse given contentfile (for product information)\n"
          "  -d <descrdir> : do not read from stdin, but use data in descrdir\n"
	  "  -h : print help & exit\n"
	  "  -n <name>: save attributes as <name>.attr\n"
	 );
   exit(status);
}

/* content file query */
static void
doquery(Pool *pool, Repo *repo, const char *arg)
{
  char qbuf[256];
  const char *str;
  Id id;

  snprintf(qbuf, sizeof(qbuf), "susetags:%s", arg);
  id = pool_str2id(pool, qbuf, 0);
  if (!id)
    return;
  str = repo_lookup_str(repo, SOLVID_META, id);
  if (str)
    printf("%s\n", str);
}

int
main(int argc, char **argv)
{
  const char *contentfile = 0;
  const char *attrname = 0;
  const char *descrdir = 0;
  const char *basefile = 0;
  const char *query = 0;
  const char *mergefile = 0;
  Id defvendor = 0;
  int flags = 0;
#ifdef SUSE
  int add_auto = 0;
#endif
  int c;
  Pool *pool;
  Repo *repo;

  while ((c = getopt(argc, argv, "hn:c:d:b:q:M:X")) >= 0)
    {
      switch (c)
	{
	case 'h':
	  usage(0);
	  break;
	case 'n':
	  attrname = optarg;
	  break;
	case 'c':
	  contentfile = optarg;
	  break;
	case 'd':
	  descrdir = optarg;
	  break;
	case 'b':
	  basefile = optarg;
	  break;
	case 'q':
	  query = optarg;
	  break;
	case 'M':
	  mergefile = optarg;
	  break;
	case 'X':
#ifdef SUSE
	  add_auto = 1;
#endif
	  break;
	default:
	  usage(1);
	  break;
	}
    }
  pool = pool_create();
  repo = repo_create(pool, "<susetags>");

  repo_add_repodata(repo, 0);

  if (contentfile)
    {
      FILE *fp = fopen(contentfile, "r");
      if (!fp)
        {
	  perror(contentfile);
	  exit(1);
	}
      if (repo_add_content(repo, fp, REPO_REUSE_REPODATA))
	{
	  fprintf(stderr, "susetags2solv: %s: %s\n", contentfile, pool_errstr(pool));
	  exit(1);
	}
      defvendor = repo_lookup_id(repo, SOLVID_META, SUSETAGS_DEFAULTVENDOR);
      fclose(fp);
    }

  if (attrname)
    {
      /* ensure '.attr' suffix */
      const char *dot = strrchr(attrname, '.');
      if (!dot || strcmp(dot, ".attr"))
      {
	int len = strlen (attrname);
	char *newname = (char *)malloc(len + 6); /* alloc for <attrname>+'.attr'+'\0' */
	strcpy (newname, attrname);
	strcpy (newname+len, ".attr");
	attrname = newname;
      }
    }

  /*
   * descrdir path given, open files and read from there
   */
  
  if (descrdir)
    {
      char *fnp;
      int ndirs, i;
      struct dirent **files;

      ndirs = scandir(descrdir, &files, 0, alphasort);
      if (ndirs < 0)
	{
	  perror(descrdir);
	  exit(1);
	}

      /* bring packages to front */
      for (i = 0; i < ndirs; i++)
	{
	  char *fn = files[i]->d_name;
	  if (!strcmp(fn, "packages") || !strcmp(fn, "packages.gz"))
	    break;
        }
      if (i == ndirs)
	{
	  fprintf(stderr, "found no packages file\n");
	  exit(1);
	}
      if (i)
	{
	  struct dirent *de = files[i];
	  memmove(files + 1, files, i * sizeof(de));
	  files[0] = de;
	}

      fnp = solv_malloc(strlen(descrdir) + 128);
      for (i = 0; i < ndirs; i++)
	{
	  char *fn = files[i]->d_name;

	  if (!strcmp(fn, "packages") || !strcmp(fn, "packages.gz"))
	    {
	      FILE *fp;
	      sprintf(fnp, "%s/%s", descrdir, fn);
	      fp = solv_xfopen(fnp, 0);
	      if (!fp)
		{
		  perror(fn);
		  exit(1);
		}
	      if (repo_add_susetags(repo, fp, defvendor, 0, flags | REPO_REUSE_REPODATA | REPO_NO_INTERNALIZE))
		{
		  fprintf(stderr, "susetags2solv: %s: %s\n", fnp, pool_errstr(pool));
		  exit(1);
		}
	      fclose(fp);
	    }
	  else if (!strcmp(fn, "packages.DU") || !strcmp(fn, "packages.DU.gz"))
	    {
	      FILE *fp;
	      sprintf(fnp, "%s/%s", descrdir, fn);
	      fp = solv_xfopen(fnp, 0);
	      if (!fp)
		{
		  perror(fn);
		  exit(1);
		}
	      if (repo_add_susetags(repo, fp, defvendor, 0, flags | SUSETAGS_EXTEND | REPO_REUSE_REPODATA | REPO_NO_INTERNALIZE))
		{
		  fprintf(stderr, "susetags2solv: %s: %s\n", fnp, pool_errstr(pool));
		  exit(1);
		}
	      fclose(fp);
 	    }
	  else if (!strcmp(fn, "packages.FL") || !strcmp(fn, "packages.FL.gz"))
	    {
#if 0
	      sprintf(fnp, "%s/%s", descrdir, fn);
	      FILE *fp = solv_xfopen(fnp, 0);
	      if (!fp)
		{
		  perror(fn);
		  exit(1);
		}
	      if (repo_add_susetags(repo, fp, defvendor, 0, flags | SUSETAGS_EXTEND | REPO_REUSE_REPODATA | REPO_NO_INTERNALIZE))
		{
		  fprintf(stderr, "susetags2solv: %s: %s\n", fnp, pool_errstr(pool));
		  exit(1);
		}
	      fclose(fp);
#else
	      /* ignore for now. reactivate when filters work */
	      continue;
#endif
 	    }
	  else if (!strncmp(fn, "packages.", 9))
	    {
	      char lang[6];
	      char *p;
	      FILE *fp;
	      sprintf(fnp, "%s/%s", descrdir, fn);
	      p = strrchr(fnp, '.');
	      if (p && !strcmp(p, ".gz"))
		{
		  *p = 0;
		  p = strrchr(fnp, '.');
		}
	      if (!p || !p[1] || strlen(p + 1) > 5)
		continue;
	      strcpy(lang, p + 1);
	      sprintf(fnp, "%s/%s", descrdir, fn);
	      fp = solv_xfopen(fnp, 0);
	      if (!fp)
		{
		  perror(fn);
		  exit(1);
		}
	      if (repo_add_susetags(repo, fp, defvendor, lang, flags | SUSETAGS_EXTEND | REPO_REUSE_REPODATA | REPO_NO_INTERNALIZE))
		{
		  fprintf(stderr, "susetags2solv: %s: %s\n", fnp, pool_errstr(pool));
		  exit(1);
		}
	      fclose(fp);
	    }
	}
      for (i = 0; i < ndirs; i++)
	free(files[i]);
      free(files);
      free(fnp);
      repo_internalize(repo);
    }
  else
    {
      /* read data from stdin */
      if (repo_add_susetags(repo, stdin, defvendor, 0, REPO_REUSE_REPODATA | REPO_NO_INTERNALIZE))
	{
	  fprintf(stderr, "susetags2solv: %s\n", pool_errstr(pool));
	  exit(1);
	}
    }
  repo_internalize(repo);
  if (mergefile)
    {
      FILE *fp = fopen(mergefile, "r");
      if (!fp)
	{
	  perror(mergefile);
	  exit(1);
	}
      if (repo_add_solv(repo, fp, 0))
	{
	  fprintf(stderr, "susetags2solv: %s\n", pool_errstr(pool));
	  exit(1);
	}
      fclose(fp);
    }
#ifdef SUSE
  if (add_auto)
    repo_add_autopattern(repo, 0); 
#endif

  if (query)
    doquery(pool, repo, query);
  else
    tool_write(repo, basefile, attrname);
  pool_free(pool);
  exit(0);
}
