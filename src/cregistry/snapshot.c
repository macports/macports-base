/*
 * snapshot.c
 * vim:tw=80:expandtab
 *
 * Copyright (c) 2017 The MacPorts Project
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

#include "entry.h"
#include "snapshot.h"
#include "registry.h"
#include "sql.h"
#include "util.h"

#include <sqlite3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/**
 * helper to parse variants into 'struct variant' form
 *
 * @param [in] variants_str     the string to parse the variants from
 * @param [in] delim            delimiter '+' for +ve variants, else '-'
 * @param [out] all_variants    list of 'struct variant's
 * @param [out] variant_count   count of variants parsed till now
 * @return                      false
 */

int get_parsed_variants(char* variants_str, variant* all_variants,
    char* delim, int* variant_count) {

    char *token;
    char *rest = variants_str;
    while ((token = strtok_r(rest, delim, &rest))) {
        variant v;
        v.variant_name = token;
        v.variant_sign = delim;

        *(all_variants + *variant_count) = v;
        *variant_count = *variant_count + 1;
    }
    return 0;
}

/**
 * Converts a `sqlite3_stmt` into a `reg_snapshot`. The first column of the stmt's
 * row must be the id of an snapshot; the second either `SQLITE_NULL` or the
 * address of the snapshot in memory.
 *
 * @param [in] userdata     sqlite3 database
 * @param [out] snapshot    snapshot described by `stmt`
 * @param [in] stmt         `sqlite3_stmt` with appropriate columns
 * @param [out] errPtr      unused
 * @return                  true if success; false if failure
 */
static int reg_stmt_to_snapshot(void* userdata, void** snapshot, void* stmt,
        void* calldata UNUSED, reg_error* errPtr UNUSED) {
    reg_registry* reg = (reg_registry*)userdata;
    sqlite_int64 id = sqlite3_column_int64(stmt, 0);
    reg_snapshot* s = malloc(sizeof(reg_snapshot));
    if (!s) {
        return 0;
    }
    s->reg = reg;
    s->id = id;
    s->proc = NULL;
    *snapshot = s;
    return 1;
}

/**
 * Type-safe version of `reg_all_objects` for `reg_snapshot`.
 *
 * @param [in] reg       registry to select snapshots from
 * @param [in] query     the select query to execute
 * @param [in] query_len length of the query (or -1 for automatic)
 * @param [out] objects  the snapshots selected
 * @param [out] errPtr   on error, a description of the error that occurred
 * @return               the number of snapshots if success; negative if failure
 */
static int reg_all_snapshots(reg_registry* reg, char* query, int query_len,
        reg_snapshot*** objects, reg_error* errPtr) {
    int lower_bound = 0;
    return reg_all_objects(reg, query, query_len, (void***)objects,
            reg_stmt_to_snapshot, &lower_bound, NULL, errPtr);
}

/**
 * Opens an existing snapshot in the registry.
 * NOTE: This function is actually not required but only to make sure that
 *       the user has input a valid sqlite id for snapshot
 *
 * @param [in] reg      registry to open snapshot in
 * @param [in] id       snapshot id as in registrydb
 * @param [out] errPtr  on error, a description of the error that occurred
 * @return              the snapshot if success; NULL if failure
 */
reg_snapshot* reg_snapshot_open(reg_registry* reg, sqlite_int64 id, reg_error* errPtr) {
    sqlite3_stmt* stmt = NULL;
    reg_snapshot* snapshot = NULL;
    char* query = "SELECT id FROM registry.snapshots WHERE id=?";
    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(stmt, 1, id) == SQLITE_OK)) {
        int r;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:
                    snapshot = (reg_snapshot*)malloc(sizeof(reg_snapshot));
                    snapshot->id = sqlite3_column_int64(stmt, 0);
                    snapshot->reg = reg;
                    snapshot->proc = NULL;
                    break;
                case SQLITE_DONE:
                    errPtr->code = REG_NOT_FOUND;
                    errPtr->description = sqlite3_mprintf("no snapshot found for id=%s", id);
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
    return snapshot;
}

