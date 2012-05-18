/*
 * sql.c
 * $Id$
 *
 * Copyright (c) 2007 Chris Pickel <sfiera@macports.org>
 * Copyright (c) 2012 The MacPorts Project
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

#include "registry.h"
#include "sql.h"
#include "vercomp.h"

#include <sqlite3.h>
#include <string.h>
#include <tcl.h>
#include <time.h>

/**
 * Executes a null-terminated list of queries. Pass it a list of queries, it'll
 * execute them. This is mainly intended for initialization, when you have a
 * number of standard queries to execute.
 *
 * @param [in] db      database to execute queries on
 * @param [in] queries NULL-terminated list of queries
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int do_queries(sqlite3* db, char** queries, reg_error* errPtr) {
    char** query;
    sqlite3_stmt* stmt = NULL;
    int r = SQLITE_OK;

    for (query = queries; *query != NULL; query++) {
        if ((r = sqlite3_prepare_v2(db, *query, -1, &stmt, NULL)) != SQLITE_OK) {
            sqlite3_finalize(stmt);
            break;
        }

        do {
            r = sqlite3_step(stmt);
        } while (r == SQLITE_BUSY);

        sqlite3_finalize(stmt);

        /* Either execution succeeded and r == SQLITE_DONE | SQLITE_ROW, or there was an error */
        if (r != SQLITE_DONE && r != SQLITE_ROW) {
            /* stop executing statements in case of errors */
            break;
        }
    }

    switch (r) {
        case SQLITE_OK:
        case SQLITE_DONE:
        case SQLITE_ROW:
            return 1;
        default:
            /* handle errors */
            reg_sqlite_error(db, errPtr, *query);
            return 0;
    }
}

/**
 * REGEXP function for sqlite3. Takes two arguments; the first is the value and
 * the second the pattern. If the pattern is invalid, errors out. Otherwise,
 * returns true if the value matches the pattern and false otherwise.
 *
 * This function is made available in sqlite3 as the REGEXP operator.
 *
 * @param [in] context sqlite3-defined structure
 * @param [in] argc    number of arguments - always 2 and hence unused
 * @param [in] argv    0: value to match; 1: pattern to match against
 */
static void sql_regexp(sqlite3_context* context, int argc UNUSED,
        sqlite3_value** argv) {
    const char* value = (const char*)sqlite3_value_text(argv[0]);
    const char* pattern = (const char*)sqlite3_value_text(argv[1]);
    switch (Tcl_RegExpMatch(NULL, value, pattern)) {
        case 0:
            sqlite3_result_int(context, 0);
            break;
        case 1:
            sqlite3_result_int(context, 1);
            break;
        case -1:
            sqlite3_result_error(context, "invalid pattern", -1);
            break;
    }
}

/**
 * Creates tables in the registry. This function is called upon an uninitialized
 * database to create the tables needed to record state between invocations of
 * `port`.
 *
 * @param [in] db      database with an attached registry db
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int create_tables(sqlite3* db, reg_error* errPtr) {
    static char* queries[] = {
        "BEGIN",

        /* metadata table */
        "CREATE TABLE registry.metadata (key UNIQUE, value)",
        "INSERT INTO registry.metadata (key, value) VALUES ('version', 1.100)",
        "INSERT INTO registry.metadata (key, value) VALUES ('created', strftime('%s', 'now'))",

        /* ports table */
        "CREATE TABLE registry.ports ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, "
            "name TEXT COLLATE NOCASE, portfile CLOB, url TEXT, "
            "location TEXT, epoch INTEGER, version TEXT COLLATE VERSION, "
            "revision INTEGER, variants TEXT, negated_variants TEXT, "
            "state TEXT, date DATETIME, installtype TEXT, archs TEXT, "
            "requested INT, os_platform TEXT, os_major INTEGER, "
            "UNIQUE (name, epoch, version, revision, variants), "
            "UNIQUE (url, epoch, version, revision, variants)"
            ")",
        "CREATE INDEX registry.port_name ON ports "
            "(name, epoch, version, revision, variants)",
        "CREATE INDEX registry.port_url ON ports "
            "(url, epoch, version, revision, variants)",
        "CREATE INDEX registry.port_state ON ports (state)",

        /* file map */
        "CREATE TABLE registry.files (id INTEGER, path TEXT, actual_path TEXT, "
            "active INT, mtime DATETIME, md5sum TEXT, editable INT, binary BOOL, "
            "FOREIGN KEY(id) REFERENCES ports(id))",
        "CREATE INDEX registry.file_port ON files (id)",
        "CREATE INDEX registry.file_path ON files(path)",
        "CREATE INDEX registry.file_actual ON files(actual_path)",
        "CREATE INDEX registry.file_binary ON files(binary)",

        /* dependency map */
        "CREATE TABLE registry.dependencies (id INTEGER, name TEXT, variants TEXT, "
        "FOREIGN KEY(id) REFERENCES ports(id))",
        "CREATE INDEX registry.dep_name ON dependencies (name)",

        "COMMIT",
        NULL
    };
    return do_queries(db, queries, errPtr);
}

