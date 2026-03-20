/*
 * sha3.h
 *
 * Streaming SHA3-256 interface (Init/Update/Final) built on top of the
 * Keccak-f[1600] permutation from the XKCP (eXtended Keccak Code Package)
 * by Guido Bertoni, Joan Daemen, Michael Peeters, Gilles Van Assche and
 * Ronny Van Keer.  The underlying permutation code is CC0 (public domain).
 *
 * This wrapper is Copyright (c) 2026 The MacPorts Project.
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
 * 3. Neither the name of The MacPorts Project nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SHA3_H
#define _SHA3_H

#include <stdint.h>
#include <stddef.h>

/*
 * SHA3-256 parameters:
 *   Keccak-f[1600], capacity = 512 bits, rate = 1088 bits = 136 bytes
 *   Output = 256 bits = 32 bytes
 */
#define SHA3_256_DIGEST_LENGTH  32
#define SHA3_256_RATE           136

typedef struct {
    uint8_t     state[200];     /* Keccak-f[1600] state (5x5 x 64 bits) */
    unsigned int pt;            /* index into the rate portion of state  */
} SHA3_256_CTX;

void SHA3_256_Init(SHA3_256_CTX *ctx);
void SHA3_256_Update(SHA3_256_CTX *ctx, const uint8_t *data, size_t len);
void SHA3_256_Final(uint8_t digest[SHA3_256_DIGEST_LENGTH], SHA3_256_CTX *ctx);

#endif /* _SHA3_H */
