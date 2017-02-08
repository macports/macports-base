/*
 * Copyright (c) 2007-2012, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * repo_rpmdb
 *
 * convert rpm db to repo
 *
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <limits.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>
#include <stdint.h>
#include <errno.h>

#include <rpm/rpmio.h>
#include <rpm/rpmpgp.h>
#ifndef RPM5
#include <rpm/header.h>
#endif
#include <rpm/rpmdb.h>

#ifndef DB_CREATE
# if defined(SUSE) || defined(HAVE_RPM_DB_H)
#  include <rpm/db.h>
# else
#  include <db.h>
# endif
#endif

#include "pool.h"
#include "repo.h"
#include "hash.h"
#include "util.h"
#include "queue.h"
#include "chksum.h"
#include "repo_rpmdb.h"
#include "repo_solv.h"
#ifdef ENABLE_COMPLEX_DEPS
#include "pool_parserpmrichdep.h"
#endif

/* 3: added triggers */
/* 4: fixed triggers */
/* 5: fixed checksum copying */
#define RPMDB_COOKIE_VERSION 5

#define TAG_NAME		1000
#define TAG_VERSION		1001
#define TAG_RELEASE		1002
#define TAG_EPOCH		1003
#define TAG_SUMMARY		1004
#define TAG_DESCRIPTION		1005
#define TAG_BUILDTIME		1006
#define TAG_BUILDHOST		1007
#define TAG_INSTALLTIME		1008
#define TAG_SIZE		1009
#define TAG_DISTRIBUTION	1010
#define TAG_VENDOR		1011
#define TAG_LICENSE		1014
#define TAG_PACKAGER		1015
#define TAG_GROUP		1016
#define TAG_URL			1020
#define TAG_ARCH		1022
#define TAG_FILESIZES		1028
#define TAG_FILEMODES		1030
#define TAG_FILEMD5S		1035
#define TAG_FILELINKTOS		1036
#define TAG_FILEFLAGS		1037
#define TAG_SOURCERPM		1044
#define TAG_PROVIDENAME		1047
#define TAG_REQUIREFLAGS	1048
#define TAG_REQUIRENAME		1049
#define TAG_REQUIREVERSION	1050
#define TAG_NOSOURCE		1051
#define TAG_NOPATCH		1052
#define TAG_CONFLICTFLAGS	1053
#define TAG_CONFLICTNAME	1054
#define TAG_CONFLICTVERSION	1055
#define TAG_TRIGGERNAME		1066
#define TAG_TRIGGERVERSION	1067
#define TAG_TRIGGERFLAGS	1068
#define TAG_CHANGELOGTIME	1080
#define TAG_CHANGELOGNAME	1081
#define TAG_CHANGELOGTEXT	1082
#define TAG_OBSOLETENAME	1090
#define TAG_FILEDEVICES		1095
#define TAG_FILEINODES		1096
#define TAG_SOURCEPACKAGE	1106
#define TAG_PROVIDEFLAGS	1112
#define TAG_PROVIDEVERSION	1113
#define TAG_OBSOLETEFLAGS	1114
#define TAG_OBSOLETEVERSION	1115
#define TAG_DIRINDEXES		1116
#define TAG_BASENAMES		1117
#define TAG_DIRNAMES		1118
#define TAG_PAYLOADFORMAT	1124
#define TAG_PATCHESNAME		1133
#define TAG_FILECOLORS		1140
#define TAG_OLDSUGGESTSNAME	1156
#define TAG_OLDSUGGESTSVERSION	1157
#define TAG_OLDSUGGESTSFLAGS	1158
#define TAG_OLDENHANCESNAME	1159
#define TAG_OLDENHANCESVERSION	1160
#define TAG_OLDENHANCESFLAGS	1161

/* rpm5 tags */
#define TAG_DISTEPOCH		1218

/* rpm4 tags */
#define TAG_LONGFILESIZES	5008
#define TAG_LONGSIZE		5009
#define TAG_RECOMMENDNAME	5046
#define TAG_RECOMMENDVERSION	5047
#define TAG_RECOMMENDFLAGS	5048
#define TAG_SUGGESTNAME		5049
#define TAG_SUGGESTVERSION	5050
#define TAG_SUGGESTFLAGS	5051
#define TAG_SUPPLEMENTNAME	5052
#define TAG_SUPPLEMENTVERSION	5053
#define TAG_SUPPLEMENTFLAGS	5054
#define TAG_ENHANCENAME		5055
#define TAG_ENHANCEVERSION	5056
#define TAG_ENHANCEFLAGS	5057

/* signature tags */
#define	TAG_SIGBASE		256
#define TAG_SIGMD5		(TAG_SIGBASE + 5)
#define TAG_SHA1HEADER		(TAG_SIGBASE + 13)

#define SIGTAG_SIZE		1000
#define SIGTAG_PGP		1002	/* RSA signature */
#define SIGTAG_MD5		1004	/* header+payload md5 checksum */
#define SIGTAG_GPG		1005	/* DSA signature */

#define DEP_LESS		(1 << 1)
#define DEP_GREATER		(1 << 2)
#define DEP_EQUAL		(1 << 3)
#define DEP_STRONG		(1 << 27)
#define DEP_PRE_IN		((1 << 6) | (1 << 9) | (1 << 10))
#define DEP_PRE_UN		((1 << 6) | (1 << 11) | (1 << 12))
#define DEP_RICH		(1 << 29)

#define FILEFLAG_GHOST		(1 <<  6)


#ifdef RPM5
# define RPM_INDEX_SIZE 4	/* just the rpmdbid */
#else
# define RPM_INDEX_SIZE 8	/* rpmdbid + array index */
#endif


typedef struct rpmhead {
  int cnt;
  int dcnt;
  unsigned char *dp;
  int forcebinary;		/* sigh, see rh#478907 */
  unsigned char data[1];
} RpmHead;


static inline unsigned char *
headfindtag(RpmHead *h, int tag)
{
  unsigned int i;
  unsigned char *d, taga[4];
  d = h->dp - 16;
  taga[0] = tag >> 24;
  taga[1] = tag >> 16;
  taga[2] = tag >> 8;
  taga[3] = tag;
  for (i = 0; i < h->cnt; i++, d -= 16)
    if (d[3] == taga[3] && d[2] == taga[2] && d[1] == taga[1] && d[0] == taga[0])
      return d;
  return 0;
}

static int
headexists(RpmHead *h, int tag)
{
  return headfindtag(h, tag) ? 1 : 0;
}

static unsigned int *
headint32array(RpmHead *h, int tag, int *cnt)
{
  unsigned int i, o, *r;
  unsigned char *d = headfindtag(h, tag);

  if (!d || d[4] != 0 || d[5] != 0 || d[6] != 0 || d[7] != 4)
    return 0;
  o = d[8] << 24 | d[9] << 16 | d[10] << 8 | d[11];
  i = d[12] << 24 | d[13] << 16 | d[14] << 8 | d[15];
  if (o + 4 * i > h->dcnt)
    return 0;
  d = h->dp + o;
  r = solv_calloc(i ? i : 1, sizeof(unsigned int));
  if (cnt)
    *cnt = i;
  for (o = 0; o < i; o++, d += 4)
    r[o] = d[0] << 24 | d[1] << 16 | d[2] << 8 | d[3];
  return r;
}

/* returns the first entry of an integer array */
static unsigned int
headint32(RpmHead *h, int tag)
{
  unsigned int i, o;
  unsigned char *d = headfindtag(h, tag);

  if (!d || d[4] != 0 || d[5] != 0 || d[6] != 0 || d[7] != 4)
    return 0;
  o = d[8] << 24 | d[9] << 16 | d[10] << 8 | d[11];
  i = d[12] << 24 | d[13] << 16 | d[14] << 8 | d[15];
  if (i == 0 || o + 4 * i > h->dcnt)
    return 0;
  d = h->dp + o;
  return d[0] << 24 | d[1] << 16 | d[2] << 8 | d[3];
}

static unsigned long long *
headint64array(RpmHead *h, int tag, int *cnt)
{
  unsigned int i, o;
  unsigned long long *r;
  unsigned char *d = headfindtag(h, tag);

  if (!d || d[4] != 0 || d[5] != 0 || d[6] != 0 || d[7] != 5)
    return 0;
  o = d[8] << 24 | d[9] << 16 | d[10] << 8 | d[11];
  i = d[12] << 24 | d[13] << 16 | d[14] << 8 | d[15];
  if (o + 8 * i > h->dcnt)
    return 0;
  d = h->dp + o;
  r = solv_calloc(i ? i : 1, sizeof(unsigned long long));
  if (cnt)
    *cnt = i;
  for (o = 0; o < i; o++, d += 8)
    {
      unsigned int x = d[0] << 24 | d[1] << 16 | d[2] << 8 | d[3];
      r[o] = (unsigned long long)x << 32 | (d[4] << 24 | d[5] << 16 | d[6] << 8 | d[7]);
    }
  return r;
}

/* returns the first entry of an 64bit integer array */
static unsigned long long
headint64(RpmHead *h, int tag)
{
  unsigned int i, o;
  unsigned char *d = headfindtag(h, tag);
  if (!d || d[4] != 0 || d[5] != 0 || d[6] != 0 || d[7] != 5)
    return 0;
  o = d[8] << 24 | d[9] << 16 | d[10] << 8 | d[11];
  i = d[12] << 24 | d[13] << 16 | d[14] << 8 | d[15];
  if (i == 0 || o + 8 * i > h->dcnt)
    return 0;
  d = h->dp + o;
  i = d[0] << 24 | d[1] << 16 | d[2] << 8 | d[3];
  return (unsigned long long)i << 32 | (d[4] << 24 | d[5] << 16 | d[6] << 8 | d[7]);
}

static unsigned int *
headint16array(RpmHead *h, int tag, int *cnt)
{
  unsigned int i, o, *r;
  unsigned char *d = headfindtag(h, tag);

  if (!d || d[4] != 0 || d[5] != 0 || d[6] != 0 || d[7] != 3)
    return 0;
  o = d[8] << 24 | d[9] << 16 | d[10] << 8 | d[11];
  i = d[12] << 24 | d[13] << 16 | d[14] << 8 | d[15];
  if (o + 4 * i > h->dcnt)
    return 0;
  d = h->dp + o;
  r = solv_calloc(i ? i : 1, sizeof(unsigned int));
  if (cnt)
    *cnt = i;
  for (o = 0; o < i; o++, d += 2)
    r[o] = d[0] << 8 | d[1];
  return r;
}

static char *
headstring(RpmHead *h, int tag)
{
  unsigned int o;
  unsigned char *d = headfindtag(h, tag);
  /* 6: STRING, 9: I18NSTRING */
  if (!d || d[4] != 0 || d[5] != 0 || d[6] != 0 || (d[7] != 6 && d[7] != 9))
    return 0;
  o = d[8] << 24 | d[9] << 16 | d[10] << 8 | d[11];
  if (o >= h->dcnt)
    return 0;
  return (char *)h->dp + o;
}

static char **
headstringarray(RpmHead *h, int tag, int *cnt)
{
  unsigned int i, o;
  unsigned char *d = headfindtag(h, tag);
  char **r;

  if (!d || d[4] != 0 || d[5] != 0 || d[6] != 0 || d[7] != 8)
    return 0;
  o = d[8] << 24 | d[9] << 16 | d[10] << 8 | d[11];
  i = d[12] << 24 | d[13] << 16 | d[14] << 8 | d[15];
  r = solv_calloc(i ? i : 1, sizeof(char *));
  if (cnt)
    *cnt = i;
  d = h->dp + o;
  for (o = 0; o < i; o++)
    {
      r[o] = (char *)d;
      if (o + 1 < i)
        d += strlen((char *)d) + 1;
      if (d >= h->dp + h->dcnt)
        {
          solv_free(r);
          return 0;
        }
    }
  return r;
}

