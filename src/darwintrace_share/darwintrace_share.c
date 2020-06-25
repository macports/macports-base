#include "darwintrace_share.h"
#include "ctrie/ctrie.h"
#include "shm_alloc/shm_alloc.h"
#include "trace_sandbox/trie.h"

#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>

static _Atomic(FILE *) darwintrace_stderr = NULL;

FILE * get_darwintrace_stderr()
{
	if (atomic_load(&darwintrace_stderr) != NULL) {
		return (darwintrace_stderr);
	}

	char *darwintrace_stderr_filename;
	FILE *old_fileptr, *new_fileptr;

	/*
	 * DARWINTRACE_STDERR is preserved across execs.
	 * This is handled in darwintracelib1.0/proc.c
	 */
	darwintrace_stderr_filename = getenv("DARWINTRACE_STDERR");

	if (darwintrace_stderr_filename == NULL) {
		fprintf(stderr, "DARWINTRACE_STDERR not set, using stderr as darwintrace_stderr\n");
		return (stderr);
	}

	old_fileptr = NULL;
	new_fileptr = fopen(darwintrace_stderr_filename, "a+");

	if (new_fileptr == NULL) {
		perror("fopen(3) failed, using stderr darwintrace_stderr");
		return (stderr);
	}

	atomic_compare_exchange_strong(&darwintrace_stderr, &old_fileptr, new_fileptr);

	return (atomic_load(&darwintrace_stderr));
}

bool set_shared_memory(char *shm_filename)
{
	return (shm_init(NULL, shm_filename));
}

void unset_shared_memory(void)
{
	shm_deinit();
}

shm_offt new_cache_tree(void)
{
	return (ctrie_new());
}

void add_to_cache(shm_offt cache_root, const char *key, uint32_t flags)
{
	insert_result_t res;
	value_t val;

	val.flags = flags;

	res = ctrie_insert(cache_root, key, &val);

	if (res == INSERT_SUCCESS) {
		return;
	}
	
	/*
	 * This need not be handled by caller,
	 * as even if the cache runs out of memory,
	 * code execution shouldn't stop.
	 * Thus, this function doesn't return failure status.
	 */
	if (res == INSERT_OUT_OF_MEMORY) {
		DT_PRINT("ctrie_insert(): out of memory");
	} else if (res == INSERT_BUG) {
		DT_PRINT("ctrie_insert(): bug");
	}
}

bool search_cache(shm_offt cache_root, const char *key, uint32_t *flags)
{
	lookup_result_t res;
	value_t val;

	res = ctrie_lookup(cache_root, key, &val);

	if (res == LOOKUP_FOUND) {
		*flags = val.flags;
		return (true);
	}

	if (res == LOOKUP_BUG) {
		DT_PRINT("ctrie_lookup(): bug");
	}

	return (false);
}

shm_offt new_trace_sandbox(void)
{
	return (trie_init());
}

void trace_sandbox_set_fence(shm_offt sandbox)
{
	trie_set_fence(sandbox);
}

void trace_sandbox_unset_fence(shm_offt sandbox)
{
	trie_unset_fence(sandbox);
}

bool trace_sandbox_is_fence_set(shm_offt sandbox)
{
	return (trie_is_fence_set(sandbox));
}

bool add_to_trace_sandbox(shm_offt sandbox, const char *path, uint8_t sandbox_action)
{
	return (trie_insert(sandbox, path, sandbox_action));
}

bool is_path_in_sandbox(shm_offt sandbox, const char *path, uint8_t *sandbox_action)
{
	return (trie_prefix_search(sandbox, path, sandbox_action));
}
