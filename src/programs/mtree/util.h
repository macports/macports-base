/*	$NetBSD: util.h,v 1.3 2002/12/02 17:03:24 jschauma Exp $	*/

/*-
 * Copyright (c) 1995
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

#ifndef _UTIL_H_
#define _UTIL_H_

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#if HAVE_SYS_CDEFS_H
#include <sys/cdefs.h>
#endif

#ifdef HAVE_SYS_TTYCOM_H
#include <sys/ttycom.h>
#endif
#include <sys/types.h>
#include <stdio.h>

#ifdef HAVE_PWD_H
#include <pwd.h>
#endif

#ifdef HAVE_TERMIOS_H
#include <termios.h>
#endif

#ifdef HAVE_UTMP_H
#include <utmp.h>
#endif

#define	PIDLOCK_NONBLOCK	1
#define PIDLOCK_USEHOSTNAME	2

#define	FPARSELN_UNESCESC	0x01
#define	FPARSELN_UNESCCONT	0x02
#define	FPARSELN_UNESCCOMM	0x04
#define	FPARSELN_UNESCREST	0x08
#define	FPARSELN_UNESCALL	0x0f

__BEGIN_DECLS
struct iovec;
struct passwd;
struct termios;
struct utmp;
struct winsize;

pid_t		forkpty(int *, char *, struct termios *, struct winsize *);
const char     *getbootfile(void);
int		getmaxpartitions(void);
int		getrawpartition(void);
void		login(const struct utmp *);
int		login_tty(int);
int		logout(const char *);
void		logwtmp(const char *, const char *, const char *);
int		opendisk(const char *, int, char *, size_t, int);
int		openpty(int *, int *, char *, struct termios *,
			struct winsize *);
void		pidfile(const char *);
int		pidlock(const char *, int, pid_t *, const char *);
int		pw_abort(void);
void		pw_copy(int, int, struct passwd *, struct passwd *);
void		pw_edit(int, const char *);
void		pw_error(const char *, int, int);
void		pw_getconf(char *, size_t, const char *, const char *);
const char     *pw_getprefix(void);
void		pw_init(void);
int		pw_lock(int);
int		pw_mkdb(const char *, int);
void		pw_prompt(void);
int		pw_setprefix(const char *);
int		secure_path(const char *);
int		ttyaction(const char *, const char *, const char *);
int		ttylock(const char *, int, pid_t *);
char	       *ttymsg(struct iovec *, int, const char *, int);
int		ttyunlock(const char *);

#ifndef HAVE_STRSEP
char *strsep(char **, const char *);
#endif

#ifndef HAVE_SETMODE
void *setmode(const char *);
#endif

#ifndef HAVE_GETPROGNAME
const char *getprogname(void);
#endif



#ifndef HAVE_FGETLN
char		*fgetln(FILE *, size_t *);
#define LIST_EMPTY(head)                ((head)->lh_first == NULL) 
#define LIST_FIRST(head)                ((head)->lh_first)
#define LIST_NEXT(elm, field)           ((elm)->field.le_next)
#endif

__END_DECLS

static int isescaped(const char *, const char *, int);
static char *fparseln(FILE *, size_t *, size_t *, const char[3], int);

#ifndef HAVE_FPARSELN
#define _DIAGASSERT(e)

/* isescaped():
 *      Return true if the character in *p that belongs to a string
 *      that starts in *sp, is escaped by the escape character esc.
 */     
static int
isescaped(const char *sp, const char *p, int esc)
{
        const char     *cp;
        size_t          ne;

        _DIAGASSERT(sp != NULL);
        _DIAGASSERT(p != NULL);

        /* No escape character */
        if (esc == '\0')
                return 1;
       
        /* Count the number of escape characters that precede ours */
        for (ne = 0, cp = p; --cp >= sp && *cp == esc; ne++)
                continue;
       
        /* Return true if odd number of escape characters */
        return (ne & 1) != 0;
}

/* fparseln():
 *      Read a line from a file parsing continuations ending in \
 *      and eliminating trailing newlines, or comments starting with
 *      the comment char.
 */
static char *
fparseln(FILE *fp, size_t *size, size_t *lineno, const char str[3], int flags)
{
        static const char dstr[3] = { '\\', '\\', '#' };
       
        size_t  s, len;
        char   *buf;
        char   *ptr, *cp;
        int     cnt;
        char    esc, con, nl, com;
       
        _DIAGASSERT(fp != NULL);
       
        len = 0;
        buf = NULL;
        cnt = 1;
       
        if (str == NULL)
                str = dstr;
       
        esc = str[0];
        con = str[1];
        com = str[2];
        /*
         * XXX: it would be cool to be able to specify the newline character,
         * but unfortunately, fgetln does not let us
         */
        nl  = '\n';
       
        while (cnt) {
                cnt = 0;
       
                if (lineno)
                        (*lineno)++;
       
                if ((ptr = (char *)fgetln(fp, &s)) == NULL)
                        break;
       
                if (s && com) {         /* Check and eliminate comments */
                        for (cp = ptr; cp < ptr + s; cp++)
                                if (*cp == com && !isescaped(ptr, cp, esc)) {
                                        s = cp - ptr;
                                        cnt = s == 0 && buf == NULL;
                                        break;
                                }
                }
       
                if (s && nl) {          /* Check and eliminate newlines */
                        cp = &ptr[s - 1];
       
                        if (*cp == nl)
                                s--;    /* forget newline */
                }
       
                if (s && con) {         /* Check and eliminate continuations */
                        cp = &ptr[s - 1];
       
                        if (*cp == con && !isescaped(ptr, cp, esc)) {
                                s--;    /* forget escape */
                                cnt = 1;
                        }
                }
                if (s == 0 && buf != NULL)
                        continue;
       
                if ((cp = realloc(buf, len + s + 1)) == NULL) {
                        free(buf);
                        return NULL;
                }
                buf = cp;
       
                (void) memcpy(buf + len, ptr, s);
                len += s;
                buf[len] = '\0';
        }
       
        if ((flags & FPARSELN_UNESCALL) != 0 && esc && buf != NULL &&
            strchr(buf, esc) != NULL) {
                ptr = cp = buf;
                while (cp[0] != '\0') {
                        int skipesc;
       
                        while (cp[0] != '\0' && cp[0] != esc)
                                *ptr++ = *cp++;
                        if (cp[0] == '\0' || cp[1] == '\0')
                                break;
       
                        skipesc = 0;
                        if (cp[1] == com)
                                skipesc += (flags & FPARSELN_UNESCCOMM);
                        if (cp[1] == con)
                                skipesc += (flags & FPARSELN_UNESCCONT);
                        if (cp[1] == esc)
                                skipesc += (flags & FPARSELN_UNESCESC);
                        if (cp[1] != com && cp[1] != con && cp[1] != esc)
                                skipesc = (flags & FPARSELN_UNESCREST);
       
                        if (skipesc)
                                cp++;
                        else
                                *ptr++ = *cp++;
                        *ptr++ = *cp++;
                }
                *ptr = '\0';
                len = strlen(buf);
        }
       
        if (size)
                *size = len;
        return buf;
}      
#endif

#endif /* !_UTIL_H_ */
