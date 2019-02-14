/*
 * entry.c
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
#include <sqlite3.h>

#include <cregistry/util.h>

#include "entry.h"
#include "entryobj.h"
#include "registry.h"
#include "util.h"

/**
 * Converts a command name into a `reg_entry`.
 *
 * @param [in] interp  Tcl interpreter to check within
 * @param [in] name    name of entry to get
 * @param [out] errPtr description of error if the entry can't be found
 * @return             an entry, or NULL if one couldn't be found
 * @see get_object
 */
static reg_entry* get_entry(Tcl_Interp* interp, char* name, reg_error* errPtr) {
    return (reg_entry*)get_object(interp, name, "entry", entry_obj_cmd, errPtr);
}

/**
 * Removes the entry from the Tcl interpreter. Doesn't actually delete it since
 * that's the registry's job. This is written to be used as the
 * `Tcl_CmdDeleteProc` for an entry object command.
 *
 * @param [in] clientData address of a reg_entry to remove
 */
void delete_entry(ClientData clientData) {
    reg_entry* entry = (reg_entry*)clientData;
    free(entry->proc);
    entry->proc = NULL;
}

/*
static int obj_to_entry(Tcl_Interp* interp, reg_entry** entry, Tcl_Obj* obj,
        reg_error* errPtr) {
    reg_entry* result = get_entry(interp, Tcl_GetString(obj), errPtr);
    if (result == NULL) {
        return 0;
    } else {
        *entry = result;
        return 1;
    }
}

static int list_obj_to_entry(Tcl_Interp* interp, reg_entry*** entries,
        const Tcl_Obj** objv, int objc, reg_error* errPtr) {
    return recast(interp, (cast_function*)obj_to_entry, NULL, (void***)entries,
            (void**)objv, objc, errPtr);
}
*/


/*
 * registry::entry create portname version revision variants epoch
 *
 * Unlike the old registry::new_entry, revision, variants, and epoch are all
 * required. That's OK because there's only one place this function is called,
 * and it's called with all of them there.
 */
static int entry_create(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc != 7) {
        Tcl_WrongNumArgs(interp, 2, objv, "name version revision variants "
                "epoch");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else {
        char* name = Tcl_GetString(objv[2]);
        char* version = Tcl_GetString(objv[3]);
        char* revision = Tcl_GetString(objv[4]);
        char* variants = Tcl_GetString(objv[5]);
        char* epoch = Tcl_GetString(objv[6]);
        reg_error error;
        reg_entry* entry = reg_entry_create(reg, name, version, revision,
                variants, epoch, &error);
        if (entry != NULL) {
            Tcl_Obj* result;
            if (entry_to_obj(interp, &result, entry, NULL, &error)) {
                Tcl_SetObjResult(interp, result);
                return TCL_OK;
            }
        }
        return registry_failed(interp, &error);
    }
}

/*
 * registry::entry delete entry
 *
 * Deletes an entry from the registry (then closes it). If this is done within a
 * transaction and the transaction is rolled back, the entry will remain valid.
 */
static int entry_delete(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "delete entry");
        return TCL_ERROR;
    } if (reg == NULL) {
        return TCL_ERROR;
    } else {
        reg_error error;
        reg_entry* entry = get_entry(interp, Tcl_GetString(objv[2]), &error);
        entry_list** list_handle;
        if (entry == NULL) {
            return registry_failed(interp, &error);
        }
        if (!reg_entry_delete(entry, &error)) {
            return registry_failed(interp, &error);
        }
        /* if there's a transaction going on, record this entry in a list so we
         * can roll it back if necessary
         */
        list_handle = Tcl_GetAssocData(interp, "registry::deleted", NULL);
        if (list_handle) {
            entry_list* list = *list_handle;
            *list_handle = malloc(sizeof(entry_list));
            if (*list_handle) {
                (*list_handle)->entry = entry;
                (*list_handle)->next = list;
            } else {
                reg_entry_free(entry);
                return TCL_ERROR;
            }
        } else {
            reg_entry_free(entry);
        }
        Tcl_DeleteCommand(interp, Tcl_GetString(objv[2]));
        /* set flag so that the db will be vacuumed when we close it */
        Tcl_SetAssocData(interp, "registry::needs_vacuum", NULL, (ClientData)1);
        return TCL_OK;
    }
}

/*
 * registry::entry open portname version revision variants epoch ?name?
 *
 * Opens an entry matching the given parameters.
 */
static int entry_open(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc != 7) {
        Tcl_WrongNumArgs(interp, 1, objv, "open portname version revision "
                "variants epoch");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else {
        char* name = Tcl_GetString(objv[2]);
        char* version = Tcl_GetString(objv[3]);
        char* revision = Tcl_GetString(objv[4]);
        char* variants = Tcl_GetString(objv[5]);
        char* epoch = Tcl_GetString(objv[6]);
        reg_error error;
        reg_entry* entry = reg_entry_open(reg, name, version, revision,
                variants, epoch, &error);
        if (entry != NULL) {
            Tcl_Obj* result;
            if (entry_to_obj(interp, &result, entry, NULL, &error)) {
                Tcl_SetObjResult(interp, result);
                return TCL_OK;
            }
        }
        return registry_failed(interp, &error);
    }
    return TCL_ERROR;
}

