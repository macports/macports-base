/* A Bison parser, made by GNU Bison 2.0.  */

/* Skeleton parser for Yacc-like parsing with Bison,
   Copyright (C) 1984, 1989, 1990, 2000, 2001, 2002, 2003, 2004 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330,
   Boston, MA 02111-1307, USA.  */

/* As a special exception, when this file is copied by Bison into a
   Bison output file, you may use that output file without restriction.
   This special exception was added by the Free Software Foundation
   in version 1.24 of Bison.  */

/* Written by Richard Stallman by simplifying the original so called
   ``semantic'' parser.  */

/* All symbols defined below should begin with yy or YY, to avoid
   infringing on user name space.  This should be done even for local
   variables, as they might otherwise be expanded by user macros.
   There are some unavoidable exceptions within include files to
   define necessary library symbols; they are noted "INFRINGES ON
   USER NAME SPACE" below.  */

/* Identify Bison output.  */
#define YYBISON 1

/* Skeleton name.  */
#define YYSKELETON_NAME "yacc.c"

/* Pure parsers.  */
#define YYPURE 0

/* Using locations.  */
#define YYLSP_NEEDED 0



/* Tokens.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
   /* Put the tokens into the symbol table, so that GDB and other debuggers
      know about them.  */
   enum yytokentype {
     STRING = 258,
     CONSTANT = 259
   };
#endif
#define STRING 258
#define CONSTANT 259




/* Copy the first part of user declarations.  */
#line 6 "json.y"

#include <tcl.h>
#include <ctype.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

#include <json_y.h>

#define TOKEN(tok)   TRACE (("TOKEN  %s\n", tok))
#define TOKEN1(tok)  TRACE (("TOKEN  %s (%s)\n", tok, Tcl_GetString(context->obj)))
#define REDUCE(rule) TRACE (("REDUCE %s\n", rule))

#define TRUE_O  (Tcl_NewStringObj("true", 4))
#define FALSE_O (Tcl_NewStringObj("false", 5))
#define NULL_O  (Tcl_NewStringObj("null", 4))

static void jsonerror(struct context *, const char *);
static int  jsonlexp(struct context *context);

#define YYPARSE_PARAM_TYPE void *
#define YYPARSE_PARAM	   context
#define YYPARSE_PARAM_DECL

#define yylex()	     jsonlexp(context)
#define yyerror(msg) jsonerror(context, msg)

#ifndef YYBISON
static int yyparse(YYPARSE_PARAM_TYPE YYPARSE_PARAM);
#endif



/* Enabling traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif

/* Enabling verbose error messages.  */
#ifdef YYERROR_VERBOSE
# undef YYERROR_VERBOSE
# define YYERROR_VERBOSE 1
#else
# define YYERROR_VERBOSE 0
#endif

#if ! defined (YYSTYPE) && ! defined (YYSTYPE_IS_DECLARED)
#line 40 "json.y"
typedef union YYSTYPE {
	Tcl_Obj		*obj;
	struct {
		Tcl_Obj	*key;
		Tcl_Obj	*val;
	} keyval;
} YYSTYPE;
/* Line 190 of yacc.c.  */
#line 126 "json.tab.c"
# define yystype YYSTYPE /* obsolescent; will be withdrawn */
# define YYSTYPE_IS_DECLARED 1
# define YYSTYPE_IS_TRIVIAL 1
#endif



/* Copy the second part of user declarations.  */


/* Line 213 of yacc.c.  */
#line 138 "json.tab.c"

#if ! defined (yyoverflow) || YYERROR_VERBOSE

# ifndef YYFREE
#  define YYFREE free
# endif
# ifndef YYMALLOC
#  define YYMALLOC malloc
# endif

/* The parser invokes alloca or malloc; define the necessary symbols.  */

# ifdef YYSTACK_USE_ALLOCA
#  if YYSTACK_USE_ALLOCA
#   ifdef __GNUC__
#    define YYSTACK_ALLOC __builtin_alloca
#   else
#    define YYSTACK_ALLOC alloca
#   endif
#  endif
# endif

# ifdef YYSTACK_ALLOC
   /* Pacify GCC's `empty if-body' warning. */
#  define YYSTACK_FREE(Ptr) do { /* empty */; } while (0)
# else
#  if defined (__STDC__) || defined (__cplusplus)
#   include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
#   define YYSIZE_T size_t
#  endif
#  define YYSTACK_ALLOC YYMALLOC
#  define YYSTACK_FREE YYFREE
# endif
#endif /* ! defined (yyoverflow) || YYERROR_VERBOSE */


#if (! defined (yyoverflow) \
     && (! defined (__cplusplus) \
	 || (defined (YYSTYPE_IS_TRIVIAL) && YYSTYPE_IS_TRIVIAL)))

/* A type that is properly aligned for any stack member.  */
union yyalloc
{
  short int yyss;
  YYSTYPE yyvs;
  };

/* The size of the maximum gap between one aligned stack and the next.  */
# define YYSTACK_GAP_MAXIMUM (sizeof (union yyalloc) - 1)

/* The size of an array large to enough to hold all stacks, each with
   N elements.  */
# define YYSTACK_BYTES(N) \
     ((N) * (sizeof (short int) + sizeof (YYSTYPE))			\
      + YYSTACK_GAP_MAXIMUM)

/* Copy COUNT objects from FROM to TO.  The source and destination do
   not overlap.  */
# ifndef YYCOPY
#  if defined (__GNUC__) && 1 < __GNUC__
#   define YYCOPY(To, From, Count) \
      __builtin_memcpy (To, From, (Count) * sizeof (*(From)))
#  else
#   define YYCOPY(To, From, Count)		\
      do					\
	{					\
	  register YYSIZE_T yyi;		\
	  for (yyi = 0; yyi < (Count); yyi++)	\
	    (To)[yyi] = (From)[yyi];		\
	}					\
      while (0)
#  endif
# endif

/* Relocate STACK from its old location to the new one.  The
   local variables YYSIZE and YYSTACKSIZE give the old and new number of
   elements in the stack, and YYPTR gives the new location of the
   stack.  Advance YYPTR to a properly aligned location for the next
   stack.  */