static unsigned char *
headbinary(RpmHead *h, int tag, unsigned int *sizep)
{
  unsigned int i, o;
  unsigned char *d = headfindtag(h, tag);
  if (!d || d[4] != 0 || d[5] != 0 || d[6] != 0 || d[7] != 7)
    return 0;
  o = d[8] << 24 | d[9] << 16 | d[10] << 8 | d[11];
  i = d[12] << 24 | d[13] << 16 | d[14] << 8 | d[15];
  if (o > h->dcnt || o + i < o || o + i > h->dcnt)
    return 0;
  if (sizep)
    *sizep = i;
  return h->dp + o;
}

static char *headtoevr(RpmHead *h)
{
  unsigned int epoch;
  char *version, *v;
  char *release;
  char *evr;
  char *distepoch;

  version  = headstring(h, TAG_VERSION);
  release  = headstring(h, TAG_RELEASE);
  epoch = headint32(h, TAG_EPOCH);
  if (!version || !release)
    {
      fprintf(stderr, "headtoevr: bad rpm header\n");
      return 0;
    }
  for (v = version; *v >= '0' && *v <= '9'; v++)
    ;
  if (epoch || (v != version && *v == ':'))
    {
      char epochbuf[11];        /* 32bit decimal will fit in */
      sprintf(epochbuf, "%u", epoch);
      evr = solv_malloc(strlen(epochbuf) + 1 + strlen(version) + 1 + strlen(release) + 1);
      sprintf(evr, "%s:%s-%s", epochbuf, version, release);
    }
  else
    {
      evr = solv_malloc(strlen(version) + 1 + strlen(release) + 1);
      sprintf(evr, "%s-%s", version, release);
    }
  distepoch = headstring(h, TAG_DISTEPOCH);
  if (distepoch && *distepoch)
    {
      int l = strlen(evr);
      evr = solv_realloc(evr, l + strlen(distepoch) + 2);
      evr[l++] = ':';
      strcpy(evr + l, distepoch);
    }
  return evr;
}


static void
setutf8string(Repodata *repodata, Id handle, Id tag, const char *str)
{
  if (str[solv_validutf8(str)])
    {
      char *ustr = solv_latin1toutf8(str);	/* not utf8, assume latin1 */
      repodata_set_str(repodata, handle, tag, ustr);
      solv_free(ustr);
    }
  else
    repodata_set_str(repodata, handle, tag, str);
}

/*
 * strong: 0: ignore strongness
 *         1: filter to strong
 *         2: filter to weak
 */
static unsigned int
makedeps(Pool *pool, Repo *repo, RpmHead *rpmhead, int tagn, int tagv, int tagf, int flags)
{
  char **n, **v;
  unsigned int *f;
  int i, cc, nc, vc, fc;
  int haspre, premask;
  unsigned int olddeps;
  Id *ida;
  int strong = 0;

  n = headstringarray(rpmhead, tagn, &nc);
  if (!n)
    {
      switch (tagn)
	{
	case TAG_SUGGESTNAME:
	  tagn = TAG_OLDSUGGESTSNAME;
	  tagv = TAG_OLDSUGGESTSVERSION;
	  tagf = TAG_OLDSUGGESTSFLAGS;
	  strong = -1;
	  break;
	case TAG_ENHANCENAME:
	  tagn = TAG_OLDENHANCESNAME;
	  tagv = TAG_OLDENHANCESVERSION;
	  tagf = TAG_OLDENHANCESFLAGS;
	  strong = -1;
	  break;
	case TAG_RECOMMENDNAME:
	  tagn = TAG_OLDSUGGESTSNAME;
	  tagv = TAG_OLDSUGGESTSVERSION;
	  tagf = TAG_OLDSUGGESTSFLAGS;
	  strong = 1;
	  break;
	case TAG_SUPPLEMENTNAME:
	  tagn = TAG_OLDENHANCESNAME;
	  tagv = TAG_OLDENHANCESVERSION;
	  tagf = TAG_OLDENHANCESFLAGS;
	  strong = 1;
	  break;
	default:
	  return 0;
	}
      n = headstringarray(rpmhead, tagn, &nc);
    }
  if (!n || !nc)
    return 0;
  vc = fc = 0;
  v = headstringarray(rpmhead, tagv, &vc);
  f = headint32array(rpmhead, tagf, &fc);
  if (!v || !f || nc != vc || nc != fc)
    {
      char *pkgname = rpm_query(rpmhead, 0);
      pool_error(pool, 0, "bad dependency entries for %s: %d %d %d", pkgname ? pkgname : "<NULL>", nc, vc, fc);
      solv_free(pkgname);
      solv_free(n);
      solv_free(v);
      solv_free(f);
      return 0;
    }

  cc = nc;
  haspre = 0;	/* add no prereq marker */
  premask = tagn == TAG_REQUIRENAME ? DEP_PRE_IN | DEP_PRE_UN : 0;
  if ((flags & RPM_ADD_NO_RPMLIBREQS) || strong)
    {
      /* we do filtering */
      cc = 0;
      for (i = 0; i < nc; i++)
	{
	  if (strong && (f[i] & DEP_STRONG) != (strong < 0 ? 0 : DEP_STRONG))
	    continue;
	  if ((flags & RPM_ADD_NO_RPMLIBREQS) != 0)
	    if (!strncmp(n[i], "rpmlib(", 7))
	      continue;
	  if ((f[i] & premask) != 0)
	    haspre = 1;
	  cc++;
	}
    }
  else if (premask)
    {
      /* no filtering, just look for the first prereq */
      for (i = 0; i < nc; i++)
	if ((f[i] & premask) != 0)
	  {
	    haspre = 1;
	    break;
	  }
    }
  if (cc == 0)
    {
      solv_free(n);
      solv_free(v);
      solv_free(f);
      return 0;
    }
  cc += haspre;		/* add slot for the prereq marker */
  olddeps = repo_reserve_ids(repo, 0, cc);
  ida = repo->idarraydata + olddeps;
  for (i = 0; ; i++)
    {
      Id id;
      if (i == nc)
	{
	  if (haspre != 1)
	    break;
	  haspre = 2;	/* pass two: prereqs */
	  i = 0;
	  *ida++ = SOLVABLE_PREREQMARKER;
	}
      if (strong && (f[i] & DEP_STRONG) != (strong < 0 ? 0 : DEP_STRONG))
	continue;
      if (haspre)
	{
	  if (haspre == 1 && (f[i] & premask) != 0)
	    continue;
	  if (haspre == 2 && (f[i] & premask) == 0)
	    continue;
	}
      if ((flags & RPM_ADD_NO_RPMLIBREQS) != 0)
	if (!strncmp(n[i], "rpmlib(", 7))
	  continue;
#ifdef ENABLE_COMPLEX_DEPS
      if ((f[i] & (DEP_RICH|DEP_LESS| DEP_EQUAL|DEP_GREATER)) == DEP_RICH && n[i][0] == '(')
	{
	  id = pool_parserpmrichdep(pool, n[i]);
	  if (id)
	    *ida++ = id;
	  else
	    cc--;
	  continue;
	}
#endif
      id = pool_str2id(pool, n[i], 1);
      if (f[i] & (DEP_LESS|DEP_GREATER|DEP_EQUAL))
	{
	  Id evr;
	  int fl = 0;
	  if ((f[i] & DEP_LESS) != 0)
	    fl |= REL_LT;
	  if ((f[i] & DEP_EQUAL) != 0)
	    fl |= REL_EQ;
	  if ((f[i] & DEP_GREATER) != 0)
	    fl |= REL_GT;
	  if (v[i][0] == '0' && v[i][1] == ':' && v[i][2])
	    evr = pool_str2id(pool, v[i] + 2, 1);
	  else
	    evr = pool_str2id(pool, v[i], 1);
	  id = pool_rel2id(pool, id, evr, fl, 1);
	}
      *ida++ = id;
    }
  *ida++ = 0;
  repo->idarraysize += cc + 1;
  solv_free(n);
  solv_free(v);
  solv_free(f);
  return olddeps;
}


static void
adddudata(Repodata *data, Id handle, RpmHead *rpmhead, char **dn, unsigned int *di, int fc, int dc)
{
  Id did;
  int i, fszc;
  unsigned int *fkb, *fn, *fsz, *fm, *fino;
  unsigned long long *fsz64;
  unsigned int inotest[256], inotestok;

  if (!fc)
    return;
  if ((fsz64 = headint64array(rpmhead, TAG_LONGFILESIZES, &fszc)) != 0)
    {
      /* convert to kbyte */
      fsz = solv_malloc2(fszc, sizeof(*fsz));
      for (i = 0; i < fszc; i++)
        fsz[i] = fsz64[i] ? fsz64[i] / 1024 + 1 : 0;
      solv_free(fsz64);
    }
  else if ((fsz = headint32array(rpmhead, TAG_FILESIZES, &fszc)) != 0)
    {
      /* convert to kbyte */
      for (i = 0; i < fszc; i++)
        if (fsz[i])
	  fsz[i] = fsz[i] / 1024 + 1;
    }
  else
    return;
  if (fc != fszc)
    {
      solv_free(fsz);
      return;
    }

  /* stupid rpm records sizes of directories, so we have to check the mode */
  fm = headint16array(rpmhead, TAG_FILEMODES, &fszc);
  if (!fm || fc != fszc)
    {
      solv_free(fsz);
      solv_free(fm);
      return;
    }
  fino = headint32array(rpmhead, TAG_FILEINODES, &fszc);
  if (!fino || fc != fszc)
    {
      solv_free(fsz);
      solv_free(fm);
      solv_free(fino);
      return;
    }

  /* kill hardlinked entries */
  inotestok = 0;
  if (fc < sizeof(inotest))
    {
      /* quick test just hashing the inode numbers */
      memset(inotest, 0, sizeof(inotest));
      for (i = 0; i < fc; i++)
	{
	  int off, bit;
	  if (fsz[i] == 0 || !S_ISREG(fm[i]))
	    continue;	/* does not matter */
	  off = (fino[i] >> 5) & (sizeof(inotest)/sizeof(*inotest) - 1);
	  bit = 1 << (fino[i] & 31);
	  if ((inotest[off] & bit) != 0)
	    break;
	  inotest[off] |= bit;
	}
      if (i == fc)
	inotestok = 1;	/* no conflict found */
    }
  if (!inotestok)
    {
      /* hardlinked files are possible, check ino/dev pairs */
      unsigned int *fdev = headint32array(rpmhead, TAG_FILEDEVICES, &fszc);
      unsigned int *fx, j;
      unsigned int mask, hash, hh;
      if (!fdev || fc != fszc)
	{
	  solv_free(fsz);
	  solv_free(fm);
	  solv_free(fdev);
	  solv_free(fino);
	  return;
	}
      mask = fc;
      while ((mask & (mask - 1)) != 0)
	mask = mask & (mask - 1);
      mask <<= 2;
      if (mask > sizeof(inotest)/sizeof(*inotest))
        fx = solv_calloc(mask, sizeof(unsigned int));
      else
	{
	  fx = inotest;
	  memset(fx, 0, mask * sizeof(unsigned int));
	}
      mask--;
      for (i = 0; i < fc; i++)
	{
	  if (fsz[i] == 0 || !S_ISREG(fm[i]))
	    continue;
	  hash = (fino[i] + fdev[i] * 31) & mask;
          hh = 7;
	  while ((j = fx[hash]) != 0)
	    {
	      if (fino[j - 1] == fino[i] && fdev[j - 1] == fdev[i])
		{
		  fsz[i] = 0;	/* kill entry */
		  break;
		}
	      hash = (hash + hh++) & mask;
	    }
	  if (!j)
	    fx[hash] = i + 1;
	}
      if (fx != inotest)
        solv_free(fx);
      solv_free(fdev);
    }
  solv_free(fino);

  /* sum up inode count and kbytes for each directory */
  fn = solv_calloc(dc, sizeof(unsigned int));
  fkb = solv_calloc(dc, sizeof(unsigned int));
  for (i = 0; i < fc; i++)
    {
      if (di[i] >= dc)
	continue;	/* corrupt entry */
      fn[di[i]]++;
      if (fsz[i] == 0 || !S_ISREG(fm[i]))
	continue;
      fkb[di[i]] += fsz[i];
    }
  solv_free(fsz);
  solv_free(fm);
  /* commit */
  for (i = 0; i < dc; i++)
    {
      if (!fn[i])
	continue;
      if (!*dn[i])
	{
	  Solvable *s = data->repo->pool->solvables + handle;
          if (s->arch == ARCH_SRC || s->arch == ARCH_NOSRC)
	    did = repodata_str2dir(data, "/usr/src", 1);
	  else
	    continue;	/* work around rpm bug */
	}
      else
        did = repodata_str2dir(data, dn[i], 1);
      repodata_add_dirnumnum(data, handle, SOLVABLE_DISKUSAGE, did, fkb[i], fn[i]);
    }
  solv_free(fn);
  solv_free(fkb);
}

