/* vim: set et sw=4 ts=4 sts=4: */
/*
 * system.c
 *
 * Copyright (c) 2015 Clemens Lang <cal@macports.org>
 * Copyright (c) 2015 The MacPorts Project
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

#include <spawn.h>

/**
 * Behaves like execve(2), but checks whether trace mode is enabled (by
 * checking for DYLD_INSERT_LIBRARIES in the environment) and the binary is
 * covered by 10.11's new system integrity protection. If it is, the binary
 * will be copied to a separate folder (or updated if already there and
 * modification time differs) and executed from there.
 */
int sip_copy_execve(const char *path, char *const argv[], char *const envp[]);


/**
 * Behaves like posix_spawn(2), but checks whether trace mode is enabled (by
 * checking for DYLD_INSERT_LIBRARIES in the environment) and the binary is
 * covered by 10.11's new system integrity protection. If it is, the binary
 * will be copied to a separate folder (or updated if already there and
 * modification time differs) and executed from there.
 */
int sip_copy_posix_spawn(
        pid_t *restrict pid,
        const char *restrict path,
        const posix_spawn_file_actions_t *file_actions,
        const posix_spawnattr_t *restrict attrp,
        char *const argv[restrict],
        char *const envp[restrict]);
