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

#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <assert.h>
#include <fcntl.h>
#include <pthread.h>

#include "shm_alloc.h"
#include "shm_bit_fiddler.h"
#include "shm_constants.h"
#include "shm_debug.h"
#include "shm_err.h"
#include "shm_types.h"
#include "shm_user_types.h"

#include <stdarg.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static _Atomic(struct shm_manager *) manager = NULL;


#define ACCESS_SHM_MGMT(offset) \
	((struct shm_block_mgmt *)((uint8_t *)manager->shm_mapping.base + get_shm_mgmt_base_offt() + (offset)))

#define ACCESS_SHM_DATA_TABLE(offset) \
	((struct shm_data_table *)((uint8_t *)manager->shm_mapping.base + get_shm_data_table_offt() + (offset)))

#define ACCESS_SHM_MGMT_BY_MGMT_BLK_NO(bitmap_no) \
	ACCESS_SHM_MGMT((bitmap_no) * sizeof(struct shm_block_mgmt))

#define ACCESS_SHM_MAPPING(offset) \
	((void *)((uint8_t *)manager->shm_mapping.base + (offset)))



#define ACCESS_SHM_MAPPING_BY_MANAGER(manager, offset) \
	((void *)((uint8_t *)manager->shm_mapping.base + (offset)))

#define ACCESS_SHM_MGMT_BY_MANAGER(manager, offset) \
	((struct shm_block_mgmt *)((uint8_t *)manager->shm_mapping.base + get_shm_mgmt_base_offt() + (offset)))

#define ACCESS_SHM_MGMT_BY_MGMT_BLK_NO_BY_MANAGER(manager, bitmap_no) \
	ACCESS_SHM_MGMT_BY_MANAGER(manager, (bitmap_no) * sizeof(struct shm_block_mgmt))

/*
 * shm base for user starts from offset to null.
 * Means if we return offset 0 to user, it is null.
 *
 * Allocatable region is followed by null region
 */
#define ACCESS_SHM_FOR_USER(offset) \
	((uint8_t *)manager->shm_mapping.base + get_shm_null_base_offt() + (offset))



/*
 * retval:
 *  If success returns `true` else `false`
 *
 * param1 :
 *  Memory required
 *
 * param2 :
 *  Pass address of a `struct bmp_data_mgr` which gets filled
 *  with the allocated bitmap data
 *
 * Description:
 *  The function iterates over the mgmt mapping area,
 *  checking the bitmaps for availability of the required memory.
 *  If a bitmap with desired memory is found, allocation is done
 *  by setting the bit and the bitmap data is filled in param2.
 */
static bool search_all_bitmaps_for_mem(size_t, struct bmp_data_mgr *);

/*
 * retval:
 *  Returns the address of blk mgr that is stored in
 *  shm data table region.
 *
 * Description:
 *  This is the blk mgr that is supposed to have the first free
 *  memory not considering the ones freed by shm_free().
 *  Coming straight to it saves the unnecessary iterations
 *  to reach here.
 */
static struct shm_block_mgmt * get_start_blk_mgr();

/*
 * retval:
 *  If the update was made, true is returned else false
 *
 * Description:
 *  Updates the start blk mgr if param1 is greater than
 *  previous value of address.
 *
 * param1:
 *  New blk mgr to be set.
 */
static bool update_start_blk_mgr(struct shm_block_mgmt *);

/*
 * retval:
 *  Returns relative bit posn for memory level passed as param2
 *  if allocation is successfully performed in the buddy bitmap passed
 *  as param1.
 *  Returns -1 in case of failure.
 *
 * param1:
 *  Address of a `struct shm_block_mgmt` type in which allocation needs
 *  to be performed.
 *
 * param2:
 *  Amount of memory to be allocated
 */
static int occupy_mem_in_bitmap(struct shm_block_mgmt *, size_t);

/*
 * Description:
 *  This sets all children of the bit posn param1.
 *
 * param1:
 *  The bit posn whose set bitmap is needed
 *
 * retval:
 *  Bitmap with param1's children set
 */
static shm_bitmap get_set_bitmap_for_bit(int);

/*
 * retval:
 *  A `struct mem_offt_mgr` type is returned with all elements filled
 *  in accordance with param1.
 *
 * param1:
 *  A `struct bmp_data_mgr` type with all elements filled.
 *
 * Description:
 *  Evaluates the offsets in accordance with the passed bitmap data
 *  w.r.t the user's shm base.
 *
 */