static int
is_filtered(const char *dir)
{
  if (!dir)
    return 1;
  /* the dirs always have a trailing / in rpm */
  if (strstr(dir, "bin/"))
    return 0;
  if (!strncmp(dir, "/etc/", 5))
    return 0;
  if (!strcmp(dir, "/usr/lib/"))
    return 2;
  return 1;
}

static void
addfilelist(Repodata *data, Id handle, RpmHead *rpmhead, int flags)
{
  char **bn;
  char **dn;
  unsigned int *di;
  int bnc, dnc, dic;
  int i;
  Id lastdid = 0;
  unsigned int lastdii = -1;
  int lastfiltered = 0;

  if (!data)
    return;
  bn = headstringarray(rpmhead, TAG_BASENAMES, &bnc);
  if (!bn)
    return;
  dn = headstringarray(rpmhead, TAG_DIRNAMES, &dnc);
  if (!dn)
    {
      solv_free(bn);
      return;
    }
  di = headint32array(rpmhead, TAG_DIRINDEXES, &dic);
  if (!di)
    {
      solv_free(bn);
      solv_free(dn);
      return;
    }
  if (bnc != dic)
    {
      pool_error(data->repo->pool, 0, "bad filelist");
      return;
    }

  adddudata(data, handle, rpmhead, dn, di, bnc, dnc);

  for (i = 0; i < bnc; i++)
    {
      Id did;
      char *b = bn[i];

      if (di[i] == lastdii)
	did = lastdid;
      else
	{
	  if (di[i] >= dnc)
	    continue;	/* corrupt entry */
	  lastdii = di[i];
	  if ((flags & RPM_ADD_FILTERED_FILELIST) != 0)
	    {
	      lastfiltered = is_filtered(dn[di[i]]);
	      if (lastfiltered == 1)
		continue;
	    }
	  did = repodata_str2dir(data, dn[lastdii], 1);
	  if (!did)
	    did = repodata_str2dir(data, "/", 1);
	  lastdid = did;
	}
      if (b && *b == '/')	/* work around rpm bug */
	b++;
      if (lastfiltered)
	{
	  if (lastfiltered != 2 || strcmp(b, "sendmail"))
	    continue;
	}
      repodata_add_dirstr(data, handle, SOLVABLE_FILELIST, did, b);
    }
  solv_free(bn);
  solv_free(dn);
  solv_free(di);
}

static void
addchangelog(Repodata *data, Id handle, RpmHead *rpmhead)
{
  char **cn;
  char **cx;
  unsigned int *ct;
  int i, cnc, cxc, ctc;
  Queue hq;

  ct = headint32array(rpmhead, TAG_CHANGELOGTIME, &ctc);
  cx = headstringarray(rpmhead, TAG_CHANGELOGTEXT, &cxc);
  cn = headstringarray(rpmhead, TAG_CHANGELOGNAME, &cnc);
  if (!ct || !cx || !cn || !ctc || ctc != cxc || ctc != cnc)
    {
      solv_free(ct);
      solv_free(cx);
      solv_free(cn);
      return;
    }
  queue_init(&hq);
  for (i = 0; i < ctc; i++)
    {
      Id h = repodata_new_handle(data);
      if (ct[i])
        repodata_set_num(data, h, SOLVABLE_CHANGELOG_TIME, ct[i]);
      if (cn[i])
        setutf8string(data, h, SOLVABLE_CHANGELOG_AUTHOR, cn[i]);
      if (cx[i])
        setutf8string(data, h, SOLVABLE_CHANGELOG_TEXT, cx[i]);
      queue_push(&hq, h);
    }
  for (i = 0; i < hq.count; i++)
    repodata_add_flexarray(data, handle, SOLVABLE_CHANGELOG, hq.elements[i]);
  queue_free(&hq);
  solv_free(ct);
  solv_free(cx);
  solv_free(cn);
}

static void
set_description_author(Repodata *data, Id handle, char *str)
{
  char *aut, *p;
  for (aut = str; (aut = strchr(aut, '\n')) != 0; aut++)
    if (!strncmp(aut, "\nAuthors:\n--------\n", 19))
      break;
  if (aut)
    {
      /* oh my, found SUSE special author section */
      int l = aut - str;
      str = solv_strdup(str);
      aut = str + l;
      str[l] = 0;
      while (l > 0 && str[l - 1] == '\n')
	str[--l] = 0;
      if (l)
	setutf8string(data, handle, SOLVABLE_DESCRIPTION, str);
      p = aut + 19;
      aut = str;	/* copy over */
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
	setutf8string(data, handle, SOLVABLE_AUTHORS, str);
      free(str);
    }
  else if (*str)
    setutf8string(data, handle, SOLVABLE_DESCRIPTION, str);
}

static int
rpm2solv(Pool *pool, Repo *repo, Repodata *data, Solvable *s, RpmHead *rpmhead, int flags)
{
  char *name;
  char *evr;
  char *sourcerpm;

  name = headstring(rpmhead, TAG_NAME);
  if (!name)
    {
      pool_error(pool, 0, "package has no name");
      return 0;
    }
  if (!strcmp(name, "gpg-pubkey"))
    return 0;
  s->name = pool_str2id(pool, name, 1);
  sourcerpm = headstring(rpmhead, TAG_SOURCERPM);
  if (sourcerpm || (rpmhead->forcebinary && !headexists(rpmhead, TAG_SOURCEPACKAGE)))
    s->arch = pool_str2id(pool, headstring(rpmhead, TAG_ARCH), 1);
  else
    {
      if (headexists(rpmhead, TAG_NOSOURCE) || headexists(rpmhead, TAG_NOPATCH))
        s->arch = ARCH_NOSRC;
      else
        s->arch = ARCH_SRC;
    }
  if (!s->arch)
    s->arch = ARCH_NOARCH;
  evr = headtoevr(rpmhead);
  s->evr = pool_str2id(pool, evr, 1);
  s->vendor = pool_str2id(pool, headstring(rpmhead, TAG_VENDOR), 1);

  s->provides = makedeps(pool, repo, rpmhead, TAG_PROVIDENAME, TAG_PROVIDEVERSION, TAG_PROVIDEFLAGS, 0);
  if (s->arch != ARCH_SRC && s->arch != ARCH_NOSRC)
    s->provides = repo_addid_dep(repo, s->provides, pool_rel2id(pool, s->name, s->evr, REL_EQ, 1), 0);
  s->requires = makedeps(pool, repo, rpmhead, TAG_REQUIRENAME, TAG_REQUIREVERSION, TAG_REQUIREFLAGS, flags);
  s->conflicts = makedeps(pool, repo, rpmhead, TAG_CONFLICTNAME, TAG_CONFLICTVERSION, TAG_CONFLICTFLAGS, 0);
  s->obsoletes = makedeps(pool, repo, rpmhead, TAG_OBSOLETENAME, TAG_OBSOLETEVERSION, TAG_OBSOLETEFLAGS, 0);

  s->recommends = makedeps(pool, repo, rpmhead, TAG_RECOMMENDNAME, TAG_RECOMMENDVERSION, TAG_RECOMMENDFLAGS, 0);
  s->suggests = makedeps(pool, repo, rpmhead, TAG_SUGGESTNAME, TAG_SUGGESTVERSION, TAG_SUGGESTFLAGS, 0);
  s->supplements = makedeps(pool, repo, rpmhead, TAG_SUPPLEMENTNAME, TAG_SUPPLEMENTVERSION, TAG_SUPPLEMENTFLAGS, 0);
  s->enhances  = makedeps(pool, repo, rpmhead, TAG_ENHANCENAME, TAG_ENHANCEVERSION, TAG_ENHANCEFLAGS, 0);

  s->supplements = repo_fix_supplements(repo, s->provides, s->supplements, 0);
  s->conflicts = repo_fix_conflicts(repo, s->conflicts);

  if (data)
    {
      Id handle;
      char *str;
      unsigned int u32;
      unsigned long long u64;

      handle = s - pool->solvables;
      str = headstring(rpmhead, TAG_SUMMARY);
      if (str)
        setutf8string(data, handle, SOLVABLE_SUMMARY, str);
      str = headstring(rpmhead, TAG_DESCRIPTION);
      if (str)
	set_description_author(data, handle, str);
      str = headstring(rpmhead, TAG_GROUP);
      if (str)
        repodata_set_poolstr(data, handle, SOLVABLE_GROUP, str);
      str = headstring(rpmhead, TAG_LICENSE);
      if (str)
        repodata_set_poolstr(data, handle, SOLVABLE_LICENSE, str);
      str = headstring(rpmhead, TAG_URL);
      if (str)
	repodata_set_str(data, handle, SOLVABLE_URL, str);
      str = headstring(rpmhead, TAG_DISTRIBUTION);
      if (str)
	repodata_set_poolstr(data, handle, SOLVABLE_DISTRIBUTION, str);
      str = headstring(rpmhead, TAG_PACKAGER);
      if (str)
	repodata_set_poolstr(data, handle, SOLVABLE_PACKAGER, str);
      if ((flags & RPM_ADD_WITH_PKGID) != 0)
	{
	  unsigned char *chksum;
	  unsigned int chksumsize;
	  chksum = headbinary(rpmhead, TAG_SIGMD5, &chksumsize);
	  if (chksum && chksumsize == 16)
	    repodata_set_bin_checksum(data, handle, SOLVABLE_PKGID, REPOKEY_TYPE_MD5, chksum);
	}
      if ((flags & RPM_ADD_WITH_HDRID) != 0)
	{
	  str = headstring(rpmhead, TAG_SHA1HEADER);
	  if (str && strlen(str) == 40)
	    repodata_set_checksum(data, handle, SOLVABLE_HDRID, REPOKEY_TYPE_SHA1, str);
	  else if (str && strlen(str) == 64)
	    repodata_set_checksum(data, handle, SOLVABLE_HDRID, REPOKEY_TYPE_SHA256, str);
	}
      u32 = headint32(rpmhead, TAG_BUILDTIME);
      if (u32)
        repodata_set_num(data, handle, SOLVABLE_BUILDTIME, u32);
      u32 = headint32(rpmhead, TAG_INSTALLTIME);
      if (u32)
        repodata_set_num(data, handle, SOLVABLE_INSTALLTIME, u32);
      u64 = headint64(rpmhead, TAG_LONGSIZE);
      if (u64)
        repodata_set_num(data, handle, SOLVABLE_INSTALLSIZE, u64);
      else
	{
	  u32 = headint32(rpmhead, TAG_SIZE);
	  if (u32)
	    repodata_set_num(data, handle, SOLVABLE_INSTALLSIZE, u32);
	}
      if (sourcerpm)
	repodata_set_sourcepkg(data, handle, sourcerpm);
      if ((flags & RPM_ADD_TRIGGERS) != 0)
	{
	  Id id, lastid;
	  unsigned int ida = makedeps(pool, repo, rpmhead, TAG_TRIGGERNAME, TAG_TRIGGERVERSION, TAG_TRIGGERFLAGS, 0);

	  lastid = 0;
	  for (; (id = repo->idarraydata[ida]) != 0; ida++)
	    {
	      /* we currently do not support rel ids in incore data, so
	       * strip off versioning information */
	      while (ISRELDEP(id))
		{
		  Reldep *rd = GETRELDEP(pool, id);
		  id = rd->name;
		}
	      if (id == lastid)
		continue;
	      repodata_add_idarray(data, handle, SOLVABLE_TRIGGERS, id);
	      lastid = id;
	    }
	}
      if ((flags & RPM_ADD_NO_FILELIST) == 0)
	addfilelist(data, handle, rpmhead, flags);
      if ((flags & RPM_ADD_WITH_CHANGELOG) != 0)
	addchangelog(data, handle, rpmhead);
    }
  solv_free(evr);
  return 1;
}


