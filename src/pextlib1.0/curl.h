/*
 * curl.h
 * $Id$
 *
 * Copyright (c) 2005 Paul Guyot, The MacPorts Project.
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

#ifndef _CURL_H
#define _CURL_H

#include <tcl.h>

/**
 * Init libcurl.
 * libcurl will never be cleaned (where should I plug the hook?)
 */
int CurlInit(Tcl_Interp* interp);

/**
 * A native command to use libcurl.
 *
 * The syntax is:
 * curl fetch [options] url file
 *	Fetch a URL to file. Return an error if it failed.
 *  -v display progress meter
 *  --disable-epsv - like curl(1)
 *  -u user:pass - like curl(1)
 *
 * curl isnewer url date
 *	Determine if some resource is newer than date. Try to not fetch the resource
 *  if possible. The date is the number of seconds since epoch.
 *
 * curl getsize url
 *	Determine the file size of some resource. Try to not fetch the resource
 *  if possible. The size returned is the number of bytes.
 */
int CurlCmd(ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);

#endif
		/* _FILEMAP_H */

/* ====================================================================== **
** Has everyone noticed that all the letters of the word "database" are   **
** typed with the left hand?  Now the layout of the QWERTYUIOP typewriter **
** keyboard was designed, among other things, to facilitate the even use  **
** of both hands.  It follows, therefore, that writing about databases is **
** not only unnatural, but a lot harder than it appears.                  **
** ====================================================================== */