static struct mem_offt_mgr get_offset_for_user_by_bmp_data(struct bmp_data_mgr);

/*
 * retval:
 *  A `struct mem_offt_mgr` type is returned with all elements filled
 *  in accordance with param1.
 *
 * param1:
 *  The net offset that was returned to the user.
 */
static struct mem_offt_mgr convert_offset_to_mem_offt_mgr(shm_offt);

/*
 * retval:
 *  A `struct bmp_data_mgr` type is returned with all elements filled
 *  in accordance with param1.
 *
 * param1:
 *  A `struct mem_offt_mgr` type with all elements filled.
 *
 * Description:
 *  Evaluates the bitmap data in accordance with the passed offset data.
 */
static struct bmp_data_mgr get_bmp_data_by_mem_offt_data(struct mem_offt_mgr);

/*
 * retval:
 *  Returns a `struct blk_hdr` loaded with header info
 *
 * param1:
 *  An offset allocated by shm_(m|c)alloc.
 *
 * NOTE:
 *  The size stored in the header includes
 *  the size occupied by header aswell.
 */
static struct blk_hdr get_blk_hdr(shm_offt);

/*
 * param1:
 *  Offset as per the user.
 *
 * param2:
 *  The value to be stored in header.
 *
 * Description:
 *  Sets the value in the header area of allocated
 *  memory to the value of param2
 */
static void set_blk_hdr(shm_offt, struct blk_hdr);

/*
 * param1:
 *  A struct shm_manager * that whose values
 *  were set by shm_init()
 *
 * Description:
 *  unmaps the mappings whose addr is in manager
 *  and frees the manager itself
 */
static void shm_deinit_by_manager(struct shm_manager *);

/*
 * This is the function which does the setting up
 * of shared mappings.
 *
 * It would first create/open a file that is to be used as
 * the shared memory, ftruncate(2) it to desired size(which also fills the file with zeros)
 * and mmap(2) the file into the current process.
 * This function can handle being called within multiple processes/threads.
 */