/******************************************************************/
/*  Rpm Database stuff
 */

struct rpmdbstate {
  Pool *pool;
  char *rootdir;

  RpmHead *rpmhead;	/* header storage space */
  int rpmheadsize;

  int dbopened;
  DB_ENV *dbenv;	/* database environment */
  DB *db;		/* packages database */
  int byteswapped;	/* endianess of packages database */
  int is_ostree;	/* read-only db that lives in /usr/share/rpm */
};

struct rpmdbentry {
  Id rpmdbid;
  Id nameoff;
};

#define ENTRIES_BLOCK 255
#define NAMEDATA_BLOCK 1023


static inline Id db2rpmdbid(unsigned char *db, int byteswapped)
{
#ifdef RPM5
  return db[0] << 24 | db[1] << 16 | db[2] << 8 | db[3];
#else
# if defined(WORDS_BIGENDIAN)
  if (!byteswapped)
# else
  if (byteswapped)
# endif
    return db[0] << 24 | db[1] << 16 | db[2] << 8 | db[3];
  else
    return db[3] << 24 | db[2] << 16 | db[1] << 8 | db[0];
#endif
}

static inline void rpmdbid2db(unsigned char *db, Id id, int byteswapped)
{
#ifdef RPM5
  db[0] = id >> 24, db[1] = id >> 16, db[2] = id >> 8, db[3] = id;
#else
# if defined(WORDS_BIGENDIAN)
  if (!byteswapped)
# else
  if (byteswapped)
# endif
    db[0] = id >> 24, db[1] = id >> 16, db[2] = id >> 8, db[3] = id;
  else
    db[3] = id >> 24, db[2] = id >> 16, db[1] = id >> 8, db[0] = id;
#endif
}

#ifdef FEDORA
int
serialize_dbenv_ops(struct rpmdbstate *state)
{
  char lpath[PATH_MAX];
  mode_t oldmask;
  int fd;
  struct flock fl;

  snprintf(lpath, PATH_MAX, "%s/var/lib/rpm/.dbenv.lock", state->rootdir ? state->rootdir : "");
  oldmask = umask(022);
  fd = open(lpath, (O_RDWR|O_CREAT), 0644);
  umask(oldmask);
  if (fd < 0)
    return -1;
  memset(&fl, 0, sizeof(fl));
  fl.l_type = F_WRLCK;
  fl.l_whence = SEEK_SET;
  for (;;)
    {
      if (fcntl(fd, F_SETLKW, &fl) != -1)
	return fd;
      if (errno != EINTR)
	break;
    }
  close(fd);
  return -1;
}
#endif

/* should look in /usr/lib/rpm/macros instead, but we want speed... */
static int
opendbenv(struct rpmdbstate *state)
{
  const char *rootdir = state->rootdir;
  char dbpath[PATH_MAX];
  DB_ENV *dbenv = 0;
  int r;

  if (db_env_create(&dbenv, 0))
    return pool_error(state->pool, 0, "db_env_create: %s", strerror(errno));
#if defined(FEDORA) && (DB_VERSION_MAJOR >= 5 || (DB_VERSION_MAJOR == 4 && DB_VERSION_MINOR >= 5))
  dbenv->set_thread_count(dbenv, 8);
#endif
  snprintf(dbpath, PATH_MAX, "%s/var/lib/rpm", rootdir ? rootdir : "");
  if (access(dbpath, W_OK) == -1)
    {
      snprintf(dbpath, PATH_MAX, "%s/usr/share/rpm/Packages", rootdir ? rootdir : "");
      if (access(dbpath, R_OK) == 0)
	state->is_ostree = 1;
      snprintf(dbpath, PATH_MAX, "%s%s", rootdir ? rootdir : "", state->is_ostree ? "/usr/share/rpm" : "/var/lib/rpm");
      r = dbenv->open(dbenv, dbpath, DB_CREATE|DB_PRIVATE|DB_INIT_MPOOL, 0);
    }
  else
    {
#ifdef FEDORA
      int serialize_fd = serialize_dbenv_ops(state);
      r = dbenv->open(dbenv, dbpath, DB_CREATE|DB_INIT_CDB|DB_INIT_MPOOL, 0644);
      if (serialize_fd >= 0)
	close(serialize_fd);
#else
      r = dbenv->open(dbenv, dbpath, DB_CREATE|DB_PRIVATE|DB_INIT_MPOOL, 0);
#endif
    }
  if (r)
    {
      pool_error(state->pool, 0, "dbenv->open: %s", strerror(errno));
      dbenv->close(dbenv, 0);
      return 0;
    }
  state->dbenv = dbenv;
  return 1;
}

static void
closedbenv(struct rpmdbstate *state)
{
#ifdef FEDORA
  uint32_t eflags = 0;
#endif

  if (!state->dbenv)
    return;
#ifdef FEDORA
  (void)state->dbenv->get_open_flags(state->dbenv, &eflags);
  if (!(eflags & DB_PRIVATE))
    {
      int serialize_fd = serialize_dbenv_ops(state);
      state->dbenv->close(state->dbenv, 0);
      if (serialize_fd >= 0)
	close(serialize_fd);
    }
  else
    state->dbenv->close(state->dbenv, 0);
#else
  state->dbenv->close(state->dbenv, 0);
#endif
  state->dbenv = 0;
}

static int
openpkgdb(struct rpmdbstate *state)
{
  if (state->dbopened)
    return state->dbopened > 0 ? 1 : 0;
  state->dbopened = -1;
  if (!state->dbenv && !opendbenv(state))
    return 0;
  if (db_create(&state->db, state->dbenv, 0))
    {
      pool_error(state->pool, 0, "db_create: %s", strerror(errno));
      state->db = 0;
      closedbenv(state);
      return 0;
    }
  if (state->db->open(state->db, 0, "Packages", 0, DB_UNKNOWN, DB_RDONLY, 0664))
    {
      pool_error(state->pool, 0, "db->open Packages: %s", strerror(errno));
      state->db->close(state->db, 0);
      state->db = 0;
      closedbenv(state);
      return 0;
    }
  if (state->db->get_byteswapped(state->db, &state->byteswapped))
    {
      pool_error(state->pool, 0, "db->get_byteswapped: %s", strerror(errno));
      state->db->close(state->db, 0);
      state->db = 0;
      closedbenv(state);
      return 0;
    }
  state->dbopened = 1;
  return 1;
}

/* get the rpmdbids of all installed packages from the Name index database.
 * This is much faster then querying the big Packages database */
static struct rpmdbentry *
getinstalledrpmdbids(struct rpmdbstate *state, const char *index, const char *match, int *nentriesp, char **namedatap)
{
  DB_ENV *dbenv = 0;
  DB *db = 0;
  DBC *dbc = 0;
  int byteswapped;
  DBT dbkey;
  DBT dbdata;
  unsigned char *dp;
  int dl;
  Id nameoff;

  char *namedata = 0;
  int namedatal = 0;
  struct rpmdbentry *entries = 0;
  int nentries = 0;

  *nentriesp = 0;
  if (namedatap)
    *namedatap = 0;

  if (!state->dbenv && !opendbenv(state))
    return 0;
  dbenv = state->dbenv;
  if (db_create(&db, dbenv, 0))
    {
      pool_error(state->pool, 0, "db_create: %s", strerror(errno));
      return 0;
    }
  if (db->open(db, 0, index, 0, DB_UNKNOWN, DB_RDONLY, 0664))
    {
      pool_error(state->pool, 0, "db->open %s: %s", index, strerror(errno));
      db->close(db, 0);
      return 0;
    }
  if (db->get_byteswapped(db, &byteswapped))
    {
      pool_error(state->pool, 0, "db->get_byteswapped: %s", strerror(errno));
      db->close(db, 0);
      return 0;
    }
  if (db->cursor(db, NULL, &dbc, 0))
    {
      pool_error(state->pool, 0, "db->cursor: %s", strerror(errno));
      db->close(db, 0);
      return 0;
    }
  memset(&dbkey, 0, sizeof(dbkey));
  memset(&dbdata, 0, sizeof(dbdata));
  if (match)
    {
      dbkey.data = (void *)match;
      dbkey.size = strlen(match);
    }
  while (dbc->c_get(dbc, &dbkey, &dbdata, match ? DB_SET : DB_NEXT) == 0)
    {
      if (!match && dbkey.size == 10 && !memcmp(dbkey.data, "gpg-pubkey", 10))
	continue;
      dl = dbdata.size;
      dp = dbdata.data;
      nameoff = namedatal;
      if (namedatap)
	{
	  namedata = solv_extend(namedata, namedatal, dbkey.size + 1, 1, NAMEDATA_BLOCK);
	  memcpy(namedata + namedatal, dbkey.data, dbkey.size);
	  namedata[namedatal + dbkey.size] = 0;
	  namedatal += dbkey.size + 1;
	}
      while(dl >= RPM_INDEX_SIZE)
	{
	  entries = solv_extend(entries, nentries, 1, sizeof(*entries), ENTRIES_BLOCK);
	  entries[nentries].rpmdbid = db2rpmdbid(dp, byteswapped);
	  entries[nentries].nameoff = nameoff;
	  nentries++;
	  dp += RPM_INDEX_SIZE;
	  dl -= RPM_INDEX_SIZE;
	}
      if (match)
	break;
    }
  dbc->c_close(dbc);
  db->close(db, 0);
  /* make sure that enteries is != 0 if there was no error */
  if (!entries)
    entries = solv_extend(entries, 1, 1, sizeof(*entries), ENTRIES_BLOCK);
  *nentriesp = nentries;
  if (namedatap)
    *namedatap = namedata;
  return entries;
}

/* retrive header by rpmdbid */
static int
getrpmdbid(struct rpmdbstate *state, Id rpmdbid)
{
  unsigned char buf[16];
  DBT dbkey;
  DBT dbdata;
  RpmHead *rpmhead;

  if (!rpmdbid)
    {
      pool_error(state->pool, 0, "illegal rpmdbid");
      return -1;
    }
  if (state->dbopened != 1 && !openpkgdb(state))
    return -1;
  rpmdbid2db(buf, rpmdbid, state->byteswapped);
  memset(&dbkey, 0, sizeof(dbkey));
  memset(&dbdata, 0, sizeof(dbdata));
  dbkey.data = buf;
  dbkey.size = 4;
  dbdata.data = 0;
  dbdata.size = 0;
  if (state->db->get(state->db, NULL, &dbkey, &dbdata, 0))
    return 0;
  if (dbdata.size < 8)
    {
      pool_error(state->pool, 0, "corrupt rpm database (size)");
      return -1;
    }
  if (dbdata.size > state->rpmheadsize)
    {
      state->rpmheadsize = dbdata.size + 128;
      state->rpmhead = solv_realloc(state->rpmhead, sizeof(*rpmhead) + state->rpmheadsize);
    }
  rpmhead = state->rpmhead;
  memcpy(buf, dbdata.data, 8);
  rpmhead->forcebinary = 1;
  rpmhead->cnt = buf[0] << 24  | buf[1] << 16  | buf[2] << 8 | buf[3];
  rpmhead->dcnt = buf[4] << 24  | buf[5] << 16  | buf[6] << 8 | buf[7];
  if (8 + rpmhead->cnt * 16 + rpmhead->dcnt > dbdata.size)
    {
      pool_error(state->pool, 0, "corrupt rpm database (data size)");
      return -1;
    }
  memcpy(rpmhead->data, (unsigned char *)dbdata.data + 8, rpmhead->cnt * 16 + rpmhead->dcnt);
  rpmhead->dp = rpmhead->data + rpmhead->cnt * 16;
  return 1;
}