/**
 * Lists the existing snapshots in the registry for the user to choose
 * from, for restore action
 *
 * @param [in] reg         registry to search in
 * @param [out] snapshots  a list of snapshots
 * @param [out] errPtr     on error, a description of the error that occurred
 * @return                 the number of snapshots if success; false if failure
 */
int reg_snapshot_list(reg_registry* reg, reg_snapshot*** snapshots, int limit, reg_error* errPtr) {
    // Currently limiting to last 10 snapshots in the registry
    int lower_bound = limit;
    char* query;
    int result;
    query = sqlite3_mprintf("SELECT id FROM registry.snapshots ORDER BY id DESC LIMIT %d",
            lower_bound);
    result = reg_all_snapshots(reg, query, -1, snapshots, errPtr);
    sqlite3_free(query);
    return result;
}

/**
 * Creates a new snapshot in the snapshots registry.
 *
 * @param [in] reg      the registry to create the snapshot in
 * @param [in] note     any note/details to identify the snapshot by the user
                        if not time
 * @param [out] errPtr  on error, a description of the error that occurred
 * @return              the snapshot if success; NULL if failure
 */
reg_snapshot* reg_snapshot_create(reg_registry* reg, char* note, reg_error* errPtr) {

    sqlite3_stmt* stmt = NULL;
    reg_snapshot* snapshot = NULL;
    char* query = "INSERT INTO registry.snapshots (note) VALUES (?)";

    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 1, note, -1, SQLITE_STATIC)
                == SQLITE_OK)) {
        int r;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_DONE:
                    snapshot = (reg_snapshot*)malloc(sizeof(reg_snapshot));
                    if (snapshot) {
                        snapshot->id = sqlite3_last_insert_rowid(reg->db);
                        snapshot->reg = reg;
                        snapshot->proc = NULL;

                        int ports_saved = snapshot_store_ports(reg, snapshot, errPtr);

                        switch (ports_saved) {
                            case 1:
                                // TODO: pass the custom SUCCESS message
                                break;
                            case 0:
                                reg_sqlite_error(reg->db, errPtr, query);
                                break;
                        }
                    }
                    break;
                case SQLITE_BUSY:
                    break;
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
    return snapshot;
}

/**
 * helper method for storing ports for this snapshot
 *
 * @param [in] reg          associated registry
 * @param [in] snapshot     reg_snapshot, its id to use for foreignkey'ing the ports
 * @param [out] errPtr      on error, a description of the error that occurred
 * @return                  true if success; 0 if failure
 */
int snapshot_store_ports(reg_registry* reg, reg_snapshot* snapshot, reg_error* errPtr) {
    reg_entry** entries;
    reg_error error;
    int i, entry_count;
    int result = 1;
    entry_count = reg_entry_installed(reg, NULL, &entries, &error);
    char* key1 = "name";
    char* key2 = "requested";
    char* key3 = "state";
    char* key4 = "variants";
    char* key5 = "negated_variants";
    if (entry_count >= 0) {
        for ( i = 0; i < entry_count; i++) {
            char* port_name;
            char* requested;
            char* state;
            char* positive_variants_str;
            char* negative_variants_str;
            sqlite3_stmt* stmt = NULL;
            reg_entry* entry = NULL;
            if (reg_entry_propget(entries[i], key1, &port_name, &error)
                && reg_entry_propget(entries[i], key2, &requested, &error)
                && reg_entry_propget(entries[i], key3, &state, &error)
                && reg_entry_propget(entries[i], key4, &positive_variants_str, &error)
                && reg_entry_propget(entries[i], key5, &negative_variants_str, &error)) {

                char* query = "INSERT INTO registry.snapshot_ports "
                    "(snapshots_id, port_name, requested, state, variants, negated_variants) "
                    "VALUES (?, ?, ?, ?, ?, ?)";

                if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
                        && (sqlite3_bind_int64(stmt, 1, snapshot->id) == SQLITE_OK)
                        && (sqlite3_bind_text(stmt, 2, port_name, -1, SQLITE_STATIC) == SQLITE_OK)
                        && (sqlite3_bind_int64(stmt, 3, atoi(requested)) == SQLITE_OK)
                        && (sqlite3_bind_text(stmt, 4, state, -1, SQLITE_STATIC) == SQLITE_OK)
                        && (sqlite3_bind_text(stmt, 5, positive_variants_str, -1, SQLITE_STATIC) == SQLITE_OK)
                        && (sqlite3_bind_text(stmt, 6, negative_variants_str, -1, SQLITE_STATIC) == SQLITE_OK)) {
                    int r;
                    do {
                        r = sqlite3_step(stmt);
                        switch (r) {
                            case SQLITE_DONE:
                                break;
                            case SQLITE_BUSY:
                                break;
                            default:
                                reg_sqlite_error(reg->db, errPtr, query);
                                result = 0;
                                break;
                        }
                    } while (r == SQLITE_BUSY);
                } else {
                    reg_sqlite_error(reg->db, errPtr, query);
                    result = 0;
                }
                if (stmt) {
                    sqlite3_finalize(stmt);
                }
            }
            free(entry);
        }
    }
    return result;
}

