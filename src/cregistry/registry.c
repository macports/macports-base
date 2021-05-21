/*
 * registry.c
 * vim:expandtab:tw=80
 *
 * Copyright (c) 2007 Chris Pickel <sfiera@macports.org>
 * Copyright (c) 2012, 2014 The MacPorts Project
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
#include "entry.h"
#include "file.h"
#include "sql.h"

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <libgen.h>
#include <string.h>
#include <stdarg.h>
#include <sqlite3.h>
#include <sys/stat.h>
#include <errno.h>

/*
 * TODO: maybe all the errPtrs could be made a property of `reg_registry`
 *       instead, and be destroyed with it? That would make memory-management
 *       much easier for errors, and there's no need to have more than one error
 *       alive at any given time.
 */

/*
 * Error constants. Those need to be constants and cannot be string literals
 * because we'll use address comparisons for those and compilers don't have to
 * guarantee string literals always have the same address (they don't have to
 * guarantee string literals will have an address at all, so comparing the
 * address of a string with a string literal is undefined behavior).
 */
char *const registry_err_not_found      = "registry::not-found";
char *const registry_err_invalid        = "registry::invalid";
char *const registry_err_constraint     = "registry::constraint";
char *const registry_err_sqlite_error   = "registry::sqlite-error";
char *const registry_err_misuse         = "registry::misuse";
char *const registry_err_cannot_init    = "registry::cannot-init";
char *const registry_err_already_active = "registry::already-active";

/**
 * Destroys a `reg_error` object. This should be called on any reg_error when a
 * registry function returns a failure condition; depending on the function,
 * failure could be false, negative, or null.
 *
 * @param [in] errPtr the error to destroy
 */
void reg_error_destruct(reg_error* errPtr) {
    if (errPtr->free) {
        errPtr->free(errPtr->description);
    }
}

/**
 * Sets `errPtr` according to the last error in `db`. Convenience function for
 * internal use only. Sets the error code to REG_SQLITE_ERROR and sets an
 * appropriate error description (including a query if non-NULL).
 *
 * @param [in] db      sqlite3 database connection which had the error
 * @param [out] errPtr an error to write to
 * @param [in] query   the query that this error occurred during
 */
void reg_sqlite_error(sqlite3* db, reg_error* errPtr, char* query) {
    errPtr->code = REG_SQLITE_ERROR;
    errPtr->free = (reg_error_destructor*)sqlite3_free;
    if (query == NULL) {
        errPtr->description = sqlite3_mprintf("sqlite error: %s (%d)",
                sqlite3_errmsg(db), sqlite3_errcode(db));
    } else {
        errPtr->description = sqlite3_mprintf("sqlite error: %s (%d) while "
                "executing query: %s", sqlite3_errmsg(db), sqlite3_errcode(db),
                query);
    }
}

void reg_throw(reg_error* errPtr, char* code, char* fmt, ...) {
    va_list list;
    va_start(list, fmt);
    errPtr->description = sqlite3_vmprintf(fmt, list);
    va_end(list);

    errPtr->code = code;
    errPtr->free = (reg_error_destructor*)sqlite3_free;
}

/**
 * Creates a new registry object. To start using a registry, one must first be
 * attached with `reg_attach`.
 *
 * @param [out] regPtr address of the allocated registry
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_open(reg_registry** regPtr, reg_error* errPtr) {
    reg_registry* reg = malloc(sizeof(reg_registry));
    if (!reg) {
        return 0;
    }
    if (sqlite3_open(NULL, &reg->db) == SQLITE_OK) {
        /* Enable extended result codes, requires SQLite >= 3.3.8
         * Check added for compatibility with Tiger. */
#if SQLITE_VERSION_NUMBER >= 3003008
        if (sqlite3_libversion_number() >= 3003008) {
            sqlite3_extended_result_codes(reg->db, 1);
        }
#endif

        sqlite3_busy_timeout(reg->db, 25);

        if (init_db(reg->db, errPtr)) {
            reg->status = reg_none;
            *regPtr = reg;
            return 1;
        }
    } else {
        reg_sqlite_error(reg->db, errPtr, NULL);
    }
    sqlite3_close(reg->db);
    free(reg);
    return 0;
}

