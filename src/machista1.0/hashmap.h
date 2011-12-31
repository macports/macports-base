/* vim:tw=80:expandtab
 */
/**
 * @file  hashmap.h
 * @brief A hash map implementation in C.
 * @author Christoph Erhardt <erhardt@cs.fau.de>
 */

/*-
 * Copyright (c) 2011 Christoph Erhardt. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY CHRISTOPH ERHARDT ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL CHRISTOPH ERHARDT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
/*-
 * Modified by Clemens Lang to accept values of arbitrary type.
 */


#ifndef HASHMAP_H
#define HASHMAP_H


#include <stdlib.h>


/** Hash map type. */
typedef struct HashMap HashMap;


/**
 * @brief Creates a hash map.
 *
 * The keys and values managed in the map can be arbitrary C strings.
 * @param freeFunc Function to call in order to free a stored value
 * @return Pointer to the newly created hash map, or @c NULL on error.
 */
HashMap *hashMapCreate(void (*freeFunc)(const void *));

/**
 * @brief Inserts a key-value pair into a hash map.
 *
 * Both key and value are copied internally, so the caller can reuse the
 * original variables.
 * If oldValPtr is @c NULL, the previously stored value corresponding to the key
 * is freed. Otherwise it is written into @c *valPtr and the caller is
 * responsible for freeing it.
 * @param map       Hash map.
 * @param key       Key.
 * @param value     Value.
 * @param oldValPtr Output parameter receiving the previously stored value
 *                  corresponding to the key (@c NULL if no mapping existed
 *                  before).
 * @return Nonzero on success, 0 on error.
 */
int hashMapPut(HashMap *map, const char key[], const void * const value,
               const void **oldValPtr);

/**
 * @brief Performs a hash map lookup.
 *
 * The returned value must not be freed or otherwise manipulated by the caller.
 * @param map Hash map.
 * @param key Key.
 * @return Value corresponding to the key on success, @c NULL if no matching
 *         entry was found.
 */
const void *hashMapGet(HashMap *map, const char key[]);

/**
 * @brief Checks whether a hash map contains an entry with a certain key.
 * @param map Hash map.
 * @param key Key.
 * @return Nonzero if the map contains an entry with the given key, 0 if it does
 *         not.
 */
int hashMapContainsKey(HashMap *map, const char key[]);

/**
 * @brief Removes a key-value pair from a hash map and frees the stored key.
 *
 * If @c valPtr is @c NULL, the internally stored value corresponding to the key
 * is freed. Otherwise it is written into @c *valPtr and the caller is
 * responsible for freeing it.
 * @param map    Hash map.
 * @param key    Key.
 * @param valPtr Output parameter receiving the internally stored value
 *               corresponding to the key.
 */
void hashMapRemove(HashMap *map, const char key[], const void **valPtr);

/**
 * @brief Returns the number of elements stored in a hash map.
 * @param map Hash map.
 * @return Number of elements stored in the map.
 */
size_t hashMapSize(const HashMap *map);

/**
 * @brief Checks whether a hash map is empty.
 * @param map Hash map.
 * @return Nonzero if the map contains no entries, 0 otherwise.
 */
int hashMapIsEmpty(const HashMap *map);

/**
 * @brief Removes all entries from a hash map.
 * @param map Hash map.
 */
void hashMapClear(HashMap *map);

/**
 * @brief Destroys a hash map.
 * @param map Hash map to be destroyed.
 */
void hashMapDestroy(HashMap *map);


#endif /* HASHMAP_H */
