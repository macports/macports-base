/*
 * Copyright (c) 2007, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

#define _GNU_SOURCE
#define _XOPEN_SOURCE /* glibc2 needs this */
#include <sys/types.h>
#include <limits.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <expat.h>
#include <time.h>

#include "pool.h"
#include "repo.h"
#include "repo_updateinfoxml.h"
#define DISABLE_SPLIT
#include "tools_util.h"

/*
 * <updates>
 *   <update from="rel-eng@fedoraproject.org" status="stable" type="security" version="1.4">
 *     <id>FEDORA-2007-4594</id>
 *     <title>imlib-1.9.15-6.fc8</title>
 *     <severity>Important</severity>
 *     <release>Fedora 8</release>
 *     <rights>Copyright 2007 Company Inc</rights>
 *     <issued date="2007-12-28 16:42:30"/>
 *     <updated date="2008-03-14 12:00:00"/>
 *     <references>
 *       <reference href="https://bugzilla.redhat.com/show_bug.cgi?id=426091" id="426091" title="CVE-2007-3568 imlib: infinite loop DoS using crafted BMP image" type="bugzilla"/>
 *     </references>
 *     <description>This update includes a fix for a denial-of-service issue (CVE-2007-3568) whereby an attacker who could get an imlib-using user to view a  specially-crafted BMP image could cause the user's CPU to go into an infinite loop.</description>
 *     <pkglist>
 *       <collection short="F8">
 *         <name>Fedora 8</name>
 *         <package arch="ppc64" name="imlib-debuginfo" release="6.fc8" src="http://download.fedoraproject.org/pub/fedora/linux/updates/8/ppc64/imlib-debuginfo-1.9.15-6.fc8.ppc64.rpm" version="1.9.15">
 *           <filename>imlib-debuginfo-1.9.15-6.fc8.ppc64.rpm</filename>
 *           <reboot_suggested>True</reboot_suggested>
 *         </package>
 *       </collection>
 *     </pkglist>
 *   </update>
 * </updates>
*/

enum state {
  STATE_START,
  STATE_UPDATES,
  STATE_UPDATE,
  STATE_ID,
  STATE_TITLE,
  STATE_RELEASE,
  STATE_ISSUED,
  STATE_UPDATED,
  STATE_MESSAGE,
  STATE_REFERENCES,
  STATE_REFERENCE,
  STATE_DESCRIPTION,
  STATE_PKGLIST,
  STATE_COLLECTION,
  STATE_NAME,
  STATE_PACKAGE,
  STATE_FILENAME,
  STATE_REBOOT,
  STATE_RESTART,
  STATE_RELOGIN,
  STATE_RIGHTS,
  STATE_SEVERITY,
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
  { STATE_START,       "updates",         STATE_UPDATES,     0 },
  { STATE_START,       "update",          STATE_UPDATE,      0 },
  { STATE_UPDATES,     "update",          STATE_UPDATE,      0 },
  { STATE_UPDATE,      "id",              STATE_ID,          1 },
  { STATE_UPDATE,      "title",           STATE_TITLE,       1 },
  { STATE_UPDATE,      "severity",        STATE_SEVERITY,    1 },
  { STATE_UPDATE,      "rights",          STATE_RIGHTS,      1 },
  { STATE_UPDATE,      "release",         STATE_RELEASE,     1 },
  { STATE_UPDATE,      "issued",          STATE_ISSUED,      0 },
  { STATE_UPDATE,      "updated",         STATE_UPDATED,     0 },
  { STATE_UPDATE,      "description",     STATE_DESCRIPTION, 1 },
  { STATE_UPDATE,      "message",         STATE_MESSAGE    , 1 },
  { STATE_UPDATE,      "references",      STATE_REFERENCES,  0 },
  { STATE_UPDATE,      "pkglist",         STATE_PKGLIST,     0 },
  { STATE_REFERENCES,  "reference",       STATE_REFERENCE,   0 },
  { STATE_PKGLIST,     "collection",      STATE_COLLECTION,  0 },
  { STATE_COLLECTION,  "name",            STATE_NAME,        1 },
  { STATE_COLLECTION,  "package",         STATE_PACKAGE,     0 },
  { STATE_PACKAGE,     "filename",        STATE_FILENAME,    1 },
  { STATE_PACKAGE,     "reboot_suggested",STATE_REBOOT,      1 },
  { STATE_PACKAGE,     "restart_suggested",STATE_RESTART,    1 },
  { STATE_PACKAGE,     "relogin_suggested",STATE_RELOGIN,    1 },
  { NUMSTATES }
};

