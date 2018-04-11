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
#include <errno.h>
#include <fcntl.h>
#include <dirent.h>

#include "pool.h"
#include "repo.h"
#include "util.h"
#include "chksum.h"
#include "solv_xfopen.h"
#include "repo_arch.h"

static long long parsenum(unsigned char *p, int cnt)
{
  long long x = 0;
  if (!cnt)
    return -1;
  if (*p & 0x80)
    {
      /* binary format */
      x = *p & 0x40 ? (-1 << 8 | *p)  : (*p ^ 0x80);
      while (--cnt > 0)
	x = (x << 8) | *p++;
      return x;
    }
  while (cnt > 0 && (*p == ' ' || *p == '\t'))
    cnt--, p++;
  if (*p == '-')
    return -1;
  for (; cnt > 0 && *p >= '0' && *p < '8'; cnt--, p++)
    x = (x << 3) | (*p - '0');
  return x;
}

static int readblock(FILE *fp, unsigned char *blk)
{
  int r, l = 0;
  while (l < 512)
    {
      r = fread(blk + l, 1, 512 - l, fp);
      if (r <= 0)
	return -1;
      l += r;
    }
  return 0;
}

struct tarhead {
  FILE *fp;
  unsigned char blk[512];
  int type;
  long long length;
  char *path;
  int eof;
  int ispax;
  int off;
  int end;
};

static char *getsentry(struct tarhead *th, char *s, int size)
{
  char *os = s;
  if (th->eof || size <= 1)
    return 0;
  size--;	/* terminating 0 */
  for (;;)
    {
      int i;
      for (i = th->off; i < th->end; i++)
	{
	  *s++ = th->blk[i];
	  size--;
	  if (!size || th->blk[i] == '\n')
	    {
	      th->off = i + 1;
	      *s = 0;
	      return os;
	    }
	}
      th->off = i;
      if (!th->path)
	{
	  /* fake entry */
	  th->end = fread(th->blk, 1, 512, th->fp);
	  if (th->end <= 0)
	    {
	      th->eof = 1;
	      return 0;
	    }
	  th->off = 0;
	  continue;
	}
      if (th->length <= 0)
	return 0;
      if (readblock(th->fp, th->blk))
	{
	  th->eof = 1;
	  return 0;
	}
      th->off = 0;
      th->end = th->length > 512 ? 512 : th->length;
      th->length -= th->end;
    }
}

static void skipentry(struct tarhead *th)
{
  for (; th->length > 0; th->length -= 512)
    {
      if (readblock(th->fp, th->blk))
	{
	  th->eof = 1;
	  th->length = 0;
	  return;
	}
    }
  th->length = 0;
  th->off = th->end = 0;
}

static void inittarhead(struct tarhead *th, FILE *fp)
{
  memset(th, 0, sizeof(*th));
  th->fp = fp;
}

static void freetarhead(struct tarhead *th)
{
  solv_free(th->path);
}

