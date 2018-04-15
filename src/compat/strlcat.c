/*
**  Replacement for a missing strlcat.
**
**  Written by Russ Allbery <rra@stanford.edu>
**  This work is hereby placed in the public domain by its author.
**
**  Provides the same functionality as the *BSD function strlcat, originally
**  developed by Todd Miller and Theo de Raadt.  strlcat works similarly to
**  strncat, except simpler.  The result is always nul-terminated even if the
**  source string is longer than the space remaining in the destination
**  string, and the total space required is returned.  The third argument is
**  the total space available in the destination buffer, not just the amount
**  of space remaining.
*/

#include <stddef.h>
#include <string.h>

#if HAVE_CONFIG_H
#include <config.h>
#endif

#ifndef HAVE_STRLCAT

#include "strlcat.h"

size_t strlcat(char *dst, const char *src, size_t size)
{
    size_t used, length, copy;

    used = strlen(dst);
    length = strlen(src);
    if (size > 0 && used < size - 1) {
        copy = (length >= size - used) ? size - used - 1 : length;
        memcpy(dst + used, src, copy);
        dst[used + copy] = '\0';
    }
    return used + length;
}
#endif