bool shm_init(void *optional_addr, const char *shm_filename)
{
	int retval, num_mgrs;
	struct stat st;
	struct shm_manager *new_manager, *old_manager;
	struct shm_block_mgmt *null_blk_mgr;
	void * shm_null_base;
	size_t shm_null_size;
	shm_bitmap old_bmp, new_bmp, set_mask;

	if (manager != NULL) {
		return (true);
	}

#ifndef NDEBUG
	if (BITMAP_SIZE > BITS) {
		P_ERR("This shm cache doesn't support power difference more than %d",
		    MAX_ALLOC_POW2 - MIN_ALLOC_POW2 - __BUILTIN_CTZ(BITMAP_SIZE/BITS));
		P_ERR("Current MAX_ALLOC_POW2 - MIN_ALLOC_POW2 = %d\n", MAX_ALLOC_POW2 - MIN_ALLOC_POW2);
		abort();
	}
#endif

	assert(get_shm_min_allocatable_size() < get_shm_max_allocatable_size());

	new_manager = malloc(sizeof(struct shm_manager));

	if (new_manager == NULL) {
		P_ERR("malloc(2) failed");
		return (false);
	}

	new_manager->shm_file.name = shm_filename;

	if (new_manager->shm_file.name == NULL) {

		P_ERR("arg(shm_filename) is NULL");
		return (false);
	}

	/* would create file if doesn't exist yet */
	new_manager->shm_file.fd = open(new_manager->shm_file.name, O_CREAT | O_RDWR, 0666);

	if (new_manager->shm_file.fd == -1) {
		P_ERR("open(2) failed");
		free(new_manager);
		return (false);
	}

	retval = fstat(new_manager->shm_file.fd, &st);

	if (retval == -1) {
		P_ERR("fstat(2) failed");
		free(new_manager);
		return (false);
	}

	new_manager->shm_file.size = st.st_size;
	new_manager->shm_mapping.size = SHM_MAPPING_SIZE;

	if (new_manager->shm_file.size == 0) {

		/*
		 * remember ftruncate(2) sets all file to 0
		 */
		retval = ftruncate(new_manager->shm_file.fd, new_manager->shm_mapping.size);

		if (retval == -1) {
			free(new_manager);
			P_ERR("ftruncate(2) failed");
			return (false);
		}

		 new_manager->shm_file.size = new_manager->shm_mapping.size;
	}

	if (optional_addr == NULL) {
		new_manager->shm_mapping.base =
		    mmap(NULL, new_manager->shm_file.size, PROT_READ | PROT_WRITE, MAP_SHARED,
		    new_manager->shm_file.fd, 0);
	} else {
		new_manager->shm_mapping.base =
		    mmap(optional_addr, new_manager->shm_file.size, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_FIXED,
		    new_manager->shm_file.fd, 0);
	}

	if (new_manager->shm_mapping.base == MAP_FAILED) {
		free(new_manager);
		P_ERR("mmap(2) failed");
		return (false);
	}

	/*
	 * Make the region called as shm null readonly
	 * This would make it easier to debug such that
	 * if null region is accessed, error is generated
	 * saying readonly memory accessed
	 */
	shm_null_base = ACCESS_SHM_MAPPING_BY_MANAGER(new_manager, get_shm_null_base_offt());
	shm_null_size = get_shm_null_size();

	if (mmap(shm_null_base, shm_null_size, PROT_READ, MAP_SHARED | MAP_FIXED,
	    new_manager->shm_file.fd, 0) == MAP_FAILED) {

		P_ERR("mmap(2) failed while setting shm null");
		free(new_manager);
		return (false);
	}

	(void)close(new_manager->shm_file.fd);

	/*
	 * As shm null exists in the allocatable region,
	 * we need to set its management block to indicate that its completely
	 * used
	 */
	num_mgrs = shm_null_size/MAX_ALLOCATABLE_SIZE + (shm_null_size % MAX_ALLOCATABLE_SIZE > 0 ? 1 : 0);
	set_mask = get_set_bitmap_for_bit(get_start_bit_pos_for_mem_level(MAX_ALLOCATABLE_SIZE));

	for (int mgr = 0 ; mgr < num_mgrs ; ++mgr) {

		null_blk_mgr = ACCESS_SHM_MGMT_BY_MGMT_BLK_NO_BY_MANAGER(new_manager, mgr);

		do {
			old_bmp = null_blk_mgr->mgmt_bmp;
			new_bmp = old_bmp | set_mask;

		}while (!atomic_compare_exchange_weak_explicit(&null_blk_mgr->mgmt_bmp, &old_bmp, new_bmp,
		    memory_order_relaxed, memory_order_relaxed));

		atomic_store(&null_blk_mgr->mem_used, MAX_ALLOCATABLE_SIZE);
	}

	old_manager = NULL;

	if (!atomic_compare_exchange_strong_explicit(&manager, &old_manager, new_manager,
	    memory_order_relaxed, memory_order_relaxed)) {

		shm_deinit_by_manager(new_manager);
		return (true);
	}

	return (true);
}

size_t get_mapping_size_needed_by_shm()
{
	return (SHM_MAPPING_SIZE);
}

static void shm_deinit_by_manager(struct shm_manager *this_manager)
{
	int retval;

	if (this_manager == NULL) {
		P_ERR("manager is NULL");
		return;
	}

	retval = munmap(this_manager->shm_mapping.base, this_manager->shm_mapping.size);

	if (retval == -1) {
		P_ERR("munmap(2) failed");
	}

	free(this_manager);
}

void shm_deinit()
{
	shm_deinit_by_manager(manager);
	manager = NULL;
}

size_t get_shm_max_allocatable_size()
{
	return (MAX_ALLOCATABLE_SIZE);
}

size_t get_sizeof_block_header()
{
	return (sizeof(struct blk_hdr));
}

size_t get_shm_min_allocatable_size()
{
	return (MIN_ALLOCATABLE_SIZE);
}

void * get_shm_user_base(void)
{

	if (manager == NULL) {
		P_ERR("manager == NULL");
		return (NULL);
	}

#if ATOMIC_POINTER_LOCK_FREE == 2
	/*
	 * Well basically this function is equivalent to ACCESS_SHM_FOR_USER(0)
	 * We do the crap below to store the value of ACCESS_SHM_FOR_USER(0)
	 * so that subsequent calls don't need to call ACCESS_SHM_FOR_USER(0)
	 */

	static _Atomic(void *) base = NULL;

	if (atomic_load(&base) == NULL) {
		void *old_val = NULL;
		atomic_compare_exchange_strong(&base, &old_val, ACCESS_SHM_FOR_USER(0));
	}

	return (atomic_load(&base));
#else
	return (ACCESS_SHM_FOR_USER(0));
#endif
}

