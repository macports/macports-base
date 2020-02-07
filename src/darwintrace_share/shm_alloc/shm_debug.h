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

/*
 * Well if this crappy multithreaded lock free program needed debugging,
 * the functions here are really helpful.
 *
 * The main essence here is to use `pid_file`, which is a file named
 * after process' pid and thread's tid. Before using it, open_pid_file()
 * should be called.
 * The directory in which these files are created can be defined by macro
 * DEBUG_DIR whose value is a path to be enclosed in double quotes.
 * e.g., #define DEBUG_DIR "some/path".
 * If not defined, it defaults to PWD.
 *
 * TODO: override pthread_create() and main thread or whatever
 * so that when a new thread gets created, open_pid_file() is
 * automatically called.
 */

#ifndef __SHM_DEBUG_H__
#define __SHM_DEBUG_H__

#include <sys/param.h>
#include "shm_types.h"

extern _Thread_local char pid_file_name[MAXPATHLEN];
extern _Thread_local FILE *pid_file;

void open_pid_file();

#define BTS(boolean) ((boolean) ? "true" : "false")

#define PRINT_IN_PID_FILE_WITH_VARGS(fmt, ...) \
	do{ open_pid_file(); fprintf(pid_file, fmt, __VA_ARGS__); }while(0)

#define PRINT_IN_PID_FILE(fmt) \
	do{ open_pid_file(); fprintf(pid_file, fmt); }while(0)


#define PTPRINTF_WITH_VARGS(format, ...) \
	printf("[%d,%ld]:" format, getpid(), (long)pthread_self(), __VA_ARGS__)

#define PTPRINTF(format) \
	printf("[%d,%ld]:" format, getpid(), (long)pthread_self())


void print_buddy_bitmap(shm_bitmap, FILE *) ;
void print_all_bits(shm_bitmap, FILE *);

void print_bmp_data(struct bmp_data_mgr, FILE *);
void print_mem_offt_data(struct mem_offt_mgr, FILE *);

#endif /* __SHM_DEBUG_H__ */
