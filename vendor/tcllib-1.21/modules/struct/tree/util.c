/* struct::tree - critcl - support - stack/queue of nodes.
 * definitions.
 */

#include "tcl.h"
#include <util.h>

static NL* nlq_newitem (void* n);


/* Initialize queue data structure.
 */

void
nlq_init (NLQ* q)
{
    q->start = q->end = NULL;
}

/* Add item to end of the list
 */

void
nlq_append (NLQ* q, void* n)
{
    NL* qi = nlq_newitem (n);

    if (!q->end) {
	q->start = q->end = qi;
    } else {
	q->end->next = qi;
	q->end = qi;
    }
}

/* Add item to the front of the list
 */

void
nlq_push (NLQ* q, void* n)
{
    NL* qi = nlq_newitem (n);

    if (!q->end) {
	q->start = q->end = qi;
    } else {
	qi->next = q->start;
	q->start = qi;
    }
}

/* Return item at front of the list.
 */

void*
nlq_pop (NLQ* q)
{
    NL*	  qi = NULL;
    void* n  = NULL;

    if (!q->start) {
	return NULL;
    }

    qi = q->start;
    n  = qi->n;

    q->start = qi->next;
    if (q->end == qi) {
	q->end = NULL;
    }

    ckfree ((char*) qi);
    return n;
}

/* Delete all items in the list.
 */

void*
nlq_clear (NLQ* q)
{
    NL* next;
    NL* qi = q->start;

    while (qi) {
	next = qi->next;
	ckfree ((char*) qi);
	qi = next;
    }
    q->start = NULL;
    q->end   = NULL;
}

/* INTERNAL - Create new item to put into the list.
 */

static NL*
nlq_newitem (void* n)
{
    NL* qi = (NL*) ckalloc (sizeof (NL));

    qi->n    = n;
    qi->next = NULL;

    return qi;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
