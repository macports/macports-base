/*	$NetBSD: compare.c,v 1.5 2003/02/21 11:19:19 grant Exp $	*/

/*-
 * Copyright (c) 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#if HAVE_SYS_CDEFS_H
#include <sys/cdefs.h>
#endif

#if defined(__RCSID) && !defined(lint)
#if 0
static char sccsid[] = "@(#)compare.c	8.1 (Berkeley) 6/6/93";
#else
__RCSID("$NetBSD: compare.c,v 1.5 2003/02/21 11:19:19 grant Exp $");
#endif
#endif /* not lint */

#include <sys/param.h>

#ifdef HAVE_SYS_STAT_H
#include <sys/stat.h>
#endif

#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif

#include <errno.h>

#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#endif

#include <stdio.h>

#ifdef HAVE_STRING_H
#include <string.h>
#endif

#ifdef HAVE_TIME_H
#include <time.h>
#endif

#include <unistd.h>

#ifdef HAVE_MD5_H
#include <md5.h>
#endif

#ifdef HAVE_RMD160_H
#include <rmd160.h>
#endif

#ifdef HAVE_SHA1_H
#include <sha1.h>
#endif

#include "extern.h"

#define	INDENTNAMELEN	8
#define MARK								\
do {									\
	len = printf("%s: ", RP(p));					\
	if (len > INDENTNAMELEN) {					\
		tab = "\t";						\
		printf("\n");						\
	} else {							\
		tab = "";						\
		printf("%*s", INDENTNAMELEN - (int)len, "");		\
	}								\
} while (/* CONSTCOND */0)
#define	LABEL if (!label++) MARK

#define CHANGEFLAGS(path, oflags)					\
	if (flags != (oflags)) {					\
		if (!label) {						\
			MARK;						\
			printf("%sflags (\"%s\"", tab,			\
			    flags_to_string(p->fts_statp->st_flags, "none")); \
		}							\
		if (lchflags(path, flags)) {				\
			label++;					\
			printf(", not modified: %s)\n",			\
			    strerror(errno));				\
		} else							\
			printf(", modified to \"%s\")\n",		\
			     flags_to_string(flags, "none"));		\
	}

/* SETFLAGS:
 * given pflags, additionally set those flags specified in sflags and
 * selected by mask (the other flags are left unchanged). oflags is
 * passed as reference to check if lchflags is necessary.
 */
#define SETFLAGS(path, sflags, pflags, oflags, mask)			\
do {									\
	flags = ((sflags) & (mask)) | (pflags);				\
	CHANGEFLAGS(path, oflags);					\
} while (0)

/* CLEARFLAGS:
 * given pflags, reset the flags specified in sflags and selected by mask
 * (the other flags are left unchanged). oflags is
 * passed as reference to check if lchflags is necessary.
 */
#define CLEARFLAGS(path, sflags, pflags, oflags, mask)			\
do {									\
	flags = (~((sflags) & (mask)) & CH_MASK) & (pflags);		\
	CHANGEFLAGS(path, oflags);					\
} while (0)

