/*
 * Copyright (c) 2007-2013, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * repo_pubkey
 *
 * support for pubkey reading
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
#include <dirent.h>

#include <rpm/rpmio.h>
#include <rpm/rpmpgp.h>
#ifndef RPM5
#include <rpm/header.h>
#endif
#include <rpm/rpmdb.h>

#include "pool.h"
#include "repo.h"
#include "hash.h"
#include "util.h"
#include "queue.h"
#include "chksum.h"
#include "repo_rpmdb.h"
#include "repo_pubkey.h"
#ifdef ENABLE_PGPVRFY
#include "solv_pgpvrfy.h"
#endif

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

static char *
r64dec1(char *p, unsigned int *vp, int *eofp)
{
  int i, x;
  unsigned int v = 0;

  for (i = 0; i < 4; )
    {
      x = *p++;
      if (!x)
	return 0;
      if (x >= 'A' && x <= 'Z')
	x -= 'A';
      else if (x >= 'a' && x <= 'z')
	x -= 'a' - 26;
      else if (x >= '0' && x <= '9')
	x -= '0' - 52;
      else if (x == '+')
	x = 62;
      else if (x == '/')
	x = 63;
      else if (x == '=')
	{
	  x = 0;
	  if (i == 0)
	    {
	      *eofp = 3;
	      *vp = 0;
	      return p - 1;
	    }
	  *eofp += 1;
	}
      else
	continue;
      v = v << 6 | x;
      i++;
    }
  *vp = v;
  return p;
}

static unsigned int
crc24(unsigned char *p, int len)
{
  unsigned int crc = 0xb704ce;
  int i;

  while (len--)
    {
      crc ^= (*p++) << 16;
      for (i = 0; i < 8; i++)
        if ((crc <<= 1) & 0x1000000)
	  crc ^= 0x1864cfb;
    }
  return crc & 0xffffff;
}

static int
unarmor(char *pubkey, unsigned char **pktp, int *pktlp, const char *startstr, const char *endstr)
{
  char *p, *pubkeystart = pubkey;
  int l, eof;
  unsigned char *buf, *bp;
  unsigned int v;

  *pktp = 0;
  *pktlp = 0;
  if (!pubkey)
    return 0;
  l = strlen(startstr);
  while (strncmp(pubkey, startstr, l) != 0)
    {
      pubkey = strchr(pubkey, '\n');
      if (!pubkey)
	return 0;
      pubkey++;
    }
  pubkey = strchr(pubkey, '\n');
  if (!pubkey++)
    return 0;
  /* skip header lines */
  for (;;)
    {
      while (*pubkey == ' ' || *pubkey == '\t')
	pubkey++;
      if (*pubkey == '\n')
	break;
      pubkey = strchr(pubkey, '\n');
      if (!pubkey++)
	return 0;
    }
  pubkey++;
  p = strchr(pubkey, '=');
  if (!p)
    return 0;
  l = p - pubkey;
  bp = buf = solv_malloc(l * 3 / 4 + 4);
  eof = 0;
  while (!eof)
    {
      pubkey = r64dec1(pubkey, &v, &eof);
      if (!pubkey)
	{
	  solv_free(buf);
	  return 0;
	}
      *bp++ = v >> 16;
      *bp++ = v >> 8;
      *bp++ = v;
    }
  while (*pubkey == ' ' || *pubkey == '\t' || *pubkey == '\n' || *pubkey == '\r')
    pubkey++;
  bp -= eof;
  if (*pubkey != '=' || (pubkey = r64dec1(pubkey + 1, &v, &eof)) == 0)
    {
      solv_free(buf);
      return 0;
    }
  if (v != crc24(buf, bp - buf))
    {
      solv_free(buf);
      return 0;
    }
  while (*pubkey == ' ' || *pubkey == '\t' || *pubkey == '\n' || *pubkey == '\r')
    pubkey++;
  if (strncmp(pubkey, endstr, strlen(endstr)) != 0)
    {
      solv_free(buf);
      return 0;
    }
  p = strchr(pubkey, '\n');
  if (!p)
    p = pubkey + strlen(pubkey);
  *pktp = buf;
  *pktlp = bp - buf;
  return (p ? p + 1 : pubkey + strlen(pubkey)) - pubkeystart;
}

#define ARMOR_NLAFTER	16

static char *
armor(unsigned char *pkt, int pktl, const char *startstr, const char *endstr, const char *version)
{
  static const char bintoasc[64] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  char *str = solv_malloc(strlen(startstr) + strlen(endstr) + strlen(version) + (pktl / 3) * 4 + (pktl / (ARMOR_NLAFTER * 3)) + 30);
  char *p = str;
  int a, b, c, i;
  unsigned int v;

  v = crc24(pkt, pktl);
  sprintf(p, "%s\nVersion: %s\n\n", startstr, version);
  p += strlen(p);
  for (i = -1; pktl > 0; pktl -= 3)
    {
      if (++i == ARMOR_NLAFTER)
	{
	  i = 0;
	  *p++ = '\n';
	}
      a = *pkt++;
      b = pktl > 1 ? *pkt++ : 0;
      c = pktl > 2 ? *pkt++ : 0;
      *p++ = bintoasc[a >> 2];
      *p++ = bintoasc[(a & 3) << 4 | b >> 4];
      *p++ = pktl > 1 ? bintoasc[(b & 15) << 2 | c >> 6] : '=';
      *p++ = pktl > 2 ? bintoasc[c & 63] : '=';
    }
  *p++ = '\n';
  *p++ = '=';
  *p++ = bintoasc[v >> 18 & 0x3f];
  *p++ = bintoasc[v >> 12 & 0x3f];
  *p++ = bintoasc[v >>  6 & 0x3f];
  *p++ = bintoasc[v       & 0x3f];
  sprintf(p, "\n%s\n", endstr);
  return str;
}

