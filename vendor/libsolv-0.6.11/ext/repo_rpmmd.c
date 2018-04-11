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
#include <expat.h>

#include "pool.h"
#include "repo.h"
#define DISABLE_SPLIT
#include "tools_util.h"
#include "repo_rpmmd.h"
#include "chksum.h"
#ifdef ENABLE_COMPLEX_DEPS
#include "pool_parserpmrichdep.h"
#endif

enum state {
  STATE_START,

  STATE_SOLVABLE,

  STATE_NAME,
  STATE_ARCH,
  STATE_VERSION,

  /* package rpm-md */
  STATE_LOCATION,
  STATE_CHECKSUM,
  STATE_RPM_GROUP,
  STATE_RPM_LICENSE,

  /* resobject attributes */
  STATE_SUMMARY,
  STATE_DESCRIPTION,
  STATE_DISTRIBUTION,
  STATE_PACKAGER,
  STATE_URL,
  STATE_INSNOTIFY,
  STATE_DELNOTIFY,
  STATE_VENDOR,
  STATE_SIZE,
  STATE_TIME,
  STATE_DOWNLOADSIZE,
  STATE_INSTALLTIME,
  STATE_INSTALLONLY,

  /* Novell/SUSE extended attributes */
  STATE_EULA,
  STATE_KEYWORD,
  STATE_DISKUSAGE,
  STATE_DIRS,
  STATE_DIR,

  /* patch */
  STATE_ID,
  STATE_TIMESTAMP,
  STATE_AFFECTSPKG,
  STATE_REBOOTNEEDED,

  /* pattern attributes */
  STATE_CATEGORY, /* pattern and patches */
  STATE_ORDER,
  STATE_INCLUDES,
  STATE_INCLUDESENTRY,
  STATE_EXTENDS,
  STATE_EXTENDSENTRY,
  STATE_SCRIPT,
  STATE_ICON,
  STATE_USERVISIBLE,
  STATE_DEFAULT,
  STATE_INSTALL_TIME,

  /* product */
  STATE_RELNOTESURL,
  STATE_UPDATEURL,
  STATE_OPTIONALURL,
  STATE_FLAG,

  /* rpm-md dependencies inside the
     format tag */
  STATE_PROVIDES,
  STATE_REQUIRES,
  STATE_OBSOLETES,
  STATE_CONFLICTS,
  STATE_RECOMMENDS,
  STATE_SUPPLEMENTS,
  STATE_SUGGESTS,
  STATE_ENHANCES,
  STATE_FRESHENS,
  STATE_SOURCERPM,
  STATE_HEADERRANGE,

  STATE_PROVIDESENTRY,
  STATE_REQUIRESENTRY,
  STATE_OBSOLETESENTRY,
  STATE_CONFLICTSENTRY,
  STATE_RECOMMENDSENTRY,
  STATE_SUPPLEMENTSENTRY,
  STATE_SUGGESTSENTRY,
  STATE_ENHANCESENTRY,
  STATE_FRESHENSENTRY,

  STATE_FILE,

  STATE_CHANGELOG,

  /* general */
  NUMSTATES
};

struct stateswitch {
  enum state from;
  char *ename;
  enum state to;
  int docontent;
};

static struct stateswitch stateswitches[] = {
  /** fake tag used to enclose 2 different xml files in one **/
  { STATE_START,       "rpmmd",           STATE_START,    0 },

  /** tags for different package data, we just ignore the tag **/
  { STATE_START,       "metadata",        STATE_START,    0 },
  { STATE_START,       "otherdata",       STATE_START,    0 },
  { STATE_START,       "filelists",       STATE_START,    0 },
  { STATE_START,       "diskusagedata",   STATE_START,    0 },
  { STATE_START,       "susedata",        STATE_START,    0 },

  { STATE_START,       "product",         STATE_SOLVABLE, 0 },
  { STATE_START,       "pattern",         STATE_SOLVABLE, 0 },
  { STATE_START,       "patch",           STATE_SOLVABLE, 0 },
  { STATE_START,       "package",         STATE_SOLVABLE, 0 },

  { STATE_SOLVABLE,    "name",            STATE_NAME, 1 },
  { STATE_SOLVABLE,    "arch",            STATE_ARCH, 1 },
  { STATE_SOLVABLE,    "version",         STATE_VERSION, 0 },

  /* package attributes rpm-md */
  { STATE_SOLVABLE,    "location",        STATE_LOCATION, 0 },
  { STATE_SOLVABLE,    "checksum",        STATE_CHECKSUM, 1 },

  /* resobject attributes */

  { STATE_SOLVABLE,    "summary",         STATE_SUMMARY,      1 },
  { STATE_SOLVABLE,    "description",     STATE_DESCRIPTION,  1 },
  { STATE_SOLVABLE,    "distribution",    STATE_DISTRIBUTION, 1 },
  { STATE_SOLVABLE,    "url",             STATE_URL,          1 },
  { STATE_SOLVABLE,    "packager",        STATE_PACKAGER,     1 },
  { STATE_SOLVABLE,    "vendor",          STATE_VENDOR,       1 },
  { STATE_SOLVABLE,    "size",            STATE_SIZE,         0 },
  { STATE_SOLVABLE,    "archive-size",    STATE_DOWNLOADSIZE, 1 },
  { STATE_SOLVABLE,    "install-time",    STATE_INSTALLTIME,  1 },
  { STATE_SOLVABLE,    "install-only",    STATE_INSTALLONLY,  1 },
  { STATE_SOLVABLE,    "time",            STATE_TIME,         0 },

