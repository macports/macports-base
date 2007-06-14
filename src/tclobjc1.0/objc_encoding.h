/*
 * objc_encoding.h
 *
 * Copyright (c) 2004 Landon J. Fuller <landonf@opendarwin.org>
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
 * 3. Neither the name of the copyright owner nor the names of contributors
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

int objc_to_tclobj(Tcl_Interp *interp, Tcl_Obj **objPtr, const char *type, void *val);
int tclobj_to_objc(Tcl_Interp *interp, void **val, const char *type, Tcl_Obj *objPtr);

#ifdef GNU_RUNTIME
#include <objc/encoding.h>
#endif

#ifdef APPLE_RUNTIME
#include <objc/objc-class.h>
#define _C_BYCOPY       'O'
#define _C_IN           'n'
#define _C_OUT          'o'
#define _C_INOUT        'N'
#define _C_CONST        'r'
#define _C_ONEWAY       'V'
#define _C_BYREF        'R' /* XXX unsupported */
#define _C_GCINVISIBLE  '!' /* XXX unsupported */

#define _F_BYCOPY       0x04
#define _F_IN           0x01
#define _F_OUT          0x02
#define _F_INOUT        0x03
#define _F_CONST        0x01
#define _F_ONEWAY       0x10
#define _F_BYREF        0x08
#define _F_GCINVISIBLE  0x20 /* XXX unsupported */
#endif
