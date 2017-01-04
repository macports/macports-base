/*
 * = = == === ===== ======== ============= =====================
 * == pt::rde (critcl) - Data Structures - Generic stack
 */

#ifndef _RDE_DS_STACK_H
#define _RDE_DS_STACK_H 1

#include <util.h> /* Scoping */

/*
 * The stack data structure declared in this file is an array of void*
 * cells, with each cell either directly containing the data, or being
 * a pointer to it.
 *
 * The structure maintains a max-size field, reallocating the array if
 * and only if we go over this size. Each allocation doubles the
 * available room.
 *
 * A pointer to a delete function is maintained, to delete cells which
 * are references to the actual data.
 */

typedef void (*RDE_STACK_CELL_FREE) (void* cell);
typedef struct RDE_STACK_* RDE_STACK;

static const int RDE_STACK_INITIAL_SIZE = 256;

/*
 * Notes
 * - push -- Item allocation is responsibility of caller.
 *           Stack takes ownership of the item.
 * - pop  -- Stack frees allocated item.
 * - trim -- Ditto
 * - top  -- Provides top item, no transfer of ownership.
 * - del  -- Releases stack, cell array, and items, if any.
 * - drop -- Like pop, but doesn't free, assumes that caller
 *           is taking ownership of the pointer.
 */

/* SKIP START */
SCOPE RDE_STACK rde_stack_new  (RDE_STACK_CELL_FREE freeCellProc);
SCOPE void      rde_stack_del  (RDE_STACK s);

SCOPE void*    rde_stack_top  (RDE_STACK s);
SCOPE void     rde_stack_push (RDE_STACK s, void* item);
SCOPE void     rde_stack_pop  (RDE_STACK s, long int n);
SCOPE void     rde_stack_trim (RDE_STACK s, long int n);
SCOPE void     rde_stack_drop (RDE_STACK s, long int n);
SCOPE void     rde_stack_move (RDE_STACK dst, RDE_STACK src);
SCOPE void     rde_stack_get  (RDE_STACK s, long int* cn, void*** cc);
SCOPE long int rde_stack_size (RDE_STACK s);
/* SKIP END */
#endif /* _RDE_DS_STACK_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
