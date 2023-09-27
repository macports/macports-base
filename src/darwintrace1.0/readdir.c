/*
 * Copyright (c) 2005 Apple Inc. All rights reserved.
 * Copyright (c) 2005-2006 Paul Guyot <pguyot@kallisys.net>,
 * All rights reserved.
 * Copyright (c) 2006-2013 The MacPorts Project
 *
 * @APPLE_BSD_LICENSE_HEADER_START@
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 * 3.  Neither the name of Apple Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * @APPLE_BSD_LICENSE_HEADER_END@
 */

#include "darwintrace.h"

#include <errno.h>
#include <sys/dirent.h>
#include <sys/param.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>

/**
 * re-implementation of getdirent(2) and __getdirent64(2) preventing paths
 * outside the sandbox to show up when reading the contents of a directory.
 * Unfortunately, since we need to access the contents of the buffer, but the
 * contents differ by architecture, we can not rely on the dirent structure
 * defined by the header included by this program, because we don't know
 * whether darwintrace.dylib has been compiled for 64bit or 32bit inodes. We
 * thus copy both structs and decide at runtime.
 */

#if defined(__DARWIN_64_BIT_INO_T) && defined(HAVE___GETDIRENTRIES64)

struct dirent64  {
	__uint64_t  d_ino;      /* file number of entry */
	__uint64_t  d_seekoff;  /* seek offset */
	__uint16_t  d_reclen;   /* length of this record */
	__uint16_t  d_namlen;   /* length of string in d_name */
	__uint8_t   d_type;     /* file type */
	char      d_name[__DARWIN_MAXPATHLEN]; /* entry name (up to MAXPATHLEN bytes) */
};

// __getdirentries64(2) is private API. There's no header for it.
size_t __getdirentries64(int fd, void *buf, size_t bufsize, __darwin_off_t *basep);

static size_t _dt_getdirentries64(int fd, void *buf, size_t bufsize, __darwin_off_t *basep) {
	if (!__darwintrace_initialized) {
		return __getdirentries64(fd, buf, bufsize, basep);
	}

	__darwintrace_setup();

	size_t sz = __getdirentries64(fd, buf, bufsize, basep);
	// FIXME Support longer paths
	char dirname[MAXPATHLEN];
	size_t dnamelen;

	if (-1 == fcntl(fd, F_GETPATH, dirname)) {
		errno = EBADF;
		return -1;
	}

	dnamelen = strlen(dirname);
	if (dirname[dnamelen - 1] != '/') {
		dirname[dnamelen] = '/';
		dirname[dnamelen + 1] = '\0';
		dnamelen++;
	}

	dnamelen = strlen(dirname);
	size_t offset;
	for (offset = 0; offset < sz;) {
		struct dirent64 *dent = (struct dirent64 *)(((char *) buf) + offset);
		dirname[dnamelen] = '\0';
		// FIXME This crashes sometimes
		strcat(dirname, dent->d_name);
		if (!__darwintrace_is_in_sandbox(dirname, DT_ALLOWDIR)) {
			debug_printf("__getdirentries64: filtered %s\n", dirname);
			dent->d_ino = 0;
		} else {
			debug_printf("__getdirentries64:  allowed %s\n", dirname);
		}
		offset += dent->d_reclen;
	}

	return sz;
}

DARWINTRACE_INTERPOSE(_dt_getdirentries64, __getdirentries64);

#else

#pragma pack(4)
struct dirent32 {
	ino_t d_ino;            /* file number of entry */
	__uint16_t d_reclen;    /* length of this record */
	__uint8_t  d_type;      /* file type */
	__uint8_t  d_namlen;    /* length of string in d_name */
	char d_name[__DARWIN_MAXNAMLEN + 1]; /* name must be no longer than this */
};
#pragma pack()

// do not use dirent.h, as it applies a define to a non-existing symbol
int getdirentries(int fd, char *buf, int nbytes, long *basep);

static int _dt_getdirentries(int fd, char *buf, int nbytes, long *basep) {
	if (!__darwintrace_initialized) {
		return getdirentries(fd, buf, nbytes, basep);
	}

	__darwintrace_setup();

	size_t sz = getdirentries(fd, buf, nbytes, basep);
	char dirname[MAXPATHLEN];
	size_t dnamelen;

	if (-1 == fcntl(fd, F_GETPATH, dirname)) {
		errno = EBADF;
		return 0;
	}

	dnamelen = strlen(dirname);
	if (dirname[dnamelen - 1] != '/') {
		dirname[dnamelen] = '/';
		dirname[dnamelen + 1] = '\0';
		dnamelen++;
	}

	size_t offset;
	for (offset = 0; offset < sz;) {
		struct dirent32 *dent = (struct dirent32 *)(buf + offset);
		dirname[dnamelen] = '\0';
		strcat(dirname, dent->d_name);
		if (!__darwintrace_is_in_sandbox(dirname, DT_ALLOWDIR)) {
			debug_printf("getdirentries: filtered %s\n", dirname);
			dent->d_ino = 0;
		} else {
			debug_printf("getdirentries:  allowed %s\n", dirname);
		}
		offset += dent->d_reclen;
	}

	return sz;
}

DARWINTRACE_INTERPOSE(_dt_getdirentries, getdirentries);

#endif /* defined(__DARWIN_64_BIT_INO_T) && defined(HAVE___GETDIRENTRIES64) */
