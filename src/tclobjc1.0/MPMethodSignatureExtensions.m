/*
 * MPMethodSignatureExtension.m
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

#include "MPMethodSignatureExtensions.h"

#include <tcl.h>

#include "objc_encoding.h"

#ifdef GNU_RUNTIME

unsigned int tclobjc_getarg_typespecifier (NSMethodSignature* signature, unsigned int index) {
    	NSArgumentInfo info;
    	info = [signature argumentInfoAtIndex: index];
    	return info.qual;    
}

const char *tclobjc_getarg_typestring (NSMethodSignature* signature, unsigned int index) {
    return [signature getArgumentTypeAtIndex: index];
}

const char *tclobjc_getreturn_typestring (NSMethodSignature* signature) {
    return [signature methodReturnType];
}

#elif defined(APPLE_RUNTIME)

/**
 * Skips any initial argument type specifiers, and returns a pointer
 * to the argument type.
 */
static const char *strip_specifiers (const char *type) {
	const char *p;
	for (p = type; p != '\0'; p++) {
		switch (*p) {
			case _C_BYCOPY:
			case _C_IN:
			case _C_OUT:
			case _C_INOUT:
			case _C_CONST:
			case _C_ONEWAY:
				break;
			default:
				return(p);
		}
	}
	return (NULL);
}

/**
 * Returns the argument's type specifier (in GNU Objective-C style).
 */
unsigned int tclobjc_getarg_typespecifier (NSMethodSignature* signature, unsigned int index) {
    	const char *type;
    	unsigned int qual = 0;
    	type = [signature getArgumentTypeAtIndex: index];
    	for (; type != '\0'; type++) {
    		switch (type[0]) {
    			case _C_BYCOPY:
    				qual |= _F_BYCOPY;
    				break;
    			case _C_IN:
    				qual |= _F_IN;
    				break;
    			case _C_OUT:
    				qual |= _F_OUT;
    				break;
    			case _C_INOUT:
    				qual |= _F_INOUT;
    				break;
    			case _C_CONST:
    				qual |= _F_CONST;
    				break;
    			case _C_ONEWAY:
    				qual |= _F_ONEWAY;
    				break;
    			default:
    				goto finish;
    		}
    	}
finish:
    	return (qual);
}

/**
 * Returns apointer to the argument's type string.
 */
const char *tclobjc_getarg_typestring (NSMethodSignature* signature, unsigned int index) {
    const char *type;

    /* Fetch the argument type, and strip the type specifiers. */
	type = strip_specifiers([signature getArgumentTypeAtIndex: index]);
	if (type == NULL) {
		/* This is a fatal condition */
		NSLog(@"No type found in string at %s:%d", __FILE__, __LINE__);
        abort();
	}
	return (type);
}

const char *tclobjc_getreturn_typestring (NSMethodSignature* signature) {
    const char *type;
	type = strip_specifiers([signature methodReturnType]);
	if (type == NULL) {
		/* This is a fatal condition */
		NSLog(@"No type found in string at %s:%d", __FILE__, __LINE__);
		abort();
	}
	return (type);
}

#endif
