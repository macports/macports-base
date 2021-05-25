/*
 * util.c
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

#include <string.h>
#include <stdlib.h>
#include <tcl.h>

#include "util.h"
#include "entryobj.h"
#include "fileobj.h"
#include "portgroupobj.h"

/**
 * Generates a unique proc name starting with prefix.
 *
 * This function loops through the integers trying to find a name
 * "<prefix><int>" such that no command with that name exists within the given
 * Tcl interp context. This behavior is similar to that of the builtin
 * `interp create` command, and is intended to generate names for created
 * objects of a similar nature.
 */
char* unique_name(Tcl_Interp* interp, char* prefix, unsigned int* lower_bound) {
    size_t result_size = strlen(prefix) + TCL_INTEGER_SPACE + 1;
    char* result = malloc(result_size);
    Tcl_CmdInfo info;
    unsigned int i;
    if (!result)
        return NULL;
    if (lower_bound == NULL) {
        i = 0;
    } else {
        i = *lower_bound;
    }
    /* XXX Technically an infinite loop if all possible names are taken
       - just assuming we won't use up all 4 billion, since performance
       is going to become abysmal before we get there anyway. */
    for (; ; i++) {
        snprintf(result, result_size, "%s%d", prefix, i);
        if (Tcl_GetCommandInfo(interp, result, &info) == 0) {
            break;
        }
    }
    if (lower_bound != NULL) {
        *lower_bound = i + 1;
    }
    return result;
}

/**
 * Parses flags given to a Tcl command.
 *
 * Starting at `objv[start]`, this function will loop through the remaining
 * arguments until a non-flag argument is found, or an END_FLAGS flag is found,
 * or an invalid flag is found. In the first two cases, TCL_OK will be returned
 * and `start` will be moved to the first non-flag argument; in the third,
 * TCL_ERROR will be returned.
 *
 * It is recommended that all callers of this function include the entry
 * `{ "--", END_FLAGS }` in the NULL-terminated list `options`. For other,
 * non-zero flag values in `options`, flags will be bitwise or'ed by that value.
 *
 * Note that `alpha -beta gamma -delta epsilon` will be recognized as three
 * arguments following one flag. This could be changed but would make things
 * much more difficult.
 *
 * TODO: support flags of the form ?-flag value?. No functions currently have a
 * use for this yet, so it's not a priority, but it should be there for
 * completeness.
 */
int parse_flags(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[], int* start,
        option_spec options[], int* flags) {
    int i;
    int index;
    *flags = 0;
    for (i=*start; i<objc; i++) {
        if (Tcl_GetString(objv[i])[0] != '-') {
            break;
        }
        if (Tcl_GetIndexFromObjStruct(interp, objv[i], options,
                    sizeof(option_spec), "option", 0, &index) == TCL_OK) {
            if (options[index].flag == END_FLAGS) {
                i++;
                break;
            } else {
                *flags |= options[index].flag;
            }
        } else {
            return TCL_ERROR;
        }
    }
    *start = i;
    return TCL_OK;
}

/**
 * Retrieves the object whose proc is named by `name`.
 *
 * A common design pattern is to have an object be a proc whose clientData
 * points to the object and whose function points to an object function. This
 * function retrieves such an object.
 *
 * `proc` is used to verify that a proc names an instance of the object. If not,
 * `type` is used to construct an appropriate error message before it returns
 * NULL.
 */
void* get_object(Tcl_Interp* interp, char* name, char* type,
        Tcl_ObjCmdProc* proc, reg_error* errPtr) {
    Tcl_CmdInfo info;
    if (Tcl_GetCommandInfo(interp, name, &info) && info.objProc == proc){
        return info.objClientData;
    } else {
        errPtr->code = "registry::not-found";
        errPtr->description = sqlite3_mprintf("could not find %s \"%s\"", type,
                name);
        errPtr->free = (reg_error_destructor*)sqlite3_free;
        return NULL;
    }
}

/**
 * Sets the object whose proc is named by `name`.
 *
 * See the documentation for `get_object`. This function registers such an
 * object, and additionally requires the `deleteProc` argument, which will be
 * used to free the object.
 *
 * TODO: cause the error used here not to leak memory. This probably needs to be
 *       addressed as a generic "reg_error_free" routine
 */
