/*
 * Copyright (c) 2004 Rob Braun
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
 * 3. Neither the name of Rob Braun nor the names of its contributors
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
 * 24-Apr-2005
 * DRI: Rob Braun <bbraun@synack.net>
 */

#include "config.h"
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <libgen.h>
#include <sys/fcntl.h>
#include <sys/stat.h>
#include <arpa/inet.h>
#include "xar.h"
#include "arcmod.h"
#include "b64.h"
#include <errno.h>
#include <string.h>
#include "util.h"
#include "linuxattr.h"
#include "io.h"
#include "appledouble.h"
#include "stat.h"

#if defined(HAVE_SYS_XATTR_H)
#include <sys/xattr.h>
#endif

static int Fd;

#if defined(__APPLE__)
#ifdef HAVE_GETATTRLIST
#include <sys/attr.h>
#include <sys/vnode.h>
struct fi {
    uint32_t     length;
    fsobj_type_t objtype;
    char finderinfo[32];
};

static char *Gfinfo = NULL;

/* finfo_read
 * This is for archiving the finderinfo via the getattrlist method.
 * This function is used from the nonea_archive() function.
 */
static int32_t finfo_read(xar_t x, xar_file_t f, void *buf, size_t len) {
	if( len < 32 )
		return -1;

	if( Gfinfo == NULL )
		return 0;

	memcpy(buf, Gfinfo, 32);
	Gfinfo = NULL;
	return 32;
}

/* finfo_write
 * This is for extracting the finderinfo via the setattrlist method.
 * This function is used from the nonea_extract() function.
 */
static int32_t finfo_write(xar_t x, xar_file_t f, void *buf, size_t len) {
	struct attrlist attrs;
	struct fi finfo;

	if( len < 32 )
		return -1;
	if( Gfinfo == NULL )
		return 0;

	memset(&attrs, 0, sizeof(attrs));
	attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
	attrs.commonattr = ATTR_CMN_OBJTYPE | ATTR_CMN_FNDRINFO;

	getattrlist(Gfinfo, &attrs, &finfo, sizeof(finfo), 0);

	attrs.commonattr = ATTR_CMN_FNDRINFO;
	if( setattrlist(Gfinfo, &attrs, buf, 32, 0) != 0 )
		return -1;

	Gfinfo = NULL;
	return 32;
}
#endif /* HAVE_GETATTRLIST */

/* xar_rsrc_read
 * This is the read callback function for archiving the resource fork via
 * the ..namedfork method.  This callback is used from nonea_archive()
 */
static int32_t xar_rsrc_read(xar_t x, xar_file_t f, void *inbuf, size_t bsize) {
	int32_t r;

	while(1) {
		r = read(Fd, inbuf, bsize);
		if( (r < 0) && (errno == EINTR) )
			continue;
		return r;
	}
}
#endif /* __APPLE__ */

/* xar_rsrc_write
 * This is the write callback function for writing the resource fork
 * back to the file via ..namedfork method.  This is the callback used
 * in nonea_extract() and underbar_extract().
 */
static int32_t xar_rsrc_write(xar_t x, xar_file_t f, void *buf, size_t len) {
	int32_t r;
	size_t off = 0;
	do {
		r = write(Fd, buf+off, len-off);
		if( (r < 0) && (errno != EINTR) )
			return r;
		off += r;
	} while( off < len );
	return off;
}

#ifdef __APPLE__
#if defined(HAVE_GETXATTR)
static char *Gbuf = NULL;
static int   Glen = 0;
static int   Goff = 0;

static int32_t xar_ea_read(xar_t x, xar_file_t f, void *buf, size_t len) {
	if( Gbuf == NULL )
		return 0;

	if( (Glen-Goff) <= len ) {
		int siz = Glen-Goff;
		memcpy(buf, Gbuf+Goff, siz);
		free(Gbuf);
		Gbuf = NULL;
		Goff = 0;
		Glen = 0;
		return siz;
	}

	memcpy(buf, Gbuf+Goff, len);
	Goff += len;

	if( Goff == Glen ) {
		free(Gbuf);
		Gbuf = NULL;
		Goff = 0;
		Glen = 0;
	}

	return len;
}

