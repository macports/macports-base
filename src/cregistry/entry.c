/*
 * entry.c
 *
 * Copyright (c) 2010-2011, 2014, 2017-2018 The MacPorts Project
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

/* required for asprintf(3) on macOS */
#define _DARWIN_C_SOURCE
/* required for asprintf(3) on Linux */
#define _GNU_SOURCE

#include "portgroup.h"
#include "entry.h"
#include "registry.h"
#include "sql.h"
#include "util.h"

#include <sqlite3.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/*
 * TODO: reg_entry_installed and reg_entry_imaged could benefit from the added
 *       flexibility of -glob and -regexp too. Not a high priority, though.
 *
 * TODO: process the 'state' keyword in a more efficient way. I still believe
 *       there could be benefits to be reaped in the future by allowing
 *       arbitrary values; but at the same time the field will (or should)
 *       always have very discrete values. These could be more efficiently dealt
 *       with as integers.
 *
 * TODO: considering a "weak" flag in registry.files. The meaning of this would
 *       be "I wish for my version of this file to be activated when I am, but
 *       not to be deactivated when I am; nor should other ports be prevented
 *       from overwriting this file." This would be useful for files like e.g.
 *       perllocal.pod (or whatever it's called; the one that causes problems).
 *
 * TODO: expose a file's mtime attribute. This should be used during port
 *       deactivation to determine if any files have local modifications. If so,
 *       they should be moved aside instead of being removed when the port is
 *       deactivated/uninstalled.
 */

/**
 * Converts a `sqlite3_stmt` into a `reg_entry`. The first column of the stmt's
 * row must be the id of an entry; the second either `SQLITE_NULL` or the
 * address of the entry in memory.
 *
 * @param [in] userdata sqlite3 database
 * @param [out] entry   entry described by `stmt`
 * @param [in] stmt     `sqlite3_stmt` with appropriate columns
 * @param [out] errPtr  unused
 * @return              true if success; false if failure
 */
static int reg_stmt_to_entry(void* userdata, void** entry, void* stmt,
        void* calldata UNUSED, reg_error* errPtr UNUSED) {
    int is_new;
    reg_registry* reg = (reg_registry*)userdata;
    sqlite_int64 id = sqlite3_column_int64(stmt, 0);
    Tcl_HashEntry* hash = Tcl_CreateHashEntry(&reg->open_entries,
            (const char*)&id, &is_new);
    if (is_new) {
        reg_entry* e = malloc(sizeof(reg_entry));
        if (!e) {
            return 0;
        }
        e->reg = reg;
        e->id = id;
        e->proc = NULL;
        *entry = e;
        Tcl_SetHashValue(hash, e);
    } else {
        *entry = Tcl_GetHashValue(hash);
    }
    return 1;
}

/**
 * Creates a new entry in the ports registry. Unlike the old
 * `registry::new_entry`, revision, variants, and epoch are all required. That's
 * OK because there's only one place this function is called, and it's called
 * with all of them there.
 *
 * @param [in] reg      the registry to create the entry in
 * @param [in] name     name of port
 * @param [in] version  version of port
 * @param [in] revision revision of port
 * @param [in] variants variants to record
 * @param [in] epoch    epoch of port
 * @param [out] errPtr  on error, a description of the error that occurred
 * @return              the entry if success; NULL if failure
 */
reg_entry* reg_entry_create(reg_registry* reg, char* name, char* version,
        char* revision, char* variants, char* epoch, reg_error* errPtr) {
    sqlite3_stmt* stmt = NULL;
    reg_entry* entry = NULL;
    char* query = "INSERT INTO registry.ports "
        "(name, version, revision, variants, epoch) VALUES (?, ?, ?, ?, ?)";
    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
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
        int r;
        Tcl_HashEntry* hash;
        int is_new;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_DONE:
                    entry = malloc(sizeof(reg_entry));
                    if (entry) {
                        entry->id = sqlite3_last_insert_rowid(reg->db);
                        entry->reg = reg;
                        entry->proc = NULL;
                        hash = Tcl_CreateHashEntry(&reg->open_entries,
                                (const char*)&entry->id, &is_new);
                        Tcl_SetHashValue(hash, entry);
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
    return entry;
}

/**
 * Opens an existing entry in the registry.
 *
 * @param [in] reg      registry to open entry in
 * @param [in] name     name of port
 * @param [in] version  version of port
 * @param [in] revision revision of port
 * @param [in] variants variants to record
 * @param [in] epoch    epoch of port
 * @param [out] errPtr  on error, a description of the error that occurred
 * @return              the entry if success; NULL if failure
 */
reg_entry* reg_entry_open(reg_registry* reg, char* name, char* version,
        char* revision, char* variants, char* epoch, reg_error* errPtr) {
    sqlite3_stmt* stmt = NULL;
    reg_entry* entry = NULL;
    int lower_bound = 0;
    char* query;
    if (strlen(epoch) > 0) {
        query = "SELECT id FROM registry.ports "
#if MP_SQLITE_VERSION >= 3006004
                "INDEXED BY port_name "
#endif
                "WHERE name=? AND version=? AND revision=? AND variants=? AND epoch=?";
    } else {
        query = "SELECT id FROM registry.ports "
#if MP_SQLITE_VERSION >= 3006004
                "INDEXED BY port_name "
#endif
                "WHERE name=? AND version=? AND revision=? AND variants=? AND epoch!=?";
    }
    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
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
        int r;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:
                    reg_stmt_to_entry(reg, (void**)&entry, stmt, &lower_bound, errPtr);
                    break;
                case SQLITE_DONE:
                    errPtr->code = REG_NOT_FOUND;
                    errPtr->description = sqlite3_mprintf("no matching port found for: " \
                            "name=%s, version=%s, revision=%s, variants=%s, epoch=%s", \
                            name, version, revision, variants, epoch);
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
    return entry;
}

/**
 * Deletes an entry. After calling this, `reg_entry_free` needs to be called
 * manually on the entry. Care should be taken to not free the entry if this
 * deletion is rolled back.
 *
 * @param [in] entry   the entry to delete
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_entry_delete(reg_entry* entry, reg_error* errPtr) {
    reg_registry* reg = entry->reg;
    int result = 0;

    errPtr->code = REG_SQLITE_ERROR;
    errPtr->description = "an unknown sqlite error occurred";
    errPtr->free = NULL;

    sqlite3_stmt* ports = NULL;
    sqlite3_stmt* files = NULL;
    sqlite3_stmt* dependencies = NULL;
    sqlite3_stmt* portgroups = NULL;
    char* ports_query = "DELETE FROM registry.ports WHERE id=?";
    char* files_query = "DELETE FROM registry.files WHERE id=?";
    char* dependencies_query = "DELETE FROM registry.dependencies WHERE id=?";
    char* portgroups_query = "DELETE FROM registry.portgroups WHERE id=?";
    if ((sqlite3_prepare_v2(reg->db, ports_query, -1, &ports, NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(ports, 1, entry->id) == SQLITE_OK)
            && (sqlite3_prepare_v2(reg->db, files_query, -1, &files, NULL)
                == SQLITE_OK)
            && (sqlite3_bind_int64(files, 1, entry->id) == SQLITE_OK)
            && (sqlite3_prepare_v2(reg->db, dependencies_query, -1, &dependencies,
                    NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(dependencies, 1, entry->id) == SQLITE_OK)
            && (sqlite3_prepare_v2(reg->db, portgroups_query, -1, &portgroups,
                    NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(portgroups, 1, entry->id) == SQLITE_OK)) {
        int r;
        do {
            r = sqlite3_step(ports);
            switch (r) {
                case SQLITE_DONE:
                    if (sqlite3_changes(reg->db) > 0) {
                        do {
                            r = sqlite3_step(files);
                            switch (r) {
                                case SQLITE_DONE:
                                    do {
                                        r = sqlite3_step(dependencies);
                                        switch (r) {
                                            case SQLITE_DONE:
                                                do {
                                                    r = sqlite3_step(portgroups);
                                                    switch (r) {
                                                        case SQLITE_DONE:
                                                            result = 1;
                                                            break;
                                                        case SQLITE_BUSY:
                                                            break;
                                                        case SQLITE_ERROR:
                                                        default:
                                                            reg_sqlite_error(reg->db,
                                                                    errPtr, NULL);
                                                            break;
                                                    }
                                                } while (r == SQLITE_BUSY);
                                                break;
                                            case SQLITE_BUSY:
                                                break;
                                            case SQLITE_ERROR:
                                            default:
                                                reg_sqlite_error(reg->db,
                                                        errPtr, NULL);
                                                break;
                                        }
                                    } while (r == SQLITE_BUSY);
                                    break;
                                case SQLITE_BUSY:
                                    break;
                                case SQLITE_ERROR:
                                default:
                                    reg_sqlite_error(reg->db, errPtr, NULL);
                                    break;
                            }
                        } while (r == SQLITE_BUSY);
                        break;
                    } else {
                        errPtr->code = REG_INVALID;
                        errPtr->description = "an invalid entry was passed";
                        errPtr->free = NULL;
                    }
                    break;
                case SQLITE_BUSY:
                    break;
                case SQLITE_ERROR:
                default:
                    reg_sqlite_error(reg->db, errPtr, NULL);
                    break;
            }
        } while (r == SQLITE_BUSY);
    } else {
        reg_sqlite_error(reg->db, errPtr, NULL);
    }
    if (ports) {
        sqlite3_finalize(ports);
    }
    if (files) {
        sqlite3_finalize(files);
    }
    if (dependencies) {
        sqlite3_finalize(dependencies);
    }
    if (portgroups) {
        sqlite3_finalize(portgroups);
    }
    return result;
}

/**
 * Frees an entry. Normally this is unnecessary, as open entries will be
 * automatically freed when the registry is detached. Calling this method
 * externally should only be necessary following `reg_entry_delete`.
 *
 * @param [in] entry the entry to free
 */
void reg_entry_free(reg_entry* entry) {
    Tcl_HashEntry* hash = Tcl_FindHashEntry(&entry->reg->open_entries,
                            (const char*)&entry->id);
    Tcl_DeleteHashEntry(hash);
    if (entry->proc != NULL) {
        free(entry->proc);
    }
    free(entry);
}

/**
 * Type-safe version of `reg_all_objects` for `reg_entry`.
 *
 * @param [in] reg       registry to select entries from
 * @param [in] query     the select query to execute
 * @param [in] query_len length of the query (or -1 for automatic)
 * @param [out] objects  the entries selected
 * @param [out] errPtr   on error, a description of the error that occurred
 * @return               the number of entries if success; negative if failure
 */
static int reg_all_entries(reg_registry* reg, char* query, int query_len,
        reg_entry*** objects, reg_error* errPtr) {
    int lower_bound = 0;
    return reg_all_objects(reg, query, query_len, (void***)objects,
            reg_stmt_to_entry, &lower_bound, NULL, errPtr);
}

/**
 * Searches the registry for ports for which each key's value is equal to the
 * given value. To find all ports, pass a key_count of 0.
 *
 * Bad keys should cause sqlite3 errors but not permit SQL injection attacks.
 * Pass it good keys anyway.
 *
 * @param [in] reg       registry to search in
 * @param [in] keys      a list of keys to search by
 * @param [in] vals      a list of values to search by, matching keys
 * @param [in] key_count the number of key/value pairs passed
 * @param [in] strategies  strategies to use (one of the `reg_strategy_*` constants)
 * @param [out] entries  a list of matching entries
 * @param [out] errPtr   on error, a description of the error that occurred
 * @return               the number of entries if success; false if failure
 */
int reg_entry_search(reg_registry* reg, const char** keys, const char** vals,
        int key_count, int *strategies, reg_entry*** entries, reg_error* errPtr) {
    int i;
    char* kwd = " WHERE ";
    char* query;
    size_t query_len, query_space;
    int result;
    char* op;
    /* build the query */
    query = strdup("SELECT id FROM registry.ports");
    if (!query) {
        return -1;
    }
    query_len = query_space = strlen(query);
    for (i=0; i<key_count; i++) {
        /* get the strategy */
        op = reg_strategy_op(strategies[i], errPtr);
        if (op == NULL) {
            free(query);
            return -1;
        }
        char* cond = sqlite3_mprintf(op, keys[i], vals[i]);
        if (!cond || !reg_strcat(&query, &query_len, &query_space, kwd)
            || !reg_strcat(&query, &query_len, &query_space, cond)) {
            free(query);
            return -1;
        }
        sqlite3_free(cond);
        kwd = " AND ";
    }
    /* do the query */
    result = reg_all_entries(reg, query, -1, entries, errPtr);
    free(query);
    return result;
}

/**
 * Finds ports which are installed as an image, and/or those which are active
 * in the filesystem. When the install mode is 'direct', this will be equivalent
 * to `reg_entry_installed`.
 *
 * Note that the name is a bit of a misnomer, since you can install a port with
 * installtype direct and it will still be in this list. It's really "imaged or
 * installed" but that's usually redundant and too long to type.
 *
 * @param [in] reg      registry object as created by `registry_open`
 * @param [in] name     specific port to find (NULL for any)
 * @param [in] version  specific version to find (NULL for any)
 * @param [out] entries list of ports meeting the criteria
 * @param [out] errPtr  description of error encountered, if any
 * @return              the number of entries if success; false if failure
 */
int reg_entry_imaged(reg_registry* reg, const char* name, const char* version,
        const char* revision, const char* variants, reg_entry*** entries,
        reg_error* errPtr) {
    char* query;
    int result;
    char* empty = "";
    char* name_clause = empty;
    char* version_clause = empty;
    char* revision_clause = empty;
    char* variants_clause = empty;
    if (name != NULL) {
        name_clause = sqlite3_mprintf(" AND name='%q'", name);
    }
    if (version != NULL) {
        version_clause = sqlite3_mprintf(" AND version='%q'", version);
    }
    if (revision != NULL) {
        revision_clause = sqlite3_mprintf(" AND revision='%q'", revision);
    }
    if (variants != NULL) {
        variants_clause = sqlite3_mprintf(" AND variants='%q'", variants);
    }
    query = sqlite3_mprintf("SELECT id FROM ports WHERE (state='imaged' OR "
            "state='installed')%s%s%s%s", name_clause,
            version_clause, revision_clause, variants_clause);
    result = reg_all_entries(reg, query, -1, entries, errPtr);
    sqlite3_free(query);
    if (name_clause != empty) sqlite3_free(name_clause);
    if (version_clause != empty) sqlite3_free(version_clause);
    if (revision_clause != empty) sqlite3_free(revision_clause);
    if (variants_clause != empty) sqlite3_free(variants_clause);
    return result;
}

/**
 * Finds ports which are active in the filesystem. These ports are able to meet
 * dependencies, and properly own the files they map.
 * @todo add more arguments (epoch, revision, variants), maybe
 *
 * @param [in] reg      registry object as created by `registry_open`
 * @param [in] name     specific port to find (NULL for any)
 * @param [out] entries list of ports meeting the criteria
 * @param [out] errPtr  description of error encountered, if any
 * @return              the number of entries if success; false if failure
 */
int reg_entry_installed(reg_registry* reg, char* name, reg_entry*** entries,
        reg_error* errPtr) {
    char* format;
    char* query;
    int result;
    char* select = "SELECT id FROM registry.ports";
    if (name == NULL) {
        format = "%s WHERE state='installed'";
    } else {
        format = "%s "
#if MP_SQLITE_VERSION >= 3006004
                "INDEXED BY port_name "
#endif
                "WHERE state='installed' AND name='%q'";
    }
    query = sqlite3_mprintf(format, select, name);
    result = reg_all_entries(reg, query, -1, entries, errPtr);
    sqlite3_free(query);
    return result;
}

/**
 * Finds the owner of a given file. Only ports active in the filesystem will be
 * returned.
 *
 * @param [in] reg     registry to search in
 * @param [in] path    path of the file to check ownership of
 * @param [in] cs      false if check should be performed case-insensitive,
 *                     true otherwise
 * @param [out] entry  the owner, or NULL if no active port owns the file
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_entry_owner(reg_registry* reg, char* path, int cs, reg_entry** entry,
        reg_error* errPtr) {
    int result = 0;
    sqlite3_stmt* stmt = NULL;
    int lower_bound = 0;
    char *query = NULL;

    asprintf(&query, "SELECT id FROM registry.files %s WHERE (actual_path = ? %s) AND active",
#if MP_SQLITE_VERSION >= 3003013
#if MP_SQLITE_VERSION >= 3006004
             cs ? "INDEXED BY file_actual" : "INDEXED BY file_actual_nocase",
#else
             "",
#endif
             cs ? "" : "COLLATE NOCASE");
#else
             "", "");
#endif

    if (!query) {
        return 0;
    }

    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 1, path, -1, SQLITE_STATIC)
                == SQLITE_OK)) {
        int r;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:
                    result = reg_stmt_to_entry(reg, (void**)entry, stmt,
                            &lower_bound, errPtr);
                    break;
                case SQLITE_DONE:
                    *entry = NULL;
                    result = 1;
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
    free(query);
    return result;
}

/**
 * Shortcut to retrieve a file's owner's id directly. This should be a bit
 * faster than `reg_entry_owner` because it doesn't have to check the hash table
 * of open entries. It might still be slower than necessary because it's doing
 * a join of two tables, but the only way to improve that would be to cache a
 * file's active state in registry.files itself, which I'd rather not do unless
 * absolutely necessary.
 *
 * @param [in] reg  registry to find file in
 * @param [in] path path of file to get owner of
 * @param [in] cs   false if check should be performed case-insensitive,
 *                  true otherwise
 * @return          id of owner, or 0 for none
 */
sqlite_int64 reg_entry_owner_id(reg_registry* reg, char* path, int cs) {
    sqlite3_stmt* stmt = NULL;
    sqlite_int64 result = 0;
    char *query = NULL;

    asprintf(&query, "SELECT id FROM registry.files %s WHERE (actual_path = ? %s) AND active",
#if MP_SQLITE_VERSION >= 3003013
#if MP_SQLITE_VERSION >= 3006004
             cs ? "INDEXED BY file_actual" : "INDEXED BY file_actual_nocase",
#else
             "",
#endif
             cs ? "" : "COLLATE NOCASE");
#else
             "", "");
#endif

    if (!query) {
        return 0;
    }

    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 1, path, -1, SQLITE_STATIC)
                == SQLITE_OK)) {
        int r;
        do {
            r = sqlite3_step(stmt);
            if (r == SQLITE_ROW) {
                result = sqlite3_column_int64(stmt, 0);
            }
        } while (r == SQLITE_BUSY);
    }
    if (stmt) {
        sqlite3_finalize(stmt);
    }
    free(query);
    return result;
}