shm_offt shm_malloc(size_t size)
{
	if (manager == NULL) {
		P_ERR("manager == NULL");
		return (SHM_NULL);
	}

	size_t reqd_size;
	struct blk_hdr allocated_blk_hdr;
	struct bmp_data_mgr allocated_bmp_data;
	struct mem_offt_mgr mem_offt_data;
	bool found;
	shm_offt allocated_offset;

	/* evaluate reqd mem at least equal to MIN_ALLOCATABLE_SIZE */
	reqd_size = get_next_power_of_two(size + sizeof(allocated_blk_hdr));

	if (reqd_size < MIN_ALLOCATABLE_SIZE)
		reqd_size = MIN_ALLOCATABLE_SIZE;

	if (reqd_size > MAX_ALLOCATABLE_SIZE) {
		P_ERR("Can't allocate %zu bytes, MAX_ALLOCATABLE_SIZE = %zu", reqd_size, MAX_ALLOCATABLE_SIZE);
		return (SHM_NULL);
	}

	/*
	 * if memory is available, `allocated_bitmap`
	 * gets filled with the bitmap pos and bit pos
	 */
	found = search_all_bitmaps_for_mem(reqd_size, &allocated_bmp_data);

	if (found) {

		/* get offset to allocated memory */
		mem_offt_data = get_offset_for_user_by_bmp_data(allocated_bmp_data);

		allocated_offset = mem_offt_data.offt_to_allocated_mem;

		/* user's offset is memory after the header */
		allocated_offset += sizeof(allocated_blk_hdr);

		allocated_blk_hdr.mem = reqd_size;

		set_blk_hdr(allocated_offset, allocated_blk_hdr);

	} else {
		P_ERR("Out of memory");
		allocated_offset = SHM_NULL;
	}

	return (allocated_offset);
}

void *ptr_malloc(size_t size)
{
	shm_offt offt_in_shm;

	offt_in_shm = shm_malloc(size);

	if (offt_in_shm == SHM_NULL) {
		return (NULL);
	}

	return (SHM_OFFT_TO_ADDR(offt_in_shm));
}


void *ptr_calloc(size_t count, size_t size)
{
	shm_offt offt_in_shm;

	offt_in_shm = shm_calloc(count, size);

	if (offt_in_shm == SHM_NULL) {
		return (NULL);
	}

	return (SHM_OFFT_TO_ADDR(offt_in_shm));
}

void ptr_free(void *ptr)
{
	shm_offt offt_in_shm;

	if (ptr == NULL) {
		offt_in_shm = SHM_NULL;
	} else {
		offt_in_shm = SHM_ADDR_TO_OFFT(ptr);
	}

	shm_free(offt_in_shm);
}

shm_offt shm_calloc(size_t cnt, size_t size)
{
	if (manager == NULL) {
		P_ERR("manager == NULL");
		return (SHM_NULL);
	}

	shm_offt allocated_offt;
	struct blk_hdr allocated_blk_hdr;

	allocated_offt = shm_malloc(cnt * size);

	if (allocated_offt == SHM_NULL)
		return (SHM_NULL);

	allocated_blk_hdr = get_blk_hdr(allocated_offt);

	memset((void *)ACCESS_SHM_FOR_USER(allocated_offt), 0, (allocated_blk_hdr.mem - sizeof(allocated_blk_hdr)));

	return (allocated_offt);
}

void shm_free(shm_offt shm_ptr)
{
	struct bmp_data_mgr bmp_data;
	struct shm_block_mgmt *blk_mgr;
	struct mem_offt_mgr mem_offt_data;
	shm_bitmap set_mask, old_bmp, new_bmp;

	mem_offt_data = convert_offset_to_mem_offt_mgr(shm_ptr);

	bmp_data = get_bmp_data_by_mem_offt_data(mem_offt_data);

	blk_mgr = ACCESS_SHM_MGMT_BY_MGMT_BLK_NO(bmp_data.bitmap_no);

	set_mask = get_set_bitmap_for_bit(bmp_data.abs_bit_pos);

	do {
		old_bmp = blk_mgr->mgmt_bmp;

		/* did you know == has higher precedence than &, well I didn't */
		assert((~old_bmp & set_mask) == 0);

		new_bmp = old_bmp & ~set_mask;
	}while (!atomic_compare_exchange_weak_explicit(&blk_mgr->mgmt_bmp, &old_bmp, new_bmp,
	    memory_order_relaxed, memory_order_relaxed));

	atomic_fetch_sub(&blk_mgr->mem_used, bmp_data.mem_level);
}

