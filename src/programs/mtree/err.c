/*	$Id: err.c,v 1.2 2003/06/21 21:47:48 ssen Exp $	*/

/*
 * Copyright 1997-2000 Luke Mewburn <lukem@netbsd.org>.
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

#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "util.h"

#ifndef HAVE_ERR
void
err(int eval, const char *fmt, ...)
{
	va_list	ap;
        int	sverrno;

	sverrno = errno;
        (void)fprintf(stderr, "%s: ", getprogname());
	va_start(ap, fmt);
        if (fmt != NULL) {
                (void)vfprintf(stderr, fmt, ap);
                (void)fprintf(stderr, ": ");
        }
	va_end(ap);
        (void)fprintf(stderr, "%s\n", strerror(sverrno));
        exit(eval);
}
#endif

#ifndef HAVE_ERRX
void
errx(int eval, const char *fmt, ...)
{
	va_list	ap;

        (void)fprintf(stderr, "%s: ", getprogname());
	va_start(ap, fmt);
        if (fmt != NULL)
                (void)vfprintf(stderr, fmt, ap);
	va_end(ap);
        (void)fprintf(stderr, "\n");
        exit(eval);
}
#endif

#ifndef HAVE_WARN
void
warn(const char *fmt, ...)
{
	va_list	ap;
        int	sverrno;

	sverrno = errno;
        (void)fprintf(stderr, "%s: ", getprogname());
	va_start(ap, fmt);
        if (fmt != NULL) {
                (void)vfprintf(stderr, fmt, ap);
                (void)fprintf(stderr, ": ");
        }
	va_end(ap);
        (void)fprintf(stderr, "%s\n", strerror(sverrno));
}
#endif

#ifndef HAVE_WARNX
void
warnx(const char *fmt, ...)
{
	va_list	ap;

        (void)fprintf(stderr, "%s: ", getprogname());
	va_start(ap, fmt);
        if (fmt != NULL)
                (void)vfprintf(stderr, fmt, ap);
	va_end(ap);
        (void)fprintf(stderr, "\n");
}
#endif
