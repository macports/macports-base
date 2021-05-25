/*
 * util.h
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
#ifndef _UTIL_H
#define _UTIL_H

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include <tcl.h>
#include <sqlite3.h>

#include <cregistry/registry.h>
#include <cregistry/portgroup.h>
#include <cregistry/entry.h>
#include <cregistry/file.h>

typedef struct {
    char* option;
    int flag;
} option_spec;

#define END_FLAGS 0

char* unique_name(Tcl_Interp* interp, char* prefix, unsigned int* lower_bound);

int parse_flags(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[], int* start,
        option_spec options[], int* flags);

void* get_object(Tcl_Interp* interp, char* name, char* type,
        Tcl_ObjCmdProc* proc, reg_error* errPtr);
int set_object(Tcl_Interp* interp, char* name, void* value, char* type,
        Tcl_ObjCmdProc* proc, Tcl_CmdDeleteProc* deleteProc, reg_error* errPtr);
int set_entry(Tcl_Interp* interp, char* name, reg_entry* entry,
        reg_error* errPtr);
int set_file(Tcl_Interp* interp, char* name, reg_file* file,
        reg_error* errPtr);
int set_portgroup(Tcl_Interp* interp, char* name, reg_portgroup* portgroup,
        reg_error* errPtr);

void set_sqlite_result(Tcl_Interp* interp, sqlite3* db, const char* query);

const char* string_or_null(Tcl_Obj* obj);

int recast(void* userdata, cast_function* fn, void* castcalldata,
        free_function* del, void*** outv, void** inv, int inc,
        reg_error* errPtr);

int entry_to_obj(Tcl_Interp* interp, Tcl_Obj** obj, reg_entry* entry,
        void* param UNUSED, reg_error* errPtr);
int list_entry_to_obj(Tcl_Interp* interp, Tcl_Obj*** objs,
        reg_entry** entries, int entry_count, reg_error* errPtr);
int file_to_obj(Tcl_Interp* interp, Tcl_Obj** ibj, reg_file* file,
        void* param UNUSED, reg_error* errPtr);
int list_file_to_obj(Tcl_Interp* interp, Tcl_Obj*** objs,
        reg_file** files, int file_count, reg_error* errPtr);
int portgroup_to_obj(Tcl_Interp* interp, Tcl_Obj** ibj, reg_portgroup* portgroup,
        void* param UNUSED, reg_error* errPtr);
int list_portgroup_to_obj(Tcl_Interp* interp, Tcl_Obj*** objs,
        reg_portgroup** portgroups, int portgroup_count, reg_error* errPtr);

void free_strings(void* userdata UNUSED, char** strings, int count);

int list_obj_to_string(char*** strings, Tcl_Obj** objv, int objc,
        reg_error* errPtr);
int list_string_to_obj(Tcl_Obj*** objv, char** strings, int objc,
        reg_error* errPtr);

#endif /* _UTIL_H */
