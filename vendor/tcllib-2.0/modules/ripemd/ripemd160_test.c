/* ripemd160_check.c Copyright (C) 2004 Pat Thoyts <patthoyts@users.sf.net>
 *
 * Generate test data to permit comparison of the tcl implementation of
 * RIPE-MD160 against the OpenSSL library implementation.
 *
 * usage: ripemd_test
 *
 * $Id: ripemd160_test.c,v 1.1 2004/12/03 12:03:33 patthoyts Exp $
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <openssl/ripemd.h>
#include <openssl/hmac.h>

static const char rcsid[] = 
"$Id: ripemd160_test.c,v 1.1 2004/12/03 12:03:33 patthoyts Exp $";

typedef unsigned char uchar;

typedef struct {
    size_t       len;
    const uchar *dat;
} vector_t;

typedef struct {
    size_t       keylen;
    const uchar *key;
    size_t       len;
    const uchar *dat;
} hvector_t;

static const vector_t vectors[] = {
    { 0,  "" },
    { 1,  "a" },
    { 3,  "abc" },
    { 14, "message digest" },
    { 26, "abcdefghijklmnopqrstuvwxyz" },
    { 56, "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" },
    { 62, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"},
    { 1,  "-" },
    { 6,  "-error" }
};

static const uchar U0[] = {0x0b,0x0b,0x0b,0x0b,0x0b,0x0b,0x0b,0x0b,0x0b,0x0b,
                           0x0b,0x0b,0x0b,0x0b,0x0b,0x0b,0x0b,0x0b,0x0b,0x0b};
static const uchar U1[] = {0xaa,0xaa,0xaa,0xaa,0xaa,0xaa,0xaa,0xaa,0xaa,0xaa,
                           0xaa,0xaa,0xaa,0xaa,0xaa,0xaa,0xaa,0xaa,0xaa,0xaa};
static const uchar U2[] = {0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,
                           0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,
                           0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,
                           0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,
                           0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd,0xdd};
static const uchar U3[] = {0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,
                           0x0b,0x0c,0x0d,0x0e,0x0f,0x10,0x11,0x12,0x13,0x14,
                           0x15,0x16,0x17,0x18,0x19};
static const uchar U4[] = {0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,
                           0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,
                           0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,
                           0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,
                           0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd,0xcd};
static const uchar U5[] = {0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,
                           0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c};
static const uchar U6[] = {0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,
                           0xaa,0xbb,0xcc,0xdd,0xee,0xff,0x01,0x23,0x45,0x67};
static const uchar U7[] = {0x01,0x23,0x45,0x67,0x89,0xab,0xcd,0xef,0xfe,0xdc,
                           0xba,0x98,0x76,0x54,0x32,0x10,0x00,0x11,0x22,0x33};

static const hvector_t hvectors[] = {
    { 20, U0, 8, "Hi There" },
    { 4, "Jefe", 28, "what do ya want for nothing?" },
    { 20, U1, 50, U2 },
    { 25, U3, 50, U4 },
    { 20, U5, 20, "Test With Truncation" },
};

static void
digest(const char *data, size_t len, unsigned char *res)
{
    RIPEMD160_CTX ctx;
    RIPEMD160_Init(&ctx);
    RIPEMD160_Update(&ctx, data, len);
    RIPEMD160_Final(res, &ctx);
}

static void
hmac(const unsigned char *data, size_t len, 
     const unsigned char *key, size_t keylen, 
     unsigned char *res, size_t *reslen)
{
    /*
      HMAC_CTX ctx;
      HMAC_CTX_init(&ctx);
      HMAC_Init(&ctx, key, keylen, EVP_ripemd160());
      HMAC_Update(&ctx, data, len);
      HMAC_Final(&ctx, res, reslen);
    */
    HMAC(EVP_ripemd160(), key, keylen, data, len, res, reslen);
}

static void
dump(unsigned char *data, size_t len)
{
    char buf[80], *p;
    size_t cn, n;

    for (cn = 0, p = buf; cn < len; cn++, p += 2) {
        n = sprintf(p, "%02X", data[cn]);
    }
    puts(buf);
}

int
main(int argc, char *argv[])
{
    size_t n;
    size_t hashlen = 20;
    unsigned char hash[EVP_MAX_MD_SIZE];

    puts("RIPEMD-160 digests (tcllib tests)");
    for (n = 0; n < sizeof(vectors)/sizeof(vectors[0]); n++) {
        digest(vectors[n].dat, vectors[n].len, hash);
        printf("HASH %2u: ", n+1);
        dump(hash, hashlen);
    }

    puts("HMAC-RIPEMD-160 digests (tcllib test key 1)");
    for (n = 0; n < sizeof(vectors)/sizeof(vectors[0]); n++) {
        hmac(vectors[n].dat, vectors[n].len, U6, 20, hash, &hashlen);
        printf("HMAC %2u: ", n+1);
        dump(hash, hashlen);
    }
    
    puts("HMAC-RIPEMD-160 digests (tcllib test key 2)");
    for (n = 0; n < sizeof(vectors)/sizeof(vectors[0]); n++) {
        hmac(vectors[n].dat, vectors[n].len, U7, 20, hash, &hashlen);
        printf("HMAC %2u: ", n+1);
        dump(hash, hashlen);
    }

    puts("RFC2286 HMAC-RIPEMD-160 test vectors");
    for (n = 0; n < sizeof(hvectors)/sizeof(hvectors[0]); n++) {
        hmac(hvectors[n].dat, hvectors[n].len, 
             hvectors[n].key, hvectors[n].keylen,
             hash, &hashlen);
        printf("HMAC %2u: ", n+1);
        dump(hash, hashlen);
    }

    return 0;
}

/*
 * Local variables:
 *   mode: c
 *   indent-tabs-mode: nil
 * End:
 */
