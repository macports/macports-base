/* struct::set - critcl - layer 0 declarations
 * Tcl_ObjType 'set'.
 */

#ifndef _S_H
#define _S_H 1

#include "tcl.h"
#include "ds.h"

int      s_get (Tcl_Interp* interp, Tcl_Obj* o, SPtr* sStar);
Tcl_Obj* s_new (SPtr s);

Tcl_ObjType* s_stype (void);
Tcl_ObjType* s_ltype (void);

void s_add        (SPtr a, SPtr b, int* newPtr);
void s_add1       (SPtr a, const char* item);
int  s_contains   (SPtr a, const char* item);
SPtr s_difference (SPtr a, SPtr b);
SPtr s_dup        (SPtr a); /* a == NULL allowed */
int  s_empty      (SPtr a);
int  s_equal      (SPtr a, SPtr b);
void s_free       (SPtr a);
SPtr s_intersect  (SPtr a, SPtr b);
int  s_size       (SPtr a);
int  s_subsetof   (SPtr a, SPtr b);
void s_subtract   (SPtr a, SPtr b, int* delPtr);
void s_subtract1  (SPtr a, const char* item);
SPtr s_union      (SPtr a, SPtr b);

#endif /* _S_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
