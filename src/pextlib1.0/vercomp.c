/*
 * vercomp.c
 * version comparison
 *
 * Author: Landon Fuller <landonf@macports.org>
 *
 * Copyright (c) 2002 - 2003 Apple Inc.
 * Copyright (c) 2004 Landon Fuller <landonf@macports.org>
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
 * 3. Neither the name of Apple Inc. nor the names of its
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

#include <ctype.h>
#include <string.h>

#include <tcl.h>

#include "vercomp.h"

/*
 * If A is newer than B, return an integer > 0
 * If A and B are equal, return 0
 * If B is newer than A, return an integer < 0
 */

static int vercmp (const char *versionA, const char *versionB) {
	const char *ptrA, *ptrB;
	const char *eptrA, *eptrB;

	/* if versions equal, return zero */
	if(!strcmp(versionA, versionB))
		return 0;

	ptrA = versionA;
	ptrB = versionB;
	while (*ptrA != '\0' && *ptrB != '\0') {
		/* skip all non-alphanumeric characters */
		while (*ptrA != '\0' && !isalnum(*ptrA))
			ptrA++;
		while (*ptrB != '\0' && !isalnum(*ptrB))
			ptrB++;

		eptrA = ptrA;
		eptrB = ptrB;

		/* Somewhat arbitrary rules as per RPM's implementation.
		 * This code could be more clever, but we're aiming
		 * for clarity instead. */

		/* If versionB's segment is not a digit segment, but
		 * versionA's segment IS a digit segment, return 1.
		 * (Added for redhat compatibility. See redhat bugzilla
		 * #50977 for details) */
		if (!isdigit(*ptrB)) {
			if (isdigit(*ptrA))
				return 1;
		}

		/* Otherwise, if the segments are of different types,
		 * return -1 */

		if ((isdigit(*ptrA) && isalpha(*ptrB)) || (isalpha(*ptrA) && isdigit(*ptrB)))
			return -1;

		/* Find the first segment composed of entirely alphabetical
		 * or numeric members */
		if (isalpha(*ptrA)) {
			while (*eptrA != '\0' && isalpha(*eptrA))
				eptrA++;

			while (*eptrB != '\0' && isalpha(*eptrB))
				eptrB++;
		} else {
			int countA = 0, countB = 0;
			while (*eptrA != '\0' && isdigit(*eptrA)) {
				countA++;
				eptrA++;
			}
			while (*eptrB != '\0' && isdigit(*eptrB)) {
				countB++;
				eptrB++;
			}

			/* skip leading '0' characters */
			while (ptrA != eptrA && *ptrA == '0') {
				ptrA++;
				countA--;
			}
			while (ptrB != eptrB && *ptrB == '0') {
				ptrB++;
				countB--;
			}

			/* If A is longer than B, return 1 */
			if (countA > countB)
				return 1;

			/* If B is longer than A, return -1 */
			if (countB > countA)
				return -1;
		}
		/* Compare strings lexicographically */
		while (ptrA != eptrA && ptrB != eptrB && *ptrA == *ptrB) {
				ptrA++;
				ptrB++;
		}
		if (ptrA != eptrA && ptrB != eptrB)
			return *ptrA - *ptrB;

		ptrA = eptrA;
		ptrB = eptrB;
	}

	/* If both pointers are null, all alphanumeric
	 * characters were identical and only seperating
	 * characters differed. According to RPM, these
	 * version strings are equal */
	if (*ptrA == '\0' && *ptrB == '\0')
		return 0;

	/* If A has unchecked characters, return 1
	 * Otherwise, if B has remaining unchecked characters,
	 * return -1 */
	if (*ptrA != '\0')
		return 1;
	else
		return -1;
}

int VercompCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Obj *tcl_result;
	const char *versionA, *versionB;
	int rval;

	if (objc != 3) {
		Tcl_WrongNumArgs(interp, 1, objv, "versionA versionB");
		return TCL_ERROR;
	}

	versionA = Tcl_GetString(objv[1]);
	versionB = Tcl_GetString(objv[2]);

	rval = vercmp(versionA, versionB);

	tcl_result = Tcl_NewIntObj(rval);
	Tcl_SetObjResult(interp, tcl_result);

	return TCL_OK;
}
