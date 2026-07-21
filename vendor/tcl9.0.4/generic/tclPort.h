/*
 * tclPort.h --
 *
 *	This header file handles porting issues that occur because
 *	of differences between systems.  It reads in platform specific
 *	portability files.
 *
 * Copyright (c) 1994-1995 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#ifndef _TCLPORT
#define _TCLPORT

#ifdef HAVE_TCL_CONFIG_H
#include "tclConfig.h"
#endif
#if defined(_WIN32)
#   include "tclWinPort.h"
#else
#   include "tclUnixPort.h"
#endif
#include "tcl.h"

#define UWIDE_MAX ((Tcl_WideUInt)-1)
#define WIDE_MAX ((Tcl_WideInt)(UWIDE_MAX >> 1))
#define WIDE_MIN ((Tcl_WideInt)((Tcl_WideUInt)WIDE_MAX+1))

#endif /* _TCLPORT */
