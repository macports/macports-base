/*
 * BSD 2-Clause License
 *
 * Copyright (c) 2020 The MacPorts Project
 * Copyright (c) 2020, Mihir Luthra
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#ifndef __SHM_USER_TYPES_H__
#define __SHM_USER_TYPES_H__

#include <stdio.h>
#include <stdatomic.h>

#if ATOMIC_LONG_LOCK_FREE == 2

typedef unsigned long shm_offt;
#define PRIu_shm_offt "lu"

#elif ATOMIC_INT_LOCK_FREE == 2

typedef unsigned int shm_offt;
#define PRIu_shm_offt "u"

#else /* ATOMIC_INT_LOCK_FREE == 2 */

#	error "Neither ATOMIC_LONG_LOCK_FREE nor ATOMIC_INT_LOCK_FREE is 2, can't proceed"

#endif

#define SHM_NULL ((shm_offt)0)

#endif /* __SHM_USER_TYPES_H__ */