/**
 * Gets a named property of an entry. That property can be set using
 * `reg_entry_propset`. The property named must be one that exists in the table
 * and must not be one with internal meaning such as `id` or `state`.
 *
 * @param [in] entry   entry to get property from
 * @param [in] key     property to get
 * @param [out] value  the value of the property
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_entry_propget(reg_entry* entry, char* key, char** value,
        reg_error* errPtr) {
    reg_registry* reg = entry->reg;
    int result = 0;
    sqlite3_stmt* stmt = NULL;
    char* query;
    const char *text;
    query = sqlite3_mprintf("SELECT %q FROM registry.ports WHERE id=%lld", key,
            entry->id);
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
                    errPtr->description = "an invalid entry was passed";
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
 * Sets a named property of an entry. That property can be later retrieved using
 * `reg_entry_propget`. The property named must be one that exists in the table
 * and must not be one with internal meaning such as `id` or `state`. If `name`,
 * `epoch`, `version`, `revision`, or `variants` is set, it could trigger a
 * conflict if another port with the same combination of values for those
 * columns exists.
 *
 * @param [in] entry   entry to set property for
 * @param [in] key     property to set
 * @param [in] value   the desired value of the property
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_entry_propset(reg_entry* entry, char* key, char* value,
        reg_error* errPtr) {
    reg_registry* reg = entry->reg;
    int result = 0;
    sqlite3_stmt* stmt = NULL;
    char* query;
    query = sqlite3_mprintf("UPDATE registry.ports SET %q = '%q' WHERE id=%lld",
            key, value, entry->id);
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
 * Associates a portgroup with given port.
 *
 * @param [in] entry      the entry to map the portgroup to
 * @param [in] name       the portgroup name (e.g. "muniversal")
 * @param [in] version    the portgroup version (e.g. "1.0")
 * @param [in] sha256     the sha256 hash of the portgroup file
 * @param [in] size       the size of the portgroup file in bytes
 * @param [out] errPtr    on error, a description of the error that occurred
 * @return                true if success; false if failure
 */
