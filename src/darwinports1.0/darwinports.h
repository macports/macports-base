/*
 * darwinports.h
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

#ifndef __DARWINPORTS_H__
#define __DARWINPORTS_H__

typedef void* dp_session_t;
typedef void* dp_software_t;

typedef void* dp_array_t;
dp_array_t dp_array_create();
dp_array_t dp_array_create_copy(dp_array_t a);
dp_array_t dp_array_retain(dp_array_t a);
void dp_array_release(dp_array_t a);
void dp_array_append(dp_array_t a, const void* data);
int dp_array_get_count(dp_array_t a);
const void* dp_array_get_index(dp_array_t a, int index);
// something for delete

dp_session_t dp_session_open();
int dp_session_sync_index();

int dp_software_search(dp_session_t dp, const char* regexp, dp_software_t* out_matches, int* out_count);
dp_software_t dp_software_open_portfile(dp_session_t dp, const char* path, const char** options);
dp_session_t dp_software_get_session(dp_software_t sw);
dp_software_t dp_software_exec(dp_software_t sw, const char* target);
int dp_softare_close(dp_software_t sw);

int dp_session_close();

#endif /* __DARWINPORTS_H__ */