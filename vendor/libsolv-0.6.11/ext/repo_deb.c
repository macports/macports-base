/*
 * Copyright (c) 2009, Novell Inc.
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
#include <zlib.h>
#include <errno.h>

#include "pool.h"
#include "repo.h"
#include "util.h"
#include "solver.h"	/* for GET_USERINSTALLED_ flags */
#include "chksum.h"
#include "repo_deb.h"

static unsigned char *
decompress(unsigned char *in, int inl, int *outlp)
{
  z_stream strm;
  int outl, ret;
  unsigned char *out;

  memset(&strm, 0, sizeof(strm));
  strm.next_in = in;
  strm.avail_in = inl;
  out = solv_malloc(4096);
  strm.next_out = out;
  strm.avail_out = 4096;
  outl = 0;
  ret = inflateInit2(&strm, -MAX_WBITS);
  if (ret != Z_OK)
    {
      free(out);
      return 0;
    }
  for (;;)
    {
      if (strm.avail_out == 0)
	{
	  outl += 4096;
	  out = solv_realloc(out, outl + 4096);
	  strm.next_out = out + outl;
	  strm.avail_out = 4096;
	}
      ret = inflate(&strm, Z_NO_FLUSH);
      if (ret == Z_STREAM_END)
	break;
      if (ret != Z_OK)
	{
	  free(out);
	  return 0;
	}
    }
  outl += 4096 - strm.avail_out;
  inflateEnd(&strm);
  *outlp = outl;
  return out;
}

static Id
parseonedep(Pool *pool, char *p)
{
  char *n, *ne, *e, *ee;
  Id name, evr;
  int flags;

  while (*p == ' ' || *p == '\t' || *p == '\n')
    p++;
  if (!*p || *p == '(')
    return 0;
  n = p;
  /* find end of name */
  while (*p && *p != ' ' && *p != '\t' && *p != '\n' && *p != '(' && *p != '|')
    p++;
  ne = p;
  while (*p == ' ' || *p == '\t' || *p == '\n')
    p++;
  evr = 0;
  flags = 0;
  e = ee = 0;
  if (*p == '(')
    {
      p++;
      while (*p == ' ' || *p == '\t' || *p == '\n')
	p++;
      if (*p == '>')
	flags |= REL_GT;
      else if (*p == '=')
	flags |= REL_EQ;
      else if (*p == '<')
	flags |= REL_LT;
      if (flags)
	{
	  p++;
	  if (*p == '>')
	    flags |= REL_GT;
	  else if (*p == '=')
	    flags |= REL_EQ;
	  else if (*p == '<')
	    flags |= REL_LT;
	  else
	    p--;
	  p++;
	}
      while (*p == ' ' || *p == '\t' || *p == '\n')
	p++;
      e = p;
      while (*p && *p != ' ' && *p != '\t' && *p != '\n' && *p != ')')
	p++;
      ee = p;
      while (*p && *p != ')')
	p++;
      if (*p)
	p++;
      while (*p == ' ' || *p == '\t' || *p == '\n')
	p++;
    }
  if (ne - n > 4 && ne[-4] == ':' && !strncmp(ne - 4, ":any", 4))
    {
      /* multiarch annotation */
      name = pool_strn2id(pool, n, ne - n - 4, 1);
      name = pool_rel2id(pool, name, ARCH_ANY, REL_MULTIARCH, 1);
    }
  else
    name = pool_strn2id(pool, n, ne - n, 1);
  if (e)
    {
      evr = pool_strn2id(pool, e, ee - e, 1);
      name = pool_rel2id(pool, name, evr, flags, 1);
    }
  if (*p == '|')
    {
      Id id = parseonedep(pool, p + 1);
      if (id)
	name = pool_rel2id(pool, name, id, REL_OR, 1);
    }
  return name;
}

static unsigned int
makedeps(Repo *repo, char *deps, unsigned int olddeps, Id marker)
{
  Pool *pool = repo->pool;
  char *p;
  Id id;

  while ((p = strchr(deps, ',')) != 0)
    {
      *p = 0;
      olddeps = makedeps(repo, deps, olddeps, marker);
      *p = ',';
      deps = p + 1;
    }
  id = parseonedep(pool, deps);
  if (!id)
    return olddeps;
  return repo_addid_dep(repo, olddeps, id, marker);
}