/**
 * Closes a registry object. Will detach if necessary.
 *
 * @param [in] reg     the registry to close
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_close(reg_registry* reg, reg_error* errPtr) {
    if ((reg->status & reg_attached) && !reg_detach(reg, errPtr)) {
        return 0;
    }
    if (sqlite3_close(reg->db) == SQLITE_OK) {
        free(reg);
        return 1;
    } else {
        reg_throw(errPtr, REG_SQLITE_ERROR, "registry db not closed correctly "
                "(%s)\n", sqlite3_errmsg(reg->db));
        return 0;
    }
}

/**
 * Do some initial configuration of a registry object.
 *
 * @param [in] reg     the registry to configure
 * @return             true if success; false if failure
 */
int reg_configure(reg_registry* reg) {
    sqlite3_stmt* stmt = NULL;
    int result = 0;
#if SQLITE_VERSION_NUMBER >= 3022000
    /* Ensure WAL files persist. */
    if (sqlite3_libversion_number() >= 3022000) {
        int persist = 1;
        sqlite3_file_control(reg->db, "registry", SQLITE_FCNTL_PERSIST_WAL, &persist);
    }
#endif
    /* Turn on fullfsync. */
    if (sqlite3_prepare_v2(reg->db, "PRAGMA fullfsync = 1", -1, &stmt, NULL) == SQLITE_OK) {
        int r;
        do {
            sqlite3_step(stmt);
            r = sqlite3_reset(stmt);
            if (r == SQLITE_OK) {
                result = 1;
            }
        } while (r == SQLITE_BUSY);
    }
    if (stmt) {
        sqlite3_finalize(stmt);
    }
    return result;
}

/**
 * Attaches a registry database to the registry object. Prior to calling this,
 * the registry object is not actually connected to the registry. This function
 * attaches it so it can be queried and manipulated.
 *
 * @param [in] reg     the registry to attach to
 * @param [in] path    path to the registry db on disk
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_attach(reg_registry* reg, const char* path, reg_error* errPtr) {
    struct stat sb;
    int initialized = 1; /* registry already exists */
    int can_write = 1; /* can write to this location */
    int result = 0;
    if (reg->status & reg_attached) {
        reg_throw(errPtr, REG_MISUSE, "a database is already attached to this "
                "registry");
        return 0;
    }
    if (stat(path, &sb) != 0) {
        initialized = 0;
        if (errno == ENOENT) {
            char *dirc, *dname;
            dirc = strdup(path);
            dname = dirname(dirc);
            if (stat(dname, &sb) != 0) {
                can_write = 0;
            }
            free(dirc);
        } else {
            can_write = 0;
        }
    }
    /* can_write is still true if one of the stat calls succeeded */
    if (initialized || can_write) {
        sqlite3_stmt* stmt = NULL;
        char* query = sqlite3_mprintf("ATTACH DATABASE '%q' AS registry", path);
        int r;
        do {
            r = sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL);
        } while (r == SQLITE_BUSY);
        if (r == SQLITE_OK) {
            /* XXX: Busy waiting, consider using sqlite3_busy_handler/timeout */
            do {
                sqlite3_step(stmt);
                r = sqlite3_reset(stmt);
                switch (r) {
                    case SQLITE_OK:
                        if (initialized || (create_tables(reg->db, errPtr))) {
                            Tcl_InitHashTable(&reg->open_entries,
                                    sizeof(sqlite_int64)/sizeof(int));
                            Tcl_InitHashTable(&reg->open_files,
                                    TCL_STRING_KEYS);
                            Tcl_InitHashTable(&reg->open_portgroups,
                                    sizeof(sqlite_int64)/sizeof(int));
                            reg->status |= reg_attached;
                            result = 1;
                        }
                        break;
                    case SQLITE_BUSY:
                        break;
                    default:
                        reg_sqlite_error(reg->db, errPtr, query);
                }
            } while (r == SQLITE_BUSY);

            sqlite3_finalize(stmt);
            stmt = NULL;

            if (result) {
                result &= update_db(reg->db, errPtr);
            }
        } else {
            reg_sqlite_error(reg->db, errPtr, query);
        }
        if (stmt) {
            sqlite3_finalize(stmt);
        }
        sqlite3_free(query);
    } else {
        reg_throw(errPtr, REG_CANNOT_INIT, "port registry doesn't exist at "
                "\"%q\" and couldn't write to this location", path);
    }
    return result;
}

