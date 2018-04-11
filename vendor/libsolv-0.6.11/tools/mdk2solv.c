/*
 * Copyright (c) 2012, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * mdk2solv.c
 *
 * parse Mandriva/Mageie synthesis file
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
#include "repo_mdk.h"
#include "solv_xfopen.h"
#include "common_write.h"


static void
usage(int status)
{
  fprintf(stderr, "\nUsage:\n"
          "mdk2solv [-i <infoxml>]\n"
          "  reads a 'synthesis' repository from <stdin> and writes a .solv file to <stdout>\n"
          "  -i : info.xml file for extra attributes\n"
          "  -f : files.xml file for extra attributes\n"
          "  -h : print help & exit\n"
         );
   exit(status);
}

int
main(int argc, char **argv)
{
  Pool *pool;
  Repo *repo;
  char *infofile = 0, *filesfile = 0;
  int c;

  while ((c = getopt(argc, argv, "hi:f:")) >= 0)
    {
      switch(c)
	{
	case 'h':
	  usage(0);
	  break;
	case 'i':
	  infofile = optarg;
	  break;
	case 'f':
	  filesfile = optarg;
	  break;
	default:
	  usage(1);
	  break;
	}
    }
  pool = pool_create();
  repo = repo_create(pool, "<stdin>");
  if (repo_add_mdk(repo, stdin, REPO_NO_INTERNALIZE))
    {
      fprintf(stderr, "mdk2solv: %s\n", pool_errstr(pool));
      exit(1);
    }
  if (infofile)
    {
      FILE *fp = solv_xfopen(infofile, "r");
      if (!fp)
	{
	  perror(infofile);
	  exit(1);
	}
      if (repo_add_mdk_info(repo, fp, REPO_EXTEND_SOLVABLES | REPO_REUSE_REPODATA | REPO_NO_INTERNALIZE))
	{
	  fprintf(stderr, "mdk2solv: %s\n", pool_errstr(pool));
	  exit(1);
	}
      fclose(fp);
    }
  if (filesfile)
    {
      FILE *fp = solv_xfopen(filesfile, "r");
      if (!fp)
	{
	  perror(filesfile);
	  exit(1);
	}
      if (repo_add_mdk_info(repo, fp, REPO_EXTEND_SOLVABLES | REPO_REUSE_REPODATA | REPO_NO_INTERNALIZE))
	{
	  fprintf(stderr, "mdk2solv: %s\n", pool_errstr(pool));
	  exit(1);
	}
      fclose(fp);
    }
  repo_internalize(repo);
  tool_write(repo, 0, 0);
  pool_free(pool);
  exit(0);
}