/* retrive header by berkeleydb cursor */
static Id
getrpmcursor(struct rpmdbstate *state, DBC *dbc)
{
  unsigned char buf[16];
  DBT dbkey;
  DBT dbdata;
  RpmHead *rpmhead;
  Id dbid;

  memset(&dbkey, 0, sizeof(dbkey));
  memset(&dbdata, 0, sizeof(dbdata));
  while (dbc->c_get(dbc, &dbkey, &dbdata, DB_NEXT) == 0)
    {
      if (dbkey.size != 4)
	return pool_error(state->pool, -1, "corrupt Packages database (key size)");
      dbid = db2rpmdbid(dbkey.data, state->byteswapped);
      if (dbid == 0)		/* the join key */
	continue;
      if (dbdata.size < 8)
	return pool_error(state->pool, -1, "corrupt rpm database (size %u)\n", dbdata.size);
      if (dbdata.size > state->rpmheadsize)
	{
	  state->rpmheadsize = dbdata.size + 128;
	  state->rpmhead = solv_realloc(state->rpmhead, sizeof(*state->rpmhead) + state->rpmheadsize);
	}
      rpmhead = state->rpmhead;
      memcpy(buf, dbdata.data, 8);
      rpmhead->forcebinary = 1;
      rpmhead->cnt = buf[0] << 24  | buf[1] << 16  | buf[2] << 8 | buf[3];
      rpmhead->dcnt = buf[4] << 24  | buf[5] << 16  | buf[6] << 8 | buf[7];
      if (8 + rpmhead->cnt * 16 + rpmhead->dcnt > dbdata.size)
	return pool_error(state->pool, -1, "corrupt rpm database (data size)\n");
      memcpy(rpmhead->data, (unsigned char *)dbdata.data + 8, rpmhead->cnt * 16 + rpmhead->dcnt);
      rpmhead->dp = rpmhead->data + rpmhead->cnt * 16;
      return dbid;
    }
  return 0;
}

static void
freestate(struct rpmdbstate *state)
{
  /* close down */
  if (!state)
    return;
  if (state->db)
    state->db->close(state->db, 0);
  if (state->dbenv)
    closedbenv(state);
  if (state->rootdir)
    solv_free(state->rootdir);
  solv_free(state->rpmhead);
}

void *
rpm_state_create(Pool *pool, const char *rootdir)
{
  struct rpmdbstate *state;
  state = solv_calloc(1, sizeof(*state));
  state->pool = pool;
  if (rootdir)
    state->rootdir = solv_strdup(rootdir);
  return state;
}

void *
rpm_state_free(void *state)
{
  freestate(state);
  return solv_free(state);
}

static int
count_headers(struct rpmdbstate *state)
{
  Pool *pool = state->pool;
  char dbpath[PATH_MAX];
  struct stat statbuf;
  DB *db = 0;
  DBC *dbc = 0;
  int count = 0;
  DBT dbkey;
  DBT dbdata;

  snprintf(dbpath, PATH_MAX, "%s%s/Name", state->rootdir ? state->rootdir : "", state->is_ostree ? "/usr/share/rpm" : "/var/lib/rpm");
  if (stat(dbpath, &statbuf))
    return 0;
  memset(&dbkey, 0, sizeof(dbkey));
  memset(&dbdata, 0, sizeof(dbdata));
  if (db_create(&db, state->dbenv, 0))
    {
      pool_error(pool, 0, "db_create: %s", strerror(errno));
      return 0;
    }
  if (db->open(db, 0, "Name", 0, DB_UNKNOWN, DB_RDONLY, 0664))
    {
      pool_error(pool, 0, "db->open Name: %s", strerror(errno));
      db->close(db, 0);
      return 0;
    }
  if (db->cursor(db, NULL, &dbc, 0))
    {
      db->close(db, 0);
      pool_error(pool, 0, "db->cursor: %s", strerror(errno));
      return 0;
    }
  while (dbc->c_get(dbc, &dbkey, &dbdata, DB_NEXT) == 0)
    count += dbdata.size / RPM_INDEX_SIZE;
  dbc->c_close(dbc);
  db->close(db, 0);
  return count;
}

/******************************************************************/

static Offset
copydeps(Pool *pool, Repo *repo, Offset fromoff, Repo *fromrepo)
{
  int cc;
  Id *ida, *from;
  Offset ido;

  if (!fromoff)
    return 0;
  from = fromrepo->idarraydata + fromoff;
  for (ida = from, cc = 0; *ida; ida++, cc++)
    ;
  if (cc == 0)
    return 0;
  ido = repo_reserve_ids(repo, 0, cc);
  ida = repo->idarraydata + ido;
  memcpy(ida, from, (cc + 1) * sizeof(Id));
  repo->idarraysize += cc + 1;
  return ido;
}

#define COPYDIR_DIRCACHE_SIZE 512

static Id copydir_complex(Pool *pool, Repodata *data, Repodata *fromdata, Id did, Id *cache);

static inline Id
copydir(Pool *pool, Repodata *data, Repodata *fromdata, Id did, Id *cache)
{
  if (cache && cache[did & 255] == did)
    return cache[(did & 255) + 256];
  return copydir_complex(pool, data, fromdata, did, cache);
}

static Id
copydir_complex(Pool *pool, Repodata *data, Repodata *fromdata, Id did, Id *cache)
{
  Id parent = dirpool_parent(&fromdata->dirpool, did);
  Id compid = dirpool_compid(&fromdata->dirpool, did);
  if (parent)
    parent = copydir(pool, data, fromdata, parent, cache);
  if (data->localpool || fromdata->localpool)
    compid = repodata_translate_id(data, fromdata, compid, 1);
  compid = dirpool_add_dir(&data->dirpool, parent, compid, 1);
  if (cache)
    {
      cache[did & 255] = did;
      cache[(did & 255) + 256] = compid;
    }
  return compid;
}

struct solvable_copy_cbdata {
  Repodata *data;
  Id handle;
  Id subhandle;
  Id *dircache;
};

static int
solvable_copy_cb(void *vcbdata, Solvable *r, Repodata *fromdata, Repokey *key, KeyValue *kv)
{
  struct solvable_copy_cbdata *cbdata = vcbdata;
  Id id, keyname;
  Repodata *data = cbdata->data;
  Id handle = cbdata->handle;
  Pool *pool = data->repo->pool;

  keyname = key->name;
  switch(key->type)
    {
    case REPOKEY_TYPE_ID:
    case REPOKEY_TYPE_CONSTANTID:
    case REPOKEY_TYPE_IDARRAY:	/* used for triggers */
      id = kv->id;
      if (data->localpool || fromdata->localpool)
	id = repodata_translate_id(data, fromdata, id, 1);
      if (key->type == REPOKEY_TYPE_ID)
        repodata_set_id(data, handle, keyname, id);
      else if (key->type == REPOKEY_TYPE_CONSTANTID)
        repodata_set_constantid(data, handle, keyname, id);
      else
        repodata_add_idarray(data, handle, keyname, id);
      break;
    case REPOKEY_TYPE_STR:
      repodata_set_str(data, handle, keyname, kv->str);
      break;
    case REPOKEY_TYPE_VOID:
      repodata_set_void(data, handle, keyname);
      break;
    case REPOKEY_TYPE_NUM:
      repodata_set_num(data, handle, keyname, SOLV_KV_NUM64(kv));
      break;
    case REPOKEY_TYPE_CONSTANT:
      repodata_set_constant(data, handle, keyname, kv->num);
      break;
    case REPOKEY_TYPE_DIRNUMNUMARRAY:
      id = kv->id;
      id = copydir(pool, data, fromdata, id, cbdata->dircache);
      repodata_add_dirnumnum(data, handle, keyname, id, kv->num, kv->num2);
      break;
    case REPOKEY_TYPE_DIRSTRARRAY:
      id = kv->id;
      id = copydir(pool, data, fromdata, id, cbdata->dircache);
      repodata_add_dirstr(data, handle, keyname, id, kv->str);
      break;
    case REPOKEY_TYPE_FLEXARRAY:
      if (kv->eof == 2)
	{
	  assert(cbdata->subhandle);
	  cbdata->handle = cbdata->subhandle;
	  cbdata->subhandle = 0;
	  break;
	}
      if (!kv->entry)
        {
	  assert(!cbdata->subhandle);
	  cbdata->subhandle = cbdata->handle;
	}
      cbdata->handle = repodata_new_handle(data);
      repodata_add_flexarray(data, cbdata->subhandle, keyname, cbdata->handle);
      break;
    default:
      if (solv_chksum_len(key->type))
	{
	  repodata_set_bin_checksum(data, handle, keyname, key->type, (const unsigned char *)kv->str);
	  break;
	}
      break;
    }
  return 0;
}

static void
solvable_copy(Solvable *s, Solvable *r, Repodata *data, Id *dircache)
{
  int p, i;
  Repo *repo = s->repo;
  Pool *pool = repo->pool;
  Repo *fromrepo = r->repo;
  struct solvable_copy_cbdata cbdata;

  /* copy solvable data */
  s->name = r->name;
  s->evr = r->evr;
  s->arch = r->arch;
  s->vendor = r->vendor;
  s->provides = copydeps(pool, repo, r->provides, fromrepo);
  s->requires = copydeps(pool, repo, r->requires, fromrepo);
  s->conflicts = copydeps(pool, repo, r->conflicts, fromrepo);
  s->obsoletes = copydeps(pool, repo, r->obsoletes, fromrepo);
  s->recommends = copydeps(pool, repo, r->recommends, fromrepo);
  s->suggests = copydeps(pool, repo, r->suggests, fromrepo);
  s->supplements = copydeps(pool, repo, r->supplements, fromrepo);
  s->enhances  = copydeps(pool, repo, r->enhances, fromrepo);

  /* copy all attributes */
  if (!data)
    return;
  cbdata.data = data;
  cbdata.handle = s - pool->solvables;
  cbdata.subhandle = 0;
  cbdata.dircache = dircache;
  p = r - fromrepo->pool->solvables;
#if 0
  repo_search(fromrepo, p, 0, 0, SEARCH_NO_STORAGE_SOLVABLE | SEARCH_SUB | SEARCH_ARRAYSENTINEL, solvable_copy_cb, &cbdata);
#else
  FOR_REPODATAS(fromrepo, i, data)
    {
      if (p >= data->start && p < data->end)
        repodata_search(data, p, 0, SEARCH_SUB | SEARCH_ARRAYSENTINEL, solvable_copy_cb, &cbdata);
      cbdata.dircache = 0;	/* only for first repodata */
    }
#endif
}

/* used to sort entries by package name that got returned in some database order */
static int
rpmids_sort_cmp(const void *va, const void *vb, void *dp)
{
  struct rpmdbentry const *a = va, *b = vb;
  char *namedata = dp;
  int r;
  r = strcmp(namedata + a->nameoff, namedata + b->nameoff);
  if (r)
    return r;
  return a->rpmdbid - b->rpmdbid;
}

