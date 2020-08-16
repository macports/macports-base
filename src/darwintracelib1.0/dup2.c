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

#define DARWINTRACE_USE_PRIVATE_API 1
#include "darwintrace.h"

#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

/**
 * Wrapper around \c dup(2) that moves darwintrace's socket FD if software
 * attempts to overwrite it using \c dup(2). Shells tend to do that a lot when
 * FDs are numbered in ascending order.
 */
static int _dt_dup2(int filedes, int filedes2) {
	if (!__darwintrace_initialized) {
		return dup2(filedes, filedes2);
	}

	__darwintrace_setup();

	FILE *stream = __darwintrace_sock();
	if (stream && filedes2 == fileno(stream)) {
		// if somebody tries to close our file descriptor, just move it out of
		// the way. Make sure it doesn't end up as stdin/stdout/stderr, though!
		int new_darwintrace_fd;
		FILE *new_stream;

		if (-1 == (new_darwintrace_fd = fcntl(fileno(stream), F_DUPFD, STDOUT_FILENO + 1))) {
			// if duplicating fails, do not allow overwriting either!
			return -1;
		}

		__darwintrace_close();
		if (NULL == (new_stream = fdopen(new_darwintrace_fd, "a+"))) {
			perror("darwintrace: fdopen");
			abort();
		}
		__darwintrace_sock_set(new_stream);
	}

	return dup2(filedes, filedes2);
}

DARWINTRACE_INTERPOSE(_dt_dup2, dup2);
