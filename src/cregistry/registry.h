/*
 * registry.h
 * vim:tw=80:expandtab
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
#ifndef _CREG_H
#define _CREG_H

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include <sqlite3.h>
#include <tcl.h>

#define REG_NOT_FOUND       (registry_err_not_found)
#define REG_INVALID         (registry_err_invalid)
#define REG_CONSTRAINT      (registry_err_constraint)
#define REG_SQLITE_ERROR    (registry_err_sqlite_error)
#define REG_MISUSE          (registry_err_misuse)
#define REG_CANNOT_INIT     (registry_err_cannot_init)
#define REG_ALREADY_ACTIVE  (registry_err_already_active)

extern char *const registry_err_not_found;
extern char *const registry_err_invalid;
extern char *const registry_err_constraint;
extern char *const registry_err_sqlite_error;
extern char *const registry_err_misuse;
extern char *const registry_err_cannot_init;
extern char *const registry_err_already_active;

typedef void reg_error_destructor(const char* description);

typedef struct {
    char* code;
    const char* description;
    reg_error_destructor* free;
} reg_error;

void reg_sqlite_error(sqlite3* db, reg_error* errPtr, char* query);
void reg_error_destruct(reg_error* errPtr);
void reg_throw(reg_error* errPtr, char* code, char* fmt, ...);

typedef int (cast_function)(void* userdata, void** dst, void* src,
        void* calldata, reg_error* errPtr);
typedef void (free_function)(void* userdata, void* item);

enum {
    reg_none = 0,
    reg_attached = 1,
    reg_transacting = 2,
    reg_can_write = 4
};

typedef struct {
    sqlite3* db;
    int status;
    Tcl_HashTable open_entries;
    Tcl_HashTable open_files;
    Tcl_HashTable open_portgroups;
} reg_registry;

int reg_open(reg_registry** regPtr, reg_error* errPtr);
int reg_close(reg_registry* reg, reg_error* errPtr);
int reg_configure(reg_registry* reg);

int reg_attach(reg_registry* reg, const char* path, reg_error* errPtr);
int reg_detach(reg_registry* reg, reg_error* errPtr);

int reg_start_read(reg_registry* reg, reg_error* errPtr);
int reg_start_write(reg_registry* reg, reg_error* errPtr);
int reg_commit(reg_registry* reg, reg_error* errPtr);
int reg_rollback(reg_registry* reg, reg_error* errPtr);

int reg_vacuum(char* db_path);
int reg_checkpoint(reg_registry* reg, reg_error* errPtr);

int reg_get_metadata(reg_registry* reg, const char* key, char** value, reg_error* errPtr);
int reg_set_metadata(reg_registry* reg, const char* key, const char* value, reg_error* errPtr);
int reg_del_metadata(reg_registry* reg, const char* key, reg_error* errPtr);

#endif /* _CREG_H */