static int
pkgids_sort_cmp(const void *va, const void *vb, void *dp)
{
  Repo *repo = dp;
  Pool *pool = repo->pool;
  Solvable *a = pool->solvables + *(Id *)va;
  Solvable *b = pool->solvables + *(Id *)vb;
  Id *rpmdbid;

  if (a->name != b->name)
    return strcmp(pool_id2str(pool, a->name), pool_id2str(pool, b->name));
  rpmdbid = repo->rpmdbid;
  return rpmdbid[(a - pool->solvables) - repo->start] - rpmdbid[(b - pool->solvables) - repo->start];
}

static void
swap_solvables(Repo *repo, Repodata *data, Id pa, Id pb)
{
  Pool *pool = repo->pool;
  Solvable tmp;

  tmp = pool->solvables[pa];
  pool->solvables[pa] = pool->solvables[pb];
  pool->solvables[pb] = tmp;
  if (repo->rpmdbid)
    {
      Id tmpid = repo->rpmdbid[pa - repo->start];
      repo->rpmdbid[pa - repo->start] = repo->rpmdbid[pb - repo->start];
      repo->rpmdbid[pb - repo->start] = tmpid;
    }
  /* only works if nothing is already internalized! */
  if (data)
    repodata_swap_attrs(data, pa, pb);
}

static void
mkrpmdbcookie(struct stat *st, unsigned char *cookie, int flags)
{
  int f = 0;
  memset(cookie, 0, 32);
  cookie[3] = RPMDB_COOKIE_VERSION;
  memcpy(cookie + 16, &st->st_ino, sizeof(st->st_ino));
  memcpy(cookie + 24, &st->st_dev, sizeof(st->st_dev));
  if ((flags & RPM_ADD_WITH_PKGID) != 0)
    f |= 1;
  if ((flags & RPM_ADD_WITH_HDRID) != 0)
    f |= 2;
  if ((flags & RPM_ADD_WITH_CHANGELOG) != 0)
    f |= 4;
  if ((flags & RPM_ADD_NO_FILELIST) == 0)
    f |= 8;
  if ((flags & RPM_ADD_NO_RPMLIBREQS) != 0)
    cookie[1] = 1;
  cookie[0] = f;
}

/*
 * read rpm db as repo
 *
 */

int
repo_add_rpmdb(Repo *repo, Repo *ref, int flags)
{
  Pool *pool = repo->pool;
  char dbpath[PATH_MAX];
  struct stat packagesstat;
  unsigned char newcookie[32];
  const unsigned char *oldcookie = 0;
  Id oldcookietype = 0;
  Repodata *data;
  int count = 0, done = 0;
  struct rpmdbstate state;
  int i;
  Solvable *s;
  unsigned int now;

  now = solv_timems(0);
  memset(&state, 0, sizeof(state));
  state.pool = pool;
  if (flags & REPO_USE_ROOTDIR)
    state.rootdir = solv_strdup(pool_get_rootdir(pool));

  data = repo_add_repodata(repo, flags);

  if (ref && !(ref->nsolvables && ref->rpmdbid && ref->pool == repo->pool))
    {
      if ((flags & RPMDB_EMPTY_REFREPO) != 0)
	repo_empty(ref, 1);
      ref = 0;
    }

  if (!opendbenv(&state))
    {
      solv_free(state.rootdir);
      return -1;
    }

  /* XXX: should get ro lock of Packages database! */
  snprintf(dbpath, PATH_MAX, "%s%s/Packages", state.rootdir ? state.rootdir : "", state.is_ostree ? "/usr/share/rpm" : "/var/lib/rpm");
  if (stat(dbpath, &packagesstat))
    {
      pool_error(pool, -1, "%s: %s", dbpath, strerror(errno));
      freestate(&state);
      return -1;
    }
  mkrpmdbcookie(&packagesstat, newcookie, flags);
  repodata_set_bin_checksum(data, SOLVID_META, REPOSITORY_RPMDBCOOKIE, REPOKEY_TYPE_SHA256, newcookie);

  if (ref)
    oldcookie = repo_lookup_bin_checksum(ref, SOLVID_META, REPOSITORY_RPMDBCOOKIE, &oldcookietype);
  if (!ref || !oldcookie || oldcookietype != REPOKEY_TYPE_SHA256 || memcmp(oldcookie, newcookie, 32) != 0)
    {
      int solvstart = 0, solvend = 0;
      Id dbid;
      DBC *dbc = 0;

      if (ref && (flags & RPMDB_EMPTY_REFREPO) != 0)
	repo_empty(ref, 1);	/* get it out of the way */
      if ((flags & RPMDB_REPORT_PROGRESS) != 0)
	count = count_headers(&state);
      if (!openpkgdb(&state))
	{
	  freestate(&state);
	  return -1;
	}
      if (state.db->cursor(state.db, NULL, &dbc, 0))
	{
	  freestate(&state);
	  return pool_error(pool, -1, "db->cursor failed");
	}
      i = 0;
      s = 0;
      while ((dbid = getrpmcursor(&state, dbc)) != 0)
	{
	  if (dbid == -1)
	    {
	      dbc->c_close(dbc);
	      freestate(&state);
	      return -1;
	    }
	  if (!s)
	    {
	      s = pool_id2solvable(pool, repo_add_solvable(repo));
	      if (!solvstart)
		solvstart = s - pool->solvables;
	      solvend = s - pool->solvables + 1;
	    }
	  if (!repo->rpmdbid)
	    repo->rpmdbid = repo_sidedata_create(repo, sizeof(Id));
	  repo->rpmdbid[(s - pool->solvables) - repo->start] = dbid;
	  if (rpm2solv(pool, repo, data, s, state.rpmhead, flags | RPM_ADD_TRIGGERS))
	    {
	      i++;
	      s = 0;
	    }
	  else
	    {
	      /* We can reuse this solvable, but make sure it's still
		 associated with this repo.  */
	      memset(s, 0, sizeof(*s));
	      s->repo = repo;
	    }
	  if ((flags & RPMDB_REPORT_PROGRESS) != 0)
	    {
	      if (done < count)
	        done++;
	      if (done < count && (done - 1) * 100 / count != done * 100 / count)
	        pool_debug(pool, SOLV_ERROR, "%%%% %d\n", done * 100 / count);
	    }
	}
      dbc->c_close(dbc);
      if (s)
	{
	  /* oops, could not reuse. free it instead */
          repo_free_solvable(repo, s - pool->solvables, 1);
	  solvend--;
	  s = 0;
	}
      /* now sort all solvables in the new solvstart..solvend block */
      if (solvend - solvstart > 1)
	{
	  Id *pkgids = solv_malloc2(solvend - solvstart, sizeof(Id));
	  for (i = solvstart; i < solvend; i++)
	    pkgids[i - solvstart] = i;
	  solv_sort(pkgids, solvend - solvstart, sizeof(Id), pkgids_sort_cmp, repo);
	  /* adapt order */
	  for (i = solvstart; i < solvend; i++)
	    {
	      int j = pkgids[i - solvstart];
	      while (j < i)
		j = pkgids[i - solvstart] = pkgids[j - solvstart];
	      if (j != i)
	        swap_solvables(repo, data, i, j);
	    }
	  solv_free(pkgids);
	}
    }
  else
    {
      Id dircache[COPYDIR_DIRCACHE_SIZE];		/* see copydir */
      struct rpmdbentry *entries = 0, *rp;
      int nentries = 0;
      char *namedata = 0;
      unsigned int refmask, h;
      Id id, *refhash;
      int res;

      memset(dircache, 0, sizeof(dircache));

      /* get ids of installed rpms */
      entries = getinstalledrpmdbids(&state, "Name", 0, &nentries, &namedata);
      if (!entries)
	{
	  freestate(&state);
	  return -1;
	}

      /* sort by name */
      if (nentries > 1)
        solv_sort(entries, nentries, sizeof(*entries), rpmids_sort_cmp, namedata);

      /* create hash from dbid to ref */
      refmask = mkmask(ref->nsolvables);
      refhash = solv_calloc(refmask + 1, sizeof(Id));
      for (i = 0; i < ref->end - ref->start; i++)
	{
	  if (!ref->rpmdbid[i])
	    continue;
	  h = ref->rpmdbid[i] & refmask;
	  while (refhash[h])
	    h = (h + 317) & refmask;
	  refhash[h] = i + 1;	/* make it non-zero */
	}

      /* count the misses, they will cost us time */
      if ((flags & RPMDB_REPORT_PROGRESS) != 0)
        {
	  for (i = 0, rp = entries; i < nentries; i++, rp++)
	    {
	      if (refhash)
		{
		  Id dbid = rp->rpmdbid;
		  h = dbid & refmask;
		  while ((id = refhash[h]))
		    {
		      if (ref->rpmdbid[id - 1] == dbid)
			break;
		      h = (h + 317) & refmask;
		    }
		  if (id)
		    continue;
		}
	      count++;
	    }
        }

      if (ref && (flags & RPMDB_EMPTY_REFREPO) != 0)
        s = pool_id2solvable(pool, repo_add_solvable_block_before(repo, nentries, ref));
      else
        s = pool_id2solvable(pool, repo_add_solvable_block(repo, nentries));
      if (!repo->rpmdbid)
        repo->rpmdbid = repo_sidedata_create(repo, sizeof(Id));

      for (i = 0, rp = entries; i < nentries; i++, rp++, s++)
	{
	  Id dbid = rp->rpmdbid;
	  repo->rpmdbid[(s - pool->solvables) - repo->start] = rp->rpmdbid;
	  if (refhash)
	    {
	      h = dbid & refmask;
	      while ((id = refhash[h]))
		{
		  if (ref->rpmdbid[id - 1] == dbid)
		    break;
		  h = (h + 317) & refmask;
		}
	      if (id)
		{
		  Solvable *r = ref->pool->solvables + ref->start + (id - 1);
		  if (r->repo == ref)
		    {
		      solvable_copy(s, r, data, dircache);
		      continue;
		    }
		}
	    }
	  res = getrpmdbid(&state, dbid);
	  if (res <= 0)
	    {
	      if (!res)
	        pool_error(pool, -1, "inconsistent rpm database, key %d not found. run 'rpm --rebuilddb' to fix.", dbid);
	      freestate(&state);
	      solv_free(entries);
	      solv_free(namedata);
	      solv_free(refhash);
	      return -1;
	    }
	  rpm2solv(pool, repo, data, s, state.rpmhead, flags | RPM_ADD_TRIGGERS);
	  if ((flags & RPMDB_REPORT_PROGRESS) != 0)
	    {
	      if (done < count)
		done++;
	      if (done < count && (done - 1) * 100 / count != done * 100 / count)
		pool_debug(pool, SOLV_ERROR, "%%%% %d\n", done * 100 / count);
	    }
	}

      solv_free(entries);
      solv_free(namedata);
      solv_free(refhash);
      if (ref && (flags & RPMDB_EMPTY_REFREPO) != 0)
	repo_empty(ref, 1);
    }

  freestate(&state);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  if ((flags & RPMDB_REPORT_PROGRESS) != 0)
    pool_debug(pool, SOLV_ERROR, "%%%% 100\n");
  POOL_DEBUG(SOLV_DEBUG_STATS, "repo_add_rpmdb took %d ms\n", solv_timems(now));
  POOL_DEBUG(SOLV_DEBUG_STATS, "repo size: %d solvables\n", repo->nsolvables);
  POOL_DEBUG(SOLV_DEBUG_STATS, "repo memory used: %d K incore, %d K idarray\n", repodata_memused(data)/1024, repo->idarraysize / (int)(1024/sizeof(Id)));
  return 0;
}

