#ifndef __DARWINTRACE_SHARE_H__
#define __DARWINTRACE_SHARE_H__

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "ctrie/ctrie.h"
#include "shm_alloc/shm_alloc.h"
#include "trace_sandbox/trie.h"
#include <stdbool.h>
#include <stdint.h>
#include "trace_sandbox/trie.h"

bool set_shared_memory(char *);
void unset_shared_memory(void);

enum {
	TRACE_SANDBOX_ALLOW      = 0,
	TRACE_SANDBOX_DENY       = 1,
	TRACE_SANDBOX_ASK_SERVER = 2
};


FILE * get_darwintrace_stderr();

#define DT_PRINT(fmt, ...) \
	do {\
		fprintf(get_darwintrace_stderr(), "%d:" fmt "\n", __LINE__, ##__VA_ARGS__);\
		fflush(get_darwintrace_stderr());\
	}while (0)

#define DT_ERR(fmt, ...) \
	do {\
		fprintf(get_darwintrace_stderr(), "%d:%s:" fmt "\n", __LINE__, strerror(errno), ##__VA_ARGS__);\
		fflush(get_darwintrace_stderr());\
	}while (0)

shm_offt new_cache_tree(void);
void add_to_cache(shm_offt cache_root, const char *key, uint32_t flags);
bool search_cache(shm_offt cache_root, const char *key, uint32_t *flags);


shm_offt new_trace_sandbox(void);
void trace_sandbox_set_fence(shm_offt sandbox);
void trace_sandbox_unset_fence(shm_offt sandbox);
bool trace_sandbox_is_fence_set(shm_offt sandbox);
bool add_to_trace_sandbox(shm_offt sandbox, const char *path, uint8_t sandbox_action);
bool is_path_in_sandbox(shm_offt sandbox, const char *path, uint8_t *sandbox_action);
#endif /* __DARWINTRACE_SHARE_H__ */