# define YYSTACK_RELOCATE(Stack)					\
    do									\
      {									\
	YYSIZE_T yynewbytes;						\
	YYCOPY (&yyptr->Stack, Stack, yysize);				\
	Stack = &yyptr->Stack;						\
	yynewbytes = yystacksize * sizeof (*Stack) + YYSTACK_GAP_MAXIMUM; \
	yyptr += yynewbytes / sizeof (*yyptr);				\
      }									\
    while (0)

#endif

#if defined (__STDC__) || defined (__cplusplus)
   typedef signed char yysigned_char;
#else
   typedef short int yysigned_char;
#endif

/* YYFINAL -- State number of the termination state. */
#define YYFINAL  18
/* YYLAST -- Last index in YYTABLE.  */
#define YYLAST   23

/* YYNTOKENS -- Number of terminals. */
#define YYNTOKENS  11
/* YYNNTS -- Number of nonterminals. */
#define YYNNTS  10
/* YYNRULES -- Number of rules. */
#define YYNRULES  17
/* YYNRULES -- Number of states. */
#define YYNSTATES  27

/* YYTRANSLATE(YYLEX) -- Bison symbol number corresponding to YYLEX.  */
#define YYUNDEFTOK  2
#define YYMAXUTOK   259

#define YYTRANSLATE(YYX) 						\
  ((unsigned int) (YYX) <= YYMAXUTOK ? yytranslate[YYX] : YYUNDEFTOK)

/* YYTRANSLATE[YYLEX] -- Bison symbol number corresponding to YYLEX.  */
static const unsigned char yytranslate[] =
{
       0,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     9,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,    10,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     7,     2,     8,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     5,     2,     6,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     1,     2,     3,     4
};

#if YYDEBUG
/* YYPRHS[YYN] -- Index of the first RHS symbol of rule number YYN in
   YYRHS.  */
static const unsigned char yyprhs[] =
{
       0,     0,     3,     5,     7,    11,    14,    18,    21,    23,
      27,    29,    33,    37,    39,    41,    43,    45
};

/* YYRHS -- A `-1'-separated list of the rules' RHS. */
static const yysigned_char yyrhs[] =
{
      12,     0,    -1,    13,    -1,    20,    -1,     5,    17,     6,
      -1,     5,     6,    -1,     7,    16,     8,    -1,     7,     8,
      -1,    20,    -1,    16,     9,    20,    -1,    18,    -1,    17,
       9,    18,    -1,    19,    10,    20,    -1,     3,    -1,     4,
      -1,    19,    -1,    14,    -1,    15,    -1
};

/* YYRLINE[YYN] -- source line where rule number YYN was defined.  */
static const unsigned char yyrline[] =
{
       0,    62,    62,    74,    77,    81,    87,    91,    97,   101,
     108,   114,   122,   129,   135,   139,   140,   141
};
#endif

#if YYDEBUG || YYERROR_VERBOSE
/* YYTNME[SYMBOL-NUM] -- String name of the symbol SYMBOL-NUM.
   First, the terminals, then, starting at YYNTOKENS, nonterminals. */
static const char *const yytname[] =
{
  "$end", "error", "$undefined", "STRING", "CONSTANT", "'{'", "'}'",
  "'['", "']'", "','", "':'", "$accept", "tree", "json", "object", "list",
  "values", "members", "member", "string", "value", 0
};
#endif

# ifdef YYPRINT
/* YYTOKNUM[YYLEX-NUM] -- Internal token number corresponding to
   token YYLEX-NUM.  */
static const unsigned short int yytoknum[] =
{
       0,   256,   257,   258,   259,   123,   125,    91,    93,    44,
      58
};
# endif

/* YYR1[YYN] -- Symbol number of symbol that rule YYN derives.  */
static const unsigned char yyr1[] =
{
       0,    11,    12,    13,    14,    14,    15,    15,    16,    16,
      17,    17,    18,    19,    20,    20,    20,    20
};

/* YYR2[YYN] -- Number of symbols composing right hand side of rule YYN.  */
static const unsigned char yyr2[] =
{
       0,     2,     1,     1,     3,     2,     3,     2,     1,     3,
       1,     3,     3,     1,     1,     1,     1,     1
};

/* YYDEFACT[STATE-NAME] -- Default rule to reduce with in state
   STATE-NUM when YYTABLE doesn't specify something else to do.  Zero
   means the default is an error.  */
static const unsigned char yydefact[] =
{
       0,    13,    14,     0,     0,     0,     2,    16,    17,    15,
       3,     5,     0,    10,     0,     7,     0,     8,     1,     4,
       0,     0,     6,     0,    11,    12,     9
};

/* YYDEFGOTO[NTERM-NUM]. */
static const yysigned_char yydefgoto[] =
{
      -1,     5,     6,     7,     8,    16,    12,    13,     9,    10
};

/* YYPACT[STATE-NUM] -- Index in YYTABLE of the portion describing
   STATE-NUM.  */
#define YYPACT_NINF -6
static const yysigned_char yypact[] =
{
       5,    -6,    -6,     8,    -1,    15,    -6,    -6,    -6,    -6,
      -6,    -6,     7,    -6,    -5,    -6,    12,    -6,    -6,    -6,
      19,     5,    -6,     5,    -6,    -6,    -6
};

/* YYPGOTO[NTERM-NUM].  */
static const yysigned_char yypgoto[] =
{
      -6,    -6,    -6,    -6,    -6,    -6,    -6,     3,    -2,    -4
};

/* YYTABLE[YYPACT[STATE-NUM]].  What to do in state STATE-NUM.  If
   positive, shift that token.  If negative, reduce the rule which
   number is the opposite.  If zero, do what YYDEFACT says.
   If YYTABLE_NINF, syntax error.  */
#define YYTABLE_NINF -1
static const unsigned char yytable[] =
{
      17,    14,     1,     2,     3,    21,     4,    15,     1,     2,
       3,     1,     4,    19,    11,    18,    20,    25,    14,    26,
      22,    23,     1,    24
};

static const unsigned char yycheck[] =
{
       4,     3,     3,     4,     5,    10,     7,     8,     3,     4,
       5,     3,     7,     6,     6,     0,     9,    21,    20,    23,
       8,     9,     3,    20
};

/* YYSTOS[STATE-NUM] -- The (internal number of the) accessing
   symbol of state STATE-NUM.  */
