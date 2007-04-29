/*
 * compat.h
 * $Id$
 *
 * Copyright (c) 2004 Paul Guyot, MacPorts Team.
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
 * 3. Neither the name of MacPorts Team nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _COMPAT_H
#define _COMPAT_H

#include <tcl.h>

/**
 * A native command to handle limitation of old versions of Tcl.
 *
 * The syntax is:
 * compat filenormalize path
 *	Normalize path just like file normalize does.
 *  Fixes a problem with Tcl installations affected by bug #953284. (this is
 *	the case with 10.3's Tcl)
 *
 * compat filelinkhard dstpath srcpath
 *	Creates a hard link just like file link -hard does.
 *  Fixes a problem with Tcl installations that do not understand link
 *  (typically 10.2's Tcl).
 *
 * compat filelinksymbolic dstpath srcpath
 *	Creates a symbolic link just like file link -symbolic does.
 *  Fixes a problem with Tcl installations that do not understand link
 *  (typically 10.2's Tcl).
 */
int CompatCmd(ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);

#endif
		/* _COMPAT_H */

/* ================================================= **
** Truly simple systems... require infinite testing. **
**                 -- Norman Augustine               **
** ================================================= */
