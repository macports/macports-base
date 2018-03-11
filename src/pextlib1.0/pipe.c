/*
 * pipe.c
 *
 * Copyright (c) 2009 The MacPorts Project
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
#include <string.h>
#include <unistd.h>

#include <tcl.h>

#include "pipe.h"

/**
 * Call pipe(2) to create a pipe.
 * Syntax is:
 * pipe
 *
 * Generate a Tcl error if something goes wrong.
 * Return a list with the file descriptors of the pipe. The first item is the
 * readable fd.
 */
int PipeCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Obj* result;
	int fildes[2];

	if (objc != 1) {
		Tcl_WrongNumArgs(interp, 1, objv, NULL);
		return TCL_ERROR;
	}
	
	if (pipe(fildes) < 0) {
		Tcl_AppendResult(interp, "pipe failed: ", strerror(errno), NULL);
		return TCL_ERROR;
	}
	
	/* build a list out of the couple */
	result = Tcl_NewListObj(0, NULL);
	Tcl_ListObjAppendElement(interp, result, Tcl_NewIntObj(fildes[0]));
	Tcl_ListObjAppendElement(interp, result, Tcl_NewIntObj(fildes[1]));
	Tcl_SetObjResult(interp, result);

	return TCL_OK;
}
