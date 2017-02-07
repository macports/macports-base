/*
 * sha256cmd.c
 *
 * Copyright (c) 2009, 2011 The MacPorts Project
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
 * 3. Neither the name of The MacPorts Project nor the names of its contributors
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

#include "sha256cmd.h"

#if HAVE_COMMONCRYPTO_COMMONDIGEST_H

#define COMMON_DIGEST_FOR_OPENSSL
#include <CommonCrypto/CommonDigest.h>

/* Tiger compatibility */
#ifndef SHA256_DIGEST_LENGTH
#define SHA256_DIGEST_LENGTH            CC_SHA256_DIGEST_LENGTH
#define SHA256_CTX                      CC_SHA256_CTX
#define SHA256_Init(c)                  CC_SHA256_Init(c)
#define SHA256_Update(c,d,l)            CC_SHA256_Update(c,d,l)
#define SHA256_Final(m, c)              CC_SHA256_Final(m,c)
#endif

#include "md_wrappers.h"
CHECKSUMEnd(SHA256_, SHA256_CTX, SHA256_DIGEST_LENGTH)
CHECKSUMFile(SHA256_, SHA256_CTX)

#elif defined(HAVE_LIBMD) && defined(HAVE_SHA256_H) && !defined(__FreeBSD__) /*dumps core*/
#include <sys/types.h>
#include <sha256.h>
#ifndef SHA256_DIGEST_LENGTH
#define SHA256_DIGEST_LENGTH 32
#endif
#elif defined(HAVE_LIBCRYPTO) && defined(HAVE_OPENSSL_SHA_H) && defined(HAVE_SHA256_UPDATE)
#include <openssl/sha.h>

#include "md_wrappers.h"
CHECKSUMEnd(SHA256_, SHA256_CTX, SHA256_DIGEST_LENGTH)
CHECKSUMFile(SHA256_, SHA256_CTX)
#else
/*
 * let's use our own version of sha256* libraries.
 */
#include <sys/types.h>
#include "sha2.h"
#include "sha2.c"

#include "md_wrappers.h"
CHECKSUMEnd(SHA256_, SHA256_CTX, SHA256_DIGEST_LENGTH)
CHECKSUMFile(SHA256_, SHA256_CTX)
#endif

int SHA256Cmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	char *file, *action;
	char buf[2*SHA256_DIGEST_LENGTH + 1];
	const char usage_message[] = "Usage: sha256 file";
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

	if (!SHA256_File(file, buf)) {
		tcl_result = Tcl_NewStringObj(error_message, sizeof(error_message) - 1);
		Tcl_AppendObjToObj(tcl_result, Tcl_NewStringObj(file, -1));
		Tcl_SetObjResult(interp, tcl_result);
		return TCL_ERROR;
	}
	tcl_result = Tcl_NewStringObj(buf, sizeof(buf) - 1);
	Tcl_SetObjResult(interp, tcl_result);
	return TCL_OK;
}