/* put data from control file into the solvable */
/* warning: does inplace changes */
static void
control2solvable(Solvable *s, Repodata *data, char *control)
{
  Repo *repo = s->repo;
  Pool *pool = repo->pool;
  char *p, *q, *end, *tag;
  int x, l;
  int havesource = 0;
  char checksum[32 * 2 + 1];
  Id checksumtype = 0;
  Id newtype;

  p = control;
  while (*p)
    {
      p = strchr(p, '\n');
      if (!p)
	break;
      if (p[1] == ' ' || p[1] == '\t')
	{
	  char *q;
	  /* continuation line */
	  q = p - 1;
	  while (q >= control && *q == ' ' && *q == '\t')
	    q--;
	  l = q + 1 - control;
	  if (l)
	    memmove(p + 1 - l, control, l);
	  control = p + 1 - l;
	  p[1] = '\n';
	  p += 2;
	  continue;
	}
      end = p - 1;
      if (*p)
        *p++ = 0;
      /* strip trailing space */
      while (end >= control && (*end == ' ' || *end == '\t'))
	*end-- = 0;
      tag = control;
      control = p;
      q = strchr(tag, ':');
      if (!q || q - tag < 4)
	continue;
      *q++ = 0;
      while (*q == ' ' || *q == '\t')
	q++;
      x = '@' + (tag[0] & 0x1f);
      x = (x << 8) + '@' + (tag[1] & 0x1f);
      switch(x)
	{
	case 'A' << 8 | 'R':
	  if (!strcasecmp(tag, "architecture"))
	    s->arch = pool_str2id(pool, q, 1);
	  break;
	case 'B' << 8 | 'R':
	  if (!strcasecmp(tag, "breaks"))
	    s->conflicts = makedeps(repo, q, s->conflicts, 0);
	  break;
	case 'C' << 8 | 'O':
	  if (!strcasecmp(tag, "conflicts"))
	    s->conflicts = makedeps(repo, q, s->conflicts, 0);
	  break;
	case 'D' << 8 | 'E':
	  if (!strcasecmp(tag, "depends"))
	    s->requires = makedeps(repo, q, s->requires, -SOLVABLE_PREREQMARKER);
	  else if (!strcasecmp(tag, "description"))
	    {
	      char *ld = strchr(q, '\n');
	      if (ld)
		{
		  *ld++ = 0;
	          repodata_set_str(data, s - pool->solvables, SOLVABLE_DESCRIPTION, ld);
		}
	      else
	        repodata_set_str(data, s - pool->solvables, SOLVABLE_DESCRIPTION, q);
	      repodata_set_str(data, s - pool->solvables, SOLVABLE_SUMMARY, q);
	    }
	  break;
	case 'E' << 8 | 'N':
	  if (!strcasecmp(tag, "enhances"))
	    s->enhances = makedeps(repo, q, s->enhances, 0);
	  break;
	case 'F' << 8 | 'I':
	  if (!strcasecmp(tag, "filename"))
	    repodata_set_location(data, s - pool->solvables, 0, 0, q);
	  break;
	case 'H' << 8 | 'O':
	  if (!strcasecmp(tag, "homepage"))
	    repodata_set_str(data, s - pool->solvables, SOLVABLE_URL, q);
	  break;
	case 'I' << 8 | 'N':
	  if (!strcasecmp(tag, "installed-size"))
	    repodata_set_num(data, s - pool->solvables, SOLVABLE_INSTALLSIZE, strtoull(q, 0, 10) << 10);
	  break;
	case 'M' << 8 | 'D':
	  if (!strcasecmp(tag, "md5sum") && !checksumtype && strlen(q) == 16 * 2)
	    {
	      strcpy(checksum, q);
	      checksumtype = REPOKEY_TYPE_MD5;
	    }
	  break;
	case 'P' << 8 | 'A':
	  if (!strcasecmp(tag, "package"))
	    s->name = pool_str2id(pool, q, 1);
	  break;
	case 'P' << 8 | 'R':
	  if (!strcasecmp(tag, "pre-depends"))
	    s->requires = makedeps(repo, q, s->requires, SOLVABLE_PREREQMARKER);
	  else if (!strcasecmp(tag, "provides"))
	    s->provides = makedeps(repo, q, s->provides, 0);
	  break;
	case 'R' << 8 | 'E':
	  if (!strcasecmp(tag, "replaces"))
	    s->obsoletes = makedeps(repo, q, s->obsoletes, 0);
	  else if (!strcasecmp(tag, "recommends"))
	    s->recommends = makedeps(repo, q, s->recommends, 0);
	  break;
	case 'S' << 8 | 'H':
	  newtype = solv_chksum_str2type(tag);
	  if (!newtype || solv_chksum_len(newtype) * 2 != strlen(q))
	    break;
	  if (!checksumtype || (newtype == REPOKEY_TYPE_SHA1 && checksumtype != REPOKEY_TYPE_SHA256) || newtype == REPOKEY_TYPE_SHA256)
	    {
	      strcpy(checksum, q);
	      checksumtype = newtype;
	    }
	  break;
	case 'S' << 8 | 'O':
	  if (!strcasecmp(tag, "source"))
	    {
	      char *q2;
	      /* ignore version for now */
	      for (q2 = q; *q2; q2++)
		if (*q2 == ' ' || *q2 == '\t')
		  {
		    *q2 = 0;
		    break;
		  }
	      if (s->name && !strcmp(q, pool_id2str(pool, s->name)))
		repodata_set_void(data, s - pool->solvables, SOLVABLE_SOURCENAME);
	      else
		repodata_set_id(data, s - pool->solvables, SOLVABLE_SOURCENAME, pool_str2id(pool, q, 1));
	      havesource = 1;
	    }
	  break;
	case 'S' << 8 | 'T':
	  if (!strcasecmp(tag, "status"))
	    repodata_set_poolstr(data, s - pool->solvables, SOLVABLE_INSTALLSTATUS, q);
	  break;
	case 'S' << 8 | 'U':
	  if (!strcasecmp(tag, "suggests"))
	    s->suggests = makedeps(repo, q, s->suggests, 0);
	  break;
	case 'V' << 8 | 'E':
	  if (!strcasecmp(tag, "version"))
	    s->evr = pool_str2id(pool, q, 1);
	  break;
	}
    }
  if (checksumtype)
    repodata_set_checksum(data, s - pool->solvables, SOLVABLE_CHECKSUM, checksumtype, checksum);
  if (!s->arch)
    s->arch = ARCH_ALL;
  if (!s->evr)
    s->evr = ID_EMPTY;
  if (s->name)
    s->provides = repo_addid_dep(repo, s->provides, pool_rel2id(pool, s->name, s->evr, REL_EQ, 1), 0);
  if (s->name && !havesource)
    repodata_set_void(data, s - pool->solvables, SOLVABLE_SOURCENAME);
  if (s->obsoletes)
    {
      /* obsoletes only count when the packages also conflict */
      /* XXX: should not transcode here */
      int i, j, k;
      Id d, cid;
      for (i = j = s->obsoletes; (d = repo->idarraydata[i]) != 0; i++)
	{
	  if (!s->conflicts)
	    continue;
	  for (k = s->conflicts; (cid = repo->idarraydata[k]) != 0; k++)
	    {
	      if (repo->idarraydata[k] == cid)
		break;
	      if (ISRELDEP(cid))
		{
		  Reldep *rd = GETRELDEP(pool, cid);
		  if (rd->flags < 8 && rd->name == d)
		    break;	/* specialize obsoletes */
		}
	    }
	  if (cid)
	    repo->idarraydata[j++] = cid;
	}
      repo->idarraydata[j] = 0;
      if (j == s->obsoletes)
	s->obsoletes = 0;
    }
}

