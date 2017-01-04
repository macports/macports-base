/*
 * cattcl.c --
 *    A crude version of cat used in the build to concatenate Tcl source
 * files into a library.
 *-----------------------------------------------------------------------------
 * Copyright 1996-1999 Karl Lehenbauer and Mark Diekhans.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies.  Karl Lehenbauer and
 * Mark Diekhans make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *-----------------------------------------------------------------------------
 * $Id: cattcl.c,v 1.1 2001/10/24 23:31:50 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include <stdio.h>
#include <windows.h>


/*-----------------------------------------------------------------------------
 * TclX_SplitWinCmdLine --
 *   Parse the window command line into arguments.
 *
 * Parameters:
 *   o argcPtr (O) - Count of arguments is returned here.
 *   o argvPtr (O) - Argument vector is returned here.
 * Notes:
 *   This code taken from the Tcl file tclAppInit.c: Copyright (c) 1996 by
 * Sun Microsystems, Inc.
 *-----------------------------------------------------------------------------
 */
void
TclX_SplitWinCmdLine (argcPtr, argvPtr)
    int    *argcPtr;
    char ***argvPtr;
{
    char   *args = GetCommandLine ();
    char **argvlist, *p;
    int size, i;

    /*
     * Precompute an overly pessimistic guess at the number of arguments
     * in the command line by counting non-space spans.
     */
    for (size = 2, p = args; *p != '\0'; p++) {
        if (isspace (*p)) {
            size++;
            while (isspace (*p)) {
                p++;
            }
            if (*p == '\0') {
                break;
            }
        }
    }
    argvlist = (char **) malloc ((unsigned) (size * sizeof (char *)));
    *argvPtr = argvlist;

    /*
     * Parse the Windows command line string.  If an argument begins with a
     * double quote, then spaces are considered part of the argument until the
     * next double quote.  The argument terminates at the second quote.  Note
     * that this is different from the usual Unix semantics.
     */
    for (i = 0, p = args; *p != '\0'; i++) {
        while (isspace (*p)) {
            p++;
        }
        if (*p == '\0') {
            break;
        }
        if (*p == '"') {
            p++;
            (*argvPtr) [i] = p;
            while ((*p != '\0') && (*p != '"')) {
                p++;
            }
        } else {
            (*argvPtr) [i] = p;
            while (*p != '\0' && !isspace(*p)) {
                p++;
            }
        }
        if (*p != '\0') {
            *p = '\0';
            p++;
        }
    }
    (*argvPtr) [i] = NULL;
    *argcPtr = i;
}

/*
 * Concatenate a bunch of files.
 */
int
main (int    argc,
      char **argv)
{
    FILE *fh;
    int idx, c;

    TclX_SplitWinCmdLine (&argc, &argv);


    for (idx = 1; idx < argc; idx++) {
        fh = fopen (argv [idx], "r");
        if (fh == NULL) {
            fprintf (stderr, "error opening \"%s\": %s\n",
                     argv [idx], strerror (errno));
            exit (1);
        }
        while ((c = fgetc (fh)) != EOF) {
            if (fputc (c, stdout) == EOF) {
                fprintf (stderr, "error writing stdout: %s\n", 
                         strerror (errno));
                exit (1);
            }
        }
        if (ferror (fh)) {
            fprintf (stderr, "error reading \"%s\": %s\n",
                     argv [idx], strerror (errno));
            exit (1);
        }
        fclose (fh);
    }
    return 0;
}