  /* extended Novell/SUSE attributes (susedata.xml) */
  { STATE_SOLVABLE,    "eula",            STATE_EULA,         1 },
  { STATE_SOLVABLE,    "keyword",         STATE_KEYWORD,      1 },
  { STATE_SOLVABLE,    "diskusage",       STATE_DISKUSAGE,    0 },

  /* pattern attribute */
  { STATE_SOLVABLE,    "script",          STATE_SCRIPT,        1 },
  { STATE_SOLVABLE,    "icon",            STATE_ICON,          1 },
  { STATE_SOLVABLE,    "uservisible",     STATE_USERVISIBLE,   1 },
  { STATE_SOLVABLE,    "category",        STATE_CATEGORY,      1 },
  { STATE_SOLVABLE,    "order",           STATE_ORDER,         1 },
  { STATE_SOLVABLE,    "includes",        STATE_INCLUDES,      0 },
  { STATE_SOLVABLE,    "extends",         STATE_EXTENDS,       0 },
  { STATE_SOLVABLE,    "default",         STATE_DEFAULT,       1 },
  { STATE_SOLVABLE,    "install-time",    STATE_INSTALL_TIME,  1 },

  /* product attributes */
  /* note the product type is an attribute */
  { STATE_SOLVABLE,    "release-notes-url", STATE_RELNOTESURL, 1 },
  { STATE_SOLVABLE,    "update-url",      STATE_UPDATEURL,   1 },
  { STATE_SOLVABLE,    "optional-url",    STATE_OPTIONALURL, 1 },
  { STATE_SOLVABLE,    "flag",            STATE_FLAG,        1 },

  { STATE_SOLVABLE,    "rpm:vendor",      STATE_VENDOR,      1 },
  { STATE_SOLVABLE,    "rpm:group",       STATE_RPM_GROUP,   1 },
  { STATE_SOLVABLE,    "rpm:license",     STATE_RPM_LICENSE, 1 },

  /* rpm-md dependencies */
  { STATE_SOLVABLE,    "rpm:provides",    STATE_PROVIDES,     0 },
  { STATE_SOLVABLE,    "rpm:requires",    STATE_REQUIRES,     0 },
  { STATE_SOLVABLE,    "rpm:obsoletes",   STATE_OBSOLETES,    0 },
  { STATE_SOLVABLE,    "rpm:conflicts",   STATE_CONFLICTS,    0 },
  { STATE_SOLVABLE,    "rpm:recommends",  STATE_RECOMMENDS ,  0 },
  { STATE_SOLVABLE,    "rpm:supplements", STATE_SUPPLEMENTS,  0 },
  { STATE_SOLVABLE,    "rpm:suggests",    STATE_SUGGESTS,     0 },
  { STATE_SOLVABLE,    "rpm:enhances",    STATE_ENHANCES,     0 },
  { STATE_SOLVABLE,    "rpm:freshens",    STATE_FRESHENS,     0 },
  { STATE_SOLVABLE,    "rpm:sourcerpm",   STATE_SOURCERPM,    1 },
  { STATE_SOLVABLE,    "rpm:header-range", STATE_HEADERRANGE, 0 },
  { STATE_SOLVABLE,    "file",            STATE_FILE, 1 },
  { STATE_SOLVABLE,    "changelog",       STATE_CHANGELOG, 1 },

   /* extended Novell/SUSE diskusage attributes (susedata.xml) */
  { STATE_DISKUSAGE,   "dirs",            STATE_DIRS,         0 },
  { STATE_DIRS,        "dir",             STATE_DIR,          0 },

  { STATE_PROVIDES,    "rpm:entry",       STATE_PROVIDESENTRY, 0 },
  { STATE_REQUIRES,    "rpm:entry",       STATE_REQUIRESENTRY, 0 },
  { STATE_OBSOLETES,   "rpm:entry",       STATE_OBSOLETESENTRY, 0 },
  { STATE_CONFLICTS,   "rpm:entry",       STATE_CONFLICTSENTRY, 0 },
  { STATE_RECOMMENDS,  "rpm:entry",       STATE_RECOMMENDSENTRY, 0 },
  { STATE_SUPPLEMENTS, "rpm:entry",       STATE_SUPPLEMENTSENTRY, 0 },
  { STATE_SUGGESTS,    "rpm:entry",       STATE_SUGGESTSENTRY, 0 },
  { STATE_ENHANCES,    "rpm:entry",       STATE_ENHANCESENTRY, 0 },
  { STATE_FRESHENS,    "rpm:entry",       STATE_FRESHENSENTRY, 0 },

  { STATE_INCLUDES,    "item",            STATE_INCLUDESENTRY, 0 },
  { STATE_EXTENDS,     "item",            STATE_EXTENDSENTRY,  0 },

  { NUMSTATES}
};

