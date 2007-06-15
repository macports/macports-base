/*
 * macports.h
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

#ifndef __MACPORTS_H__
#define __MACPORTS_H__

typedef void* mp_session_t;
typedef void* mp_software_t;

typedef void* mp_array_t;
mp_array_t mp_array_create();
mp_array_t mp_array_create_copy(mp_array_t a);
mp_array_t mp_array_retain(mp_array_t a);
void mp_array_release(mp_array_t a);
void mp_array_append(mp_array_t a, const void* data);
int mp_array_get_count(mp_array_t a);
const void* mp_array_get_index(mp_array_t a, int index);
/* something for delete */

mp_session_t mp_session_open();
int mp_session_sync_index();

int mp_software_search(mp_session_t mp, const char* regexp, mp_software_t* out_matches, int* out_count);
mp_software_t mp_software_open_portfile(mp_session_t mp, const char* path, const char** options);
mp_session_t mp_software_get_session(mp_software_t sw);
mp_software_t mp_software_exec(mp_software_t sw, const char* target);
int mp_softare_close(mp_software_t sw);

int mp_session_close();

#endif /* __MACPORTS_H__ */
