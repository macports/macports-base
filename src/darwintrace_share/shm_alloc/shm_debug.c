/*
 * BSD 2-Clause License
 *
 * Copyright (c) 2020 The MacPorts Project
 * Copyright (c) 2020, Mihir Luthra
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#include <pthread.h>

#include "shm_bit_fiddler.h"
#include "shm_err.h"
#include "shm_constants.h"
#include "shm_types.h"
#include "shm_debug.h"

#include <stdlib.h>
#include <string.h>
#include <unistd.h>

_Thread_local char pid_file_name[MAXPATHLEN];
_Thread_local FILE *pid_file;

void open_pid_file()
{
	char pid_file_name_alias[MAXPATHLEN];

#ifndef DEBUG_DIR
#define DEBUG_DIR getenv("PWD")
#endif

	sprintf(pid_file_name_alias, "%s/pid=%d,tid=%ld.dbgfl", DEBUG_DIR, getpid(), (long)pthread_self());

	if (strcmp(pid_file_name_alias, pid_file_name)) {
		pid_file = NULL;
		strcpy(pid_file_name, pid_file_name_alias);
	}

	if (pid_file == NULL)
		pid_file = fopen(pid_file_name, "a+");

	if (pid_file == NULL) {
		P_ERR("fopen(2) failed for file %s", pid_file_name);
		abort();
	}
}

void print_bmp_data(struct bmp_data_mgr bmp_data, FILE *outfile)
{
	fprintf(outfile, "bitmap_no : %d\n", bmp_data.bitmap_no);
	fprintf(outfile, "relative_bit_pos : %d\n", bmp_data.relative_bit_pos);
	fprintf(outfile, "abs_bit_pos : %d\n", bmp_data.abs_bit_pos);
	fprintf(outfile, "mem_level : %zu\n", bmp_data.mem_level);
}

void print_mem_offt_data(struct mem_offt_mgr mem_offt_data, FILE *outfile)
{
	fprintf(outfile, "offt_to_blk : %zu\n", mem_offt_data.offt_to_blk);
	fprintf(outfile, "internal_offt : %zu\n", mem_offt_data.internal_offt);
	fprintf(outfile, "offt_to_allocated_mem : %zu\n", mem_offt_data.offt_to_allocated_mem);
	fprintf(outfile, "mem : %zu\n", mem_offt_data.mem);
}

void print_buddy_bitmap(shm_bitmap bmp, FILE *outfile)
{
	size_t mem = MAX_ALLOCATABLE_SIZE;

	for (int i = 1 ; i < BITS  ; ++i)
	{
		fprintf(outfile, "%lu", (bmp >> (BITS - (i % BITS) - 1) & (shm_bitmap)1));

		if (is_power_of_two(i+1)) {
			fprintf(outfile, " --> %zu \n", (mem));
			mem /= 2;
		}
	}
	fprintf(outfile, "\n");
}


void print_all_bits(shm_bitmap bmp, FILE *outfile)
{
	for(int i = BITS - 1 ; i >= 0 ; --i)
		fprintf(outfile, "%" PRIu_shm_offt, ((shm_bitmap)bmp >> i) & (shm_bitmap)1);

	fprintf(outfile, "\n");
}
