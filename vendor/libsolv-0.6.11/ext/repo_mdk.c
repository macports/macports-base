/*
 * Copyright (c) 2012, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <expat.h>

#include "pool.h"
#include "repo.h"
#include "util.h"
#include "chksum.h"
#include "repo_mdk.h"

static Offset
parse_deps(Solvable *s, char *bp, Id marker)
{
  Pool *pool = s->repo->pool;
  Offset deps = 0;
  char *nbp, *ebp;
  for (; bp; bp = nbp)
    {
      int ispre = 0;
      Id id, evr = 0;
      int flags = 0;

      nbp = strchr(bp, '@');
      if (!nbp)
	ebp = bp + strlen(bp);
      else
	{
	  ebp = nbp;
	  *nbp++ = 0;
	}
      if (ebp[-1] == ']')
	{
	  char *sbp = ebp - 1;
	  while (sbp >= bp && *sbp != '[')
	    sbp--;
	  if (sbp >= bp && sbp[1] != '*')
	    {
	      char *fbp;
	      for (fbp = sbp + 1;; fbp++)
		{
		  if (*fbp == '>')
		    flags |= REL_GT;
		  else if (*fbp == '=')
		    flags |= REL_EQ;
		  else if (*fbp == '<')
		    flags |= REL_LT;
		  else
		    break;
		}
	      if (*fbp == ' ')
		fbp++;
	      evr = pool_strn2id(pool, fbp, ebp - 1 - fbp, 1);
	      ebp = sbp;
	    }
	}
      if (ebp[-1] == ']' && ebp >= bp + 3 && !strncmp(ebp - 3, "[*]", 3))
	{
	  ispre = 1;
	  ebp -= 3;
	}
      id = pool_strn2id(pool, bp, ebp - bp, 1);
      if (evr)
	id = pool_rel2id(pool, id, evr, flags, 1);
      deps = repo_addid_dep(s->repo, deps, id, ispre ? marker : 0);
      bp = nbp;
    }
  return deps;
}

int
repo_add_mdk(Repo *repo, FILE *fp, int flags)
{
  Pool *pool = repo->pool;
  Repodata *data;
  Solvable *s;
  char *buf;
  int bufa, bufl;

  data = repo_add_repodata(repo, flags);
  bufa = 4096;
  buf = solv_malloc(bufa);
  bufl = 0;
  s = 0;
  while (fgets(buf + bufl, bufa - bufl, fp) > 0)
    {
      bufl += strlen(buf + bufl);
      if (!bufl)
	continue;
      if (buf[bufl - 1] != '\n')
	{
	  if (bufa - bufl < 256)
	    {
	      bufa += 4096;
	      buf = solv_realloc(buf, bufa);
	    }
	  continue;
	}
      buf[bufl - 1] = 0;
      bufl = 0;
      if (buf[0] != '@')
	{
	  pool_debug(pool, SOLV_ERROR, "bad line <%s>\n", buf);
	  continue;
	}
      if (!s)
	s = pool_id2solvable(pool, repo_add_solvable(repo));
      if (!strncmp(buf + 1, "filesize@", 9))
	repodata_set_num(data, s - pool->solvables, SOLVABLE_DOWNLOADSIZE, strtoull(buf + 10, 0, 10));
      else if (!strncmp(buf + 1, "summary@", 8))
	repodata_set_str(data, s - pool->solvables, SOLVABLE_SUMMARY, buf + 9);
      else if (!strncmp(buf + 1, "provides@", 9))
	s->provides = parse_deps(s, buf + 10, 0);
      else if (!strncmp(buf + 1, "requires@", 9))
	s->requires = parse_deps(s, buf + 10, SOLVABLE_PREREQMARKER);
      else if (!strncmp(buf + 1, "suggests@", 9))
	s->suggests = parse_deps(s, buf + 10, 0);
      else if (!strncmp(buf + 1, "obsoletes@", 10))
	s->obsoletes = parse_deps(s, buf + 11, 0);
      else if (!strncmp(buf + 1, "conflicts@", 10))
	s->conflicts = parse_deps(s, buf + 11, 0);
      else if (!strncmp(buf + 1, "info@", 5))
	{
	  char *nvra = buf + 6;
	  char *epochstr;
	  char *arch;
	  char *version;
	  char *filename;
	  if ((epochstr = strchr(nvra, '@')) != 0)
	    {
	      char *sizestr;
	      *epochstr++ = 0;
	      if ((sizestr = strchr(epochstr, '@')) != 0)
		{
		  char *groupstr;
		  *sizestr++ = 0;
		  if ((groupstr = strchr(sizestr, '@')) != 0)
		    {
		      char *n;
		      *groupstr++ = 0;
		      if ((n = strchr(groupstr, '@')) != 0)
			*n = 0;
		      if (*groupstr)
			repodata_set_poolstr(data, s - pool->solvables, SOLVABLE_GROUP, groupstr);
		    }
		  repodata_set_num(data, s - pool->solvables, SOLVABLE_INSTALLSIZE, strtoull(sizestr, 0, 10));
		}
	    }
          filename = pool_tmpjoin(pool, nvra, ".rpm", 0);
	  arch = strrchr(nvra, '.');
	  if (arch)
	    {
	      *arch++ = 0;
	      s->arch = pool_str2id(pool, arch, 1);
	    }
	  /* argh, do we have a distepoch or not, check self-provides */
	  if (s->provides)
	    {
	      Id id, lastid, *idp = s->repo->idarraydata + s->provides;
	      lastid = 0;
	      for (idp = s->repo->idarraydata + s->provides; (id = *idp) != 0; idp++)
		{
		  const char *evr, *name;
		  int namel;
		  Reldep *rd;
		  if (!ISRELDEP(id))
		    continue;
		  rd = GETRELDEP(pool, id);
		  if (rd->flags != REL_EQ)
		    continue;
		  name = pool_id2str(pool, rd->name);
		  namel = strlen(name);
		  if (strncmp(name, nvra, namel) != 0 || nvra[namel] != '-')
		    continue;
		  evr = pool_id2str(pool, rd->evr);
		  evr = strrchr(evr, '-');
		  if (evr && strchr(evr, ':') != 0)
		    lastid = id;
		}
	      if (lastid)
		{
		  /* self provides found, and it contains a distepoch */
		  /* replace with self-provides distepoch to get rid of the disttag */
		  char *nvradistepoch = strrchr(nvra, '-');
		  if (nvradistepoch)
		    {
		      Reldep *rd = GETRELDEP(pool, lastid);
		      const char *evr = pool_id2str(pool, rd->evr);
		      evr = strrchr(evr, '-');
		      if (evr && (evr = strchr(evr, ':')) != 0)
			{
			  if (strlen(evr) < strlen(nvradistepoch))
			    strcpy(nvradistepoch, evr);
			}
		    }
		}
	    }
	  version = strrchr(nvra, '-');
	  if (version)
	    {
	      char *release = version;
	      *release = 0;
	      version = strrchr(nvra, '-');
	      *release = '-';
	      if (!version)
		version = release;
	      *version++ = 0;
	    }
	  else
	    version = "";
	  s->name = pool_str2id(pool, nvra, 1);
	  if (epochstr && *epochstr && strcmp(epochstr, "0") != 0)
	    {
	      char *evr = pool_tmpjoin(pool, epochstr, ":", version);
	      s->evr = pool_str2id(pool, evr, 1);
	    }
	  else
	    s->evr = pool_str2id(pool, version, 1);
	  repodata_set_location(data, s - pool->solvables, 0, 0, filename);
	  if (s->name && s->arch != ARCH_SRC && s->arch != ARCH_NOSRC)
	    s->provides = repo_addid_dep(s->repo, s->provides, pool_rel2id(pool, s->name, s->evr, REL_EQ, 1), 0);
          s = 0;
	}
      else
	{
	  char *tagend = strchr(buf + 1, '@');
	  if (tagend)
	    *tagend = 0;
	  pool_debug(pool, SOLV_ERROR, "unknown tag <%s>\n", buf + 1);
	  continue;
	}
    }
  if (s)
    {
      pool_debug(pool, SOLV_ERROR, "unclosed package at EOF\n");
      repo_free_solvable(s->repo, s - pool->solvables, 1);
    }
  solv_free(buf);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return 0;
}

