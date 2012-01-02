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
    for (query = queries; *query != NULL; query++) {
        sqlite3_stmt* stmt = NULL;
        if ((sqlite3_prepare(db, *query, -1, &stmt, NULL) != SQLITE_OK)
                || (sqlite3_step(stmt) != SQLITE_DONE)) {
            reg_sqlite_error(db, errPtr, *query);
            if (stmt) {
                sqlite3_finalize(stmt);
            }
            return 0;
        }
        sqlite3_finalize(stmt);
    }
    return 1;
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
    char* query = "SELECT value FROM registry.metadata WHERE key = 'version'";
    sqlite3_stmt *stmt = NULL;

    if ((sqlite3_prepare(db, query, -1, &stmt, NULL) != SQLITE_OK)
            || (sqlite3_step(stmt) != SQLITE_ROW)) {
        goto reg_err_out;
    }
    if (NULL == (version = (const char *)sqlite3_column_text(stmt, 0))) {
        goto reg_err_out;
    }
    /* can't call rpm_vercomp directly, because it is static, but can call sql_version */
    if (sql_version(NULL, strlen(version), version, strlen("1.1"), "1.1") < 0) {
        /* conversion necessary, add binary field and index to files table */
        static char* version_1_1_queries[] = {
            "BEGIN",

            "ALTER TABLE registry.files ADD COLUMN binary BOOL",
            "CREATE INDEX registry.file_binary ON files(binary)",

            "UPDATE registry.metadata SET value = '1.100' WHERE key = 'version'",

            "COMMIT",
            NULL
        };

        if (!do_queries(db, version_1_1_queries, errPtr)) {
            goto err_out;
        }

        /* TODO: Walk the file tree and set the binary field */
    }
    sqlite3_finalize(stmt);
    return 1;

reg_err_out:
    reg_sqlite_error(db, errPtr, query);
err_out:
    sqlite3_finalize(stmt);
    return 0;
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

