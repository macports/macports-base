/*
 * CFLib.c
 * CFLib.dylib
 * $Id$
 *
 * Copyright (c) 2003 Kevin Van Vechten <kevin@opendarwin.org>
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

#include <tcl.h>
#include <CoreFoundation/CoreFoundation.h>

/*
	Wildebeest
	TCL bindings for CoreFoundation
	
	Currently CFString, CFData, CFURL, CFArray, and CFDictionary are
	toll free bridged.
	
	Most of CFArray, CFDictionary, CFBundle, and CFPropertyList
	have been implemented.
	
	TODO:
		Toll free bridges for CFNumber, CFDate, CFBoolean.
 */

/* CFBase.h */

/* CFType ObjType */
static int tclObjToCFString(Tcl_Interp*, Tcl_Obj*, CFTypeRef*);
static int tclObjToCFType(Tcl_Interp* interp, Tcl_Obj* obj, CFTypeRef* outPtr) {
	*outPtr = NULL;
	if (obj->typePtr == Tcl_GetObjType("CFString") ||
		obj->typePtr == Tcl_GetObjType("CFData") ||
		obj->typePtr == Tcl_GetObjType("CFURL") ||
		obj->typePtr == Tcl_GetObjType("CFNumber") ||
		obj->typePtr == Tcl_GetObjType("CFArray") ||
		obj->typePtr == Tcl_GetObjType("CFDictionary") ||
		obj->typePtr == Tcl_GetObjType("CFBundle") ||
		obj->typePtr == Tcl_GetObjType("CFType")) {
		*outPtr = CFRetain(obj->internalRep.otherValuePtr);
	} else {
		return tclObjToCFString(interp, obj, outPtr);
	}
	return TCL_OK;
}

static void cfTypeDupInternalRepProc(Tcl_Obj* srcPtr, Tcl_Obj* dupPtr) {
	dupPtr->typePtr = srcPtr->typePtr;
	CFTypeRef cf = srcPtr->internalRep.otherValuePtr;
	dupPtr->internalRep.otherValuePtr = cf ? (void*)CFRetain(cf) : NULL;
}

static void cfTypeFreeInternalRepProc(Tcl_Obj* objPtr) {
	objPtr->typePtr = NULL;
	CFTypeRef cf = objPtr->internalRep.otherValuePtr;
	if (cf) CFRelease(cf);
}

static void cfTypeUpdateStringProc2(Tcl_Obj* objPtr, CFStringRef str) {
	if (str) {
		CFIndex length = CFStringGetLength(str);
		CFIndex size = CFStringGetMaximumSizeForEncoding(length + 1, kCFStringEncodingUTF8);
		objPtr->bytes = Tcl_Alloc(size);
		if (objPtr->bytes) {
			CFIndex bytesUsed;
			CFStringGetBytes(str, CFRangeMake(0, length), kCFStringEncodingUTF8, '?', 0, objPtr->bytes, size, &bytesUsed);
			objPtr->length = bytesUsed;
			objPtr->bytes[bytesUsed] = 0;	// terminating NUL as per TCL spec.
		}
	}
}

static void cfTypeUpdateStringProc(Tcl_Obj* objPtr) {
	CFTypeRef cf = objPtr->internalRep.otherValuePtr;
	if (cf) {
		CFStringRef str = CFCopyDescription(cf);
		if (str) {
			cfTypeUpdateStringProc2(objPtr, str);
			CFRelease(str);
		}
	}
}

static int cfTypeSetFromAnyProc(Tcl_Interp* interp, Tcl_Obj* objPtr) {
	Tcl_Obj* tcl_result = Tcl_NewStringObj("CFTypes must be created with CF constructors", -1);
	Tcl_SetObjResult(interp, tcl_result);
	return TCL_ERROR;
}

static void cfTypeRegister() {
	static Tcl_ObjType cfTypeType;
	cfTypeType.name = "CFType";
	cfTypeType.freeIntRepProc = cfTypeFreeInternalRepProc;
	cfTypeType.dupIntRepProc = cfTypeDupInternalRepProc;
	cfTypeType.updateStringProc = cfTypeUpdateStringProc;
	cfTypeType.setFromAnyProc = cfTypeSetFromAnyProc;
	Tcl_RegisterObjType(&cfTypeType);
}




/* CFString.h */

// tcl string -> CFString implicit conversion
static int tclObjToCFString(Tcl_Interp* interp, Tcl_Obj* obj, CFTypeRef* outString) {
	*outString = NULL;
	if (obj->typePtr != Tcl_GetObjType("CFString")) {
		int length;
		char* buf = Tcl_GetStringFromObj(obj, &length);
		if (buf) {
			*outString = CFStringCreateWithBytes(NULL, buf, length, kCFStringEncodingUTF8, 0);
		} else {
			return TCL_ERROR;
		}
	} else {
		*outString = CFRetain(obj->internalRep.otherValuePtr);
	}
	return TCL_OK;
}

// CFString -> tcl string implicit conversion
static Tcl_Obj* cfStringToTCLString(CFStringRef cf) {
	Tcl_Obj* tcl_result = NULL;
	if (cf) {
		CFIndex length = CFStringGetLength(cf);
		CFIndex size = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUnicode);
		UniChar* buffer = (UniChar*)Tcl_Alloc(size);
		if (buffer) {
			CFStringGetCharacters(cf, CFRangeMake(0, length), buffer);
			tcl_result = Tcl_NewUnicodeObj(buffer, length);
			Tcl_Free((char*)buffer);
		}
	}
	return tcl_result;
}


/* CFString ObjType */

static int cfStringSetFromAnyProc(Tcl_Interp* interp, Tcl_Obj* objPtr) {
	if (objPtr->bytes) {
		objPtr->internalRep.otherValuePtr = (void*)CFStringCreateWithBytes(NULL, 
												objPtr->bytes,
												objPtr->length,
												kCFStringEncodingUTF8,
												0);
		return TCL_OK;
	} else {
		return TCL_ERROR;
	}
}

static void cfStringUpdateStringProc(Tcl_Obj* objPtr) {
	cfTypeUpdateStringProc2(objPtr, objPtr->internalRep.otherValuePtr);
}