enum state {
  STATE_START,
  STATE_MEDIA_INFO,
  STATE_INFO,
  STATE_FILES,
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
  { STATE_START, "media_info", STATE_MEDIA_INFO, 0 },
  { STATE_MEDIA_INFO, "info", STATE_INFO, 1 },
  { STATE_MEDIA_INFO, "files", STATE_FILES, 1 },
  { NUMSTATES }
};

struct parsedata {
  Pool *pool;
  Repo *repo;
  Repodata *data;
  int depth;
  enum state state;
  int statedepth;
  char *content;
  int lcontent;
  int acontent;
  int docontent;
  struct stateswitch *swtab[NUMSTATES];
  enum state sbtab[NUMSTATES];
  Solvable *solvable;
  Hashtable joinhash;
  Hashval joinhashmask;
};

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

static Hashtable
joinhash_init(Repo *repo, Hashval *hmp)
{
  Hashval hm = mkmask(repo->nsolvables);
  Hashtable ht = solv_calloc(hm + 1, sizeof(*ht));
  Hashval h, hh;
  Solvable *s;
  int i;

  FOR_REPO_SOLVABLES(repo, i, s)
    {
      hh = HASHCHAIN_START;
      h = s->name & hm;
      while (ht[h])
        h = HASHCHAIN_NEXT(h, hh, hm);
      ht[h] = i;
    }
  *hmp = hm;
  return ht;
}

