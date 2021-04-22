/*
 * = = == === ===== ======== ============= =====================
 * == pt::rde (critcl) - Data Structures - Generic token cache
 */

#ifndef _RDE_DS_TC_H
#define _RDE_DS_TC_H 1

#include <util.h> /* Scoping */

typedef struct RDE_TC_* RDE_TC;

/* SKIP START */
SCOPE RDE_TC rde_tc_new  (void);
SCOPE void   rde_tc_del  (RDE_TC tc);

SCOPE long int    rde_tc_size   (RDE_TC tc);
SCOPE void        rde_tc_clear  (RDE_TC tc);
SCOPE char*       rde_tc_append (RDE_TC tc, char* ch, long int len);
SCOPE void        rde_tc_get    (RDE_TC tc, int at, char** ch, long int *len);
SCOPE void        rde_tc_get_s  (RDE_TC tc, int at, int last, char** ch, long int *len);
/* SKIP END */
#endif /* _RDE_DS_TC_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