static int gettarhead(struct tarhead *th)
{
  int l, type;
  long long length;

  th->path = solv_free(th->path);
  th->ispax = 0;
  th->type = 0;
  th->length = 0;
  th->off = 0;
  th->end = 0;
  if (th->eof)
    return 0;
  for (;;)
    {
      int r = readblock(th->fp, th->blk);
      if (r)
	{
	  if (feof(th->fp))
	    {
	      th->eof = 1;
	      return 0;
	    }
	  return -1;
	}
      if (th->blk[0] == 0)
	{
          th->eof = 1;
	  return 0;
	}
      length = parsenum(th->blk + 124, 12);
      if (length < 0)
	return -1;
      type = 0;
      switch (th->blk[156])
	{
	case 'S': case '0':
	  type = 1;	/* file */
	  break;
	case '1':
	  /* hard link, special length magic... */
	  if (!th->ispax)
	    length = 0;
	  break;
	case '5':
	  type = 2;	/* dir */
	  break;
	case '2': case '3': case '4': case '6':
	  length = 0;
	  break;
	case 'X': case 'x': case 'L':
	  {
	    char *data, *pp;
	    if (length < 1 || length >= 1024 * 1024)
	      return -1;
	    data = pp = solv_malloc(length + 512);
	    for (l = length; l > 0; l -= 512, pp += 512)
	      if (readblock(th->fp, (unsigned char *)pp))
	        {
		  solv_free(data);
		  return -1;
	        }
	    data[length] = 0;
	    type = 3;		/* extension */
	    if (th->blk[156] == 'L')
	      {
	        solv_free(th->path);
	        th->path = data;
	        length = 0;
		break;
	      }
	    pp = data;
	    while (length > 0)
	      {
		int ll = 0;
		for (l = 0; l < length && pp[l] >= '0' && pp[l] <= '9'; l++)
		  ll = ll * 10 + (pp[l] - '0');
		if (l == length || pp[l] != ' ' || ll < 1 || ll > length || pp[ll - 1] != '\n')
		  {
		    solv_free(data);
		    return -1;
		  }
		length -= ll;
		pp += l + 1;
		ll -= l + 1;
		pp[ll - 1] = 0;
		if (!strncmp(pp, "path=", 5))
		  {
		    solv_free(th->path);
		    th->path = solv_strdup(pp + 5);
		  }
		pp += ll;
	      }
	    solv_free(data);
	    th->ispax = 1;
	    length = 0;
	    break;
	  }
	default:
	  type = 3;	/* extension */
	  break;
	}
      if ((type == 1 || type == 2) && !th->path)
	{
	  char path[157];
	  memcpy(path, th->blk, 156);
	  path[156] = 0;
	  if (!memcmp(th->blk + 257, "ustar\0\060\060", 8) && !th->path && th->blk[345])
	    {
	      /* POSIX ustar with prefix */
	      char prefix[156];
	      memcpy(prefix, th->blk + 345, 155);
	      prefix[155] = 0;
	      l = strlen(prefix);
	      if (l && prefix[l - 1] == '/')
		prefix[l - 1] = 0;
	      th->path = solv_dupjoin(prefix, "/", path);
	    }
	  else
	    th->path = solv_dupjoin(path, 0, 0);
	}
      if (type == 1 || type == 2)
	{
	  l = strlen(th->path);
	  if (l && th->path[l - 1] == '/')
	    {
	      if (l > 1)
		th->path[l - 1] = 0;
	      type = 2;
	    }
	}
      if (type != 3)
	break;
      while (length > 0)
	{
	  r = readblock(th->fp, th->blk);
	  if (r)
	    return r;
	  length -= 512;
	}
    }
  th->type = type;
  th->length = length;
  return 1;
}

static Offset
adddep(Repo *repo, Offset olddeps, char *line)
{
  Pool *pool = repo->pool;
  char *p;
  Id id;

  while (*line == ' ' || *line == '\t')
    line++;
  p = line;
  while (*p && *p != ' ' && *p != '\t' && *p != '<' && *p != '=' && *p != '>')
    p++;
  id = pool_strn2id(pool, line, p - line, 1);
  while (*p == ' ' || *p == '\t')
    p++;
  if (*p == '<' || *p == '=' || *p == '>')
    {
      int flags = 0;
      for (;; p++)
	{
	  if (*p == '<')
	    flags |= REL_LT;
	  else if (*p == '=')
	    flags |= REL_EQ;
	  else if (*p == '>')
	    flags |= REL_GT;
	  else
	    break;
	}
      while (*p == ' ' || *p == '\t')
        p++;
      line = p;
      while (*p && *p != ' ' && *p != '\t')
	p++;
      id = pool_rel2id(pool, id, pool_strn2id(pool, line, p - line, 1), flags, 1);
    }
  return repo_addid_dep(repo, olddeps, id, 0);
}