/* internal representation of a signature */
struct pgpsig {
  int type;
  Id hashalgo;
  unsigned char issuer[8];
  int haveissuer;
  unsigned int created;
  unsigned int expires;
  unsigned int keyexpires;
  unsigned char *sigdata;
  int sigdatal;
  int mpioff;
};

static Id
pgphashalgo2type(int algo)
{
  if (algo == 1)
    return REPOKEY_TYPE_MD5;
  if (algo == 2)
    return REPOKEY_TYPE_SHA1;
  if (algo == 8)
    return REPOKEY_TYPE_SHA256;
  if (algo == 9)
    return REPOKEY_TYPE_SHA384;
  if (algo == 10)
    return REPOKEY_TYPE_SHA512;
  if (algo == 11)
    return REPOKEY_TYPE_SHA224;
  return 0;
}

/* hash the pubkey/userid data for self-sig verification
 * hash the final trailer
 * create a "sigdata" block suitable for a call to solv_pgpverify */
static void
pgpsig_makesigdata(struct pgpsig *sig, unsigned char *p, int l, unsigned char *pubkey, int pubkeyl, unsigned char *userid, int useridl, Chksum *h)
{
  int type = sig->type;
  unsigned char b[6];
  const unsigned char *cs;
  int csl;

  if (!h || sig->mpioff < 2 || l <= sig->mpioff)
    return;
  if ((type >= 0x10 && type <= 0x13) || type == 0x1f || type == 0x18 || type == 0x20 || type == 0x28)
    {
      b[0] = 0x99;
      b[1] = pubkeyl >> 8;
      b[2] = pubkeyl;
      solv_chksum_add(h, b, 3);
      solv_chksum_add(h, pubkey, pubkeyl);
    }
  if ((type >= 0x10 && type <= 0x13))
    {
      if (p[0] != 3)
	{
	  b[0] = 0xb4;
	  b[1] = useridl >> 24;
	  b[2] = useridl >> 16;
	  b[3] = useridl >> 8;
	  b[4] = useridl;
	  solv_chksum_add(h, b, 5);
	}
      solv_chksum_add(h, userid, useridl);
    }
  /* add trailer */
  if (p[0] == 3)
    solv_chksum_add(h, p + 2, 5);
  else
    {
      int hl = 6 + (p[4] << 8 | p[5]);
      solv_chksum_add(h, p, hl);
      b[0] = 4;
      b[1] = 0xff;
      b[2] = hl >> 24;
      b[3] = hl >> 16;
      b[4] = hl >> 8;
      b[5] = hl;
      solv_chksum_add(h, b, 6);
    }
  cs = solv_chksum_get(h, &csl);
  if (cs[0] == p[sig->mpioff - 2] && cs[1] == p[sig->mpioff - 1])
    {
      int ml = l - sig->mpioff;
      sig->sigdata = solv_malloc(2 + csl + ml);
      sig->sigdatal = 2 + csl + ml;
      sig->sigdata[0] = p[0] == 3 ? p[15] : p[2];
      sig->sigdata[1] = p[0] == 3 ? p[16] : p[3];
      memcpy(sig->sigdata + 2, cs, csl);
      memcpy(sig->sigdata + 2 + csl, p + sig->mpioff, ml);
    }
}

/* parse the header of a subpacket contained in a signature packet
 * returns: length of the packet header, 0 if there was an error
 * *pktlp is set to the packet length, the tag is the first byte.
 */
static inline int
parsesubpkglength(unsigned char *q, int ql, int *pktlp)
{
  int x, sl, hl;
  /* decode sub-packet length, ql must be > 0 */
  x = *q++;
  if (x < 192)
    {
      sl = x;
      hl = 1;
    }
  else if (x == 255)
    {
      if (ql < 5 || q[0] != 0)
	return 0;
      sl = q[1] << 16 | q[2] << 8 | q[3];
      hl = 5;
    }
  else
    {
      if (ql < 2)
	return 0;
      sl = ((x - 192) << 8) + q[0] + 192;
      hl = 2;
    }
  if (!sl || ql < sl + hl)	/* sub pkg tag is included in length, i.e. sl must not be zero */
    return 0;
  *pktlp = sl;
  return hl;
}

