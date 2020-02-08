/**
 * Copyright (c) 2019, Clemens Lang <cal@macports.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef __CTRIE_H__
#define __CTRIE_H__

#include <stdint.h>
#include "darwintrace_share/shm_alloc/shm_alloc.h"

typedef struct ctrie ctrie_t;

typedef enum {
	LOOKUP_NOTFOUND = 0,
	LOOKUP_FOUND = 1,
	LOOKUP_BUG = 0xff
} lookup_result_t;

typedef enum {
	INSERT_SUCCESS = 0,
	INSERT_OUT_OF_MEMORY = 1,
	INSERT_CAS_FAILED = 2,
	INSERT_BUG = 0xff
} insert_result_t;

typedef struct {
	uint32_t counter;
	uint32_t flags;
} value_t;

lookup_result_t ctrie_lookup(PTR(ctrie_t) ctrie, const char* key, value_t* value);
insert_result_t ctrie_insert(PTR(ctrie_t) ctrie, const char* key, const value_t* value);
void ctrie_print(PTR(ctrie_t) ctrie);
PTR(ctrie_t) ctrie_new();

#endif /* defined(__CTRIE_H__) */
