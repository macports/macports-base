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

#define SZ (10000)
#define KEYSZ 60

#define xstr(s) str(s)
#define str(s) #s

void ctrie_test_insert(PTR(ctrie_t) ctrie, int processes, int modulo) {
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
				if (i % processes != modulo) {
						continue;
				}
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
				value.counter = i;
				value.flags = modulo;

				//fprintf(stderr, "inserting key %zd: %s (hash: 0x%x)...\n", i, inputs[i], hash(inputs[i]));
				clock_t start = clock();
				if (ctrie_insert(ctrie, inputs[i], &value) != INSERT_SUCCESS) {
						fprintf(stderr, "[%d]: Failed to insert key %s\n", getpid(), inputs[i]);
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

		fprintf(stderr, "[%d]: time gen: %Lf\n", getpid(), ((long double)gen) / CLOCKS_PER_SEC);
		fprintf(stderr, "[%d]: time insert: %Lf\n", getpid(), ((long double)insert) / CLOCKS_PER_SEC);

		bool failed = false;
		clock_t lookup = 0;

		for (size_t i = 0; i < SZ; ++i) {
				if (i % processes != modulo) {
						continue;
				}
				value_t val;
				clock_t start = clock();
				lookup_result_t res = ctrie_lookup(ctrie, inputs[i], &val);
				lookup += (clock() - start);
				if (res != LOOKUP_FOUND) {
						fprintf(stderr, "[%d]: Failed to find entry %s in ctrie\n", getpid(), inputs[i]);
						continue;
				}
				if (val.counter != i) {
						fprintf(stderr, "[%d]: value counter of entry %s was modified to %x\n", getpid(), inputs[i], val.counter);
						failed = true;
				}
		}

		fprintf(stderr, "[%d]: time lookup: %Lf\n", getpid(), ((long double)lookup) / CLOCKS_PER_SEC);

}

void ctrie_add_filetree(PTR(ctrie_t) ctrie, char* const path) {
		if (!ctrie) {
				perror("ctrie_new");
				abort();
		}

		clock_t insert = 0;
		char* const paths[] = {path, NULL};
		FTS* fts = fts_open(paths, FTS_NOCHDIR, 0);
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

		fprintf(stderr, "[%d]: insert time: %Lf\n", getpid(), ((long double) insert) / CLOCKS_PER_SEC);

		fts_close(fts);

}

int double_myself() {
		switch (fork()) {
				case -1: /* error */
						perror("fork");
						abort();
				case 0: /* child */
						return 1;
				default: /* parent */
						// continue
						return 0;
		}
}

int main(int argc, char* argv[]) {
		if (argc < 5) {
				fprintf(stderr, "Usage: %s path0 path1 path2 path3\n", argv[0]);
				exit(EXIT_FAILURE);
		}
		PTR(ctrie_t) ctrie_insert = ctrie_new();
		PTR(ctrie_t) ctrie_filetree = ctrie_new();
		int id = (double_myself() * 2 + double_myself());
		int processes = 4;
		ctrie_test_insert(ctrie_insert, processes, id);
		ctrie_add_filetree(ctrie_filetree, argv[1 + id]);

		if (id == 0) {
				sleep(2);
				ctrie_print(ctrie_insert);
				ctrie_print(ctrie_filetree);
		}
}
