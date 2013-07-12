/* $Id$ */
#ifdef HAVE_STRLCAT
#include <string.h>
#else
size_t strlcat(char *dst, const char *src, size_t size);
#endif