int reg_entry_addgroup(reg_entry* entry, char* name, char *version,
        char *sha256, sqlite_int64 size, reg_error* errPtr) {
    reg_registry* reg = entry->reg;
    int result = 1;
    sqlite3_stmt* stmt = NULL;
    char* insert = "INSERT INTO registry.portgroups (id, name, version, size, sha256) "
        "VALUES (?, ?, ?, ?, ?)";
    if ((sqlite3_prepare_v2(reg->db, insert, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(stmt, 1, entry->id) == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 2, name, -1, SQLITE_STATIC) == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 3, version, -1, SQLITE_STATIC) == SQLITE_OK)
            && (sqlite3_bind_int64(stmt, 4, size) == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 5, sha256, -1, SQLITE_STATIC) == SQLITE_OK)) {
        int r;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_DONE:
                    sqlite3_reset(stmt);
                    break;
                case SQLITE_BUSY:
                    break;
                default:
                    reg_sqlite_error(reg->db, errPtr, insert);
                    result = 0;
                    break;
            }
        } while (r == SQLITE_BUSY);
    } else {
        reg_sqlite_error(reg->db, errPtr, insert);
        result = 0;
    }
    if (stmt) {
        sqlite3_finalize(stmt);
    }
    return result;
}

/**
 * Gets a list of portgroups that are used by this port.
 *
 * @param [in] entry       a port
 * @param [out] portgroups a list of portgroups used by the given port
 * @param [out] errPtr     on error, a description of the error that occurred
 * @return                 true if success; false if failure
 */
