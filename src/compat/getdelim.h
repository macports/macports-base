#ifndef _GETDELIM_H_
#define _GETDELIM_H_

#include <stdio.h>
#include <unistd.h>

#if !HAVE_GETDELIM
ssize_t	getdelim(char **, size_t *, int, FILE *);
#endif

#endif	/* _GETDELIM_H */