/* parse a signature packet, initializing the pgpsig struct */
static void
pgpsig_init(struct pgpsig *sig, unsigned char *p, int l)
{
  memset(sig, 0, sizeof(*sig));
  sig->type = -1;
  if (p[0] == 3)
    {
      /* printf("V3 signature packet\n"); */
      if (l <= 19 || p[1] != 5)
	return;
      sig->type = p[2];
      sig->haveissuer = 1;
      memcpy(sig->issuer, p + 7, 8);
      sig->created = p[3] << 24 | p[4] << 16 | p[5] << 8 | p[6];
      sig->hashalgo = p[16];
      sig->mpioff = 19;
    }
  else if (p[0] == 4)
    {
      int j, ql, x;
      unsigned char *q;

      /* printf("V4 signature packet\n"); */
      if (l < 6)
	return;
      sig->type = p[1];
      sig->hashalgo = p[3];
      q = p + 4;
      sig->keyexpires = -1;
      for (j = 0; q && j < 2; j++)
	{
	  if (q + 2 > p + l)
	    {
	      q = 0;
	      break;
	    }
	  ql = q[0] << 8 | q[1];
	  q += 2;
	  if (q + ql > p + l)
	    {
	      q = 0;
	      break;
	    }
	  while (ql > 0)
	    {
	      int sl, hl;
	      hl = parsesubpkglength(q, ql, &sl);
	      if (!hl)
		{
		  q = 0;
		  break;
		}
	      q += hl;
	      ql -= hl;
	      x = q[0] & 127;	/* strip critical bit */
	      /* printf("%d SIGSUB %d %d\n", j, x, sl); */
	      if (x == 16 && sl == 9 && !sig->haveissuer)
		{
		  sig->haveissuer = 1;
		  memcpy(sig->issuer, q + 1, 8);
		}
	      if (x == 2 && j == 0)
		sig->created = q[1] << 24 | q[2] << 16 | q[3] << 8 | q[4];
	      if (x == 3 && j == 0)
		sig->expires = q[1] << 24 | q[2] << 16 | q[3] << 8 | q[4];
	      if (x == 9 && j == 0)
		sig->keyexpires = q[1] << 24 | q[2] << 16 | q[3] << 8 | q[4];
	      q += sl;
	      ql -= sl;
	    }
	}
      if (q && q - p + 2 < l)
	sig->mpioff = q - p + 2;
    }
}

/* parse a pgp packet header
 * returns: length of the packet header, 0 if there was an error
 * *tagp and *pktlp is set to the packet tag and the packet length
 */
static int
parsepkgheader(unsigned char *p, int pl, int *tagp, int *pktlp)
{
  unsigned char *op = p;
  int x, l;

  if (!pl)
    return 0;
  x = *p++;
  pl--;
  if (!(x & 128) || pl <= 0)
    return 0;
  if ((x & 64) == 0)
    {
      *tagp = (x & 0x3c) >> 2;		/* old format */
      x = 1 << (x & 3);
      if (x > 4 || pl < x || (x == 4 && p[0]))
	return 0;
      pl -= x;
      for (l = 0; x--;)
	l = l << 8 | *p++;
    }
  else
    {
      *tagp = (x & 0x3f);		/* new format */
      x = *p++;
      pl--;
      if (x < 192)
	l = x;
      else if (x >= 192 && x < 224)
	{
	  if (pl <= 0)
	    return 0;
	  l = ((x - 192) << 8) + *p++ + 192;
	  pl--;
	}
      else if (x == 255)
	{
	  if (pl <= 4 || p[0] != 0)	/* sanity: p[0] must be zero */
	    return 0;
	  l = p[1] << 16 | p[2] << 8 | p[3];
	  p += 4;
	  pl -= 4;
	}
      else
	return 0;
    }
  if (l > pl)
    return 0;
  *pktlp = l;
  return p - op;
}

/* parse the first pubkey (possible creating new packages for the subkeys)
 * returns the number of parsed bytes.
 * if flags contains ADD_WITH_SUBKEYS, all subkeys will be added as new
 * solvables as well */
