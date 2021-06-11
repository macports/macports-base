/*
 * file.c
 * vim:tw=80:expandtab
 *
 * Copyright (c) 2011 Clemens Lang <cal@macports.org>
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

#include <sqlite3.h>
#include <stdlib.h>
#include <string.h>
#include <tcl.h>

#include <cregistry/file.h>
#include <cregistry/util.h>

#include "file.h"
#include "fileobj.h"
#include "registry.h"
#include "util.h"

/**
 * Converts a command name into a `reg_file`.
 *
 * @param [in] interp  Tcl interpreter to check within
 * @param [in] name    name of file to get
 * @param [out] errPtr description of error if the file can't be found
 * @return             a file, or NULL if one couldn't be found
 * @see get_object
 */
static reg_file* get_file(Tcl_Interp* interp, char* name, reg_error* errPtr) {
    return (reg_file*)get_object(interp, name, "file", file_obj_cmd, errPtr);
}

/**
 * Removes the file from the Tcl interpreter. Doesn't actually delete it since
 * that's the registry's job. This is written to be used as the
 * `Tcl_CmdDeleteProc` for an file object command.
 *
 * @param [in] clientData address of a reg_file to remove
 */
void delete_file(ClientData clientData) {
    reg_file* file = (reg_file*)clientData;
    free(file->proc);
    free(file->key.path);
    file->proc = NULL;
}

/**
 * registry::file open portid path
 *
 * Opens a file matching the given parameters.
 */
static int file_open(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
	reg_registry* reg = registry_for(interp, reg_attached);
	if (objc != 4) {
		Tcl_WrongNumArgs(interp, 1, objv, "open portid path");
		return TCL_ERROR;
	} else if (reg == NULL) {
		return TCL_ERROR;
	} else {
		char* id = Tcl_GetString(objv[2]);
		char* path = Tcl_GetString(objv[3]);
		reg_error error;
		reg_file* file = reg_file_open(reg, id, path, &error);
		if (file != NULL) {
			Tcl_Obj* result;
			if (file_to_obj(interp, &result, file, NULL, &error)) {
				Tcl_SetObjResult(interp, result);
				return TCL_OK;
			}
		}
		return registry_failed(interp, &error);
	}
	return TCL_ERROR;
}

/**
 * registry::file close file
 *
 * Closes a file. It will remain in the registry.
 */
static int file_close(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
	if (objc != 3) {
		Tcl_WrongNumArgs(interp, 1, objv, "close file");
		return TCL_ERROR;
	} else {
		reg_error error;
		char* proc = Tcl_GetString(objv[2]);
		reg_file* file = get_file(interp, proc, &error);
		if (file == NULL) {
			return registry_failed(interp, &error);
		} else {
			Tcl_DeleteCommand(interp, proc);
			return TCL_OK;
		}
	}
}

typedef struct {
    char* name;
    reg_strategy strategy;
} strategy_type;

static strategy_type strategies[] = {
    { "-exact",  reg_strategy_exact },
    { "-glob",   reg_strategy_glob },
    { "-regexp", reg_strategy_regexp },
    { "-null",   reg_strategy_null },
    { "--",      reg_strategy_exact },
    { NULL, 0 }
};

/*
 * registry::file search ?key value ...?
 *
 * Searches the registry for files for which each key's value is equal to the
 * given value. To find all files, call `file search` with no key-value pairs.
 * For each key, can be given an option of -exact, -glob, -regexp or -null to
 * specify the matching strategy; defaults to exact.
 */
