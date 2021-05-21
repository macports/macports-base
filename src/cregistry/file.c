/*
 * file.c
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

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include "file.h"
#include "util.h"
#include "registry.h"
#include "sql.h"

#include <sqlite3.h>
#include <stdlib.h>
#include <string.h>

/**
 * Converts a `sqlite3_stmt` into a `reg_file`. The first column of the stmt's
 * row must be the id of a file; the second column must be the path of a file;
 * the third either `SQLITE_NULL` or the address of the entry in memory.
 *
 * @param [in] userdata sqlite3 database
 * @param [out] file    file described by `stmt`
 * @param [in] stmt     `sqlite3_stmt` with appropriate columns
 * @param [out] errPtr  unused
 * @return              true if success; false if failure
 */
static int reg_stmt_to_file(void* userdata, void** file, void* stmt,
        void* calldata UNUSED, reg_error* errPtr UNUSED) {
    int is_new;
    reg_registry* reg = (reg_registry*)userdata;
    reg_file_pk key;
    Tcl_HashEntry* hash;
    char* hashkey;

    key.id = sqlite3_column_int64(stmt, 0);
    key.path = strdup((const char*) sqlite3_column_text(stmt, 1));
    if (!key.path) {
        return 0;
    }

    hashkey = sqlite3_mprintf("%lld:%s", key.id, key.path);
    if (!hashkey) {
        free(key.path);
        return 0;
    }
    hash = Tcl_CreateHashEntry(&reg->open_files,
            hashkey, &is_new);
    sqlite3_free(hashkey);

    if (is_new) {
        reg_file* f = malloc(sizeof(reg_file));
        if (!f) {
            free(key.path);
            return 0;
        }
        f->reg = reg;
        f->key = key;
        f->proc = NULL;
        *file = f;
        Tcl_SetHashValue(hash, f);
    } else {
        free(key.path);
        *file = Tcl_GetHashValue(hash);
    }
    return 1;
}

/**
 * Opens an existing file in the registry.
 *
 * @param [in] reg      registry to open entry in
 * @param [in] id       port id in the dabatase
 * @param [in] name     file path in the database
 * @param [out] errPtr  on error, a description of the error that occures
 * @return              the file if success, NULL if failure
 */
reg_file* reg_file_open(reg_registry* reg, char* id, char* name,
        reg_error* errPtr) {
    sqlite3_stmt* stmt = NULL;
    reg_file* file = NULL;
    char* query = "SELECT id, path FROM registry.files "
#if MP_SQLITE_VERSION >= 3006004
        /* if the version of SQLite supports it force the usage of the index on
         * path, rather than the one on id which has a lot less discriminative
         * power and leads to very slow queries. This is needed for the new
         * query planner introduced in 3.8.0 which would not use the correct
         * index automatically. */
        "INDEXED BY file_path "
#endif
        "WHERE id=? AND path=?";
    int lower_bound = 0;

    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 1, id, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 2, name, -1, SQLITE_STATIC)
                == SQLITE_OK)) {
        int r;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:
                    reg_stmt_to_file(reg, (void**)&file, stmt, &lower_bound,
                            errPtr);
                    break;
                case SQLITE_DONE:
                    errPtr->code = REG_NOT_FOUND;
                    errPtr->description = sqlite3_mprintf("no matching file found for: "
                            "id=%s, name=%s", id, name);
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
    return file;
}

/**
 * Type-safe version of `reg_all_objects` for `reg_file`.
 *
 * @param [in] reg       registry to select entries from
 * @param [in] query     the select query to execute
 * @param [in] query_len length of the query (or -1 for automatic)
 * @param [out] objects  the files selected
 * @param [out] errPtr   on error, a description of the error that occurred
 * @return               the number of entries if success; negative if failure
 */
static int reg_all_files(reg_registry* reg, char* query, int query_len,
        reg_file*** objects, reg_error* errPtr) {
    int lower_bound = 0;
    return reg_all_objects(reg, query, query_len, (void***)objects,
            reg_stmt_to_file, &lower_bound, NULL, errPtr);
}

/**
 * Searches the registry for files for which each key's value is equal to the
 * given value. To find all files, pass a key_count of 0.
 *
 * Bad keys should cause sqlite3 errors but not permit SQL injection attacks.
 * Pass it good keys anyway.
 *
 * @param [in] reg       registry to search in
 * @param [in] keys      a list of keys to search by
 * @param [in] vals      a list of values to search by, matching keys
 * @param [in] strats    a list of strategies to use when searching
 * @param [in] key_count the number of key/value pairs passed
 * @param [out] files    a list of matching files
 * @param [out] errPtr   on error, a description of the error that occurred
 * @return               the number of entries if success; false if failure
 */
