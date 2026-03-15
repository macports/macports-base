#ifndef __CRITCL_UTIL_TRACE_H
#define __CRITCL_UTIL_TRACE_H 1

/*
 * Copyright (c) 2017-2024 Andreas Kupries <andreas_kupries@users.sourceforge.net>
 *
 * Narrative tracing support, controlled by CRITCL_TRACER
 * = = == === ===== ======== ============= =====================
 *
 * Further control of the active logical sub-streams is done via the
 * declarators
 * - TRACE_ON
 * - TRACE_OFF
 * - TRACE_TAG_ON
 * - TRACE_TAG_OFF
 *
 * The macros make use of the standard macros __FILE__ and __LINE__
 * to identify traced locations (physically).
 *
 * ATTENTION: The trace facility assumes a C99 compiler to have
 *            access to the __func__ string which holds the name
 *            of the current function.
 *
 * NOTE: define CRITCL_TRACE_NOTHREADS if the tracer is run on a single-threaded
 *       process for sure. Else leave it at the new default of multi-threaded
 *       operation.
 *
 *       In this mode it generates one `.trace` file per thread with active tracing.
 *	 In single-threaded mode it writes to stdout as before.
 *
 * NOTE 2: The above can be done through the `critcl::tracer-config` command, i.e.
 *         invoke:
 *             critcl::tracer-config -nothreads
 */

#include <tcl.h>

/*
 * Main (convenience) commands:
 *
 * - TRACE_FUNC        :: Function entry, formatted parameters
 * - TRACE_FUNC_VOID   :: Function entry, no parameters
 * - TRACE_RETURN      :: Function exit, formatted result
 * - TRACE_RETURN_VOID :: Function exit, no result
 * - TRACE             :: Additional trace line.
 *
 * The above commands are composed from the lower level commands below.
 *
 * Scoping
 * - TRACE_PUSH_SCOPE :: Start a named scope, no output
 * - TRACE_PUSH_FUNC  :: Start a scope, named by the current function, no output
 * - TRACE_POP        :: End a scope, no output

 * Tracing
 * - TRACE_HEADER  :: Start of trace line (location, indentation, scope)
 * - TRACE_ADD     :: Extend trace line, formatted information
 * - TRACE_CLOSER  :: End of trace line
 *
 * All of the tracing command also come in TRACE_TAG_ forms which take an
 * additional 1st argument, the tag of the stream. The scoping commands do not
 * take tags. They manage indentation without generating output on their own.
 */

#ifndef CRITCL_TRACER
/* Tracing is disabled. All macros vanish / devolve to their untraced functionality.
 */

#define TRACE_THREAD_EXIT TCL_THREAD_CREATE_RETURN
#define TRACE_PUSH_SCOPE(string)
#define TRACE_PUSH_FUNC
#define TRACE_POP
#define TRACE_ON
#define TRACE_OFF
#define TRACE_HEADER(indent)
#define TRACE_ADD(format, ...)
#define TRACE_CLOSER
#define TRACE_TAG_ON(tag)
#define TRACE_TAG_OFF(tag)
#define TRACE_TAG_HEADER(tag,indent)
#define TRACE_TAG_ADD(tag, format, ...)
#define TRACE_TAG_CLOSER(tag)
#define TRACE_FUNC(format, ...)
#define TRACE_FUNC_VOID
#define TRACE_RETURN(format,x) return (x);
#define TRACE_RETURN_VOID      return;
#define TRACE(format, ...)
#define TRACE_TAG_FUNC(tag, format, ...)
#define TRACE_TAG_FUNC_VOID(tag)
#define TRACE_TAG_RETURN(tag, format, x) return (x);
#define TRACE_TAG_RETURN_VOID(tag)       return;
#define TRACE_TAG(tag, format, ...)
#define TRACE_RUN(code)
#define TRACE_DO(code)
#define TRACE_TAG_DO(tag, code)
#define TRACE_TAG_VAR(tag) 0
#endif

#ifdef CRITCL_TRACER
/* Tracing is active. All macros are properly defined.
 */
#define TRACE_THREAD_EXIT TRACE ("THREAD EXIT %s", "(void)") ; TRACE_POP ; critcl_trace_thread_end() ; TCL_THREAD_CREATE_RETURN