struct parsedata {
  int ret;
  Pool *pool;
  Repo *repo;
  Repodata *data;
  char *kind;
  int depth;
  enum state state;
  int statedepth;
  char *content;
  int lcontent;
  int acontent;
  int docontent;
  Solvable *solvable;
  Offset freshens;
  struct stateswitch *swtab[NUMSTATES];
  enum state sbtab[NUMSTATES];
  struct joindata jd;
  /* temporal to store attribute tag language */
  const char *tmplang;
  Id chksumtype;
  Id handle;
  XML_Parser *parser;
  Id (*dirs)[3]; /* dirid, size, nfiles */
  int ndirs;
  const char *language;			/* default language */
  Id langcache[ID_NUM_INTERNAL];	/* cache for the default language */

  Id lastdir;
  char *lastdirstr;
  int lastdirstrl;

  Id changelog_handle;

  /** Hash to maps checksums to solv */
  Stringpool cspool;
  /** Cache of known checksums to solvable id */
  Id *cscache;
  /* the current longest index in the table */
  int ncscache;
};

static Id
langtag(struct parsedata *pd, Id tag, const char *language)
{
  if (language)
    {
      if (!language[0] || !strcmp(language, "en"))
	return tag;
      return pool_id2langid(pd->pool, tag, language, 1);
    }
  if (!pd->language)
    return tag;
  if (tag >= ID_NUM_INTERNAL)
    return pool_id2langid(pd->pool, tag, pd->language, 1);
  if (!pd->langcache[tag])
    pd->langcache[tag] = pool_id2langid(pd->pool, tag, pd->language, 1);
  return pd->langcache[tag];
}

static int
id3_cmp (const void *v1, const void *v2, void *dp)
{
  Id *i1 = (Id*)v1;
  Id *i2 = (Id*)v2;
  return i1[0] - i2[0];
}

static void
commit_diskusage (struct parsedata *pd, Id handle)
{
  int i;
  Dirpool *dp = &pd->data->dirpool;
  /* Now sort in dirid order.  This ensures that parents come before
     their children.  */
  if (pd->ndirs > 1)
    solv_sort(pd->dirs, pd->ndirs, sizeof (pd->dirs[0]), id3_cmp, 0);
  /* Substract leaf numbers from all parents to make the numbers
     non-cumulative.  This must be done post-order (i.e. all leafs
     adjusted before parents).  We ensure this by starting at the end of
     the array moving to the start, hence seeing leafs before parents.  */
  for (i = pd->ndirs; i--;)
    {
      Id p = dirpool_parent(dp, pd->dirs[i][0]);
      int j = i;
      for (; p; p = dirpool_parent(dp, p))
        {
          for (; j--;)
	    if (pd->dirs[j][0] == p)
	      break;
	  if (j >= 0)
	    {
	      if (pd->dirs[j][1] < pd->dirs[i][1])
	        pd->dirs[j][1] = 0;
	      else
	        pd->dirs[j][1] -= pd->dirs[i][1];
	      if (pd->dirs[j][2] < pd->dirs[i][2])
	        pd->dirs[j][2] = 0;
	      else
	        pd->dirs[j][2] -= pd->dirs[i][2];
	    }
	  else
	    /* Haven't found this parent in the list, look further if
	       we maybe find the parents parent.  */
	    j = i;
	}
    }
#if 0
  char sbuf[1024];
  char *buf = sbuf;
  unsigned slen = sizeof (sbuf);
  for (i = 0; i < pd->ndirs; i++)
    {
      dir2str (attr, pd->dirs[i][0], &buf, &slen);
      fprintf (stderr, "have dir %d %d %d %s\n", pd->dirs[i][0], pd->dirs[i][1], pd->dirs[i][2], buf);
    }
  if (buf != sbuf)
    free (buf);
#endif
  for (i = 0; i < pd->ndirs; i++)
    if (pd->dirs[i][1] || pd->dirs[i][2])
      {
	repodata_add_dirnumnum(pd->data, handle, SOLVABLE_DISKUSAGE, pd->dirs[i][0], pd->dirs[i][1], pd->dirs[i][2]);
      }
  pd->ndirs = 0;
}


/*
 * makeevr_atts
 * parse 'epoch', 'ver' and 'rel', return evr Id
 *
 */

static Id
makeevr_atts(Pool *pool, struct parsedata *pd, const char **atts)
{
  const char *e, *v, *r, *v2;
  char *c;
  int l;

  e = v = r = 0;
  for (; *atts; atts += 2)
    {
      if (!strcmp(*atts, "epoch"))
	e = atts[1];
      else if (!strcmp(*atts, "ver"))
	v = atts[1];
      else if (!strcmp(*atts, "rel"))
	r = atts[1];
    }
  if (e && (!*e || !strcmp(e, "0")))
    e = 0;
  if (v && !e)
    {
      for (v2 = v; *v2 >= '0' && *v2 <= '9'; v2++)
        ;
      if (v2 > v && *v2 == ':')
	e = "0";
    }
  l = 1;
  if (e)
    l += strlen(e) + 1;
  if (v)
    l += strlen(v);
  if (r)
    l += strlen(r) + 1;
  if (l > pd->acontent)
    {
      pd->content = solv_realloc(pd->content, l + 256);
      pd->acontent = l + 256;
    }
  c = pd->content;
  if (e)
    {
      strcpy(c, e);
      c += strlen(c);
      *c++ = ':';
    }
  if (v)
    {
      strcpy(c, v);
      c += strlen(c);
    }
  if (r)
    {
      *c++ = '-';
      strcpy(c, r);
      c += strlen(c);
    }
  *c = 0;
  if (!*pd->content)
    return 0;
#if 0
  fprintf(stderr, "evr: %s\n", pd->content);
#endif
  return pool_str2id(pool, pd->content, 1);
}


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
 * dependency relations
 */

