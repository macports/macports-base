/*
 * repo_appdatadb.c
 *
 * Parses AppSteam Data files.
 * See http://people.freedesktop.org/~hughsient/appdata/
 *
 *
 * Copyright (c) 2013, Novell Inc.
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
#include "repo_appdata.h"


enum state {
  STATE_START,
  STATE_APPLICATION,
  STATE_ID,
  STATE_PKGNAME,
  STATE_LICENCE,
  STATE_NAME,
  STATE_SUMMARY,
  STATE_DESCRIPTION,
  STATE_P,
  STATE_UL,
  STATE_UL_LI,
  STATE_OL,
  STATE_OL_LI,
  STATE_URL,
  STATE_GROUP,
  STATE_KEYWORDS,
  STATE_KEYWORD,
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
  { STATE_START,       "applications",  STATE_START,         0 },
  { STATE_START,       "components",    STATE_START,         0 },
  { STATE_START,       "application",   STATE_APPLICATION,   0 },
  { STATE_START,       "component",     STATE_APPLICATION,   0 },
  { STATE_APPLICATION, "id",            STATE_ID,            1 },
  { STATE_APPLICATION, "pkgname",       STATE_PKGNAME,       1 },
  { STATE_APPLICATION, "product_license", STATE_LICENCE,     1 },
  { STATE_APPLICATION, "name",          STATE_NAME,          1 },
  { STATE_APPLICATION, "summary",       STATE_SUMMARY,       1 },
  { STATE_APPLICATION, "description",   STATE_DESCRIPTION,   0 },
  { STATE_APPLICATION, "url",           STATE_URL,           1 },
  { STATE_APPLICATION, "project_group", STATE_GROUP,         1 },
  { STATE_APPLICATION, "keywords",      STATE_KEYWORDS,      0 },
  { STATE_DESCRIPTION, "p",             STATE_P,             1 },
  { STATE_DESCRIPTION, "ul",            STATE_UL,            0 },
  { STATE_DESCRIPTION, "ol",            STATE_OL,            0 },
  { STATE_UL,          "li",            STATE_UL_LI,         1 },
  { STATE_OL,          "li",            STATE_OL_LI,         1 },
  { STATE_KEYWORDS,    "keyword",       STATE_KEYWORD,       1 },
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

  Solvable *solvable;
  Id handle;

  char *description;
  int licnt;
  int skip_depth;
  int flags;
  char *desktop_file;
  int havesummary;
};


static inline const char *
find_attr(const char *txt, const char **atts)
{
  for (; *atts; atts += 2)
    if (!strcmp(*atts, txt))
      return atts[1];
  return 0;
}


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

  if (!pd->skip_depth && find_attr("xml:lang", atts))
    pd->skip_depth = pd->depth;
  if (pd->skip_depth)
    {
      pd->docontent = 0;
      return;
    }

  switch(pd->state)
    {
    case STATE_APPLICATION:
      s = pd->solvable = pool_id2solvable(pool, repo_add_solvable(pd->repo));
      pd->handle = s - pool->solvables;
      pd->havesummary = 0;
      break;
    case STATE_DESCRIPTION:
      pd->description = solv_free(pd->description);
      break;
    case STATE_OL:
    case STATE_UL:
      pd->licnt = 0;
      break;
    default:
      break;
    }
}

/* replace whitespace with one space/newline */
/* also strip starting/ending whitespace */
static void
wsstrip(struct parsedata *pd)
{
  int i, j;
  int ws = 0;
  for (i = j = 0; pd->content[i]; i++)
    {
      if (pd->content[i] == ' ' || pd->content[i] == '\t' || pd->content[i] == '\n')
	{
	  ws |= pd->content[i] == '\n' ? 2 : 1;
	  continue;
	}
      if (ws && j)
	pd->content[j++] = (ws & 2) ? '\n' : ' ';
      ws = 0;
      pd->content[j++] = pd->content[i];
    }
  pd->content[j] = 0;
  pd->lcontent = j;
}

