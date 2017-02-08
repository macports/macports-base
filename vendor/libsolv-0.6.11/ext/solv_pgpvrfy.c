/*
 * Copyright (c) 2013, SUSE Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/* simple and slow rsa/dsa verification code. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "util.h"
#include "solv_pgpvrfy.h"

typedef unsigned int mp_t;
typedef unsigned long long mp2_t;
#define MP_T_BYTES 4

#define MP_T_BITS (MP_T_BYTES * 8)

static inline void
mpzero(int len, mp_t *target)
{
  memset(target, 0, MP_T_BYTES * len);
}

static inline mp_t *
mpnew(int len)
{
  return solv_calloc(len, MP_T_BYTES);
}

static inline void
mpcpy(int len, mp_t *target, mp_t *source)
{
  memcpy(target, source, len * MP_T_BYTES);
}

#if 0
static void mpdump(int l, mp_t *a, char *s)
{
  int i;
  if (s)
    fprintf(stderr, "%s", s);
  for (i = l - 1; i >= 0; i--)
    fprintf(stderr, "%0*x", MP_T_BYTES * 2, a[i]);
  fprintf(stderr, "\n");
}
#endif

/* target[len] = x, target = target % mod
 * assumes that target < (mod << MP_T_BITS)! */
static void
mpdomod(int len, mp_t *target, mp2_t x, mp_t *mod)
{
  int i, j;
  for (i = len - 1; i >= 0; i--)
    {
      x = (x << MP_T_BITS) | target[i];
      target[i] = 0;
      if (mod[i])
	break;
    }
  if (i < 0)
    return;
  while (x >= 2 * (mp2_t)mod[i])
    {
      /* reduce */
      mp2_t z = x / ((mp2_t)mod[i] + 1);
      mp2_t n = 0;
      if ((z >> MP_T_BITS) != 0)
	z = (mp2_t)1 << MP_T_BITS;	/* just in case... */
      for (j = 0; j < i; j++)
	{
	  mp_t n2;
	  n += mod[j] * z;
	  n2 = (mp_t)n;
	  n >>= MP_T_BITS;
	  if (n2 > target[j])
	    n++;
	  target[j] -= n2;
	}
      n += mod[j] * z;
      x -= n;
    }
  target[i] = x;
  if (x >= mod[i])
    {
      mp_t n;
      if (x == mod[i])
	{
	  for (j = i - 1; j >= 0; j--)
	    if (target[j] < mod[j])
	      return;
	    else if (target[j] > mod[j])
	      break;
	}
      /* target >= mod, subtract mod */
      n = 0;
      for (j = 0; j <= i; j++)
	{
	  mp2_t n2 = mod[j] + n;
	  n = n2 > target[j] ? 1 : 0;
	  target[j] -= (mp_t)n2;
	}
    }
}

/* target += src * m */
static void
mpmult_add_int(int len, mp_t *target, mp_t *src, mp2_t m, mp_t *mod)
{
  int i;
  mp2_t x = 0;
  for (i = 0; i < len; i++)
    {
      x += src[i] * m + target[i];
      target[i] = x;
      x >>= MP_T_BITS;
    }
  mpdomod(len, target, x, mod);
}

/* target = target << MP_T_BITS */
static void
mpshift(int len, mp_t *target, mp_t *mod)
{
  mp_t x;
  if (len <= 0)
    return;
  x = target[len - 1];
  if (len > 1)
    memmove(target + 1, target, (len - 1) * MP_T_BYTES);
  target[0] = 0;
  mpdomod(len, target, x, mod);
}

/* target += m1 * m2 */
static void
mpmult_add(int len, mp_t *target, mp_t *m1, int m2len, mp_t *m2, mp_t *tmp, mp_t *mod)
{
  int i, j;
  for (j = m2len - 1; j >= 0; j--)
    if (m2[j])
      break;
  if (j < 0)
    return;
  mpcpy(len, tmp, m1);
  for (i = 0; i < j; i++)
    {
      if (m2[i])
        mpmult_add_int(len, target, tmp, m2[i], mod);
      mpshift(len, tmp, mod);
    }
  if (m2[i])
    mpmult_add_int(len, target, tmp, m2[i], mod);
}

/* target = target * m */
static void
mpmult_inplace(int len, mp_t *target, mp_t *m, mp_t *tmp1, mp_t *tmp2, mp_t *mod)
{
  mpzero(len, tmp1);
  mpmult_add(len, tmp1, target, len, m, tmp2, mod);
  mpcpy(len, target, tmp1);
}

