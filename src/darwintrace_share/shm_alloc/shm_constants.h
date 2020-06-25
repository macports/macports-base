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

#ifndef __SHM_CONSTANTS_H__
#define __SHM_CONSTANTS_H__

#include "shm_types.h"
#include "shm_user_types.h"
#include <stdatomic.h>
#include <unistd.h>

/*
 * This branch uses a single shm_bitmap variable to implement
 * buddy system.  (MAX_ALLOC_POW2 - MIN_ALLOC_POW2 <= 5) should hold true
 * if bitmap is of 64 bits.
 * If bitmap is of 32 bits, (MAX_ALLOC_POW2 - MIN_ALLOC_POW2 <= 4)
 */
#ifndef MAX_ALLOC_POW2
#	define MAX_ALLOC_POW2 (10) /* 1UL << 10 = 1024   */
#endif

#ifndef MIN_ALLOC_POW2
#	if ATOMIC_LONG_LOCK_FREE == 2
#		define MIN_ALLOC_POW2 (5)  /* 1UL << 5  = 32 */
#	else
#		define MIN_ALLOC_POW2 (6)  /* 1UL << 6  = 64 */
#	endif
#endif


/*
 * The size of mapping that is for allocating.
 * This need not necessarily be power of 2.
 * 1UL << 28 = 256 MB
 */
#ifndef MAX_ALLOCATABLE_SHM_SIZE
#	define MAX_ALLOCATABLE_SHM_SIZE (size_t)(1UL << (8+10+10))
#endif

/*
 * Maximum and minumum sizes that can be allocated
 * via shm_(m|c)alloc
 * Should always be a power of 2, that why they are to be set via
 * M(AX|IN)_ALLOC_POW2
 */
#define MAX_ALLOCATABLE_SIZE (size_t)(1UL << MAX_ALLOC_POW2)
#define MIN_ALLOCATABLE_SIZE (size_t)(1UL << MIN_ALLOC_POW2)

/*
 * This is the actual bitmap size.
 * It is not necessary for this to be same as BITS macro.
 * e.g., shm_bitmap maybe a type holding 64 bits but bitmap size
 * may only be 8 bits.
 */
#define BITMAP_SIZE  (int)((MAX_ALLOCATABLE_SIZE/MIN_ALLOCATABLE_SIZE) * 2)

#define SHM_DATA_TABLE_SIZE (sizeof(struct shm_data_table))

#define SHM_MGMT_SIZE ((MAX_ALLOCATABLE_SHM_SIZE/MAX_ALLOCATABLE_SIZE) * (sizeof(struct shm_block_mgmt)))

/*
 * sysconf(_SC_PAGESIZE) is portable but slow
 */
static inline int shm_getpagesize()
{
	static _Atomic(int) pagesize = -1;

	if (atomic_load(&pagesize) != -1) {
		return (pagesize);
	}

	int old_val = -1;

	atomic_compare_exchange_strong(&pagesize, &old_val, sysconf(_SC_PAGESIZE));

	return (atomic_load(&pagesize));
}

static inline shm_offt diff_next_page_boundary(shm_offt offset)
{
	int pagesize = shm_getpagesize();
	shm_offt mod_res;

	mod_res  = (offset) % pagesize;

	return (pagesize - (mod_res != 0 ? mod_res : pagesize));
}


/*
 * Description:
 *  Returns the offset from the mapping base,
 *  from where the shm data table region of shm starts.
 */
static inline shm_offt get_shm_data_table_offt()
{
	return (0);
}

/*
 * Description:
 *  Returns shm data table size
 */
static inline size_t get_shm_data_table_size()
{
	return (SHM_DATA_TABLE_SIZE);
}

/*
 * Description:
 *  Returns the offset from the mapping base,
 *  from where the mgmt region of shm starts.
 */
static inline shm_offt get_shm_mgmt_base_offt()
{
	return (get_shm_data_table_offt() + get_shm_data_table_size());
}

/*
 * Description:
 *  Returns size of shm mgmt
 */
static inline size_t get_shm_mgmt_size()
{
	return (SHM_MGMT_SIZE);
}

/*
 * Description:
 *  Returns offset from where shm null starts
 *  It needs to be aligned to page boundary
 *  as this page is made readonly by mmap(2) with PROT_READ.
 */
static inline shm_offt get_shm_null_base_offt()
{
	shm_offt offt;
	offt = get_shm_mgmt_base_offt() + get_shm_mgmt_size();

	offt += diff_next_page_boundary(offt);

	return (offt);
}

/*
 * Description:
 *  Reutuns shm null size.
 *  As PROT_READ is called upon shm null region,
 *  it needs to be multiple of page size
 */
static inline size_t get_shm_null_size()
{
	return (shm_getpagesize());
}

/*
 * Description:
 *  Returns the offset from the mapping base,
 *  from where the allocatable region of shm starts.
 */
static inline shm_offt get_allocatable_shm_base_offt()
{
	return (get_shm_null_base_offt());
}

/*
 * Description:
 *  Returns the offset from the mapping base,
 *  from where the allocatable region of shm starts.
 */
static inline size_t get_allocatable_shm_size()
{
	return (MAX_ALLOCATABLE_SHM_SIZE);
}

#define LAST_MEMORY_REGION_OFFT get_allocatable_shm_base_offt
#define LAST_MEMORY_REGION_SIZE get_allocatable_shm_size

#define SHM_MAPPING_SIZE (LAST_MEMORY_REGION_OFFT() + LAST_MEMORY_REGION_SIZE())

#endif /* __SHM_CONSTANTS_H__ */