static int file_search(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    int i, j;
    reg_registry* reg = registry_for(interp, reg_attached);
    if (reg == NULL) {
        return TCL_ERROR;
    } else {
        char** keys;
        char** vals;
        int* strats;
        int key_count = 0;
        reg_file** files;
        reg_error error;
        int file_count;
        for (i = 2; i < objc;) {
            int index, strat_index, val_length;
            if (Tcl_GetIndexFromObj(interp, objv[i], file_props, "search key",
                        0, &index) != TCL_OK) {
                return TCL_ERROR;
            }

            /* we ate the key value */
            i++;

            /* check whether there's a strategy */
            if (Tcl_GetString(objv[i])[0] == '-'
                    && Tcl_GetIndexFromObjStruct(interp, objv[i], strategies,
                        sizeof(strategy_type), "option", 0, &strat_index)
                    != TCL_ERROR) {
                /* this key has a strategy specified, eat the strategy parameter */
                i++;

                if (strategies[strat_index].strategy != reg_strategy_null) {
                    /* this key must also have a value */

                    if (Tcl_GetStringFromObj(objv[i], &val_length) == NULL
                            || val_length == 0) {
                        Tcl_WrongNumArgs(interp, 2, objv,
                                "search ?key ?options? value ...?");
                        return TCL_ERROR;
                    }

                    i++;
                }
            } else {
                /* this key must also have a value */

                if (Tcl_GetStringFromObj(objv[i], &val_length) == NULL
                        || val_length == 0) {
                    Tcl_WrongNumArgs(interp, 2, objv,
                            "search ?key ?options? value ...?");
                    return TCL_ERROR;
                }

                i++;
            }

            key_count++;
        }

        keys = malloc(key_count * sizeof(char*));
        vals = malloc(key_count * sizeof(char*));
        strats = malloc(key_count * sizeof(int));
        if (!keys || !vals || !strats) {
            if (keys) {
                free(keys);
            }
            if (vals) {
                free(vals);
            }
            if (strats) {
                free(strats);
            }
            return TCL_ERROR;
        }
        for (i = 2, j = 0; i < objc && j < key_count; j++) {
            int strat_index;

            keys[j] = Tcl_GetString(objv[i++]);

            /* try to get the strategy */
            if (Tcl_GetString(objv[i])[0] == '-'
                    && Tcl_GetIndexFromObjStruct(interp, objv[i], strategies,
                        sizeof(strategy_type), "option", 0, &strat_index)
                    != TCL_ERROR) {
                /* this key has a strategy specified */
                i++;

                strats[j] = strategies[strat_index].strategy;
            } else {
                /* use default strategy */
                strats[j] = reg_strategy_exact;
            }

            if (strats[j] != reg_strategy_null) {
                vals[j] = Tcl_GetString(objv[i++]);
            } else {
                vals[j] = NULL;
            }
        }
        file_count = reg_file_search(reg, keys, vals, strats, key_count,
                &files, &error);
        free(keys);
        free(vals);
        free(strats);
        if (file_count >= 0) {
            int retval;
            Tcl_Obj* resultObj;
            Tcl_Obj** objs;
            if (list_file_to_obj(interp, &objs, files, file_count, &error)){
                resultObj = Tcl_NewListObj(file_count, objs);
                Tcl_SetObjResult(interp, resultObj);
                free(objs);
                retval = TCL_OK;
            } else {
                retval = registry_failed(interp, &error);
            }
            free(files);
            return retval;
        }
        return registry_failed(interp, &error);
    }
}

typedef struct {
    char* name;
    int (*function)(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
} file_cmd_type;

static file_cmd_type file_cmds[] = {
    /* Global commands */
    { "open", file_open },
    { "close", file_close },
    { "search", file_search },
    { NULL, NULL }
};

/*
 * registry::file cmd ?arg ...?
 *
 * Commands manipulating file entries in the registry. This can be called `registry::file`
 */
int file_cmd(ClientData clientData UNUSED, Tcl_Interp* interp, int objc,
        Tcl_Obj* CONST objv[]) {
    int cmd_index;
    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "cmd ?arg ...?");
        return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObjStruct(interp, objv[1], file_cmds,
                sizeof(file_cmd_type), "cmd", 0, &cmd_index) == TCL_OK) {
        file_cmd_type* cmd = &file_cmds[cmd_index];
        return cmd->function(interp, objc, objv);
    }
    return TCL_ERROR;
}
