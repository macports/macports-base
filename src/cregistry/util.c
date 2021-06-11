/*
 * util.c
 * vim:tw=80:expandtab
 *
 * Copyright (c) 2007 Chris Pickel <sfiera@macports.org>
 * Copyright (c) 2012 The MacPorts Project
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

#include "util.h"

#include <stdlib.h>
#include <string.h>

/**
 * Concatenates `src` to string `dst`. Simple concatenation. Only guaranteed to
 * work with strings that have been allocated with `malloc`. Amortizes cost of
 * expanding string buffer for O(N) concatenation and such. Uses `memcpy` in
 * favor of `strcpy` in hopes it will perform a bit better.
 *
 * @param [in,out] dst       a reference to a null-terminated string
 * @param [in,out] dst_len   number of characters currently in `dst`
 * @param [in,out] dst_space number of characters `dst` can hold
 * @param [in] src           string to concatenate to `dst`
 */
int reg_strcat(char** dst, size_t* dst_len, size_t* dst_space, char* src) {
    size_t src_len = strlen(src);
    size_t result_len = *dst_len + src_len;
    if (result_len > *dst_space) {
        char* new_dst;
        *dst_space *= 2;
        if (*dst_space < result_len) {
            *dst_space = result_len;
        }
        new_dst = realloc(*dst, *dst_space * sizeof(char) + 1);
        if (!new_dst)
            return 0;
        else
            *dst = new_dst;
    }
    memcpy(*dst + *dst_len, src, src_len+1);
    *dst_len = result_len;
    return 1;
}

/**
 * Appends element `src` to the list `dst`. It's like `reg_strcat`, except `src`
 * represents a single element and not a sequence of `char`s.
 *
 * @param [in,out] dst       a reference to a list of pointers
 * @param [in,out] dst_len   number of elements currently in `dst`
 * @param [in,out] dst_space number of elements `dst` can hold
 * @param [in] src           elements to append to `dst`
 */
int reg_listcat(void*** dst, int* dst_len, int* dst_space, void* src) {
    if (*dst_len == *dst_space) {
        void** new_dst;
        *dst_space *= 2;
        new_dst = realloc(*dst, *dst_space * sizeof(void*));
        if (!new_dst)
            return 0;
        else
            *dst = new_dst;
    }
    (*dst)[*dst_len] = src;
    (*dst_len)++;
    return 1;
}

/**
 * Returns an expression to use for the given strategy. This should be passed as
 * the `fmt` argument of `sqlite3_mprintf`, with the key and value following.
 *
 * @param [in] strategy a strategy (one of the `reg_strategy_*` constants)
 * @param [out] errPtr  on error, a description of the error that occurred
 * @return              a sqlite3 expression if success; NULL if failure
 */
char* reg_strategy_op(reg_strategy strategy, reg_error* errPtr) {
    switch (strategy) {
        case reg_strategy_exact:
            return "%q = '%q'";
        case reg_strategy_glob:
            return "%q GLOB '%q'";
        case reg_strategy_regexp:
            return "REGEXP(%q, '%q')";
        case reg_strategy_null:
            return "%q IS NULL";
        default:
            errPtr->code = REG_INVALID;
            errPtr->description = "invalid matching strategy specified";
            errPtr->free = NULL;
            return NULL;
    }
}

/**
 * Convenience method for returning all objects of a given type from the
 * registry.
 *
 * @param [in] reg       registry to select objects from
 * @param [in] query     the select query to execute
 * @param [in] query_len length of the query (or -1 for automatic)
 * @param [out] objects  the objects selected
 * @param [in] fn        a function to convert sqlite3_stmts to the desired type
 * @param [in,out] castcalldata data passed along to the cast function
 * @param [in] del       a function to delete the desired type of object
 * @param [out] errPtr   on error, a description of the error that occurred
 * @return               the number of objects if success; negative if failure
 */
int reg_all_objects(reg_registry* reg, char* query, int query_len,
        void*** objects, cast_function* fn, void* castcalldata,
        free_function* del, reg_error* errPtr) {
    void** results = malloc(10*sizeof(void*));
    int result_count = 0;
    int result_space = 10;
    sqlite3_stmt* stmt = NULL;
    if (!results) {
        return -1;
    }
    if (!fn) {
        free(results);
        return -1;
    }
    if (sqlite3_prepare_v2(reg->db, query, query_len, &stmt, NULL) == SQLITE_OK) {
        int r;
        void* row;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:
                    if (fn(reg, &row, stmt, castcalldata, errPtr)) {
                        if (!reg_listcat(&results, &result_count, &result_space, row)) {
                            r = SQLITE_ERROR;
                        }
                    } else {
                        r = SQLITE_ERROR;
                    }
                    break;
                case SQLITE_DONE:
                    break;
                case SQLITE_BUSY:
                    continue;
                default:
                    reg_sqlite_error(reg->db, errPtr, query);
                    break;
            }
        } while (r == SQLITE_ROW || r == SQLITE_BUSY);
        sqlite3_finalize(stmt);
        if (r == SQLITE_DONE) {
            *objects = results;
            return result_count;
        } else if (del) {
            int i;
            for (i=0; i<result_count; i++) {
                del(NULL, results[i]);
            }
        }
    } else {
        if (stmt) {
            sqlite3_finalize(stmt);
        }
        reg_sqlite_error(reg->db, errPtr, query);
    }
    free(results);
    return -1;
}