struct parsedata {
  int ret;
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
  Id handle;
  Solvable *solvable;
  time_t buildtime;
  Id collhandle;
  struct joindata jd;

  struct stateswitch *swtab[NUMSTATES];
  enum state sbtab[NUMSTATES];
};

/*
 * Convert date strings ("1287746075" or "2010-10-22 13:14:35")
 * to timestamp.
 */
static time_t
datestr2timestamp(const char *date)
{
  const char *p;
  struct tm tm;

  if (!date || !*date)
    return 0;
  for (p = date; *p >= '0' && *p <= '9'; p++)
    ;
  if (!*p)
    return atoi(date);
  memset(&tm, 0, sizeof(tm));
  if (!strptime(date, "%F%T", &tm))
    return 0;
  return timegm(&tm);
}

/*
 * create evr (as Id) from 'epoch', 'version' and 'release' attributes
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
      else if (!strcmp(*atts, "version"))
	v = atts[1];
      else if (!strcmp(*atts, "release"))
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
      pd->content = realloc(pd->content, l + 256);
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



static void XMLCALL
startElement(void *userData, const char *name, const char **atts)
{
  struct parsedata *pd = userData;
  Pool *pool = pd->pool;
  Solvable *solvable = pd->solvable;
  struct stateswitch *sw;
  /*const char *str; */

#if 0
  fprintf(stderr, "start: [%d]%s\n", pd->state, name);
