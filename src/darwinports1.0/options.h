/*
 * options.h
 *
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
 * 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
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

#ifndef __OPTION_H__
#define __OPTION_H__

#include <sys/types.h>
#include "util.h"

/*
 * dp_options_t
 *
 * The dp_options_t type manages a collection of various options.
 * Each option has a type, either a string scalar, or an array
 * of strings.  Options may also have a default value.
 *
 * Each dp_options_t should be thought of as a single namespace
 * for options.
 *
 * All option names and option values should be UTF-8 strings.
 *
 */

typedef struct {
    u_int32_t type;
    u_int32_t size;
    union { 
        void*     ptr;
        char*     string;
        u_int64_t integer;
    } data;
} dp_desc_t;

void dp_desc_free(dp_desc_t d);
    // uses free(3) on "array", "string", and "any" types
    // also performs dp_desc_free() on elements of arrays
void dp_desc_copy(dp_desc_t* dst, dp_desc_t* src);
    // allocates any needed space with malloc(3)


/* types */
enum {
    DP_TYPE_NULL = 0x0000,
    DP_TYPE_DATA = 0x0001,	// binary data
    DP_TYPE_UTF_8 = 0x0002,	// UTF-8 string
    DP_TYPE_INT_64 = 0x0003,	// 64-bit integer
    
    DP_TYPE_ARRAY = 0x0100	// array of descriptors
};

/* option flags */
enum {
    DP_OPTIONS_FLAG_IMMUTABLE = 0x10000
};

typedef void* dp_options_t;


/* result codes */
enum {
    DP_OPTIONS_SUCCESS = 0,

    DP_OPTIONS_ERROR_UNDEFINED = -1,
        // the specified option has not been declared

    DP_OPTIONS_ERROR_WRONG_TYPE = -10,
        // array operation requested on a string type
        // type differs from previous declaration
    
    DP_OPTIONS_ERROR_WRONG_DEFAULT = -11,
        // default differs from previous declaration

    DP_OPTIONS_ERROR_IMMUTABLE = -12,
        // could not set the value, the option is immutable
        
    DP_OPTIONS_ERROR_LAST
};

dp_options_t dp_options_create();
dp_options_t dp_options_retain(dp_options_t);
void dp_options_release(dp_options_t);

int dp_options_declare(dp_options_t o, char* name, int flags, dp_desc_t* default_value);
    // will copy default_value internally

int dp_options_set_value(dp_options_t o, char* name, dp_desc_t* new_value);
    // will copy new_value internally

int dp_options_get_value(dp_options_t o, char* name, dp_desc_t* out_value);
    // free out_value with dp_desc_free();

int dp_options_set_ex_attr(dp_options_t o, char* name, char* key, dp_desc_t* new_value);
    // will copy new_value internally

int dp_options_get_ex_attr(dp_options_t o, char* name, char* key, dp_desc_t* out_value);
    // free out_value with dp_desc_free();

#endif /* __OPTION_H__ */