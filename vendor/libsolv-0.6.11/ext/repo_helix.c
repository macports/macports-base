/*
 * Copyright (c) 2007, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * repo_helix.c
 *
 * Parse 'helix' XML representation
 * and create 'repo'
 *
 * A bit of history: "Helix Code" was the name of the company that
 * wrote Red Carpet. The company was later renamed to Ximian.
 * The Red Carpet solver was merged into the ZYPP project, the
 * library used both by ZENworks and YaST for package management.
 * Red Carpet came with solver testcases in its own repository
 * format, the 'helix' format.
 *
 */

#include <sys/types.h>
#include <limits.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <expat.h>

#include "repo_helix.h"
#include "evr.h"


/* XML parser states */

enum state {
  STATE_START,
  STATE_CHANNEL,
  STATE_SUBCHANNEL,
  STATE_PACKAGE,
  STATE_NAME,
  STATE_VENDOR,
  STATE_BUILDTIME,
  STATE_HISTORY,
  STATE_UPDATE,
  STATE_EPOCH,
  STATE_VERSION,
  STATE_RELEASE,
  STATE_ARCH,
  STATE_PROVIDES,
  STATE_PROVIDESENTRY,
  STATE_REQUIRES,
  STATE_REQUIRESENTRY,
  STATE_PREREQUIRES,
  STATE_PREREQUIRESENTRY,
  STATE_OBSOLETES,
  STATE_OBSOLETESENTRY,
  STATE_CONFLICTS,
  STATE_CONFLICTSENTRY,
  STATE_RECOMMENDS,
  STATE_RECOMMENDSENTRY,
  STATE_SUPPLEMENTS,
  STATE_SUPPLEMENTSENTRY,
  STATE_SUGGESTS,
  STATE_SUGGESTSENTRY,
  STATE_ENHANCES,
  STATE_ENHANCESENTRY,
  STATE_FRESHENS,
  STATE_FRESHENSENTRY,

  STATE_SELECTTION,
  STATE_PATTERN,
  STATE_ATOM,
  STATE_PATCH,
  STATE_PRODUCT,

  STATE_PEPOCH,
  STATE_PVERSION,
  STATE_PRELEASE,
  STATE_PARCH,

  NUMSTATES
};

struct stateswitch {
  enum state from;
  char *ename;
  enum state to;
  int docontent;
};

static struct stateswitch stateswitches[] = {
  { STATE_START,       "channel",         STATE_CHANNEL, 0 },
  { STATE_CHANNEL,     "subchannel",      STATE_SUBCHANNEL, 0 },
  { STATE_SUBCHANNEL,  "package",         STATE_PACKAGE, 0 },
  { STATE_SUBCHANNEL,  "srcpackage",      STATE_PACKAGE, 0 },
  { STATE_SUBCHANNEL,  "selection",       STATE_PACKAGE, 0 },
  { STATE_SUBCHANNEL,  "pattern",         STATE_PACKAGE, 0 },
  { STATE_SUBCHANNEL,  "atom",            STATE_PACKAGE, 0 },
  { STATE_SUBCHANNEL,  "patch",           STATE_PACKAGE, 0 },
  { STATE_SUBCHANNEL,  "product",         STATE_PACKAGE, 0 },
  { STATE_SUBCHANNEL,  "application",     STATE_PACKAGE, 0 },
  { STATE_PACKAGE,     "name",            STATE_NAME, 1 },
  { STATE_PACKAGE,     "vendor",          STATE_VENDOR, 1 },
  { STATE_PACKAGE,     "buildtime",       STATE_BUILDTIME, 1 },
  { STATE_PACKAGE,     "epoch",           STATE_PEPOCH, 1 },
  { STATE_PACKAGE,     "version",         STATE_PVERSION, 1 },
  { STATE_PACKAGE,     "release",         STATE_PRELEASE, 1 },
  { STATE_PACKAGE,     "arch",            STATE_PARCH, 1 },
  { STATE_PACKAGE,     "history",         STATE_HISTORY, 0 },
  { STATE_PACKAGE,     "provides",        STATE_PROVIDES, 0 },
  { STATE_PACKAGE,     "requires",        STATE_REQUIRES, 0 },
  { STATE_PACKAGE,     "prerequires",     STATE_PREREQUIRES, 0 },
  { STATE_PACKAGE,     "obsoletes",       STATE_OBSOLETES , 0 },
  { STATE_PACKAGE,     "conflicts",       STATE_CONFLICTS , 0 },
  { STATE_PACKAGE,     "recommends" ,     STATE_RECOMMENDS , 0 },
  { STATE_PACKAGE,     "supplements",     STATE_SUPPLEMENTS, 0 },
  { STATE_PACKAGE,     "suggests",        STATE_SUGGESTS, 0 },
  { STATE_PACKAGE,     "enhances",        STATE_ENHANCES, 0 },
  { STATE_PACKAGE,     "freshens",        STATE_FRESHENS, 0 },