int set_object(Tcl_Interp* interp, char* name, void* value, char* type,
        Tcl_ObjCmdProc* proc, Tcl_CmdDeleteProc* deleteProc, reg_error* errPtr){
    Tcl_CmdInfo info;
    if (Tcl_GetCommandInfo(interp, name, &info) && info.objProc == proc) {
        errPtr->code = "registry::duplicate-object";
        errPtr->description = sqlite3_mprintf("%s named \"%s\" already exists, "
                "cannot create", type, name);
        errPtr->free = (reg_error_destructor*)sqlite3_free;
        return 0;
    }
    Tcl_CreateObjCommand(interp, name, proc, value, deleteProc);
    return 1;
}

/**
 * Sets a given name to be an entry object.
 *
 * @param [in] interp  Tcl interpreter to create the entry within
 * @param [in] name    name to associate the given entry with
 * @param [in] entry   entry to associate with the given name
 * @param [out] errPtr description of error if it couldn't be set
 * @return             true if success; false if failure
 * @see set_object
 */
int set_entry(Tcl_Interp* interp, char* name, reg_entry* entry,
        reg_error* errPtr) {
    if (set_object(interp, name, entry, "entry", entry_obj_cmd, NULL,
                errPtr)) {
        entry->proc = strdup(name);
        if (!entry->proc) {
            return 0;
        }
        return 1;
    }
    return 0;
}

/**
 * Sets a given name to be a file object.
 *
 * @param [in] interp  Tcl interpreter to create the file within
 * @param [in] name    name to associate the given file with
 * @param [in] file    file to associate with the given name
 * @param [out] errPtr description of error if it couldn't be set
 * @return             true if success; false if failure
 * @see set_object
 */
int set_file(Tcl_Interp* interp, char* name, reg_file* file,
        reg_error* errPtr) {
    if (set_object(interp, name, file, "file", file_obj_cmd, NULL,
                errPtr)) {
        file->proc = strdup(name);
        if (!file->proc) {
            return 0;
        }
        return 1;
    }
    return 0;
}

/**
 * Sets a given name to be a portgroup object.
 *
 * @param [in] interp  Tcl interpreter to create the portgroup within
 * @param [in] name    name to associate the given portgroup with
 * @param [in] portgroup    portgroup to associate with the given name
 * @param [out] errPtr description of error if it couldn't be set
 * @return             true if success; false if failure
 * @see set_object
 */
int set_portgroup(Tcl_Interp* interp, char* name, reg_portgroup* portgroup,
        reg_error* errPtr) {
    if (set_object(interp, name, portgroup, "portgroup", portgroup_obj_cmd, NULL,
                errPtr)) {
        portgroup->proc = strdup(name);
        if (!portgroup->proc) {
            return 0;
        }
        return 1;
    }
    return 0;
}

/**
 * Reports a sqlite3 error to Tcl.
 *
 * Queries the database for the most recent error message and sets it as the
 * result of the given interpreter. If a query is optionally passed, also
 * records what it was.
 */
void set_sqlite_result(Tcl_Interp* interp, sqlite3* db, const char* query) {
    Tcl_ResetResult(interp);
    Tcl_SetErrorCode(interp, "registry::sqlite-error", NULL);
    if (query == NULL) {
        Tcl_AppendResult(interp, "sqlite error: ", sqlite3_errmsg(db), NULL);
    } else {
        Tcl_AppendResult(interp, "sqlite error executing \"", query, "\": ",
                sqlite3_errmsg(db), NULL);
    }
}

const char* string_or_null(Tcl_Obj* obj) {
    const char* string = Tcl_GetString(obj);
    if (string[0] == '\0') {
        return NULL;
    } else {
        return string;
    }
}

int recast(void* userdata, cast_function* fn, void* castcalldata,
        free_function* del, void*** outv, void** inv, int inc,
        reg_error* errPtr) {
    void** result = malloc((size_t)inc*sizeof(void*));
    int i;
    if (!result) {
        return 0;
    }
    for (i=0; i<inc; i++) {
        if (!fn(userdata, &result[i], inv[i], castcalldata, errPtr)) {
            if (del != NULL) {
                for ( ; i>=0; i--) {
                    del(userdata, result[i]);
                }
            }
            free(result);
            return 0;
        }
    }
    *outv = result;
    return 1;
}

