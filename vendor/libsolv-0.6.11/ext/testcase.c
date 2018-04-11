/*
 * Copyright (c) 2012, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <limits.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "pool.h"
#include "poolarch.h"
#include "poolvendor.h"
#include "repo.h"
#include "repo_solv.h"
#include "solver.h"
#include "solverdebug.h"
#include "chksum.h"
#include "testcase.h"
#include "selection.h"
#include "solv_xfopen.h"

#define DISABLE_JOIN2
#include "tools_util.h"

static struct job2str {
  Id job;
  const char *str;
} job2str[] = {
  { SOLVER_NOOP,          "noop" },
  { SOLVER_INSTALL,       "install" },
  { SOLVER_ERASE,         "erase" },
  { SOLVER_UPDATE,        "update" },
  { SOLVER_WEAKENDEPS,    "weakendeps" },
  { SOLVER_MULTIVERSION,  "multiversion" },
  { SOLVER_MULTIVERSION,  "noobsoletes" },	/* old name */
  { SOLVER_LOCK,          "lock" },
  { SOLVER_DISTUPGRADE,   "distupgrade" },
  { SOLVER_VERIFY,        "verify" },
  { SOLVER_DROP_ORPHANED, "droporphaned" },
  { SOLVER_USERINSTALLED, "userinstalled" },
  { 0, 0 }
};

static struct jobflags2str {
  Id flag;
  const char *str;
} jobflags2str[] = {
  { SOLVER_WEAK,      "weak" },
  { SOLVER_ESSENTIAL, "essential" },
  { SOLVER_CLEANDEPS, "cleandeps" },
  { SOLVER_ORUPDATE,  "orupdate" },
  { SOLVER_FORCEBEST, "forcebest" },
  { SOLVER_TARGETED,  "targeted" },
  { SOLVER_NOTBYUSER, "notbyuser" },
  { SOLVER_SETEV,     "setev" },
  { SOLVER_SETEVR,    "setevr" },
  { SOLVER_SETARCH,   "setarch" },
  { SOLVER_SETVENDOR, "setvendor" },
  { SOLVER_SETREPO,   "setrepo" },
  { SOLVER_NOAUTOSET, "noautoset" },
  { 0, 0 }
};

static struct resultflags2str {
  Id flag;
  const char *str;
} resultflags2str[] = {
  { TESTCASE_RESULT_TRANSACTION,	"transaction" },
  { TESTCASE_RESULT_PROBLEMS,		"problems" },
  { TESTCASE_RESULT_ORPHANED,		"orphaned" },
  { TESTCASE_RESULT_RECOMMENDED,	"recommended" },
  { TESTCASE_RESULT_UNNEEDED,		"unneeded" },
  { TESTCASE_RESULT_ALTERNATIVES,	"alternatives" },
  { TESTCASE_RESULT_RULES,		"rules" },
  { TESTCASE_RESULT_GENID,		"genid" },
  { 0, 0 }
};

static struct solverflags2str {
  Id flag;
  const char *str;
  int def;
} solverflags2str[] = {
  { SOLVER_FLAG_ALLOW_DOWNGRADE,            "allowdowngrade", 0 },
  { SOLVER_FLAG_ALLOW_NAMECHANGE,           "allownamechange", 1 },
  { SOLVER_FLAG_ALLOW_ARCHCHANGE,           "allowarchchange", 0 },
  { SOLVER_FLAG_ALLOW_VENDORCHANGE,         "allowvendorchange", 0 },
  { SOLVER_FLAG_ALLOW_UNINSTALL,            "allowuninstall", 0 },
  { SOLVER_FLAG_NO_UPDATEPROVIDE,           "noupdateprovide", 0 },
  { SOLVER_FLAG_SPLITPROVIDES,              "splitprovides", 0 },
  { SOLVER_FLAG_IGNORE_RECOMMENDED,         "ignorerecommended", 0 },
  { SOLVER_FLAG_ADD_ALREADY_RECOMMENDED,    "addalreadyrecommended", 0 },
  { SOLVER_FLAG_NO_INFARCHCHECK,            "noinfarchcheck", 0 },
  { SOLVER_FLAG_KEEP_EXPLICIT_OBSOLETES,    "keepexplicitobsoletes", 0 },
  { SOLVER_FLAG_BEST_OBEY_POLICY,           "bestobeypolicy", 0 },
  { SOLVER_FLAG_NO_AUTOTARGET,              "noautotarget", 0 },
  { SOLVER_FLAG_DUP_ALLOW_DOWNGRADE,        "dupallowdowngrade", 1 },
  { SOLVER_FLAG_DUP_ALLOW_ARCHCHANGE,       "dupallowarchchange", 1 },
  { SOLVER_FLAG_DUP_ALLOW_VENDORCHANGE,     "dupallowvendorchange", 1 },
  { SOLVER_FLAG_DUP_ALLOW_NAMECHANGE,       "dupallownamechange", 1 },
  { SOLVER_FLAG_KEEP_ORPHANS,               "keeporphans", 0 },
  { SOLVER_FLAG_BREAK_ORPHANS,              "breakorphans", 0 },
  { SOLVER_FLAG_FOCUS_INSTALLED,            "focusinstalled", 0 },
  { SOLVER_FLAG_YUM_OBSOLETES,              "yumobsoletes", 0 },
  { SOLVER_FLAG_NEED_UPDATEPROVIDE,         "needupdateprovide", 0 },
  { 0, 0, 0 }
};

static struct poolflags2str {
  Id flag;
  const char *str;
  int def;
} poolflags2str[] = {
  { POOL_FLAG_PROMOTEEPOCH,                 "promoteepoch", 0 },
  { POOL_FLAG_FORBIDSELFCONFLICTS,          "forbidselfconflicts", 0 },
  { POOL_FLAG_OBSOLETEUSESPROVIDES,         "obsoleteusesprovides", 0 },
  { POOL_FLAG_IMPLICITOBSOLETEUSESPROVIDES, "implicitobsoleteusesprovides", 0 },
  { POOL_FLAG_OBSOLETEUSESCOLORS,           "obsoleteusescolors", 0 },
  { POOL_FLAG_IMPLICITOBSOLETEUSESCOLORS,   "implicitobsoleteusescolors", 0 },
  { POOL_FLAG_NOINSTALLEDOBSOLETES,         "noinstalledobsoletes", 0 },
  { POOL_FLAG_HAVEDISTEPOCH,                "havedistepoch", 0 },
  { POOL_FLAG_NOOBSOLETESMULTIVERSION,      "noobsoletesmultiversion", 0 },
  { POOL_FLAG_ADDFILEPROVIDESFILTERED,      "addfileprovidesfiltered", 0 },
  { POOL_FLAG_NOWHATPROVIDESAUX,            "nowhatprovidesaux", 0 },
  { 0, 0, 0 }
};

static struct disttype2str {
  Id type;
  const char *str;
} disttype2str[] = {
  { DISTTYPE_RPM,  "rpm" },
  { DISTTYPE_DEB,  "deb" },
  { DISTTYPE_ARCH, "arch" },
  { DISTTYPE_HAIKU, "haiku" },
  { 0, 0 }
};

static struct selflags2str {
  Id flag;
  const char *str;
} selflags2str[] = {
  { SELECTION_NAME, "name" },
  { SELECTION_PROVIDES, "provides" },
  { SELECTION_FILELIST, "filelist" },
  { SELECTION_CANON, "canon" },
  { SELECTION_DOTARCH, "dotarch" },
  { SELECTION_REL, "rel" },
  { SELECTION_INSTALLED_ONLY, "installedonly" },
  { SELECTION_GLOB, "glob" },
  { SELECTION_FLAT, "flat" },
  { SELECTION_NOCASE, "nocase" },
  { SELECTION_SOURCE_ONLY, "sourceonly" },
  { SELECTION_WITH_SOURCE, "withsource" },
  { 0, 0 }
};

static const char *features[] = {
#ifdef ENABLE_LINKED_PACKAGES
  "linked_packages",
#endif
#ifdef ENABLE_COMPLEX_DEPS
  "complex_deps",
#endif
  0
};

typedef struct strqueue {
  char **str;
  int nstr;
} Strqueue;

#define STRQUEUE_BLOCK 63

static void
strqueue_init(Strqueue *q)
{
  q->str = 0;
  q->nstr = 0;
}

static void
strqueue_free(Strqueue *q)
{
  int i;
  for (i = 0; i < q->nstr; i++)
    solv_free(q->str[i]);
  q->str = solv_free(q->str);
  q->nstr = 0;
}

static void
strqueue_push(Strqueue *q, const char *s)
{
  q->str = solv_extend(q->str, q->nstr, 1, sizeof(*q->str), STRQUEUE_BLOCK);
  q->str[q->nstr++] = solv_strdup(s);
}

static void
strqueue_pushjoin(Strqueue *q, const char *s1, const char *s2, const char *s3)
{
  q->str = solv_extend(q->str, q->nstr, 1, sizeof(*q->str), STRQUEUE_BLOCK);
  q->str[q->nstr++] = solv_dupjoin(s1, s2, s3);
}

static int
strqueue_sort_cmp(const void *ap, const void *bp, void *dp)
{
  const char *a = *(const char **)ap;
  const char *b = *(const char **)bp;
  return strcmp(a ? a : "", b ? b : "");
}

static void
strqueue_sort(Strqueue *q)
{
  if (q->nstr > 1)
    solv_sort(q->str, q->nstr, sizeof(*q->str), strqueue_sort_cmp, 0);
}

static void
strqueue_sort_u(Strqueue *q)
{
  int i, j;
  strqueue_sort(q);
  for (i = j = 0; i < q->nstr; i++)
    if (!j || strqueue_sort_cmp(q->str + i, q->str + j - 1, 0) != 0)
      q->str[j++] = q->str[i];
  q->nstr = j;
}

static char *
strqueue_join(Strqueue *q)
{
  int i, l = 0;
  char *r, *rp;
  for (i = 0; i < q->nstr; i++)
    if (q->str[i])
      l += strlen(q->str[i]) + 1;
  l++;	/* trailing \0 */
  r = solv_malloc(l);
  rp = r;
  for (i = 0; i < q->nstr; i++)
    if (q->str[i])
      {
        strcpy(rp, q->str[i]);
        rp += strlen(rp);
	*rp++ = '\n';
      }
  *rp = 0;
  return r;
}

static void
strqueue_split(Strqueue *q, const char *s)
{
  const char *p;
  if (!s)
    return;
  while ((p = strchr(s, '\n')) != 0)
    {
      q->str = solv_extend(q->str, q->nstr, 1, sizeof(*q->str), STRQUEUE_BLOCK);
      q->str[q->nstr] = solv_malloc(p - s + 1);
      if (p > s)
	memcpy(q->str[q->nstr], s, p - s);
      q->str[q->nstr][p - s] = 0;
      q->nstr++;
      s = p + 1;
    }
  if (*s)
    strqueue_push(q, s);
}

static void
strqueue_diff(Strqueue *sq1, Strqueue *sq2, Strqueue *osq)
{
  int i = 0, j = 0;
  while (i < sq1->nstr && j < sq2->nstr)
    {
      int r = strqueue_sort_cmp(sq1->str + i, sq2->str + j, 0);
      if (!r)
	i++, j++;
      else if (r < 0)
	strqueue_pushjoin(osq, "-", sq1->str[i++], 0);
      else
	strqueue_pushjoin(osq, "+", sq2->str[j++], 0);
    }
  while (i < sq1->nstr)
    strqueue_pushjoin(osq, "-", sq1->str[i++], 0);
  while (j < sq2->nstr)
    strqueue_pushjoin(osq, "+", sq2->str[j++], 0);
}


