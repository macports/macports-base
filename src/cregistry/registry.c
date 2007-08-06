/*
 * registry.c
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

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sqlite3.h>
#include <sys/stat.h>
#include <errno.h>

#include <cregistry/entry.h>
#include <cregistry/sql.h>

void reg_error_destruct(reg_error* errPtr) {
    if (errPtr->free) {
        errPtr->free(errPtr->description);
    }
}

/**
 * Sets `errPtr` according to the last error in `db`.
 */
void reg_sqlite_error(sqlite3* db, reg_error* errPtr, char* query) {
    errPtr->code = "registry::sqlite-error";
    errPtr->free = (reg_error_destructor*)sqlite3_free;
    if (query == NULL) {
        errPtr->description = sqlite3_mprintf("sqlite error: %s",
                sqlite3_errmsg(db));
    } else {
        errPtr->description = sqlite3_mprintf("sqlite error: %s while "
                "executing query: %s", sqlite3_errmsg(db), query);
    }
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
    if (sqlite3_open(NULL, &reg->db) == SQLITE_OK) {
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
        errPtr->code = "registry::not-closed";
        errPtr->description = sqlite3_mprintf("error: registry db not closed "
                "correctly (%s)\n", sqlite3_errmsg(reg->db));
        errPtr->free = (reg_error_destructor*)sqlite3_free;
        return 0;
    }
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
    int needsInit = 0; /* registry doesn't yet exist */
    int canWrite = 1; /* can write to this location */
    if (reg->status & reg_attached) {
        errPtr->code = "registry::already-attached";
        errPtr->description = "a database is already attached to this registry";
        errPtr->free = NULL;
        return 0;
    }
    if (stat(path, &sb) != 0) {
        if (errno == ENOENT) {
            needsInit = 1;
        } else {
            canWrite = 0;
        }
    }
    if (!needsInit || canWrite) {
        sqlite3_stmt* stmt;
        char* query = sqlite3_mprintf("ATTACH DATABASE '%q' AS registry", path);
        if ((sqlite3_prepare(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
                && (sqlite3_step(stmt) == SQLITE_DONE)) {
            sqlite3_finalize(stmt);
            if (!needsInit || (create_tables(reg->db, errPtr))) {
                reg->status |= reg_attached;
                return 1;
            }
        } else {
            reg_sqlite_error(reg->db, errPtr, query);
            sqlite3_finalize(stmt);
        }
    } else {
        errPtr->code = "registry::cannot-init";
        errPtr->description = sqlite3_mprintf("port registry doesn't exist at \"%q\" and couldn't write to this location", path);
        errPtr->free = (reg_error_destructor*)sqlite3_free;
    }
    return 0;
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
    sqlite3_stmt* stmt;
    char* query = "DETACH DATABASE registry";
    if (!(reg->status & reg_attached)) {
        errPtr->code = "registry::not-attached";
        errPtr->description = "no database is attached to this registry";
        errPtr->free = NULL;
        return 0;
    }
    if ((sqlite3_prepare(reg->db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_step(stmt) == SQLITE_DONE)) {
        sqlite3_finalize(stmt);
        query = "SELECT address FROM entries";
        if (sqlite3_prepare(reg->db, query, -1, &stmt, NULL) == SQLITE_OK) {
            int r;
            reg_entry* entry;
            do {
                r = sqlite3_step(stmt);
                switch (r) {
                    case SQLITE_ROW:
                        entry = *(reg_entry**)sqlite3_column_blob(stmt, 0);
                        if (entry->proc != NULL) {
                            free(entry->proc);
                        }
                        free(entry);
                        /* reg_entry_free(reg->db, entry); */
                        break;
                    case SQLITE_DONE:
                        break;
                    default:
                        reg_sqlite_error(reg->db, errPtr, query);
                        return 0;
                }
            } while (r != SQLITE_DONE);
        }
        sqlite3_finalize(stmt);
        query = "DELETE FROM entries";
        if ((sqlite3_prepare(reg->db, query, -1, &stmt, NULL) != SQLITE_OK)
                || (sqlite3_step(stmt) != SQLITE_DONE)) {
            sqlite3_finalize(stmt);
            return 0;
        }
        sqlite3_finalize(stmt);
        reg->status &= ~reg_attached;
        return 1;
    } else {
        reg_sqlite_error(reg->db, errPtr, query);
        sqlite3_finalize(stmt);
        return 0;
    }
}

static int reg_start(reg_registry* reg, const char* query, reg_error* errPtr) {
    if (reg->status & reg_transacting) {
        errPtr->code = "registry::cant-start";
        errPtr->description = "couldn't start transaction because a "
            "transaction is already open";
        errPtr->free = NULL;
        return 0;
    } else {
        int result;
        do {
            result = sqlite3_exec(reg->db, query, NULL, NULL, NULL);
            if (result == SQLITE_ERROR) {
                reg_sqlite_error(reg->db, errPtr, NULL);
                return 0;
            }
        } while (result != SQLITE_OK);
        return 1;
    }
}

int reg_start_read(reg_registry* reg, reg_error* errPtr) {
    if (reg_start(reg, "BEGIN", errPtr)) {
        reg->status |= reg_transacting;
        return 1;
    } else {
        return 0;
    }
}

int reg_start_write(reg_registry* reg, reg_error* errPtr) {
    if (reg_start(reg, "BEGIN EXCLUSIVE", errPtr)) {
        reg->status |= reg_transacting | reg_can_write;
        return 1;
    } else {
        return 0;
    }
}

static int reg_end(reg_registry* reg, const char* query, reg_error* errPtr) {
    if (!(reg->status & reg_transacting)) {
        errPtr->code = "registry::cant-end";
        errPtr->description = "couldn't end transaction because no transaction "
            "is open";
        errPtr->free = NULL;
        return 0;
    } else {
        int result;
        do {
            result = sqlite3_exec(reg->db, query, NULL, NULL, NULL);
            if (result == SQLITE_ERROR) {
                reg_sqlite_error(reg->db, errPtr, NULL);
                return 0;
            }
        } while (result != SQLITE_OK);
        return 1;
    }
}

int reg_commit(reg_registry* reg, reg_error* errPtr) {
    if (reg_end(reg, "COMMIT", errPtr)) {
        reg->status &= ~(reg_transacting | reg_can_write);
        return 1;
    } else {
        return 0;
    }
}

int reg_rollback(reg_registry* reg, reg_error* errPtr) {
    if (reg_end(reg, "ROLLBACK", errPtr)) {
        reg->status &= ~(reg_transacting | reg_can_write);
        return 1;
    } else {
        return 0;
    }
}

int reg_test_writable(reg_registry* reg, reg_error* errPtr) {
    if (reg->status & reg_can_write) {
        return 1;
    } else {
        errPtr->code = "registry::no-write";
        errPtr->description = "a write transaction has not been started";
        errPtr->free = NULL;
        return 0;
    }
}
