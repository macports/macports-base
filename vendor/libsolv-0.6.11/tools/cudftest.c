#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "pool.h"
#include "evr.h"
#include "solver.h"
#include "solverdebug.h"
#include "repo_cudf.h"
#include "repo_write.h"
#include "solv_xfopen.h"

static void
dump_repo(Repo *repo, char *name)
{
  FILE *fp;
  if ((fp = fopen(name, "w")) == 0)
    {
      perror(name);
      exit(1);
    }
  repo_write(repo, fp);
  fclose(fp);
}

static int
sortfunc(const void *ap, const void *bp, void *dp)
{
  Pool *pool = dp;
  Solvable *sa, *sb;
  sa = pool->solvables + *(Id *)ap;
  sb = pool->solvables + *(Id *)bp;
  if (sa->name != sb->name)
    {
      int r = strcmp(pool_id2str(pool, sa->name), pool_id2str(pool, sb->name));
      if (r)
	return r;
    }
  if (sa->evr != sb->evr)
    {
      int r = pool_evrcmp(pool, sa->evr, sb->evr, EVRCMP_COMPARE);
      if (r)
	return r;
    }
  return *(Id *)ap - *(Id *)bp;
}

int
main(int argc, char **argv)
{
  char *cudfin;
  char *cudfout = 0;
  Pool *pool;
  Repo *installed, *repo;
  FILE *fp, *ofp;
  Solver *solv;
  Transaction *trans;
  Queue job;
  Queue dq;
  int i;
  int debug = 0;

  while (argc > 1 && !strcmp(argv[1], "-d"))
    {
      debug++;
      argc--;
      argv++;
    }
  if (argc < 2)
    {
      fprintf(stderr, "Usage: cudftest <cudfin> [cudfout]\n");
      exit(1);
    }
  cudfin = argv[1];
  cudfout = argc > 2 ? argv[2] : 0;

  if ((fp = solv_xfopen(cudfin, 0)) == 0)
    {
      perror(cudfin);
      exit(1);
    }
  pool = pool_create();
  if (debug > 1)
    pool_setdebuglevel(pool, debug - 1);
  installed = repo_create(pool, "installed");
  pool_set_installed(pool, installed);
  repo = repo_create(pool, "repo");
  queue_init(&job);
  repo_add_cudf(repo, installed, fp, &job, 0);
  fclose(fp);

  pool_createwhatprovides(pool);

  /* debug */
  if (debug)
    {
      dump_repo(installed, "cudf_installed.solv");
      dump_repo(repo, "cudf_repo.solv");
    }

  solv = solver_create(pool);
  solver_set_flag(solv, SOLVER_FLAG_ALLOW_UNINSTALL, 1);
  /* solver_set_flag(solv, SOLVER_FLAG_IGNORE_RECOMMENDED, 1); */

  queue_push2(&job, SOLVER_VERIFY | SOLVER_SOLVABLE_ALL, 0);
  if (solver_solve(solv, &job) != 0)
    {
      int problem;
      int pcnt = solver_problem_count(solv);
      printf("Found %d problems:\n", pcnt);
      for (problem = 1; problem <= pcnt; problem++)
        {
          printf("Problem %d:\n", problem);
          solver_printprobleminfo(solv, problem);
          printf("\n");
	}
    }
  trans = solver_create_transaction(solv);
  solver_free(solv);

  if (debug)
    transaction_print(trans);

  queue_init(&dq);
  transaction_installedresult(trans, &dq);
  solv_sort(dq.elements, dq.count, sizeof(Id), sortfunc, pool);

  ofp = stdout;
  if (cudfout && ((ofp = fopen(cudfout, "w")) == 0))
    {
      perror(cudfout);
      exit(1);
    }
  for (i = 0; i < dq.count; i++)
    {
      Solvable *s = pool_id2solvable(pool, dq.elements[i]);
      fprintf(ofp, "package: %s\n", pool_id2str(pool, s->name));
      fprintf(ofp, "version: %s\n", pool_id2str(pool, s->evr));
      fprintf(ofp, "installed: true\n");
      if (s->repo == pool->installed)
        fprintf(ofp, "was-installed: true\n");
      fprintf(ofp, "\n");
    }
  queue_free(&dq);
  transaction_free(trans);
  queue_free(&job);
  pool_free(pool);
  if (ofp != stdout)
    {
      if (fclose(ofp))
	{
	  perror("fclose");
	  exit(1);
	}
    }
  exit(0);
}