static const char *
testcase_id2str(Pool *pool, Id id, int isname)
{
  const char *s = pool_id2str(pool, id);
  const char *ss;
  char *s2, *s2p;
  int bad = 0, paren = 0, parenbad = 0;

  if (id == 0)
    return "<NULL>";
  if (id == 1)
    return "\\00";
  if (strchr("[(<=>!", *s))
    bad++;
  if (!strncmp(s, "namespace:", 10))
    bad++;
  for (ss = s + bad; *ss; ss++)
    {
      if (*ss == ' ' || *ss == '\\' || *(unsigned char *)ss < 32 || *ss == '(' || *ss == ')')
        bad++;
      if (*ss == '(')
	paren = paren == 0 ? 1 : -1;
      else if (*ss == ')')
	{
	  paren = paren == 1 ? 0 : -1;
	  if (!paren)
	    parenbad += 2;
	}
    }
  if (isname && ss - s > 4 && !strcmp(ss - 4, ":any"))
    bad++;
  if (!paren && !(bad - parenbad))
    return s;

  /* we need escaping! */
  s2 = s2p = pool_alloctmpspace(pool, strlen(s) + bad * 2 + 1);
  if (!strncmp(s, "namespace:", 10))
    {
      strcpy(s2p, "namespace\\3a");
      s2p += 12;
      s += 10;
    }
  ss = s;
  for (; *ss; ss++)
    {
      *s2p++ = *ss;
      if ((ss == s && strchr("[(<=>!", *s)) || *ss == ' ' || *ss == '\\' || *(unsigned char *)ss < 32 || *ss == '(' || *ss == ')')
	{
	  s2p[-1] = '\\';
	  solv_bin2hex((unsigned char *)ss, 1, s2p);
	  s2p += 2;
	}
    }
  *s2p = 0;
  if (isname && s2p - s2 > 4 && !strcmp(s2p - 4, ":any"))
    strcpy(s2p - 4, "\\3aany");
  return s2;
}

struct oplist {
  Id flags;
  const char *opname;
} oplist[] = {
  { REL_EQ, "=" },
  { REL_GT | REL_LT | REL_EQ, "<=>" },
  { REL_LT | REL_EQ, "<=" },
  { REL_GT | REL_EQ, ">=" },
  { REL_GT, ">" },
  { REL_GT | REL_LT, "<>" },
  { REL_AND,   "&" },
  { REL_OR ,   "|" },
  { REL_WITH , "+" },
  { REL_NAMESPACE , "<NAMESPACE>" },
  { REL_ARCH,       "." },
  { REL_MULTIARCH,  "<MULTIARCH>" },
  { REL_FILECONFLICT,  "<FILECONFLICT>" },
  { REL_COND,  "<IF>" },
  { REL_COMPAT,  "compat >=" },
  { REL_KIND,  "<KIND>" },
  { REL_LT, "<" },
  { 0, 0 }
};

static const char *
testcase_dep2str_complex(Pool *pool, Id id, int addparens)
{
  Reldep *rd;
  char *s;
  const char *s2;
  int needparens;
  struct oplist *op;

  if (!ISRELDEP(id))
    return testcase_id2str(pool, id, 1);
  rd = GETRELDEP(pool, id);

  /* check for special shortcuts */
  if (rd->flags == REL_NAMESPACE && !ISRELDEP(rd->name) && !strncmp(pool_id2str(pool, rd->name), "namespace:", 10))
    {
      const char *ns = pool_id2str(pool, rd->name);
      int nslen = strlen(ns);
      /* special namespace formatting */
      const char *evrs = testcase_dep2str_complex(pool, rd->evr, 0);
      s = pool_tmpappend(pool, evrs, ns, "()");
      memmove(s + nslen + 1, s, strlen(s) - nslen - 2);
      memcpy(s, ns, nslen);
      s[nslen] = '(';
      return s;
    }
  if (rd->flags == REL_MULTIARCH && !ISRELDEP(rd->name) && rd->evr == ARCH_ANY)
    {
      /* special :any suffix */
      const char *ns = testcase_id2str(pool, rd->name, 1);
      return pool_tmpappend(pool, ns, ":any", 0);
    }

  needparens = 0;
  if (ISRELDEP(rd->name))
    {
      Reldep *rd2 = GETRELDEP(pool, rd->name);
      needparens = 1;
      if (rd->flags > 7 && rd->flags != REL_COMPAT && rd2->flags && rd2->flags <= 7)
	needparens = 0;
    }
  s = (char *)testcase_dep2str_complex(pool, rd->name, needparens);

  if (addparens)
    {
      s = pool_tmpappend(pool, s, "(", 0);
      memmove(s + 1, s, strlen(s + 1));
      s[0] = '(';
    }
  for (op = oplist; op->flags; op++)
    if (rd->flags == op->flags)
      break;
  if (op->flags)
    {
      s = pool_tmpappend(pool, s, " ", op->opname);
      s = pool_tmpappend(pool, s, " ", 0);
    }
  else
    {
      char buf[64];
      sprintf(buf, " <%u> ", rd->flags);
      s = pool_tmpappend(pool, s, buf, 0);
    }

  needparens = 0;
  if (ISRELDEP(rd->evr))
    {
      Reldep *rd2 = GETRELDEP(pool, rd->evr);
      needparens = 1;
      if (rd->flags > 7 && rd2->flags && rd2->flags <= 7)
	needparens = 0;
      if (rd->flags == REL_AND && rd2->flags == REL_AND)
	needparens = 0;	/* chain */
      if (rd->flags == REL_OR && rd2->flags == REL_OR)
	needparens = 0;	/* chain */
      if (rd->flags > 0 && rd->flags < 8 && rd2->flags == REL_COMPAT)
	needparens = 0;	/* chain */
    }
  if (!ISRELDEP(rd->evr))
    s2 = testcase_id2str(pool, rd->evr, 0);
  else
    s2 = testcase_dep2str_complex(pool, rd->evr, needparens);
  if (addparens)
    s = pool_tmpappend(pool, s, s2, ")");
  else
    s = pool_tmpappend(pool, s, s2, 0);
  pool_freetmpspace(pool, s2);
  return s;
}

const char *
testcase_dep2str(Pool *pool, Id id)
{
  return testcase_dep2str_complex(pool, id, 0);
}


/* Convert a simple string. Also handle the :any suffix */
static Id
testcase_str2dep_simple(Pool *pool, const char **sp, int isname)
{
  int haveesc = 0;
  int paren = 0;
  int isany = 0;
  Id id;
  const char *s;
  for (s = *sp; *s; s++)
    {
      if (*s == '\\')
	haveesc++;
      if (*s == ' ' || *(unsigned char *)s < 32)
	break;
      if (*s == '(')
	paren++;
      if (*s == ')' && paren-- <= 0)
	break;
    }
  if (isname && s - *sp > 4 && !strncmp(s - 4, ":any", 4))
    {
      isany = 1;
      s -= 4;
    }
  if (!haveesc)
    {
      if (s - *sp == 6 && !strncmp(*sp, "<NULL>", 6))
	id = 0;
      else
        id = pool_strn2id(pool, *sp, s - *sp, 1);
    }
  else if (s - *sp == 3 && !strncmp(*sp, "\\00", 3))
    id = 1;
  else
    {
      char buf[128], *bp, *bp2;
      const char *sp2;
      bp = s - *sp >= 128 ? solv_malloc(s - *sp + 1) : buf;
      for (bp2 = bp, sp2 = *sp; sp2 < s;)
	{
	  *bp2++ = *sp2++;
	  if (bp2[-1] == '\\')
	    solv_hex2bin(&sp2, (unsigned char *)bp2 - 1, 1);
	}
      *bp2 = 0;
      id = pool_str2id(pool, bp, 1);
      if (bp != buf)
	solv_free(bp);
    }
  if (isany)
    {
      id = pool_rel2id(pool, id, ARCH_ANY, REL_MULTIARCH, 1);
      s += 4;
    }
  *sp = s;
  return id;
}


static Id
testcase_str2dep_complex(Pool *pool, const char **sp, int relop)
{
  const char *s = *sp;
  Id flags, id, id2, namespaceid = 0;
  struct oplist *op;

  while (*s == ' ' || *s == '\t')
    s++;
  if (!strncmp(s, "namespace:", 10))
    {
      /* special namespace hack */
      const char *s2;
      for (s2 = s + 10; *s2 && *s2 != '('; s2++)
	;
      if (*s2 == '(')
	{
	  namespaceid = pool_strn2id(pool, s, s2 - s, 1);
	  s = s2;
	}
    }
  if (*s == '(')
    {
      s++;
      id = testcase_str2dep_complex(pool, &s, 0);
      if (!s || *s != ')')
	{
	  *sp = 0;
	  return 0;
	}
      s++;
    }
  else
    id = testcase_str2dep_simple(pool, &s, relop ? 0 : 1);
  if (namespaceid)
    id = pool_rel2id(pool, namespaceid, id, REL_NAMESPACE, 1);
    
  for (;;)
    {
      while (*s == ' ' || *s == '\t')
	s++;
      if (!*s || *s == ')' || (relop && strncmp(s, "compat >= ", 10) != 0))
	{
	  *sp = s;
	  return id;
	}

      /* we have an op! Find the end */
      flags = -1;
      if (s[0] == '<' && (s[1] >= '0' && s[1] <= '9'))
	{
	  const char *s2;
	  for (s2 = s + 1; *s2 >= '0' && *s2 <= '9'; s2++)
	    ;
	  if (*s2 == '>')
	    {
	      flags = strtoul(s + 1, 0, 10);
	      s = s2 + 1;
	    }
	}
      if (flags == -1)
	{
	  for (op = oplist; op->flags; op++)
	    if (!strncmp(s, op->opname, strlen(op->opname)))
	      break;
	  if (!op->flags)
	    {
	      *sp = 0;
	      return 0;
	    }
	  flags = op->flags;
	  s += strlen(op->opname);
	}
      id2 = testcase_str2dep_complex(pool, &s, flags > 0 && flags < 8);
      if (!s)
	{
	  *sp = 0;
	  return 0;
	}
      id = pool_rel2id(pool, id, id2, flags, 1);
    }
}

Id
testcase_str2dep(Pool *pool, const char *s)
{
  Id id = testcase_str2dep_complex(pool, &s, 0);
  return s && !*s ? id : 0;
}

/**********************************************************/

const char *
testcase_repoid2str(Pool *pool, Id repoid)
{
  Repo *repo = pool_id2repo(pool, repoid);
  if (repo->name)
    {
      char *r = pool_tmpjoin(pool, repo->name, 0, 0);
      char *rp;
      for (rp = r; *rp; rp++)
	if (*rp == ' ' || *rp == '\t')
	  *rp = '_';
      return r;
    }
  else
    {
      char buf[20];
      sprintf(buf, "#%d", repoid);
      return pool_tmpjoin(pool, buf, 0, 0);
    }
}

const char *
testcase_solvid2str(Pool *pool, Id p)
{
  Solvable *s = pool->solvables + p;
  const char *n, *e, *a;
  char *str, buf[20];

  if (p == SYSTEMSOLVABLE)
    return "@SYSTEM";
  n = pool_id2str(pool, s->name);
  e = pool_id2str(pool, s->evr);
  a = pool_id2str(pool, s->arch);
  str = pool_alloctmpspace(pool, strlen(n) + strlen(e) + strlen(a) + 3);
  sprintf(str, "%s-%s.%s", n, e, a);
  if (!s->repo)
    return pool_tmpappend(pool, str, "@", 0);
  if (s->repo->name)
    {
      int l = strlen(str);
      char *str2 = pool_tmpappend(pool, str, "@", s->repo->name);
      for (; str2[l]; l++)
	if (str2[l] == ' ' || str2[l] == '\t')
	  str2[l] = '_';
      return str2;
    }
  sprintf(buf, "@#%d", s->repo->repoid);
  return pool_tmpappend(pool, str, buf, 0);
}

