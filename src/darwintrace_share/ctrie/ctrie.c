/**
 * Copyright (c) 2019, Clemens Lang <cal@macports.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "ctrie.h"

#define malloc shm_malloc
#define calloc shm_calloc
#define free   shm_free

#define W (5)
#define _W (32)

typedef enum {
	TYPE_CNODE = 0,
	TYPE_SNODE = 1,
	TYPE_INODE = 2,
	TYPE_LNODE = 3
} node_type_t;

typedef struct {
	node_type_t type;
} any_node_t;

typedef struct {
	uint8_t type;
	PTR(any_node_t) main;
} inode_t;

typedef struct {
	node_type_t type;
	uint32_t bmp;
	size_t len;
	PTR(any_node_t) arr[];
} cnode_t;

typedef struct {
	node_type_t type;
	value_t value;
	size_t keylen;
	char key[];
} snode_t;

typedef struct {
	node_type_t type;
	size_t len;
	PTR(snode_t) arr[];
} lnode_t;

struct ctrie {
	PTR(inode_t) root;
};

typedef struct {
	uint32_t flag;
	uint32_t pos;
} idx_t;

typedef uint32_t hash_t;

static hash_t hash(const char key[]) {
	size_t length;
	size_t i;
	uint32_t h = 0;
	if (!key) {
		return 0;
	}
	length = strlen(key);
	for (i = 0; i < length; ++i) {
		h = (31 * h) + key[i];
	}
	h ^= (h >> 20) ^ (h >> 12);
	return h ^ (h >> 7) ^ (h >> 4);
}

static void flagpos(hash_t hc, uint8_t level, uint32_t bmp, idx_t* output) {
	uint32_t idx = (hc >> level) & ((1 << W) - 1);
	uint32_t flag = 1 << idx;
	uint32_t mask = flag - 1;
	uint32_t pos = __builtin_popcount(bmp & mask);
	output->flag = flag;
	output->pos = pos;
}

static void ctrie_print_node(PTR(any_node_t) node, uint8_t indent, const char* arridx) {
	if (!node) {
		fprintf(stderr, "%*s%sNULL\n", indent, "", arridx);
		return;
	}
	switch (DEREF(node, any_node_t).type) {
		case TYPE_INODE:
			fprintf(stderr, "%*s%sINode (.main = %p):\n", indent, "", arridx, (void*) DEREF(node, inode_t).main);
			ctrie_print_node((PTR(any_node_t)) (void*) DEREF(node, inode_t).main, indent + 2, "");
			break;
		case TYPE_CNODE:
			fprintf(stderr, "%*s%sCNode{", indent, "", arridx);
			fprintf(stderr, " .bmp = %x", DEREF(node, cnode_t).bmp);
			fprintf(stderr, " .len = %zd\n", DEREF(node, cnode_t).len);
			for (int i = 0; i < DEREF(node, cnode_t).len; ++i) {
				if (DEREF(node, cnode_t).arr[i]) {
					char arridxstr[5];
					snprintf(arridxstr, sizeof(arridxstr), "%d: ", i);
					ctrie_print_node(DEREF(node, cnode_t).arr[i], indent + 2, arridxstr);
				}
			}
			fprintf(stderr, "%*s}\n", indent, "");
			break;
		case TYPE_SNODE:
			fprintf(stderr, "%*s%sSNode{", indent, "", arridx);
			fprintf(stderr, " .value.counter = %d", DEREF(node, snode_t).value.counter);
			fprintf(stderr, " .value.flags = %x", DEREF(node, snode_t).value.flags);
			fprintf(stderr, " .keylen = %zd", DEREF(node, snode_t).keylen);
			fprintf(stderr, " .key = '%s'", DEREF(node, snode_t).key);
			fprintf(stderr, "}\n");
			break;
		case TYPE_LNODE:
			fprintf(stderr, "%*s%sLNode{", indent, "", arridx);
			fprintf(stderr, " .len = %zd\n", DEREF(node, lnode_t).len);
			for (int i = 0; i < DEREF(node, lnode_t).len; ++i) {
				if (DEREF(node, lnode_t).arr[i]) {
					char arridxstr[5];
					snprintf(arridxstr, sizeof(arridxstr), "%d: ", i);
					ctrie_print_node((PTR(any_node_t)) DEREF(node, lnode_t).arr[i], indent + 2, arridxstr);
				}
			}
			fprintf(stderr, "%*s}\n", indent, "");
			break;
	}
}

void ctrie_print(PTR(ctrie_t) ctrie) {
	PTR(inode_t) ctrie_root = DEREF(ctrie, ctrie_t).root;
	fprintf(stderr, "ctrie.root: %p\n", (void*) ctrie_root);
	if (ctrie_root) {
		ctrie_print_node((PTR(any_node_t)) ctrie_root, 0, "");
	}
}

PTR(ctrie_t) ctrie_new() {
	return calloc(1, sizeof(ctrie_t));
}

static lookup_result_t ilookup(
		PTR(inode_t) inode,
		hash_t hc,
		const char* key,
		value_t* value,
		uint8_t level);

lookup_result_t ctrie_lookup(PTR(ctrie_t) ctrie, const char* key, value_t* value) {
	if (!ctrie) {
		return LOOKUP_NOTFOUND;
	}

	PTR(inode_t) root = DEREF(ctrie, ctrie_t).root;
	if (!root) {
		return LOOKUP_NOTFOUND;
	}
	if (!DEREF(root, inode_t).main) {
		return LOOKUP_NOTFOUND;
	}

	hash_t hc = hash(key);
	return ilookup(root, hc, key, value, 0);
}

static lookup_result_t ilookup(
		PTR(inode_t) inode,
		hash_t hc,
		const char* key,
		value_t* value,
		uint8_t level) {
	PTR(any_node_t) node = DEREF(inode, inode_t).main;
	switch (DEREF(node, any_node_t).type) {
		case TYPE_CNODE: {
			PTR(cnode_t) cnode = (PTR(cnode_t)) node;
			uint32_t bmp = DEREF(cnode, cnode_t).bmp;
			idx_t idx;
			flagpos(hc, level, bmp, &idx);

			if ((bmp & idx.flag) <= 0) {
				return LOOKUP_NOTFOUND;
			}
			PTR(any_node_t) subnode = DEREF(cnode, cnode_t).arr[idx.pos];
			switch (DEREF(subnode, any_node_t).type) {
				case TYPE_INODE: {
					PTR(inode_t) subinode = (PTR(inode_t)) subnode;
					return ilookup(subinode, hc, key, value, level + W);
				}
				case TYPE_SNODE: {
					PTR(snode_t) subsnode = (PTR(snode_t)) subnode;
					if (strcmp(key, DEREF(subsnode, snode_t).key) != 0) {
						return LOOKUP_NOTFOUND;
					}
					memcpy(value, &DEREF(subsnode, snode_t).value, sizeof(value_t));
					return LOOKUP_FOUND;
				}
				default:
					// This is a bug!
					return LOOKUP_BUG;
			}
		}
		case TYPE_SNODE: {
			PTR(snode_t) snode = (PTR(snode_t)) node;
			if (strcmp(key, DEREF(snode, snode_t).key) != 0) {
				return LOOKUP_NOTFOUND;
			}
			memcpy(value, &DEREF(snode, snode_t).value, sizeof(value_t));
			return LOOKUP_FOUND;
		}
		case TYPE_LNODE: {
			PTR(lnode_t) lnode = (PTR(lnode_t)) node;
			for (size_t idx = 0; idx < DEREF(lnode, lnode_t).len; ++idx) {
				PTR(snode_t) snode = DEREF(lnode, lnode_t).arr[idx];
				if (strcmp(key, DEREF(snode, snode_t).key) == 0) {
					memcpy(value, &DEREF(snode, snode_t).value, sizeof(value_t));
					return LOOKUP_FOUND;
				}
			}
			return LOOKUP_NOTFOUND;
		}
		default:
			// This is a bug!
			return LOOKUP_BUG;
	}
}

static insert_result_t iinsert(
		PTR(inode_t) inode,
		hash_t hc,
		const char* key,
		const value_t* value,
		uint8_t level);

insert_result_t ctrie_insert(PTR(ctrie_t) ctrie, const char* key, const value_t* value) {
	insert_result_t retval = INSERT_CAS_FAILED;
	hash_t hc = hash(key);

	if (!ctrie) {
		return INSERT_BUG;
	}

	while (retval == INSERT_CAS_FAILED) {
		PTR(inode_t) root = DEREF(ctrie, ctrie_t).root;
		if (!root || !DEREF(root, inode_t).main) {
			size_t keylen = strlen(key) + 1;
			PTR(snode_t) snode = calloc(1, sizeof(snode_t) + keylen);
			if (!snode) {
				return INSERT_OUT_OF_MEMORY;
			}
			DEREF(snode, snode_t).type = TYPE_SNODE;
			DEREF(snode, snode_t).value = *value;
			DEREF(snode, snode_t).keylen = keylen;
			memcpy(DEREF(snode, snode_t).key, key, keylen);

			PTR(cnode_t) cnode = calloc(1, sizeof(cnode_t) + sizeof(PTR(any_node_t)) * 1);
			if (!cnode) {
				free(snode);
				return INSERT_OUT_OF_MEMORY;
			}
			idx_t idx;
			flagpos(hc, 0, 0, &idx);

			DEREF(cnode, cnode_t).type = TYPE_CNODE;
			DEREF(cnode, cnode_t).bmp = idx.flag;
			DEREF(cnode, cnode_t).len = 1;
			DEREF(cnode, cnode_t).arr[idx.pos] = (PTR(any_node_t)) snode;

			PTR(inode_t) inode = calloc(1, sizeof(inode_t));
			if (!inode) {
				free(cnode);
				free(snode);
				return INSERT_OUT_OF_MEMORY;
			}
			DEREF(inode, inode_t).type = TYPE_INODE;
			DEREF(inode, inode_t).main = (PTR(any_node_t)) cnode;

			if (__sync_bool_compare_and_swap(&DEREF(ctrie, ctrie_t).root, root, inode)) {
				retval = INSERT_SUCCESS;
			}
		} else {
			retval = iinsert(root, hc, key, value, 0);
		}
	}

	return retval;
}

static insert_result_t iinsert(
		PTR(inode_t) inode,
		hash_t hc,
		const char* key,
		const value_t* value,
		uint8_t level) {
	PTR(any_node_t) node = DEREF(inode, inode_t).main;
	switch (DEREF(node, any_node_t).type) {
		case TYPE_CNODE: {
			PTR(cnode_t) cnode = (PTR(cnode_t)) node;
			uint32_t bmp = DEREF(cnode, cnode_t).bmp;
			idx_t idx;
			flagpos(hc, level, bmp, &idx);

			if ((bmp & idx.flag) <= 0) {
				size_t keylen = strlen(key) + 1;
				PTR(snode_t) snode = calloc(1, sizeof(snode_t) + keylen);
				if (!snode) {
					return INSERT_OUT_OF_MEMORY;
				}
				DEREF(snode, snode_t).type = TYPE_SNODE;
				DEREF(snode, snode_t).value = *value;
				DEREF(snode, snode_t).keylen = keylen;
				memcpy(DEREF(snode, snode_t).key, key, keylen);

				PTR(cnode_t) newcnode = calloc(1, sizeof(cnode_t) + sizeof(PTR(any_node_t)) * (DEREF(cnode, cnode_t).len + 1));
				if (!newcnode) {
					free(snode);
					return INSERT_OUT_OF_MEMORY;
				}
				DEREF(newcnode, cnode_t).type = TYPE_CNODE;
				DEREF(newcnode, cnode_t).len = DEREF(cnode, cnode_t).len + 1;
				// while copying, make room at idx.pos
				memcpy(
					DEREF(newcnode, cnode_t).arr,
					DEREF(cnode, cnode_t).arr,
					sizeof(PTR(any_node_t)) * idx.pos);
				DEREF(newcnode, cnode_t).arr[idx.pos] = (PTR(any_node_t)) snode;
				memcpy(
					&DEREF(newcnode, cnode_t).arr[idx.pos+1],
					&DEREF(cnode, cnode_t).arr[idx.pos],
					sizeof(PTR(any_node_t)) * (DEREF(cnode, cnode_t).len - idx.pos));
				DEREF(newcnode, cnode_t).bmp = bmp | idx.flag;

				if (__sync_bool_compare_and_swap(
							&DEREF(inode, inode_t).main,
							(PTR(any_node_t)) cnode,
							(PTR(any_node_t)) newcnode)) {
					return INSERT_SUCCESS;
				}
				return INSERT_CAS_FAILED;
			}

			// An entry already exists at this position in the array
			PTR(any_node_t) subnode = DEREF(cnode, cnode_t).arr[idx.pos];
			switch (DEREF(subnode, any_node_t).type) {
				case TYPE_INODE: {
					PTR(inode_t) subinode = (PTR(inode_t)) subnode;
					return iinsert(subinode, hc, key, value, level + W);
				}
				case TYPE_SNODE: {
					PTR(snode_t) subsnode = (PTR(snode_t)) subnode;

					size_t keylen = strlen(key) + 1;
					PTR(snode_t) newsnode = calloc(1, sizeof(snode_t) + keylen);
					if (!newsnode) {
						return INSERT_OUT_OF_MEMORY;
					}
					DEREF(newsnode, snode_t).type = TYPE_SNODE;
					DEREF(newsnode, snode_t).value = *value;
					DEREF(newsnode, snode_t).keylen = keylen;
					memcpy(DEREF(newsnode, snode_t).key, key, keylen);

					PTR(cnode_t) newcnode = calloc(1, sizeof(cnode_t) + sizeof(PTR(any_node_t)) * (DEREF(cnode, cnode_t).len));
					if (!newcnode) {
						free(newsnode);
						return INSERT_OUT_OF_MEMORY;
					}
					DEREF(newcnode, cnode_t).type = TYPE_CNODE;
					DEREF(newcnode, cnode_t).len = DEREF(cnode, cnode_t).len;
					memcpy(
						DEREF(newcnode, cnode_t).arr,
						DEREF(cnode, cnode_t).arr,
						sizeof(PTR(any_node_t)) * DEREF(cnode, cnode_t).len);
					DEREF(newcnode, cnode_t).bmp = bmp | idx.flag;

					if (strcmp(key, DEREF(subsnode, snode_t).key) == 0) {
						DEREF(newcnode, cnode_t).arr[idx.pos] = (PTR(any_node_t)) newsnode;
					} else {
						if (level < sizeof(hash_t) * 8) {
							PTR(cnode_t) childcnode = calloc(1, sizeof(cnode_t) + sizeof(PTR(any_node_t)));
							if (!childcnode) {
								free(newsnode);
								free(newcnode);
								return INSERT_OUT_OF_MEMORY;
							}
							uint32_t bmp = 0;
							idx_t subsnode_idx;
							hash_t subsnode_hc = hash(DEREF(subsnode, snode_t).key);
							flagpos(subsnode_hc, level + W, bmp, &subsnode_idx);
							bmp |= subsnode_idx.flag;

							DEREF(childcnode, cnode_t).type = TYPE_CNODE;
							DEREF(childcnode, cnode_t).len = 1;
							DEREF(childcnode, cnode_t).bmp = bmp;
							DEREF(childcnode, cnode_t).arr[subsnode_idx.pos] = (PTR(any_node_t)) subsnode;

							PTR(inode_t) newinode = calloc(1, sizeof(inode_t));
							if (!newinode) {
								free(childcnode);
								free(newsnode);
								free(newcnode);
								return INSERT_OUT_OF_MEMORY;
							}
							DEREF(newinode, inode_t).type = TYPE_INODE;
							DEREF(newinode, inode_t).main = (PTR(any_node_t)) childcnode;

							// here be the magic of recursion!
							while (INSERT_CAS_FAILED == iinsert(newinode, hc, key, value, level + W));
							DEREF(newcnode, cnode_t).arr[idx.pos] = (PTR(any_node_t)) newinode;
						} else {
							PTR(lnode_t) childlnode = calloc(1, sizeof(lnode_t) + sizeof(PTR(any_node_t)) * 2);
							if (!childlnode) {
								free(newsnode);
								free(newcnode);
								return INSERT_OUT_OF_MEMORY;
							}
							DEREF(childlnode, lnode_t).type = TYPE_LNODE;
							DEREF(childlnode, lnode_t).len = 2;
							DEREF(childlnode, lnode_t).arr[0] = subsnode;
							DEREF(childlnode, lnode_t).arr[1] = newsnode;

							PTR(inode_t) newinode = calloc(1, sizeof(inode_t));
							if (!newinode) {
								free(childlnode);
								free(newsnode);
								free(newcnode);
								return INSERT_OUT_OF_MEMORY;
							}
							DEREF(newinode, inode_t).type = TYPE_INODE;
							DEREF(newinode, inode_t).main = (PTR(any_node_t)) childlnode;

							DEREF(newcnode, cnode_t).arr[idx.pos] = (PTR(any_node_t)) newinode;
						}
					}

					if (__sync_bool_compare_and_swap(
								&DEREF(inode, inode_t).main,
								(PTR(any_node_t)) cnode,
								(PTR(any_node_t)) newcnode)) {
						return INSERT_SUCCESS;
					}
					return INSERT_CAS_FAILED;
				}
				default:
					// This is a bug!
				return INSERT_BUG;
			}
		}
		case TYPE_LNODE: {
			PTR(lnode_t) lnode = (PTR(lnode_t)) node;

			size_t keylen = strlen(key) + 1;
			PTR(snode_t) newsnode = calloc(1, sizeof(snode_t) + keylen);
			if (!newsnode) {
				return INSERT_OUT_OF_MEMORY;
			}
			DEREF(newsnode, snode_t).type = TYPE_SNODE;
			DEREF(newsnode, snode_t).value = *value;
			DEREF(newsnode, snode_t).keylen = keylen;
			memcpy(DEREF(newsnode, snode_t).key, key, keylen);

			PTR(lnode_t) newlnode = calloc(1, sizeof(lnode_t) + sizeof(PTR(snode_t)) * (DEREF(lnode, lnode_t).len + 1));
			if (!newlnode) {
				free(newsnode);
				return INSERT_OUT_OF_MEMORY;
			}
			DEREF(newlnode, lnode_t).type = TYPE_LNODE;
			DEREF(newlnode, lnode_t).len = DEREF(lnode, lnode_t).len + 1;
			memcpy(
				DEREF(newlnode, lnode_t).arr,
				DEREF(lnode, lnode_t).arr,
				sizeof(PTR(snode_t)) * DEREF(lnode, lnode_t).len);
			DEREF(newlnode, lnode_t).arr[DEREF(lnode, lnode_t).len] = newsnode;

			if (__sync_bool_compare_and_swap(
						&DEREF(inode, inode_t).main,
						(PTR(any_node_t)) lnode,
						(PTR(any_node_t)) newlnode)) {
				return INSERT_SUCCESS;
			}
			return INSERT_CAS_FAILED;
		}
		default:
			return INSERT_BUG;
	}
}
