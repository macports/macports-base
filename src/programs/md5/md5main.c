/*	$NetBSD: digest.c,v 1.1.1.1 2002/09/19 10:44:28 agc Exp $ */

/*
 * Copyright (c) 2001 Alistair G. Crooks.  All rights reserved.
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
 *	This product includes software developed by Alistair G. Crooks.
 * 4. The name of the author may not be used to endorse or promote
 *    products derived from this software without specific prior written
 *    permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 * GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <digest-types.h>

#ifndef lint
__COPYRIGHT("@(#) Copyright (c) 2001 \
	        The NetBSD Foundation, Inc.  All rights reserved.");
__RCSID("$NetBSD: digest.c,v 1.1.1.1 2002/09/19 10:44:28 agc Exp $");
#endif


#ifdef HAVE_ERRNO_H
#include <errno.h>
#endif
#ifdef HAVE_LOCALE_H
#include <locale.h>
#endif
#include <md5.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

/* perform an md5 digest, and print the results if successful */
static int
md5_digest_file(char *fn)
{
	MD5_CTX	m;
	char	in[BUFSIZ * 20];
	char	digest[33];
	int	cc;

	if (fn == NULL) {
		MD5Init(&m);
		while ((cc = read(STDIN_FILENO, in, sizeof(in))) > 0) {
			MD5Update(&m, (u_char *)in, (unsigned) cc);
		}
		(void) printf("%s\n", MD5End(&m, digest));
	} else {
		if (MD5File(fn, digest) == NULL) {
			return 0;
		}
		(void) printf("MD5 (%s) = %s\n", fn, digest);
	}
	return 1;
}


/* this struct defines a message digest algorithm */
typedef struct alg_t {
	const char     *name;			/* algorithm name */
	int		(*func)(char *);	/* function to call */
} alg_t;

/* list of supported message digest algorithms */
static alg_t algorithms[] = {
	{ "md5",	md5_digest_file		},
	{ NULL	}
};

/* find an algorithm, given a name */
static alg_t *
find_algorithm(const char *a)
{
	alg_t	*alg;

	for (alg = algorithms ; alg->name && strcasecmp(alg->name, a) != 0 ; alg++) {
	}
	return (alg->name) ? alg : NULL;
}

int
main(int argc, char **argv)
{
	alg_t  *alg;
	int	rval;
	int	i;

#ifdef HAVE_SETLOCALE
	(void) setlocale(LC_ALL, "");
#endif
	while ((i = getopt(argc, argv, "V")) != -1) {
		switch(i) {
		case 'V':
			printf("%s\n", VERSION);
			return EXIT_SUCCESS;
		}
	}
	if ((alg = find_algorithm("md5")) == NULL) {
		(void) fprintf(stderr, "No such algorithm `%s'\n", argv[optind]);
		exit(EXIT_FAILURE);
	}
	rval = EXIT_SUCCESS;
	if (argc == optind) {
		if (!(*alg->func)(NULL)) {
			(void) fprintf(stderr, "stdin\n");
			rval = EXIT_FAILURE;
		}
	} else {
		for (i = optind ; i < argc ; i++) {
			if (!(*alg->func)(argv[i])) {
				(void) fprintf(stderr, "%s\n", argv[i]);
				rval = EXIT_FAILURE;
			}
		}
	}
	return rval;
}