Repo *
testcase_str2repo(Pool *pool, const char *str)
{
  int repoid;
  Repo *repo = 0;
  if (str[0] == '#' && (str[1] >= '0' && str[1] <= '9'))
    {
      int j;
      repoid = 0;
      for (j = 1; str[j] >= '0' && str[j] <= '9'; j++)
	repoid = repoid * 10 + (str[j] - '0');
      if (!str[j] && repoid > 0 && repoid < pool->nrepos)
	repo = pool_id2repo(pool, repoid);
    }
  if (!repo)
    {
      FOR_REPOS(repoid, repo)
	{
	  int i, l;
	  if (!repo->name)
	    continue;
	  l = strlen(repo->name);
	  for (i = 0; i < l; i++)
	    {
	      int c = repo->name[i];
	      if (c == ' ' || c == '\t')
		c = '_';
	      if (c != str[i])
		break;
	    }
	  if (i == l && !str[l])
	    break;
	}
      if (repoid >= pool->nrepos)
	repo = 0;
    }
  return repo;
}

Id
testcase_str2solvid(Pool *pool, const char *str)
{
  int i, l = strlen(str);
  int repostart;
  Repo *repo;
  Id arch;

  if (!l)
    return 0;
  if (*str == '@' && !strcmp(str, "@SYSTEM"))
    return SYSTEMSOLVABLE;
  repo = 0;
  for (i = l - 1; i >= 0; i--)
    if (str[i] == '@' && (repo = testcase_str2repo(pool, str + i + 1)) != 0)
      break;
  if (i < 0)
    i = l;
  repostart = i;
  /* now find the arch (if present) */
  arch = 0;
  for (i = repostart - 1; i > 0; i--)
    if (str[i] == '.')
      {
	arch = pool_strn2id(pool, str + i + 1, repostart - (i + 1), 0);
	if (arch)
	  repostart = i;
	break;
      }
  /* now find the name */
  for (i = repostart - 1; i > 0; i--)
    {
      if (str[i] == '-')
	{
	  Id nid, evrid, p, pp;
	  nid = pool_strn2id(pool, str, i, 0);
	  if (!nid)
	    continue;
	  evrid = pool_strn2id(pool, str + i + 1, repostart - (i + 1), 0);
	  if (!evrid)
	    continue;
	  FOR_PROVIDES(p, pp, nid)
	    {
	      Solvable *s = pool->solvables + p;
	      if (s->name != nid || s->evr != evrid)
		continue;
	      if (repo && s->repo != repo)
		continue;
	      if (arch && s->arch != arch)
		continue;
	      return p;
	    }
	}
    }
  return 0;
}

const char *
testcase_job2str(Pool *pool, Id how, Id what)
{
  char *ret;
  const char *jobstr;
  const char *selstr;
  const char *pkgstr;
  int i, o;
  Id select = how & SOLVER_SELECTMASK;

  for (i = 0; job2str[i].str; i++)
    if ((how & SOLVER_JOBMASK) == job2str[i].job)
      break;
  jobstr = job2str[i].str ? job2str[i].str : "unknown";
  if (select == SOLVER_SOLVABLE)
    {
      selstr = " pkg ";
      pkgstr = testcase_solvid2str(pool, what);
    }
  else if (select == SOLVER_SOLVABLE_NAME)
    {
      selstr = " name ";
      pkgstr = testcase_dep2str(pool, what);
    }
  else if (select == SOLVER_SOLVABLE_PROVIDES)
    {
      selstr = " provides ";
      pkgstr = testcase_dep2str(pool, what);
    }
  else if (select == SOLVER_SOLVABLE_ONE_OF)
    {
      Id p;
      selstr = " oneof ";
      pkgstr = 0;
      while ((p = pool->whatprovidesdata[what++]) != 0)
	{
	  const char *s = testcase_solvid2str(pool, p);
	  if (pkgstr)
	    {
	      pkgstr = pool_tmpappend(pool, pkgstr, " ", s);
	      pool_freetmpspace(pool, s);
	    }
	  else
	    pkgstr = s;
	}
      if (!pkgstr)
	pkgstr = "nothing";
    }
  else if (select == SOLVER_SOLVABLE_REPO)
    {
      Repo *repo = pool_id2repo(pool, what);
      selstr = " repo ";
      if (!repo->name)
	{
          char buf[20];
	  sprintf(buf, "#%d", repo->repoid);
	  pkgstr = pool_tmpjoin(pool, buf, 0, 0);
	}
      else
        pkgstr = pool_tmpjoin(pool, repo->name, 0, 0);
    }
  else if (select == SOLVER_SOLVABLE_ALL)
    {
      selstr = " all ";
      pkgstr = "packages";
    }
  else
    {
      selstr = " unknown ";
      pkgstr = "unknown";
    }
  ret = pool_tmpjoin(pool, jobstr, selstr, pkgstr);
  o = strlen(ret);
  ret = pool_tmpappend(pool, ret, " ", 0);
  for (i = 0; jobflags2str[i].str; i++)
    if ((how & jobflags2str[i].flag) != 0)
      ret = pool_tmpappend(pool, ret, ",", jobflags2str[i].str);
  if (!ret[o + 1])
    ret[o] = 0;
  else
    {
      ret[o + 1] = '[';
      ret = pool_tmpappend(pool, ret, "]", 0);
    }
  return ret;
}

static int
str2selflags(Pool *pool, char *s)	/* modifies the string! */
{
  int i, selflags = 0;
  while (s)
    {
      char *se = strchr(s, ',');
      if (se)
	*se++ = 0;
      for (i = 0; selflags2str[i].str; i++)
	if (!strcmp(s, selflags2str[i].str))
	  {
	    selflags |= selflags2str[i].flag;
	    break;
	  }
      if (!selflags2str[i].str)
	pool_debug(pool, SOLV_ERROR, "str2job: unknown selection flag '%s'\n", s);
      s = se;
    }
  return selflags;
}

static int
str2jobflags(Pool *pool, char *s)	/* modifies the string */
{
  int i, jobflags = 0;
  while (s)
    {
      char *se = strchr(s, ',');
      if (se)
	*se++ = 0;
      for (i = 0; jobflags2str[i].str; i++)
	if (!strcmp(s, jobflags2str[i].str))
	  {
	    jobflags |= jobflags2str[i].flag;
	    break;
	  }
      if (!jobflags2str[i].str)
	pool_debug(pool, SOLV_ERROR, "str2job: unknown job flag '%s'\n", s);
      s = se;
    }
  return jobflags;
}

Id
testcase_str2job(Pool *pool, const char *str, Id *whatp)
{
  int i;
  Id job;
  Id what;
  char *s;
  char **pieces = 0;
  int npieces = 0;

  *whatp = 0;
  /* so we can patch it */
  s = pool_tmpjoin(pool, str, 0, 0);
  /* split it in pieces */
  for (;;)
    {
      while (*s == ' ' || *s == '\t')
	s++;
      if (!*s)
	break;
      pieces = solv_extend(pieces, npieces, 1, sizeof(*pieces), 7);
      pieces[npieces++] = s;
      while (*s && *s != ' ' && *s != '\t')
	s++;
      if (*s)
	*s++ = 0;
    }
  if (npieces < 3)
    {
      pool_debug(pool, SOLV_ERROR, "str2job: bad line '%s'\n", str);
      solv_free(pieces);
      return -1;
    }

  for (i = 0; job2str[i].str; i++)
    if (!strcmp(pieces[0], job2str[i].str))
      break;
  if (!job2str[i].str)
    {
      pool_debug(pool, SOLV_ERROR, "str2job: unknown job '%s'\n", str);
      solv_free(pieces);
      return -1;
    }
  job = job2str[i].job;
  what = 0;
  if (npieces > 3)
    {
      char *flags = pieces[npieces - 1];
      if (*flags == '[' && flags[strlen(flags) - 1] == ']')
	{
	  npieces--;
	  flags++;
	  flags[strlen(flags) - 1] = 0;
	  job |= str2jobflags(pool, flags);
	}
    }
  if (!strcmp(pieces[1], "pkg"))
    {
      if (npieces != 3)
	{
	  pool_debug(pool, SOLV_ERROR, "str2job: bad pkg selector in '%s'\n", str);
	  solv_free(pieces);
	  return -1;
	}
      job |= SOLVER_SOLVABLE;
      what = testcase_str2solvid(pool, pieces[2]);
      if (!what)
	{
	  pool_debug(pool, SOLV_ERROR, "str2job: unknown package '%s'\n", pieces[2]);
	  solv_free(pieces);
	  return -1;
	}
    }
  else if (!strcmp(pieces[1], "name") || !strcmp(pieces[1], "provides"))
    {
      /* join em again for dep2str... */
      char *sp;
      for (sp = pieces[2]; sp < pieces[npieces - 1]; sp++)
	if (*sp == 0)
	  *sp = ' ';
      what = 0;
      if (pieces[1][0] == 'p' && strncmp(pieces[2], "namespace:", 10) == 0)
	{
	  char *spe = strchr(pieces[2], '(');
	  int l = strlen(pieces[2]);
	  if (spe && pieces[2][l - 1] == ')')
	    {
	      /* special namespace provides */
	      if (strcmp(spe, "(<NULL>)") != 0)
		{
		  pieces[2][l - 1] = 0;
		  what = testcase_str2dep(pool, spe + 1);
		  pieces[2][l - 1] = ')';
		}
	      what = pool_rel2id(pool, pool_strn2id(pool, pieces[2], spe - pieces[2], 1), what, REL_NAMESPACE, 1);
	    }
	}
      if (!what)
        what = testcase_str2dep(pool, pieces[2]);
      if (pieces[1][0] == 'n')
	job |= SOLVER_SOLVABLE_NAME;
      else
	job |= SOLVER_SOLVABLE_PROVIDES;
    }
  else if (!strcmp(pieces[1], "oneof"))
    {
      Queue q;
      job |= SOLVER_SOLVABLE_ONE_OF;
      queue_init(&q);
      if (npieces > 3 && strcmp(pieces[2], "nothing") != 0)
	{
	  for (i = 2; i < npieces; i++)
	    {
	      Id p = testcase_str2solvid(pool, pieces[i]);
	      if (!p)
		{
		  pool_debug(pool, SOLV_ERROR, "str2job: unknown package '%s'\n", pieces[i]);
		  queue_free(&q);
		  solv_free(pieces);
		  return -1;
		}
	      queue_push(&q, p);
	    }
	}
      what = pool_queuetowhatprovides(pool, &q);
      queue_free(&q);
    }
  else if (!strcmp(pieces[1], "repo"))
    {
      Repo *repo;
      if (npieces != 3)
	{
	  pool_debug(pool, SOLV_ERROR, "str2job: bad line '%s'\n", str);
	  solv_free(pieces);
	  return -1;
	}
      repo = testcase_str2repo(pool, pieces[2]);
      if (!repo)
	{
	  pool_debug(pool, SOLV_ERROR, "str2job: unknown repo '%s'\n", pieces[2]);
	  solv_free(pieces);
	  return -1;
	}
      job |= SOLVER_SOLVABLE_REPO;
      what = repo->repoid;
    }
  else if (!strcmp(pieces[1], "all"))
    {
      if (npieces != 3 && strcmp(pieces[2], "packages") != 0)
	{
	  pool_debug(pool, SOLV_ERROR, "str2job: bad line '%s'\n", str);
	  solv_free(pieces);
	  return -1;
	}
      job |= SOLVER_SOLVABLE_ALL;
      what = 0;
    }
  else
    {
      pool_debug(pool, SOLV_ERROR, "str2job: unknown selection in '%s'\n", str);
      solv_free(pieces);
      return -1;
    }
  *whatp = what;
  solv_free(pieces);
  return job;
}

