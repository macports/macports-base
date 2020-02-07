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

#ifndef __SHM_BIT_FIDDLER__
#define __SHM_BIT_FIDDLER__

#include "shm_constants.h"
#include "shm_types.h"
#include <stdatomic.h>
#include <stdbool.h>
#include <strings.h>

#if ATOMIC_LONG_LOCK_FREE == 2
#	define __BUILTIN_POPCOUNT(num)  __builtin_popcountl(num)
#	define __BUILTIN_CLZ(num)       __builtin_clzl(num)
#	define __BUILTIN_CTZ(num)       __builtin_ctzl(num)
#	define __BUILTIN_FFS(num)		__builtin_ffsl(num)
#elif ATOMIC_INT_LOCK_FREE == 2
#	define __BUILTIN_POPCOUNT(num)  __builtin_popcount(num)
#	define __BUILTIN_CLZ(num)       __builtin_clz(num)
#	define __BUILTIN_CTZ(num)       __builtin_ctz(num)
#	define __BUILTIN_FFS(num)       __builtin_ffs(num)
#else
#	error "Neither ATOMIC_LONG_LOCK_FREE nor ATOMIC_INT_LOCK_FREE is 2, can't proceed"
#endif

#define BITS (sizeof(shm_bitmap) * 8)


static inline shm_bitmap set_bit(shm_bitmap bmp, int bitpos)
{
	return (bmp | (shm_bitmap)1 << (BITS - bitpos - 1));
}

static inline shm_bitmap unset_bit(shm_bitmap bmp, int bitpos)
{
	return (bmp & ~((shm_bitmap)1 << (BITS - bitpos - 1)));
}

/*
 * Description:
 *  Sets children of param2 whose level is computed by param3.
 *
 * param1:
 *  The bitmap
 *
 * param2:
 *  The bit pos whose children are to be set.
 *
 * param3:
 *  This serves two purposes here.
 *  First, this is the number of chidren bits.
 *  e.g., a bit of memory level 512 has 4 children at level 128.
 *  Second, it is used to identify the level at which children are.
 *  e.g., If bit number is 2 and multiplier is 4, then the children start from
 *  bit 2*4 = 8. So basically set 4 bits starting from posn 8.
 *
 * retval:
 *  bitmap with children set as per the multiplier
 */
static inline shm_bitmap set_children_bits(shm_bitmap bmp, int bitpos, int multiplier)
{
	/*
	 * ((shm_bitmap)1 << multiplier) - 1) :
	 *   e.g., multiplier = 4, 1 << 4 = ...0010000
	 *   ...0010000 - 1 = ...0001111
	 *
	 *   where ... represents remaining 0 bits
	 *
	 *  Child start posn is identified by bitpos*multiplier.
	 *  So we just shift the bits obtained above at the correct posn
	 *  and | with param1
	 */
	return (bmp | ((((shm_bitmap)1 << multiplier) - 1) << (BITS - bitpos*multiplier - 1 - (multiplier - 1))));
}

/*
 * Description:
 *  Sets param3 bits starting from posn param2
 *
 * param1:
 *  The bitmap
 *
 * param2:
 *  Start pos
 *
 * param3:
 *  Count of bits to set
 *
 * retval:
 *  bitmap wil set bit range from to from+cnt
 */
static inline shm_bitmap set_bit_range(shm_bitmap bmp, int from, int cnt)
{
	return (bmp | ((((shm_bitmap)1 << cnt) - 1) << (BITS - from - 1 - (cnt - 1))));
}

static inline int get_start_bit_pos_for_mem_level(size_t mem)
{
	return (MAX_ALLOCATABLE_SIZE/mem);
}

static inline bool is_power_of_two(lock_free_int num)
{
	return (1 == __BUILTIN_POPCOUNT(num));
}

static inline lock_free_int get_prev_power_of_two(lock_free_int num)
{
	if (num == 0)
		num = -1;

	return ((lock_free_int)1 << ((sizeof(lock_free_int)*8) - 1 - __BUILTIN_CLZ(num)));
}


static inline lock_free_int get_next_power_of_two(lock_free_int num)
{
	if (num == 1 || num > (-(lock_free_int)1)/2 + 1)
		return 1;

	return ((lock_free_int)1 << ((sizeof(lock_free_int)*8) - __BUILTIN_CLZ(num-1)));
}

/*
 * Description:
 *  Abs position is the posn of bit starting from 0
 *
 * param1:
 *  relative bit posn at memory level param2
 *
 * param2:
 *  Memory level
 *
 * retval:
 *  corresponding abs bit posn
 */
static inline int get_abs_bit_pos(int rel_pos, size_t mem_level)
{
	return (get_start_bit_pos_for_mem_level(mem_level) + rel_pos);
}

/*
 * Description:
 *  Relative bit position is the bit position considering
 *  the first bit of a particular memory level as 0th bit.
 *  e.g., If starting bit of memory level 256 lies at posn
 *  4, then relative bit posn for abs posn 4 will be 0 for mem
 *  level 256. Consequently, for bit posn 5, rel bit pos will be 1
 *  and so on.
 *
 * param1:
 *  abs bit posn
 *
 * retval:
 *  Corresponding relative bit pos
 */
static inline int get_rel_bit_pos(int abs_bit_pos)
{
	return (abs_bit_pos - get_prev_power_of_two(abs_bit_pos));
}

#endif /* __SHM_BIT_FIDDLER__ */
