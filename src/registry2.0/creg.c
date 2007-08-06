/*
 * reg.c
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
#include <sqlite3.h>
#include <sys/stat.h>
#include <errno.h>

#include "graph.h"
#include "item.h"
#include "entry.h"
#include "util.h"
#include "sql.h"

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

int reg_open(sqlite3** dbPtr, reg_error* errPtr) {
    if (sqlite3_open(NULL, dbPtr) == SQLITE_OK) {
        if (init_db(*dbPtr, errPtr)) {
            return 1;
        } else {
            sqlite3_close(*dbPtr);
            *dbPtr = NULL;
        }
    } else {
        reg_sqlite_error(*dbPtr, errPtr, NULL);
        sqlite3_close(*dbPtr);
        *dbPtr = NULL;
    }
    return 0;
}

int reg_close(sqlite3* db, reg_error* errPtr) {
    if (sqlite3_close((sqlite3*)db) == SQLITE_OK) {
        return 1;
    } else {
        errPtr->code = "registry::not-closed";
        errPtr->description = sqlite3_mprintf("error: registry db not closed "
                "correctly (%s)\n", sqlite3_errmsg((sqlite3*)db));
        errPtr->free = (reg_error_destructor*)sqlite3_free;
        return 0;
    }
}

int reg_attach(sqlite3* db, const char* path, reg_error* errPtr) {
    struct stat sb;
    int needsInit = 0; /* registry doesn't yet exist */
    int canWrite = 1; /* can write to this location */
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
        if ((sqlite3_prepare(db, query, -1, &stmt, NULL) == SQLITE_OK)
                && (sqlite3_step(stmt) == SQLITE_DONE)) {
            sqlite3_finalize(stmt);
            if (!needsInit || (create_tables(db, errPtr))) {
                return 1;
            }
        } else {
            reg_sqlite_error(db, errPtr, query);
            sqlite3_finalize(stmt);
        }
    } else {
        errPtr->code = "registry::cannot-init";
        errPtr->description = sqlite3_mprintf("port registry doesn't exist at \"%q\" and couldn't write to this location", path);
        errPtr->free = (reg_error_destructor*)sqlite3_free;
    }
    return 0;
}

int reg_detach(sqlite3* db, reg_error* errPtr) {
    sqlite3_stmt* stmt;
    char* query = "DETACH DATABASE registry";
    if ((sqlite3_prepare(db, query, -1, &stmt, NULL) == SQLITE_OK)
            && (sqlite3_step(stmt) == SQLITE_DONE)) {
        sqlite3_finalize(stmt);
        query = "SELECT address FROM entries";
        if (sqlite3_prepare(db, query, -1, &stmt, NULL) == SQLITE_OK) {
            int r;
            reg_entry* entry;
            do {
                r = sqlite3_step(stmt);
                switch (r) {
                    case SQLITE_ROW:
                        entry = *(reg_entry**)sqlite3_column_blob(stmt, 0);
                        reg_entry_free(db, entry);
                        break;
                    case SQLITE_DONE:
                        break;
                    default:
                        reg_sqlite_error(db, errPtr, query);
                        return 0;
                }
            } while (r != SQLITE_DONE);
        }
        sqlite3_finalize(stmt);
        query = "DELETE FROM entries";
        if ((sqlite3_prepare(db, query, -1, &stmt, NULL) != SQLITE_OK)
                || (sqlite3_step(stmt) != SQLITE_DONE)) {
            sqlite3_finalize(stmt);
            return 0;
        }
        return 1;
    } else {
        reg_sqlite_error(db, errPtr, query);
        sqlite3_finalize(stmt);
        return 0;
    }
}

