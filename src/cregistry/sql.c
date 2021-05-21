/*
 * sql.c
 *
 * Copyright (c) 2007 Chris Pickel <sfiera@macports.org>
 * Copyright (c) 2012, 2014, 2017 The MacPorts Project
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

/*** Keep all SQL compatible with SQLite 3.1.3 as shipped with Tiger.
 *** (Conditionally doing things a better way when possible based on
 *** MP_SQLITE_VERSION is OK.)
 ***/


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
        /* settings (can't be set inside a transaction) */
        "PRAGMA fullfsync = 1",
        /* WAL was added in 3.7.0, but read-only access when using it only
           became possible in 3.22.0. It might be possible to use WAL on
           3.7.7 and later since that version added the ability to open a DB
           read-only as long as there is an existing read/write connection.
           But the DB would need to be changed back to a non-WAL journal_mode
           after doing a SQLITE_CHECKPOINT_RESTART whenever the last writer
           closes it. */
#if MP_SQLITE_VERSION >= 3022000
        "PRAGMA journal_mode=WAL",
#endif

        "BEGIN",

        /* metadata table */
        "CREATE TABLE registry.metadata (key UNIQUE, value)",
        "INSERT INTO registry.metadata (key, value) VALUES ('version', '1.210')",
        "INSERT INTO registry.metadata (key, value) VALUES ('created', strftime('%s', 'now'))",

        /* ports table */
        "CREATE TABLE registry.ports ("
              "id INTEGER PRIMARY KEY"
            ", name TEXT COLLATE NOCASE"
            ", portfile TEXT"
            ", location TEXT"
            ", epoch INTEGER"
            ", version TEXT COLLATE VERSION"
            ", revision INTEGER"
            ", variants TEXT"
            ", requested_variants TEXT"
            ", state TEXT"
            ", date DATETIME"
            ", installtype TEXT"
            ", archs TEXT"
            ", requested INTEGER"
            ", os_platform TEXT"
            ", os_major INTEGER"
            ", cxx_stdlib TEXT"
            ", cxx_stdlib_overridden INTEGER"
            ", UNIQUE (name, epoch, version, revision, variants)"
            ")",
        "CREATE INDEX registry.port_name ON ports"
            "(name, epoch, version, revision, variants)",
        "CREATE INDEX registry.port_state ON ports(state)",

        /* file map */
        "CREATE TABLE registry.files ("
              "id INTEGER"
            ", path TEXT"
            ", actual_path TEXT"
            ", active INTEGER"
            ", binary BOOL"
            ", FOREIGN KEY(id) REFERENCES ports(id))",
        "CREATE INDEX registry.file_port ON files(id)",
        "CREATE INDEX registry.file_path ON files(path)",
        "CREATE INDEX registry.file_actual ON files(actual_path)",
        "CREATE INDEX registry.file_actual_nocase ON files(actual_path COLLATE NOCASE)",

        /* dependency map */
        "CREATE TABLE registry.dependencies ("
              "id INTEGER"
            ", name TEXT"
            ", variants TEXT"
            ", FOREIGN KEY(id) REFERENCES ports(id))",
        "CREATE INDEX registry.dep_id ON dependencies(id)",
        "CREATE INDEX registry.dep_name ON dependencies(name)",

        /* portgroups table */
        "CREATE TABLE registry.portgroups ("
              "id INTEGER"
            ", name TEXT"
            ", version TEXT COLLATE VERSION"
            ", size INTEGER"
            ", sha256 TEXT"
            ", FOREIGN KEY(id) REFERENCES ports(id))",
        "CREATE INDEX registry.portgroup_id ON portgroups(id)",
        "CREATE INDEX registry.portgroup_open ON portgroups(id, name, version, size, sha256)",

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
        /* There was a bug where the registry version was set as a float
         * instead of a string on fresh installs, so some 1.100 registries
         * will say 1.1. Fortunately, there were no other versions between
         * 1.000 and 1.100. */
        if (sql_version(NULL, -1, version, -1, "1.1") < 0) {
            /* we need to update to 1.1, add binary field and index to files
             * table */
            static char* version_1_1_queries[] = {
#if MP_SQLITE_VERSION >= 3002000
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

        if (sql_version(NULL, -1, version, -1, "1.200") < 0) {
            /* We need to add the portgroup table and move the portfiles out
               of the db and into the filesystem. The latter is way easier to do
               from Tcl, so here we'll just flag that it needs to be done. */
            static char* version_1_2_queries[] = {
                /* portgroups table */
                "CREATE TABLE registry.portgroups ("
                      "id INTEGER"
                    ", name TEXT"
                    ", version TEXT COLLATE VERSION"
                    ", size INTEGER"
                    ", sha256 TEXT"
                    ", FOREIGN KEY(id) REFERENCES ports(id))",

                "UPDATE registry.metadata SET value = '1.200' WHERE key = 'version'",

                "INSERT INTO registry.metadata (key, value) VALUES ('portfiles_update_needed', 1)",

                "COMMIT",
                NULL
            };

            sqlite3_finalize(stmt);
            stmt = NULL;

            if (!do_queries(db, version_1_2_queries, errPtr)) {
                rollback_db(db);
                return 0;
            }

            did_update = 1;
            continue;
        }

        if (sql_version(NULL, -1, version, -1, "1.201") < 0) {
            /* Delete the file_binary index, since it's a low-quality index
             * according to https://www.sqlite.org/queryplanner-ng.html#howtofix */
            static char* version_1_201_queries[] = {
#if MP_SQLITE_VERSION >= 3003000
                "DROP INDEX IF EXISTS registry.file_binary",
#else
                "DROP INDEX registry.file_binary",
#endif
                "UPDATE registry.metadata SET value = '1.201' WHERE key = 'version'",
                "COMMIT",
                NULL
            };

            sqlite3_finalize(stmt);
            stmt = NULL;
            if (!do_queries(db, version_1_201_queries, errPtr)) {
                rollback_db(db);
                return 0;
            }

            did_update = 1;
            continue;
        }

        if (sql_version(NULL, -1, version, -1, "1.202") < 0) {
            static char* version_1_202_queries[] = {
                "CREATE INDEX registry.portgroup_id ON portgroups(id)",
                "CREATE INDEX registry.portgroup_open ON portgroups(id, name, version, size, sha256)",
                "CREATE INDEX registry.dep_id ON dependencies(id)",

                /*
                 * SQLite doesn't support ALTER TABLE DROP CONSTRAINT or ALTER
                 * TABLE DROP COLUMN, so we're doing the manual way to remove
                 * UNIQUE(url, epoch, version, revision, variants) and the url
                 * column.
                 */

                /* Create a temporary table */
                "CREATE TEMPORARY TABLE mp_ports_backup ("
                      "id INTEGER PRIMARY KEY"
                    ", name TEXT COLLATE NOCASE"
                    ", portfile CLOB"
                    ", location TEXT"
                    ", epoch INTEGER"
                    ", version TEXT COLLATE VERSION"
                    ", revision INTEGER"
                    ", variants TEXT"
                    ", negated_variants TEXT"
                    ", state TEXT"
                    ", date DATETIME"
                    ", installtype TEXT"
                    ", archs TEXT"
                    ", requested INT"
                    ", os_platform TEXT"
                    ", os_major INTEGER"
                    ", UNIQUE(name, epoch, version, revision, variants))",

                /* Copy all data into the temporary table */
                "INSERT INTO mp_ports_backup "
                    "SELECT"
                        "  id"
                        ", name"
                        ", portfile"
                        ", location"
                        ", epoch"
                        ", version"
                        ", revision"
                        ", variants"
                        ", negated_variants"
                        ", state"
                        ", date"
                        ", installtype"
                        ", archs"
                        ", requested"
                        ", os_platform"
                        ", os_major"
                    " FROM registry.ports",

                /* Drop the original table and re-create it with the new structure */
                "DROP TABLE registry.ports",
                "CREATE TABLE registry.ports ("
                      "id INTEGER PRIMARY KEY"
                    ", name TEXT COLLATE NOCASE"
                    ", portfile CLOB"
                    ", location TEXT"
                    ", epoch INTEGER"
                    ", version TEXT COLLATE VERSION"
                    ", revision INTEGER"
                    ", variants TEXT"
                    ", negated_variants TEXT"
                    ", state TEXT"
                    ", date DATETIME"
                    ", installtype TEXT"
                    ", archs TEXT"
                    ", requested INT"
                    ", os_platform TEXT"
                    ", os_major INTEGER"
                    ", UNIQUE(name, epoch, version, revision, variants))",

                /* Copy all data back from temporary table */
                "INSERT INTO registry.ports "
                    "SELECT"
                        "  id"
                        ", name"
                        ", portfile"
                        ", location"
                        ", epoch"
                        ", version"
                        ", revision"
                        ", variants"
                        ", negated_variants"
                        ", state"
                        ", date"
                        ", installtype"
                        ", archs"
                        ", requested"
                        ", os_platform"
                        ", os_major"
                    " FROM mp_ports_backup",

                /* Re-create indices that have been dropped with the table */
                "CREATE INDEX registry.port_name ON ports(name, epoch, version, revision, variants)",
                "CREATE INDEX registry.port_state ON ports(state)",

                /* Remove temporary table */
                "DROP TABLE mp_ports_backup",

                /*
                 * SQLite doesn't support ALTER TABLE DROP COLUMN, so we're
                 * doing the manual way to remove files.md5sum, files.mtime,
                 * files.editable.
                 */

                /* Create a temporary table */
                "CREATE TEMPORARY TABLE mp_files_backup ("
                      "id INTEGER"
                    ", path TEXT"
                    ", actual_path TEXT"
                    ", active INTEGER"
                    ", binary BOOL"
                    ")",

                /* Copy all data into the temporary table */
                "INSERT INTO mp_files_backup "
                    "SELECT"
                        "  id"
                        ", path"
                        ", actual_path"
                        ", active"
                        ", binary"
                    " FROM registry.files",

                /* Drop the original table and re-create it with the new structure */
                "DROP TABLE registry.files",
                "CREATE TABLE registry.files ("
                      "id INTEGER"
                    ", path TEXT"
                    ", actual_path TEXT"
                    ", active INTEGER"
                    ", binary BOOL"
                    ", FOREIGN KEY(id) REFERENCES ports(id))",

                /* Copy all data back from temporary table */
                "INSERT INTO registry.files "
                    "SELECT"
                        "  id"
                        ", path"
                        ", actual_path"
                        ", active"
                        ", binary"
                    " FROM mp_files_backup",

                /* Re-create indices that have been dropped with the table */
                "CREATE INDEX registry.file_port ON files(id)",
                "CREATE INDEX registry.file_path ON files(path)",
                "CREATE INDEX registry.file_actual ON files(actual_path)",

                /* Remove temporary table */
                "DROP TABLE mp_files_backup",

                /* Update version and commit */
                "UPDATE registry.metadata SET value = '1.202' WHERE key = 'version'",
                "COMMIT",
                NULL
            };

            sqlite3_finalize(stmt);
            stmt = NULL;
            if (!do_queries(db, version_1_202_queries, errPtr)) {
                rollback_db(db);
                return 0;
            }

            did_update = 1;
            continue;
        }

        if (sql_version(NULL, -1, version, -1, "1.203") < 0) {
            /*
             * A new index on files.actual_path with the COLLATE NOCASE attribute
             * will speed up queries with the equality operator and the COLLATE NOCASE
             * attribute or the LIKE operator. Needed for file mapping to ports
             * on case-insensitive file systems. Without it, any search operation
             * will be very, very, very slow.
             */
            static char* version_1_203_queries[] = {
                "CREATE INDEX registry.file_actual_nocase ON files(actual_path COLLATE NOCASE)",

                /* Update version and commit */
                "UPDATE registry.metadata SET value = '1.203' WHERE key = 'version'",
                "COMMIT",
                NULL
            };

            sqlite3_finalize(stmt);
            stmt = NULL;
            if (!do_queries(db, version_1_203_queries, errPtr)) {
                rollback_db(db);
                return 0;
            }

            did_update = 1;
            continue;
        }

        if (sql_version(NULL, -1, version, -1, "1.204") < 0) {
            /* add */
            static char* version_1_204_queries[] = {
#if MP_SQLITE_VERSION >= 3002000
                "ALTER TABLE registry.ports ADD COLUMN cxx_stdlib TEXT",
                "ALTER TABLE registry.ports ADD COLUMN cxx_stdlib_overridden INTEGER",
#else

                /* Create a temporary table */
                "CREATE TEMPORARY TABLE mp_ports_backup ("
                "id INTEGER PRIMARY KEY"
                ", name TEXT COLLATE NOCASE"
                ", portfile TEXT"
                ", location TEXT"
                ", epoch INTEGER"
                ", version TEXT COLLATE VERSION"
                ", revision INTEGER"
                ", variants TEXT"
                ", negated_variants TEXT"
                ", state TEXT"
                ", date DATETIME"
                ", installtype TEXT"
                ", archs TEXT"
                ", requested INTEGER"
                ", os_platform TEXT"
                ", os_major INTEGER"
                ", UNIQUE (name, epoch, version, revision, variants)"
                ")",

                /* Copy all data into the temporary table */
                "INSERT INTO mp_ports_backup SELECT id, name, portfile, location, epoch, "
                    "version, revision, variants, negated_variants, state, date, installtype, "
                    "archs, requested, os_platform, os_major FROM registry.ports",

                /* Drop the original table and re-create it with the new structure */
                "DROP TABLE registry.ports",
                "CREATE TABLE registry.ports ("
                "id INTEGER PRIMARY KEY"
                ", name TEXT COLLATE NOCASE"
                ", portfile TEXT"
                ", location TEXT"
                ", epoch INTEGER"
                ", version TEXT COLLATE VERSION"
                ", revision INTEGER"
                ", variants TEXT"
                ", negated_variants TEXT"
                ", state TEXT"
                ", date DATETIME"
                ", installtype TEXT"
                ", archs TEXT"
                ", requested INTEGER"
                ", os_platform TEXT"
                ", os_major INTEGER"
                ", cxx_stdlib TEXT"
                ", cxx_stdlib_overridden INTEGER"
                ", UNIQUE (name, epoch, version, revision, variants)"
                ")",
                "CREATE INDEX registry.port_name ON ports"
                    "(name, epoch, version, revision, variants)",
                "CREATE INDEX registry.port_state ON ports(state)",

                /* Copy all data back from temporary table */
                "INSERT INTO registry.ports (id, name, portfile, location, epoch, version, "
                    "revision, variants, negated_variants, state, date, installtype, archs, "
                    "requested, os_platform, os_major) SELECT id, name, portfile, location, "
                    "epoch, version, revision, variants, negated_variants, state, date, "
                    "installtype, archs, requested, os_platform, os_major "
                    "FROM mp_ports_backup",

                /* Remove temporary table */
                "DROP TABLE mp_ports_backup",
#endif

                "UPDATE registry.metadata SET value = '1.204' WHERE key = 'version'",

                "COMMIT",
                NULL
            };

            sqlite3_finalize(stmt);
            stmt = NULL;

            if (!do_queries(db, version_1_204_queries, errPtr)) {
                rollback_db(db);
                return 0;
            }

            did_update = 1;
            continue;
        }

        if (sql_version(NULL, -1, version, -1, "1.205") < 0) {
            /* enable fullfsync and possibly WAL */
            static char* version_1_205_queries[] = {
                "UPDATE registry.metadata SET value = '1.205' WHERE key = 'version'",
                "COMMIT",
                "PRAGMA fullfsync = 1",
#if MP_SQLITE_VERSION >= 3022000
                "PRAGMA journal_mode=WAL",
#endif
                NULL
            };

            sqlite3_finalize(stmt);
            stmt = NULL;

            if (!do_queries(db, version_1_205_queries, errPtr)) {
                rollback_db(db);
                return 0;
            }

            did_update = 1;
            continue;
        }

        if (sql_version(NULL, -1, version, -1, "1.210") < 0) {
            /* add */
            static char* version_1_210_queries[] = {
#if MP_SQLITE_VERSION >= 3025000
                "ALTER TABLE registry.ports RENAME COLUMN negated_variants TO requested_variants",
#else

                /* Create a temporary table */
                "CREATE TEMPORARY TABLE mp_ports_backup ("
                "id INTEGER PRIMARY KEY"
                ", name TEXT COLLATE NOCASE"
                ", portfile TEXT"
                ", location TEXT"
                ", epoch INTEGER"
                ", version TEXT COLLATE VERSION"
                ", revision INTEGER"
                ", variants TEXT"
                ", negated_variants TEXT"
                ", state TEXT"
                ", date DATETIME"
                ", installtype TEXT"
                ", archs TEXT"
                ", requested INTEGER"
                ", os_platform TEXT"
                ", os_major INTEGER"
                ", cxx_stdlib TEXT"
                ", cxx_stdlib_overridden INTEGER"
                ", UNIQUE (name, epoch, version, revision, variants)"
                ")",

                /* Copy all data into the temporary table */
                "INSERT INTO mp_ports_backup SELECT id, name, portfile, location, epoch, "
                    "version, revision, variants, negated_variants, state, date, installtype, "
                    "archs, requested, os_platform, os_major, cxx_stdlib, "
                    "cxx_stdlib_overridden FROM registry.ports",

                /* Drop the original table and re-create it with the new structure */
                "DROP TABLE registry.ports",
                "CREATE TABLE registry.ports ("
                "id INTEGER PRIMARY KEY"
                ", name TEXT COLLATE NOCASE"
                ", portfile TEXT"
                ", location TEXT"
                ", epoch INTEGER"
                ", version TEXT COLLATE VERSION"
                ", revision INTEGER"
                ", variants TEXT"
                ", requested_variants TEXT"
                ", state TEXT"
                ", date DATETIME"
                ", installtype TEXT"
                ", archs TEXT"
                ", requested INTEGER"
                ", os_platform TEXT"
                ", os_major INTEGER"
                ", cxx_stdlib TEXT"
                ", cxx_stdlib_overridden INTEGER"
                ", UNIQUE (name, epoch, version, revision, variants)"
                ")",
                "CREATE INDEX registry.port_name ON ports"
                    "(name, epoch, version, revision, variants)",
                "CREATE INDEX registry.port_state ON ports(state)",

                /* Copy all data back from temporary table */
                "INSERT INTO registry.ports (id, name, portfile, location, epoch, version, "
                    "revision, variants, requested_variants, state, date, installtype, archs, "
                    "requested, os_platform, os_major, cxx_stdlib, cxx_stdlib_overridden) "
                    "SELECT id, name, portfile, location, epoch, version, revision, "
                    "variants, negated_variants, state, date, installtype, archs, "
                    "requested, os_platform, os_major, cxx_stdlib, cxx_stdlib_overridden "
                    "FROM mp_ports_backup",

                /* Remove temporary table */
                "DROP TABLE mp_ports_backup",
#endif

                /* Assume all existing variants were requested, which often
                   won't be true, but does match the former upgrade behaviour. */
                "UPDATE registry.ports SET requested_variants = variants || requested_variants",

                "UPDATE registry.metadata SET value = '1.210' WHERE key = 'version'",

                "COMMIT",
                NULL
            };

            sqlite3_finalize(stmt);
            stmt = NULL;

            if (!do_queries(db, version_1_210_queries, errPtr)) {
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
         *  - update the current version number below
         */

        if (sql_version(NULL, -1, version, -1, "1.210") > 0) {
            /* the registry was already upgraded to a newer version and cannot be used anymore */
            reg_throw(errPtr, REG_INVALID, "Version number in metadata table is newer than expected.");
            sqlite3_finalize(stmt);
            rollback_db(db);
            return 0;
        }

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

