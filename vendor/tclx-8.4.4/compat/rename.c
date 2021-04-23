/* rename.c -- file renaming routine for systems without rename(2)
 *
 * Written by reading the System V Interface Definition, not the code.
 *
 * Totally public domain.  (Author unknown)
 *
 */

int rename(from,to)
register char *from, *to;
{
    (void) unlink(to);
    if (link(from, to) < 0)
	return(-1);

    (void) unlink(from);
    return(0);
}


/* vim: set ts=4 sw=4 sts=4 et : */
