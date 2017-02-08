/*
 * repo_zyppdb.c
 *
 * Parses legacy /var/lib/zypp/db/products/... files.
 * They are old (pre Code11) product descriptions. See bnc#429177
 *
 *
 * Copyright (c) 2008, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <limits.h>
#include <fcntl.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <dirent.h>
#include <expat.h>
#include <errno.h>

#include "pool.h"
#include "repo.h"
#include "util.h"
#define DISABLE_SPLIT
#include "tools_util.h"
#include "repo_zyppdb.h"


enum state {
  STATE_START,
  STATE_PRODUCT,
  STATE_NAME,
  STATE_VERSION,
  STATE_ARCH,
  STATE_SUMMARY,
  STATE_VENDOR,
  STATE_INSTALLTIME,
  NUMSTATES
};

struct stateswitch {
  enum state from;
  char *ename;
  enum state to;
  int docontent;
};

/* !! must be sorted by first column !! */
static struct stateswitch stateswitches[] = {
  { STATE_START,     "product",       STATE_PRODUCT,       0 },
  { STATE_PRODUCT,   "name",          STATE_NAME,          1 },
  { STATE_PRODUCT,   "version",       STATE_VERSION,       0 },
  { STATE_PRODUCT,   "arch",          STATE_ARCH,          1 },
  { STATE_PRODUCT,   "summary",       STATE_SUMMARY,       1 },
  { STATE_PRODUCT,   "install-time",  STATE_INSTALLTIME,   1 },
  { STATE_PRODUCT,   "vendor",        STATE_VENDOR,        1 },
  { NUMSTATES }
};

struct parsedata {
  int depth;
  enum state state;
  int statedepth;
  char *content;
  int lcontent;
  int acontent;
  int docontent;
  Pool *pool;
  Repo *repo;
  Repodata *data;

  struct stateswitch *swtab[NUMSTATES];
  enum state sbtab[NUMSTATES];
  struct joindata jd;

  const char *tmplang;

  Solvable *solvable;
  Id handle;
};


/*
 * find_attr
 * find value for xml attribute
 * I: txt, name of attribute
 * I: atts, list of key/value attributes
 * O: pointer to value of matching key, or NULL
 *
 */

static inline const char *
find_attr(const char *txt, const char **atts)
{
  for (; *atts; atts += 2)
    {
      if (!strcmp(*atts, txt))
        return atts[1];
    }
  return 0;
}


/*
 * XML callback: startElement
 */

static void XMLCALL
startElement(void *userData, const char *name, const char **atts)
{
  struct parsedata *pd = userData;
  Pool *pool = pd->pool;
  Solvable *s = pd->solvable;
  struct stateswitch *sw;

#if 0
  fprintf(stderr, "start: [%d]%s\n", pd->state, name);
#endif
  if (pd->depth != pd->statedepth)
    {
      pd->depth++;
      return;
    }

  pd->depth++;
  if (!pd->swtab[pd->state])	/* no statetable -> no substates */
    {
#if 0
      fprintf(stderr, "into unknown: %s (from: %d)\n", name, pd->state);
#endif
      return;
    }
  for (sw = pd->swtab[pd->state]; sw->from == pd->state; sw++)  /* find name in statetable */
    if (!strcmp(sw->ename, name))
      break;

  if (sw->from != pd->state)
    {
#if 0
      fprintf(stderr, "into unknown: %s (from: %d)\n", name, pd->state);
#endif
      return;
    }
  pd->state = sw->to;
  pd->docontent = sw->docontent;
  pd->statedepth = pd->depth;
  pd->lcontent = 0;
  *pd->content = 0;

  switch(pd->state)
    {
    case STATE_PRODUCT:
      {
	/* parse 'type' */
	const char *type = find_attr("type", atts);
	s = pd->solvable = pool_id2solvable(pool, repo_add_solvable(pd->repo));
	pd->handle = s - pool->solvables;
	if (type)
	  repodata_set_str(pd->data, pd->handle, PRODUCT_TYPE, type);
      }
      break;
    case STATE_VERSION:
      {
	const char *ver = find_attr("ver", atts);
	const char *rel = find_attr("rel", atts);
	/* const char *epoch = find_attr("epoch", atts); ignored */
	s->evr = makeevr(pd->pool, join2(&pd->jd, ver, "-", rel));
      }
      break;
      /* <summary lang="xy">... */
    case STATE_SUMMARY:
      pd->tmplang = join_dup(&pd->jd, find_attr("lang", atts));
      break;
    default:
      break;
    }
}


