/*
 * entry.c
 * $Id: $
 *
 * Copyright (c) 2007 Chris Pickel <sfiera@macports.org>
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

#include <string.h>
#include <stdlib.h>
#include <sqlite3.h>

#include <cregistry/entry.h>
#include <cregistry/registry.h>
#include <cregistry/sql.h>

/**
 * Concatenates `src` to string `dst`.
 *
 * Simple concatenation. Only guaranteed to work with strings that have been
 * allocated with `malloc`. Amortizes cost of expanding string buffer for O(N)
 * concatenation and such. Uses `memcpy` in favor of `strcpy` in hopes it will
 * perform a bit better.
 */
void reg_strcat(char** dst, int* dst_len, int* dst_space, char* src) {
    int src_len = strlen(src);
    int result_len = *dst_len + src_len;
    if (result_len >= *dst_space) {
        char* old_dst = *dst;
        *dst_space *= 2;
        if (*dst_space < result_len) {
            *dst_space = result_len;
        }
        *dst = malloc(*dst_space * sizeof(char) + 1);
        memcpy(*dst, old_dst, *dst_len);
        free(old_dst);
    }
    memcpy(*dst + *dst_len, src, src_len+1);
    *dst_len = result_len;
}

/**
 * Appends `src` to the list `dst`.
 *
 * It's like `reg_strcat`, except `src` represents an element and not a sequence
 * of `char`s.
 */
static void reg_listcat(void*** dst, int* dst_len, int* dst_space, void* src) {
    if (*dst_len == *dst_space) {
        void** old_dst = *dst;
        void** new_dst = malloc(*dst_space * 2 * sizeof(void*));
        *dst_space *= 2;
        memcpy(new_dst, old_dst, *dst_len);
        *dst = new_dst;
        free(old_dst);
    }
    (*dst)[*dst_len] = src;
    (*dst_len)++;
}

/**
 * Returns the operator to use for the given strategy.
 */
static char* reg_strategy_op(reg_strategy strategy, reg_error* errPtr) {
    switch (strategy) {
        case reg_strategy_equal:
            return "=";
        case reg_strategy_glob:
            return " GLOB ";
        case reg_strategy_regexp:
            return " REGEXP ";
        default:
            errPtr->code = "registry::invalid-strategy";
            errPtr->description = "invalid matching strategy specified";
            errPtr->free = NULL;
            return NULL;
    }
}

/**
 * Converts a `sqlite3_stmt` into a `reg_entry`. The first column of the stmt's
 * row must be the id of an entry; the second either `SQLITE_NUL`L or the
 * address of the entry in memory.
 */
static int reg_stmt_to_entry(void* userdata, void** entry, void* stmt,
        reg_error* errPtr UNUSED) {
    if (sqlite3_column_type(stmt, 1) == SQLITE_NULL) {
        reg_entry* e = malloc(sizeof(reg_entry));
        e->db = (sqlite3*)userdata;
        e->id = sqlite3_column_int64(stmt, 0);
        e->saved = 0;
        e->proc = NULL;
        *entry = e;
    } else {
        *entry = *(reg_entry**)sqlite3_column_blob(stmt, 1);
    }
    return 1;
}

/**
 * Saves the addresses of existing `reg_entry` items into the temporary sqlite3
 * table `entries`. These addresses will be retrieved by anything else that
 * needs to get entries, so only one `reg_entry` will exist in memory for any
 * given id. They will be freed when the registry is closed.
 */