static void cfStringRegister() {
	static Tcl_ObjType cfStringType;
	cfStringType.name = "CFString";
	cfStringType.freeIntRepProc = cfTypeFreeInternalRepProc;
	cfStringType.dupIntRepProc = cfTypeDupInternalRepProc;
	cfStringType.updateStringProc = cfStringUpdateStringProc;
	cfStringType.setFromAnyProc = cfStringSetFromAnyProc;
	Tcl_RegisterObjType(&cfStringType);
}

/* CFData.h */
/* CFData ObjType */

// tcl string -> CFData implicit conversion
static int tclObjToCFData(Tcl_Interp* interp, Tcl_Obj* obj, CFTypeRef* outData) {
	*outData = NULL;
	if (obj->typePtr != Tcl_GetObjType("CFData")) {
		int length;
		char* buf = Tcl_GetStringFromObj(obj, &length);
		if (buf) {
			*outData = CFDataCreate(NULL, buf, length);
		} else {
			return TCL_ERROR;
		}
	} else {
		*outData = CFRetain(obj->internalRep.otherValuePtr);
	}
	return TCL_OK;
}

static int cfDataSetFromAnyProc(Tcl_Interp* interp, Tcl_Obj* objPtr) {
	if (objPtr->bytes) {
		objPtr->internalRep.otherValuePtr = (void*)CFDataCreate(NULL, 
												objPtr->bytes,
												objPtr->length);
		return TCL_OK;
	} else {
		return TCL_ERROR;
	}
}

static void cfDataUpdateStringProc(Tcl_Obj* objPtr) {
	CFDataRef data = objPtr->internalRep.otherValuePtr;
	if (data) {
		CFIndex length = CFDataGetLength(data);
		objPtr->bytes = Tcl_Alloc(length);
		if (objPtr->bytes) {
			CFDataGetBytes(data, CFRangeMake(0, length), objPtr->bytes);
			objPtr->length = length;
		}
	}
}

static void cfDataRegister() {
	static Tcl_ObjType cfDataType;
	cfDataType.name = "CFData";
	cfDataType.freeIntRepProc = cfTypeFreeInternalRepProc;
	cfDataType.dupIntRepProc = cfTypeDupInternalRepProc;
	cfDataType.updateStringProc = cfDataUpdateStringProc;
	cfDataType.setFromAnyProc = cfDataSetFromAnyProc;
	Tcl_RegisterObjType(&cfDataType);
}


/* CFArray.h */
/* CFArray ObjType */

// tcl list -> CFArray implicit conversion
static int tclObjToCFArray(Tcl_Interp* interp, Tcl_Obj* obj, CFTypeRef* outPtr) {
	int result = TCL_OK;
	*outPtr = NULL;
	if (obj->typePtr != Tcl_GetObjType("CFArray")) {
		int objc;
		Tcl_Obj** objv;
		result = Tcl_ListObjGetElements(interp, obj, &objc, &objv);
		if (result == TCL_OK) {
			const void** argv = (const void**)Tcl_Alloc(sizeof(void*) * objc);
			int i;
			for (i = 0; i < objc; ++i) {
				result = tclObjToCFType(interp, objv[i], (CFTypeRef*)&argv[i]);
				if (result != TCL_OK) break;
			}
			if (result == TCL_OK) {
				*outPtr = CFArrayCreate(NULL, argv, objc, &kCFTypeArrayCallBacks);
			}
			Tcl_Free((char*)argv);
		}
	} else {
		*outPtr = CFRetain(obj->internalRep.otherValuePtr);
	}
	return result;
}

static int cfArraySetFromAnyProc(Tcl_Interp* interp, Tcl_Obj* objPtr) {
	Tcl_Obj* tcl_result = Tcl_NewStringObj("CFArrays must be created with CFArrayCreate", -1);
	Tcl_SetObjResult(interp, tcl_result);
	return TCL_ERROR;
}

static void cfArrayRegister() {
	static Tcl_ObjType cfArrayType;
	cfArrayType.name = "CFArray";
	cfArrayType.freeIntRepProc = cfTypeFreeInternalRepProc;
	cfArrayType.dupIntRepProc = cfTypeDupInternalRepProc;
	cfArrayType.updateStringProc = cfTypeUpdateStringProc;
	cfArrayType.setFromAnyProc = cfArraySetFromAnyProc;
	Tcl_RegisterObjType(&cfArrayType);
}