int
addselectionjob(Pool *pool, char **pieces, int npieces, Queue *jobqueue)
{
  Id job;
  int i, r;
  int selflags;
  Queue sel;

  for (i = 0; job2str[i].str; i++)
    if (!strcmp(pieces[0], job2str[i].str))
      break;
  if (!job2str[i].str)
    {
      pool_debug(pool, SOLV_ERROR, "selstr2job: unknown job '%s'\n", pieces[0]);
      return -1;
    }
  job = job2str[i].job;
  if (npieces > 3)
    {
      char *flags = pieces[npieces - 1];
      if (*flags == '[' && flags[strlen(flags) - 1] == ']')
	{
	  npieces--;
	  flags++;
	  flags[strlen(flags) - 1] = 0;
	  job |= str2jobflags(pool, flags);
	}
    }
  if (npieces < 4)
    {
      pool_debug(pool, SOLV_ERROR, "selstr2job: no selection flags\n");
      return -1;
    }
  selflags = str2selflags(pool, pieces[3]);
  queue_init(&sel);
  r = selection_make(pool, &sel, pieces[2], selflags);
  for (i = 0; i < sel.count; i += 2)
    queue_push2(jobqueue, job | sel.elements[i], sel.elements[i + 1]);
  queue_free(&sel);
  return r;
}

static void
writedeps(Repo *repo, FILE *fp, const char *tag, Id key, Solvable *s, Offset off)
{
  Pool *pool = repo->pool;
  Id id, *dp;
  int tagwritten = 0;
  const char *idstr;

  if (!off)
    return;
  dp = repo->idarraydata + off;
  while ((id = *dp++) != 0)
    {
      if (key == SOLVABLE_REQUIRES && id == SOLVABLE_PREREQMARKER)
	{
	  if (tagwritten)
	    fprintf(fp, "-%s\n", tag);
	  tagwritten = 0;
	  tag = "Prq:";
	  continue;
	}
      if (key == SOLVABLE_PROVIDES && id == SOLVABLE_FILEMARKER)
	continue;
      idstr = testcase_dep2str(pool, id);
      if (!tagwritten)
	{
	  fprintf(fp, "+%s\n", tag);
	  tagwritten = 1;
	}
      fprintf(fp, "%s\n", idstr);
    }
  if (tagwritten)
    fprintf(fp, "-%s\n", tag);
}

static void
writefilelist(Repo *repo, FILE *fp, const char *tag, Solvable *s)
{
  Pool *pool = repo->pool;
  int tagwritten = 0;
  Dataiterator di;

  dataiterator_init(&di, pool, repo, s - pool->solvables, SOLVABLE_FILELIST, 0, 0);
  while (dataiterator_step(&di))
    {
      const char *s = repodata_dir2str(di.data, di.kv.id, di.kv.str);
      if (!tagwritten)
	{
	  fprintf(fp, "+%s\n", tag);
	  tagwritten = 1;
	}
      fprintf(fp, "%s\n", s);
    }
  if (tagwritten)
    fprintf(fp, "-%s\n", tag);
  dataiterator_free(&di);
}

int
testcase_write_testtags(Repo *repo, FILE *fp)
{
  Pool *pool = repo->pool;
  Solvable *s;
  Id p;
  const char *name;
  const char *evr;
  const char *arch;
  const char *release;
  const char *tmp;
  unsigned int ti;

  fprintf(fp, "=Ver: 3.0\n");
  FOR_REPO_SOLVABLES(repo, p, s)
    {
      name = pool_id2str(pool, s->name);
      evr = pool_id2str(pool, s->evr);
      arch = pool_id2str(pool, s->arch);
      release = strrchr(evr, '-');
      if (!release)
	release = evr + strlen(evr);
      fprintf(fp, "=Pkg: %s %.*s %s %s\n", name, (int)(release - evr), evr, *release && release[1] ? release + 1 : "-", arch);
      tmp = solvable_lookup_str(s, SOLVABLE_SUMMARY);
      if (tmp)
        fprintf(fp, "=Sum: %s\n", tmp);
      writedeps(repo, fp, "Req:", SOLVABLE_REQUIRES, s, s->requires);
      writedeps(repo, fp, "Prv:", SOLVABLE_PROVIDES, s, s->provides);
      writedeps(repo, fp, "Obs:", SOLVABLE_OBSOLETES, s, s->obsoletes);
      writedeps(repo, fp, "Con:", SOLVABLE_CONFLICTS, s, s->conflicts);
      writedeps(repo, fp, "Rec:", SOLVABLE_RECOMMENDS, s, s->recommends);
      writedeps(repo, fp, "Sup:", SOLVABLE_SUPPLEMENTS, s, s->supplements);
      writedeps(repo, fp, "Sug:", SOLVABLE_SUGGESTS, s, s->suggests);
      writedeps(repo, fp, "Enh:", SOLVABLE_ENHANCES, s, s->enhances);
      if (s->vendor)
	fprintf(fp, "=Vnd: %s\n", pool_id2str(pool, s->vendor));
      ti = solvable_lookup_num(s, SOLVABLE_BUILDTIME, 0);
      if (ti)
	fprintf(fp, "=Tim: %u\n", ti);
      writefilelist(repo, fp, "Fls:", s);
    }
  return 0;
}

static inline Offset
adddep(Repo *repo, Offset olddeps, char *str, Id marker)
{
  Id id = *str == '/' ? pool_str2id(repo->pool, str, 1) : testcase_str2dep(repo->pool, str);
  return repo_addid_dep(repo, olddeps, id, marker);
}

static void
finish_v2_solvable(Pool *pool, Repodata *data, Solvable *s, char *filelist, int nfilelist)
{
  if (nfilelist)
    {
      int l;
      Id did;
      for (l = 0; l < nfilelist; l += strlen(filelist + l) + 1)
	{
	  char *p = strrchr(filelist + l, '/');
	  if (!p)
	    continue;
	  *p++ = 0;
	  did = repodata_str2dir(data, filelist + l, 1);
	  p[-1] = '/';
	  if (!did)
	    did = repodata_str2dir(data, "/", 1);
	  repodata_add_dirstr(data, s - pool->solvables, SOLVABLE_FILELIST, did, p);
	}
    }
  s->supplements = repo_fix_supplements(s->repo, s->provides, s->supplements, 0);
  s->conflicts = repo_fix_conflicts(s->repo, s->conflicts);
}

/* stripped down version of susetags parser used for testcases */
int
testcase_add_testtags(Repo *repo, FILE *fp, int flags)
{
  Pool *pool = repo->pool;
  char *line, *linep;
  int aline;
  int tag;
  Repodata *data;
  Solvable *s;
  char *sp[5];
  unsigned int t;
  int intag;
  char *filelist = 0;
  int afilelist = 0;
  int nfilelist = 0;
  int tagsversion = 0;
  int addselfprovides = 1;	/* for compat reasons */

  data = repo_add_repodata(repo, flags);
  s = 0;
  intag = 0;

  aline = 1024;
  line = solv_malloc(aline);
  linep = line;
  for (;;)
    {
      if (linep - line + 16 > aline)
	{
	  aline = linep - line;
	  line = solv_realloc(line, aline + 512);
	  linep = line + aline;
	  aline += 512;
	}
      if (!fgets(linep, aline - (linep - line), fp))
	break;
      linep += strlen(linep);
      if (linep == line || linep[-1] != '\n')
	continue;
      linep[-1] = 0;
      linep = line + intag;
      if (intag)
	{
	  if (line[intag] == '-' && !strncmp(line + 1, line + intag + 1, intag - 2))
	    {
	      intag = 0;
	      linep = line;
	      continue;
	    }
	}
      else if (line[0] == '+' && line[1] && line[1] != ':')
	{
	  char *tagend = strchr(line, ':');
	  if (!tagend)
	    continue;
	  line[0] = '=';
	  tagend[1] = ' ';
	  intag = tagend + 2 - line;
	  linep = line + intag;
	  continue;
	}
      if (*line != '=' || !line[1] || !line[2] || !line[3] || line[4] != ':')
	continue;
      tag = line[1] << 16 | line[2] << 8 | line[3];
      switch(tag)
        {
	case 'V' << 16 | 'e' << 8 | 'r':
	  tagsversion = atoi(line + 6);
	  addselfprovides = tagsversion < 3 || strstr(line + 6, "addselfprovides") != 0;
	  break;
	case 'P' << 16 | 'k' << 8 | 'g':
	  if (s)
	    {
	      if (tagsversion == 2)
		finish_v2_solvable(pool, data, s, filelist, nfilelist);
	      if (addselfprovides && s->name && s->arch != ARCH_SRC && s->arch != ARCH_NOSRC)
		s->provides = repo_addid_dep(s->repo, s->provides, pool_rel2id(pool, s->name, s->evr, REL_EQ, 1), 0);
	    }
	  nfilelist = 0;
	  if (split(line + 5, sp, 5) != 4)
	    break;
	  s = pool_id2solvable(pool, repo_add_solvable(repo));
	  s->name = pool_str2id(pool, sp[0], 1);
	  /* join back version and release */
	  if (sp[2] && !(sp[2][0] == '-' && !sp[2][1]))
	    sp[2][-1] = '-';
	  s->evr = makeevr(pool, sp[1]);
	  s->arch = pool_str2id(pool, sp[3], 1);
	  break;
	case 'S' << 16 | 'u' << 8 | 'm':
	  repodata_set_str(data, s - pool->solvables, SOLVABLE_SUMMARY, line + 6);
	  break;
	case 'V' << 16 | 'n' << 8 | 'd':
	  s->vendor = pool_str2id(pool, line + 6, 1);
	  break;
	case 'T' << 16 | 'i' << 8 | 'm':
	  t = atoi(line + 6);
	  if (t)
	    repodata_set_num(data, s - pool->solvables, SOLVABLE_BUILDTIME, t);
	  break;
	case 'R' << 16 | 'e' << 8 | 'q':
	  s->requires = adddep(repo, s->requires, line + 6, -SOLVABLE_PREREQMARKER);
	  break;
	case 'P' << 16 | 'r' << 8 | 'q':
	  s->requires = adddep(repo, s->requires, line + 6, SOLVABLE_PREREQMARKER);
	  break;
	case 'P' << 16 | 'r' << 8 | 'v':
	  /* version 2 had the file list at the end of the provides */
	  if (tagsversion == 2)
	    {
	      if (line[6] == '/')
		{
		  int l = strlen(line + 6) + 1;
		  if (nfilelist + l > afilelist)
		    {
		      afilelist = nfilelist + l + 512;
		      filelist = solv_realloc(filelist, afilelist);
		    }
		  memcpy(filelist + nfilelist, line + 6, l);
		  nfilelist += l;
		  break;
		}
	      if (nfilelist)
		{
		  int l;
		  for (l = 0; l < nfilelist; l += strlen(filelist + l) + 1)
		    s->provides = repo_addid_dep(repo, s->provides, pool_str2id(pool, filelist + l, 1), 0);
		  nfilelist = 0;
		}
	    }
	  s->provides = adddep(repo, s->provides, line + 6, 0);
	  break;
	case 'F' << 16 | 'l' << 8 | 's':
	  {
	    char *p = strrchr(line + 6, '/');
	    Id did;
	    if (!p)
	      break;
	    *p++ = 0;
	    did = repodata_str2dir(data, line + 6, 1);
	    if (!did)
	      did = repodata_str2dir(data, "/", 1);
	    repodata_add_dirstr(data, s - pool->solvables, SOLVABLE_FILELIST, did, p);
	    break;
	  }
	case 'O' << 16 | 'b' << 8 | 's':
	  s->obsoletes = adddep(repo, s->obsoletes, line + 6, 0);
	  break;
	case 'C' << 16 | 'o' << 8 | 'n':
	  s->conflicts = adddep(repo, s->conflicts, line + 6, 0);
	  break;
	case 'R' << 16 | 'e' << 8 | 'c':
	  s->recommends = adddep(repo, s->recommends, line + 6, 0);
	  break;
	case 'S' << 16 | 'u' << 8 | 'p':
	  s->supplements = adddep(repo, s->supplements, line + 6, 0);
	  break;
	case 'S' << 16 | 'u' << 8 | 'g':
	  s->suggests = adddep(repo, s->suggests, line + 6, 0);
	  break;
	case 'E' << 16 | 'n' << 8 | 'h':
	  s->enhances = adddep(repo, s->enhances, line + 6, 0);
	  break;
        default:
	  break;
        }
    }
  if (s)
    {
      if (tagsversion == 2)
	finish_v2_solvable(pool, data, s, filelist, nfilelist);
      if (addselfprovides && s->name && s->arch != ARCH_SRC && s->arch != ARCH_NOSRC)
        s->provides = repo_addid_dep(s->repo, s->provides, pool_rel2id(pool, s->name, s->evr, REL_EQ, 1), 0);
    }
  solv_free(line);
  solv_free(filelist);
  repodata_free_dircache(data);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return 0;
}

