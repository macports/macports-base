/*
 * = = == === ===== ======== ============= =====================
 * == pt::rde (critcl) - Data Structures - Generic stack
 */

#include <stack.h> /* Our public API */
#include <util.h>  /* Allocation macros */

/*
 * = = == === ===== ======== ============= =====================
 */

typedef struct RDE_STACK_ {
    long int            max;   /* Size of the cell array. */
    long int            top;   /* Index of the topmost _unused_ cell in the
				* array === Index of the _next_ cell to use
				* === Size of the stack. */
    RDE_STACK_CELL_FREE freeCellProc; 
    void**              cell;  /* Array of the stack cells. */
} RDE_STACK_;


/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE RDE_STACK
rde_stack_new (RDE_STACK_CELL_FREE freeCellProc)
{
    RDE_STACK s = ALLOC (RDE_STACK_);
    s->cell = NALLOC (RDE_STACK_INITIAL_SIZE, void*);
    s->max  = RDE_STACK_INITIAL_SIZE;
    s->top  = 0;
    s->freeCellProc = freeCellProc;

    return s;
}

SCOPE void
rde_stack_del (RDE_STACK s)
{
    if (s->freeCellProc && s->top) {
	long int i;
	for (i=0; i < s->top; i++) {
	    ASSERT_BOUNDS(i,s->max);
	    s->freeCellProc ( s->cell [i] );
	}
    }

    ckfree ((char*) s->cell);
    ckfree ((char*) s);
}

SCOPE void
rde_stack_push (RDE_STACK s, void* item)
{
    if (s->top >= s->max) {
	long int new  = s->max ? (2 * s->max) : RDE_STACK_INITIAL_SIZE;
	void**   cell = (void**) ckrealloc ((char*) s->cell, new * sizeof(void*));
	ASSERT (cell,"Memory allocation failure for RDE stack");
	s->max  = new;
	s->cell = cell;
    }

    ASSERT_BOUNDS(s->top,s->max);
    s->cell [s->top] = item;
    s->top ++;
}

SCOPE void*
rde_stack_top (RDE_STACK s)
{
    ASSERT_BOUNDS(s->top-1,s->max);
    return s->cell [s->top - 1];
}

SCOPE void
rde_stack_pop (RDE_STACK s, long int n)
{
    ASSERT (n >= 0, "Bad pop count");
    if (n == 0) return;

    if (s->freeCellProc) {
	while (n) {
	    s->top --;
	    ASSERT_BOUNDS(s->top,s->max);
	    s->freeCellProc ( s->cell [s->top] );
	    n --;
	}
    } else {
	s->top -= n;
    }
}

SCOPE void
rde_stack_trim (RDE_STACK s, long int n)
{
    ASSERT (n >= 0, "Bad trimsize");

    if (s->freeCellProc) {
	while (s->top > n) {
	    s->top --;
	    ASSERT_BOUNDS(s->top,s->max);
	    s->freeCellProc ( s->cell [s->top] );
	}
    } else {
	s->top = n;
    }
}

SCOPE void
rde_stack_drop (RDE_STACK s, long int n)
{
    ASSERT (n >= 0, "Bad pop count");
    if (n == 0) return;
    s->top -= n;
}

SCOPE void
rde_stack_move (RDE_STACK dst, RDE_STACK src)
{
    ASSERT (dst->freeCellProc == src->freeCellProc, "Ownership mismatch");

    /*
     * Note: The destination takes ownership of the moved cell, thus there is
     * no need to run free on them.
     */

    while (src->top > 0) {
	src->top --;
	ASSERT_BOUNDS(src->top,src->max);
	rde_stack_push (dst, src->cell [src->top] );
    }
}

SCOPE void
rde_stack_get (RDE_STACK s, long int* cn, void*** cc)
{
    *cn = s->top;
    *cc = s->cell;
}

SCOPE long int
rde_stack_size (RDE_STACK s)
{
    return s->top;
}

/*
 * = = == === ===== ======== ============= =====================
 */


/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