/* CFDictionary.h */
/* CFDictionary ObjType */
// tcl list -> CFDictionary implicit conversion
static int tclObjToCFDictionary(Tcl_Interp* interp, Tcl_Obj* obj, CFTypeRef* outPtr) {
	int result = TCL_OK;
	*outPtr = NULL;
	if (obj->typePtr != Tcl_GetObjType("CFDictionary")) {
		int objc;
		Tcl_Obj** objv;
		result = Tcl_ListObjGetElements(interp, obj, &objc, &objv);
		if (result == TCL_OK) {			
			if (objc & 1) {
				Tcl_Obj* tcl_result = Tcl_NewStringObj("list must have an even number of elements", -1);
				Tcl_SetObjResult(interp, tcl_result);
				result = TCL_ERROR;
			} else {
				const void** keys = (const void**)Tcl_Alloc(sizeof(void*) * objc / 2);
				const void** vals = (const void**)Tcl_Alloc(sizeof(void*) * objc / 2);
				int i, j;
				for (i = 0, j = 0; i < objc; i += 2, ++j) {
					result = tclObjToCFType(interp, objv[i], (CFTypeRef*)&keys[j]);
					if (result != TCL_OK) break;
					result = tclObjToCFType(interp, objv[i+1], (CFTypeRef*)&vals[j]);
					if (result != TCL_OK) break;
				}
				if (result == TCL_OK) {
					*outPtr = CFDictionaryCreate(NULL, keys, vals, objc / 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
				}
				Tcl_Free((char*)keys);
				Tcl_Free((char*)vals);
			}
		}
	} else {
		*outPtr = CFRetain(obj->internalRep.otherValuePtr);
	}
	return result;
}

static int cfDictionarySetFromAnyProc(Tcl_Interp* interp, Tcl_Obj* objPtr) {
	Tcl_Obj* tcl_result = Tcl_NewStringObj("CFDictionaries must be created with CFDictionaryCreate", -1);
	Tcl_SetObjResult(interp, tcl_result);
	return TCL_ERROR;
}

static void cfDictionaryRegister() {
	static Tcl_ObjType cfDictionaryType;
	cfDictionaryType.name = "CFDictionary";
	cfDictionaryType.freeIntRepProc = cfTypeFreeInternalRepProc;
	cfDictionaryType.dupIntRepProc = cfTypeDupInternalRepProc;
	cfDictionaryType.updateStringProc = cfTypeUpdateStringProc;
	cfDictionaryType.setFromAnyProc = cfDictionarySetFromAnyProc;
	Tcl_RegisterObjType(&cfDictionaryType);
}

/* CFNumber.h */
/* CFNumber ObjType */

static int cfNumberSetFromAnyProc(Tcl_Interp* interp, Tcl_Obj* objPtr) {
	Tcl_Obj* tcl_result = Tcl_NewStringObj("CFNumbers must be created with CFNumberCreate", -1);
	Tcl_SetObjResult(interp, tcl_result);
	return TCL_ERROR;
}

// XXX: consolidate with cfStringUpdateStringProc
static void cfNumberUpdateStringProc(Tcl_Obj* objPtr) {
	CFNumberRef number = objPtr->internalRep.otherValuePtr;
	CFStringRef str = CFStringCreateWithFormat(NULL, NULL, CFSTR("%@"), number);
	if (str) {
		cfTypeUpdateStringProc2(objPtr, str);
		CFRelease(str);
	}
}

static void cfNumberRegister() {
	static Tcl_ObjType cfNumberType;
	cfNumberType.name = "CFNumber";
	cfNumberType.freeIntRepProc = cfTypeFreeInternalRepProc;
	cfNumberType.dupIntRepProc = cfTypeDupInternalRepProc;
	cfNumberType.updateStringProc = cfNumberUpdateStringProc;
	cfNumberType.setFromAnyProc = cfNumberSetFromAnyProc;
	Tcl_RegisterObjType(&cfNumberType);
}

//CFNumberRef CFNumberCreate(CFAllocatorRef allocator, CFNumberType theType, const void *valuePtr);
int tclCFNumberCreate(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
	CFStringRef string;
	int			result = TCL_OK;
	Tcl_Obj*	tcl_result;
	char*		theType;
	if (objc != 3) {
		Tcl_WrongNumArgs(interp, 1, objv, "theType value");
		return TCL_ERROR;
	}
	theType = Tcl_GetStringFromObj(objv[1], NULL);
	
	tcl_result = Tcl_NewObj();
	tcl_result->typePtr = Tcl_GetObjType("CFNumber");
	tcl_result->bytes = NULL;
	tcl_result->length = 0;
	
	// This may be cutting corners, but since property lists only
	// distinguish between real and integer, we'll only make that
	// distinction here too.
	if (strcmp(theType, "kCFNumberSInt8Type") == 0 ||
		strcmp(theType, "kCFNumberSInt16Type") == 0 ||
		strcmp(theType, "kCFNumberSInt32Type") == 0 ||
		strcmp(theType, "kCFNumberSInt64Type") == 0 ||
		strcmp(theType, "kCFNumberCharType") == 0 ||
		strcmp(theType, "kCFNumberShortType") == 0 ||
		strcmp(theType, "kCFNumberIntType") == 0 ||
		strcmp(theType, "kCFNumberLongType") == 0 ||
		strcmp(theType, "kCFNumberLongLongType") == 0 ||
		strcmp(theType, "kCFNumberCFIndexType") == 0) {
			long val;
			result = Tcl_GetLongFromObj(interp, objv[2], &val);
			if (result == TCL_ERROR) return result;
			tcl_result->internalRep.otherValuePtr = (void*)CFNumberCreate(NULL, kCFNumberLongType, &val);
	} else if (strcmp(theType, "kCFNumberFloatType") == 0 ||
		strcmp(theType, "kCFNumberDoubleType") == 0 ||
		strcmp(theType, "kCFNumberFloat32Type") == 0 ||
		strcmp(theType, "kCFNumberFloat64Type") == 0) {
			double val;
			result = Tcl_GetDoubleFromObj(interp, objv[2], &val);
			if (result == TCL_ERROR) return result;
			tcl_result->internalRep.otherValuePtr = (void*)CFNumberCreate(NULL, kCFNumberDoubleType, &val);		
	} else {
		Tcl_Obj* tcl_result = Tcl_NewStringObj("unknown CFNumberType", -1);
		Tcl_SetObjResult(interp, tcl_result);
		return TCL_ERROR;
	}
	Tcl_SetObjResult(interp, tcl_result);
	return result;
}


/* CFURL.h */

// tcl string -> CFString implicit conversion
static int tclObjToCFURL(Tcl_Interp* interp, Tcl_Obj* obj, CFTypeRef* outURL) {
	*outURL = NULL;
	if (obj->typePtr != Tcl_GetObjType("CFURL")) {
		int length;
		char* buf = Tcl_GetStringFromObj(obj, &length);
		if (buf) {
			*outURL = CFURLCreateWithBytes(NULL, buf, length, kCFStringEncodingUTF8, NULL);
		} else {
			return TCL_ERROR;
		}
	} else {
		*outURL = CFRetain(obj->internalRep.otherValuePtr);
	}
	return TCL_OK;
}
/*
// CFString -> tcl string implicit conversion
static Tcl_Obj* cfURLToTCLString(CFURLRef url) {
	CFDataRef data = CFURLCreateData(NULL, url, kCFStringEncodingUTF8, 1);
	Tcl_Obj* tcl_result = NULL;
	if (data) {
		CFIndex length = CFDataGetLength(data);
		char* buffer = Tcl_Alloc(length);
		if (buffer) {
			CFDataGetBytes(data, CFRangeMake(0, length), buffer);
			tcl_result = Tcl_NewStringObj(buffer, length);
			Tcl_Free(buffer);
		}
	}
	return tcl_result;
}
*/

/* CFString ObjType */

static int cfURLSetFromAnyProc(Tcl_Interp* interp, Tcl_Obj* objPtr) {
	if (objPtr->bytes) {
		objPtr->internalRep.otherValuePtr = (void*)CFURLCreateWithBytes(NULL, 
												objPtr->bytes,
												objPtr->length,
												kCFStringEncodingUTF8,
												NULL);
		if (objPtr->internalRep.otherValuePtr == NULL) return TCL_ERROR;
		return TCL_OK;
	} else {
		return TCL_ERROR;
	}
}

static void cfURLUpdateStringProc(Tcl_Obj* objPtr) {
	CFURLRef url = objPtr->internalRep.otherValuePtr;
	if (url) {
		CFURLRef absurl = CFURLCopyAbsoluteURL(url);
		if (absurl) {
			CFStringRef str = CFURLGetString(absurl);
			cfTypeUpdateStringProc2(objPtr, str);
			CFRelease(absurl);
		}
	}
}

static void cfURLRegister() {
	static Tcl_ObjType cfURLType;
	cfURLType.name = "CFURL";
	cfURLType.freeIntRepProc = cfTypeFreeInternalRepProc;
	cfURLType.dupIntRepProc = cfTypeDupInternalRepProc;
	cfURLType.updateStringProc = cfURLUpdateStringProc;
	cfURLType.setFromAnyProc = cfURLSetFromAnyProc;
	Tcl_RegisterObjType(&cfURLType);
}




/* CFBase.h */

static Tcl_Obj* cfTypeToTCLString(CFTypeRef cf) {
	if (CFGetTypeID(cf) == CFStringGetTypeID()) {
		return cfStringToTCLString(cf);
	} else {
		CFStringRef string = CFCopyDescription(cf);
		return cfStringToTCLString(string);
	}
}


// CFGetTypeID(cf)
int tclCFGetTypeID(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
	CFTypeRef cf;
	Tcl_Obj* tcl_result;
	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "cftype");
		return TCL_ERROR;
	}
	cf = objv[1]->internalRep.otherValuePtr;
	if (cf) {
		// xxx: test for valid objv[1]->typePtr;
		tcl_result = Tcl_NewIntObj(CFGetTypeID(cf));
		if (!tcl_result) return TCL_ERROR;
		Tcl_SetObjResult(interp, tcl_result);
		return TCL_OK;
	} else {
		return TCL_ERROR;
	}
}

