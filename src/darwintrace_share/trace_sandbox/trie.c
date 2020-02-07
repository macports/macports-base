#include <assert.h>

#include "darwintrace_share/shm_alloc/shm_alloc.h"

#include <errno.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "trie.h"

#define P_ERR(format, ...) \
	do {\
		fprintf(stderr, "%s:%d:%s:" format "\n", __FILE__, __LINE__, strerror(errno), ##__VA_ARGS__);\
		fflush(stderr);\
	}while(0)


static void triebmp_print_all_bits(triebmp bmp[BMP_ARR_SIZE], FILE *outfile)
{
	for (int j = 0 ; j < BMP_ARR_SIZE ; ++j) {
		for(int i = BITS - 1 ; i >= 0 ; --i) {
			fprintf(outfile, "%" PRIu_triebmp, ((triebmp)bmp[j] >> i) & (triebmp)1);
		}
	}

	fprintf(outfile, "\n");
}

static inline void triebmp_set_bit(triebmp bmp[BMP_ARR_SIZE], int pos)
{
	assert(pos >= 0 && pos < BITMAP_SIZE);
	int idx = pos/BITS;
	bmp[idx] |= (triebmp)1 << (BITS - (pos % BITS) - 1);

}

static inline bool triebmp_is_bit_set(triebmp bmp[BMP_ARR_SIZE], int pos)
{
	assert(pos >= 0 && pos < BITMAP_SIZE);
	int idx = pos/BITS;
	return (bmp[idx] & ((triebmp)1 << (BITS - (pos % BITS) - 1)));
}

/*
 * param `mask` is first set to all 0 and then from - to bits are set
 */
static void triebmp_set_mask_for_range(triebmp mask[BMP_ARR_SIZE], int from, int to)
{
	int start_idx, end_idx, idx;

	assert(from >= 0 && from <= BITMAP_SIZE \
	    && to >= 0 && to <= BITMAP_SIZE);

	memset(mask, 0, sizeof(triebmp) * BMP_ARR_SIZE);

	start_idx = from/BITS;
	end_idx   = (to-1)/BITS;

	for (idx = start_idx ; idx <= end_idx ; ++idx) {
		mask[idx] = (triebmp)-1;
	}

	mask[end_idx]   = mask[end_idx] << ( BITS - ((to-1) % BITS) - 1);
	mask[start_idx] &= (triebmp)-1 >> (from % BITS);
}


static int inline triebmp_masked_popcount(triebmp bmp[BMP_ARR_SIZE], triebmp mask[BMP_ARR_SIZE])
{
	int sum = 0;
	for (int i = 0 ; i < BMP_ARR_SIZE ; ++i) {
		sum += __BUILTIN_POPCOUNT(mask[i] & bmp[i]);
	}
	return (sum);
}

static int inline triebmp_popcount(triebmp bmp[BMP_ARR_SIZE])
{
	int sum = 0;
	for (int i = 0 ; i < BMP_ARR_SIZE ; ++i) {
		sum += __BUILTIN_POPCOUNT(bmp[i]);
	}
	return (sum);
}

/*
 * index = bitcount(bits right to bit_pos)
 *
 * a lame example :
 *  for 8 bit bitmap 10110000
 *  For the 3 set bits:
 *  For rightmost, idx = 0
 *  Left to it has idx = 1
 *  then idx = 2
 */
static inline int get_index(triebmp bmp[BMP_ARR_SIZE], int bit_pos)
{
	triebmp mask[BMP_ARR_SIZE];
	triebmp_set_mask_for_range(mask, bit_pos + 1, BITMAP_SIZE);
	return (triebmp_masked_popcount(bmp, mask));
}

/*
 * Adds new entry to the bitmap.
 *
 * Creates a new copy of array and adds itself to it.
 * If index for this new entry is somewhere in between
 * the array, space is made for it and other indices are
 * shifted.
 *
 * Try it yourself how value of get_index() changes for
 * a bit on addition of other bits
 *
 * Another 8 bit lame example:
 *  0001 0000
 * Till now 4th bit was enjoying index = 0.
 * When a new bit is added:
 *  0001 0100
 * index of 4th bit becomes 1.
 */
bool trie_add_new_child(struct trie_node *crawler_ptr, int new_bit, int idx)
{
	int old_arrsize;
	PTR(PTR(struct trie_node)) new_arr, old_arr;
	
	old_arr = crawler_ptr->array_of_children;

	PTR(struct trie_node) *old_arr_ptr, *new_arr_ptr;

	old_arr_ptr = SHM_OFFT_TO_ADDR(old_arr);
	old_arrsize = triebmp_popcount(crawler_ptr->bmp);
	new_arr = shm_calloc(old_arrsize + 1, sizeof(PTR(struct trie_node)));

	if (new_arr == SHM_NULL) {
		P_ERR("shm_calloc(): out of memory");
		return (false);
	}

	new_arr_ptr  = SHM_OFFT_TO_ADDR(new_arr);
	new_arr_ptr[idx] = shm_calloc(1, sizeof(struct trie_node));

	if (new_arr_ptr == SHM_NULL) {
		P_ERR("shm_calloc(): out of memory");
		shm_free(new_arr);
		return (false);
	}

	triebmp_set_bit(crawler_ptr->bmp, new_bit);

	if (old_arrsize > 0) {
		memcpy(new_arr_ptr, old_arr_ptr, idx * sizeof(PTR(struct trie_node)));
		if (old_arrsize != idx) {
			memcpy(new_arr_ptr + idx + 1, old_arr_ptr + idx,
			    (old_arrsize - idx) * sizeof(PTR(struct trie_node)));
		}
		shm_free(old_arr);
	}
	
	crawler_ptr->array_of_children = new_arr;

	return (true);
}

PTR(struct prefix_trie) trie_init()
{
	PTR(struct prefix_trie) pt = shm_calloc(1, sizeof(struct prefix_trie));

	if (pt == SHM_NULL) {
		P_ERR("shm_calloc() failed");
		return (SHM_NULL);
	}
	DEREF(pt, struct prefix_trie).root = shm_calloc(1, sizeof(struct trie_node));

	if (DEREF(pt, struct prefix_trie).root == SHM_NULL) {
		P_ERR("shm_calloc() failed");
		shm_free(pt);
		return (SHM_NULL);
	}

	DEREF(pt, struct prefix_trie).is_fence_set = false;

	return (pt);
}

void trie_set_fence(PTR(struct prefix_trie) pt)
{
	assert(pt != SHM_NULL);
	DEREF(pt, struct prefix_trie).is_fence_set = true;
}

bool trie_is_fence_set(PTR(struct prefix_trie) pt)
{
	assert(pt != SHM_NULL);
	return (DEREF(pt, struct prefix_trie).is_fence_set);
}

void trie_unset_fence(PTR(struct prefix_trie) pt)
{
	assert(pt != SHM_NULL);
	DEREF(pt, struct prefix_trie).is_fence_set = false;
}

bool trie_insert(PTR(struct prefix_trie) pt, const char *key, uint8_t permission)
{
	int index, bit_pos;
	PTR(struct trie_node) *children_array_ptr;
	struct trie_node *crawler_ptr;
	bool res;

	if (ACCESS(pt, struct prefix_trie) == SHM_NULL || DEREF(pt, struct prefix_trie).root == SHM_NULL) {
		P_ERR("root is NULL");
		return (false);
	}

	if (key == NULL || key[0] == '\0') {
		P_ERR("key is NULL");
		return (false);
	}

	crawler_ptr = SHM_OFFT_TO_ADDR(DEREF(pt, struct prefix_trie).root);

	for (int level = 0; key[level] != '\0' ; ++level) {

		bit_pos = key[level];
		index = get_index(crawler_ptr->bmp, bit_pos);

		if (triebmp_is_bit_set(crawler_ptr->bmp, bit_pos) == false) {
			res = trie_add_new_child(crawler_ptr, bit_pos, index);
			if (res == false) {
				/*
				 * TODO: In case of failures, free the nodes
				 * allocated uptil now.
				 * Set current node's is_end to true,
				 * implement trie_delete() and call it with a copy of
				 * key such that key_copy[level] = '\0'
				 */
				return (false);
			}
		}

		children_array_ptr = SHM_OFFT_TO_ADDR(crawler_ptr->array_of_children);
		crawler_ptr = SHM_OFFT_TO_ADDR(children_array_ptr[index]);
	}

	crawler_ptr->permission = permission;
	crawler_ptr->is_end = true;

	return (true);
}

bool trie_search(PTR(struct prefix_trie) pt, const char *key, uint8_t *permission)
{
	int index, bit_pos;
	PTR(struct trie_node) crawler, *children_array_ptr;
	struct trie_node *crawler_ptr;

	if (ACCESS(pt, struct prefix_trie) == SHM_NULL || DEREF(pt, struct prefix_trie).root == SHM_NULL) {
		P_ERR("root is NULL");
		return (false);
	}

	if (key == NULL) {
		P_ERR("key is NULL");
		return (false);
	}

	crawler = DEREF(pt, struct prefix_trie).root;
	crawler_ptr = SHM_OFFT_TO_ADDR(crawler);

	for (int level = 0; key[level] != '\0' ; ++level) {

		bit_pos = key[level];
		index = get_index(crawler_ptr->bmp, bit_pos);

		if (triebmp_is_bit_set(crawler_ptr->bmp, bit_pos) == false) {
			return (false);
		}

		children_array_ptr = SHM_OFFT_TO_ADDR(crawler_ptr->array_of_children);
		crawler_ptr = SHM_OFFT_TO_ADDR(children_array_ptr[index]);
	}

	*permission = crawler_ptr->permission;

	return (crawler_ptr->is_end);
}

/*
 * param1: root of trie
 * param2: key to check
 * param3: permission is stored in it
 *
 * retval : true if prefix of param2 exists else false
 *          on true stores the permission for prefix in param3
 */
bool trie_prefix_search(PTR(struct prefix_trie) pt, const char *key, uint8_t *permission)
{
	int index, bit_pos, level;
	PTR(struct trie_node) crawler, *children_array_ptr;
	struct trie_node *crawler_ptr;
	bool has_prefix;
	uint8_t stored_permission;

	if (ACCESS(pt, struct prefix_trie) == SHM_NULL || DEREF(pt, struct prefix_trie).root == SHM_NULL) {
		P_ERR("root is NULL");
		return (false);
	}

	if (key == NULL) {
		P_ERR("key is NULL");
		return (false);
	}

	has_prefix = false;
	crawler = DEREF(pt, struct prefix_trie).root;
	crawler_ptr = SHM_OFFT_TO_ADDR(crawler);

	for (level = 0; key[level] != '\0' ; ++level) {

		if (crawler_ptr->is_end == true && key[level] == '/') {
			has_prefix = true;
			stored_permission = crawler_ptr->permission;
		}

		bit_pos = key[level];
		index = get_index(crawler_ptr->bmp, bit_pos);

		if (triebmp_is_bit_set(crawler_ptr->bmp, bit_pos) == false) {

			if (has_prefix) {
				*permission = stored_permission;
				return (true);
			}

			return (false);
		}

		children_array_ptr = SHM_OFFT_TO_ADDR(crawler_ptr->array_of_children);
		crawler_ptr = SHM_OFFT_TO_ADDR(children_array_ptr[index]);
	}

	*permission = crawler_ptr->permission;

	return (crawler_ptr->is_end);
}

/*
 * Same as above function but returns the prefix that was used
 * to decide the permission. The buffer for prefix is allocated in function itself.
 * If prefix not found, returns NULL.
 *
 * Maybe helpful for debugging.
 */
char * trie_prefix_search_get_prefix(PTR(struct prefix_trie) pt, const char *key, uint8_t *permission)
{
#define SET_PREFIX(prefix, key, prefix_level) \
	do {\
		prefix = malloc(sizeof(char) * (prefix_level+1));\
		if (prefix == NULL) {\
			P_ERR("malloc(2) failed");\
			abort();\
		}\
		strncpy(prefix, key, prefix_level);\
		prefix[prefix_level] = '\0';\
	}while (0)
	

	int index, bit_pos, level, prefix_level;
	PTR(struct trie_node) crawler, *children_array_ptr;
	struct trie_node *crawler_ptr;
	uint8_t stored_permission;
	char *prefix;

	if (ACCESS(pt, struct prefix_trie) == SHM_NULL || DEREF(pt, struct prefix_trie).root == SHM_NULL) {
		P_ERR("root is NULL");
		return (NULL);
	}

	if (key == NULL) {
		P_ERR("key is NULL");
		return (NULL);
	}

	prefix_level = -1;
	crawler = DEREF(pt, struct prefix_trie).root;
	crawler_ptr = SHM_OFFT_TO_ADDR(crawler);

	for (level = 0; key[level] != '\0' ; ++level) {

		if (crawler_ptr->is_end == true && key[level] == '/') {
			prefix_level = level;
			stored_permission = crawler_ptr->permission;
		}

		bit_pos = key[level];
		index = get_index(crawler_ptr->bmp, bit_pos);

		if (triebmp_is_bit_set(crawler_ptr->bmp, bit_pos) == false) {

			if (prefix_level != -1) {
				SET_PREFIX(prefix, key, prefix_level);
				*permission = stored_permission;
				return (prefix);
			}

			return (NULL);
		}

		children_array_ptr = SHM_OFFT_TO_ADDR(crawler_ptr->array_of_children);
		crawler_ptr = SHM_OFFT_TO_ADDR(children_array_ptr[index]);
	}

	if (crawler_ptr->is_end) {
		prefix_level = level;
		SET_PREFIX(prefix, key, prefix_level);
		*permission = crawler_ptr->permission;
		return prefix;
	}

	return (NULL);
}
