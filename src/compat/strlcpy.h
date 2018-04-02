#ifndef _STRLCPY_H
#define _STRLCPY_H

#include <string.h>

#if !HAVE_STRLCPY
size_t strlcpy(char * restrict dst, const char * restrict src, size_t size);
#endif

#endif /* _STRLCPY_H */