const char *
testcase_getpoolflags(Pool *pool)
{
  const char *str = 0;
  int i, v;
  for (i = 0; poolflags2str[i].str; i++)
    {
      v = pool_get_flag(pool, poolflags2str[i].flag);
      if (v == poolflags2str[i].def)
	continue;
      str = pool_tmpappend(pool, str, v ? " " : " !", poolflags2str[i].str);
    }
  return str ? str + 1 : "";
}

int
testcase_setpoolflags(Pool *pool, const char *str)
{
  const char *p = str, *s;
  int i, v;
  for (;;)
    {
      while (*p == ' ' || *p == '\t' || *p == ',')
	p++;
      v = 1;
      if (*p == '!')
	{
	  p++;
	  v = 0;
	}
      if (!*p)
	break;
      s = p;
      while (*p && *p != ' ' && *p != '\t' && *p != ',')
	p++;
      for (i = 0; poolflags2str[i].str; i++)
	if (!strncmp(poolflags2str[i].str, s, p - s) && poolflags2str[i].str[p - s] == 0)
	  break;
      if (!poolflags2str[i].str)
	{
	  pool_debug(pool, SOLV_ERROR, "setpoolflags: unknown flag '%.*s'\n", (int)(p - s), s);
	  return 0;
	}
      pool_set_flag(pool, poolflags2str[i].flag, v);
    }
  return 1;
}

void
testcase_resetpoolflags(Pool *pool)
{
  int i;
  for (i = 0; poolflags2str[i].str; i++)
    pool_set_flag(pool, poolflags2str[i].flag, poolflags2str[i].def);
}

const char *
testcase_getsolverflags(Solver *solv)
{
  Pool *pool = solv->pool;
  const char *str = 0;
  int i, v;
  for (i = 0; solverflags2str[i].str; i++)
    {
      v = solver_get_flag(solv, solverflags2str[i].flag);
      if (v == solverflags2str[i].def)
	continue;
      str = pool_tmpappend(pool, str, v ? " " : " !", solverflags2str[i].str);
    }
  return str ? str + 1 : "";
}

int
testcase_setsolverflags(Solver *solv, const char *str)
{
  const char *p = str, *s;
  int i, v;
  for (;;)
    {
      while (*p == ' ' || *p == '\t' || *p == ',')
	p++;
      v = 1;
      if (*p == '!')
	{
	  p++;
	  v = 0;
	}
      if (!*p)
	break;
      s = p;
      while (*p && *p != ' ' && *p != '\t' && *p != ',')
	p++;
      for (i = 0; solverflags2str[i].str; i++)
	if (!strncmp(solverflags2str[i].str, s, p - s) && solverflags2str[i].str[p - s] == 0)
	  break;
      if (!solverflags2str[i].str)
	{
	  pool_debug(solv->pool, SOLV_ERROR, "setsolverflags: unknown flag '%.*s'\n", (int)(p - s), s);
	  return 0;
	}
      solver_set_flag(solv, solverflags2str[i].flag, v);
    }
  return 1;
}

void
testcase_resetsolverflags(Solver *solv)
{
  int i;
  for (i = 0; solverflags2str[i].str; i++)
    solver_set_flag(solv, solverflags2str[i].flag, solverflags2str[i].def);
}

static const char *
testcase_ruleid(Solver *solv, Id rid)
{
  Strqueue sq;
  Queue q;
  int i;
  Chksum *chk;
  const unsigned char *md5;
  int md5l;
  const char *s;

  queue_init(&q);
  strqueue_init(&sq);
  solver_ruleliterals(solv, rid, &q);
  for (i = 0; i < q.count; i++)
    {
      Id p = q.elements[i];
      s = testcase_solvid2str(solv->pool, p > 0 ? p : -p);
      if (p < 0)
	s = pool_tmpjoin(solv->pool, "!", s, 0);
      strqueue_push(&sq, s);
    }
  queue_free(&q);
  strqueue_sort_u(&sq);
  chk = solv_chksum_create(REPOKEY_TYPE_MD5);
  for (i = 0; i < sq.nstr; i++)
    solv_chksum_add(chk, sq.str[i], strlen(sq.str[i]) + 1);
  md5 = solv_chksum_get(chk, &md5l);
  s = pool_bin2hex(solv->pool, md5, md5l);
  chk = solv_chksum_free(chk, 0);
  strqueue_free(&sq);
  return s;
}

static const char *
testcase_problemid(Solver *solv, Id problem)
{
  Strqueue sq;
  Queue q;
  Chksum *chk;
  const unsigned char *md5;
  int i, md5l;
  const char *s;

  /* we build a hash of all rules that define the problem */
  queue_init(&q);
  strqueue_init(&sq);
  solver_findallproblemrules(solv, problem, &q);
  for (i = 0; i < q.count; i++)
    strqueue_push(&sq, testcase_ruleid(solv, q.elements[i]));
  queue_free(&q);
  strqueue_sort_u(&sq);
  chk = solv_chksum_create(REPOKEY_TYPE_MD5);
  for (i = 0; i < sq.nstr; i++)
    solv_chksum_add(chk, sq.str[i], strlen(sq.str[i]) + 1);
  md5 = solv_chksum_get(chk, &md5l);
  s = pool_bin2hex(solv->pool, md5, 4);
  chk = solv_chksum_free(chk, 0);
  strqueue_free(&sq);
  return s;
}

static const char *
testcase_solutionid(Solver *solv, Id problem, Id solution)
{
  Id intid;
  Chksum *chk;
  const unsigned char *md5;
  int md5l;
  const char *s;

  intid = solver_solutionelement_internalid(solv, problem, solution);
  /* internal stuff! handle with care! */
  if (intid < 0)
    {
      /* it's a job */
      s = testcase_job2str(solv->pool, solv->job.elements[-intid - 1], solv->job.elements[-intid]);
    }
  else
    {
      /* it's a rule */
      s = testcase_ruleid(solv, intid);
    }
  chk = solv_chksum_create(REPOKEY_TYPE_MD5);
  solv_chksum_add(chk, s, strlen(s) + 1);
  md5 = solv_chksum_get(chk, &md5l);
  s = pool_bin2hex(solv->pool, md5, 4);
  chk = solv_chksum_free(chk, 0);
  return s;
}

static const char *
testcase_alternativeid(Solver *solv, int type, Id id, Id from)
{
  const char *s;
  Pool *pool = solv->pool;
  Chksum *chk;
  const unsigned char *md5;
  int md5l;
  chk = solv_chksum_create(REPOKEY_TYPE_MD5);
  if (type == SOLVER_ALTERNATIVE_TYPE_RECOMMENDS)
    {
      s = testcase_solvid2str(pool, from);
      solv_chksum_add(chk, s, strlen(s) + 1);
      s = testcase_dep2str(pool, id);
      solv_chksum_add(chk, s, strlen(s) + 1);
    }
  else if (type == SOLVER_ALTERNATIVE_TYPE_RULE)
    {
      s = testcase_ruleid(solv, id);
      solv_chksum_add(chk, s, strlen(s) + 1);
    }
  md5 = solv_chksum_get(chk, &md5l);
  s = pool_bin2hex(pool, md5, 4);
  chk = solv_chksum_free(chk, 0);
  return s;
}

static struct class2str {
  Id class;
  const char *str;
} class2str[] = {
  { SOLVER_TRANSACTION_ERASE,          "erase" },
  { SOLVER_TRANSACTION_INSTALL,        "install" },
  { SOLVER_TRANSACTION_REINSTALLED,    "reinstall" },
  { SOLVER_TRANSACTION_DOWNGRADED,     "downgrade" },
  { SOLVER_TRANSACTION_CHANGED,        "change" },
  { SOLVER_TRANSACTION_UPGRADED,       "upgrade" },
  { SOLVER_TRANSACTION_OBSOLETED,      "obsolete" },
  { SOLVER_TRANSACTION_MULTIINSTALL,   "multiinstall" },
  { SOLVER_TRANSACTION_MULTIREINSTALL, "multireinstall" },
  { 0, 0 }
};

static int
dump_genid(Pool *pool, Strqueue *sq, Id id, int cnt)
{
  struct oplist *op;
  char cntbuf[20];
  const char *s;

  if (ISRELDEP(id))
    {
      Reldep *rd = GETRELDEP(pool, id);
      for (op = oplist; op->flags; op++)
	if (rd->flags == op->flags)
	  break;
      cnt = dump_genid(pool, sq, rd->name, cnt);
      cnt = dump_genid(pool, sq, rd->evr, cnt);
      sprintf(cntbuf, "genid %2d: genid ", cnt++);
      s = pool_tmpjoin(pool, cntbuf, "op ", op->flags ? op->opname : "unknown");
    }
  else
    {
      sprintf(cntbuf, "genid %2d: genid ", cnt++);
      s = pool_tmpjoin(pool, cntbuf, id ? "lit " : "null", id ? pool_id2str(pool, id) : 0);
    }
  strqueue_push(sq, s);
  return cnt;
}

