/*
 * MacSWReceipt.c
 * OS X Installer.app Package Receipt Management
 *
 * Authors: Landon J. Fuller <landonf@opendarwin.org>
 *          Kevin Van Vechten <kevin@opendarwin.org>
 *
 * Copyright (c) 2005 Landon Fuller <landonf@opendarwin.org>
 * Copyright (c) 2003 Kevin Van Vechten <kevin@opendarwin.org>
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
 * 3. Neither the name of Apple Computer, Inc. nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
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

#include <stdlib.h>
#include <ctype.h>
#include <tcl.h>

#if HAVE_STRING_H
#include <string.h>
#endif

#if HAVE_STRINGS_H
#include <strings.h>
#endif

#ifdef CFOUNDATION_ENABLE
#include <CoreFoundation/CoreFoundation.h>

static int convert_cfstring(CFStringRef str, char **dest, int *length) {
	CFIndex stringLen;
	size_t tclStringLen;
	char *tclString;

	stringLen = CFStringGetLength(str);
	tclStringLen = CFStringGetMaximumSizeForEncoding(stringLen, kCFStringEncodingUTF8);
	tclStringLen++; /* Length + \0 */
	tclString = malloc(tclStringLen);

	if (!tclString)
		return (TCL_ERROR);

	if (CFStringGetCString(str, tclString, tclStringLen, kCFStringEncodingUTF8) != true) {
		free(tclString);
		return (TCL_ERROR);
	}

	/*
	 * CFStringGetMaximumSizeForEncoding doesn't return the actual
	 * size of the string. Compute that now.
	 */
	 tclStringLen = strlen(tclString) + 1; /* Length + \0 */
	 tclString = realloc(tclString, tclStringLen);
	 if (!tclString)
		 return (TCL_ERROR);

	*length = tclStringLen;
	*dest = tclString;

	return (TCL_OK);
}

int MacSWReceiptCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
	const char namespace_eval[] = "namespace eval dports::uglytcl { }";
	const char portinfo[] = "dports::uglytcl::portinfo";
	const char array_get[] = "array get ";
	CFArrayRef bundles;
	Tcl_Obj *pkgList;
	Tcl_Obj *tcl_result;
	CFURLRef url;

	if (objc != 1) {
		Tcl_WrongNumArgs(interp, 1, objv, NULL);
		return TCL_ERROR;
	}

	url = CFURLCreateWithFileSystemPath(NULL, CFSTR("/Library/Receipts"), kCFURLPOSIXPathStyle, 1);
	bundles = CFBundleCreateBundlesFromDirectory(NULL, url, CFSTR("pkg"));
	pkgList = Tcl_NewListObj(0, NULL);
	
	if (bundles) {
		CFIndex i, count = CFArrayGetCount(bundles);

		Tcl_EvalEx(interp, namespace_eval, sizeof(namespace_eval) - 1, 0);

		for (i = 0; i < count; ++i) {
			CFBundleRef receipt;
			CFURLRef resources;
			CFStringRef str;
			Tcl_Obj *pkgArray;
			Tcl_Obj *tclString;
			int cStringLen;
			char *cString;

			receipt  = (CFBundleRef)CFArrayGetValueAtIndex(bundles, i);
			str = CFBundleGetValueForInfoDictionaryKey(receipt, CFSTR("CFBundleIdentifier"));

			str = CFBundleGetValueForInfoDictionaryKey(receipt, CFSTR("CFBundleName"));
			if (str) {
				if (convert_cfstring(str, &cString, &cStringLen) != TCL_OK)
					return (TCL_ERROR);

				tclString = Tcl_NewStringObj(cString, cStringLen - 1); /* cStringLen - \0 */
				free(cString);
				Tcl_SetVar2Ex(interp, portinfo, "name", tclString, 0);
			} else {
				continue; /* Name is absolutely required */
			}

			str = CFBundleGetValueForInfoDictionaryKey(receipt, CFSTR("CFBundleShortVersionString"));
			if (str) {
				if (convert_cfstring(str, &cString, &cStringLen) != TCL_OK)
					return (TCL_ERROR);

				tclString = Tcl_NewStringObj(cString, cStringLen - 1); /* cStringLen - \0 */
				free(cString);
				Tcl_SetVar2Ex(interp, portinfo, "version", tclString, 0);
			}

			str = CFBundleGetValueForInfoDictionaryKey(receipt, CFSTR("IFPkgReceiptLocation"));
			if (str) {
				if (convert_cfstring(str, &cString, &cStringLen) != TCL_OK)
					return (TCL_ERROR);

				tclString = Tcl_NewStringObj(cString, cStringLen - 1); /* cStringLen - \0 */
				free(cString);
				Tcl_SetVar2Ex(interp, portinfo, "prefix", tclString, 0);
			}

			url = CFBundleCopyBundleURL(receipt);
			if (url) {
				str = CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
				CFRelease(url);
				if (str) {
					if (convert_cfstring(str, &cString, &cStringLen) != TCL_OK)
						return (TCL_ERROR);

					CFRelease(str);
					tclString = Tcl_NewStringObj(cString, cStringLen - 1); /* cStringLen - \0 */
					free(cString);
					Tcl_SetVar2Ex(interp, portinfo, "receiptpath", tclString, 0);
				}
			}


			resources = CFBundleCopyResourcesDirectoryURL(receipt);
			if (resources) {
				CFURLRef description = CFURLCreateWithString(NULL, CFSTR("Description.plist"), resources);

				if (description) {
					CFReadStreamRef stream = CFReadStreamCreateWithFile(NULL, description);

					if (stream) {
						CFStringRef errorString = NULL;
						CFDictionaryRef d;
						d = CFPropertyListCreateFromStream(NULL, stream, 0, kCFPropertyListImmutable, NULL, &errorString);
						CFReadStreamOpen(stream);

						if (d) {
							str = CFDictionaryGetValue(d, CFSTR("IFPkgDescriptionDescription"));
							if (str) {
								if (convert_cfstring(str, &cString, &cStringLen) != TCL_OK)
									return (TCL_ERROR);

								tclString = Tcl_NewStringObj(cString, cStringLen - 1); /* cStringLen - \0 */
								free(cString);
								Tcl_SetVar2Ex(interp, portinfo, "description", tclString, 0);
							}
						}
						CFReadStreamClose(stream);
						CFRelease(stream);
					}
					CFRelease(description);
				}
				CFRelease(resources);
			}
			/* Oi, this is ugly. Tcl array manipulation is awful! */
			cStringLen = sizeof(portinfo) + sizeof(array_get) - 1; /* portinfo + array_get - extra \0 */
			cString = malloc(cStringLen);
			if (!cString)
				return (TCL_ERROR);

			strcpy(cString, array_get);
			strcat(cString, portinfo);

			Tcl_EvalEx(interp, cString, cStringLen - 1, 0);
			free(cString);
			pkgArray = Tcl_GetObjResult(interp);
			Tcl_ListObjAppendElement(interp, pkgList, pkgArray);
			Tcl_UnsetVar(interp, portinfo, 0);
		}
	}

	CFRelease(bundles);

	tcl_result = pkgList;
	Tcl_SetObjResult(interp, pkgList);
	return (TCL_OK);
}

#endif /* CFOUNDATION_ENABLED */
