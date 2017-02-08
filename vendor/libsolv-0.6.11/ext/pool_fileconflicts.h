/*
 * Copyright (c) 2009-2012, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

#ifndef POOL_FILECONFLICTS_H
#define POOL_FILECONFLICTS_H

#include "pool.h"

extern int pool_findfileconflicts(Pool *pool, Queue *pkgs, int cutoff, Queue *conflicts, int flags, void *(*handle_cb)(Pool *, Id, void *) , void *handle_cbdata);

#define FINDFILECONFLICTS_USE_SOLVABLEFILELIST	(1 << 0)
#define FINDFILECONFLICTS_CHECK_DIRALIASING	(1 << 1)
#define FINDFILECONFLICTS_USE_ROOTDIR		(1 << 2)

#endif