static void XMLCALL
endElement(void *userData, const char *name)
{
  struct parsedata *pd = userData;
  Solvable *s = pd->solvable;

#if 0
  fprintf(stderr, "end: [%d]%s\n", pd->state, name);
#endif
  if (pd->depth != pd->statedepth)
    {
      pd->depth--;
#if 0
      fprintf(stderr, "back from unknown %d %d %d\n", pd->state, pd->depth, pd->statedepth);
#endif
      return;
    }

  pd->depth--;
  pd->statedepth--;

  switch (pd->state)
    {
    case STATE_PRODUCT:
      if (!s->arch)
	s->arch = ARCH_NOARCH;
      if (!s->evr)
	s->evr = ID_EMPTY;
      if (s->name && s->arch != ARCH_SRC && s->arch != ARCH_NOSRC)
	s->provides = repo_addid_dep(pd->repo, s->provides, pool_rel2id(pd->pool, s->name, s->evr, REL_EQ, 1), 0);
      pd->solvable = 0;
      break;
    case STATE_NAME:
      s->name = pool_str2id(pd->pool, join2(&pd->jd, "product", ":", pd->content), 1);
      break;
    case STATE_ARCH:
      s->arch = pool_str2id(pd->pool, pd->content, 1);
      break;
    case STATE_SUMMARY:
      repodata_set_str(pd->data, pd->handle, pool_id2langid(pd->pool, SOLVABLE_SUMMARY, pd->tmplang, 1), pd->content);
      break;
    case STATE_VENDOR:
      s->vendor = pool_str2id(pd->pool, pd->content, 1);
      break;
    case STATE_INSTALLTIME:
      repodata_set_num(pd->data, pd->handle, SOLVABLE_INSTALLTIME, atol(pd->content));
    default:
      break;
    }

  pd->state = pd->sbtab[pd->state];
  pd->docontent = 0;

#if 0
  fprintf(stderr, "end: [%s] -> %d\n", name, pd->state);
#endif
}


static void XMLCALL
characterData(void *userData, const XML_Char *s, int len)
{
  struct parsedata *pd = userData;
  int l;
  char *c;
  if (!pd->docontent)
    return;
  l = pd->lcontent + len + 1;
  if (l > pd->acontent)
    {
      pd->content = realloc(pd->content, l + 256);
      pd->acontent = l + 256;
    }
  c = pd->content + pd->lcontent;
  pd->lcontent += len;
  while (len-- > 0)
    *c++ = *s++;
  *c = 0;
}

#define BUFF_SIZE 8192


/*
 * add single product to repo
 *
 */

static void
add_zyppdb_product(struct parsedata *pd, FILE *fp)
{
  char buf[BUFF_SIZE];
  int l;

  XML_Parser parser = XML_ParserCreate(NULL);
  XML_SetUserData(parser, pd);
  XML_SetElementHandler(parser, startElement, endElement);
  XML_SetCharacterDataHandler(parser, characterData);

  for (;;)
    {
      l = fread(buf, 1, sizeof(buf), fp);
      if (XML_Parse(parser, buf, l, l == 0) == XML_STATUS_ERROR)
	{
	  pool_debug(pd->pool, SOLV_ERROR, "repo_zyppdb: %s at line %u:%u\n", XML_ErrorString(XML_GetErrorCode(parser)), (unsigned int)XML_GetCurrentLineNumber(parser), (unsigned int)XML_GetCurrentColumnNumber(parser));
	  if (pd->solvable)
	    {
	      repo_free_solvable(pd->repo, pd->solvable - pd->pool->solvables, 1);
	      pd->solvable = 0;
	    }
	  return;
	}
      if (l == 0)
	break;
    }
  XML_ParserFree(parser);
}


/*
 * read all installed products
 *
 * parse each one as a product
 */

int
repo_add_zyppdb_products(Repo *repo, const char *dirpath, int flags)
{
  int i;
  struct parsedata pd;
  struct stateswitch *sw;
  struct dirent *entry;
  char *fullpath;
  DIR *dir;
  FILE *fp;
  Repodata *data;

  data = repo_add_repodata(repo, flags);
  memset(&pd, 0, sizeof(pd));
  pd.repo = repo;
  pd.pool = repo->pool;
  pd.data = data;

  pd.content = malloc(256);
  pd.acontent = 256;

  for (i = 0, sw = stateswitches; sw->from != NUMSTATES; i++, sw++)
    {
      if (!pd.swtab[sw->from])
        pd.swtab[sw->from] = sw;
      pd.sbtab[sw->to] = sw->from;
    }

  if (flags & REPO_USE_ROOTDIR)
    dirpath = pool_prepend_rootdir(repo->pool, dirpath);
  dir = opendir(dirpath);
  if (dir)
    {
      while ((entry = readdir(dir)))
	{
	  if (strlen(entry->d_name) < 3)
	    continue;	/* skip '.' and '..' */
	  fullpath = join2(&pd.jd, dirpath, "/", entry->d_name);
	  if ((fp = fopen(fullpath, "r")) == 0)
	    {
	      pool_error(repo->pool, 0, "%s: %s", fullpath, strerror(errno));
	      continue;
	    }
	  add_zyppdb_product(&pd, fp);
	  fclose(fp);
	}
    }
  closedir(dir);

  free(pd.content);
  join_freemem(&pd.jd);
  if (flags & REPO_USE_ROOTDIR)
    solv_free((char *)dirpath);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return 0;
}

/* EOF */