static char *flagtab[] = {
  "GT",
  "EQ",
  "GE",
  "LT",
  "NE",
  "LE"
};


/*
 * adddep
 * parse attributes to reldep Id
 *
 */

static unsigned int
adddep(Pool *pool, struct parsedata *pd, unsigned int olddeps, const char **atts, int isreq)
{
  Id id, marker;
  const char *n, *f, *k;
  const char **a;

  n = f = k = 0;
  marker = isreq ? -SOLVABLE_PREREQMARKER : 0;
  for (a = atts; *a; a += 2)
    {
      if (!strcmp(*a, "name"))
	n = a[1];
      else if (!strcmp(*a, "flags"))
	f = a[1];
      else if (!strcmp(*a, "kind"))
	k = a[1];
      else if (isreq && !strcmp(*a, "pre") && a[1][0] == '1')
	marker = SOLVABLE_PREREQMARKER;
    }
  if (!n)
    return olddeps;
  if (k && !strcmp(k, "package"))
    k = 0;
  if (k)
    {
      int l = strlen(k) + 1 + strlen(n) + 1;
      if (l > pd->acontent)
	{
	  pd->content = solv_realloc(pd->content, l + 256);
	  pd->acontent = l + 256;
	}
      sprintf(pd->content, "%s:%s", k, n);
      id = pool_str2id(pool, pd->content, 1);
    }
#ifdef ENABLE_COMPLEX_DEPS
  else if (!f && n[0] == '(')
    {
      id = pool_parserpmrichdep(pool, n);
      if (!id)
	return olddeps;
    }
#endif
  else
    id = pool_str2id(pool, (char *)n, 1);
  if (f)
    {
      Id evr = makeevr_atts(pool, pd, atts);
      int flags;
      for (flags = 0; flags < 6; flags++)
	if (!strcmp(f, flagtab[flags]))
	  break;
      flags = flags < 6 ? flags + 1 : 0;
      id = pool_rel2id(pool, id, evr, flags, 1);
    }
#if 0
  fprintf(stderr, "new dep %s\n", pool_dep2str(pool, id));
#endif
  return repo_addid_dep(pd->repo, olddeps, id, marker);
}


/*
 * set_description_author
 *
 */
static void
set_description_author(Repodata *data, Id handle, char *str, struct parsedata *pd)
{
  char *aut, *p;

  if (!str || !*str)
    return;
  for (aut = str; (aut = strchr(aut, '\n')) != 0; aut++)
    if (!strncmp(aut, "\nAuthors:\n--------\n", 19))
      break;
  if (aut)
    {
      /* oh my, found SUSE special author section */
      int l = aut - str;
      str[l] = 0;
      while (l > 0 && str[l - 1] == '\n')
	str[--l] = 0;
      if (l)
	repodata_set_str(data, handle, langtag(pd, SOLVABLE_DESCRIPTION, pd->tmplang), str);
      p = aut + 19;
      aut = str;        /* copy over */
      while (*p == ' ' || *p == '\n')
	p++;
      while (*p)
	{
	  if (*p == '\n')
	    {
	      *aut++ = *p++;
	      while (*p == ' ')
		p++;
	      continue;
	    }
	  *aut++ = *p++;
	}
      while (aut != str && aut[-1] == '\n')
	aut--;
      *aut = 0;
      if (*str)
	repodata_set_str(data, handle, SOLVABLE_AUTHORS, str);
    }
  else if (*str)
    repodata_set_str(data, handle, langtag(pd, SOLVABLE_DESCRIPTION, pd->tmplang), str);
}


/*-----------------------------------------------*/
/* XML callbacks */

/*
 * startElement
 * XML callback
 *
 */