int
repo_add_debpackages(Repo *repo, FILE *fp, int flags)
{
  Pool *pool = repo->pool;
  Repodata *data;
  char *buf, *p;
  int bufl, l, ll;
  Solvable *s;

  data = repo_add_repodata(repo, flags);
  buf = solv_malloc(4096);
  bufl = 4096;
  l = 0;
  buf[l] = 0;
  p = buf;
  for (;;)
    {
      if (!(p = strchr(p, '\n')))
	{
	  int l3;
	  if (l + 1024 >= bufl)
	    {
	      buf = solv_realloc(buf, bufl + 4096);
	      bufl += 4096;
	      p = buf + l;
	      continue;
	    }
	  p = buf + l;
	  ll = fread(p, 1, bufl - l - 1, fp);
	  if (ll <= 0)
	    break;
	  p[ll] = 0;
	  while ((l3 = strlen(p)) < ll)
	    p[l3] = '\n';
	  l += ll;
	  continue;
	}
      p++;
      if (*p != '\n')
	continue;
      *p = 0;
      ll = p - buf + 1;
      s = pool_id2solvable(pool, repo_add_solvable(repo));
      control2solvable(s, data, buf);
      if (!s->name)
	repo_free_solvable(repo, s - pool->solvables, 1);
      if (l > ll)
        memmove(buf, p + 1, l - ll);
      l -= ll;
      p = buf;
      buf[l] = 0;
    }
  if (l)
    {
      s = pool_id2solvable(pool, repo_add_solvable(repo));
      control2solvable(s, data, buf);
      if (!s->name)
	repo_free_solvable(repo, s - pool->solvables, 1);
    }
  solv_free(buf);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return 0;
}