/*
 * registry::entry close entry
 *
 * Closes an entry. It will remain in the registry until next time.
 */
static int entry_close(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "close entry");
        return TCL_ERROR;
    } else {
        reg_error error;
        char* proc = Tcl_GetString(objv[2]);
        reg_entry* entry = get_entry(interp, proc, &error);
        if (entry == NULL) {
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
 * registry::entry search ?key value ...?
 *
 * Searches the registry for ports for which each key's value is equal to the
 * given value. To find all ports, call `entry search` with no key-value pairs.
 * Can be given an option of -exact, -glob, -regexp or -null to specify the
 * matching strategy; defaults to exact.
 */
static int entry_search(Tcl_Interp* interp, int objc, Tcl_Obj* CONST *objv) {
    reg_registry *reg = registry_for(interp, reg_attached);
    if (!reg) {
        return TCL_ERROR;
    }
    const char **keys = malloc(objc * sizeof(char *));
    const char **vals = malloc(objc * sizeof(char *));
    int *strats = malloc(objc * sizeof(int));
    if (!keys || !vals || !strats) {
        goto cleanup_error;
    }
    int key_count = 0;

    /* Skip the "registry::entry" "search" bit */
    objv += 2;
    objc -= 2;

    for (int i = 0; i < objc; ++key_count /* i in incremented in the loop */) {
        int key_index, strategy_index;

        /* Grab the key */
        if (Tcl_GetIndexFromObj(interp, objv[i], entry_props, "search key",
            0, &key_index) != TCL_OK) {
            goto cleanup_error;
        }
        keys[key_count] = entry_props[key_index];
        if (objc <= ++i) {
            goto wrong_num_args; /* We're missing a strategy or value */
        }

        /* Set the default strategy, in case we don't find one */
        strats[key_count] = reg_strategy_exact;
        /* Try to grab the strategy */
        if (Tcl_GetIndexFromObjStruct(interp, objv[i], strategies,
                sizeof(strategy_type), "option", 0, &strategy_index) !=
                TCL_ERROR) {
            strats[key_count] = strategies[strategy_index].strategy;
            if (objc <= ++i && strats[key_count] != reg_strategy_null) {
                goto wrong_num_args;
            } else if (strats[key_count] == reg_strategy_null) {
                /* This doesn't take a value, so start from the top */
                continue;
            }
        }

        /* Grab the value */
        if (!(vals[key_count] = Tcl_GetString(objv[i++]))) {
            goto wrong_num_args; /* We're missing a value */
        }
    }

    reg_entry **entries;
    reg_error error;
    int entry_count;
    entry_count = reg_entry_search(reg, keys, vals, key_count, strats, &entries,
        &error);
    free(keys);
    free(vals);
    free(strats);

    if (entry_count >= 0) {
        int retval;
        Tcl_Obj* resultObj;
        Tcl_Obj** objs;
        if (list_entry_to_obj(interp, &objs, entries, entry_count, &error)){
            resultObj = Tcl_NewListObj(entry_count, objs);
            Tcl_SetObjResult(interp, resultObj);
            free(objs);
            retval = TCL_OK;
        } else {
            retval = registry_failed(interp, &error);
        }
        free(entries);
        return retval;
    } else {
        return registry_failed(interp, &error);
    }

wrong_num_args:
    Tcl_WrongNumArgs(interp, 2, objv,
            "search ?key ?options? value ...?");
cleanup_error:
    free(keys);
    free(vals);
    free(strats);
    return TCL_ERROR;
}

/*
 * registry::entry exists name
 *
 * Note that this is <i>not</i> the same as entry_exists from registry1.0. This
 * simply checks if the given string is a valid entry object in the current
 * interp. No query to the database will be made.
 */
static int entry_exists(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    reg_error error;
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "name");
        return TCL_ERROR;
    }
    if (get_entry(interp, Tcl_GetString(objv[2]), &error) == NULL) {
        reg_error_destruct(&error);
        Tcl_SetObjResult(interp, Tcl_NewBooleanObj(0));
    } else {
        Tcl_SetObjResult(interp, Tcl_NewBooleanObj(1));
    }
    return TCL_OK;
}

/*
 * registry::entry imaged ?name? ?version?
 *
 * Returns a list of all ports installed as images and/or active in the
 * filesystem. If `name` is specified, only returns ports with that name, and if
 * `version` is specified, only with that version. Remember, the variants can
 * still be different, so specifying both places no constraints on the number
 * of returned values.
 *
 * Note that this command corresponds to installed ports in 'image' mode and has
 * no analogue in 'direct' mode (it will be equivalent to `registry::entry
 * installed`). That is, these ports are available but cannot meet dependencies.
 *
 * I would have liked to allow implicit variants, but there's no convenient way
 * to distinguish between variants not being specified and being specified as
 * empty. So, if a revision is specified, so must variants be.
 *
 * TODO: add more arguments (epoch, revision, variants), maybe
 */
