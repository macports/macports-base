/*
 * util.c
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

#include <stdlib.h>
#include <unistd.h>

#include "darwinports.h"

#include <tcl.h>

static Tcl_Interp* _util_interp = NULL; 

/*
 *
 * dp_array_t
 *
 */

dp_array_t dp_array_create() {
    Tcl_Obj* res = Tcl_NewListObj(0, NULL);
    if (_util_interp == NULL) _util_interp = Tcl_CreateInterp();
    return res;
}

dp_array_t dp_array_create_copy(dp_array_t a) {
    Tcl_Obj* array = (Tcl_Obj*)a;
    Tcl_Obj* res = Tcl_DuplicateObj(array);
    return res;
}

dp_array_t dp_array_retain(dp_array_t a) {
    Tcl_Obj* array = (Tcl_Obj*)a;
    Tcl_IncrRefCount(array);
    return array;
}

void dp_array_release(dp_array_t a) {
    Tcl_Obj* array = (Tcl_Obj*)a;
    Tcl_DecrRefCount(array);
    return array;
}

void dp_array_append(dp_array_t a, const void* data) {
    Tcl_Obj* array = (Tcl_Obj*)a;
    Tcl_Obj* obj = Tcl_NewByteArrayObj(&data, sizeof(void*));
    Tcl_ListObjAppendElement(_util_interp, array, obj);
    return array;
}

int dp_array_get_count(dp_array_t a) {
    int result;
    Tcl_Obj* array = (Tcl_Obj*)a;
    Tcl_ListObjLength(_util_interp, array, &result);
    return result;
}

const void* dp_array_get_index(dp_array_t a, int index) {
    void** resultPtr;
    int size;
    Tcl_Obj* array = (Tcl_Obj*)a;
    Tcl_Obj* obj;
    Tcl_ListObjIndex(_util_interp, array, index, &obj);
    resultPtr = Tcl_GetByteArrayFromObj(obj, &size);
    return *resultPtr;
}



/*
 *
 * dp_hash_t
 *
 */