static Solvable *
joinhash_lookup(Repo *repo, Hashtable ht, Hashval hm, const char *fn, const char *distepoch)
{
  Hashval h, hh;
  const char *p, *vrstart, *vrend;
  Id name, arch;

  if (!fn || !*fn)
    return 0;
  if (distepoch && !*distepoch)
    distepoch = 0;
  p = fn + strlen(fn);
  while (--p > fn)
    if (*p == '.')
      break;
  if (p == fn)
    return 0;
  arch = pool_str2id(repo->pool, p + 1, 0);
  if (!arch)
    return 0;
  if (distepoch)
    {
      while (--p > fn)
        if (*p == '-')
          break;
      if (p == fn)
	return 0;
    }
  vrend = p;
  while (--p > fn)
    if (*p == '-')
      break;
  if (p == fn)
    return 0;
  while (--p > fn)
    if (*p == '-')
      break;
  if (p == fn)
    return 0;
  vrstart = p + 1;
  name = pool_strn2id(repo->pool, fn, p - fn, 0);
  if (!name)
    return 0;
  hh = HASHCHAIN_START;
  h = name & hm;
  while (ht[h])
    {
      Solvable *s = repo->pool->solvables + ht[h];
      if (s->name == name && s->arch == arch)
	{
	  /* too bad we don't know the epoch... */
	  const char *evr = pool_id2str(repo->pool, s->evr);
	  for (p = evr; *p >= '0' && *p <= '9'; p++)
	    ;
	  if (p > evr && *p == ':')
	    evr = p + 1;
	  if (distepoch)
	    {
              if (!strncmp(evr, vrstart, vrend - vrstart) && evr[vrend - vrstart] == ':' && !strcmp(distepoch, evr + (vrend - vrstart + 1)))
	        return s;
	    }
          else if (!strncmp(evr, vrstart, vrend - vrstart) && evr[vrend - vrstart] == 0)
	    return s;
	}
      h = HASHCHAIN_NEXT(h, hh, hm);
    }
  return 0;
}

