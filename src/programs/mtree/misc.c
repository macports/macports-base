/*	$NetBSD: misc.c,v 1.8 2002/12/02 17:03:24 jschauma Exp $	*/

/*-
 * Copyright (c) 1991, 1993
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
 *
 *	@(#)misc.c	8.1 (Berkeley) 6/6/93
 */
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#if HAVE_SYS_CDEFS_H
#include <sys/cdefs.h>
#endif

#if defined(__RCSID) && !defined(lint)
__RCSID("$NetBSD: misc.c,v 1.8 2002/12/02 17:03:24 jschauma Exp $");
#endif /* not lint */

#include <sys/types.h>
#include <sys/stat.h>

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "extern.h"
#include "util.h"

typedef struct _key {
	const char	*name;		/* key name */
	u_int		val;		/* value */

#define	NEEDVALUE	0x01
	u_int		flags;
} KEY;

/* NB: the following tables must be sorted lexically. */
static KEY keylist[] = {
	{"cksum",	F_CKSUM,	NEEDVALUE},
	{"device",	F_DEV,		NEEDVALUE},
	{"flags",	F_FLAGS,	NEEDVALUE},
	{"gid",		F_GID,		NEEDVALUE},
	{"gname",	F_GNAME,	NEEDVALUE},
	{"ignore",	F_IGN,		0},
	{"link",	F_SLINK,	NEEDVALUE},
	{"md5",		F_MD5,		NEEDVALUE},
	{"md5digest",	F_MD5,		NEEDVALUE},
	{"mode",	F_MODE,		NEEDVALUE},
	{"nlink",	F_NLINK,	NEEDVALUE},
	{"optional",	F_OPT,		0},
	{"rmd160",	F_RMD160,	NEEDVALUE},
	{"rmd160digest",F_RMD160,	NEEDVALUE},
	{"sha1",	F_SHA1,		NEEDVALUE},
	{"sha1digest",	F_SHA1,		NEEDVALUE},
	{"size",	F_SIZE,		NEEDVALUE},
	{"tags",	F_TAGS,		NEEDVALUE},
	{"time",	F_TIME,		NEEDVALUE},
	{"type",	F_TYPE,		NEEDVALUE},
	{"uid",		F_UID,		NEEDVALUE},
	{"uname",	F_UNAME,	NEEDVALUE}
};

static KEY typelist[] = {
	{"block",	F_BLOCK,	},
	{"char",	F_CHAR,		},
	{"dir",		F_DIR,		},
	{"fifo",	F_FIFO,		},
	{"file",	F_FILE,		},
	{"link",	F_LINK,		},
	{"socket",	F_SOCK,		},
};

slist_t	excludetags, includetags;
int	keys = KEYDEFAULT;


int keycompare(const void *, const void *);

u_int
parsekey(const char *name, int *needvaluep)
{
	static int allbits;
	KEY *k, tmp;

	if (allbits == 0) {
		int i;

		for (i = 0; i < sizeof(keylist) / sizeof(KEY); i++)
			allbits |= keylist[i].val;
	}
	tmp.name = name;
	if (strcmp(name, "all") == 0)
		return (allbits);
	k = (KEY *)bsearch(&tmp, keylist, sizeof(keylist) / sizeof(KEY),
	    sizeof(KEY), keycompare);
	if (k == NULL)
		mtree_err("unknown keyword `%s'", name);

	if (needvaluep)
		*needvaluep = k->flags & NEEDVALUE ? 1 : 0;

	return (k->val);
}

u_int
parsetype(const char *name)
{
	KEY *k, tmp;

	tmp.name = name;
	k = (KEY *)bsearch(&tmp, typelist, sizeof(typelist) / sizeof(KEY),
	    sizeof(KEY), keycompare);
	if (k == NULL)
		mtree_err("unknown file type `%s'", name);

	return (k->val);
}

int
keycompare(const void *a, const void *b)
{

	return (strcmp(((const KEY *)a)->name, ((const KEY *)b)->name));
}

void
mtree_err(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
	if (mtree_lineno)
		warnx("failed at line %lu of the specification",
		    (u_long) mtree_lineno);
	exit(1);
	/* NOTREACHED */
}

void
addtag(slist_t *list, char *elem)
{

#define	TAG_CHUNK 20

	if ((list->count % TAG_CHUNK) == 0) {
		char **new;

		new = (char **)realloc(list->list, (list->count + TAG_CHUNK)
		    * sizeof(char *));
		if (new == NULL)
			mtree_err("memory allocation error");
		list->list = new;
	}
	list->list[list->count] = elem;
	list->count++;
}

#ifndef HAVE_STRSEP
char *strsep(char **, const char *);
#endif

void
parsetags(slist_t *list, char *args)
{
	char	*p, *e;
	int	len;

	if (args == NULL) {
		addtag(list, NULL);
		return;
	}
	while ((p = strsep(&args, ",")) != NULL) {
		if (*p == '\0')
			continue;
		len = strlen(p) + 3;	/* "," + p + ",\0" */
		if ((e = malloc(len)) == NULL)
			mtree_err("memory allocation error");
		snprintf(e, len, ",%s,", p);
		addtag(list, e);
	}
}

/*
 * matchtags
 *	returns 0 if there's a match from the exclude list in the node's tags,
 *	or there's an include list and no match.
 *	return 1 otherwise.
 */
int
matchtags(NODE *node)
{
	int	i;

	if (node->tags) {
		for (i = 0; i < excludetags.count; i++)
			if (strstr(node->tags, excludetags.list[i]))
				break;
		if (i < excludetags.count)
			return (0);

		for (i = 0; i < includetags.count; i++)
			if (strstr(node->tags, includetags.list[i]))
				break;
		if (i > 0 && i == includetags.count)
			return (0);
	} else if (includetags.count > 0) {
		return (0);
	}
	return (1);
}

u_int
nodetoino(u_int type)
{

	switch (type) {
	case F_BLOCK:
		return S_IFBLK;
	case F_CHAR:
		return S_IFCHR;
	case F_DIR:
		return S_IFDIR;
	case F_FIFO:
		return S_IFIFO;
	case F_FILE:
		return S_IFREG;
	case F_LINK:
		return S_IFLNK;
	case F_SOCK:
		return S_IFSOCK;
	default:
		printf("unknown type %d", type);
		abort();
	}
	/* NOTREACHED */
}

const char *
nodetype(u_int type)
{

	return (inotype(nodetoino(type)));
}


const char *
inotype(u_int type)
{

	switch (type & S_IFMT) {
	case S_IFBLK:
		return ("block");
	case S_IFCHR:
		return ("char");
	case S_IFDIR:
		return ("dir");
	case S_IFIFO:
		return ("fifo");
	case S_IFREG:
		return ("file");
	case S_IFLNK:
		return ("link");
	case S_IFSOCK:
		return ("socket");
	default:
		return ("unknown");
	}
	/* NOTREACHED */
}

#ifndef HAVE_STRSEP
/* taken from the version in lukemftp */
char *
strsep(char **stringp, const char *delim)
{
	char *s;
	const char *spanp;
	int c, sc;
	char *tok;

	if ((s = *stringp) == NULL)
		return (NULL);
	for (tok = s;;) {
		c = *s++;
		spanp = delim;
		do {
			if ((sc = *spanp++) == c) {
				if (c == 0)
					s = NULL;
				else
					s[-1] = 0;
				*stringp = s;
				return (tok);
			}
		} while (sc != 0);
	}
	/* NOTREACHED */
}
#endif
