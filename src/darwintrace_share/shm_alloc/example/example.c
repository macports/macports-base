#include "shm_alloc.h"
#include <stdlib.h>
#include <string.h>

int main()
{
	char *shm_file_name;
	bool retval;

	shm_file_name = "shm_temp_file";

	/*
	 * Initialize shm
	 */
	retval = shm_init(NULL, shm_file_name);

	if (retval == false) {
		fprintf(stderr, "shm_init() failed!");
		exit(EXIT_FAILURE);
	}

	shm_offt str;

	/* needs to be uint8_t */
	uint8_t *shm_base;
	shm_base = get_shm_user_base();

	size_t string_len = 100;

	/*
	 * shm calloc returns an offset which needs to be added to
	 * the shared memory base to access the memory
	 */
	str = shm_calloc(string_len, sizeof(char));

	if (str == SHM_NULL) {
		fprintf(stderr, "Out of memory\n");
		exit(EXIT_FAILURE);
	}

	strcpy((char *)(shm_base + str), "My test string!");

	printf("%s\n", (char *)(shm_base + str));

	/* free from the shared memory */
	shm_free(str);

	/* release resources held by shared memory */
	shm_deinit();

	/* User's responsibilty to delete the file after usage */
	remove(shm_file_name);

	return 0;
}