static void XMLCALL
startElement(void *userData, const char *name, const char **atts)
{
  struct parsedata *pd = userData;
  Pool *pool = pd->pool;
  struct stateswitch *sw;

  if (pd->depth != pd->statedepth)
    {
      pd->depth++;
      return;
    }
  pd->depth++;
  if (!pd->swtab[pd->state])
    return;
  for (sw = pd->swtab[pd->state]; sw->from == pd->state; sw++)
    if (!strcmp(sw->ename, name))
      break;
  if (sw->from != pd->state)
    return;
  pd->state = sw->to;
  pd->docontent = sw->docontent;
  pd->statedepth = pd->depth;
  pd->lcontent = 0;
  *pd->content = 0;
  switch (pd->state)
    {
    case STATE_INFO:
      {
	const char *fn = find_attr("fn", atts);
	const char *distepoch = find_attr("distepoch", atts);
	const char *str;
	pd->solvable = joinhash_lookup(pd->repo, pd->joinhash, pd->joinhashmask, fn, distepoch);
	if (!pd->solvable)
	  break;
	str = find_attr("url", atts);
	if (str && *str)
	  repodata_set_str(pd->data, pd->solvable - pool->solvables, SOLVABLE_URL, str);
	str = find_attr("license", atts);
	if (str && *str)
	  repodata_set_poolstr(pd->data, pd->solvable - pool->solvables, SOLVABLE_LICENSE, str);
	str = find_attr("sourcerpm", atts);
	if (str && *str)
	  repodata_set_sourcepkg(pd->data, pd->solvable - pool->solvables, str);
        break;
      }
    case STATE_FILES:
      {
	const char *fn = find_attr("fn", atts);
	const char *distepoch = find_attr("distepoch", atts);
	pd->solvable = joinhash_lookup(pd->repo, pd->joinhash, pd->joinhashmask, fn, distepoch);
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
  if (pd->depth != pd->statedepth)
    {
      pd->depth--;
      return;
    }
  pd->depth--;
  pd->statedepth--;
  switch (pd->state)
    {
    case STATE_INFO:
      if (s && *pd->content)
        repodata_set_str(pd->data, s - pd->pool->solvables, SOLVABLE_DESCRIPTION, pd->content);
      break;
    case STATE_FILES:
      if (s && *pd->content)
	{
	  char *np, *p, *sl;
	  for (p = pd->content; p && *p; p = np)
	    {
	      Id id;
	      np = strchr(p, '\n');
	      if (np)
		*np++ = 0;
	      if (!*p)
		continue;
	      sl = strrchr(p, '/');
	      if (sl)
		{
		  *sl++ = 0;
		  id = repodata_str2dir(pd->data, p, 1);
		}
	      else
		{
		  sl = p;
		  id = 0;
		}
	      if (!id)
		id = repodata_str2dir(pd->data, "/", 1);
	      repodata_add_dirstr(pd->data, s - pd->pool->solvables, SOLVABLE_FILELIST, id, sl);
	    }
	}
      break;
    default:
      break;
    }
  pd->state = pd->sbtab[pd->state];
  pd->docontent = 0;
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
repo_add_mdk_info(Repo *repo, FILE *fp, int flags)
{
  Repodata *data;
  struct parsedata pd;
  char buf[BUFF_SIZE];
  int i, l;
  struct stateswitch *sw;
  XML_Parser parser;

  if (!(flags & REPO_EXTEND_SOLVABLES))
    {
      pool_debug(repo->pool, SOLV_ERROR, "repo_add_mdk_info: can only extend existing solvables\n");
      return -1;
    }

  data = repo_add_repodata(repo, flags);

  memset(&pd, 0, sizeof(pd));
  pd.repo = repo;
  pd.pool = repo->pool;
  pd.data = data;

  pd.content = solv_malloc(256);
  pd.acontent = 256;

  pd.joinhash = joinhash_init(repo, &pd.joinhashmask);

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
  solv_free(pd.joinhash);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return 0;
}