/**
 * reg_snapshot_ports_get: Gets the ports of a snapshot.
 *
 * @param [in] snapshot   snapshot to get property from
 * @param [out] ports     ports in the 'struct port' form defined in snapshot.h
 * @param [out] errPtr    on error, a description of the error that occurred
 * @return                port_count if success; -1 if failure
 */
int reg_snapshot_ports_get(reg_snapshot* snapshot, port*** ports, reg_error* errPtr) {

    reg_registry* reg = snapshot->reg;
    sqlite3_stmt* stmt = NULL;

    char* query = "SELECT * FROM registry.snapshot_ports WHERE snapshots_id=?";

    const char* port_name;
    const char* state;
    const char* positive_variants;
    const char* negated_variants;

    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
        && (sqlite3_bind_int64(stmt, 1, snapshot->id) == SQLITE_OK )) {

        // TODO: why 10?
        port** result = (port**)malloc(10 * sizeof(port*));

        if (!result) {
            return -1;
        }

        int result_count = 0;
        int result_space = 10;
        int r;

        sqlite_int64 snapshot_port_id;
        int requested;
        char* variantstr = NULL;

        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:

                    snapshot_port_id = sqlite3_column_int64(stmt, 0);
                    port_name = (const char*) sqlite3_column_text(stmt, 2);
                    requested = (int) sqlite3_column_int64(stmt, 3);
                    state = (const char*) sqlite3_column_text(stmt, 4);
                    positive_variants = (const char*) sqlite3_column_text(stmt, 5);
                    negated_variants = (const char*) sqlite3_column_text(stmt, 6);

                    port* current_port = (port*) malloc(sizeof(port));
                    if (!current_port) {
                        return -1;
                    }

                    variantstr = malloc(strlen(positive_variants) + strlen(negated_variants) + 1);
                    if (!variantstr) {
                        return -1;
                    }
                    variantstr[0] = '\0';
                    strcat(variantstr, positive_variants);
                    strcat(variantstr, negated_variants);

                    current_port->name = strdup(port_name);
                    current_port->requested = requested;
                    current_port->state = strdup(state);
                    current_port->variants = variantstr;

                    if (!reg_listcat((void***)&result, &result_count, &result_space, current_port)) {
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
            *ports = result;
            return result_count;
        } else {
            int i;
            for (i=0; i<result_count; i++) {
                free(result[i]);
            }
            free(result);
            return -1;
        }
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }
    reg_sqlite_error(reg->db, errPtr, query);
    return -1;
}

/**
 * Gets a named property of a snapshot. The property named must be one
 * that exists in the table and must not be one with internal meaning
 * such as `id` or `state`.
 *
 * @param [in] snapshot   snapshot to get property from
 * @param [in] key        property to get
 * @param [out] value     the value of the property
 * @param [out] errPtr    on error, a description of the error that occurred
 * @return                true if success; false if failure
 */
int reg_snapshot_propget(reg_snapshot* snapshot, char* key, char** value,
    reg_error* errPtr) {
    reg_registry* reg = snapshot->reg;
    int result = 0;
    sqlite3_stmt* stmt = NULL;
    char* query;
    const char *text;
    query = sqlite3_mprintf("SELECT %q FROM registry.snapshots WHERE id=%lld", key,
            snapshot->id);
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
                    errPtr->description = "An invalid snapshot was passed";
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
