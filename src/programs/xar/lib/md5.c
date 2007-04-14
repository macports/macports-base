#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <zlib.h>
#include <openssl/evp.h>

#include "config.h"
#ifndef HAVE_ASPRINTF
#include "asprintf.h"
#endif
#include "xar.h"

static EVP_MD_CTX src_ctx, dst_ctx;
static int initted = 0;

static char* xar_format_md5(const unsigned char* m);

int32_t xar_md5_uncompressed(xar_t x, xar_file_t f, const char *attr, void **in, size_t *inlen) {
	const EVP_MD *md;

	if( !initted ) {
		OpenSSL_add_all_digests();
		md = EVP_get_digestbyname("md5");
		if( md == NULL ) return -1;
		EVP_DigestInit(&src_ctx, md);
		EVP_DigestInit(&dst_ctx, md);
		initted = 1;
	}

	if( *inlen == 0 )
		return 0;

	EVP_DigestUpdate(&src_ctx, *in, *inlen);
	return 0;
}

int32_t xar_md5_compressed(xar_t x, xar_file_t f, const char *attr, void *in, size_t inlen) {
	const EVP_MD *md;

	if( !initted ) {
		OpenSSL_add_all_digests();
		md = EVP_get_digestbyname("md5");
		if( md == NULL ) return -1;
		EVP_DigestInit(&src_ctx, md);
		EVP_DigestInit(&dst_ctx, md);
		initted = 1;
	}

	if( inlen == 0 )
		return 0;

	EVP_DigestUpdate(&dst_ctx, in, inlen);
	return 0;
}

int32_t xar_md5_done(xar_t x, xar_file_t f, const char *attr) {
	unsigned char md5str[EVP_MAX_MD_SIZE];
	char *str, *tmpstr;
	unsigned int len;

	memset(md5str, 0, sizeof(md5str));
	EVP_DigestFinal(&src_ctx, md5str, &len);
	str = xar_format_md5(md5str);
	asprintf(&tmpstr, "%s/extracted-checksum", attr);
	if( f ) {
		xar_prop_set(f, tmpstr, str);
		xar_attr_set(f, tmpstr, "style", "md5");
	}
	free(tmpstr);
	free(str);

	memset(md5str, 0, sizeof(md5str));
	EVP_DigestFinal(&dst_ctx, md5str, &len);
	str = xar_format_md5(md5str);
	asprintf(&tmpstr, "%s/archived-checksum", attr);
	if( f ) {
		xar_prop_set(f, tmpstr, str);
		xar_attr_set(f, tmpstr, "style", "md5");
	}
	free(tmpstr);
	free(str);

	initted = 0;
	return 0;
}

static char* xar_format_md5(const unsigned char* m) {
	char* result = NULL;
	asprintf(&result,
		"%02x%02x%02x%02x"
		"%02x%02x%02x%02x"
		"%02x%02x%02x%02x"
		"%02x%02x%02x%02x",
		m[0], m[1], m[2], m[3],
		m[4], m[5], m[6], m[7],
		m[8], m[9], m[10], m[11],
		m[12], m[13], m[14], m[15]);
	return result;
}

int32_t xar_md5out_done(xar_t x, xar_file_t f, const char *attr) {
	const char *uncomp, *uncompstyle;
	unsigned char md5str[EVP_MAX_MD_SIZE];
	unsigned int len;
	char *tmpstr;

	asprintf(&tmpstr, "%s/extracted-checksum", attr);
	xar_prop_get(f, tmpstr, &uncomp);
	uncompstyle = xar_attr_get(f, tmpstr, "style");
	free(tmpstr);

	if( uncomp && uncompstyle && (strcmp(uncompstyle, "md5")==0) ) {
		char *str;
		memset(md5str, 0, sizeof(md5str));
		EVP_DigestFinal(&dst_ctx, md5str, &len);
		str = xar_format_md5(md5str);
		if(strcmp(uncomp, str) != 0) {
			xar_err_new(x);
			xar_err_set_file(x, f);
			xar_err_set_string(x, "extracted-checksum MD5's do not match");
			xar_err_callback(x, XAR_SEVERITY_FATAL, XAR_ERR_ARCHIVE_EXTRACTION);
		}
		free(str);
	}

	EVP_DigestFinal(&src_ctx, md5str, &len);
	initted = 0;

	return 0;
}