int entry_to_obj(Tcl_Interp* interp, Tcl_Obj** obj, reg_entry* entry,
        void* param UNUSED, reg_error* errPtr) {
    static unsigned int lower_bound = 0;
    if (entry->proc == NULL) {
        char* name = unique_name(interp, "::registry::entry", &lower_bound);
        if (!name) {
            return 0;
        }
        if (!set_entry(interp, name, entry, errPtr)) {
            free(name);
            return 0;
        }
        free(name);
    }
    *obj = Tcl_NewStringObj(entry->proc, -1);
    return 1;
}

int file_to_obj(Tcl_Interp* interp, Tcl_Obj** obj, reg_file* file,
        void* param UNUSED, reg_error* errPtr) {
    static unsigned int lower_bound = 0;
    if (file->proc == NULL) {
        char* name = unique_name(interp, "::registry::file", &lower_bound);
        if (!name) {
            return 0;
        }
        if (!set_file(interp, name, file, errPtr)) {
            free(name);
            return 0;
        }
        free(name);
    }
    *obj = Tcl_NewStringObj(file->proc, -1);
    return 1;
}

int portgroup_to_obj(Tcl_Interp* interp, Tcl_Obj** obj, reg_portgroup* portgroup,
        void* param UNUSED, reg_error* errPtr) {
    static unsigned int lower_bound = 0;
    if (portgroup->proc == NULL) {
        char* name = unique_name(interp, "::registry::portgroup", &lower_bound);
        if (!name) {
            return 0;
        }
        if (!set_portgroup(interp, name, portgroup, errPtr)) {
            free(name);
            return 0;
        }
        free(name);
    }
    *obj = Tcl_NewStringObj(portgroup->proc, -1);
    return 1;
}

int list_entry_to_obj(Tcl_Interp* interp, Tcl_Obj*** objs,
        reg_entry** entries, int entry_count, reg_error* errPtr) {
    return recast(interp, (cast_function*)entry_to_obj, NULL, NULL,
            (void***)objs, (void**)entries, entry_count, errPtr);
}

int list_file_to_obj(Tcl_Interp* interp, Tcl_Obj*** objs,
        reg_file** files, int file_count, reg_error* errPtr) {
    return recast(interp, (cast_function*)file_to_obj, NULL, NULL,
            (void***)objs, (void**)files, file_count, errPtr);
}

int list_portgroup_to_obj(Tcl_Interp* interp, Tcl_Obj*** objs,
        reg_portgroup** portgroups, int portgroup_count, reg_error* errPtr) {
    return recast(interp, (cast_function*)portgroup_to_obj, NULL, NULL,
            (void***)objs, (void**)portgroups, portgroup_count, errPtr);
}

static int obj_to_string(void* userdata UNUSED, char** string, Tcl_Obj* obj,
        void* param UNUSED, reg_error* errPtr UNUSED) {
    *string = Tcl_GetString(obj);
    return 1;
}

int list_obj_to_string(char*** strings, Tcl_Obj** objv, int objc,
        reg_error* errPtr) {
    return recast(NULL, (cast_function*)obj_to_string, NULL, NULL, (void***)strings,
            (void**)objv, objc, errPtr);
}

static int string_to_obj(void* userdata UNUSED, Tcl_Obj** obj, char* string,
        void* param UNUSED, reg_error* errPtr UNUSED) {
    *obj = Tcl_NewStringObj(string, -1);
    return 1;
}

static void free_obj(void* userdata UNUSED, Tcl_Obj* obj) {
    Tcl_DecrRefCount(obj);
}

int list_string_to_obj(Tcl_Obj*** objv, char** strings, int objc,
        reg_error* errPtr) {
    return recast(NULL, (cast_function*)string_to_obj, NULL, (free_function*)free_obj,
            (void***)objv, (void**)strings, objc, errPtr);
}
