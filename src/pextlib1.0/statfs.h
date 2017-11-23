/*
 * statfs.h
 *
 * Copyright (c) 2017 The MacPorts Project.
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
 * 3. Neither the name of MacPorts Team nor the names of its contributors
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

#include <tcl.h>

/* Add new access to statfs members via X-macros; X(MEMBER_NAME, TCL_FCN_NAME)
 * new members can be added with a new line here, and all necessary (C and TCL
 * interface) functions are created in Pextlib.c and statfs.c. */

/* String members */
#define STATFS_STRINGS \
 X(f_fstypename,    statfs_fstype_name) \
 X(f_mntfromname,   statfs_dev_node) \
 X(f_mntonname,     statfs_mnt_pt)

/* Int members (all cast to long) members */
#define STATFS_LONGS \
 X(f_iosize, statfs_io_size)

/* Useful for X-macros where type is irrelevant. */
#define STATFS_ALL \
 STATFS_STRINGS \
 STATFS_LONGS

/* X-macro to declare accessor functions. */
#define X(_MEMB_, UNUSED) \
int _MEMB_##Cmd(ClientData clientData, \
                Tcl_Interp* interp, \
                int objc, \
                Tcl_Obj* CONST objv[]);
STATFS_ALL
#undef X
