/*
 * vim:tw=80:expandtab
 *
 * Copyright (c) 2014 The MacPorts Project
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

#include "portgroup.h"
#include "util.h"
#include "registry.h"
#include "sql.h"

#include <sqlite3.h>
#include <stdlib.h>
#include <string.h>

/**
 * Converts a `sqlite3_stmt` into a `reg_portgroup`. The first column of the stmt's
 * row must be the id of a portgroup; the second either `SQLITE_NULL` or the
 * address of the entry in memory.
 *
 * @param [in] userdata sqlite3 database
 * @param [out] portgroup   portgroup described by `stmt`
 * @param [in] stmt     `sqlite3_stmt` with appropriate columns
 * @param [out] errPtr  unused
 * @return              true if success; false if failure
 */
static int reg_stmt_to_portgroup(void* userdata, void** portgroup, void* stmt,
        void* calldata UNUSED, reg_error* errPtr UNUSED) {
    int is_new;
    reg_registry* reg = (reg_registry*)userdata;
    sqlite_int64 id = sqlite3_column_int64(stmt, 0);
    Tcl_HashEntry* hash = Tcl_CreateHashEntry(&reg->open_portgroups,
            (const char*)&id, &is_new);
    if (is_new) {
        reg_portgroup* p = malloc(sizeof(reg_portgroup));
        if (!p) {
            return 0;
        }
        p->reg = reg;
        p->id = id;
        p->proc = NULL;
        *portgroup = p;
        Tcl_SetHashValue(hash, p);
    } else {
        *portgroup = Tcl_GetHashValue(hash);
    }
    return 1;
}

/**
 * Type-safe version of `reg_all_objects` for `reg_portgroup`.
 *
 * @param [in] reg       registry to select entries from
 * @param [in] query     the select query to execute
 * @param [in] query_len length of the query (or -1 for automatic)
 * @param [out] objects  the portgroups selected
 * @param [out] errPtr   on error, a description of the error that occurred
 * @return               the number of entries if success; negative if failure
 */
int reg_all_portgroups(reg_registry* reg, char* query, int query_len,
        reg_portgroup*** objects, reg_error* errPtr) {
    int lower_bound = 0;
    return reg_all_objects(reg, query, query_len, (void***)objects,
            reg_stmt_to_portgroup, &lower_bound, NULL, errPtr);
}

/**
 * Searches the registry for portgroups for which each key's value is equal to the
 * given value. To find all portgroups, pass a key_count of 0.
 *
 * Bad keys should cause sqlite3 errors but not permit SQL injection attacks.
 * Pass it good keys anyway.
 *
 * @param [in] reg       registry to search in
 * @param [in] keys      a list of keys to search by
 * @param [in] vals      a list of values to search by, matching keys
 * @param [in] strats    a list of strategies to use when searching
 * @param [in] key_count the number of key/value pairs passed
 * @param [out] portgroups    a list of matching portgroups
 * @param [out] errPtr   on error, a description of the error that occurred
 * @return               the number of entries if success; false if failure
 */
int reg_portgroup_search(reg_registry* reg, char** keys, char** vals, int* strats,
        int key_count, reg_portgroup*** portgroups, reg_error* errPtr) {
    int i;
    char* kwd = " WHERE ";
    char* query;
    size_t query_len, query_space;
    int result;

    /* build the query */
    query = strdup("SELECT ROWID FROM registry.portgroups");
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
    result = reg_all_portgroups(reg, query, -1, portgroups, errPtr);
    free(query);
    return result;
}

/**
 * Gets a named property of a portgroup. That property can be set using
 * `reg_portgroup_propset`. The property named must be one that exists in the table
 * and must not be one with internal meaning such as `id` or `state`.
 *
 * @param [in] portgroup   portgroup to get property from
 * @param [in] key     property to get
 * @param [out] value  the value of the property
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_portgroup_propget(reg_portgroup* portgroup, char* key, char** value,
        reg_error* errPtr) {
    reg_registry* reg = portgroup->reg;
    int result = 0;
    sqlite3_stmt* stmt = NULL;
    char* query;
    const char *text;
    query = sqlite3_mprintf("SELECT %q FROM registry.portgroups WHERE ROWID=%lld", key,
            portgroup->id);
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
                    errPtr->description = "an invalid portgroup was passed";
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
 * Sets a named property of an portgroup. That property can be later retrieved using
 * `reg_portgroup_propget`. The property named must be one that exists in the table
 * and must not be one with internal meaning such as `id` or `state`. If `name`,
 * `epoch`, `version`, `revision`, or `variants` is set, it could trigger a
 * conflict if another port with the same combination of values for those
 * columns exists.
 *
 * @param [in] portgroup   portgroup to set property for
 * @param [in] key     property to set
 * @param [in] value   the desired value of the property
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_portgroup_propset(reg_portgroup* portgroup, char* key, char* value,
        reg_error* errPtr) {
    reg_registry* reg = portgroup->reg;
    int result = 0;
    sqlite3_stmt* stmt = NULL;
    char* query;
    query = sqlite3_mprintf("UPDATE registry.ports SET %q = '%q' WHERE ROWID=%lld",
            key, value, portgroup->id);
    if (sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK) {
        int r;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_DONE:
                    result = 1;
                    break;
                case SQLITE_BUSY:
                    break;
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
 * Opens an existing portgroup in the registry.
 *
 * @param [in] reg      registry to open portgroup in
 * @param [in] id       id of entry referencing portgroup
 * @param [in] name     name of portgroup
 * @param [in] version  version of portgroup
 * @param [in] size     size of portgroup
 * @param [in] sha256   sha256 of portgroup
 * @param [out] errPtr  on error, a description of the error that occurred
 * @return              the portgroup if success; NULL if failure
 */
reg_portgroup* reg_portgroup_open(reg_registry* reg, char *id, char* name, char* version,
        char* size, char* sha256, reg_error* errPtr) {
    sqlite3_stmt* stmt = NULL;
    reg_portgroup* portgroup = NULL;
    int lower_bound = 0;
    char* query;
    query = "SELECT ROWID FROM registry.portgroups WHERE id=? AND name=? AND version=? "
        "AND size=? AND sha256=?";
    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 1, id, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 2, name, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 3, version, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 4, size, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 5, sha256, -1, SQLITE_STATIC)
                == SQLITE_OK)) {
        int r;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:
                    reg_stmt_to_portgroup(reg, (void**)&portgroup, stmt, &lower_bound, errPtr);
                    break;
                case SQLITE_DONE:
                    errPtr->code = REG_NOT_FOUND;
                    errPtr->description = sqlite3_mprintf("no matching portgroup found for: " \
                            "id=%s, name=%s, version=%s, size=%s, sha256=%s", \
                            id, name, version, size, sha256);
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
    return portgroup;
}