// CFNumberGetTypeID(), CFStringGetTypeID(), et al.
int tclCFGetTypeID2(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
	Tcl_Obj* tcl_result;
	if (objc != 1) {
		Tcl_WrongNumArgs(interp, 1, objv, "");
		return TCL_ERROR;
	}
	tcl_result = Tcl_NewIntObj((int)clientData);
	if (!tcl_result) return TCL_ERROR;
	Tcl_SetObjResult(interp, tcl_result);
	return TCL_OK;
}


/* CFPropertyList.h */

static int tclObjToCFPropertyList(Tcl_Interp* interp, Tcl_Obj* obj, CFTypeRef* outPtr) {
	*outPtr = NULL;
	if (obj->typePtr == Tcl_GetObjType("CFString") ||
		obj->typePtr == Tcl_GetObjType("CFData") ||
		obj->typePtr == Tcl_GetObjType("CFNumber") ||
		obj->typePtr == Tcl_GetObjType("CFArray") ||
		obj->typePtr == Tcl_GetObjType("CFDictionary")) {
		*outPtr = CFRetain(obj->internalRep.otherValuePtr);
	} else {
		return tclObjToCFString(interp, obj, outPtr);
	}
	return TCL_OK;
}

static int tclObjToCFPropertyListFormat(Tcl_Interp* interp, Tcl_Obj* obj, CFTypeRef* outPtr) {
	int result = TCL_OK, length;
	char* buf = Tcl_GetStringFromObj(obj, &length);
	*outPtr = NULL;
	if (buf && strcmp(buf, "kCFPropertyListOpenStepFormat") == 0) {
		*outPtr = (CFTypeRef) kCFPropertyListOpenStepFormat;
	} else if (buf && strcmp(buf, "kCFPropertyListXMLFormat_v1_0") == 0) {
		*outPtr = (CFTypeRef) kCFPropertyListXMLFormat_v1_0;
	} else if (buf && strcmp(buf, "kCFPropertyListBinaryFormat_v1_0") == 0) {
		*outPtr = (CFTypeRef) kCFPropertyListBinaryFormat_v1_0;
	} else {
		Tcl_Obj* tcl_result = Tcl_NewStringObj("invalid property list format constant", -1);
		Tcl_SetObjResult(interp, tcl_result);
		result = TCL_ERROR;
	}
	return result;
}

static int tclObjToCFMutabilityOption(Tcl_Interp* interp, Tcl_Obj* obj, CFTypeRef* outPtr) {
	int result = TCL_OK, length;
	char* buf = Tcl_GetStringFromObj(obj, &length);
	*outPtr = NULL;
	if (buf && strcmp(buf, "kCFPropertyListImmutable") == 0) {
		*outPtr = (CFTypeRef) kCFPropertyListImmutable;
	} else if (buf && strcmp(buf, "kCFPropertyListMutableContainers") == 0) {
		*outPtr = (CFTypeRef) kCFPropertyListMutableContainers;
	} else if (buf && strcmp(buf, "kCFPropertyListMutableContainersAndLeaves") == 0) {
		*outPtr = (CFTypeRef) kCFPropertyListMutableContainersAndLeaves;
	} else {
		Tcl_Obj* tcl_result = Tcl_NewStringObj("invalid mutability option constant", -1);
		Tcl_SetObjResult(interp, tcl_result);
		result = TCL_ERROR;
	}
	return result;
}



/* CFBundle.h */
/* CFBundle ObjType */

static int tclObjToCFBundle(Tcl_Interp* interp, Tcl_Obj* obj, CFTypeRef* outPtr) {
	*outPtr = NULL;
	if (obj->typePtr == Tcl_GetObjType("CFBundle")) {
		*outPtr = CFRetain(obj->internalRep.otherValuePtr);
	} else {
		Tcl_Obj* tcl_result = Tcl_NewStringObj("argument must be a CFBundle", -1);
		Tcl_SetObjResult(interp, tcl_result);
		return TCL_ERROR;
	}
	return TCL_OK;
}

