/* md4_check.c Copyright (C) 2003 Pat Thoyts <patthoyts@users.sourceforge.net>
 *
 * Generate test data to permit comparison of the tcl implementation of MD4
 * against the OpenSSL library implementation.
 *
 * usage: md4_check
 *
 * $Id: md4_check.c,v 1.2 2004/01/15 06:36:13 andreas_kupries Exp $
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <openssl/md4.h>

static const char rcsid[] = 
"$Id: md4_check.c,v 1.2 2004/01/15 06:36:13 andreas_kupries Exp $";

void
md4(const char *buf, size_t len, unsigned char *res)
{
    MD4_CTX ctx;
    MD4_Init(&ctx);
    MD4_Update(&ctx, buf, len);
    MD4_Final(res, &ctx);
}

void
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
    size_t cn;
    char buf[256];
    unsigned char r[16];

    memset(buf, 'a', 256);

    for (cn = 0; cn < 150; cn++) {
        md4(buf, cn, r);
        printf("%7d ", cn);
        dump(r, 16);
    }
    return 0;
}

/*
 * Local variables:
 *   mode: c
 *   indent-tabs-mode: nil
 * End:
 */