static const unsigned char yystos[] =
{
       0,     3,     4,     5,     7,    12,    13,    14,    15,    19,
      20,     6,    17,    18,    19,     8,    16,    20,     0,     6,
       9,    10,     8,     9,    18,    20,    20
};

#if ! defined (YYSIZE_T) && defined (__SIZE_TYPE__)
# define YYSIZE_T __SIZE_TYPE__
#endif
#if ! defined (YYSIZE_T) && defined (size_t)
# define YYSIZE_T size_t
#endif
#if ! defined (YYSIZE_T)
# if defined (__STDC__) || defined (__cplusplus)
#  include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  define YYSIZE_T size_t
# endif
#endif
#if ! defined (YYSIZE_T)
# define YYSIZE_T unsigned int
#endif

#define yyerrok		(yyerrstatus = 0)
#define yyclearin	(yychar = YYEMPTY)
#define YYEMPTY		(-2)
#define YYEOF		0

#define YYACCEPT	goto yyacceptlab
#define YYABORT		goto yyabortlab
#define YYERROR		goto yyerrorlab


/* Like YYERROR except do call yyerror.  This remains here temporarily
   to ease the transition to the new meaning of YYERROR, for GCC.
   Once GCC version 2 has supplanted version 1, this can go.  */

#define YYFAIL		goto yyerrlab

#define YYRECOVERING()  (!!yyerrstatus)

#define YYBACKUP(Token, Value)					\
do								\
  if (yychar == YYEMPTY && yylen == 1)				\
    {								\
      yychar = (Token);						\
      yylval = (Value);						\
      yytoken = YYTRANSLATE (yychar);				\
      YYPOPSTACK;						\
      goto yybackup;						\
    }								\
  else								\
    { 								\
      yyerror ("syntax error: cannot back up");\
      YYERROR;							\
    }								\
while (0)


#define YYTERROR	1
#define YYERRCODE	256


/* YYLLOC_DEFAULT -- Set CURRENT to span from RHS[1] to RHS[N].
   If N is 0, then set CURRENT to the empty location which ends
   the previous symbol: RHS[0] (always defined).  */

#define YYRHSLOC(Rhs, K) ((Rhs)[K])
#ifndef YYLLOC_DEFAULT
# define YYLLOC_DEFAULT(Current, Rhs, N)				\
    do									\
      if (N)								\
	{								\
	  (Current).first_line   = YYRHSLOC (Rhs, 1).first_line;	\
	  (Current).first_column = YYRHSLOC (Rhs, 1).first_column;	\
	  (Current).last_line    = YYRHSLOC (Rhs, N).last_line;		\
	  (Current).last_column  = YYRHSLOC (Rhs, N).last_column;	\
	}								\
      else								\
	{								\
	  (Current).first_line   = (Current).last_line   =		\
	    YYRHSLOC (Rhs, 0).last_line;				\
	  (Current).first_column = (Current).last_column =		\
	    YYRHSLOC (Rhs, 0).last_column;				\
	}								\
    while (0)
#endif


/* YY_LOCATION_PRINT -- Print the location on the stream.
   This macro was not mandated originally: define only if we know
   we won't break user code: when these are the locations we know.  */

#ifndef YY_LOCATION_PRINT
# if YYLTYPE_IS_TRIVIAL
#  define YY_LOCATION_PRINT(File, Loc)			\
     fprintf (File, "%d.%d-%d.%d",			\
              (Loc).first_line, (Loc).first_column,	\
              (Loc).last_line,  (Loc).last_column)
# else
#  define YY_LOCATION_PRINT(File, Loc) ((void) 0)
# endif
#endif


/* YYLEX -- calling `yylex' with the right arguments.  */

#ifdef YYLEX_PARAM
# define YYLEX yylex (YYLEX_PARAM)
#else
# define YYLEX yylex ()
#endif

/* Enable debugging if requested.  */
#if YYDEBUG

# ifndef YYFPRINTF
#  include <stdio.h> /* INFRINGES ON USER NAME SPACE */
#  define YYFPRINTF fprintf
# endif

# define YYDPRINTF(Args)			\
do {						\
  if (yydebug)					\
    YYFPRINTF Args;				\
} while (0)

# define YY_SYMBOL_PRINT(Title, Type, Value, Location)		\
do {								\
  if (yydebug)							\
    {								\
      YYFPRINTF (stderr, "%s ", Title);				\
      yysymprint (stderr, 					\
                  Type, Value);	\
      YYFPRINTF (stderr, "\n");					\
    }								\
} while (0)

/*------------------------------------------------------------------.
| yy_stack_print -- Print the state stack from its BOTTOM up to its |
| TOP (included).                                                   |
`------------------------------------------------------------------*/

#if defined (__STDC__) || defined (__cplusplus)
static void
yy_stack_print (short int *bottom, short int *top)
#else
static void
yy_stack_print (bottom, top)
    short int *bottom;
    short int *top;
#endif
{
  YYFPRINTF (stderr, "Stack now");
  for (/* Nothing. */; bottom <= top; ++bottom)
    YYFPRINTF (stderr, " %d", *bottom);
  YYFPRINTF (stderr, "\n");
}

# define YY_STACK_PRINT(Bottom, Top)				\
do {								\
  if (yydebug)							\
    yy_stack_print ((Bottom), (Top));				\
} while (0)


/*------------------------------------------------.
| Report that the YYRULE is going to be reduced.  |
`------------------------------------------------*/

#if defined (__STDC__) || defined (__cplusplus)
static void
yy_reduce_print (int yyrule)
#else
static void
yy_reduce_print (yyrule)
    int yyrule;
#endif
{
  int yyi;
  unsigned int yylno = yyrline[yyrule];
  YYFPRINTF (stderr, "Reducing stack by rule %d (line %u), ",
             yyrule - 1, yylno);
  /* Print the symbols being reduced, and their result.  */
  for (yyi = yyprhs[yyrule]; 0 <= yyrhs[yyi]; yyi++)
    YYFPRINTF (stderr, "%s ", yytname [yyrhs[yyi]]);
  YYFPRINTF (stderr, "-> %s\n", yytname [yyr1[yyrule]]);
}

# define YY_REDUCE_PRINT(Rule)		\
do {					\
  if (yydebug)				\
    yy_reduce_print (Rule);		\
} while (0)

/* Nonzero means print parse trace.  It is left uninitialized so that
   multiple parsers can coexist.  */