static int32_t xar_ea_write(xar_t x, xar_file_t f, void *buf, size_t len) {
	if( Gbuf == NULL )
		return 0;

	if( Goff == Glen )
		return 0;

	if( (Glen-Goff) <= len ) {
		int siz = Glen-Goff;
		memcpy(Gbuf+Goff, buf, siz);
		return siz;
	}

	memcpy(Gbuf+Goff, buf, len);
	Goff += len;

	return len;
}

static int32_t ea_archive(xar_t x, xar_file_t f, const char* file) {
	char *buf, *i;
	int ret, bufsz;
	int32_t retval = 0;

	ret = listxattr(file, NULL, 0, XATTR_NOFOLLOW);
	if( ret < 0 )
		return -1;
	if( ret == 0 )
		return 0;
	bufsz = ret;

TRYAGAIN:
	buf = malloc(bufsz);
	if( !buf )
		goto TRYAGAIN;
	ret = listxattr(file, buf, bufsz, XATTR_NOFOLLOW);
	if( ret < 0 ) {
		switch(errno) {
		case ERANGE: bufsz = bufsz*2; free(buf); goto TRYAGAIN;
		case ENOTSUP: retval = 0; goto BAIL;
		default: retval = -1; goto BAIL;
		};
	}
	if( ret == 0 ) {
		retval = 0;
		goto BAIL;
	}

	for( i = buf; (i-buf) < ret; i += strlen(i)+1 ) {
		char tempnam[1024];
		ret = getxattr(file, i, NULL, 0, 0, XATTR_NOFOLLOW);
		if( ret < 0 )
			continue;
		Glen = ret;
		Gbuf = malloc(Glen);
		if( !Gbuf )
			goto BAIL;

		ret = getxattr(file, i, Gbuf, Glen, 0, XATTR_NOFOLLOW);
		if( ret < 0 ) {
			free(Gbuf);
			Gbuf = NULL;
			Glen = 0;
			continue;
		}

		memset(tempnam, 0, sizeof(tempnam));
		snprintf(tempnam, sizeof(tempnam)-1, "ea/%s", i);
		xar_attrcopy_to_heap(x, f, tempnam, xar_ea_read);
	}
BAIL:
	free(buf);
	return retval;
}

static int32_t ea_extract(xar_t x, xar_file_t f, const char* file) {
	const char *prop;
	xar_iter_t iter;
	
	iter = xar_iter_new();
	for(prop = xar_prop_first(f, iter); prop; prop = xar_prop_next(iter)) {
		const char *opt;
		char sz[1024];
		int len;

		if( strncmp(prop, XAR_EA_FORK, strlen(XAR_EA_FORK)) )
			continue;
		if( strlen(prop) <= strlen(XAR_EA_FORK) )
			continue;

		memset(sz, 0, sizeof(sz));
		snprintf(sz, sizeof(sz)-1, "%s/size", prop);
		xar_prop_get(f, sz, &opt);
		if( !opt )
			continue;

		len = strtol(opt, NULL, 10);
		Gbuf = malloc(len);
		if( !Gbuf )
			return -1;
		Glen = len;

		xar_attrcopy_from_heap(x, f, prop, xar_ea_write);

		setxattr(file, prop+strlen(XAR_EA_FORK)+1, Gbuf, Glen, 0, XATTR_NOFOLLOW);
		free(Gbuf);
		Gbuf = NULL;
		Glen = 0;
		Goff = 0;
	}

	return 0;
}
#endif /* HAVE_GETXATTR */

/* nonea_archive
 * Archive the finderinfo and resource fork through getattrlist and
 * ..namedfork methods rather than via EAs.  This is mainly for 10.3
 * and earlier support
 */
static int32_t nonea_archive(xar_t x, xar_file_t f, const char* file) {
	char rsrcname[4096];
	struct stat sb;
#ifdef HAVE_GETATTRLIST
	struct attrlist attrs;
	struct fi finfo;
	int ret;
	char z[32];
	
	memset(&attrs, 0, sizeof(attrs));
	attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
	attrs.commonattr = ATTR_CMN_OBJTYPE | ATTR_CMN_FNDRINFO;

	ret = getattrlist(file, &attrs, &finfo, sizeof(finfo), 0);
	if( ret != 0 )
		return -1;

	memset(z, 0, sizeof(z));
	if( memcmp(finfo.finderinfo, z, sizeof(finfo.finderinfo)) != 0 ) {
		Gfinfo = finfo.finderinfo;
		xar_attrcopy_to_heap(x, f, "ea/com.apple.FinderInfo", finfo_read);
	}
#endif /* HAVE_GETATTRLIST */


	memset(rsrcname, 0, sizeof(rsrcname));
	snprintf(rsrcname, sizeof(rsrcname)-1, "%s/..namedfork/rsrc", file);
	if( lstat(rsrcname, &sb) != 0 )
		return 0;

	if( sb.st_size == 0 )
		return 0;

	Fd = open(rsrcname, O_RDONLY, 0);
	if( Fd < 0 )
		return -1;

	xar_attrcopy_to_heap(x, f, "ea/com.apple.ResourceFork", xar_rsrc_read);
	close(Fd);
	return 0;
}

