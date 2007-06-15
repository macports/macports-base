/*
 * util.c
 * $Id$
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

#include "macports.h"
#include "util.h"

#include <tcl.h>

static Tcl_Interp* _util_interp = NULL; 

/*
 *
 * mp_array_t
 *
 */

mp_array_t mp_array_create() {
    Tcl_Obj* res = Tcl_NewListObj(0, NULL);
    if (_util_interp == NULL) _util_interp = Tcl_CreateInterp();
    return res;
}

mp_array_t mp_array_create_copy(mp_array_t a) {
    Tcl_Obj* array = (Tcl_Obj*)a;
    Tcl_Obj* res = Tcl_DuplicateObj(array);
    return res;
}

mp_array_t mp_array_retain(mp_array_t a) {
    Tcl_Obj* array = (Tcl_Obj*)a;
    Tcl_IncrRefCount(array);
    return (mp_array_t)array;
}

void mp_array_release(mp_array_t a) {
    Tcl_Obj* array = (Tcl_Obj*)a;
    Tcl_DecrRefCount(array);
}

void mp_array_append(mp_array_t a, const void* data) {
    Tcl_Obj* array = (Tcl_Obj*)a;
    Tcl_Obj* obj = Tcl_NewByteArrayObj((unsigned char*)&data, sizeof(void*));
    Tcl_ListObjAppendElement(_util_interp, array, obj);
}

int mp_array_get_count(mp_array_t a) {
    int result;
    Tcl_Obj* array = (Tcl_Obj*)a;
    Tcl_ListObjLength(_util_interp, array, &result);
    return result;
}

const void* mp_array_get_index(mp_array_t a, int index) {
    void** resultPtr;
    int size;
    Tcl_Obj* array = (Tcl_Obj*)a;
    Tcl_Obj* obj;
    Tcl_ListObjIndex(_util_interp, array, index, &obj);
    resultPtr = (void**)Tcl_GetByteArrayFromObj(obj, &size);
    return *resultPtr;
}



/*
 *
 * mp_hash_t
 *
 */
struct hashtable {
    Tcl_HashTable table;
    int refcount;
};

mp_hash_t mp_hash_create() {
    struct hashtable* hash = malloc(sizeof(struct hashtable));
    Tcl_InitHashTable(&hash->table, TCL_STRING_KEYS);
    hash->refcount = 1;
    return (mp_hash_t)hash;
}

mp_hash_t mp_hash_retain(mp_hash_t h) {
    struct hashtable* hash = (struct hashtable*)h;
    ++hash->refcount;
    return h;
}

void mp_hash_release(mp_hash_t h) {
    struct hashtable* hash = (struct hashtable*)h;
    --hash->refcount;
    if (hash->refcount == 0) {
        Tcl_DeleteHashTable(&hash->table);
        free(hash);
    }
}

void mp_hash_set_value(mp_hash_t h, const void* key, const void* data) {
    struct hashtable* hash = (struct hashtable*)h;
    int created;
    Tcl_HashEntry* entry = Tcl_CreateHashEntry(&hash->table, key, &created);
    Tcl_SetHashValue(entry, (ClientData)data);
}

const void* mp_hash_get_value(mp_hash_t h, const void* key) {
    struct hashtable* hash = (struct hashtable*)h;
    Tcl_HashEntry* entry = Tcl_FindHashEntry(&hash->table, key);
    if (entry != NULL) {
        return (const void*)Tcl_GetHashValue(entry);
    } else {
        return NULL;
    }
}
