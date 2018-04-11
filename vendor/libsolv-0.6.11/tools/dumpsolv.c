/*
 * Copyright (c) 2007, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

static int with_attr;
static int dump_json;

#include "pool.h"
#include "chksum.h"
#include "repo_solv.h"


static int
dump_attr(Repo *repo, Repodata *data, Repokey *key, KeyValue *kv)
{
  const char *keyname;
  KeyValue *kvp;
  int indent = 0;

  keyname = pool_id2str(repo->pool, key->name);
  for (kvp = kv; (kvp = kvp->parent) != 0; indent += 2)
    printf("  ");
  switch(key->type)
    {
    case REPOKEY_TYPE_ID:
      if (data && data->localpool)
	kv->str = stringpool_id2str(&data->spool, kv->id);
      else
	kv->str = pool_dep2str(repo->pool, kv->id);
      printf("%s: %s\n", keyname, kv->str);
      break;
    case REPOKEY_TYPE_CONSTANTID:
      printf("%s: %s\n", keyname, pool_dep2str(repo->pool, kv->id));
      break;
    case REPOKEY_TYPE_IDARRAY:
      if (!kv->entry)
        printf("%s:\n%*s", keyname, indent, "");
      if (data && data->localpool)
        printf("  %s\n", stringpool_id2str(&data->spool, kv->id));
      else
        printf("  %s\n", pool_dep2str(repo->pool, kv->id));
      break;
    case REPOKEY_TYPE_STR:
      printf("%s: %s\n", keyname, kv->str);
      break;
    case REPOKEY_TYPE_VOID:
      printf("%s: (void)\n", keyname);
      break;
    case REPOKEY_TYPE_U32:
    case REPOKEY_TYPE_CONSTANT:
      printf("%s: %u\n", keyname, kv->num);
      break;
    case REPOKEY_TYPE_NUM:
      printf("%s: %llu\n", keyname, SOLV_KV_NUM64(kv));
      break;
    case REPOKEY_TYPE_BINARY:
      if (kv->num)
        printf("%s: %02x..%02x len %u\n", keyname, (unsigned char)kv->str[0], (unsigned char)kv->str[kv->num - 1], kv->num);
      else
        printf("%s: len 0\n", keyname);
      break;
    case REPOKEY_TYPE_DIRNUMNUMARRAY:
      if (!kv->entry)
        printf("%s:\n%*s", keyname, indent, "");
      printf("  %s %u %u\n", repodata_dir2str(data, kv->id, 0), kv->num, kv->num2);
      break;
    case REPOKEY_TYPE_DIRSTRARRAY:
      if (!kv->entry)
        printf("%s:\n%*s", keyname, indent, "");
      printf("  %s\n", repodata_dir2str(data, kv->id, kv->str));
      break;
    case REPOKEY_TYPE_FIXARRAY:
    case REPOKEY_TYPE_FLEXARRAY:
      if (!kv->entry)
        printf("%s:\n", keyname);
      else
        printf("\n");
      break;
    default:
      if (solv_chksum_len(key->type))
	{
	  printf("%s: %s (%s)\n", keyname, repodata_chk2str(data, key->type, (unsigned char *)kv->str), solv_chksum_type2str(key->type));
	  break;
	}
      printf("%s: ?\n", keyname);
      break;
    }
  return 0;
}

static const char *
jsonstring(Pool *pool, const char *s)
{
  int needed = 0;
  const unsigned char *s1;
  char *r, *rp;
  
  for (s1 = (const unsigned char *)s; *s1; s1++)
    {
      if (*s1 < 32)
	needed += *s1 == '\n' ? 2 : 6;
      else if (*s1 == '\\' || *s1 == '\"')
	needed += 2;
      else
	needed++;
    }
  r = rp = pool_alloctmpspace(pool, needed + 3);
  *rp++ = '\"';
  for (s1 = (const unsigned char *)s; *s1; s1++)
    {
      if (*s1 < 32)
	{
	  int x;
	  if (*s1 == '\n')
	    {
	      *rp++ = '\\';
	      *rp++ = 'n';
	      continue;
	    }
	  *rp++ = '\\';
	  *rp++ = 'u';
	  *rp++ = '0';
	  *rp++ = '0';
	  x = *s1 / 16;
	  *rp++ = (x < 10 ? '0' : 'a' - 10) + x;
	  x = *s1 & 15;
	  *rp++ = (x < 10 ? '0' : 'a' - 10) + x;
	}
      else if (*s1 == '\\' || *s1 == '\"')
	{
	  *rp++ = '\\';
	  *rp++ = *s1;
	}
      else
        *rp++ = *s1;
    }
  *rp++ = '\"';
  *rp = 0;
  return r;
}

struct cbdata {
  unsigned char *first;
  int nfirst;
  int baseindent;
};

static int
dump_attr_json(Repo *repo, Repodata *data, Repokey *key, KeyValue *kv, struct cbdata *cbdata)
{
  Pool *pool = repo->pool;
  const char *keyname;
  KeyValue *kvp;
  int indent = cbdata->baseindent;
  int isarray = 0;
  const char *str;
  int depth = 0;

  keyname = pool_id2str(repo->pool, key->name);
  for (kvp = kv; (kvp = kvp->parent) != 0; indent += 4)
    depth++;
  if (cbdata->nfirst < depth + 1)
    {
      cbdata->first = solv_realloc(cbdata->first, depth + 16);
      memset(cbdata->first + cbdata->nfirst, 0, depth + 16 - cbdata->nfirst);
      cbdata->nfirst = depth + 16;
    }
  switch(key->type)
    {
    case REPOKEY_TYPE_IDARRAY:
    case REPOKEY_TYPE_DIRNUMNUMARRAY:
    case REPOKEY_TYPE_DIRSTRARRAY:
      isarray = 1;
      break;
    case REPOKEY_TYPE_FIXARRAY:
    case REPOKEY_TYPE_FLEXARRAY:
      isarray = 2;
      break;
    default:
      break;
    }
  if (!isarray || !kv->entry)
    {
      if (cbdata->first[depth])
	printf(",\n");
      printf("%*s%s: ", indent, "", jsonstring(pool, keyname));
      cbdata->first[depth] = 1;
    }
  if (isarray == 1 && !kv->entry)
    printf("[\n%*s", indent + 2, "");
  else if (isarray == 1 && kv->entry)
    printf("%*s", indent + 2, "");
  switch(key->type)
    {
    case REPOKEY_TYPE_ID:
      if (data && data->localpool)
	str = stringpool_id2str(&data->spool, kv->id);
      else
	str = pool_dep2str(repo->pool, kv->id);
      printf("%s", jsonstring(pool, str));
      break;
    case REPOKEY_TYPE_CONSTANTID:
      str = pool_dep2str(repo->pool, kv->id);
      printf("%s", jsonstring(pool, str));
      break;
    case REPOKEY_TYPE_IDARRAY:
      if (data && data->localpool)
        str = stringpool_id2str(&data->spool, kv->id);
      else
        str = pool_dep2str(repo->pool, kv->id);
      printf("%s", jsonstring(pool, str));
      break;
    case REPOKEY_TYPE_STR:
      str = kv->str;
      printf("%s", jsonstring(pool, str));
      break;
    case REPOKEY_TYPE_VOID:
      printf("null");
      break;
    case REPOKEY_TYPE_U32:
    case REPOKEY_TYPE_CONSTANT:
      printf("%u", kv->num);
      break;
    case REPOKEY_TYPE_NUM:
      printf("%llu", SOLV_KV_NUM64(kv));
      break;
    case REPOKEY_TYPE_BINARY:
      printf("\"<binary>\"");
      break;
    case REPOKEY_TYPE_DIRNUMNUMARRAY:
      printf("{\n");
      printf("%*s    \"dir\": %s,\n", indent, "", jsonstring(pool, repodata_dir2str(data, kv->id, 0)));
      printf("%*s    \"num1\": %u,\n", indent, "", kv->num);
      printf("%*s    \"num2\": %u\n", indent, "", kv->num2);
      printf("%*s  }", indent, "");
      break;
    case REPOKEY_TYPE_DIRSTRARRAY:
      printf("%s", jsonstring(pool, repodata_dir2str(data, kv->id, kv->str)));
      break;
    case REPOKEY_TYPE_FIXARRAY:
    case REPOKEY_TYPE_FLEXARRAY:
      cbdata->first[depth + 1] = 0;
      if (!kv->entry)
	printf("[\n");
      else
	{
	  if (kv->eof != 2)
            printf("\n%*s  },\n", indent, "");
	  else
            printf("\n%*s  }\n", indent, "");
	}
      if (kv->eof != 2)
        printf("%*s  {\n", indent, "");
      else
        printf("%*s]", indent, "");
      break;
    default:
      if (solv_chksum_len(key->type))
	{
	  printf("{\n");
	  printf("%*s  \"value\": %s,\n", indent, "", jsonstring(pool, repodata_chk2str(data, key->type, (unsigned char *)kv->str)));
	  printf("%*s  \"type\": %s\n", indent, "", jsonstring(pool, solv_chksum_type2str(key->type)));
	  printf("%*s}", indent, "");
	  break;
	}
      printf("\"?\"");
      break;
    }
  if (isarray == 1)
    {
      if (!kv->eof)
        printf(",\n");
      else
        printf("\n%*s]", indent, "");
    }
  return 0;
}

static int
dump_repodata_cb(void *vcbdata, Solvable *s, Repodata *data, Repokey *key, KeyValue *kv)
{
  if (key->name == REPOSITORY_SOLVABLES)
    return SEARCH_NEXT_SOLVABLE;
  if (!dump_json)
    return dump_attr(data->repo, data, key, kv);
  else
    return dump_attr_json(data->repo, data, key, kv, vcbdata);
}

static void
dump_repodata(Repo *repo)
{
  int i;
  Repodata *data;
  if (repo->nrepodata == 0)
    return;
  printf("repo contains %d repodata sections:\n", repo->nrepodata - 1);
  FOR_REPODATAS(repo, i, data)
    {
      unsigned int j;
      printf("\nrepodata %d has %d keys, %d schemata\n", i, data->nkeys - 1, data->nschemata - 1);
      for (j = 1; j < data->nkeys; j++)
	printf("  %s (type %s size %d storage %d)\n", pool_id2str(repo->pool, data->keys[j].name), pool_id2str(repo->pool, data->keys[j].type), data->keys[j].size, data->keys[j].storage);
      if (data->localpool)
	printf("  localpool has %d strings, size is %d\n", data->spool.nstrings, data->spool.sstrings);
      if (data->dirpool.ndirs)
	printf("  localpool has %d directories\n", data->dirpool.ndirs);
      printf("\n");
      repodata_search(data, SOLVID_META, 0, SEARCH_ARRAYSENTINEL|SEARCH_SUB, dump_repodata_cb, 0);
    }
  printf("\n");
}

static void
dump_repodata_json(Repo *repo, struct cbdata *cbdata)
{
  int i;
  Repodata *data;
  if (repo->nrepodata == 0)
    return;
  cbdata->baseindent = 6;
  FOR_REPODATAS(repo, i, data)
    repodata_search(data, SOLVID_META, 0, SEARCH_ARRAYSENTINEL|SEARCH_SUB, dump_repodata_cb, cbdata);
}

/*
 * dump all attributes for Id <p>
 */

