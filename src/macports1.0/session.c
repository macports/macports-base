/*
 * session.c
 * $Id$
 *
 * Copyright (c) 2003 Apple Computer, Inc.
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
 * 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
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

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include <sys/param.h>

#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>

#include "macports.h"

#include <tcl.h>

/*
 *
 * mp_session_t
 *
 */
struct session {
    char* portdbpath;
    char* portconf;
    char* sources_conf;
    mp_array_t sources;
    char* portsharepath;
    char* registry_path;
};

mp_session_t mp_session_open() {
    struct session* mp = malloc(sizeof(struct session));
    char* path;
    /* mp_array_t conf_files = mp_array_create(); */
    
    mp->portconf = NULL;
    
    /* first look at PORTSRC for testing/debugging */
    path = getenv("PORTSRC");
    if (path != NULL && access(path, R_OK) == 0) {
        mp->portconf = strdup(path);
        /* mp_array_append(conf_files, mp->portconf); */
    }

    /* then look in ~/.macports/macports.conf */
    if (mp->portconf == NULL) {
        char* home = getenv("HOME");
        if (home != NULL) {
            char path[PATH_MAX];
            snprintf(path, sizeof(path), "%s/.macports/macports.conf", home);
            if (access(path, R_OK) == 0) {
                mp->portconf = strdup(path);
                /* mp_array_append(conf_files, mp->portconf); */
            }
        }
    }

    /* finally ${prefix}/etc/macports/macports.conf, or whatever path was configured */
    if (mp->portconf == NULL) {
      /* XXX: honor autoconf setting ($macports_conf_path) */
        char* path = "${prefix}/etc/macports/macports.conf";
        if (access(path, R_OK) == 0) {
            mp->portconf = strdup(path);
            /* mp_array_append(conf_files, mp->portconf); */
        }
    }
    
    /* foreach conf_files */
    {
        int fd = open(mp->portconf, O_RDONLY, 0);
        if (fd != -1) {
	  /* XXX: parse config file */
        }
    }
    
    if (mp->sources_conf == NULL) {
        fprintf(stderr, "sources_conf must be set in ${prefix}/etc/macports/macports.conf or in your ~/.macports/macports.conf file\n");
    }
    return (mp_session_t)mp;
}

