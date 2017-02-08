/*
 * Copyright (c) 2013, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * appdata2solv.c
 * 
 * parse AppStream appdata type xml and write out .solv file
 *
 * reads from stdin
 * writes to stdout
 */

#include <sys/types.h>
#include <limits.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "pool.h"
#include "repo.h"
#include "repo_appdata.h"
#include "common_write.h"

int
main(int argc, char **argv)
{
  Pool *pool = pool_create();
  Repo *repo;
  int c;
  const char *appdatadir = 0;
  const char *root = 0;

  while ((c = getopt(argc, argv, "hd:r:")) >= 0)
    {
      switch (c)
	{
	case 'd':
	  appdatadir = optarg;
	  break;
	case 'r':
	  root = optarg;
	  break;
	default:
	  fprintf(stderr, "usage: appdata2solv [-d appdatadir]");
	  exit(c == 'h' ? 0 : 1);
	}
    }

  if (root)
    pool_set_rootdir(pool, root);
    
  repo = repo_create(pool, "<stdin>");
  if (!appdatadir)
    {
      if (repo_add_appdata(repo, stdin, 0))
	{
	  fprintf(stderr, "appdata2solv: %s\n", pool_errstr(pool));
	  exit(1);
	}
    }
  else
    {
      if (repo_add_appdata_dir(repo, appdatadir, REPO_USE_ROOTDIR))
	{
	  fprintf(stderr, "appdata2solv: %s\n", pool_errstr(pool));
	  exit(1);
	}
    }
  tool_write(repo, 0, 0);
  pool_free(pool);
  exit(0);
}
