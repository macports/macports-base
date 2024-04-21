/*
 * tdbc.c --
 *
 *	Basic services for TDBC (Tcl DataBase Connectivity)
 *
 * Copyright (c) 2008 by Kevin B. Kenny.
 *
 * Please refer to the file, 'license.terms' for the conditions on
 * redistribution of this file and for a DISCLAIMER OF ALL WARRANTIES.
 *
 * RCS: @(#) $Id$
 *
 *-----------------------------------------------------------------------------
 */

#include <tcl.h>
#include <string.h>
#include "tdbcInt.h"
#include "tdbcUuid.h"

/* Static procedures declared in this file */

static int TdbcMapSqlStateObjCmd(void *unused, Tcl_Interp* interp,
				 int objc, Tcl_Obj *const objv[]);

MODULE_SCOPE const TdbcStubs tdbcStubs;

/* Table of commands to create for TDBC */

static const struct TdbcCommand {
    const char* name;		/* Name of the command */
    Tcl_ObjCmdProc* proc;	/* Command procedure */
} commandTable[] = {
    { "::tdbc::mapSqlState",	TdbcMapSqlStateObjCmd },
    { "::tdbc::tokenize", 	TdbcTokenizeObjCmd },
    { NULL, 		  	NULL               },
};

/* Table mapping SQLSTATE to error code */

static const struct SqlStateLookup {
    const char* stateclass;
    const char* message;
} StateLookup [] = {
    { "00", "UNQUALIFIED_SUCCESSFUL_COMPLETION" },
    { "01", "WARNING" },
    { "02", "NO_DATA" },
    { "07", "DYNAMIC_SQL_ERROR" },
    { "08", "CONNECTION_EXCEPTION" },
    { "09", "TRIGGERED_ACTION_EXCEPTION" },
    { "0A", "FEATURE_NOT_SUPPORTED" },
    { "0B", "INVALID_TRANSACTION_INITIATION" },
    { "0D", "INVALID_TARGET_TYPE_SPECIFICATION" },
    { "0F", "LOCATOR_EXCEPTION" },
    { "0K", "INVALID_RESIGNAL_STATEMENT" },
    { "0L", "INVALID_GRANTOR" },
    { "0P", "INVALID_ROLE_SPECIFICATION" },
    { "0W", "INVALID_STATEMENT_UN_TRIGGER" },
    { "20", "CASE_NOT_FOUND_FOR_CASE_STATEMENT" },
    { "21", "CARDINALITY_VIOLATION" },
    { "22", "DATA_EXCEPTION" },
    { "23", "CONSTRAINT_VIOLATION" },
    { "24", "INVALID_CURSOR_STATE" },
    { "25", "INVALID_TRANSACTION_STATE" },
    { "26", "INVALID_SQL_STATEMENT_IDENTIFIER" },
    { "27", "TRIGGERED_DATA_CHANGE_VIOLATION" },
    { "28", "INVALID_AUTHORIZATION_SPECIFICATION" },
    { "2B", "DEPENDENT_PRIVILEGE_DESCRIPTORS_STILL_EXIST" },
    { "2C", "INVALID_CHARACTER_SET_NAME" },
    { "2D", "INVALID_TRANSACTION_TERMINATION" },
    { "2E", "INVALID_CONNECTION_NAME" },
    { "2F", "SQL_ROUTINE_EXCEPTION" },
    { "33", "INVALID_SQL_DESCRIPTOR_NAME" },
    { "34", "INVALID_CURSOR_NAME" },
    { "35", "INVALID_CONDITION_NUMBER" },
    { "36", "CURSOR_SENSITIVITY_EXCEPTION" },
    { "37", "SYNTAX_ERROR_OR_ACCESS_VIOLATION" },
    { "38", "EXTERNAL_ROUTINE_EXCEPTION" },
    { "39", "EXTERNAL_ROUTINE_INVOCATION_EXCEPTION" },
    { "3B", "SAVEPOINT_EXCEPTION" },
    { "3C", "AMBIGUOUS_CURSOR_NAME" },
    { "3D", "INVALID_CATALOG_NAME" },
    { "3F", "INVALID_SCHEMA_NAME" },
    { "40", "TRANSACTION_ROLLBACK" },
    { "42", "SYNTAX_ERROR_OR_ACCESS_RULE_VIOLATION" },
    { "44", "WITH_CHECK_OPTION_VIOLATION" },
    { "45", "UNHANDLED_USER_DEFINED_EXCEPTION" },
    { "46", "JAVA_DDL" },
    { "51", "INVALID_APPLICATION_STATE" },
    { "53", "INSUFFICIENT_RESOURCES" },
    { "54", "PROGRAM_LIMIT_EXCEEDED" },
    { "55", "OBJECT_NOT_IN_PREREQUISITE_STATE" },
    { "56", "MISCELLANEOUS_SQL_OR_PRODUCT_ERROR" },
    { "57", "RESOURCE_NOT_AVAILABLE_OR_OPERATOR_INTERVENTION" },
    { "58", "SYSTEM_ERROR" },
    { "70", "INTERRUPTED" },
    { "F0", "CONFIGURATION_FILE_ERROR" },
    { "HY", "GENERAL_ERROR" },
    { "HZ", "REMOTE_DATABASE_ACCESS_ERROR" },
    { "IM", "DRIVER_ERROR" },
    { "P0", "PGSQL_PLSQL_ERROR" },
    { "S0", "ODBC_2_0_DML_ERROR" },
    { "S1", "ODBC_2_0_GENERAL_ERROR" },
    { "XA", "TRANSACTION_ERROR" },
    { "XX", "INTERNAL_ERROR" },
    { NULL, NULL }
};