/* target = target ^ 16 * b ^ e */
static void
mppow_int(int len, mp_t *target, mp_t *t, mp_t *mod, int e)
{
  mp_t *t2 = t + len * 16;
  mpmult_inplace(len, target, target, t, t2, mod);
  mpmult_inplace(len, target, target, t, t2, mod);
  mpmult_inplace(len, target, target, t, t2, mod);
  mpmult_inplace(len, target, target, t, t2, mod);
  if (e)
    mpmult_inplace(len, target, t + len * e, t, t2, mod);
}

/* target = b ^ e (b has to be < mod) */
static void
mppow(int len, mp_t *target, mp_t *b, int elen, mp_t *e, mp_t *mod)
{
  int i, j;
  mp_t *t;
  mpzero(len, target);
  target[0] = 1;
  for (i = elen - 1; i >= 0; i--)
    if (e[i])
      break;
  if (i < 0)
    return;
  t = mpnew(len * 17);
  mpcpy(len, t + len, b);
  for (j = 2; j < 16; j++)
    mpmult_add(len, t + len * j, b, len, t + len * j - len, t + len * 16, mod);
  for (; i >= 0; i--)
    {
#if MP_T_BYTES == 4
      mppow_int(len, target, t, mod, (e[i] >> 28) & 0x0f);
      mppow_int(len, target, t, mod, (e[i] >> 24) & 0x0f);
      mppow_int(len, target, t, mod, (e[i] >> 20) & 0x0f);
      mppow_int(len, target, t, mod, (e[i] >> 16) & 0x0f);
      mppow_int(len, target, t, mod, (e[i] >> 12) & 0x0f);
      mppow_int(len, target, t, mod, (e[i] >>  8) & 0x0f);
      mppow_int(len, target, t, mod, (e[i] >>  4) & 0x0f);
      mppow_int(len, target, t, mod,  e[i]        & 0x0f);
#elif MP_T_BYTES == 1
      mppow_int(len, target, t, mod, (e[i] >>  4) & 0x0f);
      mppow_int(len, target, t, mod,  e[i]        & 0x0f);
#endif
    }
  free(t);
}

/* target = m1 * m2 (m1 has to be < mod) */
static void
mpmult(int len, mp_t *target, mp_t *m1, int m2len, mp_t *m2, mp_t *mod)
{
  mp_t *tmp = mpnew(len);
  mpzero(len, target);
  mpmult_add(len, target, m1, m2len, m2, tmp, mod);
  free(tmp);
}

static int
mpisless(int len, mp_t *a, mp_t *b)
{
  int i;
  for (i = len - 1; i >= 0; i--)
    if (a[i] < b[i])
      return 1;
    else if (a[i] > b[i])
      return 0;
  return 0;
}

static int
mpiszero(int len, mp_t *a)
{
  int i;
  for (i = 0; i < len; i++)
    if (a[i])
      return 0;
  return 1;
}

static void
mpdec(int len, mp_t *a)
{
  int i;
  for (i = 0; i < len; i++)
    if (a[i]--)
      return;
    else
      a[i] = -(mp_t)1;
}

