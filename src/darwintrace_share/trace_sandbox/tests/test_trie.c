#include <assert.h>
#include <errno.h>

#include "rand_string_generator.h"
#include "shm_alloc.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "trie.h"

#include <unistd.h>

#define KRED  "\x1B[31m"
#define KGRN  "\x1B[32m"
#define KNRM  "\x1B[0m"


#define P_ERR(format, ...) \
	do {\
		fprintf(stderr, "%s:%d:%s:" format "\n", __FILE__, __LINE__, strerror(errno), ##__VA_ARGS__);\
		fflush(stderr);\
	}while(0)

long max_idx;

bool test_status = true;

void insert_all_strings(PTR(struct prefix_trie), char **, int);
void search_all_strings(PTR(struct prefix_trie), char **, int);

int main(int argc, char *argv[])
{
	if (argc != 2) {
		fprintf(stderr, "usage: %s num_strings\n", argv[0]);
		exit(EXIT_FAILURE);
	}

	errno = 0;
	max_idx = strtol(argv[1], (char **)NULL, 10);
	if (max_idx <= 0) {
		if (errno != 0)
			P_ERR("Invalid string count");
		exit(EXIT_FAILURE);
	}

	bool retval = shm_init(NULL, "test_shm_file");

	if (retval == false) {
		P_ERR("shm_init() failed");
		exit(EXIT_FAILURE);
	}

	char **rand_strings;
	
	rand_strings = generate_rand_arr_of_strs(max_idx, 100, 200, 65, 91);

	if (rand_strings == NULL) {
		P_ERR("generate_rand_arr_of_strs() failed");
		exit(EXIT_FAILURE);
	}

	PTR(struct prefix_trie) pt;
	
	pt = trie_init();

	if (pt == SHM_NULL) {
		P_ERR("trie_init() failed");
		printf(KRED "TEST FAILED\n" KNRM);
	}

	insert_all_strings(pt, rand_strings, max_idx);

	search_all_strings(pt, rand_strings, max_idx);

	free_rand_strings(rand_strings, max_idx);

	if (test_status == true) {
		printf(KGRN "TEST PASSED\n" KNRM);
	} else {
		printf(KRED "TEST FAILED\n" KNRM);
	}

	return 0;
}


void insert_all_strings(PTR(struct prefix_trie) pt, char **strings, int num_str)
{
	bool did_insert;
	for (int i = 0 ; i < num_str ; ++i) {
		did_insert = trie_insert(pt, strings[i], '+');

		if (!did_insert) {
			P_ERR("trie_insert() failed for strings[%d] = %s", i, strings[i]);
			test_status = false;
		}
	}
}

void search_all_strings(PTR(struct prefix_trie) pt, char **strings, int num_str)
{
	bool did_find;
	uint8_t permission;
	for (int i = 0 ; i < num_str ; ++i) {
		did_find = trie_search(pt, strings[i], &permission);

		if (!did_find) {
			P_ERR("trie_search() failed for strings[%d] = %s", i, strings[i]);
			test_status = false;
		}
	}
}
