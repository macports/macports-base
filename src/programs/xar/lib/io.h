/*
 * Copyright (c) 2005 Rob Braun
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
 * 3. Neither the name of Rob Braun nor the names of his contributors
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
/*
 * 03-Apr-2005
 * DRI: Rob Braun <bbraun@opendarwin.org>
 */

#ifndef _XAR_IO_H_
#define _XAR_IO_H_

typedef int (*read_callback)(xar_t, xar_file_t, void *, size_t);
typedef int (*write_callback)(xar_t, xar_file_t, void *, size_t);

typedef int (*fromheap_in)(xar_t x, xar_file_t f, const char *attr, void **in, size_t *inlen);
typedef int (*fromheap_out)(xar_t x, xar_file_t f, const char *attr, void *in, size_t inlen);
typedef int (*fromheap_done)(xar_t x, xar_file_t f, const char *attr);

typedef int (*toheap_in)(xar_t x, xar_file_t f, const char *attr, void **in, size_t *inlen);
typedef int (*toheap_out)(xar_t x, xar_file_t f, const char *attr, void *in, size_t inlen);
typedef int (*toheap_done)(xar_t x, xar_file_t f, const char *attr);

struct datamod {
	fromheap_in      fh_in;
	fromheap_out     fh_out;
	fromheap_done    fh_done;
	toheap_in        th_in;
	toheap_out       th_out;
	toheap_done      th_done;
};

int32_t xar_attrcopy_to_heap(xar_t x, xar_file_t f, const char *attr, read_callback rcb);
int32_t xar_attrcopy_from_heap(xar_t x, xar_file_t f, const char *attr, write_callback wcb);
int32_t xar_heap_to_archive(xar_t x);

#endif /* _XAR_IO_H_ */