#endif
  if (pd->depth != pd->statedepth)
    {
      pd->depth++;
      return;
    }

  pd->depth++;
  if (!pd->swtab[pd->state])
    return;
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
    case STATE_START:
      break;
    case STATE_UPDATES:
      break;
      /*
       * <update from="rel-eng@fedoraproject.org"
       *         status="stable"
       *         type="bugfix" (enhancement, security)
       *         version="1.4">
       */
    case STATE_UPDATE:
      {
	const char *from = 0, *type = 0, *version = 0;
	for (; *atts; atts += 2)
	  {
	    if (!strcmp(*atts, "from"))
	      from = atts[1];
	    else if (!strcmp(*atts, "type"))
	      type = atts[1];
	    else if (!strcmp(*atts, "version"))
	      version = atts[1];
	  }
	solvable = pd->solvable = pool_id2solvable(pool, repo_add_solvable(pd->repo));
	pd->handle = pd->solvable - pool->solvables;

	solvable->vendor = pool_str2id(pool, from, 1);
	solvable->evr = pool_str2id(pool, version, 1);
	solvable->arch = ARCH_NOARCH;
	if (type)
	  repodata_set_str(pd->data, pd->handle, SOLVABLE_PATCHCATEGORY, type);
        pd->buildtime = (time_t)0;
      }
      break;
      /* <id>FEDORA-2007-4594</id> */
    case STATE_ID:
      break;
      /* <title>imlib-1.9.15-6.fc8</title> */
    case STATE_TITLE:
      break;
      /* <release>Fedora 8</release> */
    case STATE_RELEASE:
      break;
      /*  <issued date="2008-03-21 21:36:55"/>
      */
    case STATE_ISSUED:
    case STATE_UPDATED:
      {
	const char *date = 0;
	for (; *atts; atts += 2)
	  {
	    if (!strcmp(*atts, "date"))
	      date = atts[1];
	  }
	if (date)
	  {
	    time_t t = datestr2timestamp(date);
	    if (t && t > pd->buildtime)
              pd->buildtime = t;
	  }
      }
      break;
    case STATE_REFERENCES:
      break;
      /*  <reference href="https://bugzilla.redhat.com/show_bug.cgi?id=330471"
       *             id="330471"
       *             title="LDAP schema file missing for dhcpd"
       *             type="bugzilla"/>
       */
    case STATE_REFERENCE:
      {
        const char *href = 0, *id = 0, *title = 0, *type = 0;
	Id refhandle;
	for (; *atts; atts += 2)
	  {
	    if (!strcmp(*atts, "href"))
	      href = atts[1];
	    else if (!strcmp(*atts, "id"))
	      id = atts[1];
	    else if (!strcmp(*atts, "title"))
	      title = atts[1];
	    else if (!strcmp(*atts, "type"))
	      type = atts[1];
	  }
	refhandle = repodata_new_handle(pd->data);
	if (href)
	  repodata_set_str(pd->data, refhandle, UPDATE_REFERENCE_HREF, href);
	if (id)
	  repodata_set_str(pd->data, refhandle, UPDATE_REFERENCE_ID, id);
	if (title)
	  repodata_set_str(pd->data, refhandle, UPDATE_REFERENCE_TITLE, title);
	if (type)
	  repodata_set_poolstr(pd->data, refhandle, UPDATE_REFERENCE_TYPE, type);
	repodata_add_flexarray(pd->data, pd->handle, UPDATE_REFERENCE, refhandle);
      }
      break;
      /* <description>This update ...</description> */
    case STATE_DESCRIPTION:
      break;
      /* <message type="confirm">This update ...</message> */
    case STATE_MESSAGE:
      break;
    case STATE_PKGLIST:
      break;
      /* <collection short="F8" */
    case STATE_COLLECTION:
      break;
      /* <name>Fedora 8</name> */
    case STATE_NAME:
      break;
      /*   <package arch="ppc64" name="imlib-debuginfo" release="6.fc8"
       *            src="http://download.fedoraproject.org/pub/fedora/linux/updates/8/ppc64/imlib-debuginfo-1.9.15-6.fc8.ppc64.rpm"
       *            version="1.9.15">
       *
       *
       * -> patch.conflicts: {name} < {version}.{release}
       */
    case STATE_PACKAGE:
      {
	const char *arch = 0, *name = 0;
	Id evr = makeevr_atts(pool, pd, atts); /* parse "epoch", "version", "release" */
	Id n, a = 0;
	Id rel_id;

	for (; *atts; atts += 2)
	  {
	    if (!strcmp(*atts, "arch"))
	      arch = atts[1];
	    else if (!strcmp(*atts, "name"))
	      name = atts[1];
	  }
	/* generated Id for name */
	n = pool_str2id(pool, name, 1);
	rel_id = n;
	if (arch)
	  {
	    /*  generate Id for arch and combine with name */
	    a = pool_str2id(pool, arch, 1);
	    rel_id = pool_rel2id(pool, n, a, REL_ARCH, 1);
	  }
	rel_id = pool_rel2id(pool, rel_id, evr, REL_LT, 1);
	solvable->conflicts = repo_addid_dep(pd->repo, solvable->conflicts, rel_id, 0);

        /* who needs the collection anyway? */
        pd->collhandle = repodata_new_handle(pd->data);
	repodata_set_id(pd->data, pd->collhandle, UPDATE_COLLECTION_NAME, n);
	repodata_set_id(pd->data, pd->collhandle, UPDATE_COLLECTION_EVR, evr);
	if (a)
	  repodata_set_id(pd->data, pd->collhandle, UPDATE_COLLECTION_ARCH, a);
        break;
      }
      /* <filename>libntlm-0.4.2-1.fc8.x86_64.rpm</filename> */
      /* <filename>libntlm-0.4.2-1.fc8.x86_64.rpm</filename> */
    case STATE_FILENAME:
      break;
      /* <reboot_suggested>True</reboot_suggested> */
    case STATE_REBOOT:
      break;
      /* <restart_suggested>True</restart_suggested> */
    case STATE_RESTART:
      break;
      /* <relogin_suggested>True</relogin_suggested> */
    case STATE_RELOGIN:
      break;
    default:
      break;
    }
  return;
}


