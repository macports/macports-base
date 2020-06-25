#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdbool.h>
#include <string.h>
#include <time.h>
#include <sys/stat.h>
#include <fts.h>

#include "ctrie.h"

#define SZ (100000)
#define KEYSZ 200

#define xstr(s) str(s)
#define str(s) #s

static uint32_t hash(const char key[]) {
	size_t length;
	size_t i;
	uint32_t h = 0;
	if (key == NULL) {
		return 0;
	}
	length = strlen(key);
	for (i = 0; i < length; ++i) {
		h = (31 * h) + key[i];
	}
	h ^= (h >> 20) ^ (h >> 12);
	return h ^ (h >> 7) ^ (h >> 4);
}

void ctrie_test_insert() {
	PTR(ctrie_t) ctrie = ctrie_new();
	if (!ctrie) {
		perror("ctrie_new");
		abort();
	}

	clock_t insert = 0;
	clock_t gen = 0;

	char **inputs = malloc(sizeof(char*) * SZ);
	if (!inputs) {
		perror("malloc");
		abort();
	}

	//FILE *urandom = fopen("/dev/urandom", "r");
	for (size_t i = 0; i < SZ; ++i) {
		clock_t genstart = clock();
		inputs[i] = malloc(sizeof(char) * (KEYSZ + 1));
		if (!inputs[i]) {
			perror("malloc");
			abort();
		}

		//size_t inputidx = 0;
		//while (inputidx < KEYSZ) {
		//	int c = fgetc(urandom);
		//	if (c > 'a' && c <= 'z') {
		//		inputs[i][inputidx] = c;
		//		inputidx++;
		//	}
		//}
		//inputs[i][KEYSZ] = '\0';
		snprintf(inputs[i], KEYSZ + 1, "%" xstr(KEYSZ) "zd", i);
		gen += (clock() - genstart);

		value_t value;
		value.counter = hash(inputs[i]);
		value.flags = i;

		//fprintf(stderr, "inserting key %zd: %s (hash: 0x%x)...\n", i, inputs[i], hash(inputs[i]));
		clock_t start = clock();
		if (ctrie_insert(ctrie, inputs[i], &value) != INSERT_SUCCESS) {
			fprintf(stderr, "Failed to insert key %s\n", inputs[i]);
			abort();
		}
		insert += (clock() - start);

#if 0
		value_t output;
		lookup_result_t res = ctrie_lookup(ctrie, inputs[i], &output);
		if (res != LOOKUP_FOUND) {
			fprintf(stderr, "You idiot! I just inserted %s, but it's not there. Obviously you suck at this.\n", inputs[i]);
			ctrie_print(ctrie);
			abort();
		}
#endif
	}

	fprintf(stderr, "time gen: %Lf\n", ((long double)gen) / CLOCKS_PER_SEC);
	fprintf(stderr, "time insert: %Lf\n", ((long double)insert) / CLOCKS_PER_SEC);

	bool failed = false;
	clock_t lookup = 0;

	for (size_t i = 0; i < SZ; ++i) {
		value_t val;
		clock_t start = clock();
		lookup_result_t res = ctrie_lookup(ctrie, inputs[i], &val);
		lookup += (clock() - start);
		if (res != LOOKUP_FOUND) {
			fprintf(stderr, "Failed to find entry %s in ctrie\n", inputs[i]);
			continue;
		}
		if (val.flags != i) {
			fprintf(stderr, "value flags of entry %s were modified to %x\n", inputs[i], val.flags);
			failed = true;
		}
	}

	fprintf(stderr, "time lookup: %Lf\n", ((long double)lookup) / CLOCKS_PER_SEC);

	if (failed) {
		ctrie_print(ctrie);
	}
}

void ctrie_add_filetree() {
	PTR(ctrie_t) ctrie = ctrie_new();
	if (!ctrie) {
		perror("ctrie_new");
		abort();
	}

	clock_t insert = 0;
	char* const path[] = {".", NULL};
	FTS* fts = fts_open(path, FTS_NOCHDIR, 0);
	if (!fts) {
		perror("fts_open");
		abort();
	}

	FTSENT* node;
	size_t i = 0;
	while ((node = fts_read(fts)) != NULL) {
		value_t value;
		value.counter = ++i;
		value.flags = node->fts_info;
		clock_t start = clock();
		ctrie_insert(ctrie, node->fts_path, &value);
		insert += (clock() - start);
	}

	fprintf(stderr, "insert time: %Lf\n", ((long double) insert) / CLOCKS_PER_SEC);

	fts_close(fts);

	ctrie_print(ctrie);
}

int main() {
	ctrie_test_insert();
	ctrie_add_filetree();
}
