/*
 * repo_comps.c
 *
 * Parses RedHat comps format
 *
 * Copyright (c) 2012, Novell Inc.
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

#include "pool.h"
#include "repo.h"
#include "util.h"
#define DISABLE_SPLIT
#include "tools_util.h"
#include "repo_comps.h"

/*
 * TODO:
 *
 * what's the difference between group/category?
 * handle "default" and "langonly".
 *
 * maybe handle REL_COND in solver recommends handling?
 */

enum state {
  STATE_START,
  STATE_COMPS,
  STATE_GROUP,
  STATE_ID,
  STATE_NAME,
  STATE_DESCRIPTION,
  STATE_DISPLAY_ORDER,
  STATE_DEFAULT,
  STATE_LANGONLY,
  STATE_LANG_ONLY,
  STATE_USERVISIBLE,
  STATE_PACKAGELIST,
  STATE_PACKAGEREQ,
  STATE_CATEGORY,
  STATE_CID,
  STATE_CNAME,
  STATE_CDESCRIPTION,
  STATE_CDISPLAY_ORDER,
  STATE_GROUPLIST,
  STATE_GROUPID,
  NUMSTATES
};

struct stateswitch {
  enum state from;
  char *ename;
  enum state to;
  int docontent;
};

/* must be sorted by first column */
static struct stateswitch stateswitches[] = {
  { STATE_START,       "comps",         STATE_COMPS,         0 },
  { STATE_COMPS,       "group",         STATE_GROUP,         0 },
  { STATE_COMPS,       "category",      STATE_CATEGORY,      0 },
  { STATE_GROUP,       "id",            STATE_ID,            1 },
  { STATE_GROUP,       "name",          STATE_NAME,          1 },
  { STATE_GROUP,       "description",   STATE_DESCRIPTION,   1 },
  { STATE_GROUP,       "uservisible",   STATE_USERVISIBLE,   1 },
  { STATE_GROUP,       "display_order", STATE_DISPLAY_ORDER, 1 },
  { STATE_GROUP,       "default",       STATE_DEFAULT,       1 },
  { STATE_GROUP,       "langonly",      STATE_LANGONLY,      1 },
  { STATE_GROUP,       "lang_only",     STATE_LANG_ONLY,     1 },
  { STATE_GROUP,       "packagelist",   STATE_PACKAGELIST,   0 },
  { STATE_PACKAGELIST, "packagereq",    STATE_PACKAGEREQ,    1 },
  { STATE_CATEGORY,    "id",            STATE_CID,           1 },
  { STATE_CATEGORY,    "name",          STATE_CNAME,         1 },
  { STATE_CATEGORY,    "description",   STATE_CDESCRIPTION,  1 },
  { STATE_CATEGORY ,   "grouplist",     STATE_GROUPLIST,     0 },
  { STATE_CATEGORY ,   "display_order", STATE_CDISPLAY_ORDER, 1 },
  { STATE_GROUPLIST,   "groupid",       STATE_GROUPID,       1 },
  { NUMSTATES }
};

struct parsedata {
  Pool *pool;
  Repo *repo;
  Repodata *data;
  const char *filename;
  const char *basename;
  int depth;
  enum state state;
  int statedepth;
  char *content;
  int lcontent;
  int acontent;
  int docontent;

  struct stateswitch *swtab[NUMSTATES];
  enum state sbtab[NUMSTATES];
  struct joindata jd;

  const char *tmplang;
  Id reqtype;
  Id condreq;

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
    case STATE_GROUP:
    case STATE_CATEGORY:
      s = pd->solvable = pool_id2solvable(pool, repo_add_solvable(pd->repo));
      pd->handle = s - pool->solvables;
      break;

    case STATE_NAME:
    case STATE_CNAME:
    case STATE_DESCRIPTION:
    case STATE_CDESCRIPTION:
      pd->tmplang = join_dup(&pd->jd, find_attr("xml:lang", atts));
      break;

    case STATE_PACKAGEREQ:
      {
	const char *type = find_attr("type", atts);
	pd->condreq = 0;
	pd->reqtype = SOLVABLE_RECOMMENDS;
	if (type && !strcmp(type, "conditional"))
	  {
	    const char *requires = find_attr("requires", atts);
	    if (requires && *requires)
	      pd->condreq = pool_str2id(pool, requires, 1);
	  }
	else if (type && !strcmp(type, "mandatory"))
	  pd->reqtype = SOLVABLE_REQUIRES;
	else if (type && !strcmp(type, "optional"))
	  pd->reqtype = SOLVABLE_SUGGESTS;
	break;
      }

