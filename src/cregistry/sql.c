/*
 * sql.c
 * $Id$
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

#include "registry.h"
#include "sql.h"
#include "vercomp.h"

#include <tcl.h>
#include <sqlite3.h>
#include <time.h>

/*
 * TODO: maybe this could be made into something that could be separately loaded
 *       by sqlite3? It's a bit hard to query the registry with the command-line
 *       sqlite3 tool because of the missing VERSION collation. My understanding
 *       is that you can make a dylib that can be loaded using an sql statement,
 *       which is less than transparent, but certainly reasonable.
 *
 * TODO: break out rpm_vercomp into a separate file which can be shared by
 *       pextlib and cregistry. The version here is slightly modified so as to
 *       take explicit string lengths. Since these are available in Tcl it's an
 *       easy change and might be a tiny bit faster; it's necessary for the
 *       application here.
 */

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
        sqlite3_stmt* stmt;
        if ((sqlite3_prepare(db, *query, -1, &stmt, NULL) != SQLITE_OK)
                || (sqlite3_step(stmt) != SQLITE_DONE)) {
            reg_sqlite_error(db, errPtr, *query);
            sqlite3_finalize(stmt);
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
 * NOW function for sqlite3. Takes no arguments. Returns the unix timestamp of
 * the current time.
 *
 * @param [in] context sqlite3-defined structure
 * @param [in] argc    number of arguments - always 2 and hence unused
 * @param [in] argv    0: value to match; 1: pattern to match against
 */
static void sql_now(sqlite3_context* context, int argc UNUSED,
        sqlite3_value** argv UNUSED) {
    sqlite3_result_int(context, time(NULL));
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
        "INSERT INTO registry.metadata (key, value) VALUES ('version', 1.000)",
        "INSERT INTO registry.metadata (key, value) VALUES ('created', NOW())",

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
            "active INT, mtime DATETIME, md5sum TEXT, editable INT, "
            "FOREIGN KEY(id) REFERENCES ports(id))",
        "CREATE INDEX registry.file_port ON files (id)",
        "CREATE INDEX registry.file_path ON files(path)",
        "CREATE INDEX registry.file_actual ON files(actual_path)",

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
 * Initializes database connection. This function creates all the temporary
 * tables used by the registry. It also registers the user functions and
 * collations declared here, making them available.
 *
 * @param [in] db      database to initialize
 * @param [out] errPtr on error, a description of the error that occurred
 * @return             true if success; false if failure
 */
int init_db(sqlite3* db, reg_error* errPtr) {
    static char* queries[] = {
        "BEGIN",

        /* items cache */
        "CREATE TEMPORARY TABLE items (refcount, proc UNIQUE, name, url, path, "
            "worker, options, variants)",

        /* indexes list */
        "CREATE TEMPORARY TABLE indexes (file, name, attached)",

        "COMMIT",
        NULL
    };

    /* I'm not error-checking these. I don't think I need to. */
    sqlite3_create_function(db, "REGEXP", 2, SQLITE_UTF8, NULL, sql_regexp,
            NULL, NULL);
    sqlite3_create_function(db, "NOW", 0, SQLITE_ANY, NULL, sql_now, NULL,
            NULL);

    sqlite3_create_collation(db, "VERSION", SQLITE_UTF8, NULL, sql_version);

    return do_queries(db, queries, errPtr);
}

