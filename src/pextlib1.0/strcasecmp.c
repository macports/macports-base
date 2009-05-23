/*
 * strcasecmp.c
 * $Id$
 *
 * Copyright (c) 2004 Paul Guyot, The MacPorts Project.
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
 * 3. Neither the name of MacPorts Team nor the names of its contributors
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

#include <ctype.h>
#include <string.h>

#include "strcasecmp.h"

/* ------------------------------------------------------------------------- **
 * xstrcasecmp
 * ------------------------------------------------------------------------- */
int
xstrcasecmp(const char* inLeftString, const char* inRightString)
{
	/* the result */
	int result = 0;
	/* our two characters */
	int leftChar, rightChar;
	do {
		/* we use tolower(3) to do the case insensitive comparison */
		leftChar = tolower(*inLeftString++);
		rightChar = tolower(*inRightString++);

		/* this corresponds to strcmp(3) semantics */
		result = leftChar - rightChar;
		
		/* either leftChar is 0 (to mean it's the end of the left string)
			or result is not 0 (to mean that strings differ).
			if it's the end of the right string but not the end of the
			left string, then result won't be 0 */
	} while ((leftChar != 0) && (result == 0));
	
	return result;
}

/* ------------------------------------------------------------------------- **
 * xstrncasecmp
 * ------------------------------------------------------------------------- */
int
xstrncasecmp(const char* inLeftString, const char* inRightString, size_t inMaxChars)
{
	/* xstrncasecmp is just the same with an additional decrement of the
		maximum charcters */

	/* the result */
	int result = 0;
	/* our two characters */
	int leftChar, rightChar;
	do {
		/* we use tolower(3) to do the case insensitive comparison */
		leftChar = tolower(*inLeftString++);
		rightChar = tolower(*inRightString++);

		/* this corresponds to strcmp(3) semantics */
		result = leftChar - rightChar;
		
		/* either:
			- we tested inMaxChars and we must stop here
			- or leftChar is 0 (to mean it's the end of the left string)
			- or result is not 0 (to mean that strings differ).
			if it's the end of the right string but not the end of the
			left string, then result won't be 0 */
	} while ((--inMaxChars != 0) && (leftChar != 0) && (result == 0));
	
	return result;
}
