/*
 * strcasecmp.h
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

#include <string.h>

#if !HAVE_STRCASECMP
	#define strcasecmp xstrcasecmp
#endif

#if !HAVE_STRNCASECMP
	#define strncasecmp xstrncasecmp
#endif

/**
 * Compare two strings case insensitively.
 * This function has the same semantics as ANSI strcmp.
 *
 * @param inLeftString		first null terminated string to compare
 * @param inRightString		second null terminated string to compare
 * @return an integer greater than, equal to or less than 0 to mean that
 * inLeftString is greater, equal or less than inRightString.
 */
int xstrcasecmp(const char* inLeftString, const char* inRightString);

/**
 * Compare two strings case insensitively and at most n characters.
 * This function has the same semantics as ANSI strncmp.
 *
 * @param inLeftString		first string to compare
 * @param inRightString		second string to compare
 * @param inMaxChars		maximum number of characters to compare
 * @return an integer greater than, equal to or less than 0 to mean that
 * inLeftString is greater, equal or less than inRightString.
 */
int xstrncasecmp(const char* inLeftString, const char* inRightString, size_t inMaxChars);