  { STATE_HISTORY,     "update",          STATE_UPDATE, 0 },
  { STATE_UPDATE,      "epoch",           STATE_EPOCH, 1 },
  { STATE_UPDATE,      "version",         STATE_VERSION, 1 },
  { STATE_UPDATE,      "release",         STATE_RELEASE, 1 },
  { STATE_UPDATE,      "arch",            STATE_ARCH, 1 },

  { STATE_PROVIDES,    "dep",             STATE_PROVIDESENTRY, 0 },
  { STATE_REQUIRES,    "dep",             STATE_REQUIRESENTRY, 0 },
  { STATE_PREREQUIRES, "dep",             STATE_PREREQUIRESENTRY, 0 },
  { STATE_OBSOLETES,   "dep",             STATE_OBSOLETESENTRY, 0 },
  { STATE_CONFLICTS,   "dep",             STATE_CONFLICTSENTRY, 0 },
  { STATE_RECOMMENDS,  "dep",             STATE_RECOMMENDSENTRY, 0 },
  { STATE_SUPPLEMENTS, "dep",             STATE_SUPPLEMENTSENTRY, 0 },
  { STATE_SUGGESTS,    "dep",             STATE_SUGGESTSENTRY, 0 },
  { STATE_ENHANCES,    "dep",             STATE_ENHANCESENTRY, 0 },
  { STATE_FRESHENS,    "dep",             STATE_FRESHENSENTRY, 0 },
  { NUMSTATES }

};

/*
 * parser data
 */

typedef struct _parsedata {
  int ret;
  /* XML parser data */
  int depth;
  enum state state;	/* current state */
  int statedepth;
  char *content;	/* buffer for content of node */
  int lcontent;		/* actual length of current content */
  int acontent;		/* actual buffer size */
  int docontent;	/* handle content */

  /* repo data */
  Pool *pool;		/* current pool */
  Repo *repo;		/* current repo */
  Repodata *data;       /* current repo data */
  Solvable *solvable;	/* current solvable */
  Offset freshens;	/* current freshens vector */

  /* package data */
  int  epoch;		/* epoch (as offset into evrspace) */
  int  version;		/* version (as offset into evrspace) */
  int  release;		/* release (as offset into evrspace) */
  char *evrspace;	/* buffer for evr */
  int  aevrspace;	/* actual buffer space */
  int  levrspace;	/* actual evr length */
  char *kind;

  struct stateswitch *swtab[NUMSTATES];
  enum state sbtab[NUMSTATES];
} Parsedata;


/*------------------------------------------------------------------*/
/* E:V-R handling */

/* create Id from epoch:version-release */

