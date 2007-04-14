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
/*
 * Portions copyright 2003, Apple Computer, Inc.
 * filetype_name() and associated structure.
 * DRI: Kevin Van Vechten <kvv@apple.com>
 */
#define _FILE_OFFSET_BITS 64

#include "config.h"
#ifndef HAVE_ASPRINTF
#include "asprintf.h"
#endif
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <inttypes.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/fcntl.h>
#include <time.h>
#include <pwd.h>
#include <grp.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include <errno.h>
#include <libxml/hash.h>
#include <libxml/xmlstring.h>
#ifdef HAVE_SYS_ACL_H
#include <sys/acl.h>
#endif
#include "xar.h"
#include "arcmod.h"
#include "archive.h"

#ifndef LLONG_MIN
#define LLONG_MIN LONG_LONG_MIN
#endif

#ifndef LLONG_MAX
#define LLONG_MAX LONG_LONG_MAX
#endif

static struct {
	const char *name;
	mode_t type;
} filetypes [] = {
	{ "file", S_IFREG },
	{ "directory", S_IFDIR },
	{ "symlink", S_IFLNK },
	{ "fifo", S_IFIFO },
	{ "character special", S_IFCHR },
	{ "block special", S_IFBLK },
	{ "socket", S_IFSOCK },
#ifdef S_IFWHT
	{ "whiteout", S_IFWHT },
#endif
	{ NULL, 0 }
};

static const char * filetype_name (mode_t mode) {
	unsigned int i;
	for (i = 0; filetypes[i].name; i++)
		if (mode == filetypes[i].type)
			return (filetypes[i].name);
	return ("unknown");
}

static xar_file_t xar_link_lookup(xar_t x, dev_t dev, ino_t ino, xar_file_t f) {
	char key[32];
	xar_file_t ret;

	memset(key, 0, sizeof(key));
	snprintf(key, sizeof(key)-1, "%08" DEV_HEXSTRING "%08" INO_HEXSTRING, DEV_CAST dev, INO_CAST ino);
	ret = xmlHashLookup(XAR(x)->ino_hash, BAD_CAST(key));
	if( ret == NULL ) {
		xmlHashAddEntry(XAR(x)->ino_hash, BAD_CAST(key), XAR_FILE(f));
		return NULL;
	}
	return ret;
}

static int32_t aacls(xar_file_t f, const char *file) {
#ifdef HAVE_SYS_ACL_H
	acl_t a;
	const char *type;

	xar_prop_get(f, "type", &type);
	if( !type || (strcmp(type, "symlink") == 0) )
		return 0;

	a = acl_get_file(file, ACL_TYPE_DEFAULT);
	if( a ) {
		char *t;
		acl_entry_t e;

		/* If the acl is empty, or not valid, skip it */
		if( acl_get_entry(a, ACL_FIRST_ENTRY, &e) != 1 )
			goto NEXT;

		t = acl_to_text(a, NULL);
		if( t ) {
			xar_prop_set(f, "acl/default", t);
			acl_free(t);
		}
		acl_free(a);
	}
NEXT:

	a = acl_get_file(file, ACL_TYPE_ACCESS);
	if( a ) {
		char *t;
		acl_entry_t e;

		/* If the acl is empty, or not valid, skip it */
		if( acl_get_entry(a, ACL_FIRST_ENTRY, &e) != 1 )
			goto DONE;

		t = acl_to_text(a, NULL);
		if( t ) {
			xar_prop_set(f, "acl/access", t);
			acl_free(t);
		}
		acl_free(a);
	}
DONE:
#endif
	return 0;
}

