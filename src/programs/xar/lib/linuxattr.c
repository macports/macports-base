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
 * 26-Oct-2004
 * DRI: Rob Braun <bbraun@synack.net>
 */

#include "config.h"
#include <stdio.h>
#include <unistd.h>
#include <libgen.h>
#include "xar.h"
#include "arcmod.h"
#include "b64.h"
#include <errno.h>
#include <string.h>
#include "util.h"
#include "linuxattr.h"
#include "io.h"

#ifdef HAVE_SYS_PARAM_H
#include <sys/param.h>
#endif

#ifdef HAVE_SYS_STATFS_H  /* Nonexistant future OS needs this */
#include <sys/statfs.h>
#endif

#ifdef HAVE_SYS_MOUNT_H
#include <sys/mount.h>
#endif

#ifdef HAVE_SYS_XATTR_H
#include <sys/xattr.h>
#endif

#ifndef EXT3_SUPER_MAGIC
#define EXT3_SUPER_MAGIC 0xEF53
#endif

#ifndef JFS_SUPER_MAGIC
#define JFS_SUPER_MAGIC 0x3153464a
#endif

#ifndef REISERFS_SUPER_MAGIC
#define REISERFS_SUPER_MAGIC 0x52654973
#endif

#ifndef XFS_SUPER_MAGIC
#define XFS_SUPER_MAGIC 0x58465342
#endif

#if defined(HAVE_SYS_XATTR_H) && defined(HAVE_LGETXATTR) && !defined(__APPLE__)
static const char *Gfile = NULL;
static const char *Gattr = NULL;
static void *Gbuf = NULL;
static int Goff = 0;
static int Gbufsz = 0;

int32_t xar_linuxattr_read(xar_t x, xar_file_t f, void * buf, size_t len) {

	if( !Gbuf ) {
		int r;
		Gbufsz = 1024;
AGAIN2:
		Gbuf = malloc(Gbufsz);
		if(!Gbuf)
			goto AGAIN2;
		memset(Gbuf, 0, Gbufsz);
		r = lgetxattr(Gfile, Gattr+strlen(XAR_EA_FORK)+1, Gbuf, Gbufsz);
		if( r < 0 ) {
			switch(errno) {
			case ERANGE: Gbufsz *= 2; free(Gbuf); goto AGAIN2;
			case ENOTSUP: free(Gbuf); return 0;
			default: break;
			};
			return -1;
		}
		Gbufsz = r;
	}

	if( (Gbufsz-Goff) <= len ) {
		int32_t ret;
		ret = Gbufsz - Goff;
		memcpy(buf, Gbuf+Goff, ret);
		Goff += ret;
		return(ret);
	} else {
		memcpy(buf, Gbuf+Goff, len);
		Gbuf += len;
		return len;
	}
}

int32_t xar_linuxattr_write(xar_t x, xar_file_t f, void *buf, size_t len) {
	return lsetxattr(Gfile, Gattr+strlen(XAR_EA_FORK)+1, buf, len, 0);
}
#endif

int32_t xar_linuxattr_archive(xar_t x, xar_file_t f, const char* file)
{
#if defined(HAVE_SYS_XATTR_H) && defined(HAVE_LGETXATTR) && !defined(__APPLE__)
	char *i, *buf = NULL;
	int ret, retval=0, bufsz = 1024;
	struct statfs sfs;
	char *fsname = NULL;

TRYAGAIN:
	buf = malloc(bufsz);
	if(!buf)
		goto TRYAGAIN;
	ret = llistxattr(file, buf, bufsz);
	if( ret < 0 ) {
		switch(errno) {
		case ERANGE: bufsz = bufsz*2; free(buf); goto TRYAGAIN;
		case ENOTSUP: retval = 0; goto BAIL;
		default: retval = -1; goto BAIL;
		};
	}
	if( ret == 0 ) goto BAIL;

	memset(&sfs, 0, sizeof(sfs));
	statfs(file, &sfs);

	switch(sfs.f_type) {
	case EXT3_SUPER_MAGIC: fsname = "ext3"; break; /* assume ext3 */
	case JFS_SUPER_MAGIC:  fsname = "jfs" ; break;
	case REISERFS_SUPER_MAGIC:fsname = "reiser" ; break;
	case XFS_SUPER_MAGIC:  fsname = "xfs" ; break;
	default: retval=0; goto BAIL;
	};

	for( i=buf; (i-buf) < ret; i += strlen(i)+1 ) {
		char tmpnam[1024];

		Gbufsz = 0;
		Goff = 0;
		Gbuf = NULL;
		Gfile = file;
		memset(tmpnam, 0, sizeof(tmpnam));
		snprintf(tmpnam, sizeof(tmpnam)-1, "%s/%s", XAR_EA_FORK, i);
		xar_prop_set(f, tmpnam, NULL);
		xar_attr_set(f, tmpnam, "fstype", fsname);
		Gattr = tmpnam;
		xar_attrcopy_to_heap(x, f, tmpnam, xar_linuxattr_read);
		free(Gbuf);
		Gattr = NULL;
	}

BAIL:
	free(buf);
	return retval;
#endif
	return 0;
}

int32_t xar_linuxattr_extract(xar_t x, xar_file_t f, const char* file)
{
#if defined HAVE_SYS_XATTR_H && defined(HAVE_LSETXATTR) && !defined(__APPLE__)
	const char *fsname = "bogus";
	const char *prop;
	struct statfs sfs;
	int eaopt = 0;
	xar_iter_t iter;


	/* Check for EA extraction behavior */

	memset(&sfs, 0, sizeof(sfs));
	if( statfs(file, &sfs) != 0 ) {
		char *tmp, *bname;
		tmp = strdup(file);
		bname = dirname(tmp);
		statfs(bname, &sfs);
		free(tmp);
	}
	switch(sfs.f_type) {
	case EXT3_SUPER_MAGIC: fsname = "ext3"; break; /* assume ext3 */
	case JFS_SUPER_MAGIC:  fsname = "jfs" ; break;
	case REISERFS_SUPER_MAGIC:fsname = "reiser" ; break;
	case XFS_SUPER_MAGIC:  fsname = "xfs" ; break;
	};

	iter = xar_iter_new();
	for(prop = xar_prop_first(f, iter); prop; prop = xar_prop_next(iter)) {
		const char *fs;

		if( strncmp(prop, XAR_EA_FORK, strlen(XAR_EA_FORK)) != 0 )
			continue;
		if( strlen(prop) <= strlen(XAR_EA_FORK) )
			continue;

		fs = xar_attr_get(f, prop, "fstype");
		if( !eaopt && fs && strcmp(fs, fsname) != 0 ) {
			continue;
		}
		if( !fs )
			continue;

		Gfile = file;
		Gattr = prop;
		xar_attrcopy_from_heap(x, f, prop, xar_linuxattr_write);

	}
	xar_iter_free(iter);

#endif
	return 0;
}
