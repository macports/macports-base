/* struct::tree - critcl - global declarations
 */

#include <global.h>
#include <util.h>

static void release (ClientData cd, Tcl_Interp* interp);

#define KEY "tcllib/struct::graph/critcl"

/* .................................................. */

const char*
gg_new (Tcl_Interp* interp)
{
  Tcl_InterpDeleteProc* proc = release;
  GG* gg = Tcl_GetAssocData (interp, KEY, &proc);

  if (gg == NULL) {
    gg = ALLOC (GG);
    gg->counter = 0;

    Tcl_SetAssocData (interp, KEY, proc, (ClientData) gg);
  }
	    
  gg->counter ++;
  sprintf (gg->buf, "graph%d", gg->counter);
  return gg->buf;
}

/* .................................................. */

static void
release (ClientData cd, Tcl_Interp* interp)
{
  /* ClientData cd <=> GG* gg */
  ckfree((char*) cd);
}

/* .................................................. */


/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