static int
parsepubkey(Solvable *s, Repodata *data, unsigned char *p, int pl, int flags)
{
  Repo *repo = s->repo;
  unsigned char *pstart = p;
  int tag, l;
  unsigned char keyid[8];
  char subkeyofstr[17];
  unsigned int kcr = 0, maxex = 0, maxsigcr = 0;
  unsigned char *pubkey = 0;
  int pubkeyl = 0;
  int insubkey = 0;
  unsigned char *userid = 0;
  int useridl = 0;
  unsigned char *pubdata = 0;
  int pubdatal = 0;

  *subkeyofstr = 0;
  for (; ; p += l, pl -= l)
    {
      int hl = parsepkgheader(p, pl, &tag, &l);
      if (!hl || (pubkey && (tag == 6 || tag == 14)))
	{
	  /* finish old key */
	  if (kcr)
	    repodata_set_num(data, s - repo->pool->solvables, SOLVABLE_BUILDTIME, kcr);
	  if (maxex && maxex != -1)
	    repodata_set_num(data, s - repo->pool->solvables, PUBKEY_EXPIRES, maxex);
	  s->name = pool_str2id(s->repo->pool, insubkey ? "gpg-subkey" : "gpg-pubkey", 1);
	  s->evr = 1;
	  s->arch = 1;
	  if (userid && useridl)
	    {
	      char *useridstr = solv_malloc(useridl + 1);
	      memcpy(useridstr, userid, useridl);
	      useridstr[useridl] = 0;
	      setutf8string(data, s - repo->pool->solvables, SOLVABLE_SUMMARY, useridstr);
	      free(useridstr);
	    }
	  if (pubdata)
	    {
	      char keyidstr[17];
	      char evr[8 + 1 + 8 + 1];
	      solv_bin2hex(keyid, 8, keyidstr);
	      repodata_set_str(data, s - repo->pool->solvables, PUBKEY_KEYID, keyidstr);
	      /* build rpm-style evr */
	      strcpy(evr, keyidstr + 8);
	      sprintf(evr + 8, "-%08x", maxsigcr);
	      s->evr = pool_str2id(repo->pool, evr, 1);
	    }
	  if (insubkey && *subkeyofstr)
	    repodata_set_str(data, s - repo->pool->solvables, PUBKEY_SUBKEYOF, subkeyofstr);
	  if (pubdata)		/* set data blob */
	    repodata_set_binary(data, s - repo->pool->solvables, PUBKEY_DATA, pubdata, pubdatal);
	  if (!pl)
	    break;
	  if (!hl)
	    {
	      p = 0;	/* parse error */
	      break;
	    }
	  if (tag == 6 || (tag == 14 && !(flags & ADD_WITH_SUBKEYS)))
	    break;
	  if (tag == 14 && pubdata && !insubkey)
	    solv_bin2hex(keyid, 8, subkeyofstr);
	  /* create new solvable for subkey */
	  s = pool_id2solvable(repo->pool, repo_add_solvable(repo));
	}
      p += hl;
      pl -= hl;
      if (!pubkey && tag != 6)
	continue;
      if (tag == 6 || (tag == 14 && (flags & ADD_WITH_SUBKEYS) != 0))		/* Public-Key Packet */
	{
	  if (tag == 6)
	    {
	      pubkey = solv_memdup(p, l);
	      pubkeyl = l;
	    }
	  else
	    insubkey = 1;
	  pubdata = 0;
	  pubdatal = 0;
	  if (p[0] == 3 && l >= 10)
	    {
	      unsigned int ex;
	      Chksum *h;
	      maxsigcr = kcr = p[1] << 24 | p[2] << 16 | p[3] << 8 | p[4];
	      ex = 0;
	      if (p[5] || p[6])
		{
		  ex = kcr + 24*3600 * (p[5] << 8 | p[6]);
		  if (ex > maxex)
		    maxex = ex;
		}
	      memset(keyid, 0, 8);
	      if (p[7] == 1)	/* RSA */
		{
		  int ql, ql2;
		  unsigned char fp[16];
		  char fpx[32 + 1];
		  unsigned char *q;

		  ql = ((p[8] << 8 | p[9]) + 7) / 8;		/* length of public modulus */
		  if (ql >= 8 && 10 + ql + 2 <= l)
		    {
		      memcpy(keyid, p + 10 + ql - 8, 8);	/* keyid is last 64 bits of public modulus */
		      q = p + 10 + ql;
		      ql2 = ((q[0] << 8 | q[1]) + 7) / 8;	/* length of encryption exponent */
		      if (10 + ql + 2 + ql2 <= l)
			{
			  /* fingerprint is the md5 over the two MPI bodies */
			  h = solv_chksum_create(REPOKEY_TYPE_MD5);
			  solv_chksum_add(h, p + 10, ql);
			  solv_chksum_add(h, q + 2, ql2);
			  solv_chksum_free(h, fp);
			  solv_bin2hex(fp, 16, fpx);
			  repodata_set_str(data, s - s->repo->pool->solvables, PUBKEY_FINGERPRINT, fpx);
			}
		    }
		  pubdata = p + 7;
		  pubdatal = l - 7;
		}
	    }
	  else if (p[0] == 4 && l >= 6)
	    {
	      Chksum *h;
	      unsigned char hdr[3];
	      unsigned char fp[20];
	      char fpx[40 + 1];

	      maxsigcr = kcr = p[1] << 24 | p[2] << 16 | p[3] << 8 | p[4];
	      hdr[0] = 0x99;
	      hdr[1] = l >> 8;
	      hdr[2] = l;
	      /* fingerprint is the sha1 over the packet */
	      h = solv_chksum_create(REPOKEY_TYPE_SHA1);
	      solv_chksum_add(h, hdr, 3);
	      solv_chksum_add(h, p, l);
	      solv_chksum_free(h, fp);
	      solv_bin2hex(fp, 20, fpx);
	      repodata_set_str(data, s - s->repo->pool->solvables, PUBKEY_FINGERPRINT, fpx);
	      memcpy(keyid, fp + 12, 8);	/* keyid is last 64 bits of fingerprint */
	      pubdata = p + 5;
	      pubdatal = l - 5;
	    }
	}
      if (tag == 2)		/* Signature Packet */
	{
	  struct pgpsig sig;
	  Id htype;
	  if (!pubdata)
	    continue;
	  pgpsig_init(&sig, p, l);
	  if (!sig.haveissuer || !((sig.type >= 0x10 && sig.type <= 0x13) || sig.type == 0x1f))
	    continue;
	  if (sig.type >= 0x10 && sig.type <= 0x13 && !userid)
	    continue;
	  htype = pgphashalgo2type(sig.hashalgo);
	  if (htype && sig.mpioff)
	    {
	      Chksum *h = solv_chksum_create(htype);
	      pgpsig_makesigdata(&sig, p, l, pubkey, pubkeyl, userid, useridl, h);
	      solv_chksum_free(h, 0);
	    }
	  if (!memcmp(keyid, sig.issuer, 8))
	    {
#ifdef ENABLE_PGPVRFY
	      /* found self sig, verify */
	      if (solv_pgpvrfy(pubdata, pubdatal, sig.sigdata, sig.sigdatal))
#endif
		{
		  if (sig.keyexpires && maxex != -1)
		    {
		      if (sig.keyexpires == -1)
			maxex = -1;
		      else if (sig.keyexpires + kcr > maxex)
			maxex = sig.keyexpires + kcr;
		    }
		  if (sig.created > maxsigcr)
		    maxsigcr = sig.created;
		}
	    }
	  else if (flags & ADD_WITH_KEYSIGNATURES)
	    {
	      char issuerstr[17];
	      Id shandle = repodata_new_handle(data);
	      solv_bin2hex(sig.issuer, 8, issuerstr);
	      repodata_set_str(data, shandle, SIGNATURE_ISSUER, issuerstr);
	      if (sig.created)
	        repodata_set_num(data, shandle, SIGNATURE_TIME, sig.created);
	      if (sig.expires)
	        repodata_set_num(data, shandle, SIGNATURE_EXPIRES, sig.created + sig.expires);
	      if (sig.sigdata)
	        repodata_set_binary(data, shandle, SIGNATURE_DATA, sig.sigdata, sig.sigdatal);
	      repodata_add_flexarray(data, s - s->repo->pool->solvables, PUBKEY_SIGNATURES, shandle);
	    }
	  solv_free(sig.sigdata);
	}
      if (tag == 13 && !insubkey)		/* User ID Packet */
	{
	  userid = solv_realloc(userid, l);
	  if (l)
	    memcpy(userid, p, l);
	  useridl = l;
	}
    }
  solv_free(pubkey);
  solv_free(userid);
  return p ? p - pstart : 0;
}