int
repo_add_debdb(Repo *repo, int flags)
{
  FILE *fp;
  const char *path = "/var/lib/dpkg/status";
  if (flags & REPO_USE_ROOTDIR)
    path = pool_prepend_rootdir_tmp(repo->pool, path);
  if ((fp = fopen(path, "r")) == 0)
    return pool_error(repo->pool, -1, "%s: %s", path, strerror(errno));
  repo_add_debpackages(repo, fp, flags);
  fclose(fp);
  return 0;
}

Id
repo_add_deb(Repo *repo, const char *deb, int flags)
{
  Pool *pool = repo->pool;
  Repodata *data;
  unsigned char buf[4096], *bp;
  int l, l2, vlen, clen, ctarlen;
  unsigned char *ctgz;
  unsigned char pkgid[16];
  unsigned char *ctar;
  int gotpkgid;
  FILE *fp;
  Solvable *s;
  struct stat stb;

  data = repo_add_repodata(repo, flags);
  if ((fp = fopen(flags & REPO_USE_ROOTDIR ? pool_prepend_rootdir_tmp(pool, deb) : deb, "r")) == 0)
    {
      pool_error(pool, -1, "%s: %s", deb, strerror(errno));
      return 0;
    }
  if (fstat(fileno(fp), &stb))
    {
      pool_error(pool, -1, "fstat: %s", strerror(errno));
      fclose(fp);
      return 0;
    }
  l = fread(buf, 1, sizeof(buf), fp);
  if (l < 8 + 60 || strncmp((char *)buf, "!<arch>\ndebian-binary   ", 8 + 16) != 0)
    {
      pool_error(pool, -1, "%s: not a deb package", deb);
      fclose(fp);
      return 0;
    }
  vlen = atoi((char *)buf + 8 + 48);
  if (vlen < 0 || vlen > l)
    {
      pool_error(pool, -1, "%s: not a deb package", deb);
      fclose(fp);
      return 0;
    }
  vlen += vlen & 1;
  if (l < 8 + 60 + vlen + 60)
    {
      pool_error(pool, -1, "%s: unhandled deb package", deb);
      fclose(fp);
      return 0;
    }
  if (strncmp((char *)buf + 8 + 60 + vlen, "control.tar.gz  ", 16) != 0)
    {
      pool_error(pool, -1, "%s: control.tar.gz is not second entry", deb);
      fclose(fp);
      return 0;
    }
  clen = atoi((char *)buf + 8 + 60 + vlen + 48);
  if (clen <= 0 || clen >= 0x100000)
    {
      pool_error(pool, -1, "%s: control.tar.gz has illegal size", deb);
      fclose(fp);
      return 0;
    }
  ctgz = solv_calloc(1, clen + 4);
  bp = buf + 8 + 60 + vlen + 60;
  l -= 8 + 60 + vlen + 60;
  if (l > clen)
    l = clen;
  if (l)
    memcpy(ctgz, bp, l);
  if (l < clen)
    {
      if (fread(ctgz + l, clen - l, 1, fp) != 1)
	{
	  pool_error(pool, -1, "%s: unexpected EOF", deb);
	  solv_free(ctgz);
	  fclose(fp);
	  return 0;
	}
    }
  fclose(fp);
  gotpkgid = 0;
  if (flags & DEBS_ADD_WITH_PKGID)
    {
      Chksum *chk = solv_chksum_create(REPOKEY_TYPE_MD5);
      solv_chksum_add(chk, ctgz, clen);
      solv_chksum_free(chk, pkgid);
      gotpkgid = 1;
    }
  if (ctgz[0] != 0x1f || ctgz[1] != 0x8b)
    {
      pool_error(pool, -1, "%s: control.tar.gz is not gzipped", deb);
      solv_free(ctgz);
      return 0;
    }
  if (ctgz[2] != 8 || (ctgz[3] & 0xe0) != 0)
    {
      pool_error(pool, -1, "%s: control.tar.gz is compressed in a strange way", deb);
      solv_free(ctgz);
      return 0;
    }
  bp = ctgz + 4;
  bp += 6;	/* skip time, xflags and OS code */
  if (ctgz[3] & 0x04)
    {
      /* skip extra field */
      l = bp[0] | bp[1] << 8;
      bp += l + 2;
      if (bp >= ctgz + clen)
	{
          pool_error(pool, -1, "%s: control.tar.gz is corrupt", deb);
	  solv_free(ctgz);
	  return 0;
	}
    }
  if (ctgz[3] & 0x08)	/* orig filename */
    while (*bp)
      bp++;
  if (ctgz[3] & 0x10)	/* file comment */
    while (*bp)
      bp++;
  if (ctgz[3] & 0x02)	/* header crc */
    bp += 2;
  if (bp >= ctgz + clen)
    {
      pool_error(pool, -1, "%s: control.tar.gz is corrupt", deb);
      solv_free(ctgz);
      return 0;
    }
  ctar = decompress(bp, ctgz + clen - bp, &ctarlen);
  solv_free(ctgz);
  if (!ctar)
    {
      pool_error(pool, -1, "%s: control.tar.gz is corrupt", deb);
      return 0;
    }
  bp = ctar;
  l = ctarlen;
  while (l > 512)
    {
      int j;
      l2 = 0;
      for (j = 124; j < 124 + 12; j++)
	if (bp[j] >= '0' && bp[j] <= '7')
	  l2 = l2 * 8 + (bp[j] - '0');
      if (!strcmp((char *)bp, "./control") || !strcmp((char *)bp, "control"))
	break;
      l2 = 512 + ((l2 + 511) & ~511);
      l -= l2;
      bp += l2;
    }
  if (l <= 512 || l - 512 - l2 <= 0 || l2 <= 0)
    {
      pool_error(pool, -1, "%s: control.tar.gz contains no control file", deb);
      free(ctar);
      return 0;
    }
  memmove(ctar, bp + 512, l2);
  ctar = solv_realloc(ctar, l2 + 1);
  ctar[l2] = 0;
  s = pool_id2solvable(pool, repo_add_solvable(repo));
  control2solvable(s, data, (char *)ctar);
  if (!(flags & REPO_NO_LOCATION))
    repodata_set_location(data, s - pool->solvables, 0, 0, deb);
  if (S_ISREG(stb.st_mode))
    repodata_set_num(data, s - pool->solvables, SOLVABLE_DOWNLOADSIZE, (unsigned long long)stb.st_size);
  if (gotpkgid)
    repodata_set_bin_checksum(data, s - pool->solvables, SOLVABLE_PKGID, REPOKEY_TYPE_MD5, pkgid);
  solv_free(ctar);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return s - pool->solvables;
}

