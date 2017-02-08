/*
 * Copyright (c) 2007, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * deb2solv - create a solv file from one or multiple debs
 * 
 */

#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include "util.h"
#include "pool.h"
#include "repo.h"
#include "repo_deb.h"
#include "repo_solv.h"
#include "common_write.h"

static char *
fgets0(char *s, int size, FILE *stream)
{
  char *p = s;
  int c;

  while (--size > 0)
    {
      c = getc(stream);
      if (c == EOF)
	{
	  if (p == s)
	    return 0;
	  c = 0;
	}
      *p++ = c;
      if (!c)
	return s;
    }
  *p = 0;
  return s;
}

int
main(int argc, char **argv)
{
  const char **debs = 0;
  char *manifest = 0;
  int manifest0 = 0;
  int c, i, res, ndebs = 0;
  Pool *pool = pool_create();
  Repo *repo;
  FILE *fp;
  char buf[4096], *p;
  const char *basefile = 0;

  while ((c = getopt(argc, argv, "0b:m:")) >= 0)
    {
      switch(c)
	{
	case 'b':
	  basefile = optarg;
	  break;
	case 'm':
	  manifest = optarg;
	  break;
	case '0':
	  manifest0 = 1;
	  break;
	default:
	  exit(1);
	}
    }
  if (manifest)
    {
      if (!strcmp(manifest, "-"))
        fp = stdin;
      else if ((fp = fopen(manifest, "r")) == 0)
	{
	  perror(manifest);
	  exit(1);
	}
      for (;;)
	{
	  if (manifest0)
	    {
	      if (!fgets0(buf, sizeof(buf), fp))
		break;
	    }
	  else
	    {
	      if (!fgets(buf, sizeof(buf), fp))
		break;
	      if ((p = strchr(buf, '\n')) != 0)
		*p = 0;
	    }
          debs = solv_extend(debs, ndebs, 1, sizeof(char *), 15);
	  debs[ndebs++] = strdup(buf);
	}
      if (fp != stdin)
        fclose(fp);
    }
  while (optind < argc)
    {
      debs = solv_extend(debs, ndebs, 1, sizeof(char *), 15);
      debs[ndebs++] = strdup(argv[optind++]);
    }
  repo = repo_create(pool, "deb2solv");
  repo_add_repodata(repo, 0);
  res = 0;
  for (i = 0; i < ndebs; i++)
    {
      if (repo_add_deb(repo, debs[i], REPO_REUSE_REPODATA|REPO_NO_INTERNALIZE) == 0)
	{
	  fprintf(stderr, "deb2solv: %s\n", pool_errstr(pool));
	  res = 1;
	}
    }
  repo_internalize(repo);
  tool_write(repo, basefile, 0);
  pool_free(pool);
  for (c = 0; c < ndebs; c++)
    free((char *)debs[c]);
  solv_free(debs);
  exit(res);
}