int
repo_add_rpmdb_reffp(Repo *repo, FILE *fp, int flags)
{
  int res;
  Repo *ref = 0;

  if (!fp)
    return repo_add_rpmdb(repo, 0, flags);
  ref = repo_create(repo->pool, "add_rpmdb_reffp");
  if (repo_add_solv(ref, fp, 0) != 0)
    {
      repo_free(ref, 1);
      ref = 0;
    }
  if (ref && ref->start == ref->end)
    {
      repo_free(ref, 1);
      ref = 0;
    }
  if (ref)
    repo_disable_paging(ref);
  res = repo_add_rpmdb(repo, ref, flags | RPMDB_EMPTY_REFREPO);
  if (ref)
    repo_free(ref, 1);
  return res;
}

static inline unsigned int
getu32(const unsigned char *dp)
{
  return dp[0] << 24 | dp[1] << 16 | dp[2] << 8 | dp[3];
}


Id
repo_add_rpm(Repo *repo, const char *rpm, int flags)
{
  unsigned int sigdsize, sigcnt, l;
  Pool *pool = repo->pool;
  Solvable *s;
  RpmHead *rpmhead = 0;
  int rpmheadsize = 0;
  char *payloadformat;
  FILE *fp;
  unsigned char lead[4096];
  int headerstart, headerend;
  struct stat stb;
  Repodata *data;
  unsigned char pkgid[16];
  unsigned char leadsigid[16];
  unsigned char hdrid[32];
  int pkgidtype, leadsigidtype, hdridtype;
  Id chksumtype = 0;
  Chksum *chksumh = 0;
  Chksum *leadsigchksumh = 0;
  int forcebinary = 0;

  data = repo_add_repodata(repo, flags);

  if ((flags & RPM_ADD_WITH_SHA256SUM) != 0)
    chksumtype = REPOKEY_TYPE_SHA256;
  else if ((flags & RPM_ADD_WITH_SHA1SUM) != 0)
    chksumtype = REPOKEY_TYPE_SHA1;

  if ((fp = fopen(flags & REPO_USE_ROOTDIR ? pool_prepend_rootdir_tmp(pool, rpm) : rpm, "r")) == 0)
    {
      pool_error(pool, -1, "%s: %s", rpm, strerror(errno));
      return 0;
    }
  if (fstat(fileno(fp), &stb))
    {
      pool_error(pool, -1, "fstat: %s", strerror(errno));
      fclose(fp);
      return 0;
    }
  if (chksumtype)
    chksumh = solv_chksum_create(chksumtype);
  if ((flags & RPM_ADD_WITH_LEADSIGID) != 0)
    leadsigchksumh = solv_chksum_create(REPOKEY_TYPE_MD5);
  if (fread(lead, 96 + 16, 1, fp) != 1 || getu32(lead) != 0xedabeedb)
    {
      pool_error(pool, -1, "%s: not a rpm", rpm);
      fclose(fp);
      return 0;
    }
  forcebinary = lead[6] != 0 || lead[7] != 1;
  if (chksumh)
    solv_chksum_add(chksumh, lead, 96 + 16);
  if (leadsigchksumh)
    solv_chksum_add(leadsigchksumh, lead, 96 + 16);
  if (lead[78] != 0 || lead[79] != 5)
    {
      pool_error(pool, -1, "%s: not a rpm v5 header", rpm);
      fclose(fp);
      return 0;
    }
  if (getu32(lead + 96) != 0x8eade801)
    {
      pool_error(pool, -1, "%s: bad signature header", rpm);
      fclose(fp);
      return 0;
    }
  sigcnt = getu32(lead + 96 + 8);
  sigdsize = getu32(lead + 96 + 12);
  if (sigcnt >= 0x100000 || sigdsize >= 0x100000)
    {
      pool_error(pool, -1, "%s: bad signature header", rpm);
      fclose(fp);
      return 0;
    }
  sigdsize += sigcnt * 16;
  sigdsize = (sigdsize + 7) & ~7;
  headerstart = 96 + 16 + sigdsize;
  pkgidtype = leadsigidtype = hdridtype = 0;
  if ((flags & (RPM_ADD_WITH_PKGID | RPM_ADD_WITH_HDRID)) != 0)
    {
      /* extract pkgid or hdrid from the signature header */
      if (sigdsize > rpmheadsize)
	{
	  rpmheadsize = sigdsize + 128;
	  rpmhead = solv_realloc(rpmhead, sizeof(*rpmhead) + rpmheadsize);
	}
      if (fread(rpmhead->data, sigdsize, 1, fp) != 1)
	{
	  pool_error(pool, -1, "%s: unexpected EOF", rpm);
	  fclose(fp);
	  return 0;
	}
      if (chksumh)
	solv_chksum_add(chksumh, rpmhead->data, sigdsize);
      if (leadsigchksumh)
	solv_chksum_add(leadsigchksumh, rpmhead->data, sigdsize);
      rpmhead->forcebinary = 0;
      rpmhead->cnt = sigcnt;
      rpmhead->dcnt = sigdsize - sigcnt * 16;
      rpmhead->dp = rpmhead->data + rpmhead->cnt * 16;
      if ((flags & RPM_ADD_WITH_PKGID) != 0)
	{
	  unsigned char *chksum;
	  unsigned int chksumsize;
	  chksum = headbinary(rpmhead, SIGTAG_MD5, &chksumsize);
	  if (chksum && chksumsize == 16)
	    {
	      pkgidtype = REPOKEY_TYPE_MD5;
	      memcpy(pkgid, chksum, 16);
	    }
	}
      if ((flags & RPM_ADD_WITH_HDRID) != 0)
	{
	  const char *str = headstring(rpmhead, TAG_SHA1HEADER);
	  if (str && strlen(str) == 40)
	    {
	      if (solv_hex2bin(&str, hdrid, 20) == 20)
	        hdridtype = REPOKEY_TYPE_SHA1;
	    }
	  else if (str && strlen(str) == 64)
	    {
	      if (solv_hex2bin(&str, hdrid, 32) == 32)
	        hdridtype = REPOKEY_TYPE_SHA256;
	    }
	}
    }
  else
    {
      /* just skip the signature header */
      while (sigdsize)
	{
	  l = sigdsize > 4096 ? 4096 : sigdsize;
	  if (fread(lead, l, 1, fp) != 1)
	    {
	      pool_error(pool, -1, "%s: unexpected EOF", rpm);
	      fclose(fp);
	      return 0;
	    }
	  if (chksumh)
	    solv_chksum_add(chksumh, lead, l);
	  if (leadsigchksumh)
	    solv_chksum_add(leadsigchksumh, lead, l);
	  sigdsize -= l;
	}
    }
  if (leadsigchksumh)
    {
      leadsigchksumh = solv_chksum_free(leadsigchksumh, leadsigid);
      leadsigidtype = REPOKEY_TYPE_MD5;
    }
  if (fread(lead, 16, 1, fp) != 1)
    {
      pool_error(pool, -1, "%s: unexpected EOF", rpm);
      fclose(fp);
      return 0;
    }
  if (chksumh)
    solv_chksum_add(chksumh, lead, 16);
  if (getu32(lead) != 0x8eade801)
    {
      pool_error(pool, -1, "%s: bad header", rpm);
      fclose(fp);
      return 0;
    }
  sigcnt = getu32(lead + 8);
  sigdsize = getu32(lead + 12);
  if (sigcnt >= 0x100000 || sigdsize >= 0x2000000)
    {
      pool_error(pool, -1, "%s: bad header", rpm);
      fclose(fp);
      return 0;
    }
  l = sigdsize + sigcnt * 16;
  headerend = headerstart + 16 + l;
  if (l > rpmheadsize)
    {
      rpmheadsize = l + 128;
      rpmhead = solv_realloc(rpmhead, sizeof(*rpmhead) + rpmheadsize);
    }
  if (fread(rpmhead->data, l, 1, fp) != 1)
    {
      pool_error(pool, -1, "%s: unexpected EOF", rpm);
      fclose(fp);
      return 0;
    }
  if (chksumh)
    solv_chksum_add(chksumh, rpmhead->data, l);
  rpmhead->forcebinary = forcebinary;
  rpmhead->cnt = sigcnt;
  rpmhead->dcnt = sigdsize;
  rpmhead->dp = rpmhead->data + rpmhead->cnt * 16;
  if (headexists(rpmhead, TAG_PATCHESNAME))
    {
      /* this is a patch rpm, ignore */
      pool_error(pool, -1, "%s: is patch rpm", rpm);
      fclose(fp);
      solv_chksum_free(chksumh, 0);
      solv_free(rpmhead);
      return 0;
    }
  payloadformat = headstring(rpmhead, TAG_PAYLOADFORMAT);
  if (payloadformat && !strcmp(payloadformat, "drpm"))
    {
      /* this is a delta rpm */
      pool_error(pool, -1, "%s: is delta rpm", rpm);
      fclose(fp);
      solv_chksum_free(chksumh, 0);
      solv_free(rpmhead);
      return 0;
    }
  if (chksumh)
    while ((l = fread(lead, 1, sizeof(lead), fp)) > 0)
      solv_chksum_add(chksumh, lead, l);
  fclose(fp);
  s = pool_id2solvable(pool, repo_add_solvable(repo));
  if (!rpm2solv(pool, repo, data, s, rpmhead, flags & ~(RPM_ADD_WITH_HDRID | RPM_ADD_WITH_PKGID)))
    {
      repo_free_solvable(repo, s - pool->solvables, 1);
      solv_chksum_free(chksumh, 0);
      solv_free(rpmhead);
      return 0;
    }
  if (!(flags & REPO_NO_LOCATION))
    repodata_set_location(data, s - pool->solvables, 0, 0, rpm);
  if (S_ISREG(stb.st_mode))
    repodata_set_num(data, s - pool->solvables, SOLVABLE_DOWNLOADSIZE, (unsigned long long)stb.st_size);
  repodata_set_num(data, s - pool->solvables, SOLVABLE_HEADEREND, headerend);
  if (pkgidtype)
    repodata_set_bin_checksum(data, s - pool->solvables, SOLVABLE_PKGID, pkgidtype, pkgid);
  if (hdridtype)
    repodata_set_bin_checksum(data, s - pool->solvables, SOLVABLE_HDRID, hdridtype, hdrid);
  if (leadsigidtype)
    repodata_set_bin_checksum(data, s - pool->solvables, SOLVABLE_LEADSIGID, leadsigidtype, leadsigid);
  if (chksumh)
    {
      repodata_set_bin_checksum(data, s - pool->solvables, SOLVABLE_CHECKSUM, chksumtype, solv_chksum_get(chksumh, 0));
      chksumh = solv_chksum_free(chksumh, 0);
    }
  solv_free(rpmhead);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return s - pool->solvables;
}

Id
repo_add_rpm_handle(Repo *repo, void *rpmhandle, int flags)
{
  Pool *pool = repo->pool;
  Repodata *data;
  RpmHead *rpmhead = rpmhandle;
  Solvable *s;
  char *payloadformat;

  data = repo_add_repodata(repo, flags);
  if (headexists(rpmhead, TAG_PATCHESNAME))
    {
      pool_error(pool, -1, "is a patch rpm");
      return 0;
    }
  payloadformat = headstring(rpmhead, TAG_PAYLOADFORMAT);
  if (payloadformat && !strcmp(payloadformat, "drpm"))
    {
      /* this is a delta rpm */
      pool_error(pool, -1, "is a delta rpm");
      return 0;
    }
  s = pool_id2solvable(pool, repo_add_solvable(repo));
  if (!rpm2solv(pool, repo, data, s, rpmhead, flags))
    {
      repo_free_solvable(repo, s - pool->solvables, 1);
      return 0;
    }
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return s - pool->solvables;
}

static inline void
linkhash(const char *lt, char *hash)
{
  unsigned int r = 0;
  const unsigned char *str = (const unsigned char *)lt;
  int l, c;

  l = strlen(lt);
  while ((c = *str++) != 0)
    r += (r << 3) + c;
  sprintf(hash, "%08x%08x%08x%08x", r, l, 0, 0);
}

