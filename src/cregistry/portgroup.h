/*
 * vim:tw=80:expandtab
 *
 * Copyright (c) 2014 The MacPorts Project
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
#ifndef _CPORTGROUP_H
#define _CPORTGROUP_H

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include "registry.h"

#include <sqlite3.h>

typedef struct {
    sqlite_int64 id; /* rowid in the database */
    reg_registry* reg; /* associated registry */
    char* proc; /* name of Tcl proc, if using Tcl */
} reg_portgroup;

int reg_portgroup_search(reg_registry* reg, char** keys, char** vals, int* strats,
        int key_count, reg_portgroup*** portgroups, reg_error* errPtr);
int reg_all_portgroups(reg_registry* reg, char* query, int query_len,
        reg_portgroup*** objects, reg_error* errPtr);
reg_portgroup* reg_portgroup_open(reg_registry* reg, char *id, char* name, char* version,
        char* size, char* sha256, reg_error* errPtr);
int reg_portgroup_propget(reg_portgroup* portgroup, char* key, char** value,
        reg_error* errPtr);
int reg_portgroup_propset(reg_portgroup* portgroup, char* key, char* value,
        reg_error* errPtr);

#endif /* _CPORTGROUP_H */
