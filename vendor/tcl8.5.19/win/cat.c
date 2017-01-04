/*
 * cat.c --
 *
 *	Program used when testing tclWinPipe.c
 *
 * Copyright (c) 1996 by Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include <stdio.h>
#include <io.h>
#include <string.h>

int
main(void)
{
    char buf[1024];
    int n;
    const char *err;

    while (1) {
	n = read(0, buf, sizeof(buf));
	if (n <= 0) {
	    break;
	}
        write(1, buf, n);
    }
    err = (sizeof(int) == 2) ? "stderr16" : "stderr32";
    write(2, err, strlen(err));

    return 0;
}