#define TRACE_PUSH_SCOPE(string) critcl_trace_push (string)
#define TRACE_PUSH_FUNC          TRACE_PUSH_SCOPE (__func__)
#define TRACE_POP                critcl_trace_pop()

#define TRACE_ON  TRACE_TAG_ON  (THIS_FILE)
#define TRACE_OFF TRACE_TAG_OFF (THIS_FILE)

#define TRACE_HEADER(indent)   TRACE_TAG_HEADER (THIS_FILE, indent)
#define TRACE_ADD(format, ...) TRACE_TAG_ADD    (THIS_FILE, format, __VA_ARGS__)
#define TRACE_CLOSER           TRACE_TAG_CLOSER (THIS_FILE)

#define TRACE_TAG_ON(tag)  static int TRACE_TAG_VAR (tag) = 1
#define TRACE_TAG_OFF(tag) static int TRACE_TAG_VAR (tag) = 0
#define TRACE_TAG_VAR(tag) __critcl_tag_ ## tag ## _status

#define TRACE_TAG_HEADER(tag, indent)   critcl_trace_header (TRACE_TAG_VAR (tag), (indent), __FILE__, __LINE__)
#define TRACE_TAG_ADD(tag, format, ...) critcl_trace_printf (TRACE_TAG_VAR (tag), format, __VA_ARGS__)
#define TRACE_TAG_CLOSER(tag)           critcl_trace_closer (TRACE_TAG_VAR (tag))

/*
 * Highlevel (convenience) tracing support.
 */

#define TRACE_FUNC(format, ...) TRACE_TAG_FUNC        (THIS_FILE, format, __VA_ARGS__)
#define TRACE_FUNC_VOID         TRACE_TAG_FUNC_VOID   (THIS_FILE)
#define TRACE_RETURN(format,x)  TRACE_TAG_RETURN      (THIS_FILE, format, x)
#define TRACE_RETURN_VOID       TRACE_TAG_RETURN_VOID (THIS_FILE)
#define TRACE(format, ...)      TRACE_TAG             (THIS_FILE, format, __VA_ARGS__)

#define TRACE_TAG_FUNC(tag, format, ...) TRACE_PUSH_FUNC; TRACE_TAG_HEADER (tag,1); TRACE_TAG_ADD (tag, format, __VA_ARGS__); TRACE_TAG_CLOSER (tag)
#define TRACE_TAG_FUNC_VOID(tag)         TRACE_PUSH_FUNC; TRACE_TAG_HEADER (tag,1); TRACE_TAG_ADD (tag, "(%s)", "void"); TRACE_TAG_CLOSER (tag)
#define TRACE_TAG_RETURN(tag, format, x) TRACE_TAG_HEADER (tag,1); TRACE_TAG_ADD (tag, "%s", "RETURN = ") ; TRACE_TAG_ADD (tag, format, x) ; TRACE_TAG_CLOSER (tag) ; TRACE_POP ; return (x)
#define TRACE_TAG_RETURN_VOID(tag)       TRACE_TAG_HEADER (tag,1); TRACE_TAG_ADD (tag, "RETURN %s", "(void)") ; TRACE_TAG_CLOSER (tag) ; TRACE_POP ; return
#define TRACE_TAG(tag, format, ...)      TRACE_TAG_HEADER (tag,1); TRACE_TAG_ADD (tag, format, __VA_ARGS__) ; TRACE_TAG_CLOSER (tag)

#define TRACE_RUN(code)         code
#define TRACE_DO(code)          TRACE_TAG_DO (THIS_FILE, code)
#define TRACE_TAG_DO(tag, code) if (TRACE_TAG_VAR (tag)) { code ; }

/*
 * Declarations for the support functions used in the macros.
 */

extern void critcl_trace_push       (const char* scope);
extern void critcl_trace_pop        (void);
extern void critcl_trace_header     (int on, int indent, const char *filename, int line);
extern void critcl_trace_printf     (int on, const char *pat, ...);
extern void critcl_trace_closer     (int on);
extern void critcl_trace_thread_end (void);

/*
 * Declarations for the support functions used by the
 * implementation of "critcl::cproc".
 */

extern void critcl_trace_cmd_args   (const char* scope, int oc, Tcl_Obj*const* ov);
extern int  critcl_trace_cmd_result (int status, Tcl_Interp* ip);

#endif
#endif /* __CRITCL_UTIL_TRACE_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
