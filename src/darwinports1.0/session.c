/*
 * session.c
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

#include "darwinports.h"

#include <tcl.h>

/*
 *
 * dp_session_t
 *
 */
struct session {
    char* portdbpath;
    char* portconf;
    char* sources_conf;
    dp_array_t sources;
    char* portsharepath;
    char* registry_path;
};

dp_session_t dp_session_open() {
    struct session* dp = (struct session*)malloc(sizeof(struct session));
    char* path;
    //dp_array_t conf_files = dp_array_create();
    
    dp->portconf = NULL;
    
    /* first look at PORTSRC for testing/debugging */
    path = getenv("PORTSRC");
    if (path != NULL && access(path, R_OK) == 0) {
        dp->portconf = strdup(path);
        //dp_array_append(conf_files, dp->portconf);
    }

    /* then look in ~/.portsrc */
    if (dp->portconf == NULL) {
        char* home = getenv("HOME");
        if (home != NULL) {
            char path[PATH_MAX];
            snprintf(path, sizeof(path), "%s/.portsrc", home);
            if (access(path, R_OK) == 0) {
                dp->portconf = strdup(path);
                //dp_array_append(conf_files, dp->portconf);
            }
        }
    }

    /* finally /etc/ports/ports.conf, or whatever path was configured */
    if (dp->portconf == NULL) {
        // XXX: honor autoconf setting ($dports_conf_path)
        char* path = "/etc/ports/ports.conf";
        if (access(path, R_OK) == 0) {
            dp->portconf = strdup(path);
            //dp_array_append(conf_files, dp->portconf);
        }
    }
    
    // foreach conf_files
    {
        int fd = open(dp->portconf, O_RDONLY, 0);
        if (fd != -1) {
            // XXX: parse config file
        }
    }
    
    if (dp->sources_conf == NULL) {
        fprintf(stderr, "sources_conf must be set in /etc/ports/ports.conf or in your ~/.portsrc\n");
    }
    
    
    
    return (dp_session_t)dp;
}