int yydebug;
#else /* !YYDEBUG */
# define YYDPRINTF(Args)
# define YY_SYMBOL_PRINT(Title, Type, Value, Location)
# define YY_STACK_PRINT(Bottom, Top)
# define YY_REDUCE_PRINT(Rule)
#endif /* !YYDEBUG */


/* YYINITDEPTH -- initial size of the parser's stacks.  */
#ifndef	YYINITDEPTH
# define YYINITDEPTH 200
#endif

/* YYMAXDEPTH -- maximum size the stacks can grow to (effective only
   if the built-in stack extension method is used).

   Do not make this value too large; the results are undefined if
   SIZE_MAX < YYSTACK_BYTES (YYMAXDEPTH)
   evaluated with infinite-precision integer arithmetic.  */

#ifndef YYMAXDEPTH
# define YYMAXDEPTH 10000
#endif



#if YYERROR_VERBOSE

# ifndef yystrlen
#  if defined (__GLIBC__) && defined (_STRING_H)
#   define yystrlen strlen
#  else
/* Return the length of YYSTR.  */
static YYSIZE_T
#   if defined (__STDC__) || defined (__cplusplus)
yystrlen (const char *yystr)
#   else
yystrlen (yystr)
     const char *yystr;
#   endif
{
  register const char *yys = yystr;

  while (*yys++ != '\0')
    continue;

  return yys - yystr - 1;
}
#  endif
# endif

# ifndef yystpcpy
#  if defined (__GLIBC__) && defined (_STRING_H) && defined (_GNU_SOURCE)
#   define yystpcpy stpcpy
#  else
/* Copy YYSRC to YYDEST, returning the address of the terminating '\0' in
   YYDEST.  */
static char *
#   if defined (__STDC__) || defined (__cplusplus)
yystpcpy (char *yydest, const char *yysrc)
#   else
yystpcpy (yydest, yysrc)
     char *yydest;
     const char *yysrc;
#   endif
{
  register char *yyd = yydest;
  register const char *yys = yysrc;

  while ((*yyd++ = *yys++) != '\0')
    continue;

  return yyd - 1;
}
#  endif
# endif

#endif /* !YYERROR_VERBOSE */



#if YYDEBUG
/*--------------------------------.
| Print this symbol on YYOUTPUT.  |
`--------------------------------*/

#if defined (__STDC__) || defined (__cplusplus)
static void
yysymprint (FILE *yyoutput, int yytype, YYSTYPE *yyvaluep)
#else
static void
yysymprint (yyoutput, yytype, yyvaluep)
    FILE *yyoutput;
    int yytype;
    YYSTYPE *yyvaluep;
#endif
{
  /* Pacify ``unused variable'' warnings.  */
  (void) yyvaluep;

  if (yytype < YYNTOKENS)
    YYFPRINTF (yyoutput, "token %s (", yytname[yytype]);
  else
    YYFPRINTF (yyoutput, "nterm %s (", yytname[yytype]);


# ifdef YYPRINT
  if (yytype < YYNTOKENS)
    YYPRINT (yyoutput, yytoknum[yytype], *yyvaluep);
# endif
  switch (yytype)
    {
      default:
        break;
    }
  YYFPRINTF (yyoutput, ")");
}

#endif /* ! YYDEBUG */
/*-----------------------------------------------.
| Release the memory associated to this symbol.  |
`-----------------------------------------------*/

#if defined (__STDC__) || defined (__cplusplus)
static void
yydestruct (const char *yymsg, int yytype, YYSTYPE *yyvaluep)
#else
static void
yydestruct (yymsg, yytype, yyvaluep)
    const char *yymsg;
    int yytype;
    YYSTYPE *yyvaluep;
#endif
{
  /* Pacify ``unused variable'' warnings.  */
  (void) yyvaluep;

  if (!yymsg)
    yymsg = "Deleting";
  YY_SYMBOL_PRINT (yymsg, yytype, yyvaluep, yylocationp);

  switch (yytype)
    {

      default:
        break;
    }
}


/* Prevent warnings from -Wmissing-prototypes.  */

#ifdef YYPARSE_PARAM
# if defined (__STDC__) || defined (__cplusplus)
int yyparse (void *YYPARSE_PARAM);
# else
int yyparse ();
# endif
#else /* ! YYPARSE_PARAM */
#if defined (__STDC__) || defined (__cplusplus)
int yyparse (void);
#else
int yyparse ();
#endif
#endif /* ! YYPARSE_PARAM */



/* The look-ahead symbol.  */
int yychar;

/* The semantic value of the look-ahead symbol.  */
YYSTYPE yylval;

/* Number of syntax errors so far.  */
int yynerrs;



/*----------.
| yyparse.  |
`----------*/

#ifdef YYPARSE_PARAM
# if defined (__STDC__) || defined (__cplusplus)
int yyparse (void *YYPARSE_PARAM)
# else
int yyparse (YYPARSE_PARAM)
  void *YYPARSE_PARAM;
# endif
#else /* ! YYPARSE_PARAM */
#if defined (__STDC__) || defined (__cplusplus)
int
yyparse (void)
#else
int
yyparse ()