static int
mpdsa(int pl, mp_t *p, int ql, mp_t *q, mp_t *g, mp_t *y, mp_t *r, mp_t *s, int hl, mp_t *h)
{
  mp_t *w;
  mp_t *tmp;
  mp_t *u1, *u2;
  mp_t *gu1, *yu2;
#if 0
  mpdump(pl, p, "p = ");
  mpdump(ql, q, "q = ");
  mpdump(pl, g, "g = ");
  mpdump(pl, y, "y = ");
  mpdump(ql, r, "r = ");
  mpdump(ql, s, "s = ");
  mpdump(hl, h, "h = ");
#endif
  if (pl < ql || !mpisless(pl, g, p) || !mpisless(pl, y, p))
    return 0;				/* hmm, bad pubkey? */
  if (!mpisless(ql, r, q) || mpiszero(ql, r))
    return 0;
  if (!mpisless(ql, s, q) || mpiszero(ql, s))
    return 0;
  tmp = mpnew(pl);			/* note pl */
  mpcpy(ql, tmp, q);			/* tmp = q */
  mpdec(ql, tmp);			/* tmp-- */
  mpdec(ql, tmp);			/* tmp-- */
  w = mpnew(ql);
  mppow(ql, w, s, ql, tmp, q);		/* w = s ^ tmp (s ^ -1) */
  u1 = mpnew(pl);			/* note pl */
  /* order is important here: h can be >= q */
  mpmult(ql, u1, w, hl, h, q);		/* u1 = w * h */
  u2 = mpnew(ql);			/* u2 = 0 */
  mpmult(ql, u2, w, ql, r, q);		/* u2 = w * r */
  free(w);
  gu1 = mpnew(pl);
  yu2 = mpnew(pl);
  mppow(pl, gu1, g, ql, u1, p);		/* gu1 = g ^ u1 */
  mppow(pl, yu2, y, ql, u2, p);		/* yu2 = y ^ u2 */
  mpmult(pl, u1, gu1, pl, yu2, p);	/* u1 = gu1 * yu2 */
  free(gu1);
  free(yu2);
  mpzero(ql, u2);
  u2[0] = 1;				/* u2 = 1 */
  mpmult(ql, tmp, u2, pl, u1, q);	/* tmp = u2 * u1 */
  free(u1);
  free(u2);
#if 0
  mpdump(ql, tmp, "res = ");
#endif
  if (memcmp(tmp, r, ql * MP_T_BYTES) != 0)
    {
      free(tmp);
      return 0;
    }
  free(tmp);
  return 1;
}

static int
mprsa(int nl, mp_t *n, int el, mp_t *e, mp_t *m, mp_t *c)
{
  mp_t *tmp;
#if 0
  mpdump(nl, n, "n = ");
  mpdump(el, e, "e = ");
  mpdump(nl, m, "m = ");
  mpdump(nl, c, "c = ");
#endif
  if (!mpisless(nl, m, n))
    return 0;
  if (!mpisless(nl, c, n))
    return 0;
  tmp = mpnew(nl);
  mppow(nl, tmp, m, el, e, n);		/* tmp = m ^ e */
#if 0
  mpdump(nl, tmp, "res = ");
#endif
  if (memcmp(tmp, c, nl * MP_T_BYTES) != 0)
    {
      free(tmp);
      return 0;
    }
  free(tmp);
  return 1;
}

/* create mp with size tbits from data with size dbits */
static mp_t *
mpbuild(const unsigned char *d, int dbits, int tbits, int *mplp)
{
  int l = (tbits + MP_T_BITS - 1) / MP_T_BITS;
  int dl, i;

  mp_t *out = mpnew(l ? l : 1);
  if (mplp)
    *mplp = l;
  dl = (dbits + 7) / 8;
  d += dl;
  if (dbits > tbits)
    dl = (tbits + 7) / 8;
  for (i = 0; dl > 0; dl--, i++)
    {
      int x = *--d;
      out[i / MP_T_BYTES] |= x << (8 * (i % MP_T_BYTES));
    }
  return out;
}

static const unsigned char *
findmpi(const unsigned char **mpip, int *mpilp, int maxbits, int *outlen)
{
  int mpil = *mpilp;
  const unsigned char *mpi = *mpip;
  int bits, l;

  *outlen = 0;
  if (mpil < 2)
    return 0;
  bits = mpi[0] << 8 | mpi[1];
  l = 2 + (bits + 7) / 8;
  if (bits > maxbits || mpil < l || (bits && !mpi[2]))
    {
      *mpilp = 0;
      return 0;
    }
  *outlen = bits;
  *mpilp = mpil - l;
  *mpip = mpi + l;
  return mpi + 2;
}

