/*
 * registry.c
 *
 * Copyright (c) 2007 Chris Pickel <sfiera@macports.org>
 * Copyright (c) 2012, 2014 The MacPorts Project
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <tcl.h>

#include <cregistry/registry.h>
#include <cregistry/portgroup.h>
#include <cregistry/entry.h>
#include <cregistry/file.h>

#include "entry.h"
#include "entryobj.h"
#include "file.h"
#include "portgroup.h"
#include "registry.h"
#include "util.h"

int registry_failed(Tcl_Interp* interp, reg_error* errPtr) {
    Tcl_Obj* result = Tcl_NewStringObj(errPtr->description, -1);
    Tcl_SetObjResult(interp, result);
    Tcl_SetErrorCode(interp, errPtr->code, NULL);
    reg_error_destruct(errPtr);
    return TCL_ERROR;
}

/* we don't need delete_file_list and restore_file_list unless we allow deletion
   of files via the file interface */
static void delete_entry_list(ClientData list, Tcl_Interp* interp UNUSED) {
    entry_list* curr = *(entry_list**)list;
    while (curr) {
        entry_list* save = curr;
        reg_entry_free(curr->entry);
        curr = curr->next;
        free(save);
    }
    *(entry_list**)list = NULL;
}

static void restore_entry_list(ClientData list, Tcl_Interp* interp) {
    entry_list* curr = *(entry_list**)list;
    while (curr) {
        entry_list* save = curr;
        Tcl_CreateObjCommand(interp, curr->entry->proc, entry_obj_cmd,
                curr->entry, delete_entry);
        curr = curr->next;
        free(save);
    }
    *(entry_list**)list = NULL;
}

int registry_tcl_detach(Tcl_Interp* interp, reg_registry* reg,
        reg_error* errPtr) {
    reg_entry** entries;
    reg_file** files;
    int entry_count;
    int file_count;
    int i;
    entry_count = reg_all_open_entries(reg, &entries);
    if (entry_count == -1) {
        return 0;
    }
    for (i=0; i<entry_count; i++) {
        if (entries[i]->proc) {
            Tcl_DeleteCommand(interp, entries[i]->proc);
        }
    }
    free(entries);
    file_count = reg_all_open_files(reg, &files);
    if (file_count == -1) {
        return 0;
    }
    for (i = 0; i < file_count; i++) {
        if (files[i]->proc) {
            Tcl_DeleteCommand(interp, files[i]->proc);
        }
    }
    free(files);
    if (!reg_detach(reg, errPtr)) {
        return registry_failed(interp, errPtr);
    }
    return 1;
}

/**
 * Deletes the sqlite3 DB associated with interp.
 *
 * This function will close an interp's associated DB, although there doesn't
 * seem to be a way of ensuring that it happened properly. This will be a
 * problem if we get lazy and forget to finish a sqlite3_stmt somewhere, so this
 * function will be noisy and complain if we do.
 *
 * Then it will leak memory :(
 */
static void delete_reg(ClientData reg, Tcl_Interp* interp) {
    reg_error error;
    if (((reg_registry*)reg)->status & reg_attached) {
        if (Tcl_GetAssocData(interp, "registry::needs_vacuum", NULL) != NULL) {
            reg_vacuum(Tcl_GetAssocData(interp, "registry::db_path", NULL));
            Tcl_DeleteAssocData(interp, "registry::needs_vacuum");
        }
        if (!registry_tcl_detach(interp, (reg_registry*)reg, &error)) {
            fprintf(stderr, "%s", error.description);
            reg_error_destruct(&error);
        }
    }
    if (!reg_close((reg_registry*)reg, &error)) {
        fprintf(stderr, "%s", error.description);
        reg_error_destruct(&error);
    }
}

/* simple destructor for malloc()ed assoc data */
static void free_assoc_data(ClientData ptr, Tcl_Interp* interp UNUSED) {
    free(ptr);
}