#endif
#endif
{
  
  register int yystate;
  register int yyn;
  int yyresult;
  /* Number of tokens to shift before error messages enabled.  */
  int yyerrstatus;
  /* Look-ahead token as an internal (translated) token number.  */
  int yytoken = 0;

  /* Three stacks and their tools:
     `yyss': related to states,
     `yyvs': related to semantic values,
     `yyls': related to locations.

     Refer to the stacks thru separate pointers, to allow yyoverflow
     to reallocate them elsewhere.  */

  /* The state stack.  */
  short int yyssa[YYINITDEPTH];
  short int *yyss = yyssa;
  register short int *yyssp;

  /* The semantic value stack.  */
  YYSTYPE yyvsa[YYINITDEPTH];
  YYSTYPE *yyvs = yyvsa;
  register YYSTYPE *yyvsp;



#define YYPOPSTACK   (yyvsp--, yyssp--)

  YYSIZE_T yystacksize = YYINITDEPTH;

  /* The variables used to return semantic value and location from the
     action routines.  */
  YYSTYPE yyval;


  /* When reducing, the number of symbols on the RHS of the reduced
     rule.  */
  int yylen;

  YYDPRINTF ((stderr, "Starting parse\n"));

  yystate = 0;
  yyerrstatus = 0;
  yynerrs = 0;
  yychar = YYEMPTY;		/* Cause a token to be read.  */

  /* Initialize stack pointers.
     Waste one element of value and location stack
     so that they stay on the same level as the state stack.
     The wasted elements are never initialized.  */

  yyssp = yyss;
  yyvsp = yyvs;


  yyvsp[0] = yylval;

  goto yysetstate;

/*------------------------------------------------------------.
| yynewstate -- Push a new state, which is found in yystate.  |
`------------------------------------------------------------*/
 yynewstate:
  /* In all cases, when you get here, the value and location stacks
     have just been pushed. so pushing a state here evens the stacks.
     */
  yyssp++;

 yysetstate:
  *yyssp = yystate;

  if (yyss + yystacksize - 1 <= yyssp)
    {
      /* Get the current used size of the three stacks, in elements.  */
      YYSIZE_T yysize = yyssp - yyss + 1;

#ifdef yyoverflow
      {
	/* Give user a chance to reallocate the stack. Use copies of
	   these so that the &'s don't force the real ones into
	   memory.  */
	YYSTYPE *yyvs1 = yyvs;
	short int *yyss1 = yyss;


	/* Each stack pointer address is followed by the size of the
	   data in use in that stack, in bytes.  This used to be a
	   conditional around just the two extra args, but that might
	   be undefined if yyoverflow is a macro.  */
	yyoverflow ("parser stack overflow",
		    &yyss1, yysize * sizeof (*yyssp),
		    &yyvs1, yysize * sizeof (*yyvsp),

		    &yystacksize);

	yyss = yyss1;
	yyvs = yyvs1;
      }
#else /* no yyoverflow */
# ifndef YYSTACK_RELOCATE
      goto yyoverflowlab;
# else
      /* Extend the stack our own way.  */
      if (YYMAXDEPTH <= yystacksize)
	goto yyoverflowlab;
      yystacksize *= 2;
      if (YYMAXDEPTH < yystacksize)
	yystacksize = YYMAXDEPTH;

      {
	short int *yyss1 = yyss;
	union yyalloc *yyptr =
	  (union yyalloc *) YYSTACK_ALLOC (YYSTACK_BYTES (yystacksize));
	if (! yyptr)
	  goto yyoverflowlab;
	YYSTACK_RELOCATE (yyss);
	YYSTACK_RELOCATE (yyvs);

#  undef YYSTACK_RELOCATE
	if (yyss1 != yyssa)
	  YYSTACK_FREE (yyss1);
      }
# endif
#endif /* no yyoverflow */

      yyssp = yyss + yysize - 1;
      yyvsp = yyvs + yysize - 1;


      YYDPRINTF ((stderr, "Stack size increased to %lu\n",
		  (unsigned long int) yystacksize));

      if (yyss + yystacksize - 1 <= yyssp)
	YYABORT;
    }

  YYDPRINTF ((stderr, "Entering state %d\n", yystate));

  goto yybackup;

/*-----------.
| yybackup.  |
`-----------*/
yybackup:

/* Do appropriate processing given the current state.  */
/* Read a look-ahead token if we need one and don't already have one.  */
/* yyresume: */

  /* First try to decide what to do without reference to look-ahead token.  */

  yyn = yypact[yystate];
  if (yyn == YYPACT_NINF)
    goto yydefault;

  /* Not known => get a look-ahead token if don't already have one.  */

  /* YYCHAR is either YYEMPTY or YYEOF or a valid look-ahead symbol.  */
  if (yychar == YYEMPTY)
    {
      YYDPRINTF ((stderr, "Reading a token: "));
      yychar = YYLEX;
    }

  if (yychar <= YYEOF)
    {
      yychar = yytoken = YYEOF;
      YYDPRINTF ((stderr, "Now at end of input.\n"));
    }
  else
    {
      yytoken = YYTRANSLATE (yychar);
      YY_SYMBOL_PRINT ("Next token is", yytoken, &yylval, &yylloc);
    }

  /* If the proper action on seeing token YYTOKEN is to reduce or to
     detect an error, take that action.  */
  yyn += yytoken;
  if (yyn < 0 || YYLAST < yyn || yycheck[yyn] != yytoken)
    goto yydefault;
  yyn = yytable[yyn];
  if (yyn <= 0)
    {
      if (yyn == 0 || yyn == YYTABLE_NINF)
	goto yyerrlab;
      yyn = -yyn;
      goto yyreduce;
    }

  if (yyn == YYFINAL)
    YYACCEPT;

  /* Shift the look-ahead token.  */
  YY_SYMBOL_PRINT ("Shifting", yytoken, &yylval, &yylloc);

  /* Discard the token being shifted unless it is eof.  */
  if (yychar != YYEOF)
    yychar = YYEMPTY;

  *++yyvsp = yylval;


  /* Count tokens shifted since error; after three, turn off error
     status.  */
  if (yyerrstatus)
    yyerrstatus--;

  yystate = yyn;
  goto yynewstate;


/*-----------------------------------------------------------.
| yydefault -- do the default action for the current state.  |
`-----------------------------------------------------------*/
yydefault:
  yyn = yydefact[yystate];
  if (yyn == 0)
    goto yyerrlab;
  goto yyreduce;


/*-----------------------------.
| yyreduce -- Do a reduction.  |
`-----------------------------*/
yyreduce:
  /* yyn is the number of a rule to reduce with.  */
  yylen = yyr2[yyn];

  /* If YYLEN is nonzero, implement the default value of the action:
     `$$ = $1'.

     Otherwise, the following line sets YYVAL to garbage.
     This behavior is undocumented and Bison
     users should not rely upon it.  Assigning to YYVAL
     unconditionally makes the parser a bit smaller, and it avoids a
     GCC warning that YYVAL may be used uninitialized.  */
  yyval = yyvsp[1-yylen];


  YY_REDUCE_PRINT (yyn);
  switch (yyn)
    {
        case 2:
#line 63 "json.y"
    {
		struct context *c = context;
		REDUCE("TREE");
		if (c->I) {
		  Tcl_SetObjResult(c->I, (yyvsp[0].obj));
		  TRACE (("  RESULT (%s)\n", Tcl_GetString((yyvsp[0].obj))));
		}
		c->result = TCL_OK;
	;}
    break;

  case 4:
#line 78 "json.y"
    {
		(yyval.obj) = (yyvsp[-1].obj);
	;}
    break;

  case 5:
#line 82 "json.y"
    {
		(yyval.obj) = Tcl_NewObj();
	;}
    break;

  case 6:
#line 88 "json.y"
    {
		(yyval.obj) = (yyvsp[-1].obj);
	;}
    break;

  case 7:
#line 92 "json.y"
    {
		(yyval.obj) = Tcl_NewObj();
	;}
    break;

  case 8:
#line 98 "json.y"
    {	
		(yyval.obj) = Tcl_NewListObj(1, &(yyvsp[0].obj));
	;}
    break;

  case 9:
#line 102 "json.y"
    {
		Tcl_ListObjAppendElement(NULL, (yyvsp[-2].obj), (yyvsp[0].obj));
		(yyval.obj) = (yyvsp[-2].obj);
	;}
    break;

  case 10:
#line 109 "json.y"
    {
	        (yyval.obj) = Tcl_NewListObj(0, NULL);
		Tcl_ListObjAppendElement(NULL, (yyval.obj), (yyvsp[0].keyval).key);
		Tcl_ListObjAppendElement(NULL, (yyval.obj), (yyvsp[0].keyval).val);
	;}
    break;

  case 11:
#line 115 "json.y"
    {
		Tcl_ListObjAppendElement(NULL, (yyvsp[-2].obj), (yyvsp[0].keyval).key);
		Tcl_ListObjAppendElement(NULL, (yyvsp[-2].obj), (yyvsp[0].keyval).val);
		(yyval.obj) = (yyvsp[-2].obj);
	;}
    break;

  case 12:
#line 123 "json.y"
    {
		(yyval.keyval).key = (yyvsp[-2].obj);
		(yyval.keyval).val = (yyvsp[0].obj);
	;}
    break;

  case 13:
#line 130 "json.y"
    {
		(yyval.obj) = ((struct context *)context)->obj;
	;}
    break;

  case 14:
#line 136 "json.y"
    {
		(yyval.obj) = ((struct context *)context)->obj;
	;}
    break;


    }

/* Line 1037 of yacc.c.  */
#line 1148 "json.tab.c"

  yyvsp -= yylen;
  yyssp -= yylen;


  YY_STACK_PRINT (yyss, yyssp);

  *++yyvsp = yyval;


  /* Now `shift' the result of the reduction.  Determine what state
     that goes to, based on the state we popped back to and the rule
     number reduced by.  */

  yyn = yyr1[yyn];

  yystate = yypgoto[yyn - YYNTOKENS] + *yyssp;
  if (0 <= yystate && yystate <= YYLAST && yycheck[yystate] == *yyssp)
    yystate = yytable[yystate];
  else
    yystate = yydefgoto[yyn - YYNTOKENS];

  goto yynewstate;


/*------------------------------------.
| yyerrlab -- here on detecting error |
`------------------------------------*/
yyerrlab:
  /* If not already recovering from an error, report this error.  */
  if (!yyerrstatus)
    {
      ++yynerrs;
#if YYERROR_VERBOSE
      yyn = yypact[yystate];

      if (YYPACT_NINF < yyn && yyn < YYLAST)
	{
	  YYSIZE_T yysize = 0;
	  int yytype = YYTRANSLATE (yychar);
	  const char* yyprefix;
	  char *yymsg;
	  int yyx;

	  /* Start YYX at -YYN if negative to avoid negative indexes in
	     YYCHECK.  */
	  int yyxbegin = yyn < 0 ? -yyn : 0;

	  /* Stay within bounds of both yycheck and yytname.  */
	  int yychecklim = YYLAST - yyn;
	  int yyxend = yychecklim < YYNTOKENS ? yychecklim : YYNTOKENS;
	  int yycount = 0;

	  yyprefix = ", expecting ";
	  for (yyx = yyxbegin; yyx < yyxend; ++yyx)
	    if (yycheck[yyx + yyn] == yyx && yyx != YYTERROR)
	      {
		yysize += yystrlen (yyprefix) + yystrlen (yytname [yyx]);
		yycount += 1;
		if (yycount == 5)
		  {
		    yysize = 0;
		    break;
		  }
	      }
	  yysize += (sizeof ("syntax error, unexpected ")
		     + yystrlen (yytname[yytype]));
	  yymsg = (char *) YYSTACK_ALLOC (yysize);
	  if (yymsg != 0)
	    {
	      char *yyp = yystpcpy (yymsg, "syntax error, unexpected ");
	      yyp = yystpcpy (yyp, yytname[yytype]);

	      if (yycount < 5)
		{
		  yyprefix = ", expecting ";
		  for (yyx = yyxbegin; yyx < yyxend; ++yyx)
		    if (yycheck[yyx + yyn] == yyx && yyx != YYTERROR)
		      {
			yyp = yystpcpy (yyp, yyprefix);
			yyp = yystpcpy (yyp, yytname[yyx]);
			yyprefix = " or ";
		      }
		}
	      yyerror (yymsg);
	      YYSTACK_FREE (yymsg);
	    }
	  else
	    yyerror ("syntax error; also virtual memory exhausted");
	}
      else
#endif /* YYERROR_VERBOSE */
	yyerror ("syntax error");
    }



  if (yyerrstatus == 3)
    {
      /* If just tried and failed to reuse look-ahead token after an
	 error, discard it.  */

      if (yychar <= YYEOF)
        {
          /* If at end of input, pop the error token,
	     then the rest of the stack, then return failure.  */
	  if (yychar == YYEOF)
	     for (;;)
	       {

		 YYPOPSTACK;
		 if (yyssp == yyss)
		   YYABORT;
		 yydestruct ("Error: popping",
                             yystos[*yyssp], yyvsp);
	       }
        }
      else
	{
	  yydestruct ("Error: discarding", yytoken, &yylval);
	  yychar = YYEMPTY;
	}
    }

  /* Else will try to reuse look-ahead token after shifting the error
     token.  */
  goto yyerrlab1;


/*---------------------------------------------------.
| yyerrorlab -- error raised explicitly by YYERROR.  |
`---------------------------------------------------*/
yyerrorlab:

#ifdef __GNUC__
  /* Pacify GCC when the user code never invokes YYERROR and the label
     yyerrorlab therefore never appears in user code.  */
  if (0)
     goto yyerrorlab;
#endif

yyvsp -= yylen;
  yyssp -= yylen;
  yystate = *yyssp;
  goto yyerrlab1;


/*-------------------------------------------------------------.
| yyerrlab1 -- common code for both syntax error and YYERROR.  |
`-------------------------------------------------------------*/
yyerrlab1:
  yyerrstatus = 3;	/* Each real token shifted decrements this.  */

  for (;;)
    {
      yyn = yypact[yystate];
      if (yyn != YYPACT_NINF)
	{
	  yyn += YYTERROR;
	  if (0 <= yyn && yyn <= YYLAST && yycheck[yyn] == YYTERROR)
	    {
	      yyn = yytable[yyn];
	      if (0 < yyn)
		break;
	    }
	}

      /* Pop the current state because it cannot handle the error token.  */
      if (yyssp == yyss)
	YYABORT;


      yydestruct ("Error: popping", yystos[yystate], yyvsp);
      YYPOPSTACK;
      yystate = *yyssp;
      YY_STACK_PRINT (yyss, yyssp);
    }

  if (yyn == YYFINAL)
    YYACCEPT;

  *++yyvsp = yylval;


  /* Shift the error token. */
  YY_SYMBOL_PRINT ("Shifting", yystos[yyn], yyvsp, yylsp);

  yystate = yyn;
  goto yynewstate;


/*-------------------------------------.
| yyacceptlab -- YYACCEPT comes here.  |
`-------------------------------------*/
yyacceptlab:
  yyresult = 0;
  goto yyreturn;

/*-----------------------------------.
| yyabortlab -- YYABORT comes here.  |
`-----------------------------------*/
yyabortlab:
  yydestruct ("Error: discarding lookahead",
              yytoken, &yylval);
  yychar = YYEMPTY;
  yyresult = 1;
  goto yyreturn;

#ifndef yyoverflow
/*----------------------------------------------.
| yyoverflowlab -- parser overflow comes here.  |
`----------------------------------------------*/
yyoverflowlab:
  yyerror ("parser stack overflow");
  yyresult = 2;
  /* Fall through.  */
#endif

yyreturn:
#ifndef yyoverflow
  if (yyss != yyssa)
    YYSTACK_FREE (yyss);
#endif
  return yyresult;
}