int reg_entry_getgroups(reg_entry* entry, reg_portgroup*** portgroups, reg_error* errPtr) {
    reg_registry* reg = entry->reg;
    char* query = sqlite3_mprintf("SELECT ROWID FROM portgroups "
            "WHERE id=%lld",
            entry->id);
    int result = reg_all_portgroups(reg, query, -1, portgroups, errPtr);
    sqlite3_free(query);
    return result;
}

/**
 * Maps files to the given port in the filemap. The list of files must not
 * contain files that are already mapped to the given port.
 *
 * @param [in] entry      the entry to map the files to
 * @param [in] files      a list of files to map
 * @param [in] file_count the number of files
 * @param [out] errPtr    on error, a description of the error that occurred
 * @return                true if success; false if failure
 */
int reg_entry_map(reg_entry* entry, char** files, int file_count,
        reg_error* errPtr) {
    reg_registry* reg = entry->reg;
    int result = 1;
    sqlite3_stmt* stmt = NULL;
    char* insert = "INSERT INTO registry.files (id, path, active) "
        "VALUES (?, ?, 0)";
    if ((sqlite3_prepare_v2(reg->db, insert, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(stmt, 1, entry->id) == SQLITE_OK)) {
        int i;
        for (i=0; i<file_count && result; i++) {
            if (sqlite3_bind_text(stmt, 2, files[i], -1, SQLITE_STATIC)
                    == SQLITE_OK) {
                int r;
                do {
                    r = sqlite3_step(stmt);
                    switch (r) {
                        case SQLITE_DONE:
                            sqlite3_reset(stmt);
                            break;
                        case SQLITE_BUSY:
                            break;
                        default:
                            reg_sqlite_error(reg->db, errPtr, insert);
                            result = 0;
                            break;
                    }
                } while (r == SQLITE_BUSY);
            } else {
                reg_sqlite_error(reg->db, errPtr, insert);
                result = 0;
            }
        }
    } else {
        reg_sqlite_error(reg->db, errPtr, insert);
        result = 0;
    }
    if (stmt) {
        sqlite3_finalize(stmt);
    }
    return result;
}

/**
 * Unmaps files from the given port in the filemap. The files must be owned by
 * the given entry.
 *
 * @param [in] entry      the entry to unmap the files from
 * @param [in] files      a list of files to unmap
 * @param [in] file_count the number of files
 * @param [out] errPtr    on error, a description of the error that occurred
 * @return                true if success; false if failure
 */
int reg_entry_unmap(reg_entry* entry, char** files, int file_count,
        reg_error* errPtr) {
    reg_registry* reg = entry->reg;
    int result = 1;
    sqlite3_stmt* stmt = NULL;
    char* query = "DELETE FROM registry.files "
#if MP_SQLITE_VERSION >= 3006004
                  "INDEXED BY file_path "
#endif
                  "WHERE path=? AND id=?";
    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(stmt, 2, entry->id) == SQLITE_OK)) {
        int i;
        for (i=0; i<file_count && result; i++) {
            if (sqlite3_bind_text(stmt, 1, files[i], -1, SQLITE_STATIC)
                    == SQLITE_OK) {
                int r;
                do {
                    r = sqlite3_step(stmt);
                    switch (r) {
                        case SQLITE_DONE:
                            if (sqlite3_changes(reg->db) == 0) {
                                reg_throw(errPtr, REG_INVALID, "%s is not "
                                        "owned by this entry", files[i]);
                                result = 0;
                            } else {
                                sqlite3_reset(stmt);
                            }
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
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
        result = 0;
    }
    if (stmt) {
        sqlite3_finalize(stmt);
    }
    return result;
}

/**
 * Gets a list of files provided by the given port. These files are in the port
 * image and do not necessarily correspond to active files on the filesystem.
 *
 * TODO: check that the port's installtype is image
 *
 * @param [in] entry   entry to get the list for
 * @param [out] files  a list of files provided by the port
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             the number of files if success; negative if failure
 */
int reg_entry_imagefiles(reg_entry* entry, char*** files, reg_error* errPtr) {
    reg_registry* reg = entry->reg;
    sqlite3_stmt* stmt = NULL;
    char* query = "SELECT path FROM registry.files WHERE id=? ORDER BY path";
    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(stmt, 1, entry->id) == SQLITE_OK)) {
        char** result = malloc(10*sizeof(char*));
        int result_count = 0;
        int result_space = 10;
        int r;
        const char *text;
        char* element;
        if (!result) {
            return -1;
        }
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:
                    text = (const char*)sqlite3_column_text(stmt, 0);
                    if (text) {
                        element = strdup(text);
                        if (!element || !reg_listcat((void***)&result, &result_count, &result_space, element)) {
                            r = SQLITE_ERROR;
                        }
                    }
                    break;
                case SQLITE_DONE:
                case SQLITE_BUSY:
                    break;
                default:
                    reg_sqlite_error(reg->db, errPtr, query);
                    break;
            }
        } while (r == SQLITE_ROW || r == SQLITE_BUSY);
        sqlite3_finalize(stmt);
        if (r == SQLITE_DONE) {
            *files = result;
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
        return -1;
    }
}

