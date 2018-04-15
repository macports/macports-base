#ifndef _STRLCAT_H
#define _STRLCAT_H

#include <string.h>

#if !HAVE_STRLCAT
size_t strlcat(char *dst, const char *src, size_t size);
#endif

#endif /* _STRLCAT_H */