static int cfBundleSetFromAnyProc(Tcl_Interp* interp, Tcl_Obj* objPtr) {
	Tcl_Obj* tcl_result = Tcl_NewStringObj("CFBundles must be created with CFBundleCreate", -1);
	Tcl_SetObjResult(interp, tcl_result);
	return TCL_ERROR;
}

static void cfBundleUpdateStringProc(Tcl_Obj* objPtr) {
	CFBundleRef bundle = objPtr->internalRep.otherValuePtr;
	if (bundle) {
		CFStringRef description = CFCopyDescription(bundle);
		if (description) {
			CFIndex length = CFStringGetLength(description);
			CFIndex size = CFStringGetMaximumSizeForEncoding(length + 1, kCFStringEncodingUTF8);
			objPtr->bytes = Tcl_Alloc(size);
			if (objPtr->bytes) {
				CFIndex bytesUsed;
				CFStringGetBytes(description, CFRangeMake(0, length), kCFStringEncodingUTF8, '?', 0, objPtr->bytes, size, &bytesUsed);
				objPtr->length = bytesUsed;
				objPtr->bytes[bytesUsed] = 0;	// terminating NUL as per TCL spec.
			}
			CFRelease(description);
		}
	}
}

static void cfBundleDupInternalRepProc(Tcl_Obj* srcPtr, Tcl_Obj* dupPtr) {
	CFBundleRef bundle = srcPtr->internalRep.otherValuePtr;
	dupPtr->internalRep.otherValuePtr = bundle ? (void*)CFRetain(bundle) : NULL;
}

static void cfBundleFreeInternalRepProc(Tcl_Obj* objPtr) {
	CFBundleRef bundle = objPtr->internalRep.otherValuePtr;
	if (bundle) CFRelease(bundle);
}

static void cfBundleRegister() {
	static Tcl_ObjType cfBundleType;
	cfBundleType.name = "CFBundle";
	cfBundleType.freeIntRepProc = cfBundleFreeInternalRepProc;
	cfBundleType.dupIntRepProc = cfBundleDupInternalRepProc;
	cfBundleType.updateStringProc = cfBundleUpdateStringProc;
	cfBundleType.setFromAnyProc = cfBundleSetFromAnyProc;
	Tcl_RegisterObjType(&cfBundleType);
}

enum {
	LITERAL,
	CFTYPE,
	CFRANGE,
	CFINDEX,
	CFERRORSTR,
	END
};

typedef struct cfParam {
	int kind;			// LITERAL (doesn't pop argument), CFTYPE (32bit), CFRANGE (64bit)
	char* class;		// if present, type check, if null, don't type check.
	int (*func)(Tcl_Interp*, Tcl_Obj*, CFTypeRef*);	// conversion function or literal value.
} cfParam;

typedef struct cfSignature {
	char* name;			// name of CF function to call
	void* func;			// pointer to CF function to call
	char* format;		// tcl format string
	char* result;		// type of result
	int releaseResult;	// true if result should be released (create and copy funcs)
	cfParam argv[10];	// description of arguments
} cfSignature;


static int tclCFFunc(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
	cfSignature* sig = (cfSignature*)clientData;
	int result = TCL_OK;
	Tcl_Obj* tcl_result;
	void* res;
	
	int i, j, k;
	void** args;

	// iterate through argv and count up all non-LITERALs
	// this is the expected objc.
	for (i = 0, j = 1; sig->argv[i].kind != END; ++i) {
		if (sig->argv[i].kind != LITERAL && sig->argv[i].kind != CFERRORSTR) ++j;
	}

	if (objc != j) {
		Tcl_WrongNumArgs(interp, 1, objv, sig->format);
		return TCL_ERROR;
	}
	
	args = (void**)Tcl_Alloc(sizeof(void*) * /* argc */ 20);

	for (i = 0, j = 0, k = 1; sig->argv[j].kind != END; ++i, ++j) {
		// i is index to local args array.
		// j is index to argv
		// k is index to objv
		
		// Copy literal value, don't pop from Tcl stack.
		switch (sig->argv[j].kind) {
			case LITERAL:
				args[i] = (void*)sig->argv[j].func;
				break;
			
			case CFTYPE:
				// test that the classes match, if both are set.
				//if (!sig->argv[j].class || objv[k]->typePtr == NULL || objv[k]->typePtr == Tcl_GetObjType(sig->argv[j].class)) {
					result = sig->argv[j].func(interp, objv[k], (CFTypeRef*) &args[i]);
				//} else {
				//	Tcl_Obj* tcl_result = Tcl_NewStringObj("argument must be a ", -1);
				//	Tcl_AppendToObj(tcl_result, sig->argv[j].class, -1);
				//	Tcl_SetObjResult(interp, tcl_result);
				//	result = TCL_ERROR;
				//}
				++k;
				break;
				
			case CFINDEX:
				result = Tcl_GetIntFromObj(interp, objv[k], (int*) &args[i]);
				++k;
				break;
				
			case CFERRORSTR:
				args[i] = (void*) Tcl_Alloc(sizeof(CFStringRef));
				break;
				
			case CFRANGE:
				++k;
			default:
				break;
		}
		if (result != TCL_OK) break;
	}
	
	if (result == TCL_OK) {
	objc = i;
	if (objc == 0) {
		res = ((void* (*)())sig->func)();
	} else if (objc == 1) {
		res = ((void* (*)(void*))sig->func)(args[0]);
	} else if (objc == 2) {
		res = ((void* (*)(void*,void*))sig->func)(args[0],args[1]);
	} else if (objc == 3) {
		res = ((void* (*)(void*,void*,void*))sig->func)(args[0],args[1],args[2]);
	} else if (objc == 4) {
		res = ((void* (*)(void*,void*,void*,void*))sig->func)(args[0],args[1],args[2],args[3]);
	} else if (objc == 5) {
		res = ((void* (*)(void*,void*,void*,void*,void*))sig->func)(args[0],args[1],args[2],args[3],args[4]);
	} else if (objc == 6) {
		res = ((void* (*)(void*,void*,void*,void*,void*,void*))sig->func)(args[0],args[1],args[2],args[3],args[4],args[5]);
	}

	if (sig->result && strcmp(sig->result, "void") != 0) {
		tcl_result = Tcl_NewObj();
		tcl_result->bytes = NULL;
		tcl_result->length = 0;
		if (strcmp(sig->result, "CFType") == 0) {
			if (res) {
				CFTypeID id = CFGetTypeID(res);
				if (id == CFStringGetTypeID()) tcl_result->typePtr = Tcl_GetObjType("CFString");
				else if (id == CFNumberGetTypeID()) tcl_result->typePtr = Tcl_GetObjType("CFNumber");
				else if (id == CFDataGetTypeID()) tcl_result->typePtr = Tcl_GetObjType("CFData");
				else if (id == CFURLGetTypeID()) tcl_result->typePtr = Tcl_GetObjType("CFURL");
				else if (id == CFBundleGetTypeID()) tcl_result->typePtr = Tcl_GetObjType("CFBundle");
				else if (id == CFDictionaryGetTypeID()) tcl_result->typePtr = Tcl_GetObjType("CFDictionary");
				else if (id == CFArrayGetTypeID()) tcl_result->typePtr = Tcl_GetObjType("CFArray");
				else tcl_result->typePtr = Tcl_GetObjType("CFType");
				tcl_result->internalRep.otherValuePtr = (void*)CFRetain(res);
				Tcl_SetObjResult(interp, tcl_result);
				if (sig->releaseResult) CFRelease(res);
			} else {
				tcl_result->typePtr = NULL;
				tcl_result->internalRep.otherValuePtr = NULL;
			}
		} else if (strcmp(sig->result, "CFIndex") == 0) {
			tcl_result = Tcl_NewIntObj((int)res);
			Tcl_SetObjResult(interp, tcl_result);
		}
	}
	} // end TCL_OK
	
	for (i = 0; sig->argv[i].kind != END; ++i) {
		if (sig->argv[i].kind == CFERRORSTR && result == TCL_OK) {
			if (*((CFStringRef*)args[i])) {
				Tcl_Obj* tcl_result = cfStringToTCLString(*((CFStringRef*)args[i]));
				Tcl_SetObjResult(interp, tcl_result);
				result = TCL_ERROR;
			}
			Tcl_Free(args[i]);
		}
	}
	
	if (args) Tcl_Free((char*)args);
	
	return result;
}

