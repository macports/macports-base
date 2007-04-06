/*
 * Copyright (c) 2005 Rob Braun
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
 * 3. Neither the name of Rob Braun nor the names of his contributors
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
/*
 * 03-Apr-2005
 * DRI: Rob Braun <bbraun@opendarwin.org>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <zlib.h>
#include "config.h"
#ifndef HAVE_ASPRINTF
#include "asprintf.h"
#endif
#include "xar.h"
#include "filetree.h"
#include "io.h"

static int initted = 0;
static z_stream zs;

int xar_gzip_fromheap_done(xar_t x, xar_file_t f, const char *attr);

int xar_gzip_fromheap_in(xar_t x, xar_file_t f, const char *attr, void **in, size_t *inlen) {
	const char *opt;
	void *out = NULL;
	size_t outlen, offset = 0;
	int r;
	char *tmpstr;

	asprintf(&tmpstr, "%s/encoding", attr);
	opt = xar_attr_get(f, tmpstr, "style");
	free(tmpstr);
	if( !opt ) return 0;
	if( strcmp(opt, "application/x-gzip") != 0 ) return 0;

	if( !initted ) {
		zs.zalloc = Z_NULL;
		zs.zfree = Z_NULL;
		zs.opaque = Z_NULL;

		inflateInit(&zs);
		initted = 1;
	}

	outlen = *inlen;

	zs.next_in = *in;
	zs.avail_in = *inlen;
	zs.next_out = out;
	zs.avail_out = 0;

	while( zs.avail_in != 0 ) {
		outlen = outlen * 2;
		out = realloc(out, outlen);
		if( out == NULL ) abort();

		zs.next_out = out + offset;
		zs.avail_out = outlen - offset;

		r = inflate(&zs, Z_SYNC_FLUSH);
		if( (r != Z_OK) && (r != Z_STREAM_END) ) {
			xar_err_new(x);
			xar_err_set_file(x, f);
			xar_err_set_string(x, "Error decompressing file");
			xar_err_callback(x, XAR_SEVERITY_FATAL, XAR_ERR_ARCHIVE_EXTRACTION);
			return -1;
		}
		offset += outlen - offset - zs.avail_out;
		if( (r == Z_STREAM_END) && (offset == 0) ) {
			//r = inflate(&zs, Z_FINISH);
			xar_gzip_fromheap_done(x, f, attr);
			offset += outlen - offset - zs.avail_out;
			break;
		}
	}

	free(*in);
	*in = out;
	*inlen = offset;
	return 0;
}

int xar_gzip_fromheap_done(xar_t x, xar_file_t f, const char *attr) {
	initted = 0;
	inflateEnd(&zs);
	return 0;
}
int xar_gzip_toheap_done(xar_t x, xar_file_t f, const char *attr) {
	const char *opt;
	char *tmpstr;

	opt = xar_opt_get(x, XAR_OPT_COMPRESSION);
	if( !opt )
		return 0;

	if( strcmp(opt, XAR_OPT_VAL_GZIP) != 0 )
		return 0;

	initted = 0;
	deflateEnd(&zs);

	asprintf(&tmpstr, "%s/encoding", attr);
	if( f ) {
		xar_prop_set(f, tmpstr, NULL);
		xar_attr_set(f, tmpstr, "style", "application/x-gzip");
	}
	free(tmpstr);

	return 0;
}

int32_t xar_gzip_toheap_in(xar_t x, xar_file_t f, const char *attr, void **in, size_t *inlen) {
	void *out = NULL;
	size_t outlen, offset = 0;
	int r;
	const char *opt;

	opt = xar_opt_get(x, XAR_OPT_COMPRESSION);
	if( !opt )
		return 0;

	if( strcmp(opt, XAR_OPT_VAL_GZIP) != 0 )
		return 0;

	if( !initted ) {
		memset(&zs, 0, sizeof(zs));
		deflateInit(&zs, Z_BEST_COMPRESSION);
		initted = 1;
	}

	outlen = *inlen/2;
	if(outlen == 0) outlen = 1024;
	zs.next_in = *in;
	zs.avail_in = *inlen;
	zs.next_out = out;
	zs.avail_out = 0;

	do {
		outlen *= 2;
		out = realloc(out, outlen);
		if( out == NULL ) abort();

		zs.next_out = out + offset;
		zs.avail_out = outlen - offset;

		if( *inlen == 0 )
			r = deflate(&zs, Z_FINISH);
		else
			r = deflate(&zs, Z_SYNC_FLUSH);
		offset = outlen - zs.avail_out;
	} while( zs.avail_in != 0 );

	free(*in);
	*in = out;
	*inlen = offset;
	return 0;
}
