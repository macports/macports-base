/*
 * -*- coding: utf-8; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=c:et:sw=4:ts=4:sts=4:tw=100
 * libmachista.h
 *
 * Copyright (c) 2011 The MacPorts Project
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
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef __LIBMACHISTA_H__
#define __LIBMACHISTA_H__

/*
 * This is a library to parse Mach-O files in single architecture _and_ universal variant and return
 * a list of architectures and their load commands and properties
 * The name a pun: machista is the spanish translation of "macho".
 */

#ifdef __MACH__
#include <mach-o/arch.h>
#else
typedef int cpu_type_t;
#endif
#include <inttypes.h>

#define MACHO_SUCCESS   (0x00)
#define MACHO_EFILE     (0x01)
#define MACHO_EMMAP     (0x02)
#define MACHO_EMEM      (0x04)
#define MACHO_ERANGE    (0x08)
#define MACHO_EMAGIC    (0x10)
#define MACHO_ECACHE    (0x20)

/* Blind structure; this essentially contains the hash map used to cache
 * entries, but users should not have to look into this structure. struct
 * macho_handle is defined in libmachista.c */
typedef struct macho_handle macho_handle_t;

/** Structure describing a load command within a Mach-O file */
typedef struct macho_loadcmd {
    char *mlt_install_name;         /* install name of the library to be loaded by this load command */
    uint32_t mlt_type;              /* type of the load command; see mach-o/loader.h for possible
                                       values */
    uint32_t mlt_comp_version;      /* compatibility version of the file to be loaded by this
                                       command (at build time of this file) */
    uint32_t mlt_version;           /* version of the library to be loaded by this command (at build
                                       time of this file) */
    struct macho_loadcmd *next;     /* pointer to the next entry in the linked list of
                                       macho_loadcmd_t's (NULL if there's no further element) */
} macho_loadcmd_t;

/** Stucture describing an architecture within a Mach-O file */
typedef struct macho_arch {
    char *mat_install_name;         /* install name of the library or NULL if none */
    char *mat_rpath;                /* rpath of the binary of NULL if none */
    cpu_type_t mat_arch;            /* cpu_type_t describing the CPU this part of the binary is
                                       intended for */
    uint32_t mat_comp_version;      /* compatibility version of this part of the binary */
    uint32_t mat_version;           /* current version of this part of the binary */
    macho_loadcmd_t *mat_loadcmds;  /* array of macho_loadcmd_t's describing the different load
                                       commands */
    struct macho_arch *next;        /* pointer to the next entry in the linked list of
                                       macho_arch_t's (NULL if there's no further element) */
} macho_arch_t;

/** Structure describing a Mach-O file */
typedef struct macho {
    macho_arch_t *mt_archs;         /* linked list of macho_arch_t's describing the different
                                       architectures */
} macho_t;

/**
 * Creates and returns a macho_handle_t to be passed to subsequent calls to macho_parse_file. No
 * assumptions should be made about the contents of a macho_handle_t; it is declared to be a blind
 * structure.
 *
 * Returns either a pointer to a valid macho_handle_t or NULL on failure. errno will be set on
 * failure. The resources associated with a macho_handle_t must be freed by passing it to
 * macho_destroy_handle.
 */
macho_handle_t *macho_create_handle(void);

/**
 * Frees resources associated with a macho_handle_t and invalidates all results returned by
 * macho_parse_file called with this handle.
 */
void macho_destroy_handle(macho_handle_t *handle);

/**
 * Formats a dylib version number given by an uint32_t into a human-readable format and returns a
 * Pointer to the beginning of that string. The result is either a valid pointer or NULL on error
 * (in which case the errno is set to indicate the error). The pointer must be free()'d after use.
 */
char *macho_format_dylib_version(uint32_t version);

/**
 * Returns a readable version of any cpu_type_t constant. Returns a valid pointer to the first
 * character in a 0-terminated string or NULL on error. The pointer must not be free()'d after use.
 */
const char *macho_get_arch_name(cpu_type_t cputype);

/**
 * Parses the Mach-O file indicated by filepath and writes a pointer to a macho_t describing the
 * Mach-O file into the location idicated by res. Returns MACHO_SUCCESS on success or any of the
 * following error codes on error:
 *
 * code             description                                     errno set?
 * MACHO_EFILE      error stat()'ing, opening or reading the file   yes
 * MACHO_EMMAP      error mmap()'ing the file                       yes
 * MACHO_EMEM       error allocating memory                         yes
 * MACHO_ERANGE     unexpected end of file                          no
 * MACHO_EMAGIC     unknown magic number/not a Mach-O file          no
 *
 * On error, the contents of res are undefined and should not be used. The memory associated with
 * the result *res will be free()'d and should thus not be used after calling macho_destroy_handle
 * on the macho_handle_t used for the call. *res should also never be modified or otherwise
 * free()'d.
 */
int macho_parse_file(macho_handle_t *handle, const char *filepath, const macho_t **res);

/**
 * Returns a string representation of the MACHO_* error code constants
 */
const char *macho_strerror(int err);

#endif