static Id
evr2id(Pool *pool, Parsedata *pd, const char *e, const char *v, const char *r)
{
  char *c;
  int l;

  /* treat explitcit 0 as NULL */
  if (e && (!*e || !strcmp(e, "0")))
    e = 0;

  if (v && !e)
    {
      const char *v2;
      /* scan version for ":" */
      for (v2 = v; *v2 >= '0' && *v2 <= '9'; v2++)	/* skip leading digits */
        ;
      /* if version contains ":", set epoch to "0" */
      if (v2 > v && *v2 == ':')
	e = "0";
    }

  /* compute length of Id string */
  l = 1;  /* for the \0 */
  if (e)
    l += strlen(e) + 1;  /* e: */
  if (v)
    l += strlen(v);      /* v */
  if (r)
    l += strlen(r) + 1;  /* -r */

  /* extend content if not sufficient */
  if (l > pd->acontent)
    {
      pd->content = (char *)realloc(pd->content, l + 256);
      pd->acontent = l + 256;
    }

  /* copy e-v-r to content */
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
  /* if nothing inserted, return Id 0 */
  if (!*pd->content)
    return ID_NULL;
#if 0
  fprintf(stderr, "evr: %s\n", pd->content);
#endif
  /* intern and create */
  return pool_str2id(pool, pd->content, 1);
}


/* create e:v-r from attributes
 * atts is array of name,value pairs, NULL at end
 *   even index into atts is name
 *   odd index is value
 */
static Id
evr_atts2id(Pool *pool, Parsedata *pd, const char **atts)
{
  const char *e, *v, *r;
  e = v = r = 0;
  for (; *atts; atts += 2)
    {
      if (!strcmp(*atts, "epoch"))
	e = atts[1];
      else if (!strcmp(*atts, "version"))
	v = atts[1];
      else if (!strcmp(*atts, "release"))
	r = atts[1];
    }
  return evr2id(pool, pd, e, v, r);
}

/*------------------------------------------------------------------*/
/* rel operator handling */

struct flagtab {
  char *from;
  int to;
};

static struct flagtab flagtab[] = {
  { ">",  REL_GT },
  { "=",  REL_EQ },
  { ">=", REL_GT|REL_EQ },
  { "<",  REL_LT },
  { "!=", REL_GT|REL_LT },
  { "<=", REL_LT|REL_EQ },
  { "(any)", REL_LT|REL_EQ|REL_GT },
  { "==", REL_EQ },
  { "gt", REL_GT },
  { "eq", REL_EQ },
  { "ge", REL_GT|REL_EQ },
  { "lt", REL_LT },
  { "ne", REL_GT|REL_LT },
  { "le", REL_LT|REL_EQ },
  { "gte", REL_GT|REL_EQ },
  { "lte", REL_LT|REL_EQ },
  { "GT", REL_GT },
  { "EQ", REL_EQ },
  { "GE", REL_GT|REL_EQ },
  { "LT", REL_LT },
  { "NE", REL_GT|REL_LT },
  { "LE", REL_LT|REL_EQ }
};

/*
 * process new dependency from parser
 *  olddeps = already collected deps, this defines the 'kind' of dep
 *  atts = array of name,value attributes of dep
 *  isreq == 1 if its a requires
 */

