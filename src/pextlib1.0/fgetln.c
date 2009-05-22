/*	$NetBSD: fgetln.c,v 1.3 2002/01/31 19:23:14 tv Exp $	*/

/*
 * $Id$
 * Copyright 1999 Luke Mewburn <lukem@netbsd.org>.
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
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
 * OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 * TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <config.h>

extern int xxx_so_this_isnt_empty;

#if !HAVE_FGETLN
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUFCHUNKS	BUFSIZ

char *
fgetln(FILE *fp, size_t *len)
{
	static char *buf;
	static size_t bufsize;
	size_t buflen;
	char curbuf[BUFCHUNKS];
	char *p;

	if (buf == NULL) {
		bufsize = BUFCHUNKS;
		buf = (char *)malloc(bufsize);
		if (buf == NULL)
		  return NULL;
	}

	*buf = '\0';
	buflen = 0;
	while ((p = fgets(curbuf, sizeof(curbuf), fp)) != NULL) {
		size_t l;

		l = strlen(p);
		if (bufsize < buflen + l) {
			bufsize += BUFCHUNKS;
			if ((buf = (char *)realloc(buf, bufsize)) == NULL)
			  return NULL;
		}
		strcpy(buf + buflen, p);
		buflen += l;
		if (p[l - 1] == '\n')
			break;
	}
	if (p == NULL && *buf == '\0')
		return (NULL);
	*len = strlen(buf);
	return (buf);
}
#endif
