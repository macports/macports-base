/* struct::queue - critcl - layer 1 definitions
 * (c) Queue functions
 */

#include <q.h>
#include <util.h>

/* .................................................. */

Q*
qu_new (void)
{
    Q* q = ALLOC (Q);

    q->at     = 0;
    q->unget  = Tcl_NewListObj (0,NULL);
    q->queue  = Tcl_NewListObj (0,NULL);
    q->append = Tcl_NewListObj (0,NULL);

    Tcl_IncrRefCount (q->unget); 
    Tcl_IncrRefCount (q->queue); 
    Tcl_IncrRefCount (q->append);

    return q;
}

void
qu_delete (Q* q)
{
    /* Delete a queue in toto.
     */

    Tcl_DecrRefCount (q->unget);
    Tcl_DecrRefCount (q->queue);
    Tcl_DecrRefCount (q->append);
    ckfree ((char*) q);
}

/* .................................................. */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