static int32_t eacls(xar_t x, xar_file_t f, const char *file) {
#ifdef HAVE_SYS_ACL_H
	const char *t;
	acl_t a;
	const char *type;

	xar_prop_get(f, "type", &type);
	if( !type || (strcmp(type, "symlink") == 0) )
		return 0;


	xar_prop_get(f, "acl/default", &t);
	if( t ) {
		a = acl_from_text(t);
		if( !a ) {
			xar_err_new(x);
			xar_err_set_errno(x, errno);
			xar_err_set_string(x, "Error extracting default acl from toc");
			xar_err_set_file(x, f);
			xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_EXTRACTION);
		} else {
			if( acl_set_file(file, ACL_TYPE_DEFAULT, a) != 0 ) {
				xar_err_new(x);
				xar_err_set_errno(x, errno);
				xar_err_set_string(x, "Error setting default acl");
				xar_err_set_file(x, f);
				xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_EXTRACTION);
			}
		}
	}

	xar_prop_get(f, "acl/access", &t);
	if( t ) {
		a = acl_from_text(t);
		if( !a ) {
			xar_err_new(x);
			xar_err_set_errno(x, errno);
			xar_err_set_string(x, "Error extracting access acl from toc");
			xar_err_set_file(x, f);
			xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_EXTRACTION);
		} else {
			if( acl_set_file(file, ACL_TYPE_ACCESS, a) != 0 ) {
				xar_err_new(x);
				xar_err_set_errno(x, errno);
				xar_err_set_string(x, "Error setting access acl");
				xar_err_set_file(x, f);
				xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_EXTRACTION);
			}
		}
	}
#endif
	return 0;
}

int32_t xar_stat_archive(xar_t x, xar_file_t f, const char *file) {
	char *tmpstr;
	struct passwd *pw;
	struct group *gr;
	char time[128];
	struct tm t;
	const char *type;

	if( S_ISREG(XAR(x)->sbcache.st_mode) && (XAR(x)->sbcache.st_nlink > 1) ) {
		xar_file_t tmpf;
		const char *id = xar_attr_get(f, NULL, "id");
		if( !id ) {
			xar_err_new(x);
			xar_err_set_file(x, f);
			xar_err_set_string(x, "stat: No file id for file");
			xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_CREATION);
			return -1;
		}
		tmpf = xar_link_lookup(x, XAR(x)->sbcache.st_dev, XAR(x)->sbcache.st_ino, f);
		xar_prop_set(f, "type", "hardlink");
		if( tmpf ) {
			const char *id;
			id = xar_attr_get(tmpf, NULL, "id");
			xar_attr_set(f, "type", "link", id);
		} else {
			xar_attr_set(f, "type", "link", "original");
		}
	} else {
		type = filetype_name(XAR(x)->sbcache.st_mode & S_IFMT);
		xar_prop_set(f, "type", type);
	}

	if( S_ISLNK(XAR(x)->sbcache.st_mode) ) {
		char link[4096];
		struct stat lsb;

		memset(link, 0, sizeof(link));
		readlink(file, link, sizeof(link)-1);
		xar_prop_set(f, "link", link);
		if( stat(file, &lsb) != 0 ) {
			xar_attr_set(f, "link", "type", "broken");
		} else {
			type = filetype_name(lsb.st_mode & S_IFMT);
			xar_attr_set(f, "link", "type", type);
		}
	}

	asprintf(&tmpstr, "%04o", XAR(x)->sbcache.st_mode & (~S_IFMT));
	xar_prop_set(f, "mode", tmpstr);
	free(tmpstr);

	asprintf(&tmpstr, "%"PRIu64, (uint64_t)XAR(x)->sbcache.st_uid);
	xar_prop_set(f, "uid", tmpstr);
	free(tmpstr);

	pw = getpwuid(XAR(x)->sbcache.st_uid);
	if( pw )
		xar_prop_set(f, "user", pw->pw_name);

	asprintf(&tmpstr, "%"PRIu64, (uint64_t)XAR(x)->sbcache.st_gid);
	xar_prop_set(f, "gid", tmpstr);
	free(tmpstr);

	gr = getgrgid(XAR(x)->sbcache.st_gid);
	if( gr )
		xar_prop_set(f, "group", gr->gr_name);

	gmtime_r(&XAR(x)->sbcache.st_atime, &t);
	memset(time, 0, sizeof(time));
	strftime(time, sizeof(time), "%FT%T", &t);
	strcat(time, "Z");
	xar_prop_set(f, "atime", time);

	gmtime_r(&XAR(x)->sbcache.st_mtime, &t);
	memset(time, 0, sizeof(time));
	strftime(time, sizeof(time), "%FT%T", &t);
	strcat(time, "Z");
	xar_prop_set(f, "mtime", time);

	gmtime_r(&XAR(x)->sbcache.st_ctime, &t);
	memset(time, 0, sizeof(time));
	strftime(time, sizeof(time), "%FT%T", &t);
	strcat(time, "Z");
	xar_prop_set(f, "ctime", time);

	aacls(f, file);

	return 0;
}

