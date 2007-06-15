/*
 * portconf.c
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

#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>

#include "macports.h"

#include <tcl.h>

static int set_session_option(ClientData clientData UNUSED, Tcl_Interp *interp UNUSED, int objc UNUSED, Tcl_Obj *CONST objv[] UNUSED) {
    return TCL_OK;
}

void parse_port_conf(mp_session_t mp UNUSED, char* path) {
    int fd = open(path, O_RDONLY, 0);
    if (fd != -1) {
        Tcl_Interp* interp = Tcl_CreateInterp();
        char* bootstrap_options[] = {"portdbpath", "libpath", "binpath", "master_site_local",
				     "auto_path", "sources_conf", "prefix", NULL};
        char** option = bootstrap_options;
        while (*option != NULL) {
            Tcl_CreateObjCommand(interp, *option, &set_session_option, NULL, NULL);
            ++option;
        }
        /* XXX: parse config file */
    }
}