static void XMLCALL
startElement(void *userData, const char *name, const char **atts)
{
  struct parsedata *pd = userData;
  Pool *pool = pd->pool;
  Solvable *s = pd->solvable;
  struct stateswitch *sw;
  const char *str;
  Id handle = pd->handle;
  const char *pkgid;

  /* fprintf(stderr, "into %s, from %d, depth %d, statedepth %d\n", name, pd->state, pd->depth, pd->statedepth); */

  if (pd->depth != pd->statedepth)
    {
      pd->depth++;
      return;
    }

  if (pd->state == STATE_START && !strcmp(name, "patterns"))
    return;
  if (pd->state == STATE_START && !strcmp(name, "products"))
    return;
#if 0
  if (pd->state == STATE_START && !strcmp(name, "metadata"))
    return;
#endif
  if (pd->state == STATE_SOLVABLE && !strcmp(name, "format"))
    return;

  pd->depth++;
  if (!pd->swtab[pd->state])
    return;
  for (sw = pd->swtab[pd->state]; sw->from == pd->state; sw++)
    if (!strcmp(sw->ename, name))
      break;
  if (sw->from != pd->state)
    {
#if 0
      fprintf(stderr, "into unknown: %s\n", name);
#endif
      return;
    }
  pd->state = sw->to;
  pd->docontent = sw->docontent;
  pd->statedepth = pd->depth;
  pd->lcontent = 0;
  *pd->content = 0;

  if (!s && pd->state != STATE_SOLVABLE)
    return;

  switch(pd->state)
    {
    case STATE_SOLVABLE:
      pd->kind = 0;
      if (name[2] == 't' && name[3] == 't')
        pd->kind = "pattern";
      else if (name[1] == 'r')
        pd->kind = "product";
      else if (name[2] == 't' && name[3] == 'c')
        pd->kind = "patch";

      /* to support extension metadata files like others.xml which
         have the following structure:

         <otherdata xmlns="http://linux.duke.edu/metadata/other"
                    packages="101">
           <package pkgid="b78f8664cd90efe42e09a345e272997ef1b53c18"
                    name="zaptel-kmp-default"
                    arch="i586"><version epoch="0"
                    ver="1.2.10_2.6.22_rc4_git6_2" rel="70"/>
              ...

         we need to check if the pkgid is there and if it matches
         an already seen package, that means we don't need to create
         a new solvable but just append the attributes to the existing
         one.
      */
      if ((pkgid = find_attr("pkgid", atts)) != NULL)
        {
          /* look at the checksum cache */
          Id index = stringpool_str2id(&pd->cspool, pkgid, 0);
          if (!index || index >= pd->ncscache || !pd->cscache[index])
	    {
              pool_debug(pool, SOLV_WARN, "the repository specifies extra information about package with checksum '%s', which does not exist in the repository.\n", pkgid);
	      pd->solvable = 0;
	      pd->handle = 0;
	      break;
	    }
	  pd->solvable = pool_id2solvable(pool, pd->cscache[index]);
        }
      else
        {
          /* this is a new package */
          pd->solvable = pool_id2solvable(pool, repo_add_solvable(pd->repo));
          pd->freshens = 0;
        }
      pd->handle = handle = pd->solvable - pool->solvables;
      if (pd->kind && pd->kind[1] == 'r')
	{
	  /* products can have a type */
	  const char *type = find_attr("type", atts);
	  if (type && *type)
	    repodata_set_str(pd->data, handle, PRODUCT_TYPE, type);
	}
#if 0
      fprintf(stderr, "package #%d\n", pd->solvable - pool->solvables);
#endif

      break;
    case STATE_VERSION:
      s->evr = makeevr_atts(pool, pd, atts);
      break;
    case STATE_PROVIDES:
      s->provides = 0;
      break;
    case STATE_PROVIDESENTRY:
      s->provides = adddep(pool, pd, s->provides, atts, 0);
      break;
    case STATE_REQUIRES:
      s->requires = 0;
      break;
    case STATE_REQUIRESENTRY:
      s->requires = adddep(pool, pd, s->requires, atts, 1);
      break;
    case STATE_OBSOLETES:
      s->obsoletes = 0;
      break;
    case STATE_OBSOLETESENTRY:
      s->obsoletes = adddep(pool, pd, s->obsoletes, atts, 0);
      break;
    case STATE_CONFLICTS:
      s->conflicts = 0;
      break;
    case STATE_CONFLICTSENTRY:
      s->conflicts = adddep(pool, pd, s->conflicts, atts, 0);
      break;
    case STATE_RECOMMENDS:
      s->recommends = 0;
      break;
    case STATE_RECOMMENDSENTRY:
      s->recommends = adddep(pool, pd, s->recommends, atts, 0);
      break;
    case STATE_SUPPLEMENTS:
      s->supplements= 0;
      break;
    case STATE_SUPPLEMENTSENTRY:
      s->supplements = adddep(pool, pd, s->supplements, atts, 0);
      break;
    case STATE_SUGGESTS:
      s->suggests = 0;
      break;
    case STATE_SUGGESTSENTRY:
      s->suggests = adddep(pool, pd, s->suggests, atts, 0);
      break;
    case STATE_ENHANCES:
      s->enhances = 0;
      break;
    case STATE_ENHANCESENTRY:
      s->enhances = adddep(pool, pd, s->enhances, atts, 0);
      break;
    case STATE_FRESHENS:
      pd->freshens = 0;
      break;
    case STATE_FRESHENSENTRY:
      pd->freshens = adddep(pool, pd, pd->freshens, atts, 0);
      break;
    case STATE_EULA:
    case STATE_SUMMARY:
    case STATE_CATEGORY:
    case STATE_DESCRIPTION:
      pd->tmplang = join_dup(&pd->jd, find_attr("lang", atts));
      break;
    case STATE_USERVISIBLE:
      repodata_set_void(pd->data, handle, SOLVABLE_ISVISIBLE);
      break;
    case STATE_INCLUDESENTRY:
      str = find_attr("pattern", atts);
      if (str)
	repodata_add_poolstr_array(pd->data, handle, SOLVABLE_INCLUDES, join2(&pd->jd, "pattern", ":", str));
      break;
    case STATE_EXTENDSENTRY:
      str = find_attr("pattern", atts);
      if (str)
	repodata_add_poolstr_array(pd->data, handle, SOLVABLE_EXTENDS, join2(&pd->jd, "pattern", ":", str));
      break;
    case STATE_LOCATION:
      str = find_attr("href", atts);
      if (str)
	{
	  repodata_set_location(pd->data, handle, 0, 0, str);
	  str = find_attr("xml:base", atts);
	  if (str)
	    repodata_set_poolstr(pd->data, handle, SOLVABLE_MEDIABASE, str);
	}
      break;
    case STATE_CHECKSUM:
      str = find_attr("type", atts);
      pd->chksumtype = str && *str ? solv_chksum_str2type(str) : 0;
      if (!pd->chksumtype)
	pd->ret = pool_error(pool, -1, "line %d: unknown checksum type: %s", (unsigned int)XML_GetCurrentLineNumber(*pd->parser), str ? str : "NULL");
      break;
    case STATE_TIME:
      {
        unsigned int t;
        str = find_attr("build", atts);
        if (str && (t = atoi(str)) != 0)
          repodata_set_num(pd->data, handle, SOLVABLE_BUILDTIME, t);
	break;
      }
    case STATE_SIZE:
      if ((str = find_attr("installed", atts)) != 0)
	repodata_set_num(pd->data, handle, SOLVABLE_INSTALLSIZE, strtoull(str, 0, 10));
      if ((str = find_attr("package", atts)) != 0)
	repodata_set_num(pd->data, handle, SOLVABLE_DOWNLOADSIZE, strtoull(str, 0, 10));
      break;
    case STATE_HEADERRANGE:
      {
        unsigned int end;
        str = find_attr("end", atts);
	if (str && (end = atoi(str)) != 0)
	  repodata_set_num(pd->data, handle, SOLVABLE_HEADEREND, end);
	break;
      }
      /*
        <diskusage>
          <dirs>
            <dir name="/" size="56" count="11"/>
            <dir name="usr/" size="56" count="11"/>
            <dir name="usr/bin/" size="38" count="10"/>
            <dir name="usr/share/" size="18" count="1"/>
            <dir name="usr/share/doc/" size="18" count="1"/>
          </dirs>
        </diskusage>
      */
    case STATE_DISKUSAGE:
      {
        /* Really, do nothing, wait for <dir> tag */
        break;
      }
    case STATE_DIR:
      {
        long filesz = 0, filenum = 0;
        Id dirid;
        if ((str = find_attr("name", atts)) != 0)
          dirid = repodata_str2dir(pd->data, str, 1);
        else
          {
	    pd->ret = pool_error(pool, -1, "<dir .../> tag without 'name' attribute");
            break;
          }
        if (!dirid)
          dirid = repodata_str2dir(pd->data, "/", 1);
        if ((str = find_attr("size", atts)) != 0)
          filesz = strtol(str, 0, 0);
        if ((str = find_attr("count", atts)) != 0)
          filenum = strtol(str, 0, 0);
        pd->dirs = solv_extend(pd->dirs, pd->ndirs, 1, sizeof(pd->dirs[0]), 31);
        pd->dirs[pd->ndirs][0] = dirid;
        pd->dirs[pd->ndirs][1] = filesz;
        pd->dirs[pd->ndirs][2] = filenum;
        pd->ndirs++;
        break;
      }
    case STATE_CHANGELOG:
      pd->changelog_handle = repodata_new_handle(pd->data);
      if ((str = find_attr("date", atts)) != 0)
	repodata_set_num(pd->data, pd->changelog_handle, SOLVABLE_CHANGELOG_TIME, strtoull(str, 0, 10));
      if ((str = find_attr("author", atts)) != 0)
	repodata_set_str(pd->data, pd->changelog_handle, SOLVABLE_CHANGELOG_AUTHOR, str);
      break;
    default:
      break;
    }
}