/* indent all lines */
static void
indent(struct parsedata *pd, int il)
{
  int i, l;
  for (l = 0; pd->content[l]; )
    {
      if (pd->content[l] == '\n')
	{
	  l++;
	  continue;
	}
      if (pd->lcontent + il + 1 > pd->acontent)
	{
	  pd->acontent = pd->lcontent + il + 256;
	  pd->content = realloc(pd->content, pd->acontent);
	}
      memmove(pd->content + l + il, pd->content + l, pd->lcontent - l + 1);
      for (i = 0; i < il; i++)
	pd->content[l + i] = ' ';
      pd->lcontent += il;
      while (pd->content[l] && pd->content[l] != '\n')
	l++;
    }
}

static void
add_missing_tags_from_desktop_file(struct parsedata *pd, Solvable *s, const char *desktop_file)
{
  Pool *pool = pd->pool;
  FILE *fp;
  const char *filepath;
  char buf[1024];
  char *p, *p2, *p3;
  int inde = 0;

  filepath = pool_tmpjoin(pool, "/usr/share/applications/", desktop_file, 0);
  if (pd->flags & REPO_USE_ROOTDIR)
    filepath = pool_prepend_rootdir_tmp(pool, filepath);
  if (!(fp = fopen(filepath, "r")))
    return;
  while (fgets(buf, sizeof(buf), fp) > 0)
    {
      int c, l = strlen(buf);
      if (!l)
	continue;
      if (buf[l - 1] != '\n')
	{
	  /* ignore overlong lines */
	  while ((c = getc(fp)) != EOF)
	    if (c == '\n')
	      break;
	  if (c == EOF)
	    break;
	  continue;
	}
      buf[--l] = 0;
      while (l && (buf[l - 1] == ' ' || buf[l - 1] == '\t'))
        buf[--l] = 0;
      p = buf;
      while (*p == ' ' || *p == '\t')
	p++;
      if (!*p || *p == '#')
	continue;
      if (*p == '[')
	inde = 0;
      if (!strcmp(p, "[Desktop Entry]"))
	{
	  inde = 1;
	  continue;
	}
      if (!inde)
	continue;
      p2 = strchr(p, '=');
      if (!p2 || p2 == p)
	continue;
      *p2 = 0;
      for (p3 = p2 - 1; *p3 == ' ' || *p3 == '\t'; p3--)
	*p3 = 0;
      p2++;
      while (*p2 == ' ' || *p2 == '\t')
	p2++;
      if (!*p2)
	continue;
      if (!s->name && !strcmp(p, "Name"))
	s->name = pool_str2id(pool, pool_tmpjoin(pool, "application:", p2, 0), 1);
      else if (!pd->havesummary && !strcmp(p, "Comment"))
	{
	  pd->havesummary = 1;
	  repodata_set_str(pd->data, pd->handle, SOLVABLE_SUMMARY, p2);
	}
      else
	continue;
      if (s->name && pd->havesummary)
	break;	/* our work is done */
    }
  fclose(fp);
}

