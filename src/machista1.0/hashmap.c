/* vim:expandtab:tw=80:ts=2:sts=2:sw=2
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


#ifndef _BSD_SOURCE
  #define _BSD_SOURCE
#endif
#ifndef _CRT_NONSTDC_NO_DEPRECATE
  #define _CRT_NONSTDC_NO_DEPRECATE
#endif

#include "hashmap.h"
#include <limits.h>
#include <stdint.h>
#include <string.h>


static const size_t INITIAL_CAPACITY = 16; /* Must be a power of 2 */
static const size_t MAXIMUM_CAPACITY = (1U << 31);
static const float  LOAD_FACTOR      = 0.75;


typedef struct HashMapEntry {
  char                *key;
  const void          *value;
  struct HashMapEntry *next;
  uint32_t             hash;
} HashMapEntry;

struct HashMap {
  HashMapEntry **table;
  size_t         capacity;
  size_t         size;
  size_t         threshold;
  void         (*freeFunc)(const void *);
};


static void setTable(HashMap *map, HashMapEntry **table, size_t capacity) {
  map->table     = table;
  map->capacity  = capacity;
  map->threshold = (size_t) (capacity * LOAD_FACTOR);
}


static uint32_t doHash(const char key[]) {
  size_t   length;
  size_t   i;
  uint32_t h = 0;
  if (key == NULL)
    return 0;
  length = strlen(key);
  for (i = 0; i < length; ++i) {
    h = (31 * h) + key[i];
  }
  h ^= (h >> 20) ^ (h >> 12);
  return h ^ (h >> 7) ^ (h >> 4);
}


static size_t indexFor(uint32_t hash, size_t length) {
  return hash & (length - 1);
}


static int isHit(HashMapEntry *e, const char key[], uint32_t hash) {
  return (e->hash == hash
          && (e->key == key || (key != NULL && strcmp(e->key, key) == 0)));
}


static void copyOrFree(void (*freeFunc)(const void *),
                       const void *value, const void **valPtr) {
  if (valPtr != NULL)
    *valPtr = value;
  else
    freeFunc(value);
}


static int updateValue(HashMap *map, HashMapEntry *e, const void *newVal,
                       const void **oldValPtr) {
  copyOrFree(map->freeFunc, e->value, oldValPtr);
  e->value = newVal;
  return 1;
}


/* Creates a hash map. */
HashMap *hashMapCreate(void (*freeFunc)(const void *)) {
  HashMapEntry **table;
  HashMap       *map = malloc(sizeof(*map));
  if (map == NULL)
    return NULL;
  table = calloc(INITIAL_CAPACITY, sizeof(*map->table));
  if (table == NULL) {
    free(map);
    return NULL;
  }
  setTable(map, table, INITIAL_CAPACITY);
  map->size = 0;
  map->freeFunc = freeFunc;
  return map;
}


/* Inserts a key-value pair into a hash map. */
int hashMapPut(HashMap *map, const char key[], const void * const value,
               const void **oldValPtr) {

  HashMapEntry  *e;
  size_t         newCapacity;
  HashMapEntry **newTable;
  size_t         i;

  /* If an entry with the same key exists, update it */
  uint32_t hash  = doHash(key);
  size_t   index = indexFor(hash, map->capacity);
  for (e = map->table[index]; e != NULL; e = e->next) {
    if (isHit(e, key, hash) == 0)
      continue;
    return updateValue(map, e, value, oldValPtr);
  }

  /* Create a new entry */
  e = calloc(1, sizeof(HashMapEntry)); /* Must be zeroed */
  if (e == NULL)
    return 0;

  /* Copy key and value into the entry */
  if (key != NULL) {
    e->key = strdup(key);
    if (e->key == NULL) {
      free(e);
      return 0;
    }
  }
  if (updateValue(map, e, value, oldValPtr) == 0) {
    free(e->key);
    free(e);
    return 0;
  }

  /* Insert entry into the table */
  e->hash = hash;
  e->next = map->table[index];
  map->table[index] = e;
  if (map->size++ < map->threshold)
    return 1;

  /* If the size exceeds the threshold, double the table's capacity */
  newCapacity = 2 * map->capacity;
  if (map->capacity == MAXIMUM_CAPACITY) {
    map->threshold = UINT_MAX;
    return 1;
  }
  newTable = calloc(newCapacity, sizeof(*newTable));
  if (newTable == NULL)
    return 0;

  /* Copy entries from the old table into the new one */
  for (i = 0; i < map->capacity; ++i) {
    HashMapEntry *next;
    for (e = map->table[i]; e != NULL; e = next) {
      index   = indexFor(e->hash, newCapacity);
      next    = e->next;
      e->next = newTable[index];
      newTable[index] = e;
    }
  }

  /* Release the old table and set the new one */
  free(map->table);
  setTable(map, newTable, newCapacity);
  return 1;
}


/* Performs a hash map lookup. */
const void *hashMapGet(HashMap *map, const char key[]) {
  HashMapEntry *e;
  uint32_t      hash  = doHash(key);
  size_t        index = indexFor(hash, map->capacity);
  for (e = map->table[index]; e != NULL; e = e->next) {
    if (isHit(e, key, hash))
      return e->value;
  }
  return NULL;
}


/* Checks whether a hash map contains an entry with a certain key. */
int hashMapContainsKey(HashMap *map, const char key[]) {
  HashMapEntry *e;
  uint32_t      hash  = doHash(key);
  size_t        index = indexFor(hash, map->capacity);
  for (e = map->table[index]; e != NULL; e = e->next) {
    if (isHit(e, key, hash))
      return 1;
  }
  return 0;
}


/* Removes a key-value pair from a hash map. */
void hashMapRemove(HashMap *map, const char key[], const void **valPtr) {
  uint32_t      hash  = doHash(key);
  size_t        index = indexFor(hash, map->capacity);
  HashMapEntry *prev  = map->table[index];
  HashMapEntry *e     = prev;
  while (e != NULL) {
    HashMapEntry *next = e->next;
    if (isHit(e, key, hash)) {
      map->size--;
      if (prev == e)
        map->table[index] = next;
      else
        prev->next = next;
      break;
    }
    prev = e;
    e    = next;
  }
  if (e == NULL) {
    copyOrFree(map->freeFunc, NULL, valPtr);
    return;
  }
  free(e->key);
  copyOrFree(map->freeFunc, e->value, valPtr);
  free(e);
}


/* Returns the number of elements stored in a hash map. */
size_t hashMapSize(const HashMap *map) {
  return map->size;
}


/* Checks whether a hash map is empty. */
int hashMapIsEmpty(const HashMap *map) {
  return (map->size == 0);
}


/* Removes all entries from a hash map. */
void hashMapClear(HashMap *map) {
  size_t i;
  for (i = 0; i < map->capacity; ++i) {
    HashMapEntry *e;
    HashMapEntry *next;
    for (e = map->table[i]; e != NULL; e = next) {
      free(e->key);
      map->freeFunc(e->value);
      next = e->next;
      free(e);
    }
    map->table[i] = NULL;
  }
}


/* Destroys a hash map. */
void hashMapDestroy(HashMap *map) {
  if (map == NULL)
    return;
  hashMapClear(map);
  free(map->table);
  free(map);
}
