/*
 * rmd160cmd.c
 *
 * Copyright (c) 2006, 2009-2011 The MacPorts Project
 * Copyright (c) 2005 Paul Guyot <pguyot@kallisys.net>.
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

/* required for u_char on Linux */
#define _BSD_SOURCE

#include <string.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>

#include <tcl.h>

#include "rmd160cmd.h"

#if defined(HAVE_LIBMD) && defined(HAVE_RIPEMD_H)
#include <sys/types.h>
#include <ripemd.h>
#elif defined(HAVE_LIBCRYPTO) && defined(HAVE_OPENSSL_RIPEMD_H)
#include <openssl/ripemd.h>

#include "md_wrappers.h"
CHECKSUMEnd(RIPEMD160_, RIPEMD160_CTX, RIPEMD160_DIGEST_LENGTH)
CHECKSUMFile(RIPEMD160_, RIPEMD160_CTX)
CHECKSUMData(RIPEMD160_, RIPEMD160_CTX)
#else
/*
 * let's use our own version of rmd160* libraries.
 */
#include <sys/types.h>
#include "rmd160.h"
#include "rmd160.c"
#define RIPEMD160_DIGEST_LENGTH 20
#define RIPEMD160_File(x,y) RMD160File(x,y)
#define RIPEMD160_Data(x,y,z) RMD160Data(x,y,z)

#include "md_wrappers.h"
CHECKSUMEnd(RMD160, RMD160_CTX, RIPEMD160_DIGEST_LENGTH)
CHECKSUMFile(RMD160, RMD160_CTX)
CHECKSUMData(RMD160, RMD160_CTX)
#endif

int RMD160Cmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	char *file, *instr, *action;
	int inlen;
	char buf[2*RIPEMD160_DIGEST_LENGTH + 1];
	const char usage_message[] = "Usage: rmd160 file";
	const char file_error_message[] = "Could not open file: ";
	const char string_error_message[] = "Could not process string: ";
	Tcl_Obj *tcl_result;

	if (objc != 3) {
		Tcl_WrongNumArgs(interp, 1, objv, "action ?file?");
		return TCL_ERROR;
	}

	/*
	 * 'file' and 'string' actions are currently supported
	 */
	action = Tcl_GetString(objv[1]);
	if (strcmp(action, "file") == 0) {
	    file = Tcl_GetString(objv[2]);

        if (!RIPEMD160_File(file, buf)) {
            tcl_result = Tcl_NewStringObj(file_error_message, sizeof(file_error_message) - 1);
            Tcl_AppendObjToObj(tcl_result, Tcl_NewStringObj(file, -1));
            Tcl_SetObjResult(interp, tcl_result);
            return TCL_ERROR;
        }
	} else if (strcmp(action, "string") == 0) {
	    instr = Tcl_GetStringFromObj(objv[2], &inlen);

	    if (!RIPEMD160_Data((u_char *)instr, (u_int32_t)inlen, buf)) {
            tcl_result = Tcl_NewStringObj(string_error_message, sizeof(string_error_message) - 1);
            Tcl_AppendObjToObj(tcl_result, Tcl_NewStringObj(instr, -1));
            Tcl_SetObjResult(interp, tcl_result);
            return TCL_ERROR;
        }
	} else {
		tcl_result = Tcl_NewStringObj(usage_message, sizeof(usage_message) - 1);
		Tcl_SetObjResult(interp, tcl_result);
		return TCL_ERROR;
	}
	
	tcl_result = Tcl_NewStringObj(buf, sizeof(buf) - 1);
	Tcl_SetObjResult(interp, tcl_result);
	return TCL_OK;
}