/* nonea_extract
 * Extract the finderinfo and resource fork through setattrlist and
 * ..namedfork methods rather than via EAs.  This is mainly for 10.3
 * and earlier support
 */
static int32_t nonea_extract(xar_t x, xar_file_t f, const char* file) {
	char rsrcname[4096];
#ifdef HAVE_SETATTRLIST
	struct attrlist attrs;
	struct fi finfo;
	int ret;
	
	memset(&attrs, 0, sizeof(attrs));
	attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
	attrs.commonattr = ATTR_CMN_OBJTYPE | ATTR_CMN_FNDRINFO;

	ret = getattrlist(file, &attrs, &finfo, sizeof(finfo), 0);
	if( ret != 0 )
		return -1;

	Gfinfo = (char *)file;

	xar_attrcopy_from_heap(x, f, "ea/com.apple.FinderInfo", finfo_write);
#endif /* HAVE_SETATTRLIST */
	
	memset(rsrcname, 0, sizeof(rsrcname));
	snprintf(rsrcname, sizeof(rsrcname)-1, "%s/..namedfork/rsrc", file);
	Fd = open(rsrcname, O_RDWR|O_TRUNC);
	if( Fd < 0 )
		return 0;

	xar_attrcopy_from_heap(x, f, "ea/com.apple.ResourceFork", xar_rsrc_write);
	close(Fd);
	return 0;
}
#endif /* __APPLE__ */

/* xar_underbar_check
 * Check to see if the file we're archiving is a ._ file.  If so,
 * stop the archival process.
 */
int32_t xar_underbar_check(xar_t x, xar_file_t f, const char* file) {
	char *bname, *tmp;

	tmp = strdup(file);
	bname = basename(tmp);

	if(bname && (bname[0] == '.') && (bname[1] == '_')) {
		free(tmp);
		return 1;
	}

	free(tmp);
	return 0;
}

#ifdef __APPLE__
/* This only really makes sense on OSX */
static int32_t underbar_archive(xar_t x, xar_file_t f, const char* file) {
	struct stat sb;
	char underbarname[4096], z[32];
	char *dname, *bname, *tmp, *tmp2;
	struct AppleSingleHeader ash;
	struct AppleSingleEntry  ase;
	int num_entries = 0, i, r;
	off_t off;

	tmp = strdup(file);
	tmp2 = strdup(file);
	dname = dirname(tmp2);
	bname = basename(tmp);

	memset(underbarname, 0, sizeof(underbarname));
	snprintf(underbarname, sizeof(underbarname)-1, "%s/._%s", dname, bname);
	free(tmp);
	free(tmp2);
	
	if( stat(underbarname, &sb) != 0 )
		return 0;

	Fd = open(underbarname, O_RDONLY);
	if( Fd < 0 )
		return -1;

	memset(&ash, 0, sizeof(ash));
	memset(&ase, 0, sizeof(ase));
	r = read(Fd, &ash, XAR_ASH_SIZE);
	if( r < XAR_ASH_SIZE )
		return -1;

	if( ntohl(ash.magic) != APPLEDOUBLE_MAGIC )
		return -1;
	if( ntohl(ash.version) != APPLEDOUBLE_VERSION )
		return -1;

	off = XAR_ASH_SIZE;
	num_entries = ntohs(ash.entries);

	for(i = 0; i < num_entries; i++) {
		off_t entoff;
		r = read(Fd, &ase, sizeof(ase));
		if( r < sizeof(ase) )
			return -1;
		off+=r;

		if( ntohl(ase.entry_id) == AS_ID_FINDER ) {
			entoff = (off_t)ntohl(ase.offset);
			if( lseek(Fd, entoff, SEEK_SET) == -1 )
				return -1;
			r = read(Fd, z, sizeof(z));
			if( r < sizeof(z) )
				return -1;
			
			Gfinfo = z;
			xar_attrcopy_to_heap(x, f, "ea/com.apple.FinderInfo", finfo_read);
			if( lseek(Fd, (off_t)off, SEEK_SET) == -1 )
				return -1;
		}
		if( ntohl(ase.entry_id) == AS_ID_RESOURCE ) {
			entoff = (off_t)ntohl(ase.offset);
			if( lseek(Fd, entoff, SEEK_SET) == -1 )
				return -1;

			xar_attrcopy_to_heap(x, f, "ea/com.apple.ResourceFork", xar_rsrc_read);

			if( lseek(Fd, (off_t)off, SEEK_SET) == -1 )
				return -1;
		}
	}

	close(Fd);
	return 0;
}
#endif

