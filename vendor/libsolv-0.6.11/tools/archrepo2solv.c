/*
 * Copyright (c) 2012, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * archrepo2solv.c
 *
 * parse archlinux repo file
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
#include <getopt.h>

#include "pool.h"
#include "repo.h"
#include "repo_arch.h"
#include "solv_xfopen.h"
#include "common_write.h"


static void
usage(int status)
{
  fprintf(stderr, "\nUsage:\n"
          "archrepo2solv\n"
          "  reads a repository from <stdin> and writes a .solv file to <stdout>\n"
          "  -l <dbdir> : read local database\n"
          "  -h : print help & exit\n"
         );
   exit(status);
}

int
main(int argc, char **argv)
{
  Pool *pool;
  Repo *repo;
  int c, ret;
  const char *localdb = 0;

  while ((c = getopt(argc, argv, "hl:")) >= 0)
    {
      switch(c)
	{
	case 'h':
	  usage(0);
	  break;
	case 'l':
	  localdb = optarg;
	  break;
	default:
	  usage(1);
	  break;
	}
    }
  pool = pool_create();
  repo = repo_create(pool, "<stdin>");
  if (localdb)
    ret = repo_add_arch_local(repo, localdb, 0);
  else
    ret = repo_add_arch_repo(repo, stdin, 0);
  if (ret)
    {
      fprintf(stderr, "archrepo2solv: %s\n", pool_errstr(pool));
      exit(1);
    }
  tool_write(repo, 0, 0);
  pool_free(pool);
  exit(0);
}