void
dump_solvable(Repo *repo, Id p, struct cbdata *cbdata)
{
  Dataiterator di;
  dataiterator_init(&di, repo->pool, repo, p, 0, 0, SEARCH_ARRAYSENTINEL|SEARCH_SUB);
  if (cbdata && cbdata->first)
    cbdata->first[0] = 0;
  if (cbdata)
    cbdata->baseindent = 10;
  while (dataiterator_step(&di))
    {
      if (!dump_json)
        dump_attr(repo, di.data, di.key, &di.kv);
      else
        dump_attr_json(repo, di.data, di.key, &di.kv, cbdata);
    }
  dataiterator_free(&di);
}

static int
loadcallback(Pool *pool, Repodata *data, void *vdata)
{
  FILE *fp = 0;
  int r;
  const char *location;

  location = repodata_lookup_str(data, SOLVID_META, REPOSITORY_LOCATION);
  if (!location || !with_attr)
    return 0;
  fprintf(stderr, "[Loading SOLV file %s]\n", location);
  fp = fopen (location, "r");
  if (!fp)
    {
      perror(location);
      return 0;
    }
  r = repo_add_solv(data->repo, fp, REPO_USE_LOADING|REPO_LOCALPOOL);
  fclose(fp);
  return !r ? 1 : 0;
}