/* underbar_extract
 * Extract finderinfo and resource fork information to an appledouble
 * ._ file.
 */
static int32_t underbar_extract(xar_t x, xar_file_t f, const char* file) {
	char underbarname[4096];
	char *dname, *bname, *tmp, *tmp2;
	const char *rsrclenstr;
	struct AppleSingleHeader ash;
	struct AppleSingleEntry  ase;
	int num_entries = 0, rsrclen = 0, have_rsrc = 0, have_fi = 0;

	if( xar_prop_get(f, "ea/com.apple.FinderInfo", NULL) == 0 ) {
		have_fi = 1;
		num_entries++;
	}

	if( xar_prop_get(f, "ea/com.apple.ResourceFork", NULL) == 0 ) {
		have_rsrc = 1;
		num_entries++;
	}

	if( num_entries == 0 )
		return 0;

	tmp = strdup(file);
	tmp2 = strdup(file);
	dname = dirname(tmp2);
	bname = basename(tmp);

	memset(underbarname, 0, sizeof(underbarname));
	snprintf(underbarname, sizeof(underbarname)-1, "%s/._%s", dname, bname);
	free(tmp);
	free(tmp2);

	Fd = open(underbarname, O_RDWR | O_CREAT | O_TRUNC, 0);
	if( Fd < 0 )
		return -1;

	xar_prop_get(f, "ea/com.apple.ResourceFork/size", &rsrclenstr);
	if( rsrclenstr ) 
		rsrclen = strtol(rsrclenstr, NULL, 10);

	memset(&ash, 0, sizeof(ash));
	memset(&ase, 0, sizeof(ase));
	ash.magic = htonl(APPLEDOUBLE_MAGIC);
	ash.version = htonl(APPLEDOUBLE_VERSION);
	ash.entries = htons(num_entries);

	write(Fd, &ash, XAR_ASH_SIZE);

	ase.offset = htonl(XAR_ASH_SIZE + ntohs(ash.entries)*12);
	if( have_fi ) {
		ase.entry_id = htonl(AS_ID_FINDER);
		ase.length = htonl(32);
		write(Fd, &ase, 12);
	}

	if( have_rsrc ) {
		ase.entry_id = htonl(AS_ID_RESOURCE);
		ase.offset = htonl(ntohl(ase.offset) + ntohl(ase.length));
		ase.length = htonl(rsrclen);
		write(Fd, &ase, 12);
	}
	
	if( have_fi )
		xar_attrcopy_from_heap(x, f, "ea/com.apple.FinderInfo", xar_rsrc_write);
	if( have_rsrc )
		xar_attrcopy_from_heap(x, f, "ea/com.apple.ResourceFork", xar_rsrc_write);
	close(Fd);

	xar_set_perm(x, f, underbarname);
	
	return 0;
}


int32_t xar_darwinattr_archive(xar_t x, xar_file_t f, const char* file)
{
#if defined(__APPLE__)
#if defined(HAVE_GETXATTR)
	if( ea_archive(x, f, file) == 0 )
		return 0;
#endif
	if( nonea_archive(x, f, file) == 0 )
		return 0;
	return underbar_archive(x, f, file);
#endif /* __APPLE__ */
	return 0;
}

int32_t xar_darwinattr_extract(xar_t x, xar_file_t f, const char* file)
{
#if defined(__APPLE__)
#if defined(HAVE_GETXATTR)
	if( ea_extract(x, f, file) == 0 )
		return 0;
#endif

	if( nonea_extract(x, f, file) == 0 )
		return 0;
#endif /* __APPLE__ */
	return underbar_extract(x, f, file);
}
