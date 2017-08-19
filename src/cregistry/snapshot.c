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
#include <stdlib.h>
#include <string.h>

int get_parsed_variants(char* variants_str, variant* all_variants, char* delim, int* variant_count) {

    printf("var count yet %d, ", *variant_count);

    char *token;
    char *rest = variants_str;

    while ((token = strtok_r(rest, delim, &rest))) {

        printf("%s\n", token);

        variant v;
        v.variant_name = token;
        v.variant_sign = delim;

        *(all_variants + *variant_count) = v;
        *variant_count = *variant_count + 1;

        // all_variants = (variant*) realloc(all_variants, sizeof(variant));

        // if(!all_variants) {
        //     return -1;
        // }
    }

    return 0;
}

reg_snapshot* reg_snapshot_create(reg_registry* reg, char* note, reg_error* errPtr) {

    printf("inside cregsitry sn cr\n");

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

                        printf("snapshot id: %lld\n", snapshot->id);

                        int ports_saved = snapshot_store_ports(reg, snapshot, errPtr);

                        switch (ports_saved) {
                            case 1:
                                // TODO: pass the custom SUCCESS messages
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
    printf("done with the snapshot\n");
    return snapshot;
}

int snapshot_store_ports(reg_registry* reg, reg_snapshot* snapshot, reg_error* errPtr){
    reg_entry** entries;
    reg_error error;
    int i, entry_count;
    int result = 1;
    entry_count = reg_entry_imaged(reg, NULL, NULL, NULL, NULL,
            &entries, &error);
    printf("entry count: %d\n", entry_count);

    char* key1 = "name";
    char* key2 = "requested";
    char* key3 = "state";

    if (entry_count >= 0) {
        for ( i = 0; i < entry_count; i++) {
            char* port_name;
            char* requested;
            char* state;
            sqlite3_stmt* stmt = NULL;
            reg_entry* entry = NULL;
            if (reg_entry_propget(entries[i], key1, &port_name, &error)
                && reg_entry_propget(entries[i], key2, &requested, &error)
                && reg_entry_propget(entries[i], key3, &state, &error)) {

                char* query = "INSERT INTO registry.snapshot_ports "
                    "(snapshots_id, port_name, requested, state) "
                    "VALUES (?, ?, ?, ?)";

                if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
                        && (sqlite3_bind_int64(stmt, 1, snapshot->id) == SQLITE_OK)
                        && (sqlite3_bind_text(stmt, 2, port_name, -1, SQLITE_STATIC) == SQLITE_OK)
                        && (sqlite3_bind_int64(stmt, 3, atoi(requested)) == SQLITE_OK)
                        && (sqlite3_bind_text(stmt, 4, state, -1, SQLITE_STATIC) == SQLITE_OK)) {
                    int r;
                    do {
                        r = sqlite3_step(stmt);
                        switch (r) {
                            case SQLITE_DONE:
                                // store variants for entries[i]
                                entry = (reg_entry*)malloc(sizeof(reg_entry));
                                if (entry) {
                                    entry->id = sqlite3_last_insert_rowid(reg->db);
                                    entry->reg = reg;
                                    entry->proc = NULL;

                                    printf("port id: %lld, ", entry->id);

                                    int port_variants_saved = snapshot_store_port_variants(
                                        reg, entries[i], entry->id, errPtr);

                                    switch (port_variants_saved) {
                                        case 1:
                                            // TODO: pass the custom SUCCESS messages
                                            break;
                                        case 0:
                                            reg_sqlite_error(reg->db, errPtr, query);
                                            result = 0;
                                            break;
                                    }
                                }
                                printf("\ndone with *%s* port\n\n", port_name);
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

int snapshot_store_port_variants(reg_registry* reg, reg_entry* port_entry,
    int snapshot_ports_id, reg_error* errPtr) {

    reg_error error;
    int i, result = 1;

    char* key1 = "variants";
    char* key2 = "negated_variants";
    char* positive_variants_str;
    char* negative_variants_str;

    if(reg_entry_propget(port_entry, key1, &positive_variants_str, &error)
        && reg_entry_propget(port_entry, key2, &negative_variants_str, &error)) {

        printf("+ve .. %s, ", positive_variants_str);
        printf("-ve .. %s ", negative_variants_str);

        int variant_space = 10;
        variant* all_variants = (variant*) malloc(variant_space * sizeof(variant));

        if (all_variants == NULL) {
            return 0;
        }

        char* pos_delim = "+";
        char* neg_delim = "-";

        int variant_count = 0;

        int p = get_parsed_variants(positive_variants_str, all_variants, pos_delim, &variant_count);
        if (p < 0) {
            return 0;
        }

        int n = get_parsed_variants(negative_variants_str, all_variants, neg_delim, &variant_count);
        if (n < 0) {
            return 0;
        }

        printf("total var count: %d, ", variant_count);

        for ( i = 0; i < variant_count; i++){
            sqlite3_stmt* stmt = NULL;
            char* query = "INSERT INTO registry.snapshot_port_variants "
                "(snapshot_ports_id, variant_name, variant_sign) "
                "VALUES (?, ?, ?)";
            variant v = *(all_variants + i);
            if((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
                    && (sqlite3_bind_int64(stmt, 1, snapshot_ports_id) == SQLITE_OK)
                    && (sqlite3_bind_text(stmt, 2, v.variant_name, -1, SQLITE_STATIC) == SQLITE_OK)
                    && (sqlite3_bind_text(stmt, 3, v.variant_sign, -1, SQLITE_STATIC) == SQLITE_OK)) {
                int r;
                do {
                    r = sqlite3_step(stmt);
                    switch (r) {
                        case SQLITE_DONE:
                            printf("\nvariant stored: %s with sign: %s",
                                v.variant_name, v.variant_sign);
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
        }
        free(all_variants);
    }
    return result;
}

int reg_snapshot_ports_get(reg_snapshot* snapshot, port*** ports, reg_error* errPtr) {

    printf("inside cregistry get snapshot..\n");
    reg_registry* reg = snapshot->reg;
    sqlite3_stmt* stmt = NULL;

    char* query = "SELECT * FROM registry.snapshot_ports WHERE snapshots_id=?";

    const char* port_name;
    const char* state;

    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
        && (sqlite3_bind_int64(stmt, 1, snapshot->id) == SQLITE_OK )) {

        port** result = (port**)malloc(10 * sizeof(port*));

        if (!result) {
            return -1;
        }

        int result_count = 0;
        int result_space = 10;
        int r;

        variant** variants;

        sqlite_int64 snapshot_port_id;
        int requested;

        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:

                    snapshot_port_id = sqlite3_column_int64(stmt, 0);
                    port_name = (const char*) sqlite3_column_text(stmt, 2);
                    requested = (int) sqlite3_column_int64(stmt, 3);
                    state = (const char*) sqlite3_column_text(stmt, 4);

                    port* current_port = (port*) malloc(sizeof(port));
                    if (!current_port) {
                        return -1;
                    }
                    current_port->name = strdup(port_name);
                    current_port->requested = requested;
                    current_port->state = strdup(state);
                    current_port->variants = NULL;
                    
                    variants = (variant**) malloc(sizeof(variant*));
                    if (!variants) {
                        return -1;
                    }
                    int variant_count = reg_snapshot_ports_get_helper(reg, snapshot_port_id, &variants, errPtr);
                    if (variant_count > 0) {
                        current_port->variants = variants;
                    }
                    if (!reg_listcat((void***)&result, &result_count, &result_space, current_port)) {
                            r = SQLITE_ERROR;
                    }
                    int i;
                    for (i=0; i < variant_count; i++) {
                        free(variants[i]);
                    }
                    free(variants);
                    variants = NULL;
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
}

int reg_snapshot_ports_get_helper(reg_registry* reg, sqlite_int64 snapshot_port_id, variant*** variants, reg_error* errPtr) {

    sqlite3_stmt* stmt = NULL;

    char* query = "SELECT * FROM registry.snapshot_port_variants WHERE snapshot_ports_id=?";

    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
        && (sqlite3_bind_int64(stmt, 1, snapshot_port_id) == SQLITE_OK )) {

        int result_count = 0;
        int result_space = 10;
        int r;

        variant** result = (variant**)malloc(result_space * sizeof(variant*));
        if (!result) {
            return -1;
        }

        const char* variant_name;
        const char* variant_sign;

        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:

                    variant_name = (const char*)sqlite3_column_text(stmt, 2);
                    variant_sign = (const char*)sqlite3_column_text(stmt, 3);

                    variant* element = (variant*)malloc(sizeof(variant));
                    if (!element) {
                        return -1;
                    }
                    element->variant_name = strdup(variant_name);
                    element->variant_sign = strdup(variant_sign);
                    if (!reg_listcat((void***)&result, &result_count, &result_space, element)) {
                        r = SQLITE_ERROR;
                    }
                    //free(element);
                    break;
                case SQLITE_DONE:
                case SQLITE_BUSY:
                    continue;
                default:
                    reg_sqlite_error(reg->db, errPtr, query);
                    break;
            }
        } while (r == SQLITE_ROW || r == SQLITE_BUSY);

        if (r == SQLITE_DONE) {
            *variants = result;
            return result_count;
        } else {
            int i;
            for (i = 0; i < result_count; i++) {
                free((*(*variants + i))->variant_name);
                free((*(*variants + i))->variant_sign);
            }
            free(variants);
            return -1;
        }
        sqlite3_finalize(stmt);
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
        if (stmt) {
            sqlite3_finalize(stmt);
        }
        return -1;
    }
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
