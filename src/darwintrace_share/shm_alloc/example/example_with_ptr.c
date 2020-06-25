#include "shm_alloc.h"
#include <stdlib.h>
#include <string.h>

/* same as ptr_calloc() */
void *my_calloc(size_t count, size_t size)
{
	shm_offt offt_in_shm;

	offt_in_shm = shm_calloc(count, size);

	if (offt_in_shm == SHM_NULL) {
		return (NULL);
	}

	return (SHM_OFFT_TO_ADDR(offt_in_shm));
}

/* same as ptr_free() */
void my_free(void *ptr)
{
	shm_offt offt_in_shm;

	if (ptr == NULL) {
		offt_in_shm = SHM_NULL;
	} else {
		offt_in_shm = SHM_ADDR_TO_OFFT(ptr);
	}

	shm_free(offt_in_shm);
}

int main()
{

	char *tmp_shm_file = "temp_shm_file";
	bool retval;


	/*
	 * Initialize shm
	 */
	retval = shm_init(NULL, tmp_shm_file);

	if (retval == false) {
		fprintf(stderr, "shm_init() failed!");
		exit(EXIT_FAILURE);
	}

	char *str;
	size_t string_len = 100;

	str = my_calloc(string_len, sizeof(char));

	if (str == NULL) {
		fprintf(stderr, "Out of memory\n");
		exit(EXIT_FAILURE);
	}

	strcpy(str, "My test string!");

	printf("%s\n", str);

	/* free from the shared memory */
	my_free(str);

	/* release resources held by shared memory */
	shm_deinit();

	/* User's responsibilty to delete file after use */
	remove(tmp_shm_file);

	return 0;
}