int32_t xar_set_perm(xar_t x, xar_file_t f, const char *file) {
	const char *opt;
	int32_t m=0, mset=0;
	uid_t u;
	gid_t g;
	const char *timestr;
	struct tm t;
	enum {ATIME=0, MTIME};
	struct timeval tv[2];

	/* in case we don't find anything useful in the archive */
	u = geteuid();
	g = getegid();

	opt = xar_opt_get(x, XAR_OPT_OWNERSHIP);
	if( opt && (strcmp(opt, XAR_OPT_VAL_SYMBOLIC) == 0) ) {
		struct passwd *pw;
		struct group *gr;

		xar_prop_get(f, "user", &opt);
		if( opt ) {
			pw = getpwnam(opt);
			if( pw ) {
				u = pw->pw_uid;
			}
		}
		xar_prop_get(f, "group", &opt);
		if( opt ) {
			gr = getgrnam(opt);
			if( gr ) {
				g = gr->gr_gid;
			}
		}
	}
	if( opt && (strcmp(opt, XAR_OPT_VAL_NUMERIC) == 0) ) {
		xar_prop_get(f, "uid", &opt);
		if( opt ) {
			long long tmp;
			tmp = strtol(opt, NULL, 10);
			if( ( (tmp == LLONG_MIN) || (tmp == LLONG_MAX) ) && (errno == ERANGE) ) {
				return -1;
			}
			u = (uid_t)tmp;
		}

		xar_prop_get(f, "gid", &opt);
		if( opt ) {
			long long tmp;
			tmp = strtol(opt, NULL, 10);
			if( ( (tmp == LLONG_MIN) || (tmp == LLONG_MAX) ) && (errno == ERANGE) ) {
				return -1;
			}
			g = (gid_t)tmp;
		}
	}


	xar_prop_get(f, "mode", &opt);
	if( opt ) {
		long long tmp;
		tmp = strtoll(opt, NULL, 8);
		if( ( (tmp == LLONG_MIN) || (tmp == LLONG_MAX) ) && (errno == ERANGE) ) {
			return -1;
		}
		m = (mode_t)tmp;
		mset = 1;
	}

	xar_prop_get(f, "type", &opt);
	if( opt && (strcmp(opt, "symlink") == 0) ) {
#ifndef __APPLE__
		if( lchown(file, u, g) ) {
			xar_err_new(x);
			xar_err_set_file(x, f);
			xar_err_set_string(x, "perm: could not lchown symlink");
			xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_EXTRACTION);
		}
#ifndef __linux__
		if( mset )
			if( lchmod(file, m) ) {
				xar_err_new(x);
				xar_err_set_file(x, f);
				xar_err_set_string(x, "perm: could not lchmod symlink");
				xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_EXTRACTION);
			}
