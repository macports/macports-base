/*
 * snapshot.h
 * vim:tw=80:expandtab
 *
 * Copyright (c) 2017 The MacPorts Project
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

#ifndef _CSNAPSHOT_H
#define _CSNAPSHOT_H

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include "registry.h"
#include "entry.h"

#include <sqlite3.h>

typedef struct {
    char* name;     /* port name */
    int requested;  /* 1 if port os requested, else 0 */
    char* state;    /* 'imaged' or 'installed' */
    char* variants; /* string of the form: +var1-var2+var3 */
    char* requested_variants; /* string of the form: +var1-var2 */
} port;

typedef struct {
    sqlite_int64 id; /* rowid of snapshot in 'registry.snapshots' table */
    char* note;
    port* ports;    /* list of ports present while taking this snapshot */
    reg_registry* reg; /* associated registry */
    char* proc; /* name of Tcl proc, if using Tcl */
} reg_snapshot;

// get snapshot using id
reg_snapshot* reg_snapshot_open(reg_registry* reg, sqlite_int64 id,
        reg_error* errPtr);
// list all snapshots
int reg_snapshot_list(reg_registry* reg, reg_snapshot*** snapshots,
        int limit, reg_error* errPtr);
// create snapshot method
reg_snapshot* reg_snapshot_create(reg_registry* reg, char* note,
        reg_error* errPtr);
// helper method for storing ports for this snapshot
int snapshot_store_ports(reg_registry* reg, reg_snapshot* snapshot,
        reg_error* errPtr);
// helper method for storing files for this snapshot
int snapshot_store_files(reg_registry* reg, reg_snapshot* snapshot,
        reg_error* errPtr);

// snapshot properties retrieval methods
int reg_snapshot_propget(reg_snapshot* snapshot, char* key, char** value,
        reg_error* errPtr);
int reg_snapshot_ports_get(reg_snapshot* snapshot, port*** ports,
        reg_error* errPtr);

#endif /* _CSNAPSHOT_H */
