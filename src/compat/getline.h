#ifndef _GETLINE_H
#define _GETLINE_H

#include <stdio.h>
#include <unistd.h>

#if !HAVE_GETLINE
ssize_t	getline(char **, size_t *, FILE *);
#endif

#endif /* _GETLINE_H */