static int reg_save_addresses(sqlite3* db, reg_entry** entries,
        int entry_count, reg_error* errPtr) {
    sqlite3_stmt* stmt;
    int i;
    char* query = "INSERT INTO entries (id, address) VALUES (?, ?)";
    /* avoid preparing the statement if unnecessary */
    for (i=0; i<entry_count; i++) {
        if (!entries[i]->saved) {
            break;
        }
    }
    if (i == entry_count) {
        return 1;
    }
    if (sqlite3_prepare(db, query, -1, &stmt, NULL)
                == SQLITE_OK) {
        for (i=0; i<entry_count; i++) {
            if (entries[i]->saved) {
                continue;
            }
            if ((sqlite3_bind_int64(stmt, 1, entries[i]->id) == SQLITE_OK)
                    && (sqlite3_bind_blob(stmt, 2, &entries[i],
                            sizeof(reg_entry*), SQLITE_TRANSIENT) == SQLITE_OK)
                    && (sqlite3_step(stmt) == SQLITE_DONE)) {
                sqlite3_reset(stmt);
            } else {
                sqlite3_finalize(stmt);
                reg_sqlite_error(db, errPtr, query);
                return 0;
            }
        }
        sqlite3_finalize(stmt);
        return 1;
    } else {
        sqlite3_finalize(stmt);
        reg_sqlite_error(db, errPtr, query);
    }
    return 0;
}

/**
 * registry::entry create portname version revision variants epoch ?name?
 *
 * Unlike the old registry::new_entry, revision, variants, and epoch are all
 * required. That's OK because there's only one place this function is called,
 * and it's called with all of them there.
 */
reg_entry* reg_entry_create(reg_registry* reg, char* name, char* version,
        char* revision, char* variants, char* epoch, reg_error* errPtr) {
    sqlite3_stmt* stmt;
    char* query = "INSERT INTO registry.ports "
        "(name, version, revision, variants, epoch) VALUES (?, ?, ?, ?, ?)";
    if (!reg_test_writable(reg, errPtr)) {
        return NULL;
    }
    if ((sqlite3_prepare(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 2, version, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 3, revision, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 4, variants, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 5, epoch, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_step(stmt) == SQLITE_DONE)) {
        char* query = "INSERT INTO entries (id, address) VALUES (?, ?)";
        reg_entry* entry = malloc(sizeof(reg_entry));
        entry->id = sqlite3_last_insert_rowid(reg->db);
        entry->db = reg->db;
        entry->proc = NULL;
        sqlite3_finalize(stmt);
        if ((sqlite3_prepare(reg->db, query, -1, &stmt, NULL)
                == SQLITE_OK)
                && (sqlite3_bind_int64(stmt, 1, entry->id) == SQLITE_OK)
                && (sqlite3_bind_blob(stmt, 2, &entry, sizeof(reg_entry*),
                        SQLITE_TRANSIENT) == SQLITE_OK)
                && (sqlite3_step(stmt) == SQLITE_DONE)) {
            return entry;
        } else {
            reg_sqlite_error(reg->db, errPtr, query);
        }
        free(entry);
        return NULL;
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
        sqlite3_finalize(stmt);
        return NULL;
    }
}

reg_entry* reg_entry_open(reg_registry* reg, char* name, char* version,
        char* revision, char* variants, char* epoch, reg_error* errPtr) {
    sqlite3_stmt* stmt;
    char* query = "SELECT registry.ports.id, entries.address "
        "FROM registry.ports LEFT OUTER JOIN entries USING (id) "
        "WHERE name=? AND version=? AND revision=? AND variants=? AND epoch=?";
    if ((sqlite3_prepare(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 2, version, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 3, revision, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 4, variants, -1, SQLITE_STATIC)
                == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 5, epoch, -1, SQLITE_STATIC)
                == SQLITE_OK)) {
        int r = sqlite3_step(stmt);
        reg_entry* entry;
        switch (r) {
            case SQLITE_ROW:
                if (reg_stmt_to_entry(reg->db, (void**)&entry, stmt, errPtr)) {
                    sqlite3_finalize(stmt);
                    if (reg_save_addresses(reg->db, &entry, 1, errPtr)) {
                        return entry;
                    }
                }
            case SQLITE_DONE:
                errPtr->code = "registry::not-found";
                errPtr->description = "no matching port found";
                errPtr->free = NULL;
                break;
            default:
                reg_sqlite_error(reg->db, errPtr, query);
                break;
        }
        sqlite3_finalize(stmt);
        return NULL;
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
        sqlite3_finalize(stmt);
        return NULL;
    }
}