int Cflib_Init(Tcl_Interp *interp)
{
	int i;
	static cfSignature sig[] = {
		/* CFBundle.h */
		{
			"CFBundleGetMainBundle", CFBundleGetMainBundle, "", "CFType", 0,
			{ 
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleGetBundleWithIdentifier", CFBundleGetBundleWithIdentifier, "", "CFType", 0,
			{
				{ CFTYPE, "CFString", tclObjToCFString },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleGetAllBundles", CFBundleGetAllBundles, "", "CFType", 0,
			{ 
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCreate", CFBundleCreate, "bundleURL", "CFType", 1,
			{ 
				{ LITERAL, NULL, NULL },
				{ CFTYPE, "CFURL", tclObjToCFURL },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCreateBundlesFromDirectory", CFBundleCreateBundlesFromDirectory, "directoryURL bundleType", "CFType", 1,
			{ 
				{ LITERAL, NULL, NULL },
				{ CFTYPE, "CFURL", tclObjToCFURL },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopyBundleURL", CFBundleCopyBundleURL, "bundle", "CFType", 1,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleGetValueForInfoDictionaryKey", CFBundleGetValueForInfoDictionaryKey, "bundle key", "CFType", 0,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleGetInfoDictionary", CFBundleGetInfoDictionary, "bundle", "CFType", 0,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleGetLocalInfoDictionary", CFBundleGetLocalInfoDictionary, "bundle", "CFType", 0,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ END, NULL, NULL }
			}
		},
		// CFBundleGetPackageInfo
		{
			"CFBundleGetIdentifier", CFBundleGetIdentifier, "bundle", "CFType", 0,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleGetVersionNumber", CFBundleGetVersionNumber, "bundle", "CFIndex", 0,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleGetDevelopmentRegion", CFBundleGetDevelopmentRegion, "bundle", "CFType", 0,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopySupportFilesDirectoryURL", CFBundleCopySupportFilesDirectoryURL, "bundle", "CFType", 1,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopyResourcesDirectoryURL", CFBundleCopyResourcesDirectoryURL, "bundle", "CFType", 1,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopyPrivateFrameworksURL", CFBundleCopyPrivateFrameworksURL, "bundle", "CFType", 1,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopySharedFrameworksURL", CFBundleCopySharedFrameworksURL, "bundle", "CFType", 1,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopySharedSupportURL", CFBundleCopySharedSupportURL, "bundle", "CFType", 1,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopyBuiltInPlugInsURL", CFBundleCopyBuiltInPlugInsURL, "bundle", "CFType", 1,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopyInfoDictionaryInDirectory", CFBundleCopyResourcesDirectoryURL, "bundelURL", "CFType", 1,
			{
				{ CFTYPE, "CFURL", tclObjToCFURL },
				{ END, NULL, NULL }
			}
		},
		// CFBundleGetPackageInfoInDirectory
		{
			"CFBundleCopyResourceURL", CFBundleCopyResourceURL, "bundle resourceName resourceType subDirName", "CFType", 1,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopyResourceURLsOfType", CFBundleCopyResourceURLsOfType, "bundle resourceType subDirName", "CFType", 1,
			{
				{ CFTYPE, "CFBundle", tclObjToCFType },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopyLocalizedString", CFBundleCopyLocalizedString, "bundle key value tableName", "CFType", 1,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopyResourceURLInDirectory", CFBundleCopyResourceURLInDirectory, "bundleURL resourceName resourceType subDirName", "CFType", 1,
			{
				{ CFTYPE, "CFURL", tclObjToCFURL },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopyResourceURLsOfTypeInDirectory", CFBundleCopyResourceURLsOfTypeInDirectory, "bundleURL resourceType subDirName", "CFType", 1,
			{
				{ CFTYPE, "CFURL", tclObjToCFURL },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ CFTYPE, "CFString", tclObjToCFString },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopyBundleLocalizations", CFBundleCopyBundleLocalizations, "bundle", "CFType", 1,
			{
				{ CFTYPE, "CFBundle", tclObjToCFBundle },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopyPreferredLocalizationsFromArray", CFBundleCopyPreferredLocalizationsFromArray, "locArray", "CFType", 1,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ END, NULL, NULL }
			}
		},
		{
			"CFBundleCopyLocalizationsForPreferences", CFBundleCopyPreferredLocalizationsFromArray, "locArray prefArray", "CFType", 1,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ END, NULL, NULL }
			}
		},
		// CFBundleCopyResourceURLForLocalization
		// CFBundleCopyResourceURLsOfTypeForLocalization
		// CFBundleCopyInfoDictionaryForURL
		// CFBundleCopyLocalizationsForURL

		/* CFPropertyList.h */
		{
			"CFPropertyListCreateFromXMLData", CFPropertyListCreateFromXMLData, "xmlData mutabilityOption", "CFType", 1,
			{
				{ LITERAL, NULL, NULL },
				{ CFTYPE, "CFData", tclObjToCFData },
				{ CFTYPE, NULL, tclObjToCFMutabilityOption },
				{ CFERRORSTR, NULL, NULL }, // xxx: error string
				{ END, NULL, NULL }
			}
		},
		{
			"CFPropertyListCreateXMLData", CFPropertyListCreateXMLData, "propertyList", "CFType", 1,
			{
				{ LITERAL, NULL, NULL },
				{ CFTYPE, NULL, tclObjToCFPropertyList }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFPropertyListCreateDeepCopy", CFPropertyListCreateDeepCopy, "propertyList mutabilityOption", "CFType", 1,
			{
				{ LITERAL, NULL, NULL },
				{ CFTYPE, NULL, tclObjToCFPropertyList },
				{ CFTYPE, NULL, tclObjToCFMutabilityOption },
				{ END, NULL, NULL }
			}
		},
		{
			"CFPropertyListIsValid", CFPropertyListIsValid, "propertyList format", "CFIndex", 1,
			{
				{ CFTYPE, NULL, tclObjToCFPropertyList },
				{ CFTYPE, NULL, tclObjToCFPropertyListFormat },
				{ END, NULL, NULL }
			}
		},
		
		// CFPropertyListWriteToStream
		// CFPropertyListCreateFromStream
		
		/* CFArray.h */
		// CFArrayCreate
		{
			"CFArrayCreateCopy", CFArrayCreateCopy, "theArray", "CFType", 1,
			{
				{ LITERAL, NULL, NULL },
				{ CFTYPE, "CFArray", NULL },
				{ END, NULL, NULL }
			}
		},
		{
			"CFArrayCreateMutable", CFArrayCreateMutable, "capacity", "CFType", 1,
			{
				{ LITERAL, NULL, NULL },
				{ CFINDEX, "CFIndex", NULL },
				{ LITERAL, NULL, (void*)&kCFTypeArrayCallBacks },	// xxx: func to handle callbacks
				{ END, NULL, NULL }
			}
		},
		{
			"CFArrayCreateMutableCopy", CFArrayCreateMutableCopy, "capacity theArray", "CFType", 1,
			{
				{ LITERAL, NULL, NULL },
				{ CFINDEX, "CFIndex", NULL },
				{ CFTYPE, "CFArray", NULL },
				{ END, NULL, NULL }
			}
		},
		{
			"CFArrayGetCount", CFDictionaryGetCount, "theArray", "CFIndex", 0,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ END, NULL, NULL }
			}
		},
		{
			"CFArrayGetCountOfValue", CFArrayGetCountOfValue, "theArray start end value", "CFIndex", 0,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ CFINDEX, NULL, NULL },	// xxx: these part of CFRange
				{ CFINDEX, NULL, NULL }, 
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFArrayContainsValue", CFArrayContainsValue, "theArray start end value", "CFIndex", 0,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ CFINDEX, NULL, NULL },	// xxx: these part of CFRange
				{ CFINDEX, NULL, NULL }, 
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFArrayGetValueAtIndex", CFArrayGetValueAtIndex, "theArray index", "CFType", 0,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ CFINDEX, NULL, NULL }, 
				{ END, NULL, NULL }
			}
		},
		// CFArrayGetValues
		// CFArrayApplyFunction
		{
			"CFArrayGetFirstIndexOfValue", CFArrayGetFirstIndexOfValue, "theArray start end value", "CFIndex", 0,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ CFINDEX, NULL, NULL },	// xxx: these part of CFRange
				{ CFINDEX, NULL, NULL }, 
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFArrayGetLastIndexOfValue", CFArrayGetLastIndexOfValue, "theArray start end value", "CFIndex", 0,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ CFINDEX, NULL, NULL },	// xxx: these part of CFRange
				{ CFINDEX, NULL, NULL }, 
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		// CFArrayBSearchValues
		{
			"CFArrayAppendValue", CFArrayAppendValue, "theArray index", "void", 0,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFArrayInsertValueAtIndex", CFArrayInsertValueAtIndex, "theArray index value", "void", 0,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ CFINDEX, NULL, NULL },
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFArraySetValueAtIndex", CFArraySetValueAtIndex, "theArray index value", "void", 0,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ CFINDEX, NULL, NULL },
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFArrayRemoveValueAtIndex", CFArrayRemoveValueAtIndex, "theArray index", "void", 0,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ CFINDEX, NULL, NULL },
				{ END, NULL, NULL }
			}
		},
		{
			"CFArrayRemoveAllValues", CFArrayRemoveAllValues, "theArray", "void", 0,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ END, NULL, NULL }
			}
		},
		// CFArrayReplaceValues
		{
			"CFArrayExchangeValuesAtIndices", CFArrayExchangeValuesAtIndices, "theArray idx1 idx2", "void", 0,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ CFINDEX, NULL, NULL },
				{ CFINDEX, NULL, NULL },
				{ END, NULL, NULL }
			}
		},
		// CFArraySortValues
		{
			"CFArrayAppendArray", CFArrayAppendArray, "theArray otherArray start end", "void", 0,
			{
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ CFTYPE, "CFArray", tclObjToCFArray },
				{ CFINDEX, NULL, NULL },
				{ CFINDEX, NULL, NULL },
				{ END, NULL, NULL }
			}
		},
		
		
		/* CFDictionary.h */
		// CFDictionaryCreate
		{
			"CFDictionaryCreateCopy", CFDictionaryCreateCopy, "theDict", "CFType", 1,
			{
				{ LITERAL, NULL, NULL },
				{ CFTYPE, "CFDictionary", NULL },
				{ END, NULL, NULL }
			}
		},
		{
			"CFDictionaryCreateMutable", CFDictionaryCreateMutable, "capacity", "CFType", 1,
			{
				{ LITERAL, NULL, NULL },
				{ CFINDEX, "CFIndex", NULL },
				{ LITERAL, NULL, (void*)&kCFTypeDictionaryKeyCallBacks },	// xxx: func to handle callbacks
				{ LITERAL, NULL, (void*)&kCFTypeDictionaryValueCallBacks }, // xxx: func to handle callbacks
				{ END, NULL, NULL }
			}
		},
		{
			"CFDictionaryCreateMutableCopy", CFDictionaryCreateMutableCopy, "capacity theDict", "CFType", 1,
			{
				{ LITERAL, NULL, NULL },
				{ CFINDEX, "CFIndex", NULL },
				{ CFTYPE, "CFDictionary", NULL },
				{ END, NULL, NULL }
			}
		},
		{
			"CFDictionaryGetCount", CFDictionaryGetCount, "dictionary", "CFIndex", 0,
			{
				{ CFTYPE, "CFDictionary", tclObjToCFDictionary },
				{ END, NULL, NULL }
			}
		},
		{
			"CFDictionaryGetCountOfKey", CFDictionaryGetCountOfKey, "dictionary key", "CFIndex", 0,
			{
				{ CFTYPE, "CFDictionary", tclObjToCFDictionary },
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFDictionaryGetCountOfValue", CFDictionaryGetCountOfValue, "dictionary value", "CFIndex", 0,
			{
				{ CFTYPE, "CFDictionary", tclObjToCFDictionary },
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFDictionaryContainsKey", CFDictionaryContainsKey, "dictionary key", "CFIndex", 0,
			{
				{ CFTYPE, "CFDictionary", tclObjToCFDictionary },
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFDictionaryContainsValue", CFDictionaryContainsValue, "dictionary value", "CFIndex", 0,
			{
				{ CFTYPE, "CFDictionary", tclObjToCFDictionary },
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFDictionaryGetValue", CFDictionaryGetValue, "dictionary key", "CFType", 0,
			{
				{ CFTYPE, "CFDictionary", tclObjToCFDictionary },
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		// CFDictionaryGetValueIfPresent
		// CFDictionaryGetKeysAndValues
		// CFDictionaryApplyFunction
		{
			"CFDictionaryAddValue", CFDictionaryAddValue, "dictionary key value", "void", 0,
			{
				{ CFTYPE, "CFDictionary", tclObjToCFDictionary },
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFDictionarySetValue", CFDictionarySetValue, "dictionary key value", "void", 0,
			{
				{ CFTYPE, "CFDictionary", tclObjToCFDictionary },
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFDictionaryReplaceValue", CFDictionaryReplaceValue, "dictionary key value", "void", 0,
			{
				{ CFTYPE, "CFDictionary", tclObjToCFDictionary },
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFDictionaryRemoveValue", CFDictionaryRemoveValue, "dictionary key", "void", 0,
			{
				{ CFTYPE, "CFDictionary", tclObjToCFDictionary },
				{ CFTYPE, NULL, tclObjToCFType }, 
				{ END, NULL, NULL }
			}
		},
		{
			"CFDictionaryRemoveAllValues", CFDictionaryRemoveAllValues, "dictionary", "void", 0,
			{
				{ CFTYPE, "CFDictionary", tclObjToCFDictionary },
				{ END, NULL, NULL }
			}
		},
		{
			NULL, NULL, NULL, NULL, 0, { { END, NULL, NULL } }
		}
	};

	if(Tcl_InitStubs(interp, "8.4", 0) == NULL)
		return TCL_ERROR;

	for (i = 0; sig[i].name != NULL; ++i) {
		Tcl_CreateObjCommand(interp, sig[i].name, tclCFFunc, &sig[i], NULL);
	}

	cfTypeRegister();
	cfStringRegister();
	cfNumberRegister();
	cfDataRegister();
	cfBundleRegister();
	cfURLRegister();
	cfDictionaryRegister();
	cfArrayRegister();
	
	Tcl_CreateObjCommand(interp, "CFGetTypeID", tclCFGetTypeID, NULL, NULL);
	Tcl_CreateObjCommand(interp, "CFStringGetTypeID", tclCFGetTypeID2, (void*)CFStringGetTypeID(), NULL);
	Tcl_CreateObjCommand(interp, "CFNumberCreate", tclCFNumberCreate, NULL, NULL);
	Tcl_CreateObjCommand(interp, "CFNumberGetTypeID", tclCFGetTypeID2, (void*)CFNumberGetTypeID(), NULL);
	Tcl_CreateObjCommand(interp, "CFURLGetTypeID", tclCFGetTypeID2, (void*)CFURLGetTypeID(), NULL);
	Tcl_CreateObjCommand(interp, "CFBundleGetTypeID", tclCFGetTypeID2, (void*)CFBundleGetTypeID(), NULL);
	Tcl_CreateObjCommand(interp, "CFDictionaryGetTypeID", tclCFGetTypeID2, (void*)CFDictionaryGetTypeID(), NULL);
	Tcl_CreateObjCommand(interp, "CFArrayGetTypeID", tclCFGetTypeID2, (void*)CFArrayGetTypeID(), NULL);
	//Tcl_CreateObjCommand(interp, "CFBundleCreateBundlesFromDirectory", tclCFBundleCreateBundlesFromDirectory, NULL, NULL);

	if(Tcl_PkgProvide(interp, "CFLib", "1.0") != TCL_OK)
		return TCL_ERROR;
	return TCL_OK;
}