void
rpm_iterate_filelist(void *rpmhandle, int flags, void (*cb)(void *, const char *, struct filelistinfo *), void *cbdata)
{
  RpmHead *rpmhead = rpmhandle;
  char **bn;
  char **dn;
  char **md = 0;
  char **lt = 0;
  unsigned int *di, diidx;
  unsigned int *co = 0;
  unsigned int *ff = 0;
  unsigned int lastdir;
  int lastdirl;
  unsigned int *fm;
  int cnt, dcnt, cnt2;
  int i, l1, l;
  char *space = 0;
  int spacen = 0;
  char md5[33];
  struct filelistinfo info;

  dn = headstringarray(rpmhead, TAG_DIRNAMES, &dcnt);
  if (!dn)
    return;
  if ((flags & RPM_ITERATE_FILELIST_ONLYDIRS) != 0)
    {
      for (i = 0; i < dcnt; i++)
	(*cb)(cbdata, dn[i], 0);
      solv_free(dn);
      return;
    }
  bn = headstringarray(rpmhead, TAG_BASENAMES, &cnt);
  if (!bn)
    {
      solv_free(dn);
      return;
    }
  di = headint32array(rpmhead, TAG_DIRINDEXES, &cnt2);
  if (!di || cnt != cnt2)
    {
      solv_free(di);
      solv_free(bn);
      solv_free(dn);
      return;
    }
  fm = headint16array(rpmhead, TAG_FILEMODES, &cnt2);
  if (!fm || cnt != cnt2)
    {
      solv_free(fm);
      solv_free(di);
      solv_free(bn);
      solv_free(dn);
      return;
    }
  if ((flags & RPM_ITERATE_FILELIST_WITHMD5) != 0)
    {
      md = headstringarray(rpmhead, TAG_FILEMD5S, &cnt2);
      if (!md || cnt != cnt2)
	{
	  solv_free(md);
	  solv_free(fm);
	  solv_free(di);
	  solv_free(bn);
	  solv_free(dn);
	  return;
	}
    }
  if ((flags & RPM_ITERATE_FILELIST_WITHCOL) != 0)
    {
      co = headint32array(rpmhead, TAG_FILECOLORS, &cnt2);
      if (!co || cnt != cnt2)
	{
	  solv_free(co);
	  solv_free(md);
	  solv_free(fm);
	  solv_free(di);
	  solv_free(bn);
	  solv_free(dn);
	  return;
	}
    }
  if ((flags & RPM_ITERATE_FILELIST_NOGHOSTS) != 0)
    {
      ff = headint32array(rpmhead, TAG_FILEFLAGS, &cnt2);
      if (!ff || cnt != cnt2)
	{
	  solv_free(ff);
	  solv_free(co);
	  solv_free(md);
	  solv_free(fm);
	  solv_free(di);
	  solv_free(bn);
	  solv_free(dn);
	  return;
	}
    }
  lastdir = dcnt;
  lastdirl = 0;
  memset(&info, 0, sizeof(info));
  for (i = 0; i < cnt; i++)
    {
      if (ff && (ff[i] & FILEFLAG_GHOST) != 0)
	continue;
      diidx = di[i];
      if (diidx >= dcnt)
	continue;
      l1 = lastdir == diidx ? lastdirl : strlen(dn[diidx]);
      l = l1 + strlen(bn[i]) + 1;
      if (l > spacen)
	{
	  spacen = l + 16;
	  space = solv_realloc(space, spacen);
	}
      if (lastdir != diidx)
	{
          strcpy(space, dn[diidx]);
	  lastdir = diidx;
	  lastdirl = l1;
	}
      strcpy(space + l1, bn[i]);
      info.diridx = diidx;
      info.dirlen = l1;
      if (fm)
        info.mode = fm[i];
      if (md)
	{
	  info.digest = md[i];
	  if (fm && S_ISLNK(fm[i]))
	    {
	      info.digest = 0;
	      if (!lt)
		{
		  lt = headstringarray(rpmhead, TAG_FILELINKTOS, &cnt2);
		  if (cnt != cnt2)
		    lt = solv_free(lt);
		}
	      if (lt)
		{
		  linkhash(lt[i], md5);
		  info.digest = md5;
		}
	    }
	  if (!info.digest)
	    {
	      sprintf(md5, "%08x%08x%08x%08x", (fm[i] >> 12) & 65535, 0, 0, 0);
	      info.digest = md5;
	    }
	}
      if (co)
	info.color = co[i];
      (*cb)(cbdata, space, &info);
    }
  solv_free(space);
  solv_free(lt);
  solv_free(md);
  solv_free(fm);
  solv_free(di);
  solv_free(bn);
  solv_free(dn);
  solv_free(co);
  solv_free(ff);
}

char *
rpm_query(void *rpmhandle, Id what)
{
  const char *name, *arch, *sourcerpm;
  char *evr, *r;
  int l;

  RpmHead *rpmhead = rpmhandle;
  r = 0;
  switch (what)
    {
    case 0:
      name = headstring(rpmhead, TAG_NAME);
      if (!name)
	name = "";
      sourcerpm = headstring(rpmhead, TAG_SOURCERPM);
      if (sourcerpm || (rpmhead->forcebinary && !headexists(rpmhead, TAG_SOURCEPACKAGE)))
	arch = headstring(rpmhead, TAG_ARCH);
      else
	{
	  if (headexists(rpmhead, TAG_NOSOURCE) || headexists(rpmhead, TAG_NOPATCH))
	    arch = "nosrc";
	  else
	    arch = "src";
	}
      if (!arch)
	arch = "noarch";
      evr = headtoevr(rpmhead);
      l = strlen(name) + 1 + strlen(evr ? evr : "") + 1 + strlen(arch) + 1;
      r = solv_malloc(l);
      sprintf(r, "%s-%s.%s", name, evr ? evr : "", arch);
      solv_free(evr);
      break;
    case SOLVABLE_NAME:
      name = headstring(rpmhead, TAG_NAME);
      r = solv_strdup(name);
      break;
    case SOLVABLE_SUMMARY:
      name = headstring(rpmhead, TAG_SUMMARY);
      r = solv_strdup(name);
      break;
    case SOLVABLE_DESCRIPTION:
      name = headstring(rpmhead, TAG_DESCRIPTION);
      r = solv_strdup(name);
      break;
    case SOLVABLE_EVR:
      r = headtoevr(rpmhead);
      break;
    }
  return r;
}

unsigned long long
rpm_query_num(void *rpmhandle, Id what, unsigned long long notfound)
{
  RpmHead *rpmhead = rpmhandle;
  unsigned int u32;

  switch (what)
    {
    case SOLVABLE_INSTALLTIME:
      u32 = headint32(rpmhead, TAG_INSTALLTIME);
      return u32 ? u32 : notfound;
    }
  return notfound;
}

int
rpm_installedrpmdbids(void *rpmstate, const char *index, const char *match, Queue *rpmdbidq)
{
  struct rpmdbentry *entries;
  int nentries, i;

  entries = getinstalledrpmdbids(rpmstate, index ? index : "Name", match, &nentries, 0);
  if (rpmdbidq)
    {
      queue_empty(rpmdbidq);
      for (i = 0; i < nentries; i++)
        queue_push(rpmdbidq, entries[i].rpmdbid);
    }
  solv_free(entries);
  return nentries;
}

void *
rpm_byrpmdbid(void *rpmstate, Id rpmdbid)
{
  struct rpmdbstate *state = rpmstate;
  int r;

  r = getrpmdbid(state, rpmdbid);
  if (!r)
    pool_error(state->pool, 0, "header #%d not in database", rpmdbid);
  return r <= 0 ? 0 : state->rpmhead;
}

void *
rpm_byfp(void *rpmstate, FILE *fp, const char *name)
{
  struct rpmdbstate *state = rpmstate;
  /* int headerstart, headerend; */
  RpmHead *rpmhead;
  unsigned int sigdsize, sigcnt, l;
  unsigned char lead[4096];
  int forcebinary = 0;

  if (fread(lead, 96 + 16, 1, fp) != 1 || getu32(lead) != 0xedabeedb)
    {
      pool_error(state->pool, 0, "%s: not a rpm", name);
      return 0;
    }
  forcebinary = lead[6] != 0 || lead[7] != 1;
  if (lead[78] != 0 || lead[79] != 5)
    {
      pool_error(state->pool, 0, "%s: not a V5 header", name);
      return 0;
    }
  if (getu32(lead + 96) != 0x8eade801)
    {
      pool_error(state->pool, 0, "%s: bad signature header", name);
      return 0;
    }
  sigcnt = getu32(lead + 96 + 8);
  sigdsize = getu32(lead + 96 + 12);
  if (sigcnt >= 0x100000 || sigdsize >= 0x100000)
    {
      pool_error(state->pool, 0, "%s: bad signature header", name);
      return 0;
    }
  sigdsize += sigcnt * 16;
  sigdsize = (sigdsize + 7) & ~7;
  /* headerstart = 96 + 16 + sigdsize; */
  while (sigdsize)
    {
      l = sigdsize > 4096 ? 4096 : sigdsize;
      if (fread(lead, l, 1, fp) != 1)
	{
	  pool_error(state->pool, 0, "%s: unexpected EOF", name);
	  return 0;
	}
      sigdsize -= l;
    }
  if (fread(lead, 16, 1, fp) != 1)
    {
      pool_error(state->pool, 0, "%s: unexpected EOF", name);
      return 0;
    }
  if (getu32(lead) != 0x8eade801)
    {
      pool_error(state->pool, 0, "%s: bad header", name);
      return 0;
    }
  sigcnt = getu32(lead + 8);
  sigdsize = getu32(lead + 12);
  if (sigcnt >= 0x100000 || sigdsize >= 0x2000000)
    {
      pool_error(state->pool, 0, "%s: bad header", name);
      return 0;
    }
  l = sigdsize + sigcnt * 16;
  /* headerend = headerstart + 16 + l; */
  if (l > state->rpmheadsize)
    {
      state->rpmheadsize = l + 128;
      state->rpmhead = solv_realloc(state->rpmhead, sizeof(*state->rpmhead) + state->rpmheadsize);
    }
  rpmhead = state->rpmhead;
  if (fread(rpmhead->data, l, 1, fp) != 1)
    {
      pool_error(state->pool, 0, "%s: unexpected EOF", name);
      return 0;
    }
  rpmhead->forcebinary = forcebinary;
  rpmhead->cnt = sigcnt;
  rpmhead->dcnt = sigdsize;
  rpmhead->dp = rpmhead->data + rpmhead->cnt * 16;
  return rpmhead;
}

#ifdef ENABLE_RPMDB_BYRPMHEADER

void *
rpm_byrpmh(void *rpmstate, Header h)
{
  struct rpmdbstate *state = rpmstate;
  const unsigned char *uh;
  unsigned int sigdsize, sigcnt, l;
  RpmHead *rpmhead;

#ifndef RPM5
  uh = headerUnload(h);
#else
  uh = headerUnload(h, NULL);
#endif
  if (!uh)
    return 0;
  sigcnt = getu32(uh);
  sigdsize = getu32(uh + 4);
  l = sigdsize + sigcnt * 16;
  if (l > state->rpmheadsize)
    {
      state->rpmheadsize = l + 128;
      state->rpmhead = solv_realloc(state->rpmhead, sizeof(*state->rpmhead) + state->rpmheadsize);
    }
  rpmhead = state->rpmhead;
  memcpy(rpmhead->data, uh + 8, l - 8);
  free((void *)uh);
  rpmhead->forcebinary = 0;
  rpmhead->cnt = sigcnt;
  rpmhead->dcnt = sigdsize;
  rpmhead->dp = rpmhead->data + rpmhead->cnt * 16;
  return rpmhead;
}

#endif

