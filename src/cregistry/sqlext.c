#if HAVE_CONFIG_H
#include <config.h>
#endif

#include "vercomp.h"

#include <string.h>
#if HAVE_SQLITE3EXT_H
#include <sqlite3ext.h>
SQLITE_EXTENSION_INIT1
#else
#include <sqlite3.h>
#endif

/**
 * Extension for sqlite3 defining collates being used in our DB. This can be
 * used by any sqlite3 client to load the required collates.
 *
 * @param [in] db         database connection
 * @param [out] pzErrMsg  error messages string
 * @param [in] pApi       API methods
 */
int sqlite3_extension_init(
    sqlite3 *db,          /* The database connection */
    char **pzErrMsg UNUSED,      /* Write error messages here */
#if HAVE_SQLITE3EXT_H
    const sqlite3_api_routines *pApi  /* API methods */
#else
    const void *pApi
#endif
) {
#if HAVE_SQLITE3EXT_H
    SQLITE_EXTENSION_INIT2(pApi)

    sqlite3_create_collation(db, "VERSION", SQLITE_UTF8, NULL, sql_version);
#endif
    return 0;
}