char *
testcase_solverresult(Solver *solv, int resultflags)
{
  Pool *pool = solv->pool;
  int i, j;
  Id p, op;
  const char *s;
  char *result;
  Strqueue sq;

  strqueue_init(&sq);
  if ((resultflags & TESTCASE_RESULT_TRANSACTION) != 0)
    {
      Transaction *trans = solver_create_transaction(solv);
      Queue q;

      queue_init(&q);
      for (i = 0; class2str[i].str; i++)
	{
	  queue_empty(&q);
	  transaction_classify_pkgs(trans, SOLVER_TRANSACTION_KEEP_PSEUDO, class2str[i].class, 0, 0, &q);
	  for (j = 0; j < q.count; j++)
	    {
	      p = q.elements[j];
	      op = 0;
	      if (pool->installed && pool->solvables[p].repo == pool->installed)
		op = transaction_obs_pkg(trans, p);
	      s = pool_tmpjoin(pool, class2str[i].str, " ", testcase_solvid2str(pool, p));
	      if (op)
		s = pool_tmpjoin(pool, s, " ", testcase_solvid2str(pool, op));
	      strqueue_push(&sq, s);
	    }
	}
      queue_free(&q);
      transaction_free(trans);
    }
  if ((resultflags & TESTCASE_RESULT_PROBLEMS) != 0)
    {
      char *probprefix, *solprefix;
      int problem, solution, element;
      int pcnt, scnt;

      pcnt = solver_problem_count(solv);
      for (problem = 1; problem <= pcnt; problem++)
	{
	  Id rid, from, to, dep;
	  SolverRuleinfo rinfo;
	  rid = solver_findproblemrule(solv, problem);
	  s = testcase_problemid(solv, problem);
	  probprefix = solv_dupjoin("problem ", s, 0);
	  rinfo = solver_ruleinfo(solv, rid, &from, &to, &dep);
	  s = pool_tmpjoin(pool, probprefix, " info ", solver_problemruleinfo2str(solv, rinfo, from, to, dep));
	  strqueue_push(&sq, s);
	  scnt = solver_solution_count(solv, problem);
	  for (solution = 1; solution <= scnt; solution++)
	    {
	      s = testcase_solutionid(solv, problem, solution);
	      solprefix = solv_dupjoin(probprefix, " solution ", s);
	      element = 0;
	      while ((element = solver_next_solutionelement(solv, problem, solution, element, &p, &op)) != 0)
		{
		  if (p == SOLVER_SOLUTION_JOB)
		    s = pool_tmpjoin(pool, solprefix, " deljob ", testcase_job2str(pool, solv->job.elements[op - 1], solv->job.elements[op]));
		  else if (p > 0 && op == 0)
		    s = pool_tmpjoin(pool, solprefix, " erase ", testcase_solvid2str(pool, p));
		  else if (p > 0 && op > 0)
		    {
		      s = pool_tmpjoin(pool, solprefix, " replace ", testcase_solvid2str(pool, p));
		      s = pool_tmpappend(pool, s, " ", testcase_solvid2str(pool, op));
		    }
		  else if (p < 0 && op > 0)
		    s = pool_tmpjoin(pool, solprefix, " allow ", testcase_solvid2str(pool, op));
		  else
		    s = pool_tmpjoin(pool, solprefix, " unknown", 0);
		  strqueue_push(&sq, s);
		}
	      solv_free(solprefix);
	    }
	  solv_free(probprefix);
	}
    }

  if ((resultflags & TESTCASE_RESULT_ORPHANED) != 0)
    {
      Queue q;

      queue_init(&q);
      solver_get_orphaned(solv, &q);
      for (i = 0; i < q.count; i++)
	{
	  s = pool_tmpjoin(pool, "orphaned ", testcase_solvid2str(pool, q.elements[i]), 0);
	  strqueue_push(&sq, s);
	}
      queue_free(&q);
    }

  if ((resultflags & TESTCASE_RESULT_RECOMMENDED) != 0)
    {
      Queue qr, qs;

      queue_init(&qr);
      queue_init(&qs);
      solver_get_recommendations(solv, &qr, &qs, 0);
      for (i = 0; i < qr.count; i++)
	{
	  s = pool_tmpjoin(pool, "recommended ", testcase_solvid2str(pool, qr.elements[i]), 0);
	  strqueue_push(&sq, s);
	}
      for (i = 0; i < qs.count; i++)
	{
	  s = pool_tmpjoin(pool, "suggested ", testcase_solvid2str(pool, qs.elements[i]), 0);
	  strqueue_push(&sq, s);
	}
      queue_free(&qr);
      queue_free(&qs);
    }

  if ((resultflags & TESTCASE_RESULT_UNNEEDED) != 0)
    {
      Queue q, qf;

      queue_init(&q);
      queue_init(&qf);
      solver_get_unneeded(solv, &q, 0);
      solver_get_unneeded(solv, &qf, 1);
      for (i = j = 0; i < q.count; i++)
	{
	  /* we rely on qf containing a subset of q in the same order */
	  if (j < qf.count && q.elements[i] == qf.elements[j])
	    {
	      s = pool_tmpjoin(pool, "unneeded_filtered ", testcase_solvid2str(pool, q.elements[i]), 0);
	      j++;
	    }
	  else
	    s = pool_tmpjoin(pool, "unneeded ", testcase_solvid2str(pool, q.elements[i]), 0);
	  strqueue_push(&sq, s);
	}
      queue_free(&q);
      queue_free(&qf);
    }
  if ((resultflags & TESTCASE_RESULT_ALTERNATIVES) != 0)
    {
      char *altprefix;
      Queue q, rq;
      int cnt;
      Id alternative;
      queue_init(&q);
      queue_init(&rq);
      cnt = solver_alternatives_count(solv);
      for (alternative = 1; alternative <= cnt; alternative++)
	{
	  Id id, from, chosen;
	  char num[20];
	  int type = solver_get_alternative(solv, alternative, &id, &from, &chosen, &q, 0);
	  altprefix = solv_dupjoin("alternative ", testcase_alternativeid(solv, type, id, from), " ");
	  strcpy(num, " 0 ");
	  if (type == SOLVER_ALTERNATIVE_TYPE_RECOMMENDS)
	    {
	      char *s = pool_tmpjoin(pool, altprefix, num, testcase_solvid2str(pool, from));
	      s = pool_tmpappend(pool, s, " recommends ", testcase_dep2str(pool, id));
	      strqueue_push(&sq, s);
	    }
	  else if (type == SOLVER_ALTERNATIVE_TYPE_RULE)
	    {
	      /* map choice rules back to pkg rules */
	      if (solver_ruleclass(solv, id) == SOLVER_RULE_CHOICE)
		id = solver_rule2pkgrule(solv, id);
	      solver_allruleinfos(solv, id, &rq);
	      for (i = 0; i < rq.count; i += 4)
		{
		  int rtype = rq.elements[i];
		  if ((rtype & SOLVER_RULE_TYPEMASK) == SOLVER_RULE_JOB)
		    {
		      const char *js = testcase_job2str(pool, rq.elements[i + 2], rq.elements[i + 3]);
		      char *s = pool_tmpjoin(pool, altprefix, num, " job ");
		      s = pool_tmpappend(pool, s, js, 0);
		      strqueue_push(&sq, s);
		    }
		  else if (rtype == SOLVER_RULE_PKG_REQUIRES)
		    {
		      char *s = pool_tmpjoin(pool, altprefix, num, testcase_solvid2str(pool, rq.elements[i + 1]));
		      s = pool_tmpappend(pool, s, " requires ", testcase_dep2str(pool, rq.elements[i + 3]));
		      strqueue_push(&sq, s);
		    }
		}
	    }
	  for (i = 0; i < q.count; i++)
	    {
	      Id p = q.elements[i];
	      if (i >= 9)
	        num[0] = '0' + (i + 1) / 10;
	      num[1] = '0' + (i + 1) % 10;
	      if (-p == chosen)
		s = pool_tmpjoin(pool, altprefix, num, "+ ");
	      else if (p < 0)
	        s = pool_tmpjoin(pool, altprefix, num, "- ");
	      else if (p >= 0)
	        s = pool_tmpjoin(pool, altprefix, num, "  ");
	      s = pool_tmpappend(pool, s,  testcase_solvid2str(pool, p < 0 ? -p : p), 0);
	      strqueue_push(&sq, s);
	    }
	  solv_free(altprefix);
	}
      queue_free(&q);
      queue_free(&rq);
    }
  if ((resultflags & TESTCASE_RESULT_RULES) != 0)
    {
      /* dump all rules */
      Id rid;
      SolverRuleinfo rclass;
      Queue q;
      int i;

      queue_init(&q);
      for (rid = 1; (rclass = solver_ruleclass(solv, rid)) != SOLVER_RULE_UNKNOWN; rid++)
	{
	  char *prefix;
	  switch (rclass)
	    {
	    case SOLVER_RULE_PKG:
	      prefix = "pkg ";
	      break;
	    case SOLVER_RULE_UPDATE:
	      prefix = "update ";
	      break;
	    case SOLVER_RULE_FEATURE:
	      prefix = "feature ";
	      break;
	    case SOLVER_RULE_JOB:
	      prefix = "job ";
	      break;
	    case SOLVER_RULE_DISTUPGRADE:
	      prefix = "distupgrade ";
	      break;
	    case SOLVER_RULE_INFARCH:
	      prefix = "infarch ";
	      break;
	    case SOLVER_RULE_CHOICE:
	      prefix = "choice ";
	      break;
	    case SOLVER_RULE_LEARNT:
	      prefix = "learnt ";
	      break;
	    case SOLVER_RULE_BEST:
	      prefix = "best ";
	      break;
	    case SOLVER_RULE_YUMOBS:
	      prefix = "yumobs ";
	      break;
	    default:
	      prefix = "unknown ";
	      break;
	    }
	  prefix = solv_dupjoin("rule ", prefix, testcase_ruleid(solv, rid));
	  solver_ruleliterals(solv, rid, &q);
	  if (rclass == SOLVER_RULE_FEATURE && q.count == 1 && q.elements[0] == -SYSTEMSOLVABLE)
	    continue;
	  for (i = 0; i < q.count; i++)
	    {
	      Id p = q.elements[i];
	      const char *s;
	      if (p < 0)
		s = pool_tmpjoin(pool, prefix, " -", testcase_solvid2str(pool, -p));
	      else
		s = pool_tmpjoin(pool, prefix, "  ", testcase_solvid2str(pool, p));
	      strqueue_push(&sq, s);
	    }
	  solv_free(prefix);
	}
      queue_free(&q);
    }
  if ((resultflags & TESTCASE_RESULT_GENID) != 0)
    {
      for (i = 0 ; i < solv->job.count; i += 2)
	{
	  Id id, id2;
	  if (solv->job.elements[i] != (SOLVER_NOOP | SOLVER_SOLVABLE_PROVIDES))
	    continue;
	  id = solv->job.elements[i + 1];
	  s = testcase_dep2str(pool, id);
	  strqueue_push(&sq, pool_tmpjoin(pool, "genid dep ", s, 0));
	  if ((id2 = testcase_str2dep(pool, s)) != id)
	    {
	      s = pool_tmpjoin(pool, "genid roundtrip error: ", testcase_dep2str(pool, id2), 0);
	      strqueue_push(&sq, s);
	    }
	  dump_genid(pool, &sq, id, 1);
	}
    }
  strqueue_sort(&sq);
  result = strqueue_join(&sq);
  strqueue_free(&sq);
  return result;
}