#endif
#endif /* __APPLE__ */
	} else {
		if( chown(file, u, g) ) {
			xar_err_new(x);
			xar_err_set_file(x, f);
			xar_err_set_string(x, "perm: could not chown file");
			xar_err_set_errno(x, errno);
			xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_EXTRACTION);
		}
		if( mset )
			if( chmod(file, m) ) {
				xar_err_new(x);
				xar_err_set_file(x, f);
				xar_err_set_string(x, "perm: could not chmod file");
				xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_EXTRACTION);
			}
	}

	eacls(x, f, file);

	memset(tv, 0, sizeof(struct timeval) * 2);
	xar_prop_get(f, "atime", &timestr);
	if( timestr ) {
		memset(&t, 0, sizeof(t));
		strptime(timestr, "%FT%T", &t);
		tv[ATIME].tv_sec = timegm(&t);
	} else {
		tv[ATIME].tv_sec = time(NULL);
	}

	xar_prop_get(f, "mtime", &timestr);
	if( timestr ) {
		memset(&t, 0, sizeof(t));
		strptime(timestr, "%FT%T", &t);
		tv[MTIME].tv_sec = timegm(&t);
	} else {
		tv[MTIME].tv_sec = time(NULL);
	}
	utimes(file, tv);

	return 0;
}

int32_t xar_stat_extract(xar_t x, xar_file_t f, const char *file) {
	const char *opt;
	int ret, fd;

	xar_prop_get(f, "type", &opt);
	if(opt && (strcmp(opt, "directory") == 0)) {
		ret = mkdir(file, 0700);
		if( (ret != 0) && (errno != EEXIST) ) {
			xar_err_new(x);
			xar_err_set_file(x, f);
			xar_err_set_string(x, "stat: Could not create directory");
			xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_EXTRACTION);
			return ret;
		}
		return 0;
	}
	if(opt && (strcmp(opt, "symlink") == 0)) {
		xar_prop_get(f, "link", &opt);
		if( opt ) {
			unlink(file);
			ret = symlink(opt, file);
			if( ret != 0 ) {
				xar_err_new(x);
				xar_err_set_file(x, f);
				xar_err_set_string(x, "stat: Could not create symlink");
				xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_EXTRACTION);
			}
			return ret;
		}
	}
	if(opt && (strcmp(opt, "hardlink") == 0)) {
		xar_file_t tmpf;
		opt = xar_attr_get(f, "type", "link");
		if( !opt )
			return 0;
		if( strcmp(opt, "original") == 0 )
			goto CREATEFILE;

		tmpf = xmlHashLookup(XAR(x)->link_hash, BAD_CAST(opt));
		if( !tmpf ) {
			xar_err_new(x);
			xar_err_set_file(x, f);
			xar_err_set_string(x, "stat: Encountered hardlink with no original");
			xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_EXTRACTION);
			return -1;
		}

		unlink(file);
		if( link(XAR_FILE(tmpf)->fspath, file) != 0 ) {
			if( errno == ENOENT ) {
				xar_iter_t i;
				const char *ptr;
				i = xar_iter_new(x);
				for(ptr = xar_prop_first(tmpf, i); ptr; ptr = xar_prop_next(i)) {
					xar_iter_t a;
					const char *val = NULL;
					const char *akey, *aval;
					if( strncmp("data", ptr, 4) != 0 )
						continue;
	
					if( xar_prop_get(tmpf, ptr, &val) )
						continue;
	
					xar_prop_set(f, ptr, val);
					a = xar_iter_new(x);
					for(akey = xar_attr_first(tmpf, ptr, a); akey; akey = xar_attr_next(a)) {
						aval = xar_attr_get(tmpf, ptr, akey);
						xar_attr_set(f, ptr, akey, aval);
					}
					xar_iter_free(a);
				}
				xar_iter_free(i);
				xar_attr_set(f, "type", "link", "original");
				return 0;
			} else {
				xar_err_new(x);
				xar_err_set_file(x, f);
				xar_err_set_string(x, "stat: Could not link hardlink to original");
				xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_EXTRACTION);
				return -1;
			}
		}
		return 0;
	}

CREATEFILE:
	unlink(file);
	fd = open(file, O_RDWR|O_CREAT|O_TRUNC, 0600);
	if( fd > 0 )
		close(fd);
	return 0;
}