static void XMLCALL
endElement(void *userData, const char *name)
{
  struct parsedata *pd = userData;
  Pool *pool = pd->pool;
  Solvable *s = pd->solvable;
  Repo *repo = pd->repo;

#if 0
      fprintf(stderr, "end: %s\n", name);
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
    case STATE_START:
      break;
    case STATE_UPDATES:
      break;
    case STATE_UPDATE:
      s->provides = repo_addid_dep(repo, s->provides, pool_rel2id(pool, s->name, s->evr, REL_EQ, 1), 0);
      if (pd->buildtime)
	{
	  repodata_set_num(pd->data, pd->handle, SOLVABLE_BUILDTIME, pd->buildtime);
	  pd->buildtime = (time_t)0;
	}
      break;
    case STATE_ID:
      s->name = pool_str2id(pool, join2(&pd->jd, "patch", ":", pd->content), 1);
      break;
      /* <title>imlib-1.9.15-6.fc8</title> */
    case STATE_TITLE:
      while (pd->lcontent > 0 && pd->content[pd->lcontent - 1] == '\n')
        pd->content[--pd->lcontent] = 0;
      repodata_set_str(pd->data, pd->handle, SOLVABLE_SUMMARY, pd->content);
      break;
    case STATE_SEVERITY:
      repodata_set_poolstr(pd->data, pd->handle, UPDATE_SEVERITY, pd->content);
      break;
    case STATE_RIGHTS:
      repodata_set_poolstr(pd->data, pd->handle, UPDATE_RIGHTS, pd->content);
      break;
      /*
       * <release>Fedora 8</release>
       */
    case STATE_RELEASE:
      break;
    case STATE_ISSUED:
      break;
    case STATE_REFERENCES:
      break;
    case STATE_REFERENCE:
      break;
      /*
       * <description>This update ...</description>
       */
    case STATE_DESCRIPTION:
      repodata_set_str(pd->data, pd->handle, SOLVABLE_DESCRIPTION, pd->content);
      break;
      /*
       * <message>Warning! ...</message>
       */
    case STATE_MESSAGE:
      repodata_set_str(pd->data, pd->handle, UPDATE_MESSAGE, pd->content);
      break;
    case STATE_PKGLIST:
      break;
    case STATE_COLLECTION:
      break;
    case STATE_NAME:
      break;
    case STATE_PACKAGE:
      repodata_add_flexarray(pd->data, pd->handle, UPDATE_COLLECTION, pd->collhandle);
      pd->collhandle = 0;
      break;
      /* <filename>libntlm-0.4.2-1.fc8.x86_64.rpm</filename> */
      /* <filename>libntlm-0.4.2-1.fc8.x86_64.rpm</filename> */
    case STATE_FILENAME:
      repodata_set_str(pd->data, pd->collhandle, UPDATE_COLLECTION_FILENAME, pd->content);
      break;
      /* <reboot_suggested>True</reboot_suggested> */
    case STATE_REBOOT:
      if (pd->content[0] == 'T' || pd->content[0] == 't'|| pd->content[0] == '1')
	{
	  /* FIXME: this is per-package, the global flag should be computed at runtime */
	  repodata_set_void(pd->data, pd->handle, UPDATE_REBOOT);
	  repodata_set_void(pd->data, pd->collhandle, UPDATE_REBOOT);
	}
      break;
      /* <restart_suggested>True</restart_suggested> */
    case STATE_RESTART:
      if (pd->content[0] == 'T' || pd->content[0] == 't'|| pd->content[0] == '1')
	{
	  /* FIXME: this is per-package, the global flag should be computed at runtime */
	  repodata_set_void(pd->data, pd->handle, UPDATE_RESTART);
	  repodata_set_void(pd->data, pd->collhandle, UPDATE_RESTART);
	}
      break;
      /* <relogin_suggested>True</relogin_suggested> */
    case STATE_RELOGIN:
      if (pd->content[0] == 'T' || pd->content[0] == 't'|| pd->content[0] == '1')
	{
	  /* FIXME: this is per-package, the global flag should be computed at runtime */
	  repodata_set_void(pd->data, pd->handle, UPDATE_RELOGIN);
	  repodata_set_void(pd->data, pd->collhandle, UPDATE_RELOGIN);
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
    {
#if 0
      fprintf(stderr, "Content: [%d]'%.*s'\n", pd->state, len, s);
#endif
      return;
    }
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

int
repo_add_updateinfoxml(Repo *repo, FILE *fp, int flags)
{
  Pool *pool = repo->pool;
  struct parsedata pd;
  char buf[BUFF_SIZE];
  int i, l;
  struct stateswitch *sw;
  Repodata *data;
  XML_Parser parser;

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

  pd.content = malloc(256);
  pd.acontent = 256;
  pd.lcontent = 0;
  parser = XML_ParserCreate(NULL);
  XML_SetUserData(parser, &pd);
  XML_SetElementHandler(parser, startElement, endElement);
  XML_SetCharacterDataHandler(parser, characterData);
  for (;;)
    {
      l = fread(buf, 1, sizeof(buf), fp);
      if (XML_Parse(parser, buf, l, l == 0) == XML_STATUS_ERROR)
	{
	  pd.ret = pool_error(pool, -1, "repo_updateinfoxml: %s at line %u:%u", XML_ErrorString(XML_GetErrorCode(parser)), (unsigned int)XML_GetCurrentLineNumber(parser), (unsigned int)XML_GetCurrentColumnNumber(parser));
	  break;
	}
      if (l == 0)
	break;
    }
  XML_ParserFree(parser);
  free(pd.content);
  join_freemem(&pd.jd);

  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return pd.ret;
}