int
testcase_write(Solver *solv, char *dir, int resultflags, const char *testcasename, const char *resultname)
{
  Pool *pool = solv->pool;
  Repo *repo;
  int i;
  Id arch, repoid;
  Id lowscore;
  FILE *fp;
  Strqueue sq;
  char *cmd, *out;
  const char *s;

  if (!testcasename)
    testcasename = "testcase.t";
  if (!resultname)
    resultname = "solver.result";

  if (mkdir(dir, 0777) && errno != EEXIST)
    {
      pool_debug(solv->pool, SOLV_ERROR, "testcase_write: could not create directory '%s'\n", dir);
      return 0;
    }
  strqueue_init(&sq);
  FOR_REPOS(repoid, repo)
    {
      const char *name = testcase_repoid2str(pool, repoid);
      char priobuf[50];
      if (repo->subpriority)
	sprintf(priobuf, "%d.%d", repo->priority, repo->subpriority);
      else
	sprintf(priobuf, "%d", repo->priority);
      out = pool_tmpjoin(pool, name, ".repo", ".gz");
      cmd = pool_tmpjoin(pool, "repo ", name, " ");
      cmd = pool_tmpappend(pool, cmd, priobuf, " ");
      cmd = pool_tmpappend(pool, cmd, "testtags ", out);
      strqueue_push(&sq, cmd);
      out = pool_tmpjoin(pool, dir, "/", out);
      if (!(fp = solv_xfopen(out, "w")))
	{
	  pool_debug(solv->pool, SOLV_ERROR, "testcase_write: could not open '%s' for writing\n", out);
	  strqueue_free(&sq);
	  return 0;
	}
      testcase_write_testtags(repo, fp);
      if (fclose(fp))
	{
	  pool_debug(solv->pool, SOLV_ERROR, "testcase_write: write error\n");
	  strqueue_free(&sq);
	  return 0;
	}
    }
  /* hmm, this is not optimal... we currently search for the lowest score */
  lowscore = 0;
  arch = pool->solvables[SYSTEMSOLVABLE].arch;
  for (i = 0; i < pool->lastarch; i++)
    {
      if (pool->id2arch[i] == 1 && !lowscore)
	arch = i;
      if (pool->id2arch[i] > 0x10000 && (!lowscore || pool->id2arch[i] < lowscore))
	{
	  arch = i;
	  lowscore = pool->id2arch[i];
	}
    }
  cmd = pool_tmpjoin(pool, "system ", pool->lastarch ? pool_id2str(pool, arch) : "unset", 0);
  for (i = 0; disttype2str[i].str != 0; i++)
    if (pool->disttype == disttype2str[i].type)
      break;
  pool_tmpappend(pool, cmd, " ", disttype2str[i].str ? disttype2str[i].str : "unknown");
  if (pool->installed)
    cmd = pool_tmpappend(pool, cmd, " ", testcase_repoid2str(pool, pool->installed->repoid));
  strqueue_push(&sq, cmd);
  s = testcase_getpoolflags(solv->pool);
  if (*s)
    {
      cmd = pool_tmpjoin(pool, "poolflags ", s, 0);
      strqueue_push(&sq, cmd);
    }

  if (pool->vendorclasses)
    {
      cmd = 0;
      for (i = 0; pool->vendorclasses[i]; i++)
	{
	  cmd = pool_tmpappend(pool, cmd ? cmd : "vendorclass", " ", pool->vendorclasses[i]);
	  if (!pool->vendorclasses[i + 1])
	    {
	      strqueue_push(&sq, cmd);
	      cmd = 0;
	      i++;
	    }
	}
    }

  /* dump disabled packages (must come before the namespace/job lines) */
  if (pool->considered)
    {
      Id p;
      FOR_POOL_SOLVABLES(p)
	if (!MAPTST(pool->considered, p))
	  {
	    cmd = pool_tmpjoin(pool, "disable pkg ", testcase_solvid2str(pool, p), 0);
	    strqueue_push(&sq, cmd);
	  }
    }

  s = testcase_getsolverflags(solv);
  if (*s)
    {
      cmd = pool_tmpjoin(pool, "solverflags ", s, 0);
      strqueue_push(&sq, cmd);
    }

  /* now dump all the ns callback values we know */
  if (pool->nscallback)
    {
      Id rid;
      int d;
      for (rid = 1; rid < pool->nrels; rid++)
	{
	  Reldep *rd = pool->rels + rid;
	  if (rd->flags != REL_NAMESPACE || rd->name == NAMESPACE_OTHERPROVIDERS)
	    continue;
	  /* evaluate all namespace ids, skip empty results */
	  d = pool_whatprovides(pool, MAKERELDEP(rid));
	  if (!d || !pool->whatprovidesdata[d])
	    continue;
	  cmd = pool_tmpjoin(pool, "namespace ", pool_id2str(pool, rd->name), "(");
	  cmd = pool_tmpappend(pool, cmd, pool_id2str(pool, rd->evr), ")");
	  for (;  pool->whatprovidesdata[d]; d++)
	    cmd = pool_tmpappend(pool, cmd, " ", testcase_solvid2str(pool, pool->whatprovidesdata[d]));
	  strqueue_push(&sq, cmd);
	}
    }

  for (i = 0; i < solv->job.count; i += 2)
    {
      cmd = (char *)testcase_job2str(pool, solv->job.elements[i], solv->job.elements[i + 1]);
      cmd = pool_tmpjoin(pool, "job ", cmd, 0);
      strqueue_push(&sq, cmd);
    }

  if (resultflags)
    {
      char *result;
      cmd = 0;
      for (i = 0; resultflags2str[i].str; i++)
	if ((resultflags & resultflags2str[i].flag) != 0)
	  cmd = pool_tmpappend(pool, cmd, cmd ? "," : 0, resultflags2str[i].str);
      cmd = pool_tmpjoin(pool, "result ", cmd ? cmd : "?", 0);
      cmd = pool_tmpappend(pool, cmd, " ", resultname);
      strqueue_push(&sq, cmd);
      result = testcase_solverresult(solv, resultflags);
      if (!strcmp(resultname, "<inline>"))
	{
	  int i;
	  Strqueue rsq;
	  strqueue_init(&rsq);
	  strqueue_split(&rsq, result);
	  for (i = 0; i < rsq.nstr; i++)
	    {
	      cmd = pool_tmpjoin(pool, "#>", rsq.str[i], 0);
	      strqueue_push(&sq, cmd);
	    }
	  strqueue_free(&rsq);
	}
      else
	{
	  out = pool_tmpjoin(pool, dir, "/", resultname);
	  if (!(fp = fopen(out, "w")))
	    {
	      pool_debug(solv->pool, SOLV_ERROR, "testcase_write: could not open '%s' for writing\n", out);
	      solv_free(result);
	      strqueue_free(&sq);
	      return 0;
	    }
	  if (result && *result && fwrite(result, strlen(result), 1, fp) != 1)
	    {
	      pool_debug(solv->pool, SOLV_ERROR, "testcase_write: write error\n");
	      solv_free(result);
	      strqueue_free(&sq);
	      fclose(fp);
	      return 0;
	    }
	  if (fclose(fp))
	    {
	      pool_debug(solv->pool, SOLV_ERROR, "testcase_write: write error\n");
	      strqueue_free(&sq);
	      return 0;
	    }
	}
      solv_free(result);
    }

  cmd = strqueue_join(&sq);
  out = pool_tmpjoin(pool, dir, "/", testcasename);
  if (!(fp = fopen(out, "w")))
    {
      pool_debug(solv->pool, SOLV_ERROR, "testcase_write: could not open '%s' for writing\n", out);
      strqueue_free(&sq);
      return 0;
    }
  if (*cmd && fwrite(cmd, strlen(cmd), 1, fp) != 1)
    {
      pool_debug(solv->pool, SOLV_ERROR, "testcase_write: write error\n");
      strqueue_free(&sq);
      fclose(fp);
      return 0;
    }
  if (fclose(fp))
    {
      pool_debug(solv->pool, SOLV_ERROR, "testcase_write: write error\n");
      strqueue_free(&sq);
      return 0;
    }
  solv_free(cmd);
  strqueue_free(&sq);
  return 1;
}

static char *
read_inline_file(FILE *fp, char **bufp, char **bufpp, int *buflp)
{
  char *result = solv_malloc(1024);
  char *rp = result;
  int resultl = 1024;

  for (;;)
    {
      size_t rl;
      if (rp - result + 256 >= resultl)
	{
	  resultl = rp - result;
	  result = solv_realloc(result, resultl + 1024);
	  rp = result + resultl;
	  resultl += 1024;
	}
      if (!fgets(rp, resultl - (rp - result), fp))
	*rp = 0;
      rl = strlen(rp);
      if (rl && (rp == result || rp[-1] == '\n'))
	{
	  if (rl > 1 && rp[0] == '#' && rp[1] == '>')
	    {
	      memmove(rp, rp + 2, rl - 2);
	      rl -= 2;
	    }
	  else
	    {
	      while (rl + 16 > *buflp)
		{
		  *bufp = solv_realloc(*bufp, *buflp + 512);
		  *buflp += 512;
		}
	      memmove(*bufp, rp, rl);
	      if ((*bufp)[rl - 1] == '\n')
		{
		  ungetc('\n', fp);
		  rl--;
		}
	      (*bufp)[rl] = 0;
	      (*bufpp) = *bufp + rl;
	      rl = 0;
	    }
	}
      if (rl <= 0)
	{
	  *rp = 0;
	  break;
	}
      rp += rl;
    }
  return result;
}

static char *
read_file(FILE *fp)
{
  char *result = solv_malloc(1024);
  char *rp = result;
  int resultl = 1024;

  for (;;)
    {
      size_t rl;
      if (rp - result + 256 >= resultl)
	{
	  resultl = rp - result;
	  result = solv_realloc(result, resultl + 1024);
	  rp = result + resultl;
	  resultl += 1024;
	}
      rl = fread(rp, 1, resultl - (rp - result), fp);
      if (rl <= 0)
	{
	  *rp = 0;
	  break;
	}
      rp += rl;
    }
  return result;
}

static int
str2resultflags(Pool *pool, char *s)	/* modifies the string! */
{
  int i, resultflags = 0;
  while (s)
    {
      char *se = strchr(s, ',');
      if (se)
	*se++ = 0;
      for (i = 0; resultflags2str[i].str; i++)
	if (!strcmp(s, resultflags2str[i].str))
	  {
	    resultflags |= resultflags2str[i].flag;
	    break;
	  }
      if (!resultflags2str[i].str)
	pool_debug(pool, SOLV_ERROR, "result: unknown flag '%s'\n", s);
      s = se;
    }
  return resultflags;
}