static unsigned int
adddep(Pool *pool, Parsedata *pd, unsigned int olddeps, const char **atts, Id marker)
{
  Id id, name;
  const char *n, *f, *k;
  const char **a;

  n = f = k = NULL;

  /* loop over name,value pairs */
  for (a = atts; *a; a += 2)
    {
      if (!strcmp(*a, "name"))
	n = a[1];
      if (!strcmp(*a, "kind"))
	k = a[1];
      else if (!strcmp(*a, "op"))
	f = a[1];
      else if (marker && !strcmp(*a, "pre") && a[1][0] == '1')
        marker = SOLVABLE_PREREQMARKER;
    }
  if (!n)			       /* quit if no name found */
    return olddeps;

  /* kind, name */
  if (k && !strcmp(k, "package"))
    k = NULL;			       /* package is default */

  if (k)			       /* if kind!=package, intern <kind>:<name> */
    {
      int l = strlen(k) + 1 + strlen(n) + 1;
      if (l > pd->acontent)	       /* extend buffer if needed */
	{
	  pd->content = (char *)realloc(pd->content, l + 256);
	  pd->acontent = l + 256;
	}
      sprintf(pd->content, "%s:%s", k, n);
      name = pool_str2id(pool, pd->content, 1);
    }
  else
    {
      name = pool_str2id(pool, n, 1);       /* package: just intern <name> */
    }

  if (f)			       /* operator ? */
    {
      /* intern e:v-r */
      Id evr = evr_atts2id(pool, pd, atts);
      /* parser operator to flags */
      int flags;
      for (flags = 0; flags < sizeof(flagtab)/sizeof(*flagtab); flags++)
	if (!strcmp(f, flagtab[flags].from))
	  {
	    flags = flagtab[flags].to;
	    break;
	  }
      if (flags > 7)
	flags = 0;
      /* intern rel */
      id = pool_rel2id(pool, name, evr, flags, 1);
    }
  else
    id = name;			       /* no operator */

  /* add new dependency to repo */
  return repo_addid_dep(pd->repo, olddeps, id, marker);
}


/*----------------------------------------------------------------*/

/*
 * XML callback
 * <name>
 *
 */

static void XMLCALL
startElement(void *userData, const char *name, const char **atts)
{
  Parsedata *pd = (Parsedata *)userData;
  struct stateswitch *sw;
  Pool *pool = pd->pool;
  Solvable *s = pd->solvable;

  if (pd->depth != pd->statedepth)
    {
      pd->depth++;
      return;
    }

  /* ignore deps element */
  if (pd->state == STATE_PACKAGE && !strcmp(name, "deps"))
    return;

  pd->depth++;

  /* find node name in stateswitch */
  if (!pd->swtab[pd->state])
    return;
  for (sw = pd->swtab[pd->state]; sw->from == pd->state; sw++)
  {
    if (!strcmp(sw->ename, name))
      break;
  }

  /* check if we're at the right level */
  if (sw->from != pd->state)
    {
#if 0
      fprintf(stderr, "into unknown: %s\n", name);
#endif
      return;
    }

  /* set new state */
  pd->state = sw->to;

  pd->docontent = sw->docontent;
  pd->statedepth = pd->depth;

  /* start with empty content */
  /* (will collect data until end element) */
  pd->lcontent = 0;
  *pd->content = 0;

  switch (pd->state)
    {

    case STATE_NAME:
      if (pd->kind)		       /* if kind is set (non package) */
        {
          strcpy(pd->content, pd->kind);
          pd->lcontent = strlen(pd->content);
	  pd->content[pd->lcontent++] = ':';   /* prefix name with '<kind>:' */
	  pd->content[pd->lcontent] = 0;
	}
      break;

    case STATE_PACKAGE:		       /* solvable name */
      pd->solvable = pool_id2solvable(pool, repo_add_solvable(pd->repo));
      if (!strcmp(name, "selection"))
        pd->kind = "selection";
      else if (!strcmp(name, "pattern"))
        pd->kind = "pattern";
      else if (!strcmp(name, "atom"))
        pd->kind = "atom";
      else if (!strcmp(name, "product"))
        pd->kind = "product";
      else if (!strcmp(name, "patch"))
        pd->kind = "patch";
      else if (!strcmp(name, "application"))
        pd->kind = "application";
      else
        pd->kind = NULL;	       /* default is package */
      pd->levrspace = 1;
      pd->epoch = 0;
      pd->version = 0;
      pd->release = 0;
      pd->freshens = 0;
#if 0
      fprintf(stderr, "package #%d\n", s - pool->solvables);
#endif
      break;

    case STATE_UPDATE:
      pd->levrspace = 1;
      pd->epoch = 0;
      pd->version = 0;
      pd->release = 0;
      break;

    case STATE_PROVIDES:	       /* start of provides */
      s->provides = 0;
      break;
    case STATE_PROVIDESENTRY:	       /* entry within provides */
      s->provides = adddep(pool, pd, s->provides, atts, 0);
      break;
    case STATE_REQUIRESENTRY:
      s->requires = adddep(pool, pd, s->requires, atts, -SOLVABLE_PREREQMARKER);
      break;
    case STATE_PREREQUIRESENTRY:
      s->requires = adddep(pool, pd, s->requires, atts, SOLVABLE_PREREQMARKER);
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
    default:
      break;
    }
}

