/*
 * Pextlib.h
 *
 * Copyright (c) 2009, 2017 The MacPorts Project
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
 * 3. Neither the name of The MacPorts Project nor the names of its contributors
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

void ui_error(Tcl_Interp *interp, const char *format, ...) __attribute__((format(printf, 2, 3)));
void ui_warn(Tcl_Interp *interp, const char *format, ...) __attribute__((format(printf, 2, 3)));
void ui_msg(Tcl_Interp *interp, const char *format, ...) __attribute__((format(printf, 2, 3)));
void ui_notice(Tcl_Interp *interp, const char *format, ...) __attribute__((format(printf, 2, 3)));
void ui_info(Tcl_Interp *interp, const char *format, ...) __attribute__((format(printf, 2, 3)));
void ui_debug(Tcl_Interp *interp, const char *format, ...) __attribute__((format(printf, 2, 3)));

/* Mount point file system case-sensitivity caching infrastructure. */
typedef struct _mount_cs_cache mount_cs_cache_t;
mount_cs_cache_t* new_mount_cs_cache(void);
void reset_mount_cs_cache(mount_cs_cache_t *cache);

#ifdef __APPLE__
int fs_case_sensitive_darwin(Tcl_Interp *interp, const char *path, mount_cs_cache_t *cache);
#endif /* __APPLE__ */

int fs_case_sensitive_fallback(Tcl_Interp *interp, const char *path, mount_cs_cache_t *cache);