Solver *
testcase_read(Pool *pool, FILE *fp, char *testcase, Queue *job, char **resultp, int *resultflagsp)
{
  Solver *solv;
  char *buf, *bufp;
  int bufl;
  char *testcasedir, *s;
  int l;
  char **pieces = 0;
  int npieces = 0;
  int prepared = 0;
  int closefp = !fp;
  int poolflagsreset = 0;
  int missing_features = 0;
  Id *genid = 0;
  int ngenid = 0;

  if (!fp && !(fp = fopen(testcase, "r")))
    {
      pool_debug(pool, SOLV_ERROR, "testcase_read: could not open '%s'\n", testcase);
      return 0;
    }
  testcasedir = solv_strdup(testcase);
  if ((s = strrchr(testcasedir, '/')) != 0)
    s[1] = 0;
  else
    *testcasedir = 0;
  bufl = 1024;
  buf = solv_malloc(bufl);
  bufp = buf;
  solv = 0;
  for (;;)
    {
      if (bufp - buf + 16 > bufl)
	{
	  bufl = bufp - buf;
	  buf = solv_realloc(buf, bufl + 512);
	  bufp = buf + bufl;
          bufl += 512;
	}
      if (!fgets(bufp, bufl - (bufp - buf), fp))
	break;
      bufp = buf;
      l = strlen(buf);
      if (!l || buf[l - 1] != '\n')
	{
	  bufp += l;
	  continue;
	}
      buf[--l] = 0;
      s = buf;
      while (*s && (*s == ' ' || *s == '\t'))
	s++;
      if (!*s || *s == '#')
	continue;
      npieces = 0;
      /* split it in pieces */
      for (;;)
	{
	  while (*s == ' ' || *s == '\t')
	    s++;
	  if (!*s)
	    break;
	  pieces = solv_extend(pieces, npieces, 1, sizeof(*pieces), 7);
	  pieces[npieces++] = s;
	  while (*s && *s != ' ' && *s != '\t')
	    s++;
	  if (*s)
	    *s++ = 0;
	}
      pieces = solv_extend(pieces, npieces, 1, sizeof(*pieces), 7);
      pieces[npieces] = 0;
      if (!strcmp(pieces[0], "repo") && npieces >= 4)
	{
	  Repo *repo = repo_create(pool, pieces[1]);
	  FILE *rfp;
	  int prio, subprio;
	  const char *rdata;

	  prepared = 0;
          if (!poolflagsreset)
	    {
	      poolflagsreset = 1;
	      testcase_resetpoolflags(pool);	/* hmm */
	    }
	  if (sscanf(pieces[2], "%d.%d", &prio, &subprio) != 2)
	    {
	      subprio = 0;
	      prio = atoi(pieces[2]);
	    }
          repo->priority = prio;
          repo->subpriority = subprio;
	  if (strcmp(pieces[3], "empty") != 0)
	    {
	      const char *repotype = pool_tmpjoin(pool, pieces[3], 0, 0);	/* gets overwritten in <inline> case */
	      if (!strcmp(pieces[4], "<inline>"))
		{
		  char *idata = read_inline_file(fp, &buf, &bufp, &bufl);
		  rdata = "<inline>";
		  rfp = solv_xfopen_buf(rdata, &idata, 0, "rf");
		}
	      else
		{
		  rdata = pool_tmpjoin(pool, testcasedir, pieces[4], 0);
		  rfp = solv_xfopen(rdata, "r");
		}
	      if (!rfp)
		{
		  pool_debug(pool, SOLV_ERROR, "testcase_read: could not open '%s'\n", rdata);
		}
	      else if (!strcmp(repotype, "testtags"))
		{
		  testcase_add_testtags(repo, rfp, 0);
		  fclose(rfp);
		}
	      else if (!strcmp(repotype, "solv"))
		{
		  repo_add_solv(repo, rfp, 0);
		  fclose(rfp);
		}
#if 0
	      else if (!strcmp(repotype, "helix"))
		{
		  extern int repo_add_helix(Repo *repo, FILE *fp, int flags);
		  repo_add_helix(repo, rfp, 0);
		  fclose(rfp);
		}
#endif
	      else
		{
		  fclose(rfp);
		  pool_debug(pool, SOLV_ERROR, "testcase_read: unknown repo type for repo '%s'\n", repo->name);
		}
	    }
	}
      else if (!strcmp(pieces[0], "system") && npieces >= 3)
	{
	  int i;

	  /* must set the disttype before the arch */
	  prepared = 0;
	  if (strcmp(pieces[2], "*") != 0)
	    {
	      char *dp = pieces[2];
	      while (dp && *dp)
		{
		  char *dpe = strchr(dp, ',');
		  if (dpe)
		    *dpe = 0;
		  for (i = 0; disttype2str[i].str != 0; i++)
		    if (!strcmp(disttype2str[i].str, dp))
		      break;
		  if (dpe)
		    *dpe++ = ',';
		  if (disttype2str[i].str)
		    {
#ifdef MULTI_SEMANTICS
		      if (pool->disttype != disttype2str[i].type)
		        pool_setdisttype(pool, disttype2str[i].type);
#endif
		      if (pool->disttype == disttype2str[i].type)
			break;
		    }
		  dp = dpe;
		}
	      if (!(dp && *dp))
		{
		  pool_debug(pool, SOLV_ERROR, "testcase_read: system: could not change disttype to '%s'\n", pieces[2]);
		  missing_features = 1;
		}
	    }
	  if (strcmp(pieces[1], "unset") == 0)
	    pool_setarch(pool, 0);
	  else if (pieces[1][0] == ':')
	    pool_setarchpolicy(pool, pieces[1] + 1);
	  else
	    pool_setarch(pool, pieces[1]);
	  if (npieces > 3)
	    {
	      Repo *repo = testcase_str2repo(pool, pieces[3]);
	      if (!repo)
	        pool_debug(pool, SOLV_ERROR, "testcase_read: system: unknown repo '%s'\n", pieces[3]);
	      else
		pool_set_installed(pool, repo);
	    }
	}
      else if (!strcmp(pieces[0], "job") && npieces > 1)
	{
	  char *sp;
	  Id how, what;
	  if (prepared <= 0)
	    {
	      pool_addfileprovides(pool);
	      pool_createwhatprovides(pool);
	      prepared = 1;
	    }
	  if (npieces >= 3 && !strcmp(pieces[2], "selection"))
	    {
	      addselectionjob(pool, pieces + 1, npieces - 1, job);
	      continue;
	    }
	  /* rejoin */
	  for (sp = pieces[1]; sp < pieces[npieces - 1]; sp++)
	    if (*sp == 0)
	      *sp = ' ';
	  how = testcase_str2job(pool, pieces[1], &what);
	  if (how >= 0 && job)
	    queue_push2(job, how, what);
	}
      else if (!strcmp(pieces[0], "vendorclass") && npieces > 1)
	{
	  pool_addvendorclass(pool, (const char **)(pieces + 1));
	}
      else if (!strcmp(pieces[0], "namespace") && npieces > 1)
	{
	  int i = strlen(pieces[1]);
	  s = strchr(pieces[1], '(');
	  if (!s && pieces[1][i - 1] != ')')
	    {
	      pool_debug(pool, SOLV_ERROR, "testcase_read: bad namespace '%s'\n", pieces[1]);
	    }
	  else
	    {
	      Id name, evr, id;
	      Queue q;
	      queue_init(&q);
	      *s = 0;
	      pieces[1][i - 1] = 0;
	      name = pool_str2id(pool, pieces[1], 1);
	      evr = pool_str2id(pool, s + 1, 1);
	      *s = '(';
	      pieces[1][i - 1] = ')';
	      id = pool_rel2id(pool, name, evr, REL_NAMESPACE, 1);
	      for (i = 2; i < npieces; i++)
		queue_push(&q, testcase_str2solvid(pool, pieces[i]));
	      /* now do the callback */
	      if (prepared <= 0)
		{
		  pool_addfileprovides(pool);
		  pool_createwhatprovides(pool);
		  prepared = 1;
		}
	      pool->whatprovides_rel[GETRELID(id)] = pool_queuetowhatprovides(pool, &q);
	      queue_free(&q);
	    }
	}
      else if (!strcmp(pieces[0], "poolflags"))
        {
	  int i;
          if (!poolflagsreset)
	    {
	      poolflagsreset = 1;
	      testcase_resetpoolflags(pool);	/* hmm */
	    }
	  for (i = 1; i < npieces; i++)
	    testcase_setpoolflags(pool, pieces[i]);
        }
      else if (!strcmp(pieces[0], "solverflags") && npieces > 1)
        {
	  int i;
	  if (!solv)
	    {
	      solv = solver_create(pool);
	      testcase_resetsolverflags(solv);
	    }
	  for (i = 1; i < npieces; i++)
	    testcase_setsolverflags(solv, pieces[i]);
        }
      else if (!strcmp(pieces[0], "result") && npieces > 1)
	{
	  char *result = 0;
	  int resultflags = str2resultflags(pool, pieces[1]);
	  const char *rdata;
	  if (npieces > 2)
	    {
	      rdata = pool_tmpjoin(pool, testcasedir, pieces[2], 0);
	      if (!strcmp(pieces[2], "<inline>"))
		result = read_inline_file(fp, &buf, &bufp, &bufl);
	      else
		{
		  FILE *rfp = fopen(rdata, "r");
		  if (!rfp)
		    pool_debug(pool, SOLV_ERROR, "testcase_read: could not open '%s'\n", rdata);
		  else
		    {
		      result = read_file(rfp);
		      fclose(rfp);
		    }
		}
	    }
	  if (resultp)
	    *resultp = result;
	  else
	    solv_free(result);
	  if (resultflagsp)
	    *resultflagsp = resultflags;
	}
      else if (!strcmp(pieces[0], "nextjob") && npieces == 1)
	{
	  break;
	}
      else if (!strcmp(pieces[0], "disable") && npieces == 3)
	{
	  Id p;
	  if (strcmp(pieces[1], "pkg"))
	    {
	      pool_debug(pool, SOLV_ERROR, "testcase_read: bad disable type '%s'\n", pieces[1]);
	      continue;
	    }
	  if (!prepared)
	    pool_createwhatprovides(pool);
	  prepared = -1;
	  if (!pool->considered)
	    {
	      pool->considered = solv_calloc(1, sizeof(Map));
	      map_init(pool->considered, pool->nsolvables);
	      map_setall(pool->considered);
	    }
	  p = testcase_str2solvid(pool, pieces[2]);
	  if (p)
	    MAPCLR(pool->considered, p);
	  else
	    pool_debug(pool, SOLV_ERROR, "disable: unknown package '%s'\n", pieces[2]);
	}
      else if (!strcmp(pieces[0], "feature"))
	{
	  int i, j;
	  for (i = 1; i < npieces; i++)
	    {
	      for (j = 0; features[j]; j++)
		if (!strcmp(pieces[i], features[j]))
		  break;
	      if (!features[j])
		{
		  pool_debug(pool, SOLV_ERROR, "testcase_read: missing feature '%s'\n", pieces[i]);
		  missing_features++;
		}
	    }
	  if (missing_features)
	    break;
	}
      else if (!strcmp(pieces[0], "genid") && npieces > 1)
	{
	  Id id;
	  /* rejoin */
	  if (npieces > 2)
	    {
	      char *sp;
	      for (sp = pieces[2]; sp < pieces[npieces - 1]; sp++)
	        if (*sp == 0)
	          *sp = ' ';
	    }
	  genid = solv_extend(genid, ngenid, 1, sizeof(*genid), 7);
	  if (!strcmp(pieces[1], "op") && npieces > 2)
	    {
	      struct oplist *op;
	      for (op = oplist; op->flags; op++)
		if (!strncmp(pieces[2], op->opname, strlen(op->opname)))
		  break;
	      if (!op->flags)
		{
		  pool_debug(pool, SOLV_ERROR, "testcase_read: genid: unknown op '%s'\n", pieces[2]);
		  break;
		}
	      if (ngenid < 2)
		{
		  pool_debug(pool, SOLV_ERROR, "testcase_read: genid: out of stack\n");
		  break;
		}
	      ngenid -= 2;
	      id = pool_rel2id(pool, genid[ngenid] , genid[ngenid + 1], op->flags, 1);
	    }
	  else if (!strcmp(pieces[1], "lit"))
	    id = pool_str2id(pool, npieces > 2 ? pieces[2] : "", 1);
	  else if (!strcmp(pieces[1], "null"))
	    id = 0;
	  else if (!strcmp(pieces[1], "dep"))
	    id = testcase_str2dep(pool, pieces[2]);
	  else
	    {
	      pool_debug(pool, SOLV_ERROR, "testcase_read: genid: unknown command '%s'\n", pieces[1]);
	      break;
	    }
	  genid[ngenid++] = id;
	}
      else
	{
	  pool_debug(pool, SOLV_ERROR, "testcase_read: cannot parse command '%s'\n", pieces[0]);
	}
    }
  while (job && ngenid > 0)
    queue_push2(job, SOLVER_NOOP | SOLVER_SOLVABLE_PROVIDES, genid[--ngenid]);
  genid = solv_free(genid);
  buf = solv_free(buf);
  pieces = solv_free(pieces);
  solv_free(testcasedir);
  if (!prepared)
    {
      pool_addfileprovides(pool);
      pool_createwhatprovides(pool);
    }
  if (!solv)
    {
      solv = solver_create(pool);
      testcase_resetsolverflags(solv);
    }
  if (closefp)
    fclose(fp);
  if (missing_features)
    {
      solver_free(solv);
      solv = 0;
      if (resultflagsp)
	*resultflagsp = 77;	/* hack for testsolv */
    }
  return solv;
}

char *
testcase_resultdiff(char *result1, char *result2)
{
  Strqueue sq1, sq2, osq;
  char *r;
  strqueue_init(&sq1);
  strqueue_init(&sq2);
  strqueue_init(&osq);
  strqueue_split(&sq1, result1);
  strqueue_split(&sq2, result2);
  strqueue_sort(&sq1);
  strqueue_sort(&sq2);
  strqueue_diff(&sq1, &sq2, &osq);
  r = osq.nstr ? strqueue_join(&osq) : 0;
  strqueue_free(&sq1);
  strqueue_free(&sq2);
  strqueue_free(&osq);
  return r;
}

