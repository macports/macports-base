/*
 * tclobjc.m
 *
 * Copyright (c) 2003 Kevin Van Vechten <kvv@apple.com>
 * Copyright (c) 2004 Landon J. Fuller <landonf@macports.org>
 * Copyright (c) 2003 Apple Computer, Inc.
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

#include <Foundation/Foundation.h>
#include <tcl.h>

#include "objc_encoding.h"
#include "MPMethodSignatureExtensions.h"
#include "tclobjc_types.h"

/*
 * Dispatch an Objective-C method call
 */
int tclobjc_dispatch(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	int result = TCL_OK;
	id target = (id)clientData;
	SEL selector;
	Tcl_Obj *selname;
	int i = 1;
	fprintf(stderr, "objc = %d\n", objc);

	if (objc < 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "arguments");
        result = TCL_ERROR;
        goto cleanup;
	}

    /* Look up the selector */
	selname = Tcl_NewObj();
	for (i = 1; i < objc; i += 2) {
		Tcl_AppendObjToObj(selname, objv[i]);
	}
	
	fprintf(stderr, "selector = %s\n", Tcl_GetString(selname));

#if defined(GNU_RUNTIME)
	selector = sel_get_uid(Tcl_GetString(selname));
#elif defined(APPLE_RUNTIME)
	selector = sel_getUid(Tcl_GetString(selname));
#endif

    /* If the selector isn't found, error out */
	if (!selector) {
		Tcl_Obj* tcl_result = Tcl_NewStringObj("Invalid selector specified", -1);
		Tcl_SetObjResult(interp, tcl_result);
		result = TCL_ERROR;
        goto cleanup;
	}

//		fprintf(stderr, "target = %08x\n", target);
	NSMethodSignature* signature = [target methodSignatureForSelector:selector];
	NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setTarget:target];
	[invocation setSelector:selector];

    /* Build our arguments list */
	for (i = 2; i < objc; i += 2) {
		int arg_num = i / 2 + 1;

		const char* arg_type = tclobjc_getarg_typestring(signature, arg_num);
		fprintf(stderr, "argument type %s\n", arg_type);
		if (arg_type[0] == _C_ID) {
			id obj;
			if (TclObjC_GetIdFromObj(interp, objv[i], &obj) == TCL_OK) {
				[invocation setArgument:&obj atIndex:arg_num];
			}
		} else if (arg_type[0] == _C_INT) {
			int word = 0;
			if (Tcl_GetIntFromObj(interp, objv[i], &word) == TCL_OK) {
				[invocation setArgument:&word atIndex:arg_num];
			}
		} else if (arg_type[0] == _C_UINT) {
            long value;
            if (Tcl_GetLongFromObj(interp, objv[i], &value) == TCL_OK) {
                if (value > UINT_MAX || value < 0) {
                    NSString *str = [NSString stringWithFormat:@"Unsigned integer argument invalid: %ld", value];
                    Tcl_Obj *tcl_result = Tcl_NewStringObj([str cString], -1);
                    Tcl_SetObjResult(interp, tcl_result);
                    result = TCL_ERROR;
                } else {
                    unsigned int word = value;
                    [invocation setArgument:&value atIndex:arg_num];
                }
            }
		} else if (arg_type[0] == _C_CHARPTR) {
			int length;
			char* buf = Tcl_GetStringFromObj(objv[i], &length);
			if (buf)
				[invocation setArgument:&buf atIndex:arg_num];
		} else {
			NSString* str = [NSString stringWithFormat:@"unexpected argument type %s at %s:%d", arg_type, __FILE__, __LINE__];
			Tcl_Obj* tcl_result = Tcl_NewStringObj([str cString], -1);
			Tcl_SetObjResult(interp, tcl_result);
			result = TCL_ERROR;
			break;
		}
	}

    /* If all is well, invoke the Objective-C method. */
	if (result == TCL_OK) {
		Tcl_Obj *tcl_result;
		[invocation invoke];
		fprintf(stderr, "result size = %d\n", [signature methodReturnLength]);
		void* result_ptr;
		[invocation getReturnValue:&result_ptr];        
		
		const char* result_type = tclobjc_getreturn_typestring(signature);
		result = objc_to_tclobj(interp, &tcl_result, result_type, result_ptr);
		Tcl_SetObjResult(interp, tcl_result);
	}

cleanup:
	[pool release];
	return result;
}


/*
 * Invoke the standard 'unknown' procedure
 */
static int StandardUnknownObjCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
	Tcl_CmdInfo info;
	int result;
	if (!Tcl_GetCommandInfo(interp, "tclobjc::standard_unknown", &info) || !info.isNativeObjectProc)
		return (TCL_ERROR);

	result = (*info.objProc) (info.objClientData, interp, objc, objv);

	/*
	 * Make sure the string value of the result is valid.
	 */
	(void) Tcl_GetStringResult(interp);

	return (result);
}


/*
 * Replacement 'unknown' procedure.
 * Dispatches messages to Objective C classes, if one exists, or calls
 * standard 'unknown' procedure
 */
static int UnknownObjCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
	const char *className;
	id classId;
	Tcl_Obj **sobjv;
	int sobjc, result;

	if (objc < 2) {
		return (StandardUnknownObjCmd(NULL, interp, objc, objv));
	}

	className = Tcl_GetStringFromObj(objv[1], NULL);

	/*
	 * In the GNU Objective-C runtime, objc_getClass calls
	 * abort() if the class is not found.
	 *
	 * On Mac OS X (10.0+), if the class is not found, objc_getClass
	 * calls the class handler call back, and checks again.
	 * If the class is again not found, objc_getClass returns nil
	 */
#if defined(APPLE_RUNTIME)
	if ((classId = objc_getClass(className)) == nil)
#elif defined(GNU_RUNTIME)
	if ((classId = objc_lookUpClass(className)) == nil)
#endif
		return (StandardUnknownObjCmd(NULL, interp, objc, objv));

	if (objc < 3) {
			Tcl_WrongNumArgs(interp, 1, objv, "arguments");
			return TCL_ERROR;
	}

	/* dispatch, minus first argument */
	sobjc = objc - 1;
	sobjv = malloc(sobjc * sizeof(Tcl_Obj));
	memcpy(sobjv, &objv[1], sobjc * sizeof(Tcl_Obj));
	result = tclobjc_dispatch((ClientData *) classId, interp, sobjc, sobjv);
	free(sobjv);
	return (result);
}

int Tclobjc_Init(Tcl_Interp *interp)
{
	if(Tcl_InitStubs(interp, "8.3", 0) == NULL)
		return (TCL_ERROR);

	/* Register custom Tcl_Obj types */
	TclObjC_RegisterTclObjTypes();

	if(Tcl_Eval(interp, "rename ::unknown tclobjc::standard_unknown") != TCL_OK)
		return (TCL_ERROR);
	Tcl_CreateObjCommand(interp, "unknown", UnknownObjCmd, NULL, NULL);

	if(Tcl_PkgProvide(interp, "TclObjC", "1.0") != TCL_OK)
		return TCL_ERROR;
	return TCL_OK;
}