static struct blk_hdr get_blk_hdr(shm_offt offset)
{
	return *((struct blk_hdr *)ACCESS_SHM_FOR_USER(offset) - 1);
}

static void set_blk_hdr(shm_offt offset, struct blk_hdr hdr)
{
	struct blk_hdr *temp_hdr;
	temp_hdr = ((struct blk_hdr *)ACCESS_SHM_FOR_USER(offset) - 1);
	*temp_hdr = hdr;
}

static struct mem_offt_mgr convert_offset_to_mem_offt_mgr(shm_offt offset)
{
	struct mem_offt_mgr mem_offt_data;
	struct blk_hdr hdr;

	hdr = get_blk_hdr(offset);
	mem_offt_data.mem = hdr.mem;

	/* subtract size of header*/
	offset -= sizeof(hdr);

	mem_offt_data.offt_to_allocated_mem = offset;

	mem_offt_data.internal_offt = offset % MAX_ALLOCATABLE_SIZE;
	mem_offt_data.offt_to_blk   = offset - mem_offt_data.internal_offt;

	return (mem_offt_data);
}

static struct bmp_data_mgr get_bmp_data_by_mem_offt_data(struct mem_offt_mgr mem_offt_data)
{
	struct bmp_data_mgr bmp_data;

	bmp_data.mem_level = mem_offt_data.mem;

	bmp_data.bitmap_no = mem_offt_data.offt_to_blk/MAX_ALLOCATABLE_SIZE;
	bmp_data.relative_bit_pos = mem_offt_data.internal_offt/mem_offt_data.mem;
	bmp_data.abs_bit_pos = get_abs_bit_pos(bmp_data.relative_bit_pos, mem_offt_data.mem);

	return (bmp_data);
}

static struct mem_offt_mgr get_offset_for_user_by_bmp_data(struct bmp_data_mgr bmp_data)
{
	struct mem_offt_mgr mem_offt_data;

	mem_offt_data.mem = bmp_data.mem_level;

	assert(bmp_data.relative_bit_pos >= 0);

	/* shm base for user starts from shm null followed by allocatable shm region */
	mem_offt_data.offt_to_blk   = MAX_ALLOCATABLE_SIZE * bmp_data.bitmap_no;
	mem_offt_data.internal_offt = bmp_data.relative_bit_pos * bmp_data.mem_level;

	mem_offt_data.offt_to_allocated_mem = mem_offt_data.offt_to_blk + mem_offt_data.internal_offt;

	return (mem_offt_data);
}

static bool search_all_bitmaps_for_mem(size_t mem, struct bmp_data_mgr *bmp_data)
{
	struct shm_block_mgmt *cur_blk_mgr, *first_blk_mgr, *last_blk_mgr, *start_blk_mgr, *end_blk_mgr;
	int relative_bit_pos;
	bool did_find;

	first_blk_mgr  = ACCESS_SHM_MGMT(0);
	last_blk_mgr   = ACCESS_SHM_MGMT(SHM_MGMT_SIZE) - 1;

	bmp_data->bitmap_no        = -1;
	bmp_data->relative_bit_pos = -1;
	bmp_data->abs_bit_pos      = -1;
	bmp_data->mem_level        = mem;

	did_find = false;

	/*
	 * This func searches all bitmaps.
	 *
	 * When a bitmap gets full the start is moved to the next bitmap and goes
	 * way upto the last bitmap.
	 *
	 * Scan1 : Starting from the first non-full bitmap upto end.
	 * Scan2 : Starting from the very first bitmap upto the start
	 *         bitmap of scan1(for memory that may have got freed by shm_free())
	 *
	 * This is not a very neat way but saves many iterations.
	 */
	for (int scans = 0 ; scans < 2 ; ++scans) {

		if (scans == 0) {
			start_blk_mgr  = get_start_blk_mgr();
			end_blk_mgr    = last_blk_mgr;
		} else if (scans == 1) {
			end_blk_mgr    = start_blk_mgr - 1;
			start_blk_mgr  = first_blk_mgr;
		}

		for (cur_blk_mgr = start_blk_mgr ; cur_blk_mgr <= end_blk_mgr ; ++cur_blk_mgr) {

			if (atomic_load(&cur_blk_mgr->mem_used) + mem > MAX_ALLOCATABLE_SIZE) {
				continue;
			}

			relative_bit_pos = occupy_mem_in_bitmap(cur_blk_mgr, mem);

			if (relative_bit_pos != -1) {

				size_t mem_used;

				bmp_data->bitmap_no = (cur_blk_mgr - first_blk_mgr);
				bmp_data->relative_bit_pos = relative_bit_pos;
				bmp_data->abs_bit_pos = get_abs_bit_pos(relative_bit_pos, mem);

				mem_used = atomic_fetch_add(&cur_blk_mgr->mem_used, mem);

				if (mem_used + mem == MAX_ALLOCATABLE_SIZE && scans == 0) {
					/* Because this blk mgr is full, set start to next one */
					(void)update_start_blk_mgr(cur_blk_mgr + 1);
				}
				did_find = true;
				break;
			}
		}

		if (did_find) {
			break;
		}
	}

	return (did_find);
}

