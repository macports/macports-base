/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1988, 1993, 1994
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
 * 3. Neither the name of the University nor the names of its contributors
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

#ifndef lint
static const char copyright[] =
"@(#) Copyright (c) 1988, 1993, 1994\n\
	The Regents of the University of California.  All rights reserved.\n";
#endif /* not lint */

#if 0
#ifndef lint
static char sccsid[] = "@(#)env.c	8.3 (Berkeley) 4/2/94";
#endif /* not lint */
#endif

#include <sys/cdefs.h>
#include <sys/types.h>

#include <err.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern char **environ;

static void usage(void);

/*
 * Exit codes.
 */
#define EXIT_CANCELED      125 /* Internal error prior to exec attempt. */
#define EXIT_CANNOT_INVOKE 126 /* Program located, but not usable. */
#define EXIT_ENOENT        127 /* Could not find program to exec. */

int
main(int argc, char **argv)
{
	char **ep, *p;
	int ch;
	int rtrn;

	while ((ch = getopt(argc, argv, "u:")) != -1)
		switch(ch) {
		case 'u':
			rtrn = unsetenv(optarg);
			if (rtrn == -1)
				err(EXIT_FAILURE, "unsetenv %s", optarg);
			break;
		case '?':
		default:
			usage();
		}
	for (argv += optind; *argv && (p = strchr(*argv, '=')); ++argv) {
		*p = '\0';
		rtrn = setenv(*argv, p + 1, 1);
		*p = '=';
		if (rtrn == -1)
			err(EXIT_FAILURE, "setenv %s", *argv);
	}
	if (*argv) {
		execvp(*argv, argv);
		err(errno == ENOENT ? EXIT_ENOENT : EXIT_CANNOT_INVOKE,
		    "%s", *argv);
	}
	for (ep = environ; *ep; ep++)
		(void)printf("%s%c", *ep, '\n');
	exit(0);
}

static void
usage(void)
{
	(void)fprintf(stderr,
	    "usage: env [-u name] [name=value ...] [utility [argument ...]]\n");
	(void)fprintf(stderr, "%s\n", copyright);
	exit(1);
}
