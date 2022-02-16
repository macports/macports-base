/*
 * distfile.c
 * vim:tw=80:expandtab
 *
 * Copyright (c) 2011 Clemens Lang <cal@macports.org>
 * Copyright (c) 2022 The MacPorts Project
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

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include "distfile.h"
#include "util.h"
#include "registry.h"
#include "sql.h"

#include <sqlite3.h>
#include <stdlib.h>
#include <string.h>

/**
 * Converts a `sqlite3_stmt` into a `reg_distfile`. The first column of the
 * stmt's row must be the ROWID of a distfile.
 *
 * @param [in] userdata    sqlite3 database
 * @param [out] distfile   distfile described by `stmt`
 * @param [in] stmt        `sqlite3_stmt` with appropriate columns
 * @param [out] errPtr     unused
 * @return                 true if success; false if failure
 */
static int reg_stmt_to_distfile(void* userdata, void** distfile, void* stmt,
        void* calldata UNUSED, reg_error* errPtr UNUSED) {
    int is_new;
    reg_registry* reg = (reg_registry*)userdata;
    Tcl_HashEntry* hash;

    sqlite_int64 id = sqlite3_column_int64(stmt, 0);
    hash = Tcl_CreateHashEntry(&reg->open_distfiles,
            (const char*)&id, &is_new);
    if (is_new) {
        reg_distfile* f = malloc(sizeof(reg_distfile));
        if (!f) {
            Tcl_DeleteHashEntry(hash);
            return 0;
        }
        f->reg = reg;
        f->id = id;
        f->proc = NULL;
        *distfile = f;
        Tcl_SetHashValue(hash, f);
    } else {
        *distfile = Tcl_GetHashValue(hash);
    }
    return 1;
}

/**
 * Opens an existing distfile in the registry.
 *
 * @param [in] reg      registry to open entry in
 * @param [in] id       port id in the database
 * @param [in] name     distfile path in the database
 * @param [out] errPtr  on error, a description of the error that occurs
 * @return              the distfile if success, NULL if failure
 */
reg_distfile* reg_distfile_open(reg_registry* reg, const char* id, const char* subdir, const char* path,
        reg_error* errPtr) {
    sqlite3_stmt* stmt = NULL;
    reg_distfile* distfile = NULL;
    char* query = "SELECT ROWID FROM registry.distfiles "
        "WHERE id=? AND subdir=? AND path=?";
    int lower_bound = 0;

    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 1, id, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 1, subdir, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 2, path, -1, SQLITE_STATIC)
                == SQLITE_OK)) {
        int r;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:
                    reg_stmt_to_distfile(reg, (void**)&distfile, stmt, &lower_bound,
                            errPtr);
                    break;
                case SQLITE_DONE:
                    errPtr->code = REG_NOT_FOUND;
                    errPtr->description = sqlite3_mprintf("no matching distfile found for: "
                            "id=%s, subdir=%s, path=%s", id, subdir, path);
                    errPtr->free = (reg_error_destructor*) sqlite3_free;
                    break;
                case SQLITE_BUSY:
                    continue;
                default:
                    reg_sqlite_error(reg->db, errPtr, query);
                    break;
            }
        } while (r == SQLITE_BUSY);
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
    }
    if (stmt) {
        sqlite3_finalize(stmt);
    }
    return distfile;
}

/**
 * Type-safe version of `reg_all_objects` for `reg_distfile`.
 *
 * @param [in] reg       registry to select entries from
 * @param [in] query     the select query to execute
 * @param [in] query_len length of the query (or -1 for automatic)
 * @param [out] objects  the distfiles selected
 * @param [out] errPtr   on error, a description of the error that occurred
 * @return               the number of entries if success; negative if failure
 */
static int reg_all_distfiles(reg_registry* reg, char* query, int query_len,
        reg_distfile*** objects, reg_error* errPtr) {
    int lower_bound = 0;
    return reg_all_objects(reg, query, query_len, (void***)objects,
            reg_stmt_to_distfile, &lower_bound, NULL, errPtr);
}

