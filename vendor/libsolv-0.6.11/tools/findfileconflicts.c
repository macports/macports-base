/* vim: sw=2 et
 */

#include <stdio.h>
#include <stdlib.h>

#include "pool.h"
#include "repo.h"
#include "solver.h"
#include "solverdebug.h"
#include "hash.h"
#include "repo_rpmdb.h"
#include "pool_fileconflicts.h"

static void *
iterate_handle(Pool *pool, Id p, void *cbdata)
{
  Solvable *s = pool->solvables + p;
  Id rpmdbid;
  void *handle;
  
  if (!s->repo->rpmdbid)
    return 0;
  rpmdbid = s->repo->rpmdbid[p - s->repo->start];
  if (!rpmdbid)
    return 0;
  handle = rpm_byrpmdbid(cbdata, rpmdbid);
  if (!handle)
    fprintf(stderr, "rpm_byrpmdbid: %s\n", pool_errstr(pool));
  return handle;
}

int main(int argc, char **argv)
{
  Pool *pool;
  Repo *installed;
  Solvable *s;
  Id p;
  int i;
  Queue todo, conflicts;
  void *state = 0;
  char *rootdir = 0;
 
  if (argc == 3 && !strcmp(argv[1], "--root"))
    rootdir = argv[2];
  pool = pool_create();
  if (rootdir)
    pool_set_rootdir(pool, rootdir);
  pool_setdebuglevel(pool, 1);
  installed = repo_create(pool, "@System");
  pool_set_installed(pool, installed);
  if (repo_add_rpmdb(installed, 0, REPO_USE_ROOTDIR))
    {
      fprintf(stderr, "findfileconflicts: %s\n", pool_errstr(pool));
      exit(1);
    }
  queue_init(&todo);
  queue_init(&conflicts);
  FOR_REPO_SOLVABLES(installed, p, s)
    queue_push(&todo, p);
  state = rpm_state_create(pool, pool_get_rootdir(pool));
  pool_findfileconflicts(pool, &todo, 0, &conflicts, FINDFILECONFLICTS_USE_SOLVABLEFILELIST | FINDFILECONFLICTS_CHECK_DIRALIASING | FINDFILECONFLICTS_USE_ROOTDIR, &iterate_handle, state);
  rpm_state_free(state);
  queue_free(&todo);
  for (i = 0; i < conflicts.count; i += 6)
    {
      if (conflicts.elements[i] != conflicts.elements[i + 3])
        printf("%s - %s: %s[%s] %s[%s]\n", pool_id2str(pool, conflicts.elements[i]), pool_id2str(pool, conflicts.elements[i + 3]), pool_solvid2str(pool, conflicts.elements[i + 1]), pool_id2str(pool, conflicts.elements[i + 2]), pool_solvid2str(pool, conflicts.elements[i + 4]), pool_id2str(pool, conflicts.elements[i + 5]));
      else
        printf("%s: %s[%s] %s[%s]\n", pool_id2str(pool, conflicts.elements[i]), pool_solvid2str(pool, conflicts.elements[i + 1]), pool_id2str(pool, conflicts.elements[i + 2]), pool_solvid2str(pool, conflicts.elements[i + 4]), pool_id2str(pool, conflicts.elements[i + 5]));
    }
  if (conflicts.count)
    {
      Queue job;
      int problemcnt;

      queue_init(&job);
      pool_add_fileconflicts_deps(pool, &conflicts);
      pool_addfileprovides(pool);
      pool_createwhatprovides(pool);
      pool_setdebuglevel(pool, 0);
      Solver *solv = solver_create(pool);
      queue_push2(&job, SOLVER_VERIFY|SOLVER_SOLVABLE_ALL, 0);
#if 0
      solver_set_flag(solv, SOLVER_FLAG_ALLOW_UNINSTALL, 1);
#endif
      problemcnt = solver_solve(solv, &job);
      if (problemcnt)
        solver_printallsolutions(solv);
      else
	{
	  Transaction *trans = solver_create_transaction(solv);
          transaction_print(trans);
          transaction_free(trans);
	}
      queue_free(&job);
      solver_free(solv);
    }
  queue_free(&conflicts);
  exit(0);
}
