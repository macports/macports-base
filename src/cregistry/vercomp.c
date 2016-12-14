/*
 * vercomp.c
 *
 * Copyright (c) 2010 The MacPorts Project
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

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include "vercomp.h"

#include <string.h>
#include <ctype.h>

/*
 * TODO: share this function between pextlib and cregistry. The version here is
 *       slightly modified so as to take explicit string lengths. Since these
 *       are available in Tcl it's an easy change and might be a tiny bit
 *       faster; it's necessary for the application here.
 */

/**
 * EVR version comparison. Shamelessly copied from Pextlib, with some changes to
 * use string lengths instead of strlen by default. That's necessary to make it
 * work with sqlite3 collations. It should be shared with Pextlib, rather than
 * just copied though.
 *
 * @param [in] versionA first version string, i.e. "1.4.1"
 * @param [in] lengthA  length of first version string, or -1 to use strlen
 * @param [in] versionB second version string, i.e. "1.4.2"
 * @param [in] lengthB  length of second version string, or -1 to use strlen
 * @return              -1 if A < B; 0 if A = B; 1 if A > B
 */
static int vercmp (const char *versionA, int lengthA, const char *versionB,
        int lengthB) {
    const char *endA, *endB;
	const char *ptrA, *ptrB;
	const char *eptrA, *eptrB;

    if (lengthA < 0)
        lengthA = (int)strlen(versionA);
    if (lengthB < 0)
        lengthB = (int)strlen(versionB);

	/* if versions equal, return zero */
	if(lengthA == lengthB && !strncmp(versionA, versionB, (size_t)lengthA))
		return 0;

	ptrA = versionA;
	ptrB = versionB;
    endA = versionA + lengthA;
    endB = versionB + lengthB;
	while (ptrA != endA && ptrB != endB) {
		/* skip all non-alphanumeric characters */
		while (ptrA != endB && !isalnum(*ptrA))
			ptrA++;
		while (ptrB != endB && !isalnum(*ptrB))
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
			while (eptrA != endA && isalpha(*eptrA))
				eptrA++;

			while (eptrB != endB && isalpha(*eptrB))
				eptrB++;
		} else {
			int countA = 0, countB = 0;
			while (eptrA != endA && isdigit(*eptrA)) {
				countA++;
				eptrA++;
			}
			while (eptrB != endB && isdigit(*eptrB)) {
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
	if (ptrA == endA && ptrB == endB)
		return 0;

	/* If A has unchecked characters, return 1
	 * Otherwise, if B has remaining unchecked characters,
	 * return -1 */
	if (ptrA != endA)
		return 1;
	else
		return -1;
}

/**
 * VERSION collation for sqlite3. This function collates text according to
 * pextlib's vercmp function. This allows direct comparison and sorting of
 * version columns, such as port.version and port.revision.
 *
 * @param [in] userdata unused
 * @param [in] alen     length of first string
 * @param [in] a        first string
 * @param [in] blen     length of second string
 * @param [in] b        second string
 * @return              -1 if a < b; 0 if a = b; 1 if a > b
 */
int sql_version(void* userdata UNUSED, int alen, const void* a, int blen,
        const void* b) {
    return vercmp((const char*)a, alen, (const char*)b, blen);
}
