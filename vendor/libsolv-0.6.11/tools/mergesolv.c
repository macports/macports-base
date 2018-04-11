/*
 * Copyright (c) 2007, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * mergesolv
 * 
 */

#include <sys/types.h>
#include <unistd.h>
#include <limits.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "pool.h"
#include "repo_solv.h"
#ifdef SUSE
#include "repo_autopattern.h"
#endif
#include "common_write.h"

static void
usage()
{
  fprintf(stderr, "\nUsage:\n"
	  "mergesolv [file] [file] [...]\n"
	  "  merges multiple solv files into one and writes it to stdout\n"
	  );
  exit(0);
}

static int
loadcallback (Pool *pool, Repodata *data, void *vdata)
{
  FILE *fp;
  const char *location = repodata_lookup_str(data, SOLVID_META, REPOSITORY_LOCATION);
  int r;

  if (!location)
    return 0;
  fprintf(stderr, "Loading SOLV file %s\n", location);
  fp = fopen (location, "r");
  if (!fp)
    {
      perror(location);
      return 0;
    }
  r = repo_add_solv(data->repo, fp, REPO_USE_LOADING|REPO_LOCALPOOL);
  fclose(fp);
  return r ? 0 : 1;
}

int
main(int argc, char **argv)
{
  Pool *pool;
  Repo *repo;
  const char *basefile = 0;
  int with_attr = 0;
#ifdef SUSE
  int add_auto = 0;
#endif
  int c;

  pool = pool_create();
  repo = repo_create(pool, "<mergesolv>");
  
  while ((c = getopt(argc, argv, "ahb:X")) >= 0)
    {
      switch (c)
      {
	case 'h':
	  usage();
	  break;
	case 'a':
	  with_attr = 1;
	  break;
	case 'b':
	  basefile = optarg;
	  break;
	case 'X':
#ifdef SUSE
	  add_auto = 1;
#endif
	  break;
	default:
	  usage();
	  exit(1);
      }
    }
  if (with_attr)
    pool_setloadcallback(pool, loadcallback, 0);

  for (; optind < argc; optind++)
    {
      FILE *fp;
      if ((fp = fopen(argv[optind], "r")) == NULL)
	{
	  perror(argv[optind]);
	  exit(1);
	}
      if (repo_add_solv(repo, fp, 0))
	{
	  fprintf(stderr, "repo %s: %s\n", argv[optind], pool_errstr(pool));
	  exit(1);
	}
      fclose(fp);
    }
#ifdef SUSE
  if (add_auto)
    repo_add_autopattern(repo, 0);
#endif
  tool_write(repo, basefile, 0);
  pool_free(pool);
  return 0;
}