/**
 * Detaches a registry database from the registry object. This does some cleanup
 * for an attached registry, then detaches it. Allocated `reg_entry` objects are
 * deleted here.
 *
 * @param [in] reg     registry to detach from
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_detach(reg_registry* reg, reg_error* errPtr) {
    sqlite3_stmt* stmt = NULL;
    int result = 0;
    char* query = "DETACH DATABASE registry";
    if (!(reg->status & reg_attached)) {
        reg_throw(errPtr,REG_MISUSE,"no database is attached to this registry");
        return 0;
    }
    if (sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK) {
        int r;
        reg_entry* entry;
        Tcl_HashEntry* curr;
        Tcl_HashSearch search;
        /* XXX: Busy waiting, consider using sqlite3_busy_handler/timeout */
        do {
            sqlite3_step(stmt);
            r = sqlite3_reset(stmt);
            switch (r) {
                case SQLITE_OK:
                    for (curr = Tcl_FirstHashEntry(&reg->open_entries, &search);
                            curr != NULL; curr = Tcl_NextHashEntry(&search)) {
                        entry = Tcl_GetHashValue(curr);
                        if (entry->proc) {
                            free(entry->proc);
                        }
                        free(entry);
                    }
                    Tcl_DeleteHashTable(&reg->open_entries);
                    for (curr = Tcl_FirstHashEntry(&reg->open_files, &search);
                            curr != NULL; curr = Tcl_NextHashEntry(&search)) {
                        reg_file* file = Tcl_GetHashValue(curr);

                        free(file->proc);
                        free(file->key.path);
                        free(file);
                    }
                    Tcl_DeleteHashTable(&reg->open_files);
                    reg->status &= ~reg_attached;
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
 * Helper function for `reg_start_read` and `reg_start_write`.
 */
static int reg_start(reg_registry* reg, const char* query, reg_error* errPtr) {
    if (reg->status & reg_transacting) {
        reg_throw(errPtr, REG_MISUSE, "couldn't start transaction because a "
                "transaction is already open");
        errPtr->free = NULL;
        return 0;
    } else {
        int r;
        do {
            r = sqlite3_exec(reg->db, query, NULL, NULL, NULL);
            if (r == SQLITE_OK) {
                return 1;
            }
        } while (r == SQLITE_BUSY);
        reg_sqlite_error(reg->db, errPtr, NULL);
        return 0;
    }
}

/**
 * Starts a read transaction on registry. This acquires a shared lock on the
 * database. It must be released with `reg_commit` or `reg_rollback` (it doesn't
 * actually matter which, since the transaction won't have changed any values).
 *
 * @param [in] reg     registry to start transaction on
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_start_read(reg_registry* reg, reg_error* errPtr) {
    if (reg_start(reg, "BEGIN", errPtr)) {
        reg->status |= reg_transacting;
        return 1;
    } else {
        return 0;
    }
}

/**
 * Starts a write transaction on registry. This acquires an exclusive lock on
 * the database. It must be released with `reg_commit` or `reg_rollback`.
 *
 * @param [in] reg     registry to start transaction on
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_start_write(reg_registry* reg, reg_error* errPtr) {
    if (reg_start(reg, "BEGIN IMMEDIATE", errPtr)) {
        reg->status |= reg_transacting | reg_can_write;
        return 1;
    } else {
        return 0;
    }
}

/**
 * Helper function for `reg_commit` and `reg_rollback`.
 */
static int reg_end(reg_registry* reg, const char* query, reg_error* errPtr, int is_rollback) {
    if (!(reg->status & reg_transacting)) {
        reg_throw(errPtr, REG_MISUSE, "couldn't end transaction because no "
                "transaction is open");
        return 0;
    } else {
        int r;
        do {
            r = sqlite3_exec(reg->db, query, NULL, NULL, NULL);
            if (r == SQLITE_OK) {
                return 1;
            }
        } while (r == SQLITE_BUSY && !is_rollback);
        reg_sqlite_error(reg->db, errPtr, NULL);
        return 0;
    }
}

/**
 * Commits the current transaction. All values written since `reg_start_*` was
 * called will be written to the database.
 *
 * @param [in] reg     registry to commit transaction to
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_commit(reg_registry* reg, reg_error* errPtr) {
    if (reg_end(reg, "COMMIT", errPtr, 0)) {
        reg->status &= ~(reg_transacting | reg_can_write);
        return 1;
    } else {
        return 0;
    }
}

/**
 * Rolls back the current transaction. All values written since `reg_start_*`
 * was called will be reverted, and no changes will be written to the database.
 *
 * @param [in] reg     registry to roll back transaction from
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_rollback(reg_registry* reg, reg_error* errPtr) {
    if (reg_end(reg, "ROLLBACK", errPtr, 1)) {
        reg->status &= ~(reg_transacting | reg_can_write);
        return 1;
    } else {
        return 0;
    }
}

/**
 * Runs VACUUM (compact/defragment) on the given db file.
 * Works on a path rather than an open db pointer because you can't vacuum an
 * attached db, which is what the rest of the registry uses for some reason.
 *
 * @param [in] db_path path to db file to vacuum
 * @return             true if success; false if failure
 */
int reg_vacuum(char *db_path) {
    sqlite3* db;
    sqlite3_stmt* stmt = NULL;
    int result = 0;
    reg_error err;

    if (sqlite3_open(db_path, &db) == SQLITE_OK) {
        if (!init_db(db, &err)) {
            sqlite3_close(db);
            return 0;
        }
    } else {
        return 0;
    }

    if (sqlite3_prepare_v2(db, "VACUUM", -1, &stmt, NULL) == SQLITE_OK) {
        int r;
        /* XXX: Busy waiting, consider using sqlite3_busy_handler/timeout */
        do {
            sqlite3_step(stmt);
            r = sqlite3_reset(stmt);
            if (r == SQLITE_OK) {
                result = 1;
            }
        } while (r == SQLITE_BUSY);
    }
    if (stmt) {
        sqlite3_finalize(stmt);
    }
    sqlite3_close(db);
    return result;
}

/**
 * Checkpoints a registry database if WAL mode is available.
 *
 * @param [in] reg     registry to checkpoint
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_checkpoint(reg_registry* reg, reg_error* errPtr) {

#if SQLITE_VERSION_NUMBER >= 3022000
    if (sqlite3_libversion_number() >= 3022000) {
        if (sqlite3_db_readonly(reg->db, "registry") == 0
                && sqlite3_wal_checkpoint_v2(reg->db, "registry",
                SQLITE_CHECKPOINT_PASSIVE, NULL, NULL) != SQLITE_OK) {
            reg_sqlite_error(reg->db, errPtr, NULL);
            return 0;
        }
    }
#endif
    return 1;
}

/**
 * Functions for access to the metadata table
 */

/**
 * @param [in] reg     registry to get value from
 * @param [in] key     metadata key to get
 * @param [out] value  the value of the metadata
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_get_metadata(reg_registry* reg, const char* key, char** value,
        reg_error* errPtr) {
    int result = 0;
    sqlite3_stmt* stmt = NULL;
    char* query = "SELECT value FROM registry.metadata WHERE key=?";
    const char *text;
    if (sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK
            && (sqlite3_bind_text(stmt, 1, key, -1, SQLITE_STATIC) == SQLITE_OK)) {
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
                    errPtr->code = REG_NOT_FOUND;
                    errPtr->description = "no such key in metadata";
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
    return result;
}

/**
 * @param [in] reg     registry to set value in
 * @param [in] key     metadata key to set
 * @param [in] value   the desired value for the key
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int reg_set_metadata(reg_registry* reg, const char* key, const char* value,
        reg_error* errPtr) {
    int result = 0;
    sqlite3_stmt* stmt = NULL;
    char* query;
    char *test_value;
    int get_returnval = reg_get_metadata(reg, key, &test_value, errPtr);
    if (get_returnval) {
        free(test_value);
        query = sqlite3_mprintf("UPDATE registry.metadata SET value = '%q' WHERE key='%q'",
            value, key);
    } else if (errPtr->code == REG_NOT_FOUND) {
        query = sqlite3_mprintf("INSERT INTO registry.metadata (key, value) VALUES ('%q', '%q')",
            key, value);
    } else {
        return get_returnval;
    }
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
 * @param [in] reg        the registry to delete the metadata from
 * @param [in] key        the metadata key to delete
 * @param [out] errPtr    on error, a description of the error that occurred
 * @return                true if success; false if failure
 */
int reg_del_metadata(reg_registry* reg, const char* key, reg_error* errPtr) {
    int result = 1;
    sqlite3_stmt* stmt = NULL;
    char* query = "DELETE FROM registry.metadata WHERE key=?";
    if ((sqlite3_prepare_v2(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_bind_text(stmt, 1, key, -1, SQLITE_STATIC) == SQLITE_OK)) {
        int r;
        do {
            r = sqlite3_step(stmt);
            switch (r) {
                case SQLITE_DONE:
                    if (sqlite3_changes(reg->db) == 0) {
                        reg_throw(errPtr, REG_INVALID, "no such metadata key");
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
    if (stmt) {
        sqlite3_finalize(stmt);
    }
    return result;
}