/*
 *-----------------------------------------------------------------------------
 *
 * Tdbc_MapSqlState --
 *
 *	Maps the 'sqlstate' return from a database error to a key
 *	to place in the '::errorCode' variable.
 *
 * Results:
 *	Returns the key.
 *
 * This procedure examines only the first two characters of 'sqlstate',
 * which are fairly portable among databases. The remaining three characters
 * are ignored. The result is that state '22012' (Division by zero)
 * is returned as 'data exception', while state '23505' (Unique key
 * constraint violation) is returned as 'constraint violation'.
 *
 *-----------------------------------------------------------------------------
 */
TDBCAPI const char*
Tdbc_MapSqlState(const char* sqlstate)
{
    size_t i;
    for (i = 0; StateLookup[i].stateclass != NULL; ++i) {
	if (!strncmp(sqlstate, StateLookup[i].stateclass, 2)) {
	    return StateLookup[i].message;
	}
    }
    return "UNKNOWN_SQLSTATE";
}

/*
 *-----------------------------------------------------------------------------
 *
 * TdbcMapSqlStateObjCmd --
 *
 *	Command to call from a Tcl script to get a string that describes
 *	a SQLSTATE
 *
 * Usage:
 *	tdbc::mapSqlState state
 *
 * Parameters:
 *	state -- A five-character SQLSTATE
 *
 * Results:
 *	Returns a one-word token suitable for interpolating into
 *	errorInfo
 *
 *-----------------------------------------------------------------------------
 */

static int
TdbcMapSqlStateObjCmd(
    TCL_UNUSED(void *),		/* No client data */
    Tcl_Interp* interp,		/* Tcl interpreter */
    int objc,			/* Parameter count */
    Tcl_Obj *const objv[]	/* Parameter vector */
) {
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "sqlstate");
	return TCL_ERROR;
    } else {
	const char* sqlstate = Tcl_GetString(objv[1]);
	Tcl_SetObjResult(interp, Tcl_NewStringObj(Tdbc_MapSqlState(sqlstate),
						  -1));
	return TCL_OK;
    }
}

/*
 *-----------------------------------------------------------------------------
 *
 * Tdbc_Init --
 *
 *	Initializes the TDBC framework when this library is loaded.
 *
 * Side effects:
 *
 *	Creates a ::tdbc namespace and a ::tdbc::Connection class
 *	from which the connection objects created by a TDBC driver
 *	may inherit.
 *
 *-----------------------------------------------------------------------------
 */

#ifndef STRINGIFY
#  define STRINGIFY(x) STRINGIFY1(x)
#  define STRINGIFY1(x) #x
#endif

#ifdef __cplusplus
extern "C" {
#endif  /* __cplusplus */
DLLEXPORT int
Tdbc_Init(
    Tcl_Interp* interp		/* Tcl interpreter */
) {

    size_t i;
    Tcl_CmdInfo info;

    /* Require Tcl */

    if (Tcl_InitStubs(interp, "8.5-", 0) == NULL) {
	return TCL_ERROR;
    }

    /* Create the provided commands */

    for (i = 0; commandTable[i].name != NULL; ++i) {
	Tcl_CreateObjCommand(interp, commandTable[i].name, commandTable[i].proc,
			     NULL, NULL);
    }
    if (Tcl_GetCommandInfo(interp, "::tcl::build-info", &info)) {
	Tcl_CreateObjCommand(interp, "::tdbc::build-info",
		info.objProc, (void *)(
		    PACKAGE_VERSION "+" STRINGIFY(TDBC_VERSION_UUID)
#if defined(__clang__) && defined(__clang_major__)
			    ".clang-" STRINGIFY(__clang_major__)
#if __clang_minor__ < 10
			    "0"
#endif
			    STRINGIFY(__clang_minor__)
#endif
#if defined(__cplusplus) && !defined(__OBJC__)
			    ".cplusplus"
#endif
#ifndef NDEBUG
			    ".debug"
#endif
#if !defined(__clang__) && !defined(__INTEL_COMPILER) && defined(__GNUC__)
			    ".gcc-" STRINGIFY(__GNUC__)
#if __GNUC_MINOR__ < 10
			    "0"
#endif
			    STRINGIFY(__GNUC_MINOR__)
#endif
#ifdef __INTEL_COMPILER
			    ".icc-" STRINGIFY(__INTEL_COMPILER)
#endif
#ifdef TCL_MEM_DEBUG
			    ".memdebug"
#endif
#if defined(_MSC_VER)
			    ".msvc-" STRINGIFY(_MSC_VER)
#endif
#ifdef USE_NMAKE
			    ".nmake"
#endif
#ifndef TCL_CFG_OPTIMIZED
			    ".no-optimize"
#endif
#ifdef __OBJC__
			    ".objective-c"
#if defined(__cplusplus)
			    "plusplus"
#endif
#endif
#ifdef TCL_CFG_PROFILED
			    ".profile"
#endif
#ifdef PURIFY
			    ".purify"
#endif
#ifdef STATIC_BUILD
			    ".static"
#endif
		), NULL);
    }

    /* Provide the TDBC package */

    if (Tcl_PkgProvideEx(interp, PACKAGE_NAME, PACKAGE_VERSION,
			 (void *) &tdbcStubs) == TCL_ERROR) {
	return TCL_ERROR;
    }

    return TCL_OK;

}

#ifdef __cplusplus
}
#endif  /* __cplusplus */
