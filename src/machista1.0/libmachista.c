/*
 * -*- coding: utf-8; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=c:et:sw=4:ts=4:sts=4:tw=100
 * libmachista.c
 *
 * Copyright (c) 2011-2012, 2014, 2016-2018 The MacPorts Project
 * Copyright (c) 2011 Landon Fuller <landonf@macports.org>
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

/* required for asprintf(3) on macOS */
#define _DARWIN_C_SOURCE
/* required for asprintf(3) on Linux */
#define _GNU_SOURCE

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#include <err.h>
#include <string.h>
#include <strings.h>

#ifdef __MACH__
#include <mach-o/dyld.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>

#include <libkern/OSByteOrder.h>
#endif

#include "libmachista.h"
#include "hashmap.h"

#ifdef __MACH__
/* Tiger compatibility */
#ifndef LC_RPATH
#define LC_RPATH       (0x1c | LC_REQ_DYLD)    /* runpath additions */
/*
 * The rpath_command contains a path which at runtime should be added to
 * the current run path used to find @rpath prefixed dylibs.
 */
struct rpath_command {
    uint32_t     cmd;       /* LC_RPATH */
    uint32_t     cmdsize;   /* includes string */
    union lc_str path;      /* path to add to run path */
};
#endif
#ifndef LC_REEXPORT_DYLIB
#define LC_REEXPORT_DYLIB (0x1f | LC_REQ_DYLD) /* load and re-export dylib */
#endif
#endif /* __MACH__ */

typedef struct macho_input {
    const void *data;
    size_t length;
} macho_input_t;

/* This is macho_handle_t. The corresponding typedef is in the header */
struct macho_handle {
    HashMap *result_map;
};

#ifdef __MACH__
/* Verify that the given range is within bounds. */
static const void *macho_read (macho_input_t *input, const void *address, size_t length) {
    if ((((uint8_t *) address) - ((uint8_t *) input->data)) + length > input->length) {
       // warnx("Short read parsing Mach-O input");
        return NULL;
    }

    return address;
}

/* Verify that address + offset + length is within bounds. */
static const void *macho_offset (macho_input_t *input, const void *address, size_t offset, size_t length) {
    void *result = ((uint8_t *) address) + offset;
    return macho_read(input, result, length);
}
#endif

/* return a human readable formatted version number. the result must be free()'d. */
char *macho_format_dylib_version (uint32_t version) {
    char *result;
    asprintf(&result, "%"PRIu32".%"PRIu32".%"PRIu32, (version >> 16) & 0xFFFF, (version >> 8) & 0xFF, version & 0xFF);
    return result;
}