static void XMLCALL
endElement(void *userData, const char *name)
{
  struct parsedata *pd = userData;
  Pool *pool = pd->pool;
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

  if (pd->skip_depth && pd->depth + 1 >= pd->skip_depth)
    {
      if (pd->depth + 1 == pd->skip_depth)
	pd->skip_depth = 0;
      pd->state = pd->sbtab[pd->state];
      pd->docontent = 0;
      return;
    }
  pd->skip_depth = 0;

  switch (pd->state)
    {
    case STATE_APPLICATION:
      if (!s->arch)
	s->arch = ARCH_NOARCH;
      if (!s->evr)
	s->evr = ID_EMPTY;
      if ((!s->name || !pd->havesummary) && (pd->flags & APPDATA_CHECK_DESKTOP_FILE) != 0 && pd->desktop_file)
	add_missing_tags_from_desktop_file(pd, s, pd->desktop_file);
      if (!s->name && pd->desktop_file)
	{
          char *name = pool_tmpjoin(pool, "application:", pd->desktop_file, 0);
	  int l = strlen(name);
	  if (l > 8 && !strcmp(".desktop", name + l - 8))
	    l -= 8;
	  s->name = pool_strn2id(pool, name, l, 1);
	}
      if (s->name && s->arch != ARCH_SRC && s->arch != ARCH_NOSRC)
	s->provides = repo_addid_dep(pd->repo, s->provides, pool_rel2id(pd->pool, s->name, s->evr, REL_EQ, 1), 0);
      pd->solvable = 0;
      pd->desktop_file = solv_free(pd->desktop_file);
      break;
    case STATE_ID:
      pd->desktop_file = solv_strdup(pd->content);
      /* guess the appdata.xml file name from the id element */
      if (pd->lcontent > 8 && !strcmp(".desktop", pd->content + pd->lcontent - 8))
	pd->content[pd->lcontent - 8] = 0;
      else if (pd->lcontent > 4 && !strcmp(".ttf", pd->content + pd->lcontent - 4))
	pd->content[pd->lcontent - 4] = 0;
      else if (pd->lcontent > 4 && !strcmp(".otf", pd->content + pd->lcontent - 4))
	pd->content[pd->lcontent - 4] = 0;
      else if (pd->lcontent > 4 && !strcmp(".xml", pd->content + pd->lcontent - 4))
	pd->content[pd->lcontent - 4] = 0;
      else if (pd->lcontent > 3 && !strcmp(".db", pd->content + pd->lcontent - 3))
	pd->content[pd->lcontent - 3] = 0;
      id = pool_str2id(pd->pool, pool_tmpjoin(pool, "appdata(", pd->content, ".appdata.xml)"), 1);
      s->requires = repo_addid_dep(pd->repo, s->requires, id, 0);
      id = pool_str2id(pd->pool, pool_tmpjoin(pool, "application-appdata(", pd->content, ".appdata.xml)"), 1);
      s->provides = repo_addid_dep(pd->repo, s->provides, id, 0);
      break;
    case STATE_NAME:
      s->name = pool_str2id(pd->pool, pool_tmpjoin(pool, "application:", pd->content, 0), 1);
      break;
    case STATE_LICENCE:
      repodata_add_poolstr_array(pd->data, pd->handle, SOLVABLE_LICENSE, pd->content);
      break;
    case STATE_SUMMARY:
      pd->havesummary = 1;
      repodata_set_str(pd->data, pd->handle, SOLVABLE_SUMMARY, pd->content);
      break;
    case STATE_URL:
      repodata_set_str(pd->data, pd->handle, SOLVABLE_URL, pd->content);
      break;
    case STATE_GROUP:
      repodata_add_poolstr_array(pd->data, pd->handle, SOLVABLE_GROUP, pd->content);
      break;
    case STATE_DESCRIPTION:
      if (pd->description)
	{
	  /* strip trailing newlines */
	  int l = strlen(pd->description);
	  while (l && pd->description[l - 1] == '\n')
	    pd->description[--l] = 0;
          repodata_set_str(pd->data, pd->handle, SOLVABLE_DESCRIPTION, pd->description);
	}
      break;
    case STATE_P:
      wsstrip(pd);
      pd->description = solv_dupappend(pd->description, pd->content, "\n\n");
      break;
    case STATE_UL_LI:
      wsstrip(pd);
      indent(pd, 4);
      pd->content[2] = '-';
      pd->description = solv_dupappend(pd->description, pd->content, "\n");
      break;
    case STATE_OL_LI:
      wsstrip(pd);
      indent(pd, 4);
      if (++pd->licnt >= 10)
	pd->content[0] = '0' + (pd->licnt / 10) % 10;
      pd->content[1] = '0' + pd->licnt  % 10;
      pd->content[2] = '.';
      pd->description = solv_dupappend(pd->description, pd->content, "\n");
      break;
    case STATE_UL:
    case STATE_OL:
      pd->description = solv_dupappend(pd->description, "\n", 0);
      break;
    case STATE_PKGNAME:
      id = pool_str2id(pd->pool, pd->content, 1);
      s->requires = repo_addid_dep(pd->repo, s->requires, id, 0);
      break;
    case STATE_KEYWORD:
      repodata_add_poolstr_array(pd->data, pd->handle, SOLVABLE_KEYWORDS, pd->content);
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
      pd->acontent = l + 256;
      pd->content = realloc(pd->content, pd->acontent);
    }
  c = pd->content + pd->lcontent;
  pd->lcontent += len;
  while (len-- > 0)
    *c++ = *s++;
  *c = 0;
}

