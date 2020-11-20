#include <stdlib.h>
#include "missing.h"

void
freezero(void *ptr, size_t sz)
{
	if (ptr == NULL)
		return;

	explicit_bzero(ptr, sz);
	free(ptr);
}