/**
 * Returns the sqlite3 DB associated with interp.
 *
 * The registry keeps its state in a sqlite3 database that is keyed to the
 * current interpreter context. Different interps will have different instances
 * of the connection, although I don't know if the Apple-provided sqlite3 lib
 * was compiled with thread-safety, so I can't be certain that it's safe to use
 * the registry from multiple threads. I'm pretty sure it's unsafe to alias a
 * registry function into a different thread.
 *
 * If `attached` is set to true, then this function will additionally check if
 * a real registry database has been attached. If not, then it will return NULL.
 *
 * This function sets its own Tcl result.
 */
reg_registry* registry_for(Tcl_Interp* interp, int status) {
    reg_registry* reg = Tcl_GetAssocData(interp, "registry::reg", NULL);
    if (reg == NULL) {
        reg_error error;
        if (reg_open(&reg, &error)) {
            Tcl_SetAssocData(interp, "registry::reg", delete_reg, reg);
        } else {
            registry_failed(interp, &error);
            return NULL;
        }
    }
    if ((reg->status & status) != status) {
        Tcl_SetErrorCode(interp, "registry::misuse", NULL);
        if (status & reg_can_write) {
            Tcl_SetResult(interp, "a write transaction has not been started",
                    TCL_STATIC);
        } else {
            Tcl_SetResult(interp, "registry is not open", TCL_STATIC);
        }
        reg = NULL;
    }
    return reg;
}

static int registry_open(ClientData clientData UNUSED, Tcl_Interp* interp,
        int objc, Tcl_Obj* CONST objv[]) {
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "db-file");
        return TCL_ERROR;
    } else {
        char* path = Tcl_GetString(objv[1]);
        reg_registry* reg = registry_for(interp, 0);
        reg_error error;
        if (Tcl_GetAssocData(interp, "registry::db_path", NULL) == NULL) {
            char *pathCopy = strdup(path);
            Tcl_SetAssocData(interp, "registry::db_path", free_assoc_data, pathCopy);
        }
        if (reg == NULL) {
            return TCL_ERROR;
        } else if (reg_attach(reg, path, &error)) {
            reg_configure(reg);
            return TCL_OK;
        } else {
            return registry_failed(interp, &error);
        }
    }
}

static int registry_close(ClientData clientData UNUSED, Tcl_Interp* interp,
        int objc, Tcl_Obj* CONST objv[]) {
    if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, NULL);
        return TCL_ERROR;
    } else {
        reg_registry* reg = registry_for(interp, reg_attached);
        if (reg == NULL) {
            return TCL_ERROR;
        } else {
            reg_error error;
            if (Tcl_GetAssocData(interp, "registry::needs_vacuum", NULL) != NULL) {
                reg_vacuum(Tcl_GetAssocData(interp, "registry::db_path", NULL));
                Tcl_DeleteAssocData(interp, "registry::needs_vacuum");
            }
            /* Not really anything we can do if this fails. */
            if (reg_checkpoint(reg, &error) == 0) {
                fprintf(stderr, "%s\n", error.description);
            }
            if (registry_tcl_detach(interp, reg, &error)) {
                return TCL_OK;
            }
            return registry_failed(interp, &error);
        }
    }
    return TCL_ERROR;
}

static int registry_read(ClientData clientData UNUSED, Tcl_Interp* interp,
        int objc, Tcl_Obj* CONST objv[]) {
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "command");
        return TCL_ERROR;
    } else {
        reg_registry* reg = registry_for(interp, reg_attached);
        if (reg == NULL) {
            return TCL_ERROR;
        } else {
            reg_error error;
            if (reg_start_read(reg, &error)) {
                int status = Tcl_EvalObjEx(interp, objv[1], 0);
                switch (status) {
                    case TCL_OK:
                        if (reg_commit(reg, &error)) {
                            return TCL_OK;
                        }
                        break;
                    case TCL_BREAK:
                        if (reg_rollback(reg, &error)) {
                            return TCL_OK;
                        }
                        break;
                    default:
                        if (reg_rollback(reg, &error)) {
                            return status;
                        }
                        break;
                }
            }
            return registry_failed(interp, &error);
        }
    }
}

