#ifndef __TRIE_H__
#define __TRIE_H__

/*
 * This trie operates on shared memory
 * and is _not_ thread safe.
 */

#include "darwintrace_share/shm_alloc/shm_alloc.h"
#include <stdbool.h>

#define ASCII_LEN (256)

typedef unsigned long triebmp;
#define PRIu_triebmp "lu"
#define __BUILTIN_FFS(x)      __builtin_ffsl(x)
#define __BUILTIN_POPCOUNT(x) __builtin_popcountl(x)

#define BITS         ((int)(sizeof(triebmp)*8))
#define BITMAP_SIZE  ((int)(ASCII_LEN))
#define BMP_ARR_SIZE ((int)((BITMAP_SIZE/BITS) + (BITMAP_SIZE % BITS > 0 ? 1 : 0)))


/*
 * bmp:
 *  256 bits bitmap to represent 256 ascii chars
 *
 * array_of_children:
 *  allocated in shared memory; it contains reference
 *  to only those children who are set in bmp.
 *  Array index correponding to bmp is obtained by
 *  get_index() defined in trie.c
 */
struct trie_node
{
	triebmp bmp[BMP_ARR_SIZE];
	PTR(PTR(struct trie_node)) array_of_children;
	uint8_t permission; 
	bool is_end;
};

struct prefix_trie {
	PTR(struct trie_node) root;
	bool is_fence_set;
};

void trie_set_fence(PTR(struct prefix_trie) pt);
bool trie_is_fence_set(PTR(struct prefix_trie) pt);
void trie_unset_fence(PTR(struct prefix_trie) pt);

PTR(struct prefix_trie) trie_init(void);
bool trie_insert(PTR(struct prefix_trie), const char *, uint8_t);
bool trie_search(PTR(struct prefix_trie), const char *, uint8_t *);
bool trie_prefix_search(PTR(struct prefix_trie), const char *, uint8_t *);

char * trie_prefix_search_get_prefix(PTR(struct prefix_trie) pt, const char *key, uint8_t *permission);

#endif /* __TRIE_H__ */