int
solv_pgpvrfy(const unsigned char *pub, int publ, const unsigned char *sig, int sigl)
{
  int hashl;
  unsigned char *oid = 0;
  const unsigned char *mpi;
  int mpil;
  int res = 0;

  if (!pub || !sig || publ < 1 || sigl < 2)
    return 0;
  if (pub[0] != sig[0])
    return 0;		/* key algo mismatch */
  switch(sig[1])
    {
    case 1:
      hashl = 16;	/* MD5 */
      oid = (unsigned char *)"\022\060\040\060\014\006\010\052\206\110\206\367\015\002\005\005\000\004\020";
      break;
    case 2:
      hashl = 20;	/* SHA-1 */
      oid = (unsigned char *)"\017\060\041\060\011\006\005\053\016\003\002\032\005\000\004\024";
      break;
    case 8:
      hashl = 32;	/* SHA-256 */
      oid = (unsigned char *)"\023\060\061\060\015\006\011\140\206\110\001\145\003\004\002\001\005\000\004\040";
      break;
    case 9:
      hashl = 48;	/* SHA-384 */
      oid = (unsigned char *)"\023\060\101\060\015\006\011\140\206\110\001\145\003\004\002\002\005\000\004\060";
      break;
    case 10:
      hashl = 64;	/* SHA-512 */
      oid = (unsigned char *)"\023\060\121\060\015\006\011\140\206\110\001\145\003\004\002\003\005\000\004\100";
      break;
    case 11:
      hashl = 28;	/* SHA-224 */
      oid = (unsigned char *)"\023\060\061\060\015\006\011\140\206\110\001\145\003\004\002\004\005\000\004\034";
      break;
    default:
      return 0;		/* unsupported hash algo */
    }
  if (sigl < 2 + hashl)
    return 0;
  switch (pub[0])
    {
    case 1:		/* RSA */
      {
	const unsigned char *n, *e, *m;
	unsigned char *c;
	int nlen, elen, mlen, clen;
	mp_t *nx, *ex, *mx, *cx;
	int nxl, exl;

        mpi = pub + 1;
        mpil = publ - 1;
	n = findmpi(&mpi, &mpil, 8192, &nlen);
	e = findmpi(&mpi, &mpil, 1024, &elen);
        mpi = sig + 2 + hashl;
        mpil = sigl - (2 + hashl);
	m = findmpi(&mpi, &mpil, nlen, &mlen);
        if (!n || !e || !m || !nlen || !elen)
	  return 0;
	/* build padding block */
	clen = (nlen - 1) / 8;
	if (hashl + *oid + 2 > clen)
	  return 0;
	c = solv_malloc(clen);
	memset(c, 0xff, clen);
	c[0] = 1;
	memcpy(c + clen - hashl, sig + 2, hashl);
	memcpy(c + clen - hashl - *oid, oid + 1, *oid);
	c[clen - hashl - *oid - 1] = 0;
	clen = clen * 8 - 7;	/* always <= nlen */
	nx = mpbuild(n, nlen, nlen, &nxl);
	ex = mpbuild(e, elen, elen, &exl);
	mx = mpbuild(m, mlen, nlen, 0);
	cx = mpbuild(c, clen, nlen, 0);
	free(c);
	res = mprsa(nxl, nx, exl, ex, mx, cx);
	free(nx);
	free(ex);
	free(mx);
	free(cx);
	break;
      }
    case 17:		/* DSA */
      {
	const unsigned char *p, *q, *g, *y, *r, *s;
	int plen, qlen, glen, ylen, rlen, slen, hlen;
	mp_t *px, *qx, *gx, *yx, *rx, *sx, *hx;
	int pxl, qxl, hxl;

        mpi = pub + 1;
        mpil = publ - 1;
	p = findmpi(&mpi, &mpil, 8192, &plen);
	q = findmpi(&mpi, &mpil, 1024, &qlen);
	g = findmpi(&mpi, &mpil, plen, &glen);
	y = findmpi(&mpi, &mpil, plen, &ylen);
        mpi = sig + 2 + hashl;
        mpil = sigl - (2 + hashl);
	r = findmpi(&mpi, &mpil, qlen, &rlen);
	s = findmpi(&mpi, &mpil, qlen, &slen);
        if (!p || !q || !g || !y || !r || !s || !plen || !qlen)
	  return 0;
	hlen = (qlen + 7) & ~7;
	if (hlen > hashl * 8)
	  return 0;
	px = mpbuild(p, plen, plen, &pxl);
	qx = mpbuild(q, qlen, qlen, &qxl);
	gx = mpbuild(g, glen, plen, 0);
	yx = mpbuild(y, ylen, plen, 0);
	rx = mpbuild(r, rlen, qlen, 0);
	sx = mpbuild(s, slen, qlen, 0);
	hx = mpbuild(sig + 2, hlen, hlen, &hxl);
        res = mpdsa(pxl, px, qxl, qx, gx, yx, rx, sx, hxl, hx);
	free(px);
	free(qx);
	free(gx);
	free(yx);
	free(rx);
	free(sx);
	free(hx);
	break;
      }
    default:
      return 0;		/* unsupported pubkey algo */
    }
  return res;
}

