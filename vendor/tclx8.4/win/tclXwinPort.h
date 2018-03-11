/*
 * tclXwinPort.h
 *
 * Portability include file for MS Windows systems.
 *-----------------------------------------------------------------------------
 * Copyright 1996-1999 Karl Lehenbauer and Mark Diekhans.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies.  Karl Lehenbauer and
 * Mark Diekhans make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *-----------------------------------------------------------------------------
 * $Id: tclXwinPort.h,v 1.3 2005/03/24 05:11:16 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#ifndef TCLXWINPORT_H
#define TCLXWINPORT_H

#include "tclWinPort.h"

#include <direct.h>
#include <assert.h>

/*
 * Types needed for fstat, but are not directly supported (we emulate).  If
 * defined before tclWinPort.h is include, it will define the access macros.
 */
#define S_IFIFO  _S_IFIFO               /* pipe */
#define S_IFSOCK 0140000                /* socket */

/*
 * OS feature definitons.
 */
#ifndef NO_CATGETS
#   define NO_CATGETS
#endif
#ifndef NO_FCHMOD
#   define NO_FCHMOD
#endif
#ifndef NO_FCHOWN
#   define NO_FCHOWN
#endif
#ifndef NO_FSYNC
#   define NO_FSYNC
#endif
#ifndef NO_RANDOM
#   define NO_RANDOM  /* uses compat */
#endif
#ifndef NO_SIGACTION
#   define NO_SIGACTION
#endif
#ifndef NO_TRUNCATE
#   define NO_TRUNCATE    /* FIX: Are we sure there is no way to truncate???*/
#endif
#ifndef RETSIGTYPE
#   define RETSIGTYPE void
#endif

#include <math.h>
#include <limits.h>

#ifndef MAXDOUBLE
#    define MAXDOUBLE HUGE_VAL
#endif

/*
 * No restartable signals in WIN32.
 */
#ifndef NO_SIG_RESTART
#   define NO_SIG_RESTART
#endif

/*
 * Define a macro to call wait pid.  We don't use Tcl_WaitPid on Unix because
 * it delays signals.
 */
#define TCLX_WAITPID(pid, status, options) \
	Tcl_WaitPid((Tcl_Pid)pid, status, options)

#define bcopy(from, to, length)    memmove((to), (from), (length))

/*
 * Compaibility functions.
 */
extern long	random(void);

extern void	srandom(unsigned int x);

extern int	getopt(int nargc, char * const *nargv, const char *ostr);

#endif