#ifdef ENABLE_RPMDB

/* this is private to rpm, but rpm lacks an interface to retrieve
 * the values. Sigh. */
struct pgpDigParams_s {
    const char * userid;
    const unsigned char * hash;
#ifndef HAVE_PGPDIGGETPARAMS
    const char * params[4];
#endif
    unsigned char tag;
    unsigned char version;               /*!< version number. */
    unsigned char time[4];               /*!< time that the key was created. */
    unsigned char pubkey_algo;           /*!< public key algorithm. */
    unsigned char hash_algo;
    unsigned char sigtype;
    unsigned char hashlen;
    unsigned char signhash16[2];
    unsigned char signid[8];
    unsigned char saved;
};

#ifndef HAVE_PGPDIGGETPARAMS
struct pgpDig_s {
    struct pgpDigParams_s signature;
    struct pgpDigParams_s pubkey;
};
#endif


/* only rpm knows how to do the release calculation, we don't dare
 * to recreate all the bugs in libsolv */
static void
parsepubkey_rpm(Solvable *s, Repodata *data, unsigned char *pkts, int pktsl)
{
  Pool *pool = s->repo->pool;
  struct pgpDigParams_s *digpubkey;
  pgpDig dig = 0;
  char keyid[16 + 1];
  char evrbuf[8 + 1 + 8 + 1];
  unsigned int btime;

#ifndef RPM5
  dig = pgpNewDig();
#else
  dig = pgpDigNew(RPMVSF_DEFAULT, 0);
#endif
  (void) pgpPrtPkts(pkts, pktsl, dig, 0);
#ifdef HAVE_PGPDIGGETPARAMS
  digpubkey = pgpDigGetParams(dig, PGPTAG_PUBLIC_KEY);
#else
  digpubkey = &dig->pubkey;
#endif
  if (digpubkey)
    {
      btime = digpubkey->time[0] << 24 | digpubkey->time[1] << 16 | digpubkey->time[2] << 8 | digpubkey->time[3];
      solv_bin2hex(digpubkey->signid, 8, keyid);
      solv_bin2hex(digpubkey->signid + 4, 4, evrbuf);
      evrbuf[8] = '-';
      solv_bin2hex(digpubkey->time, 4, evrbuf + 9);
      s->evr = pool_str2id(pool, evrbuf, 1);
      repodata_set_str(data, s - s->repo->pool->solvables, PUBKEY_KEYID, keyid);
      if (digpubkey->userid)
	setutf8string(data, s - s->repo->pool->solvables, SOLVABLE_SUMMARY, digpubkey->userid);
      if (btime)
	repodata_set_num(data, s - s->repo->pool->solvables, SOLVABLE_BUILDTIME, btime);
    }
#ifndef RPM5
  (void)pgpFreeDig(dig);
#else
  (void)pgpDigFree(dig);
#endif
}

