#include <errno.h>
#include "rand_string_generator.h"
#include <stdlib.h>

char * generate_rand_str(unsigned long long min_len, unsigned long long max_len, char lower, char upper)
{
	char *str;
	size_t str_len;
	unsigned long long i;

	str_len = rand() % (max_len - min_len + 1) + min_len;

	str = malloc(sizeof(char) * (str_len));

	if (str == NULL) {
		/* errno should be set by malloc(2) to ENOMEM */
		return (NULL);
	}

	for (i = 0 ; i < (str_len-1) ; ++i) {
		str[i] = rand() % (upper - lower + 1) + lower;
	}

	str[i] = '\0';

	return (str);
}


char ** generate_rand_arr_of_strs(unsigned long long num_str, unsigned long long min_len,
    unsigned long long max_len, char lower, char upper)
{
	char **str_array;
	
	str_array = malloc(sizeof(char *) * num_str);
	
	if (str_array == NULL) {
		/* errno should be set by malloc(2) to ENOMEM */
		return (NULL);
	}

	for (unsigned long long i = 0 ; i < num_str ; ++i) {

		str_array[i] = generate_rand_str(min_len, max_len, lower, upper);

		if (str_array[i] == NULL) {

			/* 
			 * POSIX doesn't say free(2) to set errno but
			 * it doesn't forbid it either 
			 */
			int temp_errno = errno;

			/* free the previously allocated strings */
			free_rand_strings(str_array, i);

			errno = temp_errno;

			return (NULL);
		}
	}

	return (str_array);
}

void free_rand_str(char *str)
{
	free(str);
}

void free_rand_strings(char **str_array, unsigned long long num_str)
{
	for (unsigned long long i = 0 ; i < num_str ; ++i) {
		free_rand_str(str_array[i]);
	}

	free(str_array);
}
