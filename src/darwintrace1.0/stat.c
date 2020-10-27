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

#include <sys/syscall.h>
#include <errno.h>
#include <unistd.h>

// Do *not* include sys/stat.h, it will rewrite the stat to a stat$INODE64 symbol

// We don't include sys/stat.h because it would rewrite all stat function
// calls, but we need the declaration of stat here.
int stat(const char *path, void *sb);

/**
 * Wrapper around \c stat(2) to hide information about files outside the
 * sandbox.
 */
static int _dt_stat(const char *path, void *sb) {
	if (!__darwintrace_initialized) {
		return stat(path, sb);
	}

	__darwintrace_setup();

	int result = 0;

	if (!__darwintrace_is_in_sandbox(path, DT_REPORT | DT_ALLOWDIR | DT_FOLLOWSYMS)) {
		errno = ENOENT;
		result = -1;
	} else {
		result = stat(path, sb);
	}

	debug_printf("stat(%s) = %d\n", path, result);

	return result;
}

DARWINTRACE_INTERPOSE(_dt_stat, stat);

// Don't provide stat64 on systems that have no stat64 syscall
#if __DARWIN_64_BIT_INO_T && !__DARWIN_ONLY_64_BIT_INO_T

int stat64(const char *path, void *sb);
int stat$INODE64(const char *path, void *sb);

static int _dt_stat64(const char *path, void *sb) {
	if (!__darwintrace_initialized) {
		return stat64(path, sb);
	}

	__darwintrace_setup();

	int result = 0;

	if (!__darwintrace_is_in_sandbox(path, DT_REPORT | DT_ALLOWDIR | DT_FOLLOWSYMS)) {
		errno = ENOENT;
		result = -1;
	} else {
		result = stat64(path, sb);
	}

	debug_printf("stat64(%s) = %d\n", path, result);

	return result;
}

DARWINTRACE_INTERPOSE(_dt_stat64, stat64);
DARWINTRACE_INTERPOSE(_dt_stat64, stat$INODE64);

#endif /* __DARWIN_64_BIT_INO_T && !__DARWIN_ONLY_64_BIT_INO_T */

int lstat(const char *path, void *sb);

static int _dt_lstat(const char *path, void *sb) {
	if (!__darwintrace_initialized) {
		return lstat(path, sb);
	}

	__darwintrace_setup();

	int result = 0;

	// don't follow symlinks for lstat
	if (!__darwintrace_is_in_sandbox(path, DT_REPORT | DT_ALLOWDIR)) {
		errno = ENOENT;
		result = -1;
	} else {
		result = lstat(path, sb);
	}

	debug_printf("lstat(%s) = %d\n", path, result);

	return result;
}

DARWINTRACE_INTERPOSE(_dt_lstat, lstat);

// Don't provide lstat64 on systems that have no lstat64 syscall
#if __DARWIN_64_BIT_INO_T && !__DARWIN_ONLY_64_BIT_INO_T

int lstat64(const char *path, void *sb);
int lstat$INODE64(const char *path, void *sb);

static int _dt_lstat64(const char *path, void *sb) {
	if (!__darwintrace_initialized) {
		return lstat64(path, sb);
	}

	__darwintrace_setup();

	int result = 0;

	// don't follow symlinks for lstat
	if (!__darwintrace_is_in_sandbox(path, DT_REPORT | DT_ALLOWDIR)) {
		errno = ENOENT;
		result = -1;
	} else {
		result = lstat64(path, sb);
	}

	debug_printf("lstat64(%s) = %d\n", path, result);

	return result;
}

DARWINTRACE_INTERPOSE(_dt_lstat64, lstat64);
DARWINTRACE_INTERPOSE(_dt_lstat64, lstat$INODE64);

#endif /* __DARWIN_64_BIT_INO_T && !__DARWIN_ONLY_64_BIT_INO_T */