Id
repo_add_arch_pkg(Repo *repo, const char *fn, int flags)
{
  Pool *pool = repo->pool;
  Repodata *data;
  FILE *fp;
  struct tarhead th;
  char line[4096];
  int ignoreline;
  Solvable *s;
  int l, fd;
  struct stat stb;
  Chksum *pkgidchk = 0;

  data = repo_add_repodata(repo, flags);
  if ((fd = open(flags & REPO_USE_ROOTDIR ? pool_prepend_rootdir_tmp(pool, fn) : fn, O_RDONLY, 0)) < 0)
    {
      pool_error(pool, -1, "%s: %s", fn, strerror(errno));
      return 0;
    }
  if (fstat(fd, &stb))
    {
      pool_error(pool, -1, "%s: fstat: %s", fn, strerror(errno));
      close(fd);
      return 0;
    }
  if (!(fp = solv_xfopen_fd(fn, fd, "r")))
    {
      pool_error(pool, -1, "%s: fdopen failed", fn);
      close(fd);
      return 0;
    }
  s = 0;
  inittarhead(&th, fp);
  while (gettarhead(&th) > 0)
    {
      if (th.type != 1 || strcmp(th.path, ".PKGINFO") != 0)
	{
          skipentry(&th);
	  continue;
	}
      ignoreline = 0;
      s = pool_id2solvable(pool, repo_add_solvable(repo));
      if (flags & ARCH_ADD_WITH_PKGID)
	pkgidchk = solv_chksum_create(REPOKEY_TYPE_MD5);
      while (getsentry(&th, line, sizeof(line)))
	{
	  l = strlen(line);
	  if (l == 0)
	    continue;
	  if (pkgidchk)
	    solv_chksum_add(pkgidchk, line, l);
	  if (line[l - 1] != '\n')
	    {
	      ignoreline = 1;
	      continue;
	    }
	  if (ignoreline)
	    {
	      ignoreline = 0;
	      continue;
	    }
	  line[--l] = 0;
	  if (l == 0 || line[0] == '#')
	    continue;
	  if (!strncmp(line, "pkgname = ", 10))
	    s->name = pool_str2id(pool, line + 10, 1);
	  else if (!strncmp(line, "pkgver = ", 9))
	    s->evr = pool_str2id(pool, line + 9, 1);
	  else if (!strncmp(line, "pkgdesc = ", 10))
	    {
	      repodata_set_str(data, s - pool->solvables, SOLVABLE_SUMMARY, line + 10);
	      repodata_set_str(data, s - pool->solvables, SOLVABLE_DESCRIPTION, line + 10);
	    }
	  else if (!strncmp(line, "url = ", 6))
	    repodata_set_str(data, s - pool->solvables, SOLVABLE_URL, line + 6);
	  else if (!strncmp(line, "builddate = ", 12))
	    repodata_set_num(data, s - pool->solvables, SOLVABLE_BUILDTIME, strtoull(line + 12, 0, 10));
	  else if (!strncmp(line, "packager = ", 11))
	    repodata_set_poolstr(data, s - pool->solvables, SOLVABLE_PACKAGER, line + 11);
	  else if (!strncmp(line, "size = ", 7))
	    repodata_set_num(data, s - pool->solvables, SOLVABLE_INSTALLSIZE, strtoull(line + 7, 0, 10));
	  else if (!strncmp(line, "arch = ", 7))
	    s->arch = pool_str2id(pool, line + 7, 1);
	  else if (!strncmp(line, "license = ", 10))
	    repodata_add_poolstr_array(data, s - pool->solvables, SOLVABLE_LICENSE, line + 10);
	  else if (!strncmp(line, "replaces = ", 11))
	    s->obsoletes = adddep(repo, s->obsoletes, line + 11);
	  else if (!strncmp(line, "group = ", 8))
	    repodata_add_poolstr_array(data, s - pool->solvables, SOLVABLE_GROUP, line + 8);
	  else if (!strncmp(line, "depend = ", 9))
	    s->requires = adddep(repo, s->requires, line + 9);
	  else if (!strncmp(line, "optdepend = ", 12))
	    {
	      char *p = strchr(line, ':');
	      if (p)
		*p = 0;
	      s->suggests = adddep(repo, s->suggests, line + 12);
	    }
	  else if (!strncmp(line, "conflict = ", 11))
	    s->conflicts = adddep(repo, s->conflicts, line + 11);
	  else if (!strncmp(line, "provides = ", 11))
	    s->provides = adddep(repo, s->provides, line + 11);
	}
      break;
    }
  freetarhead(&th);
  fclose(fp);
  if (!s)
    {
      pool_error(pool, -1, "%s: not an arch package", fn);
      if (pkgidchk)
	solv_chksum_free(pkgidchk, 0);
      return 0;
    }
  if (s && !s->name)
    {
      pool_error(pool, -1, "%s: package has no name", fn);
      repo_free_solvable(repo, s - pool->solvables, 1);
      s = 0;
    }
  if (s)
    {
      if (!s->arch)
	s->arch = ARCH_ANY;
      if (!s->evr)
	s->evr = ID_EMPTY;
      s->provides = repo_addid_dep(repo, s->provides, pool_rel2id(pool, s->name, s->evr, REL_EQ, 1), 0);
      if (!(flags & REPO_NO_LOCATION))
	repodata_set_location(data, s - pool->solvables, 0, 0, fn);
      if (S_ISREG(stb.st_mode))
        repodata_set_num(data, s - pool->solvables, SOLVABLE_DOWNLOADSIZE, (unsigned long long)stb.st_size);
      if (pkgidchk)
	{
	  unsigned char pkgid[16];
	  solv_chksum_free(pkgidchk, pkgid);
	  repodata_set_bin_checksum(data, s - pool->solvables, SOLVABLE_PKGID, REPOKEY_TYPE_MD5, pkgid);
	  pkgidchk = 0;
	}
    }
  if (pkgidchk)
    solv_chksum_free(pkgidchk, 0);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return s ? s - pool->solvables : 0;
}