int
compare(NODE *s, FTSENT *p)
{
	u_int32_t len, val;
#if HAVE_STRUCT_STAT_ST_FLAGS
	u_int32_t flags;
#endif
	int fd, label;
	const char *cp, *tab;
#if !defined(NO_MD5) || !defined(NO_RMD160) || !defined(NO_SHA1)
	char digestbuf[41];	/* large enough for {MD5,RMD160,SHA1}File() */
#endif

	tab = NULL;
	label = 0;
	switch(s->type) {
	case F_BLOCK:
		if (!S_ISBLK(p->fts_statp->st_mode))
			goto typeerr;
		break;
	case F_CHAR:
		if (!S_ISCHR(p->fts_statp->st_mode))
			goto typeerr;
		break;
	case F_DIR:
		if (!S_ISDIR(p->fts_statp->st_mode))
			goto typeerr;
		break;
	case F_FIFO:
		if (!S_ISFIFO(p->fts_statp->st_mode))
			goto typeerr;
		break;
	case F_FILE:
		if (!S_ISREG(p->fts_statp->st_mode))
			goto typeerr;
		break;
	case F_LINK:
		if (!S_ISLNK(p->fts_statp->st_mode))
			goto typeerr;
		break;
	case F_SOCK:
		if (!S_ISSOCK(p->fts_statp->st_mode)) {
 typeerr:		LABEL;
			printf("\ttype (%s, %s)\n",
			    nodetype(s->type), inotype(p->fts_statp->st_mode));
			return (label);
		}
		break;
	}
	if (Wflag)
		goto afterpermwhack;
#if HAVE_STRUCT_STAT_ST_FLAGS
	if (iflag && !uflag) {
		if (s->flags & F_FLAGS)
		    SETFLAGS(p->fts_accpath, s->st_flags,
			p->fts_statp->st_flags, p->fts_statp->st_flags,
			SP_FLGS);
		return (label);
        }
	if (mflag && !uflag) {
		if (s->flags & F_FLAGS)
		    CLEARFLAGS(p->fts_accpath, s->st_flags,
			p->fts_statp->st_flags, p->fts_statp->st_flags,
			SP_FLGS);
		return (label);
        }
#endif
	if (s->flags & F_DEV &&
	    (s->type == F_BLOCK || s->type == F_CHAR) &&
	    s->st_rdev != p->fts_statp->st_rdev) {
		LABEL;
		printf("%sdevice (%#x, %#x",
		    tab, (unsigned int)s->st_rdev, (unsigned int)p->fts_statp->st_rdev);
		if (uflag) {
			if ((unlink(p->fts_accpath) == -1) ||
			    (mknod(p->fts_accpath,
			      s->st_mode | nodetoino(s->type),
			      s->st_rdev) == -1) ||
#if HAVE_LCHOWN
			    (lchown(p->fts_accpath, p->fts_statp->st_uid,
#else
			    (chown(p->fts_accpath, p->fts_statp->st_uid,
#endif
			      p->fts_statp->st_gid) == -1) )
				printf(", not modified: %s)\n",
				    strerror(errno));
			 else
				printf(", modified)\n");
		} else
			printf(")\n");
		tab = "\t";
	}
	/* Set the uid/gid first, then set the mode. */
	if (s->flags & (F_UID | F_UNAME) && s->st_uid != p->fts_statp->st_uid) {
		LABEL;
		printf("%suser (%lu, %lu",
		    tab, (u_long)s->st_uid, (u_long)p->fts_statp->st_uid);
		if (uflag) {
#if HAVE_LCHOWN
			if (lchown(p->fts_accpath, s->st_uid, -1))
#else
			if (chown(p->fts_accpath, s->st_uid, -1))
#endif
				printf(", not modified: %s)\n",
				    strerror(errno));
			else
				printf(", modified)\n");
		} else
			printf(")\n");
		tab = "\t";
	}
	if (s->flags & (F_GID | F_GNAME) && s->st_gid != p->fts_statp->st_gid) {
		LABEL;
		printf("%sgid (%lu, %lu",
		    tab, (u_long)s->st_gid, (u_long)p->fts_statp->st_gid);
		if (uflag) {
#if HAVE_LCHOWN
			if (lchown(p->fts_accpath, -1, s->st_gid))
#else
			if (chown(p->fts_accpath, -1, s->st_gid))
#endif
				printf(", not modified: %s)\n",
				    strerror(errno));
			else
				printf(", modified)\n");
		}
		else
			printf(")\n");
		tab = "\t";
	}
	if (s->flags & F_MODE &&
	    s->st_mode != (p->fts_statp->st_mode & MBITS)) {
		if (lflag) {
			mode_t tmode, mode;

			tmode = s->st_mode;
			mode = p->fts_statp->st_mode & MBITS;
			/*
			 * if none of the suid/sgid/etc bits are set,
			 * then if the mode is a subset of the target,
			 * skip.
			 */
			if (!((tmode & ~(S_IRWXU|S_IRWXG|S_IRWXO)) ||
			    (mode & ~(S_IRWXU|S_IRWXG|S_IRWXO))))
				if ((mode | tmode) == tmode)
					goto skip;
		}

		LABEL;
		printf("%spermissions (%#lo, %#lo",
		    tab, (u_long)s->st_mode,
		    (u_long)p->fts_statp->st_mode & MBITS);
		if (uflag) {
#if HAVE_LCHMOD
			if (lchmod(p->fts_accpath, s->st_mode))
#else
			if (S_ISLNK(p->fts_statp->st_mode))
				printf(", not modified: no lchmod call\n");
			else if (chmod(p->fts_accpath, s->st_mode))
#endif
				printf(", not modified: %s)\n",
				    strerror(errno));
			else
				printf(", modified)\n");
		}
		else
			printf(")\n");
		tab = "\t";
	skip:	;
	}
	if (s->flags & F_NLINK && s->type != F_DIR &&
	    s->st_nlink != p->fts_statp->st_nlink) {
		LABEL;
		printf("%slink count (%lu, %lu)\n",
		    tab, (u_long)s->st_nlink, (u_long)p->fts_statp->st_nlink);
		tab = "\t";
	}
	if (s->flags & F_SIZE && s->st_size != p->fts_statp->st_size) {
		LABEL;
		printf("%ssize (%lld, %lld)\n",
		    tab, (long long)s->st_size,
		    (long long)p->fts_statp->st_size);
		tab = "\t";
	}
	/*
	 * XXX
	 * Since utimes(2) only takes a timeval, there's no point in
	 * comparing the low bits of the timespec nanosecond field.  This
	 * will only result in mismatches that we can never fix.
	 *
	 * Doesn't display microsecond differences.
	 */
	if (s->flags & F_TIME) {
		struct timeval tv[2];
		struct stat *ps = p->fts_statp;
		time_t smtime = s->st_mtimespec.tv_sec;

#ifdef BSD4_4
		time_t pmtime = ps->st_mtimespec.tv_sec;

		TIMESPEC_TO_TIMEVAL(&tv[0], &s->st_mtimespec);
		TIMESPEC_TO_TIMEVAL(&tv[1], &ps->st_mtimespec);
#else
		time_t pmtime = (time_t)ps->st_mtime;

		tv[0].tv_sec = smtime;
		tv[0].tv_usec = 0;
		tv[1].tv_sec = pmtime;
		tv[1].tv_usec = 0;
#endif

		if (tv[0].tv_sec != tv[1].tv_sec ||
		    tv[0].tv_usec != tv[1].tv_usec) {
			LABEL;
			printf("%smodification time (%.24s, ",
			    tab, ctime(&smtime));
			printf("%.24s", ctime(&pmtime));
			if (tflag) {
				tv[1] = tv[0];
				if (utimes(p->fts_accpath, tv))
					printf(", not modified: %s)\n",
					    strerror(errno));
				else
					printf(", modified)\n");
			} else
				printf(")\n");
			tab = "\t";
		}
	}
#if HAVE_STRUCT_STAT_ST_FLAGS
	/*
	 * XXX
	 * since lchflags(2) will reset file times, the utimes() above
	 * may have been useless!  oh well, we'd rather have correct
	 * flags, rather than times?
	 */
        if ((s->flags & F_FLAGS) && ((s->st_flags != p->fts_statp->st_flags)
	    || mflag || iflag)) {
		if (s->st_flags != p->fts_statp->st_flags) {
			LABEL;
			printf("%sflags (\"%s\" is not ", tab,
			    flags_to_string(s->st_flags, "none"));
			printf("\"%s\"",
			    flags_to_string(p->fts_statp->st_flags, "none"));
		}
		if (uflag) {
			if (iflag)
				SETFLAGS(p->fts_accpath, s->st_flags,
				    0, p->fts_statp->st_flags, CH_MASK);
			else if (mflag)
				CLEARFLAGS(p->fts_accpath, s->st_flags,
				    0, p->fts_statp->st_flags, SP_FLGS);
			else
				SETFLAGS(p->fts_accpath, s->st_flags,
			     	    0, p->fts_statp->st_flags,
				    (~SP_FLGS & CH_MASK));
		} else
			printf(")\n");
		tab = "\t";
	}
#endif

	/*
	 * from this point, no more permission checking or whacking
	 * occurs, only checking of stuff like checksums and symlinks.
	 */
 afterpermwhack:
	if (s->flags & F_CKSUM) {
		if ((fd = open(p->fts_accpath, O_RDONLY, 0)) < 0) {
			LABEL;
			printf("%scksum: %s: %s\n",
			    tab, p->fts_accpath, strerror(errno));
			tab = "\t";
		} else if (crc(fd, &val, &len)) {
			close(fd);
			LABEL;
			printf("%scksum: %s: %s\n",
			    tab, p->fts_accpath, strerror(errno));
			tab = "\t";
		} else {
			close(fd);
			if (s->cksum != val) {
				LABEL;
				printf("%scksum (%lu, %lu)\n",
				    tab, s->cksum, (unsigned long)val);
			}
			tab = "\t";
		}
	}
#ifdef HAVE_MD5FILE
	if (s->flags & F_MD5) {
		if (MD5File(p->fts_accpath, digestbuf) == NULL) {
			LABEL;
			printf("%smd5: %s: %s\n",
			    tab, p->fts_accpath, strerror(errno));
			tab = "\t";
		} else {
			if (strcmp(s->md5digest, digestbuf)) {
				LABEL;
				printf("%smd5 (0x%s, 0x%s)\n",
				    tab, s->md5digest, digestbuf);
			}
			tab = "\t";
		}
	}
#endif	/* ! NO_MD5 */
#ifdef HAVE_RMD160FILE
	if (s->flags & F_RMD160) {
		if (RMD160File(p->fts_accpath, digestbuf) == NULL) {
			LABEL;
			printf("%srmd160: %s: %s\n",
			    tab, p->fts_accpath, strerror(errno));
			tab = "\t";
		} else {
			if (strcmp(s->rmd160digest, digestbuf)) {
				LABEL;
				printf("%srmd160 (0x%s, 0x%s)\n",
				    tab, s->rmd160digest, digestbuf);
			}
			tab = "\t";
		}
	}
#endif	/* RMD160 */
#ifdef HAVE_SHA1FILE
	if (s->flags & F_SHA1) {
		if (SHA1File(p->fts_accpath, digestbuf) == NULL) {
			LABEL;
			printf("%ssha1: %s: %s\n",
			    tab, p->fts_accpath, strerror(errno));
			tab = "\t";
		} else {
			if (strcmp(s->sha1digest, digestbuf)) {
				LABEL;
				printf("%ssha1 (0x%s, 0x%s)\n",
				    tab, s->sha1digest, digestbuf);
			}
			tab = "\t";
		}
	}
#endif	/* HAVE_SHA1FILE */
	if (s->flags & F_SLINK &&
	    strcmp(cp = rlink(p->fts_accpath), s->slink)) {
		LABEL;
		printf("%slink ref (%s, %s", tab, cp, s->slink);
		if (uflag) {
			if ((unlink(p->fts_accpath) == -1) ||
			    (symlink(s->slink, p->fts_accpath) == -1) )
				printf(", not modified: %s)\n",
				    strerror(errno));
			else
				printf(", modified)\n");
		} else
			printf(")\n");
	}
	return (label);
}

const char *
rlink(const char *name)
{
	static char lbuf[MAXPATHLEN];
	int len;

	if ((len = readlink(name, lbuf, sizeof(lbuf) - 1)) == -1)
		mtree_err("%s: %s", name, strerror(errno));
	lbuf[len] = '\0';
	return (lbuf);
}