#define BUFF_SIZE 8192

int
repo_add_appdata(Repo *repo, FILE *fp, int flags)
{
  Pool *pool = repo->pool;
  struct parsedata pd;
  struct stateswitch *sw;
  Repodata *data;
  char buf[BUFF_SIZE];
  int i, l;
  int ret = 0;

  data = repo_add_repodata(repo, flags);
  memset(&pd, 0, sizeof(pd));
  pd.repo = repo;
  pd.pool = repo->pool;
  pd.data = data;
  pd.flags = flags;

  pd.content = malloc(256);
  pd.acontent = 256;

  for (i = 0, sw = stateswitches; sw->from != NUMSTATES; i++, sw++)
    {
      if (!pd.swtab[sw->from])
        pd.swtab[sw->from] = sw;
      pd.sbtab[sw->to] = sw->from;
    }

  XML_Parser parser = XML_ParserCreate(NULL);
  XML_SetUserData(parser, &pd);
  XML_SetElementHandler(parser, startElement, endElement);
  XML_SetCharacterDataHandler(parser, characterData);

  for (;;)
    {
      l = fread(buf, 1, sizeof(buf), fp);
      if (XML_Parse(parser, buf, l, l == 0) == XML_STATUS_ERROR)
	{
	  pool_error(pool, -1, "repo_appdata: %s at line %u:%u\n", XML_ErrorString(XML_GetErrorCode(parser)), (unsigned int)XML_GetCurrentLineNumber(parser), (unsigned int)XML_GetCurrentColumnNumber(parser));
	  if (pd.solvable)
	    {
	      repo_free_solvable(repo, pd.solvable - pd.pool->solvables, 1);
	      pd.solvable = 0;
	    }
	  ret = -1;
	  break;
	}
      if (l == 0)
	break;
    }
  XML_ParserFree(parser);

  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);

  solv_free(pd.content);
  solv_free(pd.desktop_file);
  solv_free(pd.description);
  return ret;
}

/* add all files ending in .appdata.xml */
int
repo_add_appdata_dir(Repo *repo, const char *appdatadir, int flags)
{
  DIR *dir;
  char *dirpath;
  Repodata *data;

  data = repo_add_repodata(repo, flags);
  if (flags & REPO_USE_ROOTDIR)
    dirpath = pool_prepend_rootdir(repo->pool, appdatadir);
  else
    dirpath = solv_strdup(appdatadir);
  if ((dir = opendir(dirpath)) != 0)
    {
      struct dirent *entry;
      while ((entry = readdir(dir)))
	{
	  const char *n;
	  FILE *fp;
	  int len = strlen(entry->d_name);
	  if (len <= 12 || strcmp(entry->d_name + len - 12, ".appdata.xml") != 0)
	    continue;
	  if (entry->d_name[0] == '.')
	    continue;
          n = pool_tmpjoin(repo->pool, dirpath, "/", entry->d_name);
	  fp = fopen(n, "r");
	  if (!fp)
	    {
	      pool_error(repo->pool, 0, "%s: %s", n, strerror(errno));
	      continue;
	    }
	  repo_add_appdata(repo, fp, flags | REPO_NO_INTERNALIZE | REPO_REUSE_REPODATA | APPDATA_CHECK_DESKTOP_FILE);
	  fclose(fp);
	}
      closedir(dir);
    }
  solv_free(dirpath);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return 0;
}
