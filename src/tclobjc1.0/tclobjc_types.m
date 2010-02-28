/*
 * TclObjTypes.c
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

#include <Foundation/Foundation.h>
#include <objc/objc.h>

#include <tcl.h>

/*
 * Tcl Objc Id Object
 */

/** All (evil) Objective-C string pointer representations start with a common prefix. */
static const char tclobjc_name_prefix[] = "objc.id-";

/** Invalid Objective-C pointer string representation. */
static const char tclobjc_invalid_string_error[] = "Invalid Objective-C object: ";

/* Standard prototypes */
static void free_objc_internalrep(Tcl_Obj *objPtr);
static void dup_objc_internalrep(Tcl_Obj *srcPtr, Tcl_Obj *dupPtr);
static void update_objc_string(Tcl_Obj *objPtr);
static int set_objc_fromstring(Tcl_Interp *interp, Tcl_Obj *objPtr);

static Tcl_ObjType tclObjcIdType = {
	/* Name */
	"tclObjcId",
	/* Tcl_FreeInternalRepProc */
	&free_objc_internalrep,
	/* Tcl_DupInternalRepProc */
	&dup_objc_internalrep,
	/* Tcl_UpdateStringProc */
	&update_objc_string,
	/* Tcp_SetFromAnyProc */
	&set_objc_fromstring
};

/*
 * Private Functions
 */

/**
 * Release the internal objective-c instance.
 */
static void free_objc_internalrep(Tcl_Obj *objPtr UNUSED) {
    /* TODO cleanup */
}

/**
 * Duplicate the internal objective-c pointer.
 */
static void dup_objc_internalrep(Tcl_Obj *srcPtr, Tcl_Obj *dupPtr) {
	dupPtr->internalRep.otherValuePtr = srcPtr->internalRep.otherValuePtr;
}


/**
 * Update the string value based on the internal pointer address.
 */
static void update_objc_string (Tcl_Obj *objPtr) {
	char *string;
	int length;

	if ((length = asprintf(&string, "objc.id-%p", objPtr->internalRep.otherValuePtr)) <= 0) {
		/* ack! malloc failed! */
		abort();
	}

	/* Terminating NULL */
	length++;

	/* objPtr->bytes must be allocated with Tcl_Alloc */
	objPtr->bytes = Tcl_Alloc(length);
	strncpy(objPtr->bytes, string, length);
	free(string);
}

/**
 * Evil piece of code that set's the internal ObjC pointer value by
 * converting the provided string value.
 */
static int set_objc_fromstring (Tcl_Interp *interp, Tcl_Obj *objPtr) {
	Tcl_ObjType *oldTypePtr = objPtr->typePtr;
	Tcl_Obj *tcl_result;
	char *string, *p;
	id objcId;
	int length;

	string = Tcl_GetStringFromObj(objPtr, &length);

	/* Verify that this is a valid string */
	if ((length < (int)sizeof(tclobjc_name_prefix)) ||
			(strncmp(string, tclobjc_name_prefix,
				 sizeof(tclobjc_name_prefix)) != 0)) {
			goto invalid_obj;
	}

	p = string + sizeof(tclobjc_name_prefix);

	if (sscanf(p, "%p", (void **)&objcId) != 1)
		goto invalid_obj;
	
	/* Free the old internal representation before setting new one */
	if (oldTypePtr != NULL && oldTypePtr->freeIntRepProc != NULL) {
		oldTypePtr->freeIntRepProc(objPtr);
	}

	objPtr->internalRep.otherValuePtr = objcId;
	objPtr->typePtr = &tclObjcIdType;

	return (TCL_OK);


	/* Cleanup Handler */
invalid_obj:
	if (interp) {
		tcl_result = Tcl_NewStringObj(tclobjc_invalid_string_error, sizeof(tclobjc_invalid_string_error));
		Tcl_AppendObjToObj(tcl_result, objPtr);
		Tcl_SetObjResult(interp, tcl_result);
	}
	return (TCL_ERROR);
}

/*
 * Public Functions
 */

/**
 * Create a new Tcl Object wrapper for a given Objective-C object.
 */
Tcl_Obj *TclObjC_NewIdObj(id objcId) {
	Tcl_Obj *objPtr;

	objPtr = Tcl_NewObj();

	objPtr->bytes = NULL;

	objPtr->internalRep.otherValuePtr = [objcId retain]; /* this is a leak */
	objPtr->typePtr = &tclObjcIdType;
	return (objPtr);
}

/**
 * Returns a pointer to the wrapped Objective-C object.
 */
int TclObjC_GetIdFromObj(Tcl_Interp *interp, Tcl_Obj *objPtr, id *objcId)
{
	int result;

	if (objPtr->typePtr == &tclObjcIdType) {
		*objcId = objPtr->internalRep.otherValuePtr;
		return (TCL_OK);
	}

	result = set_objc_fromstring(interp, objPtr);

	if (result == TCL_OK)
		*objcId = objPtr->internalRep.otherValuePtr;

	return (result);
}

/**
 * Register the Tcl Objective-C Object type(s).
 */
void TclObjC_RegisterTclObjTypes(void) {
	Tcl_RegisterObjType(&tclObjcIdType);
}