static int registry_write(ClientData clientData UNUSED, Tcl_Interp* interp,
        int objc, Tcl_Obj* CONST objv[]) {
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "command");
        return TCL_ERROR;
    } else {
        reg_registry* reg = registry_for(interp, reg_attached);
        if (reg == NULL) {
            return TCL_ERROR;
        } else {
            int result;
            reg_error error;
            if (reg_start_write(reg, &error)) {
                entry_list* list = NULL;
                Tcl_SetAssocData(interp, "registry::deleted", delete_entry_list,
                        &list);
                result = Tcl_EvalObjEx(interp, objv[1], 0);
                switch (result) {
                    case TCL_OK:
                        if (reg_commit(reg, &error)) {
                            delete_entry_list(&list, interp);
                        } else {
                            result = registry_failed(interp, &error);
                        }
                        break;
                    case TCL_BREAK:
                        if (reg_rollback(reg, &error)) {
                            restore_entry_list(&list, interp);
                            result = TCL_OK;
                        } else {
                            result = registry_failed(interp, &error);
                        }
                        break;
                    default:
                        if (reg_rollback(reg, &error)) {
                            restore_entry_list(&list, interp);
                        } else {
                            result = registry_failed(interp, &error);
                        }
                        break;
                }
                Tcl_DeleteAssocData(interp, "registry::deleted");
            } else {
                result = registry_failed(interp, &error);
            }
            return result;
        }
    }
}

/*
 * registry::metadata cmd ?arg ...?
 *
 * Commands manipulating metadata in the registry. This can be called `registry::metadata`
 */
int metadata_cmd(ClientData clientData UNUSED, Tcl_Interp* interp, int objc,
        Tcl_Obj* CONST objv[]) {
    if (objc < 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "cmd key ?value?");
        return TCL_ERROR;
    }
    reg_registry* reg = registry_for(interp, reg_attached);
    if (reg == NULL) {
        return TCL_ERROR;
    }
    const char *cmdstring = Tcl_GetString(objv[1]);
    reg_error error;
    if (strcmp(cmdstring, "get") == 0) {
        char *data;
        if (reg_get_metadata(reg, Tcl_GetString(objv[2]), &data, &error)) {
            Tcl_Obj* result = Tcl_NewStringObj(data, -1);
            Tcl_SetObjResult(interp, result);
            free(data);
            return TCL_OK;
        } else if (error.code == REG_NOT_FOUND) {
            Tcl_Obj* result = Tcl_NewIntObj(-1);
            Tcl_SetObjResult(interp, result);
            return TCL_OK;
        } else {
            return registry_failed(interp, &error);
        }
    } else if (strcmp(cmdstring, "set") == 0) {
        if (objc < 4) {
            Tcl_WrongNumArgs(interp, 1, objv, "set key value");
            return TCL_ERROR;
        }
        if (reg_set_metadata(reg, Tcl_GetString(objv[2]), Tcl_GetString(objv[3]), &error)) {
            return TCL_OK;
        } else {
            return registry_failed(interp, &error);
        }
    } else if (strcmp(cmdstring, "del") == 0) {
        if (reg_del_metadata(reg, Tcl_GetString(objv[2]), &error)) {
            return TCL_OK;
        } else {
            return registry_failed(interp, &error);
        }
    }
    return TCL_ERROR;
}

/**
 * Initializer for the registry lib.
 *
 * This function is called automatically by Tcl upon loading of registry.dylib.
 * It creates the global commands made available in the registry namespace.
 */
int Registry_Init(Tcl_Interp* interp) {
    if (Tcl_InitStubs(interp, "8.4", 0) == NULL) {
        return TCL_ERROR;
    }
    Tcl_CreateObjCommand(interp, "registry::open", registry_open, NULL, NULL);
    Tcl_CreateObjCommand(interp, "registry::close", registry_close, NULL, NULL);
    Tcl_CreateObjCommand(interp, "registry::read", registry_read, NULL, NULL);
    Tcl_CreateObjCommand(interp, "registry::write", registry_write, NULL, NULL);
    Tcl_CreateObjCommand(interp, "registry::entry", entry_cmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "registry::file", file_cmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "registry::portgroup", portgroup_cmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "registry::metadata", metadata_cmd, NULL, NULL);
    if (Tcl_PkgProvide(interp, "registry2", "2.0") != TCL_OK) {
        return TCL_ERROR;
    }
    return TCL_OK;
}
