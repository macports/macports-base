/*
 * Copyright (c) 2007, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
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
#include "repo_diskusagexml.h"
#include "common_write.h"

static void
usage(int status)
{
  fprintf(stderr, "\nUsage:\n"
          "diskusagexml2solv [-a][-h][-n <attrname>]\n"
	  "  reads a 'diskusage.xml' file from <stdin> and writes a .solv file to <stdout>\n"
	  "  -h : print help & exit\n"
	  "  -n <name>: save attributes as <name>.attr\n"
	 );
  exit(status);
}

int
main(int argc, char **argv)
{
  int c, flags = 0;
  char *attrname = 0;
  
  Pool *pool = pool_create();
  Repo *repo = repo_create(pool, "<stdin>");

  while ((c = getopt(argc, argv, "hn:")) >= 0)
    {   
      switch(c)
	{
	case 'h':
	  usage(0);
	  break;
	case 'n':
	  attrname = optarg;
	  break;
	default:
	  usage(1);
	  break;
	}
    }
  if (repo_add_diskusagexml(repo, stdin, flags))
    {
      fprintf(stderr, "diskusagexml2solv: %s\n", pool_errstr(pool));
      exit(1);
    }
  tool_write(repo, 0, attrname);
  pool_free(pool);
  exit(0);
}