#endif	/* ENABLE_RPMDB */

/* parse an ascii armored pubkey
 * adds multiple pubkeys if ADD_MULTIPLE_PUBKEYS is set */
static int
pubkey2solvable(Pool *pool, Id p, Repodata *data, char *pubkey, int flags)
{
  unsigned char *pkts, *pkts_orig;
  int pktsl, pl = 0, tag, l, hl;

  if (!unarmor(pubkey, &pkts, &pktsl, "-----BEGIN PGP PUBLIC KEY BLOCK-----", "-----END PGP PUBLIC KEY BLOCK-----"))
    {
      pool_error(pool, 0, "unarmor failure");
      return 0;
    }
  pkts_orig = pkts;
  tag = 6;
  while (pktsl)
    {
      if (tag == 6)
	{
	  setutf8string(data, p, SOLVABLE_DESCRIPTION, pubkey);
	  pl = parsepubkey(pool->solvables + p, data, pkts, pktsl, flags);
#ifdef ENABLE_RPMDB
	  parsepubkey_rpm(pool->solvables + p, data, pkts, pktsl);
#endif
	  if (!pl || !(flags & ADD_MULTIPLE_PUBKEYS))
	    break;
	}
      pkts += pl;
      pktsl -= pl;
      hl = parsepkgheader(pkts, pktsl, &tag, &l);
      if (!hl)
	break;
      pl = l + hl;
      if (tag == 6)
        p = repo_add_solvable(pool->solvables[p].repo);
    }
  solv_free((void *)pkts_orig);
  return 1;
}

#ifdef ENABLE_RPMDB

int
repo_add_rpmdb_pubkeys(Repo *repo, int flags)
{
  Pool *pool = repo->pool;
  Queue q;
  int i;
  char *str;
  Repodata *data;
  const char *rootdir = 0;
  void *state;

  data = repo_add_repodata(repo, flags);
  if (flags & REPO_USE_ROOTDIR)
    rootdir = pool_get_rootdir(pool);
  state = rpm_state_create(repo->pool, rootdir);
  queue_init(&q);
  rpm_installedrpmdbids(state, "Name", "gpg-pubkey", &q);
  for (i = 0; i < q.count; i++)
    {
      Id p, p2;
      void *handle;
      unsigned long long itime;

      handle = rpm_byrpmdbid(state, q.elements[i]);
      if (!handle)
	continue;
      str = rpm_query(handle, SOLVABLE_DESCRIPTION);
      if (!str)
	continue;
      p = repo_add_solvable(repo);
      if (!pubkey2solvable(pool, p, data, str, flags))
	{
	  solv_free(str);
	  repo_free_solvable(repo, p, 1);
	  continue;
	}
      solv_free(str);
      itime = rpm_query_num(handle, SOLVABLE_INSTALLTIME, 0);
      for (p2 = p; p2 < pool->nsolvables; p2++)
	{
	  if (itime)
	    repodata_set_num(data, p2, SOLVABLE_INSTALLTIME, itime);
	  if (!repo->rpmdbid)
	    repo->rpmdbid = repo_sidedata_create(repo, sizeof(Id));
	  repo->rpmdbid[p2 - repo->start] = q.elements[i];
	}
    }
  queue_free(&q);
  rpm_state_free(state);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return 0;
}

#endif

static char *
solv_slurp(FILE *fp, int *lenp)
{
  int l, ll;
  char *buf = 0;
  int bufl = 0;

  for (l = 0; ; l += ll)
    {
      if (bufl - l < 4096)
	{
	  bufl += 4096;
	  buf = solv_realloc(buf, bufl);
	}
      ll = fread(buf + l, 1, bufl - l, fp);
      if (ll < 0)
	{
	  buf = solv_free(buf);
	  l = 0;
	  break;
	}
      if (ll == 0)
	{
	  buf[l] = 0;	/* always zero-terminate */
	  break;
	}
    }
  if (lenp)
    *lenp = l;
  return buf;
}

Id
repo_add_pubkey(Repo *repo, const char *keyfile, int flags)
{
  Pool *pool = repo->pool;
  Repodata *data;
  Id p;
  char *buf;
  FILE *fp;

  data = repo_add_repodata(repo, flags);
  buf = 0;
  if ((fp = fopen(flags & REPO_USE_ROOTDIR ? pool_prepend_rootdir_tmp(pool, keyfile) : keyfile, "r")) == 0)
    {
      pool_error(pool, -1, "%s: %s", keyfile, strerror(errno));
      return 0;
    }
  if ((buf = solv_slurp(fp, 0)) == 0)
    {
      pool_error(pool, -1, "%s: %s", keyfile, strerror(errno));
      fclose(fp);
      return 0;
    }
  fclose(fp);
  p = repo_add_solvable(repo);
  if (!pubkey2solvable(pool, p, data, buf, flags))
    {
      repo_free_solvable(repo, p, 1);
      solv_free(buf);
      return 0;
    }
  if (!(flags & REPO_NO_LOCATION))
    {
      Id p2;
      for (p2 = p; p2 < pool->nsolvables; p2++)
        repodata_set_location(data, p2, 0, 0, keyfile);
    }
  solv_free(buf);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return p;
}

