/*
 * = = == === ===== ======== ============= =====================
 * == pt::rde (critcl) - Data Structures - PARAM architectural state.
 */

#include <string.h>
#include <util.h>  /* Allocation utilities */

/*
 * = = == === ===== ======== ============= =====================
 */

#ifdef RDE_TRACE
typedef struct F_STACK {
    const char*     str;
    struct F_STACK* down;
} F_STACK;

static F_STACK* top   = 0;
static int      level = 0;

static void
push (const char* str)
{
    F_STACK* new = ALLOC (F_STACK);
    new->str = str;
    new->down = top;
    top = new;
    level += 4;
}

static void
pop (void)
{
    F_STACK* next = top->down;
    level -= 4;
    ckfree ((char*)top);
    top = next;
}

static void
indent (void)
{
    int i;
    for (i = 0; i < level; i++) {
	fwrite(" ", 1, 1, stdout);
	fflush           (stdout);
    }

    if (top) {
	fwrite(top->str, 1, strlen(top->str), stdout);
	fflush                               (stdout);
    }

    fwrite(" ", 1, 1, stdout);
    fflush           (stdout);
}

SCOPE void
trace_enter (const char* fun)
{
    push (fun);
    indent();
    fwrite("ENTER\n", 1, 6, stdout);
    fflush                 (stdout);
}

/*
 * We may trace large data structures (AST!)
 */
static char msg [1024*1024];

SCOPE void
trace_return (const char *pat, ...)
{
    int len;
    va_list args;

    indent();
    fwrite("RETURN = ", 1, 9, stdout);
    fflush                   (stdout);

    va_start(args, pat);
    len = vsprintf(msg, pat, args);
    va_end(args);

    msg[len++] = '\n';
    msg[len] = '\0';

    fwrite(msg, 1, len, stdout);
    fflush             (stdout);

    pop();
}

SCOPE void
trace_printf (const char *pat, ...)
{
    int len;
    va_list args;

    indent();

    va_start(args, pat);
    len = vsprintf(msg, pat, args);
    va_end(args);

    msg[len++] = '\n';
    msg[len] = '\0';

    fwrite(msg, 1, len, stdout);
    fflush             (stdout);
}

SCOPE void
trace_printf0 (const char *pat, ...)
{
    int len;
    va_list args;

    va_start(args, pat);
    len = vsprintf(msg, pat, args);
    va_end(args);

    msg[len++] = '\n';
    msg[len] = '\0';

    fwrite(msg, 1, len, stdout);
    fflush             (stdout);
}

#endif

/*
 * = = == === ===== ======== ============= =====================
 */


/*
 * local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