int reg_file_search(reg_registry* reg, char** keys, char** vals, int* strats,
        int key_count, reg_file*** files, reg_error* errPtr) {
    int i;
    char* kwd = " WHERE ";
    char* query;
    size_t query_len, query_space;
    int result;

    /* build the query */
    query = strdup("SELECT id, path FROM registry.files");
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
    result = reg_all_files(reg, query, -1, files, errPtr);
    free(query);
    return result;
}

/**
 * Gets a named property of a file. That property can be set using
 * `reg_file_propset`. The property named must be one that exists in the table
 * and must not be one with internal meaning such as `id`.
 *
 * @param [in] file    file to get property from
 * @param [in] key     property to get
 * @param [out] value  the value of the property
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_file_propget(reg_file* file, char* key, char** value,
        reg_error* errPtr) {
    reg_registry* reg = file->reg;
    int result = 0;
    sqlite3_stmt* stmt = NULL;
    char* query;
    const char *text;
    query = sqlite3_mprintf(
            "SELECT %q FROM registry.files "
#if MP_SQLITE_VERSION >= 3006004
            /* if the version of SQLite supports it force the usage of the index
             * on path, rather than the one on id which has a lot less
             * discriminative power and leads to very slow queries. This is
             * needed for the new query planner introduced in 3.8.0 which would
             * not use the correct index automatically. */
            "INDEXED BY file_path "
#endif
            "WHERE id=%lld AND path='%q'", key, file->key.id, file->key.path);
    if (sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK) {
        int r;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:
                    text = (const char*)sqlite3_column_text(stmt, 0);
                    if (text) {
                        *value = strdup(text);
                        result = 1;
                    } else {
                        reg_sqlite_error(reg->db, errPtr, query);
                    }
                    break;
                case SQLITE_DONE:
                    errPtr->code = REG_INVALID;
                    errPtr->description = "an invalid file was passed";
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
 * Sets a named property of a file. That property can be later retrieved using
 * `reg_file_propget`. The property named must be one that exists in the table
 * and must not be one with internal meaning such as `id`.
 *
 * @param [in] file    file to set property for
 * @param [in] key     property to set
 * @param [in] value   the desired value of the property
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_file_propset(reg_file* file, char* key, char* value,
        reg_error* errPtr) {
    reg_registry* reg = file->reg;
    int result = 0;
    sqlite3_stmt* stmt = NULL;
    char* query;
    query = sqlite3_mprintf(
            "UPDATE registry.files "
#if MP_SQLITE_VERSION >= 3006004
            /* if the version of SQLite supports it force the usage of the index
             * on path, rather than the one on id which has a lot less
             * discriminative power and leads to very slow queries. This is
             * needed for the new query planner introduced in 3.8.0 which would
             * not use the correct index automatically. */
            "INDEXED BY file_path "
#endif
            "SET %q = '%q' WHERE id=%lld AND path='%q'", key, value, file->key.id, file->key.path);
    if (sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK) {
        int r;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_DONE:
                    result = 1;
                    break;
                case SQLITE_BUSY:
                    continue;
                default:
                    if (sqlite3_reset(stmt) == SQLITE_CONSTRAINT) {
                        errPtr->code = REG_CONSTRAINT;
                        errPtr->description = "a constraint was disobeyed";
                        errPtr->free = NULL;
                    } else {
                        reg_sqlite_error(reg->db, errPtr, query);
                    }
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
 * Fetches a list of all open files
 *
 * @param [in] reg      registry to fetch files from
 * @param [out] files   a list of open files
 * @return              the number of open entries, -1 on error
 */
int reg_all_open_files(reg_registry* reg, reg_file*** files) {
    reg_file* file;
    int file_count = 0;
    int file_space = 10;
    Tcl_HashEntry* hash;
    Tcl_HashSearch search;
    *files = malloc(file_space * sizeof(reg_file*));
    if (!*files) {
        return -1;
    }
    for (hash = Tcl_FirstHashEntry(&reg->open_files, &search); hash != NULL;
            hash = Tcl_NextHashEntry(&search)) {
        file = Tcl_GetHashValue(hash);
        if (!reg_listcat((void***)files, &file_count, &file_space, file)) {
            free(*files);
            return -1;
        }
    }
    return file_count;
}