#line 144 "json.y"

void
jsonparse (struct context* context)
{
  yyparse (context);
}

#define HAVE(n) (context->remaining >= n)

#define DRAIN(n) context->text += n, context->remaining -= n

#define	STORESTRINGSEGMENT()				\
	if (initialized) {				\
		if (context->text != bp) {		\
			Tcl_AppendToObj(context->obj,	\
			    bp, context->text - bp);	\
		}					\
	} else {					\
		context->obj = Tcl_NewStringObj(	\
		    bp, context->text - bp);		\
		initialized = 1;			\
	}

void
jsonskip(struct context *context)
{
  while (context->remaining) {
    switch (*context->text) {
    case '\n':
    case ' ':
    case '\t':
    case '\r':
      DRAIN(1);
      continue;
    }
    break;
  }
}

static int
jsonlexp(struct context *context)
{
  const char *bp = NULL;

  /* Question: Why not plain numbers 1,2 for the states
   *           but these specific hex patterns ?
   */
  enum {
    PLAIN	= 0x0000ff00,
    INSTR	= 0x00ff0000
  } lstate;
  double 	 d;
  char		*end;
  const char	*p;
  int		 initialized = 0;

  /*
   * Do not auto-lex beyond a full json structure.
   */
  if (context->result == TCL_OK) {
    TOKEN ("<<eof>>");
    return 0;
  }

  /*
   * Quickly skip and ignore whitespace.
   */
  while (context->remaining) {
    switch (*context->text) {
    case '\n':
    case ' ':
    case '\t':
    case '\r':
      DRAIN(1);
      continue;
    }
    break;
  }

  /*
   * Handle the token following the whitespace. Small state machine to
   * handle strings and escapes in them, and bare words (various
   * contants, and numbers).
   */
  for (lstate = PLAIN; context->remaining > 0; DRAIN(1)) {
    if (lstate == INSTR) {
      if (*context->text == '"') {
	/*
	 * End of quoted string
	 */

	STORESTRINGSEGMENT();
	DRAIN(1);
	TOKEN1 ("STRING");
	return STRING;
      }

      if (*context->text == '\\') {
	/*
	 * Escaped sequence. The 9 sequences specified at json.org
	 * are:
	 *       \"  \\  \/  \b  \f  \n  \r  \t  \uXXXX
	 */
	char	buf[TCL_UTF_MAX];
	int	len, consumed;

	STORESTRINGSEGMENT();

	/*
	 * Perform additional checks to restrict the set of accepted
	 * escape sequence to what is allowed by json.org instead of
	 * Tcl_UtfBackslash.
	 */

	if (!HAVE(1)) {
	  Tcl_AppendToObj(context->obj, "\\", 1);
	  yyerror("incomplete escape at <<eof> error");
	  TOKEN("incomplete escape at <<eof>> error");
	  return -1;
	}
	switch (context->text[1]) {
	  case '"':
	  case '\\':
	  case '/':
	  case 'b':
	  case 'f':
	  case 'n':
	  case 'r':
	  case 't':
	    break;
	  case 'u':
	    if (!HAVE(5)) {
	      Tcl_AppendToObj(context->obj, "\\u", 2);
	      yyerror("incomplete escape at <<eof> error");
	      TOKEN("incomplete escape at <<eof>> error");
	      return -1;
	    }
	    break;
	  default:
	    Tcl_AppendToObj(context->obj, context->text + 1, 1);
	    yyerror("bad escape");
	    TOKEN("bad escape");
	    return -1;
	}

	/*
	 * XXX Tcl_UtfBackslash() may be more
	 * XXX permissive, than JSON standard.
	 * XXX But that may be a good thing:
	 * XXX "be generous in what you accept".
	 */
	len = Tcl_UtfBackslash(context->text,
			       &consumed, buf);
	DRAIN(consumed - 1);
	bp = context->text + 1;
	Tcl_AppendToObj(context->obj, buf, len);
      }
      continue;
    }

    switch (*context->text) {
    case ',':
    case '{':
    case ':':
    case '}':
    case '[':
    case ']':
      DRAIN(1);
      TOKEN (context->text[-1]);
      return context->text[-1];
    case 't':
      if ((context->remaining < 4) ||
	  strncmp("rue", context->text + 1, 3))
	goto bareword;
      DRAIN(4);
      context->obj = TRUE_O;
      TOKEN1 ("CONSTANT");
      return CONSTANT;
    case 'f':
      if ((context->remaining < 5) ||
	  strncmp("alse", context->text + 1, 4))
	goto bareword;
      DRAIN(5);
      context->obj = FALSE_O;
      TOKEN1 ("CONSTANT");
      return CONSTANT;
    case 'n':
      if ((context->remaining < 4) ||
	  strncmp("ull", context->text + 1, 3))
	goto bareword;
      DRAIN(4);
      context->obj = NULL_O;
      TOKEN1 ("CONSTANT");
      return CONSTANT;
    case '"':
      bp = context->text + 1;
      lstate = INSTR;
      continue;
    case '\\':
      yyerror("Escape character outside of string");
      TOKEN ("escape error");
      return -1;
    }

    /*
     * We already considered the null, true, and false
     * above, so it can only be a number now.
     *
     * NOTE: At this point we do not care about double
     * versus integer, nor about the possible integer
     * range. We generate a plain string Tcl_Obj and leave
     * it to the user of the generated structure to
     * convert to a number when actually needed. This
     * defered conversion also ensures that the Tcl and
     * platform we are building against does not matter
     * regarding integer range, only the abilities of the
     * Tcl at runtime.
     */

    d = strtod(context->text, &end);
    if (end == context->text)
      goto bareword; /* Nothing parsed */

    context->obj = Tcl_NewStringObj (context->text,
				     end - context->text);

    context->remaining -= (end - context->text);
    context->text = end;
    TOKEN1 ("CONSTANT");
    return CONSTANT;
  }

  TOKEN ("<<eof>>");
  return 0;
 bareword:
  yyerror("Bare word encountered");
  TOKEN ("bare word error");
  return -1;
}

