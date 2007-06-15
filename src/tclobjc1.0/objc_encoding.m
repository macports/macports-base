/*
 * objc_encoding.m
 *
 * Copyright (c) 2004 Landon J. Fuller <landonf@macports.org>
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
 * 3. Neither the name of the copyright owner nor the names of contributors
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

/* Required by glibc for asprintf() */
#define _GNU_SOURCE

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <tcl.h>

#include "tclobjc.h"
#include "objc_encoding.h"
#include "tclobjc_types.h"

int objc_to_tclobj(Tcl_Interp *interp, Tcl_Obj **objPtr, const char *type, void *val) {
	Tcl_Obj *tcl_result;
	char *name;

	switch(*type) {
		case _C_CHARPTR:
			*objPtr = Tcl_NewStringObj((char *) val, -1);
			return (TCL_OK);
		case _C_INT:
			*objPtr = Tcl_NewIntObj((int) val);
			return (TCL_OK);
		case _C_ID:
			*objPtr = TclObjC_NewIdObj(val);
			name = Tcl_GetString(*objPtr);
			Tcl_CreateObjCommand(interp, (char *) name, tclobjc_dispatch, (id) val, NULL);
			return (TCL_OK);
		default:
			/* Unhandled objc type encoding */
			if (interp) {
				tcl_result = Tcl_NewStringObj("Invalid objc type encoding: ", -1);
				Tcl_AppendToObj(tcl_result, type, -1);
				Tcl_SetObjResult(interp, tcl_result);
			}
			return (TCL_ERROR);
	}
}

int tclobj_to_objc(Tcl_Interp *interp, void **val, const char *type, Tcl_Obj *objPtr) {
	Tcl_Obj *tcl_result;

	switch(*type) {
		char *ptr;
		int length;
		case _C_CHARPTR:
			ptr = Tcl_GetStringFromObj(objPtr, &length);
			*val = malloc(length);
			if (*val == NULL)
				return (TCL_ERROR);

			memcpy(*val, ptr, length);
			return (TCL_OK);
		case _C_INT:
			*val = malloc(sizeof(int));
			if (*val == NULL)
				return (TCL_ERROR);

			if (Tcl_GetIntFromObj(interp, objPtr, *val) != TCL_OK) {
				free(*val);
				return (TCL_ERROR);
			} else {
				return (TCL_OK);
			}

		case _C_ID:
			*val = malloc(sizeof(id));
			if (TclObjC_GetIdFromObj(interp, objPtr, *val) != TCL_OK) {
				free(*val);
				return (TCL_ERROR);
			} else {
				return (TCL_OK);
			}
		default:
			/* Unhandled objc type encoding */
			if (interp) {
				tcl_result = Tcl_NewStringObj("Invalid objc type encoding: ", -1);
				Tcl_AppendToObj(tcl_result, type, -1);
				Tcl_SetObjResult(interp, tcl_result);
			}
			return (TCL_ERROR);
	}
}
