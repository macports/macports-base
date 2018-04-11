/*
 * Copyright (c) 2008-2012, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "pool.h"
#include "util.h"
#include "chksum.h"

#include "md5.h"
#include "sha1.h"
#include "sha2.h"

struct _Chksum {
  Id type;
  int done;
  unsigned char result[64];
  union {
    MD5_CTX md5;
    SHA1_CTX sha1;
    SHA224_CTX sha224;
    SHA256_CTX sha256;
    SHA384_CTX sha384;
    SHA512_CTX sha512;
  } c;
};

Chksum *
solv_chksum_create(Id type)
{
  Chksum *chk;
  chk = solv_calloc(1, sizeof(*chk));
  chk->type = type;
  switch(type)
    {
    case REPOKEY_TYPE_MD5:
      solv_MD5_Init(&chk->c.md5);
      return chk;
    case REPOKEY_TYPE_SHA1:
      solv_SHA1_Init(&chk->c.sha1);
      return chk;
    case REPOKEY_TYPE_SHA224:
      solv_SHA224_Init(&chk->c.sha224);
      return chk;
    case REPOKEY_TYPE_SHA256:
      solv_SHA256_Init(&chk->c.sha256);
      return chk;
    case REPOKEY_TYPE_SHA384:
      solv_SHA384_Init(&chk->c.sha384);
      return chk;
    case REPOKEY_TYPE_SHA512:
      solv_SHA512_Init(&chk->c.sha512);
      return chk;
    default:
      break;
    }
  free(chk);
  return 0;
}

Chksum *
solv_chksum_create_clone(Chksum *chk)
{
  return solv_memdup(chk, sizeof(*chk));
}

int
solv_chksum_len(Id type)
{
  switch (type)
    {
    case REPOKEY_TYPE_MD5:
      return 16;
    case REPOKEY_TYPE_SHA1:
      return 20;
    case REPOKEY_TYPE_SHA224:
      return 28;
    case REPOKEY_TYPE_SHA256:
      return 32;
    case REPOKEY_TYPE_SHA384:
      return 48;
    case REPOKEY_TYPE_SHA512:
      return 64;
    default:
      return 0;
    }
}

Chksum *
solv_chksum_create_from_bin(Id type, const unsigned char *buf)
{
  Chksum *chk;
  int l = solv_chksum_len(type);
  if (buf == 0 || l == 0)
    return 0;
  chk = solv_calloc(1, sizeof(*chk));
  chk->type = type;
  chk->done = 1;
  memcpy(chk->result, buf, l);
  return chk;
}

void
solv_chksum_add(Chksum *chk, const void *data, int len)
{
  if (chk->done)
    return;
  switch(chk->type)
    {
    case REPOKEY_TYPE_MD5:
      solv_MD5_Update(&chk->c.md5, (void *)data, len);
      return;
    case REPOKEY_TYPE_SHA1:
      solv_SHA1_Update(&chk->c.sha1, data, len);
      return;
    case REPOKEY_TYPE_SHA224:
      solv_SHA224_Update(&chk->c.sha224, data, len);
      return;
    case REPOKEY_TYPE_SHA256:
      solv_SHA256_Update(&chk->c.sha256, data, len);
      return;
    case REPOKEY_TYPE_SHA384:
      solv_SHA384_Update(&chk->c.sha384, data, len);
      return;
    case REPOKEY_TYPE_SHA512:
      solv_SHA512_Update(&chk->c.sha512, data, len);
      return;
    default:
      return;
    }
}

const unsigned char *
solv_chksum_get(Chksum *chk, int *lenp)
{
  if (chk->done)
    {
      if (lenp)
        *lenp = solv_chksum_len(chk->type);
      return chk->result;
    }
  switch(chk->type)
    {
    case REPOKEY_TYPE_MD5:
      solv_MD5_Final(chk->result, &chk->c.md5);
      chk->done = 1;
      if (lenp)
	*lenp = 16;
      return chk->result;
    case REPOKEY_TYPE_SHA1:
      solv_SHA1_Final(&chk->c.sha1, chk->result);
      chk->done = 1;
      if (lenp)
	*lenp = 20;
      return chk->result;
    case REPOKEY_TYPE_SHA224:
      solv_SHA224_Final(chk->result, &chk->c.sha224);
      chk->done = 1;
      if (lenp)
	*lenp = 28;
      return chk->result;
    case REPOKEY_TYPE_SHA256:
      solv_SHA256_Final(chk->result, &chk->c.sha256);
      chk->done = 1;
      if (lenp)
	*lenp = 32;
      return chk->result;
    case REPOKEY_TYPE_SHA384:
      solv_SHA384_Final(chk->result, &chk->c.sha384);
      chk->done = 1;
      if (lenp)
	*lenp = 48;
      return chk->result;
    case REPOKEY_TYPE_SHA512:
      solv_SHA512_Final(chk->result, &chk->c.sha512);
      chk->done = 1;
      if (lenp)
	*lenp = 64;
      return chk->result;
    default:
      if (lenp)
	*lenp = 0;
      return 0;
    }
}

Id
solv_chksum_get_type(Chksum *chk)
{
  return chk->type;
}

int
solv_chksum_isfinished(Chksum *chk)
{
  return chk->done != 0;
}

const char *
solv_chksum_type2str(Id type)
{
  switch(type)
    {
    case REPOKEY_TYPE_MD5:
      return "md5";
    case REPOKEY_TYPE_SHA1:
      return "sha1";
    case REPOKEY_TYPE_SHA224:
      return "sha224";
    case REPOKEY_TYPE_SHA256:
      return "sha256";
    case REPOKEY_TYPE_SHA384:
      return "sha384";
    case REPOKEY_TYPE_SHA512:
      return "sha512";
    default:
      return 0;
    }
}

Id
solv_chksum_str2type(const char *str)
{
  if (!strcasecmp(str, "md5"))
    return REPOKEY_TYPE_MD5;
  if (!strcasecmp(str, "sha") || !strcasecmp(str, "sha1"))
    return REPOKEY_TYPE_SHA1;
  if (!strcasecmp(str, "sha224"))
    return REPOKEY_TYPE_SHA224;
  if (!strcasecmp(str, "sha256"))
    return REPOKEY_TYPE_SHA256;
  if (!strcasecmp(str, "sha384"))
    return REPOKEY_TYPE_SHA384;
  if (!strcasecmp(str, "sha512"))
    return REPOKEY_TYPE_SHA512;
  return 0;
}

void *
solv_chksum_free(Chksum *chk, unsigned char *cp)
{
  if (cp)
    {
      const unsigned char *res;
      int l;
      res = solv_chksum_get(chk, &l);
      if (l && res)
        memcpy(cp, res, l);
    }
  solv_free(chk);
  return 0;
}