/**
 * Gets a list of files owned by the given port. These files are active in the
 * filesystem and could be different from the port's imagefiles.
 *
 * TODO: check that the port is active
 *
 * @param [in] entry   entry to get the list for
 * @param [out] files  a list of files owned by the port
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             the number of files if success; negative if failure
 */
int reg_entry_files(reg_entry* entry, char*** files, reg_error* errPtr) {
    reg_registry* reg = entry->reg;
    sqlite3_stmt* stmt = NULL;
    char* query = "SELECT actual_path FROM registry.files WHERE id=? "
        "AND active ORDER BY actual_path";
    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(stmt, 1, entry->id) == SQLITE_OK)) {
        char** result = malloc(10*sizeof(char*));
        int result_count = 0;
        int result_space = 10;
        int r;
        const char *text;
        char* element;
        if (!result) {
            return -1;
        }
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_ROW:
                    text = (const char*)sqlite3_column_text(stmt, 0);
                    if (text) {
                        element = strdup(text);
                        if (!element || !reg_listcat((void***)&result, &result_count, &result_space, element)) {
                            r = SQLITE_ERROR;
                        }
                    }
                    break;
                case SQLITE_DONE:
                case SQLITE_BUSY:
                    break;
                default:
                    reg_sqlite_error(reg->db, errPtr, query);
                    break;
            }
        } while (r == SQLITE_ROW || r == SQLITE_BUSY);
        sqlite3_finalize(stmt);
        if (r == SQLITE_DONE) {
            *files = result;
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
        return -1;
    }
}