/**
 * deletes an entry; still needs to be freed
 */
int reg_entry_delete(reg_registry* reg, reg_entry* entry, reg_error* errPtr) {
    sqlite3_stmt* stmt;
    char* query = "DELETE FROM registry.ports WHERE id=?";
    if (!reg_test_writable(reg, errPtr)) {
        return 0;
    }
    if ((sqlite3_prepare(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(stmt, 1, entry->id) == SQLITE_OK)
            && (sqlite3_step(stmt) == SQLITE_DONE)) {
        if (sqlite3_changes(reg->db) > 0) {
            sqlite3_finalize(stmt);
            query = "DELETE FROM entries WHERE id=?";
            if ((sqlite3_prepare(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
                    && (sqlite3_bind_int64(stmt, 1, entry->id) == SQLITE_OK)
                    && (sqlite3_step(stmt) == SQLITE_DONE)) {
                sqlite3_finalize(stmt);
                return 1;
            }
        } else {
            errPtr->code = "registry::invalid-entry";
            errPtr->description = "an invalid entry was passed";
            errPtr->free = NULL;
        }
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
    }
    sqlite3_finalize(stmt);
    return 0;
}

/*
 * Frees the given entry - not good to expose?
 */
static void reg_entry_free(reg_registry* reg UNUSED, reg_entry* entry) {
    sqlite3_stmt* stmt;
    if (entry->proc != NULL) {
        free(entry->proc);
    }
    free(entry);
    sqlite3_prepare(entry->db, "DELETE FROM entries WHERE address=?", -1, &stmt,
            NULL);
    sqlite3_bind_blob(stmt, 1, &entry, sizeof(reg_entry*), SQLITE_TRANSIENT);
    sqlite3_step(stmt);
}

static int reg_all_objects(sqlite3* db, char* query, int query_len,
        void*** objects, cast_function* fn, free_function* del,
        reg_error* errPtr) {
    int r;
    reg_entry* entry;
    void** results = malloc(10*sizeof(void*));
    int result_count = 0;
    int result_space = 10;
    sqlite3_stmt* stmt;
    if (sqlite3_prepare(db, query, query_len, &stmt, NULL) == SQLITE_OK) {
        do {
            int i;
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:
                    if (fn(db, (void**)&entry, stmt, errPtr)) {
                        reg_listcat(&results, &result_count, &result_space,
                                entry);
                        continue;
                    } else {
                        int i;
                        sqlite3_finalize(stmt);
                        for (i=0; i<result_count; i++) {
                            del(NULL, results[i]);
                        }
                        free(results);
                        return -1;
                    }
                case SQLITE_DONE:
                    break;
                default:
                    for (i=0; i<result_count; i++) {
                        del(NULL, results[i]);
                    }
                    free(results);
                    sqlite3_finalize(stmt);
                    reg_sqlite_error(db, errPtr, query);
                    return -1;
            }
        } while (r != SQLITE_DONE);
        *objects = results;
        return result_count;
    } else {
        reg_sqlite_error(db, errPtr, query);
        free(results);
        return -1;
    }
}

/*
 * Searches the registry for ports for which each key's value is equal to the
 * given value. To find all ports, pass 0 key-value pairs.
 *
 * Vulnerable to SQL-injection attacks in the `keys` field. Pass it valid keys,
 * please.
 */
int reg_entry_search(reg_registry* reg, char** keys, char** vals, int key_count,
        int strategy, reg_entry*** entries, reg_error* errPtr) {
    int i;
    char* kwd = " WHERE ";
    char* query;
    int query_len = 96;
    int query_space = 96;
    int result;
    /* get the strategy */
    char* op = reg_strategy_op(strategy, errPtr);
    if (op == NULL) {
        return -1;
    }
    /* build the query */
    query = strdup("SELECT registry.ports.id, entries.address "
            "FROM registry.ports LEFT OUTER JOIN entries USING (id)");
    for (i=0; i<key_count; i+=1) {
        char* cond = sqlite3_mprintf("%s%s%s'%q'", kwd, keys[i], op, vals[i]);
        reg_strcat(&query, &query_len, &query_space, cond);
        sqlite3_free(cond);
        kwd = " AND ";
    }
    /* do the query */
    result = reg_all_objects(reg->db, query, query_len, (void***)entries,
            reg_stmt_to_entry, (free_function*)reg_entry_free, errPtr);
    if (result > 0) {
        if (!reg_save_addresses(reg->db, *entries, result, errPtr)) {
            free(entries);
            return 0;
        }
    }
    free(query);
    return result;
}

/**
 * Finds ports which are installed as an image, and/or those which are active
 * in the filesystem. When the install mode is 'direct', this will be equivalent
 * to `reg_entry_installed`.
 * @todo add more arguments (epoch, revision, variants), maybe
 *
 * @param [in] reg      registry object as created by `registry_open`
 * @param [in] name     specific port to find (NULL for any)
 * @param [in] version  specific version to find (NULL for any)
 * @param [out] entries list of ports meeting the criteria
 * @param [out] errPtr  description of error encountered, if any
 * @return              the number of such ports found
 */
int reg_entry_imaged(reg_registry* reg, char* name, char* version, 
        reg_entry*** entries, reg_error* errPtr) {
    char* format;
    char* query;
    int result;
    char* select = "SELECT registry.ports.id, entries.address FROM "
        "registry.ports LEFT OUTER JOIN entries USING (id)";
    if (name == NULL) {
        format = "%s WHERE (state='imaged' OR state='installed')";
    } else if (version == NULL) {
        format = "%s WHERE (state='imaged' OR state='installed') AND name='%q'";
    } else {
        format = "%s WHERE (state='imaged' OR state='installed') AND name='%q' "
            "AND version='%q'";
    }
    query = sqlite3_mprintf(format, select, name, version);
    result = reg_all_objects(reg->db, query, -1, (void***)entries,
            reg_stmt_to_entry, (free_function*)reg_entry_free, errPtr);
    if (result > 0) {
        if (!reg_save_addresses(reg->db, *entries, result, errPtr)) {
            free(entries);
            return 0;
        }
    }
    sqlite3_free(query);
    return result;
}

/**
 * Finds ports which are active in the filesystem. These ports are able to fill
 * dependencies, and properly own the files they map.
 * @todo add more arguments (epoch, revision, variants), maybe
 *
 * @param [in] reg      registry object as created by `registry_open`
 * @param [in] name     specific port to find (NULL for any)
 * @param [out] entries list of ports meeting the criteria
 * @param [out] errPtr  description of error encountered, if any
 * @return              the number of such ports found
 */
int reg_entry_installed(reg_registry* reg, char* name, reg_entry*** entries,
        reg_error* errPtr) {
    char* format;
    char* query;
    int result;
    char* select = "SELECT registry.ports.id, entries.address FROM "
        "registry.ports LEFT OUTER JOIN entries USING (id)";
    if (name == NULL) {
        format = "%s WHERE state='installed'";
    } else {
        format = "%s WHERE state='installed' AND name='%q'";
    }
    query = sqlite3_mprintf(format, select, name);
    result = reg_all_objects(reg->db, query, -1, (void***)entries,
            reg_stmt_to_entry, (free_function*)reg_entry_free, errPtr);
    if (result > 0) {
        if (!reg_save_addresses(reg->db, *entries, result, errPtr)) {
            free(entries);
            return 0;
        }
    }
    sqlite3_free(query);
    return result;
}

int reg_entry_owner(reg_registry* reg, char* path, reg_entry** entry,
        reg_error* errPtr) {
    sqlite3_stmt* stmt;
    reg_entry* result;
    char* query = "SELECT registry.files.id, entries.address "
        "FROM registry.files INNER JOIN registry.ports USING(id)"
        " LEFT OUTER JOIN entries USING(id) "
        "WHERE path=? AND registry.ports.state = 'installed'";
    if ((sqlite3_prepare(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 1, path, -1, SQLITE_STATIC)
                == SQLITE_OK)) {
        int r = sqlite3_step(stmt);
        switch (r) {
            case SQLITE_ROW:
                if (reg_stmt_to_entry(reg->db, (void**)&result, stmt, errPtr)) {
                    sqlite3_finalize(stmt);
                    if (reg_save_addresses(reg->db, &result, 1, errPtr)) {
                        *entry = result;
                        return 1;
                    }
                }
            case SQLITE_DONE:
                sqlite3_finalize(stmt);
                *entry = NULL;
                return 1;
            default:
                /* barf */
                sqlite3_finalize(stmt);
                return 0;
        }
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
        sqlite3_finalize(stmt);
        return 0;
    }
}

int reg_entry_propget(reg_registry* reg, reg_entry* entry, char* key,
        char** value, reg_error* errPtr) {
    sqlite3_stmt* stmt;
    char* query;
    query = sqlite3_mprintf("SELECT %q FROM registry.ports WHERE id=%lld", key,
            entry->id);
    if (sqlite3_prepare(reg->db, query, -1, &stmt, NULL) == SQLITE_OK) {
        int r = sqlite3_step(stmt);
        switch (r) {
            case SQLITE_ROW:
                *value = strdup((const char*)sqlite3_column_text(stmt, 0));
                sqlite3_finalize(stmt);
                return 1;
            case SQLITE_DONE:
                errPtr->code = "registry::invalid-entry";
                errPtr->description = "an invalid entry was passed";
                errPtr->free = NULL;
                sqlite3_finalize(stmt);
                return 0;
            default:
                reg_sqlite_error(reg->db, errPtr, query);
                sqlite3_finalize(stmt);
                return 0;
        }
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
        return 0;
    }
}

int reg_entry_propset(reg_registry* reg, reg_entry* entry, char* key,
        char* value, reg_error* errPtr) {
    sqlite3_stmt* stmt;
    char* query;
    if (!reg_test_writable(reg, errPtr)) {
        return -1;
    }
    query = sqlite3_mprintf("UPDATE registry.ports SET %q = '%q' WHERE id=%lld",
            key, value, entry->id);
    if (sqlite3_prepare(reg->db, query, -1, &stmt, NULL) == SQLITE_OK) {
        int r = sqlite3_step(stmt);
        switch (r) {
            case SQLITE_DONE:
                sqlite3_finalize(stmt);
                return 1;
            default:
                switch (sqlite3_reset(stmt)) {
                    case SQLITE_CONSTRAINT:
                        errPtr->code = "registry::constraint";
                        errPtr->description = "a constraint was disobeyed";
                        errPtr->free = NULL;
                        sqlite3_finalize(stmt);
                        return 0;
                    default:
                        reg_sqlite_error(reg->db, errPtr, query);
                        sqlite3_finalize(stmt);
                        return 0;
                }
        }
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
        return 0;
    }
}

int reg_entry_map(reg_registry* reg, reg_entry* entry, char** files,
        int file_count, reg_error* errPtr) {
    sqlite3_stmt* stmt;
    char* insert = "INSERT INTO registry.files (id, path) VALUES (?, ?)";
    if (!reg_test_writable(reg, errPtr)) {
        return -1;
    }
    if ((sqlite3_prepare(reg->db, insert, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(stmt, 1, entry->id) == SQLITE_OK)) {
        int i;
        for (i=0; i<file_count; i++) {
            if (sqlite3_bind_text(stmt, 2, files[i], -1, SQLITE_STATIC)
                    == SQLITE_OK) {
                int r = sqlite3_step(stmt);
                switch (r) {
                    case SQLITE_DONE:
                        sqlite3_reset(stmt);
                        continue;
                    default:
                        reg_sqlite_error(reg->db, errPtr, insert);
                        sqlite3_finalize(stmt);
                        return i;
                }
            } else {
                reg_sqlite_error(reg->db, errPtr, insert);
                sqlite3_finalize(stmt);
                return i;
            }
        }
        sqlite3_finalize(stmt);
        return file_count;
    } else {
        reg_sqlite_error(reg->db, errPtr, insert);
        sqlite3_finalize(stmt);
        return 0;
    }
}

int reg_entry_unmap(reg_registry* reg, reg_entry* entry, char** files,
        int file_count, reg_error* errPtr) {
    sqlite3_stmt* stmt;
    char* query = "DELETE FROM registry.files WHERE id=? AND path=?";
    if (!reg_test_writable(reg, errPtr)) {
        return -1;
    }
    if ((sqlite3_prepare(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(stmt, 1, entry->id) == SQLITE_OK)) {
        int i;
        for (i=0; i<file_count; i++) {
            if (sqlite3_bind_text(stmt, 2, files[i], -1, SQLITE_STATIC)
                    == SQLITE_OK) {
                int r = sqlite3_step(stmt);
                switch (r) {
                    case SQLITE_DONE:
                        if (sqlite3_changes(reg->db) == 0) {
                            errPtr->code = "registry::not-owned";
                            errPtr->description = "this entry does not own the "
                                "given file";
                            errPtr->free = NULL;
                            sqlite3_finalize(stmt);
                            return i;
                        } else {
                            sqlite3_reset(stmt);
                            continue;
                        }
                    default:
                        reg_sqlite_error(reg->db, errPtr, query);
                        sqlite3_finalize(stmt);
                        return i;
                }
            } else {
                reg_sqlite_error(reg->db, errPtr, query);
                sqlite3_finalize(stmt);
                return i;
            }
        }
        sqlite3_finalize(stmt);
        return file_count;
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
        sqlite3_finalize(stmt);
        return 0;
    }
}

int reg_entry_files(reg_registry* reg, reg_entry* entry, char*** files,
        reg_error* errPtr) {
    sqlite3_stmt* stmt;
    char* query = "SELECT path FROM registry.files WHERE id=? ORDER BY path";
    if ((sqlite3_prepare(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(stmt, 1, entry->id) == SQLITE_OK)) {
        char** result = malloc(10*sizeof(char*));
        int result_count = 0;
        int result_space = 10;
        int r;
        do {
            char* element;
            int i;
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:
                    element = strdup((const char*)sqlite3_column_text(stmt, 0));
                    reg_listcat((void*)&result, &result_count, &result_space,
                            element);
                    break;
                case SQLITE_DONE:
                    break;
                default:
                    for (i=0; i<result_count; i++) {
                        free(result[i]);
                    }
                    free(result);
                    reg_sqlite_error(reg->db, errPtr, query);
                    sqlite3_finalize(stmt);
                    return -1;
            }
        } while (r != SQLITE_DONE);
        sqlite3_finalize(stmt);
        *files = result;
        return result_count;
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
        sqlite3_finalize(stmt);
        return -1;
    }
}

int reg_all_entries(reg_registry* reg, reg_entry*** entries, reg_error* errPtr){
    reg_entry* entry;
    void** results = malloc(10*sizeof(void*));
    int result_count = 0;
    int result_space = 10;
    sqlite3_stmt* stmt;
    char* query = "SELECT address FROM entries";
    if (sqlite3_prepare(reg->db, query, -1, &stmt, NULL) == SQLITE_OK) {
        int r;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:
                    entry = *(reg_entry**)sqlite3_column_blob(stmt, 0);
                    reg_listcat(&results, &result_count, &result_space, entry);
                    break;
                case SQLITE_DONE:
                    break;
                default:
                    reg_sqlite_error(reg->db, errPtr, query);
                    free(results);
                    return -1;
            }
        } while (r != SQLITE_DONE);
    }
    *entries = (reg_entry**)results;
    return result_count;
}