#ifdef __MACH__
const char *macho_get_arch_name (cpu_type_t cputype) {
    const NXArchInfo *archInfo = NXGetArchInfoFromCpuType(cputype, CPU_SUBTYPE_MULTIPLE);	
    if (!archInfo) {
        return NULL;
    }
    return archInfo->name;
#else
const char *macho_get_arch_name (cpu_type_t cputype UNUSED) {
    return NULL;
#endif
}

#ifdef __MACH__
/* Some byteswap wrappers */
static uint32_t macho_swap32 (uint32_t input) {
    return OSSwapInt32(input);
}

static uint32_t macho_nswap32(uint32_t input) {
    return input;
}

/* Creates a new macho_t.
 * Returns NULL on failure or a pointer to a 0-initialized macho_t on success */
static macho_t *create_macho_t (void) {
    macho_t *mt = malloc(sizeof(macho_t));
    if (mt == NULL)
        return NULL;

    memset(mt, 0, sizeof(macho_t));
    return mt;
}

/* Creates a new macho_arch_t.
 * Returns NULL on failure or a pointer to a 0-initialized macho_arch_t on success */
static macho_arch_t *create_macho_arch_t (void) {
    macho_arch_t *mat = malloc(sizeof(macho_arch_t));
    if (mat == NULL)
        return NULL;
    
    memset(mat, 0, sizeof(macho_arch_t));
    return mat;
}

/* Creates a new macho_loadcmd_t.
 * Returns NULL on failure or a pointer to a 0-initialized macho_loadcmd_t on success */
static macho_loadcmd_t *create_macho_loadcmd_t (void) {
    macho_loadcmd_t *mlt = malloc(sizeof(macho_loadcmd_t));
    if (mlt == NULL)
        return NULL;

    memset(mlt, 0, sizeof(macho_loadcmd_t));
    return mlt;
}
#endif

/* Frees a previously allocated macho_loadcmd_t and all it's associated resources */
static void free_macho_loadcmd_t (macho_loadcmd_t *mlt) {
    if (mlt == NULL)
        return;

    free(mlt->mlt_install_name);
    free(mlt);
}

/* Frees a previously allocated macho_arch_t and all it's associated resources */
static void free_macho_arch_t (macho_arch_t *mat) {
    if (mat == NULL)
        return;

    macho_loadcmd_t *current = mat->mat_loadcmds;
    while (current != NULL) {
        macho_loadcmd_t *freeme = current;
        current = current->next;
        free_macho_loadcmd_t(freeme);
    }

    free(mat->mat_install_name);
    free(mat->mat_rpath);
    free(mat);
}

/* Frees a previously allocated macho_t and all it's associated resources */
static void free_macho_t (macho_t *mt) {
    if (mt == NULL)
        return;

    macho_arch_t *current = mt->mt_archs;
    while (current != NULL) {
        macho_arch_t *freeme = current;
        current = current->next;
        free_macho_arch_t(freeme);
    }

    free(mt);
}

#ifdef __MACH__
/* Creates a new element in the architecture list of a macho_t (mt_archs), increases the counter of
 * architectures (mt_arch_count) and returns a pointer to the newly allocated element or NULL on
 * error */
static macho_arch_t *macho_archlist_append (macho_t *mt) {
    macho_arch_t *old_head = mt->mt_archs;

    macho_arch_t *new_head = create_macho_arch_t();
    if (new_head == NULL)
        return NULL;
    new_head->next = old_head;
    mt->mt_archs = new_head;

    return mt->mt_archs;
}

/* Creates a new element in the load command list of a macho_arch_t (mat_loadcmds), increases the
 * counter of load commands (mat_loadcmd_count) and returns a pointer to the newly allocated element
 * or NULL on error */
static macho_loadcmd_t *macho_loadcmdlist_append (macho_arch_t *mat) {
    macho_loadcmd_t *old_head = mat->mat_loadcmds;

    macho_loadcmd_t *new_head = create_macho_loadcmd_t();
    if (new_head == NULL)
        return NULL;
    new_head->next = old_head;
    mat->mat_loadcmds = new_head;

    return mat->mat_loadcmds;
}
#endif

/* Parse a Mach-O header */
#ifdef __MACH__
static int parse_macho (macho_t *mt, macho_input_t *input) {
    /* Read the file type. */
    const uint32_t *magic = macho_read(input, input->data, sizeof(uint32_t));
    if (magic == NULL)
        return MACHO_ERANGE;

    /* Parse the Mach-O header */
    bool universal = false;
    uint32_t (*swap32)(uint32_t) = macho_nswap32;

    const struct mach_header *header;
    const struct mach_header_64 *header64;
    size_t header_size;
    const struct fat_header *fat_header;

    macho_arch_t *mat = NULL;
    switch (*magic) {
        case MH_CIGAM:
            swap32 = macho_swap32;
            // Fall-through

        case MH_MAGIC:

            header_size = sizeof(*header);
            header = macho_read(input, input->data, header_size);
            if (header == NULL)
                return MACHO_ERANGE;
            mat = macho_archlist_append(mt);
            if (mat == NULL)
                return MACHO_EMEM;

            /* 32-bit Mach-O */
            mat->mat_arch = swap32(header->cputype);
            break;


        case MH_CIGAM_64:
            swap32 = macho_swap32;
            // Fall-through

        case MH_MAGIC_64:
            header_size = sizeof(*header64);
            header64 = macho_read(input, input->data, sizeof(*header64));
            if (header64 == NULL)
                return MACHO_ERANGE;
            mat = macho_archlist_append(mt);
            if (mat == NULL)
                return MACHO_EMEM;

            /* The 64-bit header is a direct superset of the 32-bit header */
            header = (struct mach_header *) header64;

            /* 64-bit Macho-O */
            mat->mat_arch = swap32(header->cputype);
            break;

        case FAT_CIGAM:
        case FAT_MAGIC:
            fat_header = macho_read(input, input->data, sizeof(*fat_header));
            universal = true;
            /* Universal binary */
            break;

        default:
            /* Unknown binary type */
            //warnx("Unknown Mach-O magic: 0x%" PRIx32 "", *magic);
            return MACHO_EMAGIC;
    }

    /* Parse universal file. */
    if (universal) {
        uint32_t nfat = OSSwapBigToHostInt32(fat_header->nfat_arch);
        const struct fat_arch *archs = macho_offset(input, fat_header, sizeof(struct fat_header), sizeof(struct fat_arch));
        if (archs == NULL)
            return MACHO_ERANGE;

        for (uint32_t i = 0; i < nfat; i++) { // foreach architecture
            const struct fat_arch *arch = macho_read(input, archs + i, sizeof(struct fat_arch));
            if (arch == NULL)
                return MACHO_ERANGE;

            /* Fetch a pointer to the architecture's Mach-O header. */
            macho_input_t arch_input;
            arch_input.length = OSSwapBigToHostInt32(arch->size);
            arch_input.data = macho_offset(input, input->data, OSSwapBigToHostInt32(arch->offset), arch_input.length);
            if (arch_input.data == NULL)
                return MACHO_ERANGE;

            /* Parse the architecture's Mach-O header */
            int res = parse_macho(mt, &arch_input);
            if (res != MACHO_SUCCESS)
                return res;
        }

        return MACHO_SUCCESS;
    }

    /* Copy the architecture */
    mat->mat_arch = swap32(header->cputype);

    /* Parse the Mach-O load commands */
    uint32_t ncmds = swap32(header->ncmds);

    /* Setup to jump over the header on the first pass through instead of the previous command */
    const struct load_command *cmd = (void *)header;
    uint32_t cmdsize = header_size;

    /* Iterate over the load commands */
    for (uint32_t i = 0; i < ncmds; i++) {
        /* Load the next command */
        cmd = macho_offset(input, cmd, cmdsize, sizeof(struct load_command));
        if (cmd == NULL)
            return MACHO_ERANGE;

        /* Load the full command */
        cmdsize = swap32(cmd->cmdsize);
        cmd = macho_read(input, cmd, cmdsize);
        if (cmd == NULL)
            return MACHO_ERANGE;

        /* Handle known types */
        uint32_t cmd_type = swap32(cmd->cmd);
        switch (cmd_type) {
            case LC_RPATH: {
                /* Copy the rpath */
                if (cmdsize < sizeof(struct rpath_command)) {
                    //warnx("Incorrect cmd size");
                    return MACHO_ERANGE;
                }

                size_t pathlen = cmdsize - sizeof(struct rpath_command);
                const void *pathptr = macho_offset(input, cmd, sizeof(struct rpath_command), pathlen);
                if (pathptr == NULL)
                    return MACHO_ERANGE;

                mat->mat_rpath = malloc(pathlen);
                if (mat->mat_rpath == NULL)
                    return MACHO_EMEM;
                strlcpy(mat->mat_rpath, pathptr, pathlen);
                break;
            }

            case LC_ID_DYLIB:
            case LC_LOAD_WEAK_DYLIB:
            case LC_REEXPORT_DYLIB:
            case LC_LOAD_DYLIB: {
                const struct dylib_command *dylib_cmd = (const struct dylib_command *) cmd;

                /* Extract the install name */
                if (cmdsize < sizeof(struct dylib_command)) {
                    //warnx("Incorrect name size");
                    return MACHO_ERANGE;
                }

                size_t namelen = cmdsize - sizeof(struct dylib_command);
                const void *nameptr = macho_offset(input, cmd, sizeof(struct dylib_command), namelen);
                if (nameptr == NULL)
                    return MACHO_ERANGE;

                if (cmd_type == LC_ID_DYLIB) {
                    /* Copy install name */
                    mat->mat_install_name = malloc(namelen);
                    if (mat->mat_install_name == NULL)
                        return MACHO_EMEM;
                    strlcpy(mat->mat_install_name, nameptr, namelen);

                    /* Copy version numbers (raw, for easier comparison) */
                    mat->mat_version = swap32(dylib_cmd->dylib.current_version);
                    mat->mat_comp_version = swap32(dylib_cmd->dylib.compatibility_version);
                } else {
                    /* Append loadcmd to list of loadcommands */
                    macho_loadcmd_t *mlt = macho_loadcmdlist_append(mat);
                    if (mlt == NULL)
                        return MACHO_EMEM;

                    /* Copy install name */
                    mlt->mlt_install_name = malloc(namelen);
                    if (mlt->mlt_install_name == NULL)
                        return MACHO_EMEM;
                    strlcpy(mlt->mlt_install_name, nameptr, namelen);

                    /* Copy version numbers (raw, for easier comparison) */
                    mlt->mlt_version = swap32(dylib_cmd->dylib.current_version);
                    mlt->mlt_comp_version = swap32(dylib_cmd->dylib.compatibility_version);

                    /* Copy command type */
                    mlt->mlt_type = cmd_type;
                }
                break;
            }

            default:
                break;
        }
    }

    return MACHO_SUCCESS;
}
#endif

/* Parse a (possible Mach-O) file. For a more detailed description, see the header */
#ifdef __MACH__
int macho_parse_file(macho_handle_t *handle, const char *filepath, const macho_t **res) {
    int fd;
    struct stat st;
    void *data;
    macho_input_t input_file;

    /* Check hashmap for precomputed results */
    const macho_t *cached_res = hashMapGet(handle->result_map, filepath);
    if (cached_res != NULL) {
        *res = cached_res;
        return MACHO_SUCCESS;
    }

    
    /* Open input file */
    if ((fd = open(filepath, O_RDONLY)) < 0) {
#ifdef HAVE__DYLD_SHARED_CACHE_CONTAINS_PATH
    /* All systems that have this function in the SDK should also have
       __builtin_available, so not bothering to check for it. */
        if (__builtin_available(macos 11.0, ios 14.0, watchos 7.0, tvos 14.0, *)) {
            if (_dyld_shared_cache_contains_path(filepath)) {
                return MACHO_ECACHE;
            }
        }
#endif /* HAVE__DYLD_SHARED_CACHE_CONTAINS_PATH */
        return MACHO_EFILE;
    }

    /* Get file length */
    if (fstat(fd, &st) != 0) {
        close(fd);
        return MACHO_EFILE;
    }

    /* Map file into address space */
    if ((data = mmap(NULL, st.st_size, PROT_READ, MAP_FILE | MAP_PRIVATE, fd, 0)) == MAP_FAILED) {
        close(fd);
        return MACHO_EMMAP;
    }

    /* Parse file */
    input_file.data = data;
    input_file.length = st.st_size;

    *res = create_macho_t();
    if (*res == NULL)
        return MACHO_EMEM;

    /* The output parameter *res should be read-only for the user of the lib only, but writable for
     * us */
    int ret = parse_macho((macho_t *)*res, &input_file);
    if (ret == MACHO_SUCCESS) {
        /* Insert into hashmap for caching */
        if (0 == hashMapPut(handle->result_map, filepath, *res, NULL)) {
            free_macho_t((macho_t *)*res);
            *res = NULL;
            ret = MACHO_EMEM;
        }
    } else {
        /* An error occured, free mt */
        free_macho_t((macho_t *)*res);
        *res = NULL;
    }

    /* Cleanup */
    munmap(data, st.st_size);
    close(fd);

    return ret;
#else
int macho_parse_file(macho_handle_t *handle UNUSED, const char *filepath UNUSED, const macho_t **res UNUSED) {
    return 0;
#endif
}

/* Create a new macho_handle_t. More information on this function is available in the header */
macho_handle_t *macho_create_handle (void) {
    macho_handle_t *mht = malloc(sizeof(macho_handle_t));
    if (mht == NULL)
        return NULL;
    mht->result_map = hashMapCreate((void (*)(const void *))free_macho_t);
    if (mht->result_map == NULL) {
        free(mht);
        return NULL;
    }
    return mht;
}

/* Release a macho_handle_t. For more documentation, see the header */
void macho_destroy_handle(macho_handle_t *handle) {
    if (handle == NULL)
        return;
    
    hashMapDestroy(handle->result_map);

    free(handle);
}

/* Returns string representation of the MACHO_* error code constants */
const char *macho_strerror(int err) {
    int num;
#ifdef HAVE_FLS
    num = fls(err);
#else
    /* Tiger compatibility, see #42186 */
    num = 0;
    while (err > 0) {
        err >>= 1;
        num++;
    }
#endif

    static char *errors[] = {
        /* 0x00 */ "Success",
        /* 0x01 */ "Error opening or reading file",
        /* 0x02 */ "Error mapping file into memory",
        /* 0x04 */ "Error allocating memory",
        /* 0x08 */ "Premature end of data, possibly corrupt file",
        /* 0x10 */ "Not a Mach-O file",
        /* 0x20 */ "Shared cache only",
    };
    return errors[num];
}