static int
is_sig_packet(unsigned char *sig, int sigl)
{
  if (!sigl)
    return 0;
  if ((sig[0] & 0x80) == 0 || (sig[0] & 0x40 ? sig[0] & 0x3f : sig[0] >> 2 & 0x0f) != 2)
    return 0;
  return 1;
}

static int
is_pubkey_packet(unsigned char *pkt, int pktl)
{
  if (!pktl)
    return 0;
  if ((pkt[0] & 0x80) == 0 || (pkt[0] & 0x40 ? pkt[0] & 0x3f : pkt[0] >> 2 & 0x0f) != 6)
    return 0;
  return 1;
}

static void
add_one_pubkey(Pool *pool, Repo *repo, Repodata *data, unsigned char *pbuf, int pbufl, int flags)
{
  Id p = repo_add_solvable(repo);
  char *solvversion = pool_tmpjoin(pool, "libsolv-", LIBSOLV_VERSION_STRING, 0);
  char *descr = armor(pbuf, pbufl, "-----BEGIN PGP PUBLIC KEY BLOCK-----", "-----END PGP PUBLIC KEY BLOCK-----", solvversion);
  setutf8string(data, p, SOLVABLE_DESCRIPTION, descr);
  parsepubkey(pool->solvables + p, data, pbuf, pbufl, flags);
#ifdef ENABLE_RPMDB
  parsepubkey_rpm(pool->solvables + p, data, pbuf, pbufl);
#endif
}

int
repo_add_keyring(Repo *repo, FILE *fp, int flags)
{
  Pool *pool = repo->pool;
  Repodata *data;
  unsigned char *buf, *p, *pbuf;
  int bufl, l, pl, pbufl;

  data = repo_add_repodata(repo, flags);
  buf = (unsigned char *)solv_slurp(fp, &bufl);
  if (buf && !is_pubkey_packet(buf, bufl))
    {
      /* assume ascii armored */
      unsigned char *nbuf = 0, *ubuf;
      int nl, ubufl;
      bufl = 0;
      for (l = 0; (nl = unarmor((char *)buf + l, &ubuf, &ubufl, "-----BEGIN PGP PUBLIC KEY BLOCK-----", "-----END PGP PUBLIC KEY BLOCK-----")) != 0; l += nl)
	{
	  /* found another block. concat. */
	  nbuf = solv_realloc(nbuf, bufl + ubufl);
	  if (ubufl)
	    memcpy(nbuf + bufl, ubuf, ubufl);
          bufl += ubufl;
	  solv_free(ubuf);
	}
      solv_free(buf);
      buf = nbuf;
    }
  /* now split into pubkey parts, ignoring the packets we don't know */
  pbuf = 0;
  pbufl = 0;
  for (p = buf; bufl; p += pl, bufl -= pl)
    {
      int tag;
      int hl = parsepkgheader(p, bufl, &tag, &pl);
      if (!hl)
	break;
      pl += hl;
      if (tag == 6)
	{
	  /* found new pubkey! flush old */
	  if (pbufl)
	    {
	      add_one_pubkey(pool, repo, data, pbuf, pbufl, flags);
	      pbuf = solv_free(pbuf);
	      pbufl = 0;
	    }
	}
      if (tag != 6 && !pbufl)
	continue;
      if (tag != 6 && tag != 2 && tag != 13 && tag != 14 && tag != 17)
	continue;
      /* we want that packet. concat. */
      pbuf = solv_realloc(pbuf, pbufl + pl);
      memcpy(pbuf + pbufl, p, pl);
      pbufl += pl;
    }
  if (pbufl)
    add_one_pubkey(pool, repo, data, pbuf, pbufl, flags);
  solv_free(pbuf);
  solv_free(buf);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return 0;
}

int
repo_add_keydir(Repo *repo, const char *keydir, const char *suffix, int flags)
{
  Pool *pool = repo->pool;
  Repodata *data;
  int i, nent, sl;
  struct dirent **namelist;
  char *rkeydir;

  data = repo_add_repodata(repo, flags);
  nent = scandir(flags & REPO_USE_ROOTDIR ? pool_prepend_rootdir_tmp(pool, keydir) : keydir, &namelist, 0, alphasort);
  if (nent == -1)
    return pool_error(pool, -1, "%s: %s", keydir, strerror(errno));
  rkeydir = pool_prepend_rootdir(pool, keydir);
  sl = suffix ? strlen(suffix) : 0;
  for (i = 0; i < nent; i++)
    {
      const char *dn = namelist[i]->d_name;
      int l;
      if (*dn == '.' && !(flags & ADD_KEYDIR_WITH_DOTFILES))
	continue;
      l = strlen(dn);
      if (sl && (l < sl || strcmp(dn + l - sl, suffix) != 0))
	continue;
      repo_add_pubkey(repo, pool_tmpjoin(pool, rkeydir, "/", dn), flags | REPO_REUSE_REPODATA);
    }
  solv_free(rkeydir);
  for (i = 0; i < nent; i++)
    solv_free(namelist[i]);
  solv_free(namelist);
  if (!(flags & REPO_NO_INTERNALIZE))
    repodata_internalize(data);
  return 0;
}