/*
 * endElement
 * XML callback
 *
 */

static void XMLCALL
endElement(void *userData, const char *name)
{
  struct parsedata *pd = userData;
  Pool *pool = pd->pool;
  Solvable *s = pd->solvable;
  Repo *repo = pd->repo;
  Id handle = pd->handle;
  Id id;
  char *p;

  if (pd->depth != pd->statedepth)
    {
      pd->depth--;
      /* printf("back from unknown %d %d %d\n", pd->state, pd->depth, pd->statedepth); */
      return;
    }

  /* ignore patterns & metadata */
  if (pd->state == STATE_START && !strcmp(name, "patterns"))
    return;
  if (pd->state == STATE_START && !strcmp(name, "products"))
    return;
#if 0
  if (pd->state == STATE_START && !strcmp(name, "metadata"))
    return;
#endif
  if (pd->state == STATE_SOLVABLE && !strcmp(name, "format"))
    return;

  pd->depth--;
  pd->statedepth--;


  if (!s)
    {
      pd->state = pd->sbtab[pd->state];
      pd->docontent = 0;
      return;
    }

  switch (pd->state)
    {
    case STATE_SOLVABLE:
      if (pd->kind && !s->name) /* add namespace in case of NULL name */
        s->name = pool_str2id(pool, join2(&pd->jd, pd->kind, ":", 0), 1);
      if (!s->arch)
        s->arch = ARCH_NOARCH;
      if (!s->evr)
        s->evr = ID_EMPTY;	/* some patterns have this */
      if (s->name && s->arch != ARCH_SRC && s->arch != ARCH_NOSRC)
        s->provides = repo_addid_dep(repo, s->provides, pool_rel2id(pool, s->name, s->evr, REL_EQ, 1), 0);
      s->supplements = repo_fix_supplements(repo, s->provides, s->supplements, pd->freshens);
      s->conflicts = repo_fix_conflicts(repo, s->conflicts);
      pd->freshens = 0;
      pd->kind = 0;
      pd->solvable = s = 0;
      break;
    case STATE_NAME:
      if (pd->kind)
        s->name = pool_str2id(pool, join2(&pd->jd, pd->kind, ":", pd->content), 1);
      else
        s->name = pool_str2id(pool, pd->content, 1);
      break;
    case STATE_ARCH:
      s->arch = pool_str2id(pool, pd->content, 1);
      break;
    case STATE_VENDOR:
      s->vendor = pool_str2id(pool, pd->content, 1);
      break;
    case STATE_RPM_GROUP:
      repodata_set_poolstr(pd->data, handle, SOLVABLE_GROUP, pd->content);
      break;
    case STATE_RPM_LICENSE:
      repodata_set_poolstr(pd->data, handle, SOLVABLE_LICENSE, pd->content);
      break;
    case STATE_CHECKSUM:
      {
        Id index;
	
	if (!pd->chksumtype)
	  break;
        if (strlen(pd->content) != 2 * solv_chksum_len(pd->chksumtype))
          {
	    pd->ret = pool_error(pool, -1, "line %d: invalid checksum length for %s", (unsigned int)XML_GetCurrentLineNumber(*pd->parser), solv_chksum_type2str(pd->chksumtype));
	    break;
          }
        repodata_set_checksum(pd->data, handle, SOLVABLE_CHECKSUM, pd->chksumtype, pd->content);
        /* we save the checksum to solvable id relationship for extended
           metadata */
        index = stringpool_str2id(&pd->cspool, pd->content, 1 /* create it */);
        if (index >= pd->ncscache)
          {
            pd->cscache = solv_zextend(pd->cscache, pd->ncscache, index + 1 - pd->ncscache, sizeof(Id), 255);
            pd->ncscache = index + 1;
          }
        /* add the checksum to the cache */
        pd->cscache[index] = s - pool->solvables;
        break;
      }
    case STATE_FILE:
#if 0
      id = pool_str2id(pool, pd->content, 1);
      s->provides = repo_addid_dep(repo, s->provides, id, SOLVABLE_FILEMARKER);
#endif
      if ((p = strrchr(pd->content, '/')) != 0)
	{
	  *p++ = 0;
	  if (pd->lastdir && !strcmp(pd->lastdirstr, pd->content))
	    {
	      id = pd->lastdir;
	    }
	  else
	    {
	      int l;
	      id = repodata_str2dir(pd->data, pd->content, 1);
	      l = strlen(pd->content) + 1;
	      if (l > pd->lastdirstrl)
		{
		  pd->lastdirstrl = l + 128;
		  pd->lastdirstr = solv_realloc(pd->lastdirstr, pd->lastdirstrl);
		}
	      strcpy(pd->lastdirstr, pd->content);
	      pd->lastdir = id;
	    }
	}
      else
	{
	  p = pd->content;
	  id = 0;
	}
      if (!id)
	id = repodata_str2dir(pd->data, "/", 1);
      repodata_add_dirstr(pd->data, handle, SOLVABLE_FILELIST, id, p);
      break;
    case STATE_SUMMARY:
      repodata_set_str(pd->data, handle, langtag(pd, SOLVABLE_SUMMARY, pd->tmplang), pd->content);
      break;
    case STATE_DESCRIPTION:
      set_description_author(pd->data, handle, pd->content, pd);
      break;
    case STATE_CATEGORY:
      repodata_set_str(pd->data, handle, langtag(pd, SOLVABLE_CATEGORY, pd->tmplang), pd->content);
      break;
    case STATE_DISTRIBUTION:
        repodata_set_poolstr(pd->data, handle, SOLVABLE_DISTRIBUTION, pd->content);
        break;
    case STATE_URL:
      if (pd->content[0])
	repodata_set_str(pd->data, handle, SOLVABLE_URL, pd->content);
      break;
    case STATE_PACKAGER:
      if (pd->content[0])
	repodata_set_poolstr(pd->data, handle, SOLVABLE_PACKAGER, pd->content);
      break;
    case STATE_SOURCERPM:
      if (pd->content[0])
	repodata_set_sourcepkg(pd->data, handle, pd->content);
      break;
    case STATE_RELNOTESURL:
      if (pd->content[0])
        {
          repodata_add_poolstr_array(pd->data, handle, PRODUCT_URL, pd->content);
          repodata_add_idarray(pd->data, handle, PRODUCT_URL_TYPE, pool_str2id(pool, "releasenotes", 1));
        }
      break;
    case STATE_UPDATEURL:
      if (pd->content[0])
        {
          repodata_add_poolstr_array(pd->data, handle, PRODUCT_URL, pd->content);
          repodata_add_idarray(pd->data, handle, PRODUCT_URL_TYPE, pool_str2id(pool, "update", 1));
        }
      break;
    case STATE_OPTIONALURL:
      if (pd->content[0])
        {
          repodata_add_poolstr_array(pd->data, handle, PRODUCT_URL, pd->content);
          repodata_add_idarray(pd->data, handle, PRODUCT_URL_TYPE, pool_str2id(pool, "optional", 1));
        }
      break;
    case STATE_FLAG:
      if (pd->content[0])
        repodata_add_poolstr_array(pd->data, handle, PRODUCT_FLAGS, pd->content);
      break;
    case STATE_EULA:
      if (pd->content[0])
	repodata_set_str(pd->data, handle, langtag(pd, SOLVABLE_EULA, pd->tmplang), pd->content);
      break;
    case STATE_KEYWORD:
      if (pd->content[0])
        repodata_add_poolstr_array(pd->data, handle, SOLVABLE_KEYWORDS, pd->content);
      break;
    case STATE_DISKUSAGE:
      if (pd->ndirs)
        commit_diskusage(pd, handle);
      break;
    case STATE_ORDER:
      if (pd->content[0])
        repodata_set_str(pd->data, handle, SOLVABLE_ORDER, pd->content);
      break;
    case STATE_CHANGELOG:
      repodata_set_str(pd->data, pd->changelog_handle, SOLVABLE_CHANGELOG_TEXT, pd->content);
      repodata_add_flexarray(pd->data, handle, SOLVABLE_CHANGELOG, pd->changelog_handle);
      pd->changelog_handle = 0;
      break;
    default:
      break;
    }
  pd->state = pd->sbtab[pd->state];
  pd->docontent = 0;
  /* fprintf(stderr, "back from known %d %d %d\n", pd->state, pd->depth, pd->statedepth); */
}


