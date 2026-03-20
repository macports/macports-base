/*
 * sha3.c
 *
 * Streaming SHA3-256 implementation (Init/Update/Final) for MacPorts.
 *
 * The Keccak-f[1600] permutation is taken verbatim from the XKCP
 * (eXtended Keccak Code Package) CompactFIPS202 "readable-and-compact"
 * reference implementation by the Keccak Team:
 *   Guido Bertoni, Joan Daemen, Michael Peeters,
 *   Gilles Van Assche and Ronny Van Keer.
 * That code is CC0 1.0 (public domain):
 *   http://creativecommons.org/publicdomain/zero/1.0/
 * Source: https://github.com/XKCP/XKCP/blob/master/Standalone/CompactFIPS202/C/
 *
 * The streaming wrapper (Init/Update/Final) is:
 * Copyright (c) 2026 The MacPorts Project.
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

#include "sha3.h"
#include <string.h>

/* ================================================================
 * Endianness detection.
 *
 * The Keccak permutation operates on 64-bit lanes.  On little-endian
 * platforms we can use direct pointer casts; otherwise we fall back to
 * portable byte-by-byte load/store helpers.
 * ================================================================ */

#if defined(__BYTE_ORDER__) && defined(__ORDER_LITTLE_ENDIAN__)
  #if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    #define KECCAK_LITTLE_ENDIAN 1
  #endif
#elif defined(__LITTLE_ENDIAN__) || defined(__ARMEL__) || \
      defined(__THUMBEL__) || defined(__AARCH64EL__) || \
      defined(__i386__) || defined(__x86_64__) || \
      defined(_M_IX86) || defined(_M_X64) || defined(_M_AMD64)
  #define KECCAK_LITTLE_ENDIAN 1
#endif

/* ================================================================
 * Keccak-f[1600] permutation — from XKCP CompactFIPS202 (CC0).
 *
 * All functions in this section are declared static to avoid symbol
 * collisions when this file is #include'd into a compilation unit.
 * ================================================================ */

typedef uint64_t tKeccakLane;

#ifndef KECCAK_LITTLE_ENDIAN
static uint64_t
keccak_load64(const uint8_t *x)
{
    int i;
    uint64_t u = 0;

    for (i = 7; i >= 0; --i) {
        u <<= 8;
        u |= x[i];
    }
    return u;
}

static void
keccak_store64(uint8_t *x, uint64_t u)
{
    unsigned int i;

    for (i = 0; i < 8; ++i) {
        x[i] = (uint8_t)u;
        u >>= 8;
    }
}

static void
keccak_xor64(uint8_t *x, uint64_t u)
{
    unsigned int i;

    for (i = 0; i < 8; ++i) {
        x[i] ^= (uint8_t)u;
        u >>= 8;
    }
}
#endif /* !KECCAK_LITTLE_ENDIAN */

#define ROL64(a, offset) \
    ((((uint64_t)(a)) << (offset)) ^ (((uint64_t)(a)) >> (64 - (offset))))
#define KI(x, y) ((x) + 5 * (y))

#ifdef KECCAK_LITTLE_ENDIAN
    #define readLane(x, y)          (((tKeccakLane*)state)[KI(x, y)])
    #define writeLane(x, y, lane)   (((tKeccakLane*)state)[KI(x, y)]) = (lane)
    #define XORLane(x, y, lane)     (((tKeccakLane*)state)[KI(x, y)]) ^= (lane)
#else
    #define readLane(x, y) \
        keccak_load64((uint8_t*)state + sizeof(tKeccakLane) * KI(x, y))
    #define writeLane(x, y, lane) \
        keccak_store64((uint8_t*)state + sizeof(tKeccakLane) * KI(x, y), lane)
    #define XORLane(x, y, lane) \
        keccak_xor64((uint8_t*)state + sizeof(tKeccakLane) * KI(x, y), lane)
#endif

/**
 * Linear feedback shift register used to define the round constants.
 * See [Keccak Reference, Section 1.2].
 */