static int entry_imaged(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc == 5 || objc > 6) {
        Tcl_WrongNumArgs(interp, 2, objv, "?name ?version ?revision variants???");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else {
        const char* name = (objc >= 3) ? string_or_null(objv[2]) : NULL;
        const char* version = (objc >= 4) ? string_or_null(objv[3]) : NULL;
        const char* revision = (objc >= 6) ? string_or_null(objv[4]) : NULL;
        const char* variants = (revision != 0) ? Tcl_GetString(objv[5]) : NULL;
        reg_entry** entries;
        reg_error error;
        int entry_count;
        entry_count = reg_entry_imaged(reg, name, version, revision, variants,
                &entries, &error);
        if (entry_count >= 0) {
            Tcl_Obj** objs;
            if (list_entry_to_obj(interp, &objs, entries, entry_count, &error)) {
                Tcl_Obj* resultObj = Tcl_NewListObj(entry_count, objs);
                Tcl_SetObjResult(interp, resultObj);
                free(entries);
                free(objs);
                return TCL_OK;
            }
            free(entries);
        }
        return registry_failed(interp, &error);
    }
}

/*
 * registry::entry installed ?name?
 *
 * Returns a list of all installed and active ports. If `name` is specified,
 * only returns the active port named, but still in a list. Treating it as
 * a single item will probably work but is bad form.
 *
 * Note that this command corresponds to active ports in 'image' mode and
 * installed ports in 'direct' mode. That is, any port which is capable of
 * satisfying a dependency.
 */
static int entry_installed(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]){
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc > 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "?name?");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else {
        char* name = (objc == 3) ? Tcl_GetString(objv[2]) : NULL;
        reg_entry** entries;
        reg_error error;
        int entry_count;
        /* name of "" means not specified */
        if (name != NULL && *name == '\0') {
            name = NULL;
        }
        entry_count = reg_entry_installed(reg, name, &entries, &error);
        if (entry_count >= 0) {
            Tcl_Obj** objs;
            if (list_entry_to_obj(interp, &objs, entries, entry_count, &error)) {
                Tcl_Obj* resultObj = Tcl_NewListObj(entry_count, objs);
                Tcl_SetObjResult(interp, resultObj);
                free(entries);
                free(objs);
                return TCL_OK;
            }
            free(entries);
        }
        return registry_failed(interp, &error);
    }
}


/*
 * registry::entry owner filename [cs = true]
 *
 * Returns the port that owns the given filename (empty string if none).
 */
static int entry_owner(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    int cs = 1;

    if ((objc < 3) || (objc > 4)) {
        Tcl_WrongNumArgs(interp, 2, objv, "path ?cs?");
        return TCL_ERROR;
    }

    if (objc == 4) {
        if (Tcl_GetBooleanFromObj(interp, objv[3], &cs) != TCL_OK) {
            return TCL_ERROR;
        }
    }

    if (reg == NULL) {
        return TCL_ERROR;
    } else {
        char* path = Tcl_GetString(objv[2]);
        reg_entry* entry;
        reg_error error;
        if (reg_entry_owner(reg, path, cs, &entry, &error)) {
            if (entry == NULL) {
                return TCL_OK;
            } else {
                Tcl_Obj* result;
                if (entry_to_obj(interp, &result, entry, NULL, &error)) {
                    Tcl_SetObjResult(interp, result);
                    return TCL_OK;
                }
            }
        }
        return registry_failed(interp, &error);
    }
}

typedef struct {
    char* name;
    int (*function)(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
} entry_cmd_type;

static entry_cmd_type entry_cmds[] = {
    /* Global commands */
    { "create", entry_create },
    { "delete", entry_delete },
    { "open", entry_open },
    { "close", entry_close },
    { "search", entry_search },
    { "exists", entry_exists },
    { "imaged", entry_imaged },
    { "installed", entry_installed },
    { "owner", entry_owner },
    { NULL, NULL }
};

/*
 * registry::entry cmd ?arg ...?
 *
 * Commands manipulating port entries in the registry. This could be called
 * `registry::port`, but that could be misleading, because `registry::item`
 * represents ports too, but not those in the registry.
 */
int entry_cmd(ClientData clientData UNUSED, Tcl_Interp* interp, int objc,
        Tcl_Obj* CONST objv[]) {
    int cmd_index;
    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "cmd ?arg ...?");
        return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObjStruct(interp, objv[1], entry_cmds,
                sizeof(entry_cmd_type), "cmd", 0, &cmd_index) == TCL_OK) {
        entry_cmd_type* cmd = &entry_cmds[cmd_index];
        return cmd->function(interp, objc, objv);
    }
    return TCL_ERROR;
}
