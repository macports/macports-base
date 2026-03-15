/*
 * Copyright (c) 2017-2024 Andreas Kupries <andreas_kupries@users.sourceforge.net>
 * = = == === ===== ======== ============= =====================
 */

#include <critcl_alloc.h>
#include <string.h>
#include <stdarg.h>

/*
 * = = == === ===== ======== ============= =====================
 */

#ifdef CRITCL_TRACER

/* Tracking the stack of scopes,
 * single-linked list,
 * top to bottom.
 */

typedef struct scope_stack {
    const char*         scope;
    struct scope_stack* down;
} scope_stack;

/*
 * = = == === ===== ======== ============= =====================
 * Tracing state (stack of scopes, associated indentation level)
 *
 * API regexp for trace output:
 *  (header printf* closer)*
 *
 * - closed == 1 :: post (closer)
 * - closed == 0 :: post (header)
 *
 * [1] in (header) && !closed
 *     => starting a new line in the middle of an incomplete line
 *     => force closer
 * [2] in (printf) && closed
 *     => continuing a line which was interrupted by another (see [1])
 *     => force header
 */

#define MSGMAX (1024*1024)

#ifdef CRITCL_TRACE_NOTHREADS

static scope_stack* top   = 0;
static int          level = 0;
static int          closed = 1;
static char         msg [MSGMAX];

#define SETUP
#define TOP    top
#define LEVEL  level
#define CLOSED closed
#define MSG    msg
#define CHAN   stdout

/* Thread end means nothing
 */

void
critcl_trace_thread_end (void) {}

#else

typedef struct ThreadSpecificData {
    scope_stack* top;
    int          level;
    int          closed;
    char         msg [MSGMAX];
    FILE*        chan;
} ThreadSpecificData;

/* copied from tclInt.h */
#define TCL_TSD_INIT(keyPtr) \
    (ThreadSpecificData *)Tcl_GetThreadData((keyPtr), sizeof(ThreadSpecificData)) /* OK tcl9 */

static Tcl_ThreadDataKey ctraceDataKey;

#define TOP    tsdPtr->top
#define LEVEL  tsdPtr->level
#define CLOSED tsdPtr->closed
#define MSG    tsdPtr->msg
#define CHAN   chan()
#define SETUP  ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&ctraceDataKey)

// Very lazy channel initialization - First actual write
static FILE* chan (void) {
    SETUP;
    if (!tsdPtr->chan) {
	sprintf (MSG, "%p.trace", Tcl_GetCurrentThread());
	tsdPtr->chan = fopen (MSG, "a");
	if (!tsdPtr->chan) {
	    Tcl_Panic ("out of files to open: %s", MSG);
	}
    }
    return tsdPtr->chan;
}

/* Thread end marker, use it to close the trace file for the ended thread.
 * This is needed to keep the number of open files under control as traced
 * threads are spawned and end. Without it we will run out of file slots
 * over time and break.
 *
 * Example: Benchmarks running a traced command with threads a few thousand
 * times.
 */

void
critcl_trace_thread_end (void)
{
    SETUP;
    if (!tsdPtr->chan) return;
    fclose (tsdPtr->chan);
    tsdPtr->chan = NULL;
    return;
}

#endif

/*
 * = = == === ===== ======== ============= =====================
 * Internals
 */

static void
indent (void)
{
    int i;
    SETUP;
    for (i = 0; i < LEVEL; i++) { fwrite(" ", 1, 1, CHAN); }
    fflush (CHAN);
}

static void
scope (void)
{
    SETUP;
    if (!TOP) return;
    fwrite (TOP->scope, 1, strlen(TOP->scope), CHAN);
    fflush (CHAN);
}

static void
separator (void)
{
    SETUP;
    fwrite(" | ", 1, 3, CHAN);
    fflush             (CHAN);
}

/*
 * = = == === ===== ======== ============= =====================
 * API
 */

void
critcl_trace_push (const char* scope)
{
    SETUP;
    scope_stack* new = ALLOC (scope_stack);
    new->scope = scope;
    new->down  = TOP;
    TOP        = new;
    LEVEL     += 4;
}

void
critcl_trace_pop (void)
{
    SETUP;
    scope_stack* next = TOP->down;
    LEVEL -= 4;
    ckfree ((char*) TOP);
    TOP = next;
}

void
critcl_trace_closer (int on)
{
    if (!on) return;
    SETUP;
    fwrite ("\n", 1, 1, CHAN);
    fflush (CHAN);
    CLOSED = 1;
}

void
critcl_trace_header (int on, int ind, const char* filename, int line)
{
    if (!on) return;
    SETUP;
    if (!CLOSED) critcl_trace_closer (1);
    // location prefix
#if 0 /* varying path length breaks indenting by call level :( */
    if (filename) {
	fprintf (CHAN, "%s:%6d", filename, line);
	fflush  (CHAN);
    }
#endif
    // indentation, scope, separator
    if (ind) { indent (); }
    scope ();
    separator();
    CLOSED = 0;
}

void
critcl_trace_printf (int on, const char *format, ...)
{
    /*
     * 1MB output-buffer. We may trace large data structures. This is also a
     * reason why the implementation can be compiled out entirely.
     */
    int len;
    va_list args;
    if (!on) return;
    SETUP;
    if (CLOSED) critcl_trace_header (1, 1, 0, 0);

    va_start (args, format);
    len = vsnprintf (MSG, MSGMAX, format, args);
    va_end (args);
    fwrite (MSG, 1, len, CHAN);
    fflush              (CHAN);
}

void
critcl_trace_cmd_args (const char* scopename, int argc, Tcl_Obj*const* argv)
{
    int i;
    critcl_trace_push (scopename);
    for (i=0; i < argc; i++) {
	// No location information
	indent();
	scope();
	separator();
	critcl_trace_printf (1, "ARG [%3d] = %p (^%d:%s) '%s'\n",
			     i, argv[i], argv[i]->refCount,
			     argv[i]->typePtr ? argv[i]->typePtr->name : "<unknown>",
			     Tcl_GetString((Tcl_Obj*) argv[i]));
    }
}

int
critcl_trace_cmd_result (int status, Tcl_Interp* ip)
{
    Tcl_Obj*    robj = Tcl_GetObjResult (ip);
    const char* rstr = Tcl_GetString (robj);
    const char* rstate;
    const char* rtype;
    static const char* state_str[] = {
	/* 0 */ "OK",
	/* 1 */ "ERROR",
	/* 2 */ "RETURN",
	/* 3 */ "BREAK",
	/* 4 */ "CONTINUE",
    };
    char buf [TCL_INTEGER_SPACE];
    if (status <= TCL_CONTINUE) {
	rstate = state_str [status];
    } else {
	sprintf (buf, "%d", status);
	rstate = (const char*) buf;
    }
    if (robj->typePtr) {
	rtype = robj->typePtr->name;
    } else {
	rtype = "<unknown>";
    }

    // No location information
    indent();
    scope();
    separator();
    critcl_trace_printf (1, "RESULT = %s %p (^%d:%s) '%s'\n",
			 rstate, robj, robj->refCount, rtype, rstr);
    critcl_trace_pop ();
    return status;
}

#endif /*  CRITCL_TRACER */
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