/*
 * characterData
 * XML callback
 *
 */

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


/*-----------------------------------------------*/
/* 'main' */

#define BUFF_SIZE 8192

/*
 * repo_add_rpmmd
 * parse rpm-md metadata (primary, others)
 *
 */

int
repo_add_rpmmd(Repo *repo, FILE *fp, const char *language, int flags)
{
  Pool *pool = repo->pool;
  struct parsedata pd;
  char buf[BUFF_SIZE];
  int i, l;
  struct stateswitch *sw;
  Repodata *data;
  unsigned int now;
  XML_Parser parser;

  now = solv_timems(0);
  data = repo_add_repodata(repo, flags);

  memset(&pd, 0, sizeof(pd));
  for (i = 0, sw = stateswitches; sw->from != NUMSTATES; i++, sw++)
    {
      if (!pd.swtab[sw->from])
        pd.swtab[sw->from] = sw;
      pd.sbtab[sw->to] = sw->from;
    }
  pd.pool = pool;
  pd.repo = repo;
  pd.data = data;

  pd.content = solv_malloc(256);
  pd.acontent = 256;
  pd.lcontent = 0;
  pd.kind = 0;
  pd.language = language && *language && strcmp(language, "en") != 0 ? language : 0;

  /* initialize the string pool where we will store
     the package checksums we know about, to get an Id
     we can use in a cache */
  stringpool_init_empty(&pd.cspool);
  if ((flags & REPO_EXTEND_SOLVABLES) != 0)
    {
      /* setup join data */
      Dataiterator di;
      dataiterator_init(&di, pool, repo, 0, SOLVABLE_CHECKSUM, 0, 0);
      while (dataiterator_step(&di))
	{
	  const char *str;
	  int index;

	  if (!solv_chksum_len(di.key->type))
	    continue;
	  str = repodata_chk2str(di.data, di.key->type, (const unsigned char *)di.kv.str);
          index = stringpool_str2id(&pd.cspool, str, 1);
	  if (index >= pd.ncscache)
	    {
	      pd.cscache = solv_zextend(pd.cscache, pd.ncscache, index + 1 - pd.ncscache, sizeof(Id), 255);
	      pd.ncscache = index + 1;
	    }
          pd.cscache[index] = di.solvid;
	}
      dataiterator_free(&di);
    }

  parser = XML_ParserCreate(NULL);
  XML_SetUserData(parser, &pd);
  pd.parser = &parser;
  XML_SetElementHandler(parser, startElement, endElement);
  XML_SetCharacterDataHandler(parser, characterData);
  for (;;)
    {
      l = fread(buf, 1, sizeof(buf), fp);
      if (XML_Parse(parser, buf, l, l == 0) == XML_STATUS_ERROR)
	{
	  pd.ret = pool_error(pool, -1, "repo_rpmmd: %s at line %u:%u", XML_ErrorString(XML_GetErrorCode(parser)), (unsigned int)XML_GetCurrentLineNumber(parser), (unsigned int)XML_GetCurrentColumnNumber(parser));
	  break;
	}
      if (l == 0)
	break;
    }
  XML_ParserFree(parser);
  solv_free(pd.content);
  solv_free(pd.lastdirstr);
  join_freemem(&pd.jd);
  stringpool_free(&pd.cspool);
  solv_free(pd.cscache);
  repodata_free_dircache(data);

  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  POOL_DEBUG(SOLV_DEBUG_STATS, "repo_add_rpmmd took %d ms\n", solv_timems(now));
  POOL_DEBUG(SOLV_DEBUG_STATS, "repo size: %d solvables\n", repo->nsolvables);
  POOL_DEBUG(SOLV_DEBUG_STATS, "repo memory used: %d K incore, %d K idarray\n", repodata_memused(data)/1024, repo->idarraysize / (int)(1024/sizeof(Id)));
  return pd.ret;
}
