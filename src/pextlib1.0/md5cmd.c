/*
 * md5cmd.c
 *
 * Copyright (c) 2004 - 2005, 2009, 2011 The MacPorts Project
 * Copyright (c) 2002 - 2003 Apple Inc.
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
 * 3. Neither the name of Apple Inc. nor the names of its contributors
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

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <tcl.h>

#include "md5cmd.h"

#if HAVE_COMMONCRYPTO_COMMONDIGEST_H

#define COMMON_DIGEST_FOR_OPENSSL
#include <CommonCrypto/CommonDigest.h>

/* md5 functions are named differently */
#define MD5Init(x) MD5_Init(x)
#define MD5Update(x,y,z) MD5_Update(x,y,z)
#define MD5Final(x,y) MD5_Final(x,y)

#include "md_wrappers.h"
CHECKSUMEnd(MD5, MD5_CTX, MD5_DIGEST_LENGTH)
CHECKSUMFile(MD5, MD5_CTX)

#elif defined(HAVE_LIBMD) && defined(HAVE_MD5_H)
#include <sys/types.h>
#include <md5.h>
#elif defined(HAVE_LIBCRYPTO) && defined(HAVE_OPENSSL_MD5_H)
#include <openssl/md5.h>

#include "md_wrappers.h"
CHECKSUMEnd(MD5_, MD5_CTX, MD5_DIGEST_LENGTH)
CHECKSUMFile(MD5_, MD5_CTX)
#define MD5File(x,y) MD5_File(x,y)
#else
#error CommonCrypto, libmd or libcrypto required
#endif

int MD5Cmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	char *file, *action;
	char buf[33];
	const char usage_message[] = "Usage: md5 file ?file?";
	const char error_message[] = "Could not open file: ";
	Tcl_Obj *tcl_result;

	if (objc != 3) {
		Tcl_WrongNumArgs(interp, 1, objv, "action ?file?");
		return TCL_ERROR;
	}

	/*
	 * Only the 'file' action is currently supported
	 */
	action = Tcl_GetString(objv[1]);
	if (strcmp(action, "file") != 0) {
		tcl_result = Tcl_NewStringObj(usage_message, sizeof(usage_message) - 1);
		Tcl_SetObjResult(interp, tcl_result);
		return TCL_ERROR;
	}
	file = Tcl_GetString(objv[2]);

	if (!MD5File(file, buf)) {
		tcl_result = Tcl_NewStringObj(error_message, sizeof(error_message) - 1);
		Tcl_AppendObjToObj(tcl_result, Tcl_NewStringObj(file, -1));
		Tcl_SetObjResult(interp, tcl_result);
		return TCL_ERROR;
	}
	tcl_result = Tcl_NewStringObj(buf, sizeof(buf) - 1);
	Tcl_SetObjResult(interp, tcl_result);
	return TCL_OK;
}