/**
 * Tries to ROLLBACK a currently running transaction on the SQLite database.
 * Errors are silently ignored to preserve errors that have been set before and
 * are probably the root cause of why we did the rollback in the first place.
 *
 * @param [in] db    database to rollback
 * @return           true if success, false on failure
 */
static int rollback_db(sqlite3* db) {
    char* rollback = "ROLLBACK";
    sqlite3_stmt* stmt = NULL;

    /*puts("Attempting to ROLLBACK...");*/

    if (sqlite3_prepare_v2(db, rollback, -1, &stmt, NULL) != SQLITE_OK) {
        /*printf("failed prepare: %d: %s\n", sqlite3_errcode(db), sqlite3_errmsg(db));*/
        return 0;
    }

    if (sqlite3_step(stmt) != SQLITE_DONE) {
        /*printf("failed step: %d: %s\n", sqlite3_errcode(db), sqlite3_errmsg(db));*/
        return 0;
    }

    /*puts("success.");*/

    return 1;
}

/**
 * Updates the database if necessary. This function queries the current database version
 * from the metadata table and executes SQL to update the schema to newer versions if needed.
 * After that, this function updates the database version number
 *
 * @param [in] db      database to update
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int update_db(sqlite3* db, reg_error* errPtr) {
    const char* version;
    int r;
    int did_update = 0; /* true, if an update was done and the loop should be run again */
    char* q_begin = "BEGIN";
    char* q_version = "SELECT value FROM registry.metadata WHERE key = 'version'";
    char* query = q_begin;
    sqlite3_stmt* stmt = NULL;

    do {
        did_update = 0;

        /* open a transaction to prevent a check-and-change race condition between
         * multiple port(1) instances */
        if ((r = sqlite3_prepare_v2(db, query, -1, &stmt, NULL)) != SQLITE_OK) {
            break;
        }

        if ((r = sqlite3_step(stmt)) != SQLITE_DONE) {
            break;
        }

        sqlite3_finalize(stmt);
        stmt = NULL;

        /* query current version number */
        query = q_version;
        if ((r = sqlite3_prepare_v2(db, query, -1, &stmt, NULL)) != SQLITE_OK) {
            break;
        }

        r = sqlite3_step(stmt);
        if (r == SQLITE_DONE) {
            /* the version number was not found */
            reg_throw(errPtr, REG_INVALID, "Version number in metadata table not found.");
            sqlite3_finalize(stmt);
            rollback_db(db);
            return 0;
        }
        if (r != SQLITE_ROW) {
            /* an error occured querying */
            break;
        }
        if (NULL == (version = (const char *)sqlite3_column_text(stmt, 0))) {
            reg_throw(errPtr, REG_INVALID, "Version number in metadata table is NULL.");
            sqlite3_finalize(stmt);
            rollback_db(db);
            return 0;
        }

        /* we can't call vercmp directly because it's static, but we have
         * sql_version, which is basically an alias */
        if (sql_version(NULL, -1, version, -1, "1.1") < 0) {
            /* we need to update to 1.1, add binary field and index to files
             * table */
            static char* version_1_1_queries[] = {
#if SQLITE_VERSION_NUMBER >= 3002000
                "ALTER TABLE registry.files ADD COLUMN binary BOOL",
#else
                /*
                 * SQLite < 3.2.0 doesn't support ALTER TABLE ADD COLUMN
                 * Unfortunately, Tiger ships with SQLite < 3.2.0 (#34463)
                 * This is taken from http://www.sqlite.org/faq.html#q11
                 */

                /* Create a temporary table */
                "CREATE TEMPORARY TABLE mp_files_backup (id INTEGER, path TEXT, "
                    "actual_path TEXT, active INT, mtime DATETIME, md5sum TEXT, editable INT, "
                    "FOREIGN KEY(id) REFERENCES ports(id))",

                /* Copy all data into the temporary table */
                "INSERT INTO mp_files_backup SELECT id, path, actual_path, active, mtime, "
                    "md5sum, editable FROM registry.files",

                /* Drop the original table and re-create it with the new structure */
                "DROP TABLE registry.files",
                "CREATE TABLE registry.files (id INTEGER, path TEXT, actual_path TEXT, "
                    "active INT, mtime DATETIME, md5sum TEXT, editable INT, binary BOOL, "
                    "FOREIGN KEY(id) REFERENCES ports(id))",
                "CREATE INDEX registry.file_port ON files(id)",
                "CREATE INDEX registry.file_path ON files(path)",
                "CREATE INDEX registry.file_actual ON files(actual_path)",

                /* Copy all data back from temporary table */
                "INSERT INTO registry.files (id, path, actual_path, active, mtime, md5sum, "
                    "editable) SELECT id, path, actual_path, active, mtime, md5sum, "
                    "editable FROM mp_files_backup",

                /* Remove temporary table */
                "DROP TABLE mp_files_backup",
#endif
                "CREATE INDEX registry.file_binary ON files(binary)",

                "UPDATE registry.metadata SET value = '1.100' WHERE key = 'version'",

                "COMMIT",
                NULL
            };

            /* don't forget to finalize the version query here, or it might
             * cause "cannot commit transaction - SQL statements in progress",
             * see #32686 */
            sqlite3_finalize(stmt);
            stmt = NULL;

            if (!do_queries(db, version_1_1_queries, errPtr)) {
                rollback_db(db);
                return 0;
            }

            did_update = 1;
            continue;
        }

        /* add new versions here, but remember to:
         *  - finalize the version query statement and set stmt to NULL
         *  - do _not_ use "BEGIN" in your query list, since a transaction has
         *    already been started for you
         *  - end your query list with "COMMIT", NULL
         *  - set did_update = 1 and continue;
         */

        /* if we arrive here, no update was done and we should end the
         * transaction. Using ROLLBACK here causes problems when rolling back
         * other transactions later in the program. */
        sqlite3_finalize(stmt);
        stmt = NULL;
        r = sqlite3_exec(db, "COMMIT", NULL, NULL, NULL);
    } while (did_update);

    sqlite3_finalize(stmt);
    switch (r) {
        case SQLITE_OK:
        case SQLITE_DONE:
        case SQLITE_ROW:
            return 1;
        default:
            reg_sqlite_error(db, errPtr, query);
            return 0;
    }
}

/**
 * Initializes database connection. This function creates all the temporary
 * tables used by the registry. It also registers the user functions and
 * collations declared here, making them available.
 *
 * @param [in] db      database to initialize
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int init_db(sqlite3* db, reg_error* errPtr) {
    /* no code that uses these tables is being built at this time */
    static char* queries[] = {
        /*"BEGIN",*/

        /* items cache */
        /*"CREATE TEMPORARY TABLE items (refcount, proc UNIQUE, name, url, path, "
            "worker, options, variants)",*/

        /* indexes list */
        /*"CREATE TEMPORARY TABLE indexes (file, name, attached)",

        "COMMIT",*/
        NULL
    };

    /* I'm not error-checking these. I don't think I need to. */
    sqlite3_create_function(db, "REGEXP", 2, SQLITE_UTF8, NULL, sql_regexp,
            NULL, NULL);

    sqlite3_create_collation(db, "VERSION", SQLITE_UTF8, NULL, sql_version);

    return do_queries(db, queries, errPtr);
}