static int
LFSR86540(uint8_t *LFSR)
{
    int result = ((*LFSR) & 0x01) != 0;
    if (((*LFSR) & 0x80) != 0)
        (*LFSR) = ((*LFSR) << 1) ^ 0x71;
    else
        (*LFSR) <<= 1;
    return result;
}

/**
 * The Keccak-f[1600] permutation.
 */
static void
KeccakF1600_StatePermute(void *state)
{
    unsigned int round, x, y, j, t;
    uint8_t LFSRstate = 0x01;

    for (round = 0; round < 24; round++) {
        {   /* === theta step === */
            tKeccakLane C[5], D;

            for (x = 0; x < 5; x++)
                C[x] = readLane(x, 0) ^ readLane(x, 1) ^ readLane(x, 2)
                      ^ readLane(x, 3) ^ readLane(x, 4);
            for (x = 0; x < 5; x++) {
                D = C[(x + 4) % 5] ^ ROL64(C[(x + 1) % 5], 1);
                for (y = 0; y < 5; y++)
                    XORLane(x, y, D);
            }
        }

        {   /* === rho and pi steps === */
            tKeccakLane current, temp;
            x = 1; y = 0;
            current = readLane(x, y);
            for (t = 0; t < 24; t++) {
                unsigned int r, Y;
                r = ((t + 1) * (t + 2) / 2) % 64;
                Y = (2 * x + 3 * y) % 5; x = y; y = Y;
                temp = readLane(x, y);
                writeLane(x, y, ROL64(current, r));
                current = temp;
            }
        }

        {   /* === chi step === */
            tKeccakLane temp[5];
            for (y = 0; y < 5; y++) {
                for (x = 0; x < 5; x++)
                    temp[x] = readLane(x, y);
                for (x = 0; x < 5; x++)
                    writeLane(x, y,
                        temp[x] ^ ((~temp[(x + 1) % 5]) & temp[(x + 2) % 5]));
            }
        }

        {   /* === iota step === */
            for (j = 0; j < 7; j++) {
                unsigned int bitPosition = (1 << j) - 1;
                if (LFSR86540(&LFSRstate))
                    XORLane(0, 0, (tKeccakLane)1 << bitPosition);
            }
        }
    }
}

/* Clean up internal macros so they don't leak out. */
#undef ROL64
#undef KI
#undef readLane
#undef writeLane
#undef XORLane

/* ================================================================
 * Streaming SHA3-256 API (Init / Update / Final).
 *
 * SHA3-256 uses Keccak[r=1088, c=512] with the domain separation
 * suffix 0x06.
 * ================================================================ */

void
SHA3_256_Init(SHA3_256_CTX *ctx)
{
    memset(ctx->state, 0, sizeof(ctx->state));
    ctx->pt = 0;
}

void
SHA3_256_Update(SHA3_256_CTX *ctx, const uint8_t *data, size_t len)
{
    unsigned int pt = ctx->pt;

    while (len-- > 0) {
        ctx->state[pt++] ^= *data++;
        if (pt >= SHA3_256_RATE) {
            KeccakF1600_StatePermute(ctx->state);
            pt = 0;
        }
    }

    ctx->pt = pt;
}

void
SHA3_256_Final(uint8_t digest[SHA3_256_DIGEST_LENGTH], SHA3_256_CTX *ctx)
{
    /*
     * Padding for SHA3: append the domain separation bits (0x06) at the
     * current position, then set the last bit of the rate block (0x80),
     * and apply the final permutation.
     *
     * For SHA3 (delimitedSuffix = 0x06), bit 7 of the suffix is 0, so
     * there is no edge case when pt == rate - 1 that requires an extra
     * permutation before setting the final padding bit.
     */
    ctx->state[ctx->pt] ^= 0x06;
    ctx->state[SHA3_256_RATE - 1] ^= 0x80;
    KeccakF1600_StatePermute(ctx->state);

    /* Squeeze: for SHA3-256 the output (32 bytes) fits within one rate
     * block (136 bytes), so a single squeeze is sufficient. */
    memcpy(digest, ctx->state, SHA3_256_DIGEST_LENGTH);
}
