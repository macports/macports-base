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

#include <sqlite3.h>

typedef struct {
    char* variant_name;
    char* variant_sign;
} variant;

typedef struct {
    char* name;g
    int requested;
    char* state;
    variant* variants;
} port;

typedef struct {
    char* id;
    char* note;
    port* ports;
    reg_registry* reg; /* associated registry */
    char* proc; /* name of Tcl proc, if using Tcl */
} reg_snapshot;

int get_parsed_variants(char* variants_str, variant* all_variants,
    char* delim, int* variant_count);

reg_entry* reg_snapshot_create(reg_registry* reg, char* note,
        reg_error* errPtr);
char* reg_snapshot_get_id(reg_registry* reg, reg_error* errPtr);
int reg_snapshot_get(reg_registry* reg, char* id,
        reg_snapshot* snapshot, reg_error* errPtr);
int reg_snapshot_port_variants_get(reg_registry* reg,
        sqlite_int64 snapshot_port_id, variant** variants, reg_error* errPtr);

int snapshot_store_ports(reg_registry* reg, reg_entry* entry,
        reg_error* errPtr);
int snapshot_store_port_variants(reg_registry* reg, reg_entry* port_entry,
        int snapshot_ports_id, reg_error* errPtr);

#endif /* _CSNAPSHOT_H */
