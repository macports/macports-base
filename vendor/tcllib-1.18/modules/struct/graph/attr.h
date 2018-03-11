/* struct::graph - critcl - layer 1 declarations
 * (c) Graph functions
 */

#ifndef _G_ATTR_H
#define _G_ATTR_H 1
/* .................................................. */

#include "tcl.h"
#include <ds.h>

/* .................................................. */

void     g_attr_dup      (Tcl_HashTable** Astar, Tcl_HashTable* src);
void     g_attr_extend   (Tcl_HashTable** Astar);
void     g_attr_delete   (Tcl_HashTable** Astar);
void     g_attr_keys     (Tcl_HashTable* attr, Tcl_Interp* interp,
			  int pc, Tcl_Obj* const* pv);
void     g_attr_kexists  (Tcl_HashTable* attr, Tcl_Interp* interp,
			  Tcl_Obj* key);
void     g_attr_set      (Tcl_HashTable* attr, Tcl_Interp* interp,
			  Tcl_Obj* key, Tcl_Obj* value);
void     g_attr_append   (Tcl_HashTable* attr, Tcl_Interp* interp,
			  Tcl_Obj* key, Tcl_Obj* value);
void     g_attr_lappend  (Tcl_HashTable* attr, Tcl_Interp* interp,
			  Tcl_Obj* key, Tcl_Obj* value);
int      g_attr_get      (Tcl_HashTable* attr, Tcl_Interp* interp,
			  Tcl_Obj* key, Tcl_Obj* o, const char* sep);
void     g_attr_getall   (Tcl_HashTable* attr, Tcl_Interp* interp,
			  int pc, Tcl_Obj* const* pv);
void     g_attr_unset    (Tcl_HashTable* attr, Tcl_Obj* key);
int      gc_attr         (GCC* gx, int mode, Tcl_Obj* detail,
			  Tcl_Interp* interp, Tcl_Obj* key,
			 GN_GET_GC* gf, G* g);
int      g_attr_serok    (Tcl_Interp* interp,    Tcl_Obj* aserial,
			  const char* what);
Tcl_Obj* g_attr_serial   (Tcl_HashTable*  attr,  Tcl_Obj* empty);
void     g_attr_deserial (Tcl_HashTable** Astar, Tcl_Obj* dict);

/* .................................................. */
#endif /* _G_ATTR_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