static struct shm_block_mgmt * get_start_blk_mgr()
{
	struct shm_data_table * data_table;
	shm_offt start_blk_mgr_offt;

	data_table = ACCESS_SHM_DATA_TABLE(0);
	start_blk_mgr_offt = atomic_load(&data_table->start_blk_mgr_offt);

	return (ACCESS_SHM_MGMT(start_blk_mgr_offt));
}

static bool update_start_blk_mgr(struct shm_block_mgmt * new_blk_mgr)
{
	shm_offt old, new;

	struct shm_data_table * data_table;
	data_table = ACCESS_SHM_DATA_TABLE(0);

	do {
		old = atomic_load(&data_table->start_blk_mgr_offt);
		new = (new_blk_mgr - ACCESS_SHM_MGMT(0)) * sizeof(struct shm_block_mgmt);

		if (new < old) {
			return (false);
		}

	}while(!atomic_compare_exchange_weak_explicit(&data_table->start_blk_mgr_offt, &old, new,
	    memory_order_relaxed, memory_order_relaxed));

	return (true);
}


static int occupy_mem_in_bitmap(struct shm_block_mgmt *blk_mgr, size_t mem)
{
	shm_bitmap mask, set_mask, old_bmp, new_bmp;
	int start_pos, cnt;
	int first_set_bit, rel_first_set_bit, ffs_res;
	bool cas_res;

	start_pos = cnt = MAX_ALLOCATABLE_SIZE/mem;

	/* mask contains the free bits at memory level mem */
	mask = set_bit_range(0, start_pos, cnt) & ~(blk_mgr->mgmt_bmp);

	do {

		ffs_res = __BUILTIN_FFS(mask);
		first_set_bit = BITS - (ffs_res != 0 ? ffs_res : BITS + 1);

		if (first_set_bit == -1) {
			return (first_set_bit);
		}

		set_mask = get_set_bitmap_for_bit(first_set_bit);

		cas_res = true;

		do {
			old_bmp = blk_mgr->mgmt_bmp;

			if (old_bmp & set_mask){
				cas_res = false;
				mask = unset_bit(mask, first_set_bit);
				mask &= ~(blk_mgr->mgmt_bmp);
				break;
			}

			new_bmp = old_bmp | set_mask;

		}while (!atomic_compare_exchange_weak_explicit(&blk_mgr->mgmt_bmp, &old_bmp, new_bmp,
		    memory_order_relaxed, memory_order_relaxed));

	}while (!cas_res);

	rel_first_set_bit = get_rel_bit_pos(first_set_bit);

	return (rel_first_set_bit);
}

static shm_bitmap get_set_bitmap_for_bit(int pos)
{
	shm_bitmap bmp = 0;
	size_t mem;

	/* current memory level of the bit */
	mem = MAX_ALLOCATABLE_SIZE/get_prev_power_of_two(pos);

	bmp = set_bit(bmp, pos);

	for (int num_children = 2 ; mem > MIN_ALLOCATABLE_SIZE ; num_children <<= 1, mem >>= 1) {
		bmp = set_children_bits(bmp, pos, num_children);
	}
	return (bmp);
}