void
pool_deb_get_autoinstalled(Pool *pool, FILE *fp, Queue *q, int flags)
{
  Id name = 0, arch = 0;
  int autoinstalled = -1;
  char *buf, *bp;
  int x, l, bufl, eof = 0;
  Id p, pp;

  queue_empty(q);
  buf = solv_malloc(4096);
  bufl = 4096;
  l = 0;
  while (!eof)
    {
      while (bufl - l < 1024)
	{
	  bufl += 4096;
	  if (bufl > 1024 * 64)
	    break;	/* hmm? */
	  buf = solv_realloc(buf, bufl);
	}
      if (!fgets(buf + l, bufl - l, fp))
	{
	  eof = 1;
	  buf[l] = '\n';
	  buf[l + 1] = 0;
	}
      l = strlen(buf);
      if (l && buf[l - 1] == '\n')
	buf[--l] = 0;
      if (!*buf || eof)
	{
	  l = 0;
	  if (name && autoinstalled > 0)
	    {
	      if ((flags & GET_USERINSTALLED_NAMEARCH) != 0)
		queue_push2(q, name, arch);
	      else if ((flags & GET_USERINSTALLED_NAMES) != 0)
		queue_push(q, name);
	      else
		{
		  FOR_PROVIDES(p, pp, name)
		    {
		      Solvable *s = pool->solvables + p;
		      if (s->name != name)
			continue;
		      if (arch && s->arch != arch)
			continue;
		      queue_push(q, p);
		    }
		}
	    }
	  name = arch = 0;
	  autoinstalled = -1;
	  continue;
	}
      /* strip trailing space */
      while (l && (buf[l - 1] == ' ' || buf[l - 1] == '\t'))
	buf[--l] = 0;
      l = 0;

      bp = strchr(buf, ':');
      if (!bp || bp - buf < 4)
	continue;
      *bp++ = 0;
      while (*bp == ' ' || *bp == '\t')
	bp++;
      x = '@' + (buf[0] & 0x1f);
      x = (x << 8) + '@' + (buf[1] & 0x1f);
      switch(x)
	{
	case 'P' << 8 | 'A':
	  if (!strcasecmp(buf, "package"))
	    name = pool_str2id(pool, bp, 1);
	  break;
	case 'A' << 8 | 'R':
	  if (!strcasecmp(buf, "architecture"))
	    arch = pool_str2id(pool, bp, 1);
	  break;
	case 'A' << 8 | 'U':
	  if (!strcasecmp(buf, "auto-installed"))
	    autoinstalled = atoi(bp);
	  break;
	default:
	  break;
	}
    }
}

