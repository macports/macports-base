/*
 * Data structures and declarations for yacc/bison based json parser.
 * External to .y file for communication and use within the binding layer.
 */

struct context {
  /*
   * General state.
   */

  Tcl_Interp	*I;         /* Tcl interpreter we are in. */
  int		 result;    /* Tcl result of the parse.
			    **
			     * NOTE: A value of TCL_OK (set when
			     * successfully reducing the main rule)
			     * causes the lexer to return <<EOF>> from
			     * then on, preventing parsing beyond a
			     * single json structure.
			     */

  /*
   * Lexer Input.
   */

  const char	*text;      /* Text to parse */
  int		 remaining; /* Number of characters left to parse. */

  /*
   * Lexer -> Parser communication.
   */

  Tcl_Obj	*obj;       /* Tcl value of the last returned token. */
  int has_error;
};

/*
 * Note: The parser function automatically sets the Tcl_Interp (See
 * field "I") result to the parse result, or an error message.
 */

extern void
jsonparse (struct context *);

#if 0
extern int
jsonlex(struct context *);
#endif

extern void
jsonskip (struct context *);

/*
 * Default: Tracing off.
 */
#ifndef JSON_DEBUG
#define JSON_DEBUG 0
#endif

#if JSON_DEBUG
#define TRACE(x) do { printf x ; fflush (stdout); } while (0)
#else
#define TRACE(x)
#endif