/**
 * Sets an entry's files as being active in the filesystem. This entry will be
 * subsequently returned by `reg_entry_owner` on those files' path. If all files
 * are being activated as the names they are in the registry, then `as_files`
 * may be NULL. If they are being activated to different paths than the original
 * files, then `as_files` should be a list of the same length as `files`.
 *
 * @param [in] entry      entry to assign the file to
 * @param [in] files      a list of files to activate
 * @param [in] as_files   NULL, or a list of paths the files are activated as
 * @param [in] file_count number of files to activate
 * @param [out] errPtr    on error, a description of the error that occurred
 * @return                true if success; false if failure
 */
int reg_entry_activate(reg_entry* entry, char** files, char** as_files,
        int file_count, reg_error* errPtr) {
    reg_registry* reg = entry->reg;
    int result = 1;
    int i;
    sqlite3_stmt* select = NULL;
    sqlite3_stmt* update = NULL;
    char* select_query = "SELECT id FROM registry.files WHERE actual_path=? "
        "AND active";
    char* update_query = "UPDATE registry.files "
#if MP_SQLITE_VERSION >= 3006004
        /* if the version of SQLite supports it force the usage of the index on
         * path, rather than the one on id which has a lot less discriminative
         * power and leads to very slow queries. This is needed for the new
         * query planner introduced in 3.8.0 which would not use the correct
         * index automatically. */
        "INDEXED BY file_path "
#endif
        "SET actual_path=?, active=1 WHERE path=? AND id=?";

    /* if as_files wasn't specified, activate as the original files */
    if (as_files == NULL) {
        as_files = files;
    }

    if (sqlite3_prepare_v2(reg->db, select_query, -1, &select, NULL) == SQLITE_OK){
        if ((sqlite3_prepare_v2(reg->db, update_query, -1, &update, NULL)
                == SQLITE_OK)
                && (sqlite3_bind_int64(update, 3, entry->id) == SQLITE_OK)) {
            for (i=0; i<file_count && result; i++) {
                if ((sqlite3_bind_text(select, 1, as_files[i], -1, SQLITE_STATIC)
                            == SQLITE_OK)
                        && (sqlite3_bind_text(update, 1, as_files[i], -1,
                                SQLITE_STATIC) == SQLITE_OK)
                        && (sqlite3_bind_text(update, 2, files[i], -1,
                                SQLITE_STATIC) == SQLITE_OK)) {
                    int r;
                    do {
                        r = sqlite3_step(select);
                        switch (r) {
                            case SQLITE_ROW:
                                reg_throw(errPtr, REG_ALREADY_ACTIVE, "%s is "
                                        "being used by another port", files[i]);
                                result = 0;
                                break;
                            case SQLITE_DONE:
                                do {
                                    r = sqlite3_step(update);
                                    switch (r) {
                                        case SQLITE_DONE:
                                            if (sqlite3_changes(reg->db) == 0) {
                                                reg_throw(errPtr, REG_INVALID,
                                                        "%s is not provided by "
                                                        "this port", files[i]);
                                                result = 0;
                                            } else {
                                                sqlite3_reset(select);
                                                sqlite3_reset(update);
                                            }
                                            break;
                                        case SQLITE_BUSY:
                                            break;
                                        case SQLITE_ERROR:
                                        default:
                                            reg_sqlite_error(reg->db, errPtr,
                                                    update_query);
                                            result = 0;
                                            break;
                                    }
                                } while (r == SQLITE_BUSY);
                                break;
                            case SQLITE_BUSY:
                                break;
                            case SQLITE_ERROR:
                            default:
                                reg_sqlite_error(reg->db, errPtr, select_query);
                                result = 0;
                                break;
                        }
                    } while (r == SQLITE_BUSY);
                } else {
                    reg_sqlite_error(reg->db, errPtr, NULL);
                    result = 0;
                }
            }
        } else {
            reg_sqlite_error(reg->db, errPtr, update_query);
            result = 0;
        }
        if (update) {
            sqlite3_finalize(update);
        }
    } else {
        reg_sqlite_error(reg->db, errPtr, select_query);
        result = 0;
    }
    if (select) {
        sqlite3_finalize(select);
    }
    return result;
}

