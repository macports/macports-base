#include <sys/types.h>
#include <sys/wait.h>

#include <errno.h>

#include <libkern/OSAtomicQueue.h>

#include <pthread.h>

#include "rand_string_generator.h"
#include "shm_alloc.h"

#include <stdatomic.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define KRED  "\x1B[31m"
#define KGRN  "\x1B[32m"
#define KNRM  "\x1B[0m"

#define P_ERR(format, ...) \
	do {\
		fprintf(stderr, "%s:%d:%s:" format "\n", __FILE__, __LINE__, strerror(errno), ##__VA_ARGS__);\
		fflush(stderr);\
	}while(0)

#if TEST_THE_TEST

#	define ptr_malloc  malloc
#	define ptr_calloc  calloc
#	define ptr_free    free

#endif

char **global_rand_strings;
int global_max_idx;
_Atomic(int) global_idx_counter = 0;
char *shm_filename = "test_shm_file";

OSFifoQueueHead queue = OS_ATOMIC_FIFO_QUEUE_INIT;

struct inserted_data_mgr {
	shm_offt  in_shm;
	int       idx;
	struct inserted_data_mgr * link;
};

struct test_results_mgr {
	long tid;
	bool status;
};

struct cmdline_args {
	int process_count;
	int thread_count;
	int num_strings;
	bool error;
};


/*
 * Prints basic test details.
 */
void test_details(void);

/*
 * Manages command line args and returns a
 * `struct cmdline_args` type.
 */
struct cmdline_args parse_args(int argc, char *argv[]);

/*
 * calls fork(2) from the "current process (process_cnt - 1)
 * times. Means it generates process 1 less than the arg.
 */
void generate_processes(int process_cnt);

/*
 * It would spawn threads for testing and
 * record the result from each thread in
 * param3
 */
void spawn_threads_for_test(int thrd_cnt, void *(*tester_func)(void *), struct test_results_mgr **);

/*
 * It does the main testing. Also,shm_init()
 * is called inside it to test if shm_init() is thread safe.
 */
void *tester_func(void *arg);

/*
 * Displays the results as received from spawn_threads_for_test()
 */
void display_test_results(struct test_results_mgr **test_results_per_thrd, int thrd_cnt);

void usage(char *prog_name);

int main(int argc, char *argv[])
{
	struct cmdline_args args;
	size_t min_rand_strlen, max_rand_strlen;
	char rand_str_lower_ascii_limit, rand_str_upper_ascii_limit;
	struct test_results_mgr **test_results;
	int status, i;

	test_details();

	args = parse_args(argc, argv);

	if (args.error == true) {
		usage(argv[0]);
		/* NOT REACHED */
	}

	/*
	 * this shared memory allocator can't
	 * allocate more than get_shm_max_allocatable_size() - get_sizeof_block_header().
	 * So that's the max string size we will generate.
	 */
	min_rand_strlen = 1;
	max_rand_strlen = get_shm_max_allocatable_size() - get_sizeof_block_header();

	rand_str_lower_ascii_limit = 65;
	rand_str_upper_ascii_limit = 91;

	global_rand_strings =
	    generate_rand_arr_of_strs(args.num_strings, min_rand_strlen, max_rand_strlen,
	    rand_str_lower_ascii_limit, rand_str_upper_ascii_limit);

	if (global_rand_strings == NULL) {
		P_ERR("generate_rand_arr_of_strs() failed");
		exit(EXIT_FAILURE);
	}

	global_max_idx = args.num_strings;

	test_results = malloc(sizeof(struct test_results_mgr *) * args.thread_count);

	if (test_results == NULL) {
		P_ERR("malloc(2) failed");
		exit(EXIT_FAILURE);
	}

	for (i = 0 ; i < args.thread_count ; ++i) {

		test_results[i] = malloc(sizeof(struct test_results_mgr));

		if (test_results[i] == NULL) {
			P_ERR("malloc(2) failed");
			exit(EXIT_FAILURE);
		}
	}

	generate_processes(args.process_count);

	/*
	 * test_results are filled when function returns with
	 * the result from each thread.
	 */
	spawn_threads_for_test(args.thread_count, tester_func, test_results);

	display_test_results(test_results, args.thread_count);

	free_rand_strings(global_rand_strings, args.num_strings);

	for (i = 0 ; i < args.thread_count ; ++i) {
		free(test_results[i]);
	}

	free(test_results);

	status = 0;
	while (wait(&status) > 0);

	return 0;
}


void test_details(void)
{
#if TEST_THE_TEST
	printf("Testing the working of test with malloc(2), calloc(2) and free(2)\n");
#else
	printf("Max allocatable size by shm_(m|c)alloc() = %zu\n", get_shm_max_allocatable_size());
	printf("Min allocatable size by shm_(m|c)alloc() = %zu\n", get_shm_min_allocatable_size());
#endif
}


void usage(char *prog_name)
{
	fprintf(stderr, "usage: %s process_count thread_count num_strings\n", prog_name);
	exit(EXIT_FAILURE);
}

struct cmdline_args parse_args(int argc, char *argv[])
{

	struct cmdline_args args;

	args.error = false;

	if (argc != 4) {
		fprintf(stderr, "Invalid number of args\n");
		args.error = true;
		return (args);
	}

	errno = 0;
	args.process_count = (int)strtol(argv[1], (char **)NULL, 10);
	if (args.process_count <= 0) {
		if (errno != 0) {
			P_ERR("Invalid process count");
		}
		args.error = true;
		return (args);
	}

	errno = 0;
	args.thread_count  = (int)strtol(argv[2], (char **)NULL, 10);
	if (args.thread_count <= 0) {
		if (errno != 0) {
			P_ERR("Invalid thread count");
		}
		args.error = true;
		return (args);
	}

	errno = 0;
	args.num_strings = strtol(argv[3], (char **)NULL, 10);
	if (args.num_strings <= 0) {
		if (errno != 0) {
			P_ERR("Invalid string count");
		}
		args.error = true;
		return (args);
	}	

	return (args);
}

void generate_processes(int process_cnt)
{
	for (int i = 0 ; i < process_cnt - 1 ; ++i) {
		if (fork() == 0) {
			break;
		}
	}
}


void spawn_threads_for_test(int thrd_cnt, void *(*tester_func)(void *), struct test_results_mgr ** test_results)
{
	int i;
	pthread_t * thrds;

	thrds = malloc(sizeof(pthread_t) * thrd_cnt);

	if (thrds == NULL) {
		P_ERR("malloc(2) failed");
		exit(EXIT_FAILURE);
	}

	for (i = 0 ; i < thrd_cnt ; ++i) {
		pthread_create(&thrds[i], NULL, tester_func, test_results[i]);
	}

	for (i = 0 ; i < thrd_cnt ; ++i) {
		pthread_join(thrds[i], NULL);
	}

	free(thrds);
	shm_deinit();
}

void *tester_func(void *arg)
{
	bool retval;	
	struct test_results_mgr * test_result = arg;
	struct inserted_data_mgr *data;
	char *str;
	int idx;

	/*
	 * to test if shm_init() is thread safe, we call it here
	 * param1 is passed as NULL and we let shm_init() choose
	 * the address where shared mem is set.
	 */
	retval = shm_init(NULL, shm_filename);

	if (retval == false) {
		P_ERR("shm_init() failed");
		exit(EXIT_FAILURE);
	}

	test_result->status = true;

	while ((idx = atomic_fetch_add(&global_idx_counter, 1)) < global_max_idx) {

		str = ptr_calloc(1, strlen(global_rand_strings[idx]) + 1);

		if (str == NULL) {
			P_ERR("ptr_calloc() : out of memory\n");
			exit(EXIT_FAILURE);
		}

		strcpy(str, global_rand_strings[idx]);

		data = malloc(sizeof(struct inserted_data_mgr));

		if (data == NULL) {
			P_ERR("malloc(2) failed");
			exit(EXIT_FAILURE);
		}

		data->idx    = idx;
		data->in_shm = SHM_ADDR_TO_OFFT(str);

		OSAtomicFifoEnqueue(&queue, data, offsetof(struct inserted_data_mgr, link));

		sched_yield();

		data = OSAtomicFifoDequeue(&queue, offsetof(struct inserted_data_mgr, link));
		
		/*
		 * The data being popped maybe the same that was pushed
		 * or different if thread got changed. In any case, even if the same data
		 * is got back, below data is checked for correctness and then if
		 * a randomly generated number is divisible by 3, only then this data is freed,
		 * otherwise its pushed again for getting checked again.
		 */

		if (data == NULL) {
			continue;
		}

		idx = data->idx;
		str = SHM_OFFT_TO_ADDR(data->in_shm);

		if (strcmp(str, global_rand_strings[idx])) {

			test_result->status = false;
			break;

		} else {

			/*
			 * Just to make it more random,
			 * generate a random number and if its divisible by 3,
			 * shm_free() the popped offset else push it again
			 */

			if (rand() % 3 == 0) {
				ptr_free(str);
				free(data);
			} else {
				OSAtomicFifoEnqueue(&queue, data, offsetof(struct inserted_data_mgr, link));
			}
		}

	}

	data = OSAtomicFifoDequeue(&queue, offsetof(struct inserted_data_mgr, link));
	
	while(data != NULL) {

		idx = data->idx;
		str = SHM_OFFT_TO_ADDR(data->in_shm);

		if (strcmp(str, global_rand_strings[idx])) {

			test_result->status = false;
			break;

		} else {
			ptr_free(str);
			free(data);
		}
	
		data = OSAtomicFifoDequeue(&queue, offsetof(struct inserted_data_mgr, link));
	}

	test_result->tid = (long)pthread_self();

	return (NULL);
}


void display_test_results(struct test_results_mgr **test_results, int thrd_cnt)
{
	for (int i = 0 ; i < thrd_cnt ; ++i) {
		if (test_results[i]->status == true) {
			fprintf(stderr, KGRN "[%d, %ld] : Test passed\n" KNRM, getpid(), test_results[i]->tid);
		} else {
			fprintf(stderr, KRED "[%d, %ld] : Test failed\n" KNRM, getpid(), test_results[i]->tid);
		}
	}
}