static const char *findKernelFlavor(Parsedata *pd, Solvable *s)
{
  Pool *pool = pd->pool;
  Id pid, *pidp;

  if (s->provides)
    {
      pidp = pd->repo->idarraydata + s->provides;
      while ((pid = *pidp++) != 0)
	{
	  Reldep *prd;
	  const char *depname;

	  if (!ISRELDEP(pid))
	    continue;               /* wrong provides name */
	  prd = GETRELDEP(pool, pid);
	  depname = pool_id2str(pool, prd->name);
	  if (!strncmp(depname, "kernel-", 7))
	    return depname + 7;
	}
    }

  if (s->requires)
    {
      pidp = pd->repo->idarraydata + s->requires;
      while ((pid = *pidp++) != 0)
	{
	  const char *depname;

	  if (!ISRELDEP(pid))
	    {
	      depname = pool_id2str(pool, pid);
	    }
	  else
	    {
	      Reldep *prd = GETRELDEP(pool, pid);
	      depname = pool_id2str(pool, prd->name);
	    }
	  if (!strncmp(depname, "kernel-", 7))
	    return depname + 7;
	}
    }

  return 0;
}


/*
 * XML callback
 * </name>
 *
 * create Solvable from collected data
 */

static void XMLCALL
endElement(void *userData, const char *name)
{
  Parsedata *pd = (Parsedata *)userData;
  Pool *pool = pd->pool;
  Solvable *s = pd->solvable;
  Id evr;
  unsigned int t = 0;
  const char *flavor;

  if (pd->depth != pd->statedepth)
    {
      pd->depth--;
      /* printf("back from unknown %d %d %d\n", pd->state, pd->depth, pd->statedepth); */
      return;
    }

  /* ignore deps element */
  if (pd->state == STATE_PACKAGE && !strcmp(name, "deps"))
    return;

  pd->depth--;
  pd->statedepth--;
  switch (pd->state)
    {

    case STATE_PACKAGE:		       /* package complete */
      if (name[0] == 's' && name[1] == 'r' && name[2] == 'c' && s->arch != ARCH_SRC && s->arch != ARCH_NOSRC)
	s->arch = ARCH_SRC;
      if (!s->arch)                    /* default to "noarch" */
	s->arch = ARCH_NOARCH;

      if (!s->evr && pd->version)      /* set solvable evr */
        s->evr = evr2id(pool, pd,
                        pd->epoch   ? pd->evrspace + pd->epoch   : 0,
                        pd->version ? pd->evrspace + pd->version : 0,
                        pd->release ? pd->evrspace + pd->release : "");
      /* ensure self-provides */
      if (s->name && s->arch != ARCH_SRC && s->arch != ARCH_NOSRC)
        s->provides = repo_addid_dep(pd->repo, s->provides, pool_rel2id(pool, s->name, s->evr, REL_EQ, 1), 0);
      s->supplements = repo_fix_supplements(pd->repo, s->provides, s->supplements, pd->freshens);
      s->conflicts = repo_fix_conflicts(pd->repo, s->conflicts);
      pd->freshens = 0;

      /* see bugzilla bnc#190163 */
      flavor = findKernelFlavor(pd, s);
      if (flavor)
	{
	  char *cflavor = solv_strdup(flavor);	/* make pointer safe */

	  Id npr;
	  Id pid;

	  /* this is either a kernel package or a kmp */
	  if (s->provides)
	    {
	      Offset prov = s->provides;
	      npr = 0;
	      while ((pid = pd->repo->idarraydata[prov++]) != 0)
		{
		  const char *depname = 0;
		  Reldep *prd = 0;

		  if (ISRELDEP(pid))
		    {
		      prd = GETRELDEP(pool, pid);
		      depname = pool_id2str(pool, prd->name);
		    }
		  else
		    {
		      depname = pool_id2str(pool, pid);
		    }


		  if (!strncmp(depname, "kernel(", 7) && !strchr(depname, ':'))
		    {
		      char newdep[100];
		      snprintf(newdep, sizeof(newdep), "kernel(%s:%s", cflavor, depname + 7);
		      pid = pool_str2id(pool, newdep, 1);
		      if (prd)
			pid = pool_rel2id(pool, pid, prd->evr, prd->flags, 1);
		    }

		  npr = repo_addid_dep(pd->repo, npr, pid, 0);
		}
	      s->provides = npr;
	    }
#if 1

	  if (s->requires)
	    {
	      Offset reqs = s->requires;
	      npr = 0;
	      while ((pid = pd->repo->idarraydata[reqs++]) != 0)
		{
		  const char *depname = 0;
		  Reldep *prd = 0;

		  if (ISRELDEP(pid))
		    {
		      prd = GETRELDEP(pool, pid);
		      depname = pool_id2str(pool, prd->name);
		    }
		  else
		    {
		      depname = pool_id2str(pool, pid);
		    }

		  if (!strncmp(depname, "kernel(", 7) && !strchr(depname, ':'))
		    {
		      char newdep[100];
		      snprintf(newdep, sizeof(newdep), "kernel(%s:%s", cflavor, depname + 7);
		      pid = pool_str2id(pool, newdep, 1);
		      if (prd)
			pid = pool_rel2id(pool, pid, prd->evr, prd->flags, 1);
		    }
		  npr = repo_addid_dep(pd->repo, npr, pid, 0);
		}
	      s->requires = npr;
	    }
#endif
	  free(cflavor);
	}
      break;
    case STATE_NAME:
      s->name = pool_str2id(pool, pd->content, 1);
      break;
    case STATE_VENDOR:
      s->vendor = pool_str2id(pool, pd->content, 1);
      break;
    case STATE_BUILDTIME:
      t = atoi (pd->content);
      if (t)
	repodata_set_num(pd->data, s - pool->solvables, SOLVABLE_BUILDTIME, t);
      break;	
    case STATE_UPDATE:		       /* new version, keeping all other metadata */
      evr = evr2id(pool, pd,
                   pd->epoch   ? pd->evrspace + pd->epoch   : 0,
                   pd->version ? pd->evrspace + pd->version : 0,
                   pd->release ? pd->evrspace + pd->release : 0);
      pd->levrspace = 1;
      pd->epoch = 0;
      pd->version = 0;
      pd->release = 0;
      /* use highest evr */
      if (!s->evr || pool_evrcmp(pool, s->evr, evr, EVRCMP_COMPARE) <= 0)
	s->evr = evr;
      break;
    case STATE_EPOCH:
    case STATE_VERSION:
    case STATE_RELEASE:
    case STATE_PEPOCH:
    case STATE_PVERSION:
    case STATE_PRELEASE:
      /* ensure buffer space */
      if (pd->lcontent + 1 + pd->levrspace > pd->aevrspace)
	{
	  pd->evrspace = (char *)realloc(pd->evrspace, pd->lcontent + 1 + pd->levrspace + 256);
	  pd->aevrspace = pd->lcontent + 1 + pd->levrspace + 256;
	}
      memcpy(pd->evrspace + pd->levrspace, pd->content, pd->lcontent + 1);
      if (pd->state == STATE_EPOCH || pd->state == STATE_PEPOCH)
	pd->epoch = pd->levrspace;
      else if (pd->state == STATE_VERSION || pd->state == STATE_PVERSION)
	pd->version = pd->levrspace;
      else
	pd->release = pd->levrspace;
      pd->levrspace += pd->lcontent + 1;
      break;
    case STATE_ARCH:
    case STATE_PARCH:
      s->arch = pool_str2id(pool, pd->content, 1);
      break;
    default:
      break;
    }
  pd->state = pd->sbtab[pd->state];
  pd->docontent = 0;
  /* printf("back from known %d %d %d\n", pd->state, pd->depth, pd->statedepth); */
}


