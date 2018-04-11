/*
 * Copyright (c) 2007, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * rpms2solv - create a solv file from multiple rpms
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
#include "repo_rpmdb.h"
#ifdef ENABLE_PUBKEY
#include "repo_pubkey.h"
#include "solv_xfopen.h"
#endif
#include "repo_solv.h"
#ifdef SUSE
#include "repo_autopattern.h"
#endif
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
  const char **rpms = 0;
  char *manifest = 0;
  int manifest0 = 0;
  int c, i, res, nrpms = 0;
  Pool *pool = pool_create();
  Repo *repo;
  FILE *fp;
  char buf[4096], *p;
  const char *basefile = 0;
#ifdef ENABLE_PUBKEY
  int pubkeys = 0;
#endif
#ifdef SUSE
  int add_auto = 0;
#endif
  int filtered_filelist = 0;

  while ((c = getopt(argc, argv, "0XkKb:m:F")) >= 0)
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
	case 'F':
	  filtered_filelist = 1;
	  break;
#ifdef ENABLE_PUBKEY
	case 'k':
	  pubkeys = 1;
	  break;
	case 'K':
	  pubkeys = 2;
	  break;
#endif
	case 'X':
#ifdef SUSE
	  add_auto = 1;
#endif
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
          rpms = solv_extend(rpms, nrpms, 1, sizeof(char *), 15);
	  rpms[nrpms++] = strdup(buf);
	}
      if (fp != stdin)
        fclose(fp);
    }
  while (optind < argc)
    {
      rpms = solv_extend(rpms, nrpms, 1, sizeof(char *), 15);
      rpms[nrpms++] = strdup(argv[optind++]);
    }
  repo = repo_create(pool, "rpms2solv");
  repo_add_repodata(repo, 0);
  res = 0;
  for (i = 0; i < nrpms; i++)
    {
#ifdef ENABLE_PUBKEY
      if (pubkeys == 2)
	{
	  FILE *fp = solv_xfopen(rpms[i], "r");
	  if (!fp)
	    {
	      perror(rpms[i]);
	      res = 1;
	      continue;
	    }
	  if (repo_add_keyring(repo, fp, REPO_REUSE_REPODATA|REPO_NO_INTERNALIZE|ADD_WITH_KEYSIGNATURES))
	    {
	      fprintf(stderr, "rpms2solv: %s\n", pool_errstr(pool));
	      res = 1;
	    }
	  fclose(fp);
	  continue;
	}
      if (pubkeys)
        {
	  if (repo_add_pubkey(repo, rpms[i], REPO_REUSE_REPODATA|REPO_NO_INTERNALIZE|ADD_WITH_KEYSIGNATURES) == 0)
	    {
	      fprintf(stderr, "rpms2solv: %s\n", pool_errstr(pool));
	      res = 1;
	    }
	  continue;
        }
#endif
      if (repo_add_rpm(repo, rpms[i], REPO_REUSE_REPODATA|REPO_NO_INTERNALIZE|(filtered_filelist ? RPM_ADD_FILTERED_FILELIST : 0)) == 0)
	{
	  fprintf(stderr, "rpms2solv: %s\n", pool_errstr(pool));
	  res = 1;
	}
    }
  repo_internalize(repo);
#ifdef SUSE
  if (add_auto)
    repo_add_autopattern(repo, 0);
#endif
  tool_write(repo, basefile, 0);
  pool_free(pool);
  for (c = 0; c < nrpms; c++)
    free((char *)rpms[c]);
  solv_free(rpms);
  exit(res);
}

