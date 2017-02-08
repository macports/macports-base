/*
 * Copyright (c) 2007, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * helix2solv.c
 * 
 * parse 'helix' type xml and write out .solv file
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

#include "pool.h"
#include "repo_helix.h"
#include "common_write.h"

int
main(int argc, char **argv)
{
  Pool *pool = pool_create();
  Repo *repo = repo_create(pool, "<stdin>");
  if (repo_add_helix(repo, stdin, 0))
    {
      fprintf(stderr, "helix2solv: %s\n", pool_errstr(pool));
      exit(1);
    }
  tool_write(repo, 0, 0);
  pool_free(pool);
  exit(0);
}
