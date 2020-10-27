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
#include <sys/stat.h>
#include <unistd.h>

#if __DARWIN_64_BIT_INO_T
#define LSTATSYSNUM SYS_lstat64
#else
#define LSTATSYSNUM SYS_lstat
#endif

/**
 * Wrapper around \c mkdir(2) that prevents creation of directories outside of
 * the sandbox. Will silently do nothing and return success for directories
 * outside the sandbox that already exist.
 */
static int _dt_mkdir(const char *path, mode_t mode) {
	if (!__darwintrace_initialized) {
		return mkdir(path, mode);
	}

	__darwintrace_setup();

	int result = 0;

	if (!__darwintrace_is_in_sandbox(path, DT_REPORT | DT_FOLLOWSYMS)) {
		struct stat st;
		if (-1 == lstat(path, &st) && errno == ENOENT) {
			// directory doesn't exist yet */
			errno = EACCES;
			result = -1;
		}
		// otherwise, leave result at 0 and return to indicate success
	} else {
		result = mkdir(path, mode);
	}

	debug_printf("mkdir(%s) = %d\n", path, result);

	return result;
}

DARWINTRACE_INTERPOSE(_dt_mkdir, mkdir);
