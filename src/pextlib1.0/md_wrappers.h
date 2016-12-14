/*
 * md_wrappers.h
 *
 * Copyright (c) 2005 Paul Guyot <pguyot@kallisys.net>.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of The MacPorts Project nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _MD_WRAPPERS_H
#define _MD_WRAPPERS_H

/* wrappers for libmd-like functions:
 * char* ALGOFile(const char* filename, char* buf)
 * char* ALGOEnd(ALGO_CTX, char* buf)
 */

#define CHECKSUMEnd(algo, ctxtype, digest_length)		\
static char *													\
algo##End(ctxtype *ctx, char *buf)						\
{														\
    int i;												\
    unsigned char digest[digest_length];				\
    static const char hex[]="0123456789abcdef";			\
														\
    if (!buf)											\
        buf = malloc(2*digest_length + 1);				\
    if (!buf)											\
        return 0;										\
    algo##Final(digest, ctx);							\
    for (i = 0; i < digest_length; i++) {				\
        buf[i+i] = hex[digest[i] >> 4];					\
        buf[i+i+1] = hex[digest[i] & 0x0f];				\
    }													\
    buf[i+i] = '\0';									\
    return buf;											\
}

#define CHECKSUMFile(algo, ctxtype)						\
static char *algo##File(const char *filename, char *buf)		\
{														\
    unsigned char buffer[BUFSIZ];						\
    ctxtype ctx;										\
    int f,i,j;											\
														\
    algo##Init(&ctx);									\
    f = open(filename,O_RDONLY);						\
    if (f < 0) return 0;								\
    while ((i = read(f,buffer,sizeof buffer)) > 0) {	\
        algo##Update(&ctx,buffer,i);					\
    }													\
    j = errno;											\
    close(f);											\
    errno = j;											\
    if (i < 0) return 0;								\
    return algo##End(&ctx, buf);						\
}

#define CHECKSUMData(algo, ctxtype)						\
static char *algo##Data(const u_char *str, u_int32_t len, char *buf)		\
{														\
    ctxtype ctx;										\
														\
    algo##Init(&ctx);									\
    algo##Update(&ctx,str,len);					        \
    return algo##End(&ctx, buf);						\
}

#endif
/* _MD_WRAPPERS_H */