Solvsig *
solvsig_create(FILE *fp)
{
  Solvsig *ss;
  unsigned char *sig;
  int sigl, hl, tag, pktl;
  struct pgpsig pgpsig;

  if ((sig = (unsigned char *)solv_slurp(fp, &sigl)) == 0)
    return 0;
  if (!is_sig_packet(sig, sigl))
    {
      /* not a raw sig, check armored */
      unsigned char *nsig;
      if (!unarmor((char *)sig, &nsig, &sigl, "-----BEGIN PGP SIGNATURE-----", "-----END PGP SIGNATURE-----"))
	{
	  solv_free(sig);
	  return 0;
	}
      solv_free(sig);
      sig = nsig;
      if (!is_sig_packet(sig, sigl))
	{
	  solv_free(sig);
	  return 0;
	}
    }
  hl = parsepkgheader(sig, sigl, &tag, &pktl);
  if (!hl || tag != 2 || !pktl)
    {
      solv_free(sig);
      return 0;
    }
  pgpsig_init(&pgpsig, sig + hl, pktl);
  if (pgpsig.type != 0 || !pgpsig.haveissuer)
    {
      solv_free(sig);
      return 0;
    }
  ss = solv_calloc(1, sizeof(*ss));
  ss->sigpkt = solv_memdup(sig + hl, pktl);
  ss->sigpktl = pktl;
  solv_free(sig);
  solv_bin2hex(pgpsig.issuer, 8, ss->keyid);
  ss->htype = pgphashalgo2type(pgpsig.hashalgo);
  ss->created = pgpsig.created;
  ss->expires = pgpsig.expires;
  return ss;
}

void
solvsig_free(Solvsig *ss)
{
  solv_free(ss->sigpkt);
  solv_free(ss);
}

static int
repo_find_all_pubkeys_cmp(const void *va, const void *vb, void *dp)
{
  Pool *pool = dp;
  Id a = *(Id *)va;
  Id b = *(Id *)vb;
  /* cannot use evrcmp, as rpm says '0' > 'a' */
  return strcmp(pool_id2str(pool, pool->solvables[b].evr), pool_id2str(pool, pool->solvables[a].evr));
}

void
repo_find_all_pubkeys(Repo *repo, const char *keyid, Queue *q)
{
  Id p;
  Solvable *s;

  queue_empty(q);
  if (!keyid)
    return;
  queue_init(q);
  FOR_REPO_SOLVABLES(repo, p, s)
    {
      const char *kidstr, *evr = pool_id2str(s->repo->pool, s->evr);

      if (!evr || strncmp(evr, keyid + 8, 8) != 0)
       continue;
      kidstr = solvable_lookup_str(s, PUBKEY_KEYID);
      if (kidstr && !strcmp(kidstr, keyid))
        queue_push(q, p);
    }
  if (q->count > 1)
    solv_sort(q->elements, q->count, sizeof(Id), repo_find_all_pubkeys_cmp, repo->pool);
}

Id
repo_find_pubkey(Repo *repo, const char *keyid)
{
  Queue q;
  Id p;
  queue_init(&q);
  repo_find_all_pubkeys(repo, keyid, &q);
  p = q.count ? q.elements[0] : 0;
  queue_free(&q);
  return p;
}

#ifdef ENABLE_PGPVRFY

/* warning: does not check key expiry/revokation, same as with gpgv or rpm */
/* returns the Id of the pubkey that verified the signature */
Id
repo_verify_sigdata(Repo *repo, unsigned char *sigdata, int sigdatal, const char *keyid)
{
  Id p;
  Queue q;
  int i;

  if (!sigdata || !keyid)
    return 0;
  queue_init(&q);
  repo_find_all_pubkeys(repo, keyid, &q);
  for (i = 0; i < q.count; i++)
    {
      int pubdatal;
      const unsigned char *pubdata = repo_lookup_binary(repo, q.elements[i], PUBKEY_DATA, &pubdatal);
      if (pubdata && solv_pgpvrfy(pubdata, pubdatal, sigdata, sigdatal))
	break;
    }
  p = i < q.count? q.elements[i] : 0;
  queue_free(&q);
  return p;
}

Id
solvsig_verify(Solvsig *ss, Repo *repo, Chksum *chk)
{
  struct pgpsig pgpsig;
  void *chk2;
  Id p;

  if (!chk || solv_chksum_isfinished(chk))
    return 0;
  pgpsig_init(&pgpsig, ss->sigpkt, ss->sigpktl);
  chk2 = solv_chksum_create_clone(chk);
  pgpsig_makesigdata(&pgpsig, ss->sigpkt, ss->sigpktl, 0, 0, 0, 0, chk2);
  solv_chksum_free(chk2, 0);
  if (!pgpsig.sigdata)
    return 0;
  p = repo_verify_sigdata(repo, pgpsig.sigdata, pgpsig.sigdatal, ss->keyid);
  solv_free(pgpsig.sigdata);
  return p;
}

#endif

