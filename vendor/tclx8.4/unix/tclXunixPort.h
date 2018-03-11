/*
 * tclXunixPort.h
 *
 * Portability include file for Unix systems.
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
 * $Id: tclXunixPort.h,v 8.5 2007/02/28 00:14:09 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#ifndef TCLXUNIXPORT_H
#define TCLXUNIXPORT_H

#include <sys/param.h>

#include <math.h>

#ifdef NO_LIMITS_H
#    include <values.h>
#else
#    include <limits.h>
#endif

#include <sys/times.h>
#include <grp.h>
#include <assert.h>

#ifndef __xlC__ /* AIX xlc */
extern int h_errno;
#endif

#ifdef __APPLE__
# undef panic
#endif

/*
 * Included the tcl file tclUnixPort.h after other system files, as it checks
 * if certain things are defined.
 */
#include "tclUnixPort.h"

/*
 * Define O_ACCMODE if <fcntl.h> does not define it.
 */
#ifndef O_ACCMODE
#    define O_ACCMODE  (O_RDONLY|O_WRONLY|O_RDWR)
#endif

/*
 * Make sure we have both O_NONBLOCK and O_NDELAY defined.
 */
#ifndef O_NONBLOCK
#   define O_NONBLOCK O_NDELAY
#endif
#ifndef O_NDELAY
#   define O_NDELAY O_NONBLOCK
#endif

/*
 * Make sure CLK_TCK is defined.
 */
#ifndef CLK_TCK
#    ifdef HZ
#        define CLK_TCK HZ
#    else
#        define CLK_TCK 60
#    endif
#endif

/*
 * Defines needed for socket code.  ((unsigned long) -1) is not correct
 * for 64-bit systems, use 0XFFFFFFFFUL. [Bug 1242825]
 */
#ifndef INADDR_NONE
#    define INADDR_NONE 0xFFFFFFFFUL
#endif

/*
 * BSD functions.
 */
#ifdef NO_BCOPY
#    define bcopy(from, to, length) memmove((to), (from), (length))
#endif

#ifdef NO_BZERO
#    define bzero(to,length) memset(to,'\0',length)
#endif

/*
 * Math defines.
 */
#ifndef MAXDOUBLE
#    define MAXDOUBLE HUGE_VAL
#endif


/*
 * Define C lib prototypes that are either missing or being emulated by
 * the compat library.
 */
#if defined(NO_RANDOM) || defined(NO_RANDOM_PROTO)
extern long random ();
#endif

/*
 * If sigaction is available, check for restartable signals.
 */
#ifndef NO_SIGACTION
#    ifndef SA_RESTART
#        define NO_SIG_RESTART
#    endif
#else
#    define NO_SIG_RESTART
#endif


/*
 * Define a macro to call wait pid.  We don't use Tcl_WaitPid on Unix because
 * it delays signals.
 */
#define TCLX_WAITPID(pid, status, options) waitpid (pid, status, options)

#endif


