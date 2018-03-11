/*
 * util.h
 * vim:tw=80:expandtab
 *
 * Copyright (c) 2011 Clemens Lang <cal@macports.org>
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
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#ifndef _CUTIL_H
#define _CUTIL_H

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include "registry.h"

typedef enum {
    reg_strategy_exact = 1,
    reg_strategy_glob = 2,
    reg_strategy_regexp = 3,
    reg_strategy_null = 4
} reg_strategy;

int reg_strcat(char** dst, size_t* dst_len, size_t* dst_space, char* src);
int reg_listcat(void*** dst, int* dst_len, int* dst_space, void* src);
int reg_all_objects(reg_registry* reg, char* query, int query_len,
        void*** objects, cast_function* fn, void* castcalldata,
        free_function* del, reg_error* errPtr);
char* reg_strategy_op(reg_strategy strategy, reg_error* errPtr);

#endif /* _CUTIL_H */