    default:
      break;
    }
}


static void XMLCALL
endElement(void *userData, const char *name)
{
  struct parsedata *pd = userData;
  Solvable *s = pd->solvable;
  Id id;

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
    case STATE_GROUP:
    case STATE_CATEGORY:
      if (!s->arch)
	s->arch = ARCH_NOARCH;
      if (!s->evr)
	s->evr = ID_EMPTY;
      if (s->name && s->arch != ARCH_SRC && s->arch != ARCH_NOSRC)
	s->provides = repo_addid_dep(pd->repo, s->provides, pool_rel2id(pd->pool, s->name, s->evr, REL_EQ, 1), 0);
      pd->solvable = 0;
      break;

    case STATE_ID:
    case STATE_CID:
      s->name = pool_str2id(pd->pool, join2(&pd->jd, pd->state == STATE_ID ? "group" : "category", ":", pd->content), 1);
      break;

    case STATE_NAME:
    case STATE_CNAME:
      repodata_set_str(pd->data, pd->handle, pool_id2langid(pd->pool, SOLVABLE_SUMMARY, pd->tmplang, 1), pd->content);
      break;

    case STATE_DESCRIPTION:
    case STATE_CDESCRIPTION:
      repodata_set_str(pd->data, pd->handle, pool_id2langid(pd->pool, SOLVABLE_DESCRIPTION, pd->tmplang, 1), pd->content);
      break;

    case STATE_PACKAGEREQ:
      id = pool_str2id(pd->pool, pd->content, 1);
      if (pd->condreq)
	id = pool_rel2id(pd->pool, id, pd->condreq, REL_COND, 1);
      repo_add_idarray(pd->repo, pd->handle, pd->reqtype, id);
      break;

    case STATE_GROUPID:
      id = pool_str2id(pd->pool, join2(&pd->jd, "group", ":", pd->content), 1);
      s->requires = repo_addid_dep(pd->repo, s->requires, id, 0);
      break;

    case STATE_USERVISIBLE:
      repodata_set_void(pd->data, pd->handle, SOLVABLE_ISVISIBLE);
      break;

    case STATE_DISPLAY_ORDER:
    case STATE_CDISPLAY_ORDER:
      repodata_set_str(pd->data, pd->handle, SOLVABLE_ORDER, pd->content);
      break;

    case STATE_DEFAULT:
      break;

    case STATE_LANGONLY:
    case STATE_LANG_ONLY:
      break;

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
      pd->content = solv_realloc(pd->content, l + 256);
      pd->acontent = l + 256;
    }
  c = pd->content + pd->lcontent;
  pd->lcontent += len;
  while (len-- > 0)
    *c++ = *s++;
  *c = 0;
}

#define BUFF_SIZE 8192


int
repo_add_comps(Repo *repo, FILE *fp, int flags)
{
  Repodata *data;
  struct parsedata pd;
  char buf[BUFF_SIZE];
  int i, l;
  struct stateswitch *sw;
  XML_Parser parser;

  data = repo_add_repodata(repo, flags);

  memset(&pd, 0, sizeof(pd));
  pd.repo = repo;
  pd.pool = repo->pool;
  pd.data = data;

  pd.content = solv_malloc(256);
  pd.acontent = 256;

  for (i = 0, sw = stateswitches; sw->from != NUMSTATES; i++, sw++)
    {
      if (!pd.swtab[sw->from])
        pd.swtab[sw->from] = sw;
      pd.sbtab[sw->to] = sw->from;
    }

  parser = XML_ParserCreate(NULL);
  XML_SetUserData(parser, &pd);
  XML_SetElementHandler(parser, startElement, endElement);
  XML_SetCharacterDataHandler(parser, characterData);
  for (;;)
    {
      l = fread(buf, 1, sizeof(buf), fp);
      if (XML_Parse(parser, buf, l, l == 0) == XML_STATUS_ERROR)
	{
	  pool_debug(pd.pool, SOLV_ERROR, "%s at line %u:%u\n", XML_ErrorString(XML_GetErrorCode(parser)), (unsigned int)XML_GetCurrentLineNumber(parser), (unsigned int)XML_GetCurrentColumnNumber(parser));
	  break;
	}
      if (l == 0)
	break;
    }
  XML_ParserFree(parser);

  solv_free(pd.content);
  join_freemem(&pd.jd);

  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return 0;
}

/* EOF */
