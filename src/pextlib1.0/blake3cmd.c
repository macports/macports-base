/*
 * blake3cmd.c
 *
 * Copyright (c) 2025 The MacPorts Project
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
#include <string.h>
#include <unistd.h>

#include <tcl.h>

#include "blake3cmd.h"
#include "blake3/blake3.h"

#define BLAKE3_DIGEST_LENGTH BLAKE3_OUT_LEN

static char *BLAKE3_File(const char *filename, char *buf)
{
    unsigned char buffer[BUFSIZ];
    blake3_hasher hasher;
    unsigned char digest[BLAKE3_DIGEST_LENGTH];
    static const char hex[] = "0123456789abcdef";
    int f, i, j;

    blake3_hasher_init(&hasher);
    f = open(filename, O_RDONLY);
    if (f < 0) return 0;
    while ((i = read(f, buffer, sizeof buffer)) > 0) {
        blake3_hasher_update(&hasher, buffer, i);
    }
    j = errno;
    close(f);
    errno = j;
    if (i < 0) return 0;

    blake3_hasher_finalize(&hasher, digest, BLAKE3_DIGEST_LENGTH);
    for (i = 0; i < BLAKE3_DIGEST_LENGTH; i++) {
        buf[i+i] = hex[digest[i] >> 4];
        buf[i+i+1] = hex[digest[i] & 0x0f];
    }
    buf[i+i] = '\0';
    return buf;
}

int BLAKE3Cmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
	char *file, *action;
	char buf[2*BLAKE3_DIGEST_LENGTH + 1];
	const char usage_message[] = "Usage: blake3 file";
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

	if (!BLAKE3_File(file, buf)) {
		int errsave = errno;
		Tcl_SetResult(interp, "Could not open file: ", TCL_STATIC);
		Tcl_AppendResult(interp, file, ": ", strerror(errsave), NULL);
		return TCL_ERROR;
	}
	tcl_result = Tcl_NewStringObj(buf, sizeof(buf) - 1);
	Tcl_SetObjResult(interp, tcl_result);
	return TCL_OK;
}