/**
 * Deactivates files owned by a given entry. That entry's version of all files
 * must currently be active.
 * 
 * @param [in] entry      current owner of the files
 * @param [in] files      a list of files to deactivate
 * @param [in] file_count number of files to deactivate
 * @param [out] errPtr    on error, a description of the error that occurred
 * @return                true if success; false if failure
 */
int reg_entry_deactivate(reg_entry* entry, char** files, int file_count,
        reg_error* errPtr) {
    reg_registry* reg = entry->reg;
    int result = 1;
    int i;
    sqlite3_stmt* stmt = NULL;
    char* query = "UPDATE registry.files "
#if MP_SQLITE_VERSION >= 3006004
        /* if the version of SQLite supports it force the usage of the index on
         * path, rather than the one on id which has a lot less discriminative
         * power and leads to very slow queries. This is needed for the new
         * query planner introduced in 3.8.0 which would not use the correct
         * index automatically. */
        "INDEXED BY file_actual "
#endif
        "SET active=0 WHERE actual_path=? AND id=?";
    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(stmt, 2, entry->id) == SQLITE_OK)) {
        for (i=0; i<file_count && result; i++) {
            if (sqlite3_bind_text(stmt, 1, files[i], -1, SQLITE_STATIC)
                    == SQLITE_OK) {
                int r;
                do {
                    r = sqlite3_step(stmt);
                    switch (r) {
                        case SQLITE_DONE:
                            if (sqlite3_changes(reg->db) == 0) {
                                reg_throw(errPtr, REG_INVALID, "%s is not "
                                        "owned by this entry", files[i]);
                                result = 0;
                            } else {
                                sqlite3_reset(stmt);
                            }
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
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
        result = 0;
    }
    if (stmt) {
        sqlite3_finalize(stmt);
    }
    return result;
}

/**
 * Gets a list of ports that depend on this one. Uninstalling the given port
 * could potentially break any port listed in its dependents, and could not
 * break any other.
 *
 * @param [in] entry       a port
 * @param [out] dependents a list of ports dependent on the given port
 * @param [out] errPtr     on error, a description of the error that occurred
 * @return                 true if success; false if failure
 */
int reg_entry_dependents(reg_entry* entry, reg_entry*** dependents,
        reg_error* errPtr) {
    reg_registry* reg = entry->reg;
    char* query = sqlite3_mprintf("SELECT dependencies.id FROM ports port "
            "INNER JOIN dependencies USING(name) INNER JOIN ports dependent "
            "USING(id) WHERE port.id=%lld ORDER BY dependent.name,"
            "dependent.epoch, dependent.version, dependent.revision,"
            "dependent.variants",
            entry->id);
    int result = reg_all_entries(reg, query, -1, dependents, errPtr);
    sqlite3_free(query);
    return result;
}

/**
 * Gets a list of ports that this one depends on. This only returns ports which
 * have state "installed" and should really only be called upon ports which have
 * state "installed" themselves. Uninstalling any port in this list could break
 * the given port, but uninstalling any other could not break it.
 *
 * @param [in] entry         a port
 * @param [out] dependencies a list of ports the given port depends on
 * @param [out] errPtr       on error, a description of the error that occurred
 * @return                   number of deps if success; negative if failure
 */
int reg_entry_dependencies(reg_entry* entry, reg_entry*** dependencies,
        reg_error* errPtr) {
    reg_registry* reg = entry->reg;
    char* query = sqlite3_mprintf("SELECT ports.id FROM registry.dependencies "
        "INNER JOIN registry.ports USING(name) WHERE dependencies.id=%lld",
        entry->id);
    int result = reg_all_entries(reg, query, -1, dependencies, errPtr);
    sqlite3_free(query);
    return result;
}

/**
 * Sets the given port to depend on the named port. This is a weak link; it
 * refers to a name and not an actual port.
 *
 * @param [in] entry   a port
 * @param [in] name    the name of a port the given port depends on
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_entry_depends(reg_entry* entry, char* name, reg_error* errPtr) {
    reg_registry* reg = entry->reg;
    int result = 0;
    sqlite3_stmt* stmt = NULL;
    char* query = "INSERT INTO registry.dependencies (id, name) VALUES (?,?)";
    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_int64(stmt, 1, entry->id) == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 2, name, -1, SQLITE_STATIC)
                == SQLITE_OK)) {
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
    return result;
}

/**
 * Fetches a list of all open entries.
 *
 * @param [in] reg      registry to fetch entries from
 * @param [out] entries a list of open entries
 * @return              the number of open entries, -1 on error
 */
int reg_all_open_entries(reg_registry* reg, reg_entry*** entries) {
    reg_entry* entry;
    int entry_count = 0;
    int entry_space = 10;
    Tcl_HashEntry* hash;
    Tcl_HashSearch search;
    *entries = malloc(entry_space * sizeof(reg_entry*));
    if (!*entries) {
        return -1;
    }
    for (hash = Tcl_FirstHashEntry(&reg->open_entries, &search); hash != NULL;
            hash = Tcl_NextHashEntry(&search)) {
        entry = Tcl_GetHashValue(hash);
        if (!reg_listcat((void***)entries, &entry_count, &entry_space, entry)) {
            free(*entries);
            return -1;
        }
    }
    return entry_count;
}