static char *getsentrynl(struct tarhead *th, char *s, int size)
{
  int l;
  if (!getsentry(th, s, size))
    {
      *s = 0;	/* eof */
      return 0;
    }
  l = strlen(s);
  if (!l)
    return 0;
  if (l && s[l - 1] == '\n')
    {
      s[l - 1] = 0;
      return s;
    }
  while (getsentry(th, s, size))
    {
      l = strlen(s);
      if (!l || s[l - 1] == '\n')
	return 0;
    }
  *s = 0;	/* eof */
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
joinhash_lookup(Repo *repo, Hashtable ht, Hashval hm, const char *fn)
{
  const char *p;
  Id name, evr;
  Hashval h, hh;

  if ((p = strrchr(fn, '/')) != 0)
    fn = p + 1;
  /* here we assume that the dirname is name-evr */
  if (!*fn)
    return 0;
  for (p = fn + strlen(fn) - 1; p > fn; p--)
    {
      while (p > fn && *p != '-')
	p--;
      if (p == fn)
	return 0;
      name = pool_strn2id(repo->pool, fn, p - fn, 0);
      if (!name)
	continue;
      evr = pool_str2id(repo->pool, p + 1, 0);
      if (!evr)
	continue;
      /* found valid name/evr combination, check hash */
      hh = HASHCHAIN_START;
      h = name & hm;
      while (ht[h])
	{
	  Solvable *s = repo->pool->solvables + ht[h];
	  if (s->name == name && s->evr == evr)
	    return s;
	  h = HASHCHAIN_NEXT(h, hh, hm);
	}
    }
  return 0;
}

static void
adddata(Repodata *data, Solvable *s, struct tarhead *th)
{
  Repo *repo = data->repo;
  Pool *pool = repo->pool;
  char line[4096];
  int l;
  int havesha256 = 0;

  while (getsentry(th, line, sizeof(line)))
    {
      l = strlen(line);
      if (l == 0 || line[l - 1] != '\n')
	continue;
      line[--l] = 0;
      if (l <= 2 || line[0] != '%' || line[l - 1] != '%')
	continue;
      if (!strcmp(line, "%FILENAME%"))
	{
	  if (getsentrynl(th, line, sizeof(line)))
	    repodata_set_location(data, s - pool->solvables, 0, 0, line);
	}
      else if (!strcmp(line, "%NAME%"))
	{
	  if (getsentrynl(th, line, sizeof(line)))
	    s->name = pool_str2id(pool, line, 1);
	}
      else if (!strcmp(line, "%VERSION%"))
	{
	  if (getsentrynl(th, line, sizeof(line)))
	    s->evr = pool_str2id(pool, line, 1);
	}
      else if (!strcmp(line, "%DESC%"))
	{
	  if (getsentrynl(th, line, sizeof(line)))
	    {
	      repodata_set_str(data, s - pool->solvables, SOLVABLE_SUMMARY, line);
	      repodata_set_str(data, s - pool->solvables, SOLVABLE_DESCRIPTION, line);
	    }
	}
      else if (!strcmp(line, "%GROUPS%"))
	{
	  if (getsentrynl(th, line, sizeof(line)))
	    repodata_add_poolstr_array(data, s - pool->solvables, SOLVABLE_GROUP, line);
	}
      else if (!strcmp(line, "%CSIZE%"))
	{
	  if (getsentrynl(th, line, sizeof(line)))
	    repodata_set_num(data, s - pool->solvables, SOLVABLE_DOWNLOADSIZE, strtoull(line, 0, 10));
	}
      else if (!strcmp(line, "%ISIZE%"))
	{
	  if (getsentrynl(th, line, sizeof(line)))
	    repodata_set_num(data, s - pool->solvables, SOLVABLE_INSTALLSIZE, strtoull(line, 0, 10));
	}
      else if (!strcmp(line, "%MD5SUM%"))
	{
	  if (getsentrynl(th, line, sizeof(line)) && !havesha256)
	    repodata_set_checksum(data, s - pool->solvables, SOLVABLE_CHECKSUM, REPOKEY_TYPE_MD5, line);
	}
      else if (!strcmp(line, "%SHA256SUM%"))
	{
	  if (getsentrynl(th, line, sizeof(line)))
	    {
	      repodata_set_checksum(data, s - pool->solvables, SOLVABLE_CHECKSUM, REPOKEY_TYPE_SHA256, line);
	      havesha256 = 1;
	    }
	}
      else if (!strcmp(line, "%URL%"))
	{
	  if (getsentrynl(th, line, sizeof(line)))
	    repodata_set_str(data, s - pool->solvables, SOLVABLE_URL, line);
	}
      else if (!strcmp(line, "%LICENSE%"))
	{
	  if (getsentrynl(th, line, sizeof(line)))
	    repodata_add_poolstr_array(data, s - pool->solvables, SOLVABLE_LICENSE, line);
	}
      else if (!strcmp(line, "%ARCH%"))
	{
	  if (getsentrynl(th, line, sizeof(line)))
	    s->arch = pool_str2id(pool, line, 1);
	}
      else if (!strcmp(line, "%BUILDDATE%"))
	{
	  if (getsentrynl(th, line, sizeof(line)))
	    repodata_set_num(data, s - pool->solvables, SOLVABLE_BUILDTIME, strtoull(line, 0, 10));
	}
      else if (!strcmp(line, "%PACKAGER%"))
	{
	  if (getsentrynl(th, line, sizeof(line)))
	    repodata_set_poolstr(data, s - pool->solvables, SOLVABLE_PACKAGER, line);
	}
      else if (!strcmp(line, "%REPLACES%"))
	{
	  while (getsentrynl(th, line, sizeof(line)) && *line)
	    s->obsoletes = adddep(repo, s->obsoletes, line);
	}
      else if (!strcmp(line, "%DEPENDS%"))
	{
	  while (getsentrynl(th, line, sizeof(line)) && *line)
	    s->requires = adddep(repo, s->requires, line);
	}
      else if (!strcmp(line, "%CONFLICTS%"))
	{
	  while (getsentrynl(th, line, sizeof(line)) && *line)
	    s->conflicts = adddep(repo, s->conflicts, line);
	}
      else if (!strcmp(line, "%PROVIDES%"))
	{
	  while (getsentrynl(th, line, sizeof(line)) && *line)
	    s->provides = adddep(repo, s->provides, line);
	}
      else if (!strcmp(line, "%OPTDEPENDS%"))
	{
	  while (getsentrynl(th, line, sizeof(line)) && *line)
	    {
	      char *p = strchr(line, ':');
	      if (p && p > line)
		*p = 0;
	      s->suggests = adddep(repo, s->suggests, line);
	    }
	}
      else if (!strcmp(line, "%FILES%"))
	{
	  while (getsentrynl(th, line, sizeof(line)) && *line)
	    {
	      char *p;
	      Id id;
	      l = strlen(line);
	      if (l > 1 && line[l - 1] == '/')
		line[--l] = 0;	/* remove trailing slashes */
	      if ((p = strrchr(line , '/')) != 0)
		{
		  *p++ = 0;
		  if (line[0] != '/')	/* anchor */
		    {
		      char tmp = *p;
		      memmove(line + 1, line, p - 1 - line);
		      *line = '/';
		      *p = 0;
		      id = repodata_str2dir(data, line, 1);
		      *p = tmp;
		    }
		  else
		    id = repodata_str2dir(data, line, 1);
		}
	      else
		{
		  p = line;
		  id = 0;
		}
	      if (!id)
		id = repodata_str2dir(data, "/", 1);
	      repodata_add_dirstr(data, s - pool->solvables, SOLVABLE_FILELIST, id, p);
	    }
	}
      while (*line)
	getsentrynl(th, line, sizeof(line));
    }
}

static void
finishsolvable(Repo *repo, Solvable *s)
{
  Pool *pool = repo->pool;
  if (!s)
    return;
  if (!s->name)
    {
      repo_free_solvable(repo, s - pool->solvables, 1);
      return;
    }
  if (!s->arch)
    s->arch = ARCH_ANY;
  if (!s->evr)
    s->evr = ID_EMPTY;
  s->provides = repo_addid_dep(repo, s->provides, pool_rel2id(pool, s->name, s->evr, REL_EQ, 1), 0);
}

int
repo_add_arch_repo(Repo *repo, FILE *fp, int flags)
{
  Pool *pool = repo->pool;
  Repodata *data;
  struct tarhead th;
  char *lastdn = 0;
  int lastdnlen = 0;
  Solvable *s = 0;
  Hashtable joinhash = 0;
  Hashval joinhashmask = 0;

  data = repo_add_repodata(repo, flags);

  if (flags & REPO_EXTEND_SOLVABLES)
    joinhash = joinhash_init(repo, &joinhashmask);

  inittarhead(&th, fp);
  while (gettarhead(&th) > 0)
    {
      char *bn;
      if (th.type != 1)
	{
          skipentry(&th);
	  continue;
	}
      bn = strrchr(th.path, '/');
      if (!bn || (strcmp(bn + 1, "desc") != 0 && strcmp(bn + 1, "depends") != 0 && strcmp(bn + 1, "files") != 0))
	{
          skipentry(&th);
	  continue;
	}
      if ((flags & REPO_EXTEND_SOLVABLES) != 0 && (!strcmp(bn + 1, "desc") || !strcmp(bn + 1, "depends")))
	{
          skipentry(&th);
	  continue;	/* skip those when we're extending */
	}
      if (!lastdn || (bn - th.path) != lastdnlen || strncmp(lastdn, th.path, lastdnlen) != 0)
	{
	  finishsolvable(repo, s);
	  solv_free(lastdn);
	  lastdn = solv_strdup(th.path);
	  lastdnlen = bn - th.path;
	  lastdn[lastdnlen] = 0;
	  if (flags & REPO_EXTEND_SOLVABLES)
	    {
	      s = joinhash_lookup(repo, joinhash, joinhashmask, lastdn);
	      if (!s)
		{
		  skipentry(&th);
		  continue;
		}
	    }
	  else
	    s = pool_id2solvable(pool, repo_add_solvable(repo));
	}
      adddata(data, s, &th);
    }
  finishsolvable(repo, s);
  solv_free(joinhash);
  solv_free(lastdn);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return 0;
}

int
repo_add_arch_local(Repo *repo, const char *dir, int flags)
{
  Pool *pool = repo->pool;
  Repodata *data;
  DIR *dp;
  struct dirent *de;
  char *entrydir, *file;
  FILE *fp;
  Solvable *s;

  data = repo_add_repodata(repo, flags);

  if (flags & REPO_USE_ROOTDIR)
    dir = pool_prepend_rootdir(pool, dir);
  dp = opendir(dir);
  if (dp)
    {
      while ((de = readdir(dp)) != 0)
	{
	  if (!de->d_name[0] || de->d_name[0] == '.')
	    continue;
	  entrydir = solv_dupjoin(dir, "/", de->d_name);
	  file = pool_tmpjoin(repo->pool, entrydir, "/desc", 0);
	  s = 0;
	  if ((fp = fopen(file, "r")) != 0)
	    {
	      struct tarhead th;
	      inittarhead(&th, fp);
	      s = pool_id2solvable(pool, repo_add_solvable(repo));
	      adddata(data, s, &th);
	      freetarhead(&th);
	      fclose(fp);
	      file = pool_tmpjoin(repo->pool, entrydir, "/files", 0);
	      if ((fp = fopen(file, "r")) != 0)
		{
		  inittarhead(&th, fp);
		  adddata(data, s, &th);
		  freetarhead(&th);
		  fclose(fp);
		}
	    }
	  solv_free(entrydir);
	}
      closedir(dp);
    }
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  if (flags & REPO_USE_ROOTDIR)
    solv_free((char *)dir);
  return 0;
}