/*
 * XML callback
 * character data
 *
 */

static void XMLCALL
characterData(void *userData, const XML_Char *s, int len)
{
  Parsedata *pd = (Parsedata *)userData;
  int l;
  char *c;

  /* check if current nodes content is interesting */
  if (!pd->docontent)
    return;

  /* adapt content buffer */
  l = pd->lcontent + len + 1;
  if (l > pd->acontent)
    {
      pd->content = (char *)realloc(pd->content, l + 256);
      pd->acontent = l + 256;
    }
  /* append new content to buffer */
  c = pd->content + pd->lcontent;
  pd->lcontent += len;
  while (len-- > 0)
    *c++ = *s++;
  *c = 0;
}

/*-------------------------------------------------------------------*/

#define BUFF_SIZE 8192

/*
 * read 'helix' type xml from fp
 * add packages to pool/repo
 *
 */

int
repo_add_helix(Repo *repo, FILE *fp, int flags)
{
  Pool *pool = repo->pool;
  Parsedata pd;
  Repodata *data;
  char buf[BUFF_SIZE];
  int i, l;
  struct stateswitch *sw;
  unsigned int now;
  XML_Parser parser;

  now = solv_timems(0);
  data = repo_add_repodata(repo, flags);

  /* prepare parsedata */
  memset(&pd, 0, sizeof(pd));
  for (i = 0, sw = stateswitches; sw->from != NUMSTATES; i++, sw++)
    {
      if (!pd.swtab[sw->from])
        pd.swtab[sw->from] = sw;
      pd.sbtab[sw->to] = sw->from;
    }

  pd.pool = pool;
  pd.repo = repo;

  pd.content = (char *)malloc(256);	/* must hold all solvable kinds! */
  pd.acontent = 256;
  pd.lcontent = 0;

  pd.evrspace = (char *)malloc(256);
  pd.aevrspace= 256;
  pd.levrspace = 1;
  pd.data = data;

  /* set up XML parser */

  parser = XML_ParserCreate(NULL);
  XML_SetUserData(parser, &pd);       /* make parserdata available to XML callbacks */
  XML_SetElementHandler(parser, startElement, endElement);
  XML_SetCharacterDataHandler(parser, characterData);

  /* read/parse XML file */
  for (;;)
    {
      l = fread(buf, 1, sizeof(buf), fp);
      if (XML_Parse(parser, buf, l, l == 0) == XML_STATUS_ERROR)
	{
	  pd.ret = pool_error(pool, -1, "%s at line %u", XML_ErrorString(XML_GetErrorCode(parser)), (unsigned int)XML_GetCurrentLineNumber(parser));
	  break;
	}
      if (l == 0)
	break;
    }
  XML_ParserFree(parser);
  free(pd.content);
  free(pd.evrspace);

  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  POOL_DEBUG(SOLV_DEBUG_STATS, "repo_add_helix took %d ms\n", solv_timems(now));
  POOL_DEBUG(SOLV_DEBUG_STATS, "repo size: %d solvables\n", repo->nsolvables);
  POOL_DEBUG(SOLV_DEBUG_STATS, "repo memory used: %d K incore, %d K idarray\n", repodata_memused(data)/1024, repo->idarraysize / (int)(1024/sizeof(Id)));
  return pd.ret;
}