static void
usage(int status)
{
  fprintf( stderr, "\nUsage:\n"
	   "dumpsolv [-a] [-j] [<solvfile>]\n"
	   "  -a  read attributes.\n"
	   "  -j  dump json format.\n"
	   );
  exit(status);
}

int main(int argc, char **argv)
{
  Repo *repo;
  Pool *pool;
  int c, i, j, n;
  Solvable *s;
  
  pool = pool_create();
  pool_setloadcallback(pool, loadcallback, 0);

  while ((c = getopt(argc, argv, "haj")) >= 0)
    {
      switch(c)
	{
	case 'h':
	  usage(0);
	  break;
	case 'a':
	  with_attr = 1;
	  break;
	case 'j':
	  dump_json = 1;
	  break;
	default:
          usage(1);
          break;
	}
    }
  if (!dump_json)
    pool_setdebuglevel(pool, 1);
  if (dump_json)
    pool->debugmask |= SOLV_DEBUG_TO_STDERR;
  for (; optind < argc; optind++)
    {
      if (freopen(argv[optind], "r", stdin) == 0)
	{
	  perror(argv[optind]);
	  exit(1);
	}
      repo = repo_create(pool, argv[optind]);
      if (repo_add_solv(repo, stdin, 0))
	{
	  fprintf(stderr, "could not read repository: %s\n", pool_errstr(pool));
	  exit(1);
	}
    }
  if (!pool->urepos)
    {
      repo = repo_create(pool, argc != 1 ? argv[1] : "<stdin>");
      if (repo_add_solv(repo, stdin, 0))
	{
	  fprintf(stderr, "could not read repository: %s\n", pool_errstr(pool));
	  exit(1);
	}
    }

  if (dump_json)
    {
      int openrepo = 0;
      struct cbdata cbdata;

      memset(&cbdata, 0, sizeof(cbdata));
      printf("{\n");
      printf("  \"repositories\": [\n");
      FOR_REPOS(j, repo)
	{
	  int open = 0;

	  if (openrepo)
	    printf("\n    },");
	  printf("    {\n");
	  openrepo = 1;
	  if (cbdata.first)
	    cbdata.first[0] = 0;
	  dump_repodata_json(repo, &cbdata);
	  if (cbdata.first[0])
	    printf(",\n");
	  printf("      \"solvables\": [\n");
	  FOR_REPO_SOLVABLES(repo, i, s)
	    {
	      if (open)
		printf("\n        },\n");
	      printf("        {\n");
	      open = 1;
	      dump_solvable(repo, i, &cbdata);
	    }
	  if (open)
	    printf("\n        }\n");
	  printf("      ]\n");
	}
      if (openrepo)
	printf("    }\n");
      printf("  ]\n");
      printf("}\n");
      solv_free(cbdata.first);
    }
  else
    {
      printf("pool contains %d strings, %d rels, string size is %d\n", pool->ss.nstrings, pool->nrels, pool->ss.sstrings);
      n = 0;
      FOR_REPOS(j, repo)
	{
	  dump_repodata(repo);
	  printf("repo %d contains %d solvables\n", j, repo->nsolvables);
	  printf("repo start: %d end: %d\n", repo->start, repo->end);
	  FOR_REPO_SOLVABLES(repo, i, s)
	    {
	      n++;
	      printf("\n");
	      printf("solvable %d (%d):\n", n, i);
	      dump_solvable(repo, i, 0);
	    }
	}
    }
  pool_free(pool);
  exit(0);
}
