/*
 * Copyright (c) 2014, Novell Inc.
 *
 * This program is licensed under the BSD license, read LICENSE.BSD
 * for further information
 */

/*
 * cplxdeps.h (internal)
 */

#ifndef LIBSOLV_CPLXDEPS_H
#define LIBSOLV_CPLXDEPS_H

extern int pool_is_complex_dep_rd(Pool *pool, Reldep *rd);

static inline int 
pool_is_complex_dep(Pool *pool, Id dep)
{
  if (ISRELDEP(dep))
    {   
      Reldep *rd = GETRELDEP(pool, dep);
      if (rd->flags >= 8 && pool_is_complex_dep_rd(pool, rd))
        return 1;
    }   
  return 0;
}

extern int pool_normalize_complex_dep(Pool *pool, Id dep, Queue *bq, int flags);

#define CPLXDEPS_TODNF   (1 << 0)
#define CPLXDEPS_EXPAND  (1 << 1)
#define CPLXDEPS_INVERT  (1 << 2)
#define CPLXDEPS_NAME    (1 << 3)
#define CPLXDEPS_DONTFIX (1 << 4)

#endif

