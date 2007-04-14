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

#ifndef _XAR_FILETREE_H_
#define _XAR_FILETREE_H_

#include <libxml/xmlwriter.h>
#include <libxml/xmlreader.h>

struct __xar_attr_t {
	const char *key;
	const char *value;
	const char *ns;
	const struct __xar_attr_t *next;
};

struct __xar_prop_t {
        const char *key;
        const char *value;
        const struct __xar_prop_t *parent;
        const struct __xar_prop_t *children;
        const struct __xar_prop_t *next;
        const struct __xar_attr_t *attrs;
        const struct __xar_file_t *file;
	const char *prefix;
	const char *ns;
};

struct __xar_file_t {
	const struct __xar_prop_t *props;
	const struct __xar_attr_t *attrs;
	const char *prefix;
	const char *ns;
	const char *fspath;
	const struct __xar_file_t *parent;
	const struct __xar_file_t *children;
	const struct __xar_file_t *next;
};

typedef const struct __xar_prop_t *xar_prop_t;
typedef const struct __xar_attr_t *xar_attr_t;
#define XAR_ATTR(x) ((struct __xar_attr_t *)(x))
#define XAR_FILE(x) ((struct __xar_file_t *)(x))
#define XAR_PROP(x) ((struct __xar_prop_t *)(x))

void xar_file_free(xar_file_t f);
xar_attr_t xar_attr_new(void);
int32_t xar_attr_set(xar_file_t f, const char *prop, const char *key, const char *value);
const char *xar_attr_get(xar_file_t f, const char *prop, const char *key);
void xar_attr_free(xar_attr_t a);
void xar_file_serialize(xar_file_t f, xmlTextWriterPtr writer);
xar_file_t xar_file_unserialize(xar_t x, xar_file_t parent, xmlTextReaderPtr reader);
xar_file_t xar_file_find(xar_file_t f, const char *path);
xar_file_t xar_file_new(xar_file_t f);
void xar_file_free(xar_file_t f);

void xar_prop_serialize(xar_prop_t p, xmlTextWriterPtr writer);
int32_t xar_prop_unserialize(xar_file_t f, xar_prop_t parent, xmlTextReaderPtr reader);
void xar_prop_free(xar_prop_t p);
xar_prop_t xar_prop_new(xar_file_t f, xar_prop_t parent);

#endif /* _XAR_FILETREE_H_ */