/**
 * Searches the registry for distfiles for which each key's value is equal to the
 * given value. To find all distfiles, pass a key_count of 0.
 *
 * Bad keys should cause sqlite3 errors but not permit SQL injection attacks.
 * Pass it good keys anyway.
 *
 * @param [in] reg          registry to search in
 * @param [in] keys         a list of keys to search by
 * @param [in] vals         a list of values to search by, matching keys
 * @param [in] strats       a list of strategies to use when searching
 * @param [in] key_count    the number of key/value pairs passed
 * @param [out] distfiles   a list of matching distfiles
 * @param [out] errPtr      on error, a description of the error that occurred
 * @return                  the number of entries if success; false if failure
 */
int reg_distfile_search(reg_registry* reg, char** keys, char** vals, int* strats,
        int key_count, reg_distfile*** distfiles, reg_error* errPtr) {
    int i;
    char* kwd = " WHERE ";
    char* query;
    size_t query_len, query_space;
    int result;

    /* build the query */
    query = strdup("SELECT ROWID FROM registry.distfiles");
    if (!query) {
        return -1;
    }
    query_len = query_space = strlen(query);

    for (i = 0; i < key_count; i++) {
        char* op;
        char* cond;

        /* get the strategy */
        if ((op = reg_strategy_op(strats[i], errPtr)) == NULL) {
            free(query);
            return -1;
        }

        cond = sqlite3_mprintf(op, keys[i], vals[i]);
        if (!cond || !reg_strcat(&query, &query_len, &query_space, kwd)
            || !reg_strcat(&query, &query_len, &query_space, cond)) {
            free(query);
            return -1;
        }
        sqlite3_free(cond);
        kwd = " AND ";
    }

    /* do the query */
    result = reg_all_distfiles(reg, query, -1, distfiles, errPtr);
    free(query);
    return result;
}

/**
 * Gets a named property of a distfile. That property can be set using
 * `reg_distfile_propset`. The property named must be one that exists in the table
 * and must not be one with internal meaning such as `id`.
 *
 * @param [in] distfile   distfile to get property from
 * @param [in] key        property to get
 * @param [out] value     the value of the property
 * @param [out] errPtr    on error, a description of the error that occurred
 * @return                true if success; false if failure
 */
int reg_distfile_propget(reg_distfile* distfile, char* key, char** value,
        reg_error* errPtr) {
    reg_registry* reg = distfile->reg;
    int result = 0;
    sqlite3_stmt* stmt = NULL;
    char* query;
    const char *text;
    query = sqlite3_mprintf(
            "SELECT %q FROM registry.distfiles WHERE ROWID=%lld", key,
            distfile->id);
    if (sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK) {
        int r;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:
                    text = (const char*)sqlite3_column_text(stmt, 0);
                    if (text) {
                        *value = strdup(text);
                        if (*value) {
                            result = 1;
                        } else {
                            errPtr->code = REG_OUT_OF_MEMORY;
                            errPtr->description = "cannot allocate memory";
                            errPtr->free = NULL;
                        }
                    } else {
                        reg_sqlite_error(reg->db, errPtr, query);
                    }
                    break;
                case SQLITE_DONE:
                    errPtr->code = REG_INVALID;
                    errPtr->description = "an invalid distfile was passed";
                    errPtr->free = NULL;
                    break;
                case SQLITE_BUSY:
                    continue;
                default:
                    reg_sqlite_error(reg->db, errPtr, query);
                    break;
            }
        } while (r == SQLITE_BUSY);
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
    }
    if (stmt) {
        sqlite3_finalize(stmt);
    }
    sqlite3_free(query);
    return result;
}

/**
 * Fetches a list of all open distfiles
 *
 * @param [in] reg          registry to fetch distfiles from
 * @param [out] distfiles   a list of open distfiles
 * @return                  the number of open entries, -1 on error
 */
int reg_all_open_distfiles(reg_registry* reg, reg_distfile*** distfiles) {
    reg_distfile* distfile;
    int distfile_count = 0;
    int distfile_space = 10;
    Tcl_HashEntry* hash;
    Tcl_HashSearch search;
    *distfiles = malloc(distfile_space * sizeof(reg_distfile*));
    if (!*distfiles) {
        return -1;
    }
    for (hash = Tcl_FirstHashEntry(&reg->open_distfiles, &search); hash != NULL;
            hash = Tcl_NextHashEntry(&search)) {
        distfile = Tcl_GetHashValue(hash);
        if (!reg_listcat((void***)distfiles, &distfile_count, &distfile_space, distfile)) {
            free(*distfiles);
            return -1;
        }
    }
    return distfile_count;
}

