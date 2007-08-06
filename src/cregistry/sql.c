/*
 * sql.c
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

#include <tcl.h>
#include <sqlite3.h>
#include <string.h>
#include <time.h>
#include <ctype.h>

#include <cregistry/registry.h>
#include <cregistry/sql.h>

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
 * RPM version comparison. Shamelessly copied from Pextlib, with some changes to
 * use string lengths instead of strlen by default. That's necessary to make it
 * work with sqlite3 collations. It should be shared with Pextlib, rather than
 * just copied though.
 *
 * @param [in] versionA first version string, i.e. "1.4.1"
 * @param [in] lengthA  length of first version string, or -1 to use strlen
 * @param [in] versionB second version string, i.e. "1.4.2"
 * @param [in] lengthA  length of second version string, or -1 to use strlen
 * @return              -1 if A < B; 0 if A = B; 1 if A > B
 */
static int rpm_vercomp (const char *versionA, int lengthA, const char *versionB,
        int lengthB) {
    const char *endA, *endB;
	const char *ptrA, *ptrB;
	const char *eptrA, *eptrB;

    if (lengthA < 0)
        lengthA = strlen(versionA);
    if (lengthB < 0)
        lengthB = strlen(versionB);

	/* if versions equal, return zero */
	if(lengthA == lengthB && !strncmp(versionA, versionB, lengthA))
		return 0;

	ptrA = versionA;
	ptrB = versionB;
    endA = versionA + lengthA;
    endB = versionB + lengthB;
	while (ptrA != endA && ptrB != endB) {
		/* skip all non-alphanumeric characters */
		while (ptrA != endB && !isalnum(*ptrA))
			ptrA++;
		while (ptrB != endB && !isalnum(*ptrB))
			ptrB++;

		eptrA = ptrA;
		eptrB = ptrB;

		/* Somewhat arbitrary rules as per RPM's implementation.
		 * This code could be more clever, but we're aiming
		 * for clarity instead. */

		/* If versionB's segment is not a digit segment, but
		 * versionA's segment IS a digit segment, return 1.
		 * (Added for redhat compatibility. See redhat bugzilla
		 * #50977 for details) */
		if (!isdigit(*ptrB)) {
			if (isdigit(*ptrA))
				return 1;
		}

		/* Otherwise, if the segments are of different types,
		 * return -1 */

		if ((isdigit(*ptrA) && isalpha(*ptrB)) || (isalpha(*ptrA) && isdigit(*ptrB)))
			return -1;

		/* Find the first segment composed of entirely alphabetical
		 * or numeric members */
		if (isalpha(*ptrA)) {
			while (eptrA != endA && isalpha(*eptrA))
				eptrA++;

			while (eptrB != endB && isalpha(*eptrB))
				eptrB++;
		} else {
			int countA = 0, countB = 0;
			while (eptrA != endA && isdigit(*eptrA)) {
				countA++;
				eptrA++;
			}
			while (eptrB != endB && isdigit(*eptrB)) {
				countB++;
				eptrB++;
			}

			/* skip leading '0' characters */
			while (ptrA != eptrA && *ptrA == '0') {
				ptrA++;
				countA--;
			}
			while (ptrB != eptrB && *ptrB == '0') {
				ptrB++;
				countB--;
			}

			/* If A is longer than B, return 1 */
			if (countA > countB)
				return 1;

			/* If B is longer than A, return -1 */
			if (countB > countA)
				return -1;
		}
		/* Compare strings lexicographically */
		while (ptrA != eptrA && ptrB != eptrB && *ptrA == *ptrB) {
				ptrA++;
				ptrB++;
		}
		if (ptrA != eptrA && ptrB != eptrB)
			return *ptrA - *ptrB;

		ptrA = eptrA;
		ptrB = eptrB;
	}

	/* If both pointers are null, all alphanumeric
	 * characters were identical and only seperating
	 * characters differed. According to RPM, these
	 * version strings are equal */
	if (ptrA == endA && ptrB == endB)
		return 0;

	/* If A has unchecked characters, return 1
	 * Otherwise, if B has remaining unchecked characters,
	 * return -1 */
	if (ptrA != endA)
		return 1;
	else
		return -1;
}

/**
 * VERSION collation for sqlite3. This function collates text according to
 * pextlib's rpm-vercomp function. This allows direct comparison and sorting of
 * version columns, such as port.version and port.revision.
 *
 * @param [in] userdata unused
 * @param [in] alen     length of first string
 * @param [in] a        first string
 * @param [in] blen     length of second string
 * @param [in] b        second string
 * @return              -1 if a < b; 0 if a = b; 1 if a > b
 */
static int sql_version(void* userdata UNUSED, int alen, const void* a, int blen,
        const void* b) {
    return rpm_vercomp((const char*)a, alen, (const char*)b, blen);
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
            "id INTEGER PRIMARY KEY AUTOINCREMENT,"
            "name, portfile, url, location, epoch, version COLLATE VERSION, "
            "revision COLLATE VERSION, variants, default_variants, state, "
            "date, installtype, "
            "UNIQUE (name, epoch, version, revision, variants), "
            "UNIQUE (url, epoch, version, revision, variants)"
            ")",
        "CREATE INDEX registry.port_name ON ports "
            "(name, epoch, version, revision, variants)",
        "CREATE INDEX registry.port_url ON ports "
            "(url, epoch, version, revision, variants)",
        "CREATE INDEX registry.port_state ON ports (state)",

        /* file map */
        "CREATE TABLE registry.files (id, path, mtime)",
        "CREATE INDEX registry.file_port ON files (id)",

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