#if 0
int
jsonlex(struct context *context)
{
  const char *bp = NULL;

  /* Question: Why not plain numbers 1,2 for the states
   *           but these specific hex patterns ?
   */
  enum {
    PLAIN	= 0x0000ff00,
    INSTR	= 0x00ff0000
  } lstate;
  double 	 d;
  char		*end;
  const char	*p;
  int		 initialized = 0;

  while (context->remaining) {
    /* Iterate over the whole string and check all tokens.
     * Nothing else.
     */

    /*
     * Quickly skip and ignore whitespace.
     */
    while (context->remaining) {
      switch (*context->text) {
      case '\n':
      case ' ':
      case '\t':
      case '\r':
	DRAIN(1);
	continue;
      }
      break;
    }

  /*
   * Handle the token following the whitespace. Small state machine to
   * handle strings and escapes in them, and bare words (various
   * contants, and numbers).
   */
  for (lstate = PLAIN; context->remaining > 0; DRAIN(1)) {
    if (lstate == INSTR) {
      if (*context->text == '"') {
	/*
	 * End of quoted string
	 */
	DRAIN(1);
	goto next_token;
      }

      if (*context->text == '\\') {
	/*
	 * Escaped sequence
	 */
	char	buf[TCL_UTF_MAX];
	int	len, consumed;

	/*
	 * XXX Tcl_UtfBackslash() may be more
	 * XXX permissive, than JSON standard.
	 * XXX But that may be a good thing:
	 * XXX "be generous in what you accept".
	 */
	len = Tcl_UtfBackslash(context->text, &consumed, buf);
	DRAIN(consumed - 1);
      }
      continue;
    }

    switch (*context->text) {
    case ',':
    case '{':
    case ':':
    case '}':
    case '[':
    case ']':
      DRAIN(1);
      goto next_token;

    case 't':
      if ((context->remaining < 4) ||
	  strncmp("rue", context->text + 1, 3))
	return -1; /* bare word */
      DRAIN(4);
      goto next_token;
    case 'f':
      if ((context->remaining < 5) ||
	  strncmp("alse", context->text + 1, 4))
	return -1; /* bare word */
      DRAIN(5);
      goto next_token;
    case 'n':
      if ((context->remaining < 4) ||
	  strncmp("ull", context->text + 1, 3))
	return -1; /* bare word */
      DRAIN(4);
      goto next_token;
    case '"':
      bp = context->text + 1;
      lstate = INSTR;
      continue;
    case '\\':
      /* Escape outside string, abort. */
      return -1;
    }

    /*
     * We already considered the null, true, and false
     * above, so it can only be a number now.
     *
     * NOTE: At this point we do not care about double
     * versus integer, nor about the possible integer
     * range. We generate a plain string Tcl_Obj and leave
     * it to the user of the generated structure to
     * convert to a number when actually needed. This
     * defered conversion also ensures that the Tcl and
     * platform we are building against does not matter
     * regarding integer range, only the abilities of the
     * Tcl at runtime.
     */

    d = strtod(context->text, &end);
    if (end == context->text)
      return -1; /* bare word */

    context->remaining -= (end - context->text);
    context->text = end;
    goto next_token;
  }

  return 0;

  next_token:
  continue;
  }
}
#endif

static void
jsonerror(struct context *context, const char *message)
{
  char *fullmessage;
  char *yytext;
  int   yyleng;

  if (context->has_error) return;

  if (context->obj) {
    yytext = Tcl_GetStringFromObj(context->obj, &yyleng);
    fullmessage = Tcl_Alloc(strlen(message) + 63 + yyleng);

    sprintf(fullmessage, "%s %d bytes before end, around ``%.*s''",
	    message, context->remaining, yyleng, yytext);
  } else {
    fullmessage = Tcl_Alloc(strlen(message) + 63);

    sprintf(fullmessage, "%s %d bytes before end",
	    message, context->remaining);
  }

  TRACE ((">>> %s\n",fullmessage));
  Tcl_SetResult    (context->I, fullmessage, TCL_DYNAMIC);
  Tcl_SetErrorCode (context->I, "JSON", "SYNTAX", NULL);
  context->has_error = 1;
}


