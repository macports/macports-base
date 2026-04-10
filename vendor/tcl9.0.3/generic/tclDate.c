/* A Bison parser, made by GNU Bison 3.8.2.  */

/* Bison implementation for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2021 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* C LALR(1) parser skeleton written by Richard Stallman, by
   simplifying the original so-called "semantic" parser.  */

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

/* All symbols defined below should begin with yy or YY, to avoid
   infringing on user name space.  This should be done even for local
   variables, as they might otherwise be expanded by user macros.
   There are some unavoidable exceptions within include files to
   define necessary library symbols; they are noted "INFRINGES ON
   USER NAME SPACE" below.  */

/* Identify Bison output, and Bison version.  */
#define YYBISON 30802

/* Bison version string.  */
#define YYBISON_VERSION "3.8.2"

/* Skeleton name.  */
#define YYSKELETON_NAME "yacc.c"

/* Pure parsers.  */
#define YYPURE 1

/* Push parsers.  */
#define YYPUSH 0

/* Pull parsers.  */
#define YYPULL 1


/* Substitute the variable and function names.  */
#define yyparse         TclDateparse
#define yylex           TclDatelex
#define yyerror         TclDateerror
#define yydebug         TclDatedebug
#define yynerrs         TclDatenerrs

/* First part of user prologue.  */

/*
 * tclDate.c --
 *
 *	This file is generated from a yacc grammar defined in the file
 *	tclGetDate.y. It should not be edited directly.
 *
 * Copyright © 1992-1995 Karl Lehenbauer & Mark Diekhans.
 * Copyright © 1995-1997 Sun Microsystems, Inc.
 * Copyright © 2015 Sergey G. Brester aka sebres.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 */
#include "tclInt.h"

/*
 * Bison generates several labels that happen to be unused. Several compilers
 * don't like that, and complain. Simply disable the warning to silence them.
 */

#ifdef _MSC_VER
#pragma warning( disable : 4102 )
#elif defined (__clang__) && (__clang_major__ > 14)
#pragma clang diagnostic ignored "-Wunused-but-set-variable"
#elif (__GNUC__)  && ((__GNUC__ > 4) || ((__GNUC__ == 4) && (__GNUC_MINOR__ > 5)))
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#endif

#if 0
#define YYDEBUG 1
#endif

/*
 * yyparse will accept a 'struct DateInfo' as its parameter; that's where the
 * parsed fields will be returned.
 */

#include "tclDate.h"

#define YYMALLOC	Tcl_Alloc
#define YYFREE(x)	(Tcl_Free((void*) (x)))

#define EPOCH		1970
#define START_OF_TIME	1902
#define END_OF_TIME	2037

/*
 * The offset of tm_year of struct tm returned by localtime, gmtime, etc.
 * Posix requires 1900.
 */

#define TM_YEAR_BASE	1900

#define HOUR(x)		((60 * (int)(x)))
#define IsLeapYear(x)	(((x) % 4 == 0) && ((x) % 100 != 0 || (x) % 400 == 0))

#define yyIncrFlags(f)				\
    do {					\
	info->errFlags |= (info->flags & (f));	\
	if (info->errFlags) { YYABORT; }	\
	info->flags |= (f);			\
    } while (0);

/*
 * An entry in the lexical lookup table.
 */

typedef struct {
    const char *name;
    int type;
    int value;
} TABLE;

/*
 * Daylight-savings mode: on, off, or not yet known.
 */

typedef enum _DSTMODE {
    DSTon, DSToff, DSTmaybe
} DSTMODE;



# ifndef YY_CAST
#  ifdef __cplusplus
#   define YY_CAST(Type, Val) static_cast<Type> (Val)
#   define YY_REINTERPRET_CAST(Type, Val) reinterpret_cast<Type> (Val)
#  else
#   define YY_CAST(Type, Val) ((Type) (Val))
#   define YY_REINTERPRET_CAST(Type, Val) ((Type) (Val))
#  endif
# endif
# ifndef YY_NULLPTR
#  if defined __cplusplus
#   if 201103L <= __cplusplus
#    define YY_NULLPTR nullptr
#   else
#    define YY_NULLPTR 0
#   endif
#  else
#   define YY_NULLPTR ((void*)0)
#  endif
# endif


/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif
#if YYDEBUG
extern int TclDatedebug;
#endif

/* Token kinds.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    YYEMPTY = -2,
    YYEOF = 0,                     /* "end of file"  */
    YYerror = 256,                 /* error  */
    YYUNDEF = 257,                 /* "invalid token"  */
    tAGO = 258,                    /* tAGO  */
    tDAY = 259,                    /* tDAY  */
    tDAYZONE = 260,                /* tDAYZONE  */
    tID = 261,                     /* tID  */
    tMERIDIAN = 262,               /* tMERIDIAN  */
    tMONTH = 263,                  /* tMONTH  */
    tMONTH_UNIT = 264,             /* tMONTH_UNIT  */
    tSTARDATE = 265,               /* tSTARDATE  */
    tSEC_UNIT = 266,               /* tSEC_UNIT  */
    tUNUMBER = 267,                /* tUNUMBER  */
    tZONE = 268,                   /* tZONE  */
    tZONEwO4 = 269,                /* tZONEwO4  */
    tZONEwO2 = 270,                /* tZONEwO2  */
    tEPOCH = 271,                  /* tEPOCH  */
    tDST = 272,                    /* tDST  */
    tISOBAS8 = 273,                /* tISOBAS8  */
    tISOBAS6 = 274,                /* tISOBAS6  */
    tISOBASL = 275,                /* tISOBASL  */
    tDAY_UNIT = 276,               /* tDAY_UNIT  */
    tNEXT = 277,                   /* tNEXT  */
    SP = 278                       /* SP  */
  };
  typedef enum yytokentype yytoken_kind_t;
#endif

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
union YYSTYPE
{

    Tcl_WideInt Number;
    MERIDIAN Meridian;


};
typedef union YYSTYPE YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif

/* Location type.  */
#if ! defined YYLTYPE && ! defined YYLTYPE_IS_DECLARED
typedef struct YYLTYPE YYLTYPE;
struct YYLTYPE
{
  int first_line;
  int first_column;
  int last_line;
  int last_column;
};
# define YYLTYPE_IS_DECLARED 1
# define YYLTYPE_IS_TRIVIAL 1
#endif




int TclDateparse (DateInfo* info);



/* Symbol kind.  */
enum yysymbol_kind_t
{
  YYSYMBOL_YYEMPTY = -2,
  YYSYMBOL_YYEOF = 0,                      /* "end of file"  */
  YYSYMBOL_YYerror = 1,                    /* error  */
  YYSYMBOL_YYUNDEF = 2,                    /* "invalid token"  */
  YYSYMBOL_tAGO = 3,                       /* tAGO  */
  YYSYMBOL_tDAY = 4,                       /* tDAY  */
  YYSYMBOL_tDAYZONE = 5,                   /* tDAYZONE  */
  YYSYMBOL_tID = 6,                        /* tID  */
  YYSYMBOL_tMERIDIAN = 7,                  /* tMERIDIAN  */
  YYSYMBOL_tMONTH = 8,                     /* tMONTH  */
  YYSYMBOL_tMONTH_UNIT = 9,                /* tMONTH_UNIT  */
  YYSYMBOL_tSTARDATE = 10,                 /* tSTARDATE  */
  YYSYMBOL_tSEC_UNIT = 11,                 /* tSEC_UNIT  */
  YYSYMBOL_tUNUMBER = 12,                  /* tUNUMBER  */
  YYSYMBOL_tZONE = 13,                     /* tZONE  */
  YYSYMBOL_tZONEwO4 = 14,                  /* tZONEwO4  */
  YYSYMBOL_tZONEwO2 = 15,                  /* tZONEwO2  */
  YYSYMBOL_tEPOCH = 16,                    /* tEPOCH  */
  YYSYMBOL_tDST = 17,                      /* tDST  */
  YYSYMBOL_tISOBAS8 = 18,                  /* tISOBAS8  */
  YYSYMBOL_tISOBAS6 = 19,                  /* tISOBAS6  */
  YYSYMBOL_tISOBASL = 20,                  /* tISOBASL  */
  YYSYMBOL_tDAY_UNIT = 21,                 /* tDAY_UNIT  */
  YYSYMBOL_tNEXT = 22,                     /* tNEXT  */
  YYSYMBOL_SP = 23,                        /* SP  */
  YYSYMBOL_24_ = 24,                       /* ':'  */
  YYSYMBOL_25_ = 25,                       /* ','  */
  YYSYMBOL_26_ = 26,                       /* '-'  */
  YYSYMBOL_27_ = 27,                       /* '/'  */
  YYSYMBOL_28_T_ = 28,                     /* 'T'  */
  YYSYMBOL_29_ = 29,                       /* '.'  */
  YYSYMBOL_30_ = 30,                       /* '+'  */
  YYSYMBOL_YYACCEPT = 31,                  /* $accept  */
  YYSYMBOL_spec = 32,                      /* spec  */
  YYSYMBOL_item = 33,                      /* item  */
  YYSYMBOL_iextime = 34,                   /* iextime  */
  YYSYMBOL_time = 35,                      /* time  */
  YYSYMBOL_zone = 36,                      /* zone  */
  YYSYMBOL_comma = 37,                     /* comma  */
  YYSYMBOL_day = 38,                       /* day  */
  YYSYMBOL_iexdate = 39,                   /* iexdate  */
  YYSYMBOL_date = 40,                      /* date  */
  YYSYMBOL_ordMonth = 41,                  /* ordMonth  */
  YYSYMBOL_isosep = 42,                    /* isosep  */
  YYSYMBOL_isodate = 43,                   /* isodate  */
  YYSYMBOL_isotime = 44,                   /* isotime  */
  YYSYMBOL_iso = 45,                       /* iso  */
  YYSYMBOL_trek = 46,                      /* trek  */
  YYSYMBOL_relspec = 47,                   /* relspec  */
  YYSYMBOL_relunits = 48,                  /* relunits  */
  YYSYMBOL_sign = 49,                      /* sign  */
  YYSYMBOL_unit = 50,                      /* unit  */
  YYSYMBOL_INTNUM = 51,                    /* INTNUM  */
  YYSYMBOL_numitem = 52,                   /* numitem  */
  YYSYMBOL_o_merid = 53                    /* o_merid  */
};
typedef enum yysymbol_kind_t yysymbol_kind_t;


/* Second part of user prologue.  */


/*
 * Prototypes of internal functions.
 */

static int		LookupWord(YYSTYPE* yylvalPtr, char *buff);
static void		TclDateerror(YYLTYPE* location,
				     DateInfo* info, const char *s);
static int		TclDatelex(YYSTYPE* yylvalPtr, YYLTYPE* location,
				   DateInfo* info);
MODULE_SCOPE int	yyparse(DateInfo*);




#ifdef short
# undef short
#endif

/* On compilers that do not define __PTRDIFF_MAX__ etc., make sure
   <limits.h> and (if available) <stdint.h> are included
   so that the code can choose integer types of a good width.  */

#ifndef __PTRDIFF_MAX__
# include <limits.h> /* INFRINGES ON USER NAME SPACE */
# if defined __STDC_VERSION__ && 199901 <= __STDC_VERSION__
#  include <stdint.h> /* INFRINGES ON USER NAME SPACE */
#  define YY_STDINT_H
# endif
#endif

/* Narrow types that promote to a signed type and that can represent a
   signed or unsigned integer of at least N bits.  In tables they can
   save space and decrease cache pressure.  Promoting to a signed type
   helps avoid bugs in integer arithmetic.  */

#ifdef __INT_LEAST8_MAX__
typedef __INT_LEAST8_TYPE__ yytype_int8;
#elif defined YY_STDINT_H
typedef int_least8_t yytype_int8;
#else
typedef signed char yytype_int8;
#endif

#ifdef __INT_LEAST16_MAX__
typedef __INT_LEAST16_TYPE__ yytype_int16;
#elif defined YY_STDINT_H
typedef int_least16_t yytype_int16;
#else
typedef short yytype_int16;
#endif

/* Work around bug in HP-UX 11.23, which defines these macros
   incorrectly for preprocessor constants.  This workaround can likely
   be removed in 2023, as HPE has promised support for HP-UX 11.23
   (aka HP-UX 11i v2) only through the end of 2022; see Table 2 of
   <https://h20195.www2.hpe.com/V2/getpdf.aspx/4AA4-7673ENW.pdf>.  */
#ifdef __hpux
# undef UINT_LEAST8_MAX
# undef UINT_LEAST16_MAX
# define UINT_LEAST8_MAX 255
# define UINT_LEAST16_MAX 65535
#endif

#if defined __UINT_LEAST8_MAX__ && __UINT_LEAST8_MAX__ <= __INT_MAX__
typedef __UINT_LEAST8_TYPE__ yytype_uint8;
#elif (!defined __UINT_LEAST8_MAX__ && defined YY_STDINT_H \
       && UINT_LEAST8_MAX <= INT_MAX)
typedef uint_least8_t yytype_uint8;
#elif !defined __UINT_LEAST8_MAX__ && UCHAR_MAX <= INT_MAX
typedef unsigned char yytype_uint8;
#else
typedef short yytype_uint8;
#endif

#if defined __UINT_LEAST16_MAX__ && __UINT_LEAST16_MAX__ <= __INT_MAX__
typedef __UINT_LEAST16_TYPE__ yytype_uint16;
#elif (!defined __UINT_LEAST16_MAX__ && defined YY_STDINT_H \
       && UINT_LEAST16_MAX <= INT_MAX)
typedef uint_least16_t yytype_uint16;
#elif !defined __UINT_LEAST16_MAX__ && USHRT_MAX <= INT_MAX
typedef unsigned short yytype_uint16;
#else
typedef int yytype_uint16;
#endif

#ifndef YYPTRDIFF_T
# if defined __PTRDIFF_TYPE__ && defined __PTRDIFF_MAX__
#  define YYPTRDIFF_T __PTRDIFF_TYPE__
#  define YYPTRDIFF_MAXIMUM __PTRDIFF_MAX__
# elif defined PTRDIFF_MAX
#  ifndef ptrdiff_t
#   include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  endif
#  define YYPTRDIFF_T ptrdiff_t
#  define YYPTRDIFF_MAXIMUM PTRDIFF_MAX
# else
#  define YYPTRDIFF_T long
#  define YYPTRDIFF_MAXIMUM LONG_MAX
# endif
#endif

#ifndef YYSIZE_T
# ifdef __SIZE_TYPE__
#  define YYSIZE_T __SIZE_TYPE__
# elif defined size_t
#  define YYSIZE_T size_t
# elif defined __STDC_VERSION__ && 199901 <= __STDC_VERSION__
#  include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  define YYSIZE_T size_t
# else
#  define YYSIZE_T unsigned
# endif
#endif

#define YYSIZE_MAXIMUM                                  \
  YY_CAST (YYPTRDIFF_T,                                 \
           (YYPTRDIFF_MAXIMUM < YY_CAST (YYSIZE_T, -1)  \
            ? YYPTRDIFF_MAXIMUM                         \
            : YY_CAST (YYSIZE_T, -1)))

#define YYSIZEOF(X) YY_CAST (YYPTRDIFF_T, sizeof (X))


/* Stored state numbers (used for stacks). */
typedef yytype_int8 yy_state_t;

/* State numbers in computations.  */
typedef int yy_state_fast_t;

#ifndef YY_
# if defined YYENABLE_NLS && YYENABLE_NLS
#  if ENABLE_NLS
#   include <libintl.h> /* INFRINGES ON USER NAME SPACE */
#   define YY_(Msgid) dgettext ("bison-runtime", Msgid)
#  endif
# endif
# ifndef YY_
#  define YY_(Msgid) Msgid
# endif
#endif


#ifndef YY_ATTRIBUTE_PURE
# if defined __GNUC__ && 2 < __GNUC__ + (96 <= __GNUC_MINOR__)
#  define YY_ATTRIBUTE_PURE __attribute__ ((__pure__))
# else
#  define YY_ATTRIBUTE_PURE
# endif
#endif

#ifndef YY_ATTRIBUTE_UNUSED
# if defined __GNUC__ && 2 < __GNUC__ + (7 <= __GNUC_MINOR__)
#  define YY_ATTRIBUTE_UNUSED __attribute__ ((__unused__))
# else
#  define YY_ATTRIBUTE_UNUSED
# endif
#endif

/* Suppress unused-variable warnings by "using" E.  */
#if ! defined lint || defined __GNUC__
# define YY_USE(E) ((void) (E))
#else
# define YY_USE(E) /* empty */
#endif

/* Suppress an incorrect diagnostic about yylval being uninitialized.  */
#if defined __GNUC__ && ! defined __ICC && 406 <= __GNUC__ * 100 + __GNUC_MINOR__
# if __GNUC__ * 100 + __GNUC_MINOR__ < 407
#  define YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN                           \
    _Pragma ("GCC diagnostic push")                                     \
    _Pragma ("GCC diagnostic ignored \"-Wuninitialized\"")
# else
#  define YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN                           \
    _Pragma ("GCC diagnostic push")                                     \
    _Pragma ("GCC diagnostic ignored \"-Wuninitialized\"")              \
    _Pragma ("GCC diagnostic ignored \"-Wmaybe-uninitialized\"")
# endif
# define YY_IGNORE_MAYBE_UNINITIALIZED_END      \
    _Pragma ("GCC diagnostic pop")
#else
# define YY_INITIAL_VALUE(Value) Value
#endif
#ifndef YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
# define YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
# define YY_IGNORE_MAYBE_UNINITIALIZED_END
#endif
#ifndef YY_INITIAL_VALUE
# define YY_INITIAL_VALUE(Value) /* Nothing. */
#endif

#if defined __cplusplus && defined __GNUC__ && ! defined __ICC && 6 <= __GNUC__
# define YY_IGNORE_USELESS_CAST_BEGIN                          \
    _Pragma ("GCC diagnostic push")                            \
    _Pragma ("GCC diagnostic ignored \"-Wuseless-cast\"")
# define YY_IGNORE_USELESS_CAST_END            \
    _Pragma ("GCC diagnostic pop")
#endif
#ifndef YY_IGNORE_USELESS_CAST_BEGIN
# define YY_IGNORE_USELESS_CAST_BEGIN
# define YY_IGNORE_USELESS_CAST_END
#endif


#define YY_ASSERT(E) ((void) (0 && (E)))

#if !defined yyoverflow

/* The parser invokes alloca or malloc; define the necessary symbols.  */

# ifdef YYSTACK_USE_ALLOCA
#  if YYSTACK_USE_ALLOCA
#   ifdef __GNUC__
#    define YYSTACK_ALLOC __builtin_alloca
#   elif defined __BUILTIN_VA_ARG_INCR
#    include <alloca.h> /* INFRINGES ON USER NAME SPACE */
#   elif defined _AIX
#    define YYSTACK_ALLOC __alloca
#   elif defined _MSC_VER
#    include <malloc.h> /* INFRINGES ON USER NAME SPACE */
#    define alloca _alloca
#   else
#    define YYSTACK_ALLOC alloca
#    if ! defined _ALLOCA_H && ! defined EXIT_SUCCESS
#     include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
      /* Use EXIT_SUCCESS as a witness for stdlib.h.  */
#     ifndef EXIT_SUCCESS
#      define EXIT_SUCCESS 0
#     endif
#    endif
#   endif
#  endif
# endif

# ifdef YYSTACK_ALLOC
   /* Pacify GCC's 'empty if-body' warning.  */
#  define YYSTACK_FREE(Ptr) do { /* empty */; } while (0)
#  ifndef YYSTACK_ALLOC_MAXIMUM
    /* The OS might guarantee only one guard page at the bottom of the stack,
       and a page size can be as small as 4096 bytes.  So we cannot safely
       invoke alloca (N) if N exceeds 4096.  Use a slightly smaller number
       to allow for a few compiler-allocated temporary stack slots.  */
#   define YYSTACK_ALLOC_MAXIMUM 4032 /* reasonable circa 2006 */
#  endif
# else
#  define YYSTACK_ALLOC YYMALLOC
#  define YYSTACK_FREE YYFREE
#  ifndef YYSTACK_ALLOC_MAXIMUM
#   define YYSTACK_ALLOC_MAXIMUM YYSIZE_MAXIMUM
#  endif
#  if (defined __cplusplus && ! defined EXIT_SUCCESS \
       && ! ((defined YYMALLOC || defined malloc) \
             && (defined YYFREE || defined free)))
#   include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
#   ifndef EXIT_SUCCESS
#    define EXIT_SUCCESS 0
#   endif
#  endif
#  ifndef YYMALLOC
#   define YYMALLOC malloc
#   if ! defined malloc && ! defined EXIT_SUCCESS
void *malloc (YYSIZE_T); /* INFRINGES ON USER NAME SPACE */
#   endif
#  endif
#  ifndef YYFREE
#   define YYFREE free
#   if ! defined free && ! defined EXIT_SUCCESS
void free (void *); /* INFRINGES ON USER NAME SPACE */
#   endif
#  endif
# endif
#endif /* !defined yyoverflow */

#if (! defined yyoverflow \
     && (! defined __cplusplus \
         || (defined YYLTYPE_IS_TRIVIAL && YYLTYPE_IS_TRIVIAL \
             && defined YYSTYPE_IS_TRIVIAL && YYSTYPE_IS_TRIVIAL)))

/* A type that is properly aligned for any stack member.  */
union yyalloc
{
  yy_state_t yyss_alloc;
  YYSTYPE yyvs_alloc;
  YYLTYPE yyls_alloc;
};

/* The size of the maximum gap between one aligned stack and the next.  */
# define YYSTACK_GAP_MAXIMUM (YYSIZEOF (union yyalloc) - 1)

/* The size of an array large to enough to hold all stacks, each with
   N elements.  */
# define YYSTACK_BYTES(N) \
     ((N) * (YYSIZEOF (yy_state_t) + YYSIZEOF (YYSTYPE) \
             + YYSIZEOF (YYLTYPE)) \
      + 2 * YYSTACK_GAP_MAXIMUM)

# define YYCOPY_NEEDED 1

/* Relocate STACK from its old location to the new one.  The
   local variables YYSIZE and YYSTACKSIZE give the old and new number of
   elements in the stack, and YYPTR gives the new location of the
   stack.  Advance YYPTR to a properly aligned location for the next
   stack.  */
# define YYSTACK_RELOCATE(Stack_alloc, Stack)                           \
    do                                                                  \
      {                                                                 \
        YYPTRDIFF_T yynewbytes;                                         \
        YYCOPY (&yyptr->Stack_alloc, Stack, yysize);                    \
        Stack = &yyptr->Stack_alloc;                                    \
        yynewbytes = yystacksize * YYSIZEOF (*Stack) + YYSTACK_GAP_MAXIMUM; \
        yyptr += yynewbytes / YYSIZEOF (*yyptr);                        \
      }                                                                 \
    while (0)

#endif

#if defined YYCOPY_NEEDED && YYCOPY_NEEDED
/* Copy COUNT objects from SRC to DST.  The source and destination do
   not overlap.  */
# ifndef YYCOPY
#  if defined __GNUC__ && 1 < __GNUC__
#   define YYCOPY(Dst, Src, Count) \
      __builtin_memcpy (Dst, Src, YY_CAST (YYSIZE_T, (Count)) * sizeof (*(Src)))
#  else
#   define YYCOPY(Dst, Src, Count)              \
      do                                        \
        {                                       \
          YYPTRDIFF_T yyi;                      \
          for (yyi = 0; yyi < (Count); yyi++)   \
            (Dst)[yyi] = (Src)[yyi];            \
        }                                       \
      while (0)
#  endif
# endif
#endif /* !YYCOPY_NEEDED */

/* YYFINAL -- State number of the termination state.  */
#define YYFINAL  2
/* YYLAST -- Last index in YYTABLE.  */
#define YYLAST   98

/* YYNTOKENS -- Number of terminals.  */
#define YYNTOKENS  31
/* YYNNTS -- Number of nonterminals.  */
#define YYNNTS  23
/* YYNRULES -- Number of rules.  */
#define YYNRULES  72
/* YYNSTATES -- Number of states.  */
#define YYNSTATES  103

/* YYMAXUTOK -- Last valid token kind.  */
#define YYMAXUTOK   278


/* YYTRANSLATE(TOKEN-NUM) -- Symbol number corresponding to TOKEN-NUM
   as returned by yylex, with out-of-bounds checking.  */
#define YYTRANSLATE(YYX)                                \
  (0 <= (YYX) && (YYX) <= YYMAXUTOK                     \
   ? YY_CAST (yysymbol_kind_t, yytranslate[YYX])        \
   : YYSYMBOL_YYUNDEF)

/* YYTRANSLATE[TOKEN-NUM] -- Symbol number corresponding to TOKEN-NUM
   as returned by yylex.  */
static const yytype_int8 yytranslate[] =
{
       0,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,    30,    25,    26,    29,    27,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,    24,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,    28,     2,     2,     2,     2,     2,
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
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     1,     2,     3,     4,
       5,     6,     7,     8,     9,    10,    11,    12,    13,    14,
      15,    16,    17,    18,    19,    20,    21,    22,    23
};

#if YYDEBUG
/* YYRLINE[YYN] -- Source line where rule number YYN was defined.  */
static const yytype_int16 yyrline[] =
{
       0,   175,   175,   176,   180,   183,   186,   189,   193,   197,
     200,   203,   207,   210,   215,   221,   227,   232,   236,   240,
     244,   248,   252,   258,   259,   262,   266,   270,   274,   278,
     282,   288,   294,   298,   303,   304,   309,   313,   318,   322,
     327,   334,   338,   344,   344,   346,   351,   356,   358,   363,
     365,   366,   374,   385,   400,   405,   408,   411,   414,   417,
     420,   423,   428,   431,   436,   441,   446,   453,   456,   459,
     464,   482,   485
};
#endif

/** Accessing symbol of state STATE.  */
#define YY_ACCESSING_SYMBOL(State) YY_CAST (yysymbol_kind_t, yystos[State])

#if YYDEBUG || 0
/* The user-facing name of the symbol whose (internal) number is
   YYSYMBOL.  No bounds checking.  */
static const char *yysymbol_name (yysymbol_kind_t yysymbol) YY_ATTRIBUTE_UNUSED;

/* YYTNAME[SYMBOL-NUM] -- String name of the symbol SYMBOL-NUM.
   First, the terminals, then, starting at YYNTOKENS, nonterminals.  */
static const char *const yytname[] =
{
  "\"end of file\"", "error", "\"invalid token\"", "tAGO", "tDAY",
  "tDAYZONE", "tID", "tMERIDIAN", "tMONTH", "tMONTH_UNIT", "tSTARDATE",
  "tSEC_UNIT", "tUNUMBER", "tZONE", "tZONEwO4", "tZONEwO2", "tEPOCH",
  "tDST", "tISOBAS8", "tISOBAS6", "tISOBASL", "tDAY_UNIT", "tNEXT", "SP",
  "':'", "','", "'-'", "'/'", "'T'", "'.'", "'+'", "$accept", "spec",
  "item", "iextime", "time", "zone", "comma", "day", "iexdate", "date",
  "ordMonth", "isosep", "isodate", "isotime", "iso", "trek", "relspec",
  "relunits", "sign", "unit", "INTNUM", "numitem", "o_merid", YY_NULLPTR
};

static const char *
yysymbol_name (yysymbol_kind_t yysymbol)
{
  return yytname[yysymbol];
}
#endif

#define YYPACT_NINF (-21)

#define yypact_value_is_default(Yyn) \
  ((Yyn) == YYPACT_NINF)

#define YYTABLE_NINF (-68)

#define yytable_value_is_error(Yyn) \
  0

/* YYPACT[STATE-NUM] -- Index in YYTABLE of the portion describing
   STATE-NUM.  */
static const yytype_int8 yypact[] =
{
     -21,    11,   -21,   -20,   -21,     5,   -21,    -9,   -21,    46,
      17,     9,     9,   -21,   -21,   -21,    24,   -21,    57,   -21,
     -21,   -21,    33,   -21,   -21,   -21,   -21,   -21,   -21,   -15,
     -21,   -21,   -21,    45,    26,   -21,    -7,   -21,    51,   -21,
     -20,   -21,   -21,   -21,    48,   -21,   -21,    67,    68,    52,
      69,   -21,    -9,    -9,   -21,   -21,   -21,   -21,    74,   -21,
      -7,   -21,   -21,   -21,   -21,    44,   -21,    79,    40,    -7,
     -21,   -21,    72,    73,   -21,    62,    61,    63,    64,   -21,
     -21,   -21,   -21,    66,   -21,   -21,   -21,   -21,    84,    -7,
     -21,   -21,   -21,    80,    81,    82,    83,   -21,   -21,   -21,
     -21,   -21,   -21
};

/* YYDEFACT[STATE-NUM] -- Default reduction number in state STATE-NUM.
   Performed when YYTABLE does not specify something else to do.  Zero
   means the default is an error.  */
static const yytype_int8 yydefact[] =
{
       2,     0,     1,    25,    19,     0,    66,     0,    64,    70,
      18,     0,     0,    39,    45,    46,     0,    65,     0,    62,
      63,     3,    71,     4,     5,     8,    47,     6,     7,    34,
      10,    11,     9,    55,     0,    61,     0,    12,    23,    26,
      36,    67,    69,    68,     0,    27,    15,    38,     0,     0,
       0,    17,     0,     0,    52,    51,    30,    41,    67,    59,
       0,    72,    16,    44,    43,     0,    54,    67,     0,    22,
      58,    24,     0,     0,    40,    14,     0,     0,    32,    20,
      21,    42,    60,     0,    48,    49,    50,    29,    67,     0,
      57,    37,    53,     0,     0,     0,     0,    28,    56,    13,
      35,    31,    33
};

/* YYPGOTO[NTERM-NUM].  */
static const yytype_int8 yypgoto[] =
{
     -21,   -21,   -21,    31,   -21,   -21,    58,   -21,   -21,   -21,
     -21,   -21,   -21,   -21,   -21,   -21,   -21,   -21,    -5,   -18,
      -6,   -21,   -21
};

/* YYDEFGOTO[NTERM-NUM].  */
static const yytype_int8 yydefgoto[] =
{
       0,     1,    21,    22,    23,    24,    39,    25,    26,    27,
      28,    65,    29,    86,    30,    31,    32,    33,    34,    35,
      36,    37,    62
};

/* YYTABLE[YYPACT[STATE-NUM]] -- What to do in state STATE-NUM.  If
   positive, shift that token.  If negative, reduce the rule whose
   number is the opposite.  If YYTABLE_NINF, syntax error.  */
static const yytype_int8 yytable[] =
{
      59,    44,     6,    41,     8,    38,    52,    53,    63,    42,
      43,     2,    60,    64,    17,     3,     4,    40,    70,     5,
       6,     7,     8,     9,    10,    11,    12,    13,    69,    14,
      15,    16,    17,    18,    51,    19,    54,    19,    67,    20,
      61,    20,    82,    55,    42,    43,    79,    80,    66,    68,
      45,    90,    88,    46,    47,   -67,    83,   -67,    42,    43,
      76,    56,    89,    84,    77,    57,     6,   -67,     8,    58,
      48,    98,    49,    50,    71,    42,    43,    73,    17,    74,
      75,    78,    81,    87,    91,    92,    93,    94,    97,    95,
      48,    96,    99,   100,   101,   102,    85,     0,    72
};

static const yytype_int8 yycheck[] =
{
      18,     7,     9,    12,    11,    25,    11,    12,    23,    18,
      19,     0,    18,    28,    21,     4,     5,    12,    36,     8,
       9,    10,    11,    12,    13,    14,    15,    16,    34,    18,
      19,    20,    21,    22,    17,    26,    12,    26,    12,    30,
       7,    30,    60,    19,    18,    19,    52,    53,     3,    23,
       4,    69,    12,     7,     8,     9,    12,    11,    18,    19,
       8,     4,    68,    19,    12,     8,     9,    21,    11,    12,
      24,    89,    26,    27,    23,    18,    19,    29,    21,    12,
      12,    12,     8,     4,    12,    12,    24,    26,     4,    26,
      24,    27,    12,    12,    12,    12,    65,    -1,    40
};

/* YYSTOS[STATE-NUM] -- The symbol kind of the accessing symbol of
   state STATE-NUM.  */
static const yytype_int8 yystos[] =
{
       0,    32,     0,     4,     5,     8,     9,    10,    11,    12,
      13,    14,    15,    16,    18,    19,    20,    21,    22,    26,
      30,    33,    34,    35,    36,    38,    39,    40,    41,    43,
      45,    46,    47,    48,    49,    50,    51,    52,    25,    37,
      12,    12,    18,    19,    51,     4,     7,     8,    24,    26,
      27,    17,    49,    49,    12,    19,     4,     8,    12,    50,
      51,     7,    53,    23,    28,    42,     3,    12,    23,    51,
      50,    23,    37,    29,    12,    12,     8,    12,    12,    51,
      51,     8,    50,    12,    19,    34,    44,     4,    12,    51,
      50,    12,    12,    24,    26,    26,    27,     4,    50,    12,
      12,    12,    12
};

/* YYR1[RULE-NUM] -- Symbol kind of the left-hand side of rule RULE-NUM.  */
static const yytype_int8 yyr1[] =
{
       0,    31,    32,    32,    33,    33,    33,    33,    33,    33,
      33,    33,    33,    34,    34,    35,    35,    36,    36,    36,
      36,    36,    36,    37,    37,    38,    38,    38,    38,    38,
      38,    39,    40,    40,    40,    40,    40,    40,    40,    40,
      40,    41,    41,    42,    42,    43,    43,    43,    44,    44,
      45,    45,    45,    46,    47,    47,    48,    48,    48,    48,
      48,    48,    49,    49,    50,    50,    50,    51,    51,    51,
      52,    53,    53
};

/* YYR2[RULE-NUM] -- Number of symbols on the right-hand side of rule RULE-NUM.  */
static const yytype_int8 yyr2[] =
{
       0,     2,     0,     2,     1,     1,     1,     1,     1,     1,
       1,     1,     1,     5,     3,     2,     2,     2,     1,     1,
       3,     3,     2,     1,     2,     1,     2,     2,     4,     3,
       2,     5,     3,     5,     1,     5,     2,     4,     2,     1,
       3,     2,     3,     1,     1,     1,     1,     1,     1,     1,
       3,     2,     2,     4,     2,     1,     4,     3,     2,     2,
       3,     1,     1,     1,     1,     1,     1,     1,     1,     1,
       1,     0,     1
};


enum { YYENOMEM = -2 };

#define yyerrok         (yyerrstatus = 0)
#define yyclearin       (yychar = YYEMPTY)

#define YYACCEPT        goto yyacceptlab
#define YYABORT         goto yyabortlab
#define YYERROR         goto yyerrorlab
#define YYNOMEM         goto yyexhaustedlab


#define YYRECOVERING()  (!!yyerrstatus)

#define YYBACKUP(Token, Value)                                    \
  do                                                              \
    if (yychar == YYEMPTY)                                        \
      {                                                           \
        yychar = (Token);                                         \
        yylval = (Value);                                         \
        YYPOPSTACK (yylen);                                       \
        yystate = *yyssp;                                         \
        goto yybackup;                                            \
      }                                                           \
    else                                                          \
      {                                                           \
        yyerror (&yylloc, info, YY_("syntax error: cannot back up")); \
        YYERROR;                                                  \
      }                                                           \
  while (0)

/* Backward compatibility with an undocumented macro.
   Use YYerror or YYUNDEF. */
#define YYERRCODE YYUNDEF

/* YYLLOC_DEFAULT -- Set CURRENT to span from RHS[1] to RHS[N].
   If N is 0, then set CURRENT to the empty location which ends
   the previous symbol: RHS[0] (always defined).  */

#ifndef YYLLOC_DEFAULT
# define YYLLOC_DEFAULT(Current, Rhs, N)                                \
    do                                                                  \
      if (N)                                                            \
        {                                                               \
          (Current).first_line   = YYRHSLOC (Rhs, 1).first_line;        \
          (Current).first_column = YYRHSLOC (Rhs, 1).first_column;      \
          (Current).last_line    = YYRHSLOC (Rhs, N).last_line;         \
          (Current).last_column  = YYRHSLOC (Rhs, N).last_column;       \
        }                                                               \
      else                                                              \
        {                                                               \
          (Current).first_line   = (Current).last_line   =              \
            YYRHSLOC (Rhs, 0).last_line;                                \
          (Current).first_column = (Current).last_column =              \
            YYRHSLOC (Rhs, 0).last_column;                              \
        }                                                               \
    while (0)
#endif

#define YYRHSLOC(Rhs, K) ((Rhs)[K])


/* Enable debugging if requested.  */
#if YYDEBUG

# ifndef YYFPRINTF
#  include <stdio.h> /* INFRINGES ON USER NAME SPACE */
#  define YYFPRINTF fprintf
# endif

# define YYDPRINTF(Args)                        \
do {                                            \
  if (yydebug)                                  \
    YYFPRINTF Args;                             \
} while (0)


/* YYLOCATION_PRINT -- Print the location on the stream.
   This macro was not mandated originally: define only if we know
   we won't break user code: when these are the locations we know.  */

# ifndef YYLOCATION_PRINT

#  if defined YY_LOCATION_PRINT

   /* Temporary convenience wrapper in case some people defined the
      undocumented and private YY_LOCATION_PRINT macros.  */
#   define YYLOCATION_PRINT(File, Loc)  YY_LOCATION_PRINT(File, *(Loc))

#  elif defined YYLTYPE_IS_TRIVIAL && YYLTYPE_IS_TRIVIAL

/* Print *YYLOCP on YYO.  Private, do not rely on its existence. */

YY_ATTRIBUTE_UNUSED
static int
yy_location_print_ (FILE *yyo, YYLTYPE const * const yylocp)
{
  int res = 0;
  int end_col = 0 != yylocp->last_column ? yylocp->last_column - 1 : 0;
  if (0 <= yylocp->first_line)
    {
      res += YYFPRINTF (yyo, "%d", yylocp->first_line);
      if (0 <= yylocp->first_column)
        res += YYFPRINTF (yyo, ".%d", yylocp->first_column);
    }
  if (0 <= yylocp->last_line)
    {
      if (yylocp->first_line < yylocp->last_line)
        {
          res += YYFPRINTF (yyo, "-%d", yylocp->last_line);
          if (0 <= end_col)
            res += YYFPRINTF (yyo, ".%d", end_col);
        }
      else if (0 <= end_col && yylocp->first_column < end_col)
        res += YYFPRINTF (yyo, "-%d", end_col);
    }
  return res;
}

#   define YYLOCATION_PRINT  yy_location_print_

    /* Temporary convenience wrapper in case some people defined the
       undocumented and private YY_LOCATION_PRINT macros.  */
#   define YY_LOCATION_PRINT(File, Loc)  YYLOCATION_PRINT(File, &(Loc))

#  else

#   define YYLOCATION_PRINT(File, Loc) ((void) 0)
    /* Temporary convenience wrapper in case some people defined the
       undocumented and private YY_LOCATION_PRINT macros.  */
#   define YY_LOCATION_PRINT  YYLOCATION_PRINT

#  endif
# endif /* !defined YYLOCATION_PRINT */


# define YY_SYMBOL_PRINT(Title, Kind, Value, Location)                    \
do {                                                                      \
  if (yydebug)                                                            \
    {                                                                     \
      YYFPRINTF (stderr, "%s ", Title);                                   \
      yy_symbol_print (stderr,                                            \
                  Kind, Value, Location, info); \
      YYFPRINTF (stderr, "\n");                                           \
    }                                                                     \
} while (0)


/*-----------------------------------.
| Print this symbol's value on YYO.  |
`-----------------------------------*/

static void
yy_symbol_value_print (FILE *yyo,
                       yysymbol_kind_t yykind, YYSTYPE const * const yyvaluep, YYLTYPE const * const yylocationp, DateInfo* info)
{
  FILE *yyoutput = yyo;
  YY_USE (yyoutput);
  YY_USE (yylocationp);
  YY_USE (info);
  if (!yyvaluep)
    return;
  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  YY_USE (yykind);
  YY_IGNORE_MAYBE_UNINITIALIZED_END
}


/*---------------------------.
| Print this symbol on YYO.  |
`---------------------------*/

static void
yy_symbol_print (FILE *yyo,
                 yysymbol_kind_t yykind, YYSTYPE const * const yyvaluep, YYLTYPE const * const yylocationp, DateInfo* info)
{
  YYFPRINTF (yyo, "%s %s (",
             yykind < YYNTOKENS ? "token" : "nterm", yysymbol_name (yykind));

  YYLOCATION_PRINT (yyo, yylocationp);
  YYFPRINTF (yyo, ": ");
  yy_symbol_value_print (yyo, yykind, yyvaluep, yylocationp, info);
  YYFPRINTF (yyo, ")");
}

/*------------------------------------------------------------------.
| yy_stack_print -- Print the state stack from its BOTTOM up to its |
| TOP (included).                                                   |
`------------------------------------------------------------------*/

static void
yy_stack_print (yy_state_t *yybottom, yy_state_t *yytop)
{
  YYFPRINTF (stderr, "Stack now");
  for (; yybottom <= yytop; yybottom++)
    {
      int yybot = *yybottom;
      YYFPRINTF (stderr, " %d", yybot);
    }
  YYFPRINTF (stderr, "\n");
}

# define YY_STACK_PRINT(Bottom, Top)                            \
do {                                                            \
  if (yydebug)                                                  \
    yy_stack_print ((Bottom), (Top));                           \
} while (0)


/*------------------------------------------------.
| Report that the YYRULE is going to be reduced.  |
`------------------------------------------------*/

static void
yy_reduce_print (yy_state_t *yyssp, YYSTYPE *yyvsp, YYLTYPE *yylsp,
                 int yyrule, DateInfo* info)
{
  int yylno = yyrline[yyrule];
  int yynrhs = yyr2[yyrule];
  int yyi;
  YYFPRINTF (stderr, "Reducing stack by rule %d (line %d):\n",
             yyrule - 1, yylno);
  /* The symbols being reduced.  */
  for (yyi = 0; yyi < yynrhs; yyi++)
    {
      YYFPRINTF (stderr, "   $%d = ", yyi + 1);
      yy_symbol_print (stderr,
                       YY_ACCESSING_SYMBOL (+yyssp[yyi + 1 - yynrhs]),
                       &yyvsp[(yyi + 1) - (yynrhs)],
                       &(yylsp[(yyi + 1) - (yynrhs)]), info);
      YYFPRINTF (stderr, "\n");
    }
}

# define YY_REDUCE_PRINT(Rule)          \
do {                                    \
  if (yydebug)                          \
    yy_reduce_print (yyssp, yyvsp, yylsp, Rule, info); \
} while (0)

/* Nonzero means print parse trace.  It is left uninitialized so that
   multiple parsers can coexist.  */
int yydebug;
#else /* !YYDEBUG */
# define YYDPRINTF(Args) ((void) 0)
# define YY_SYMBOL_PRINT(Title, Kind, Value, Location)
# define YY_STACK_PRINT(Bottom, Top)
# define YY_REDUCE_PRINT(Rule)
#endif /* !YYDEBUG */


/* YYINITDEPTH -- initial size of the parser's stacks.  */
#ifndef YYINITDEPTH
# define YYINITDEPTH 200
#endif

/* YYMAXDEPTH -- maximum size the stacks can grow to (effective only
   if the built-in stack extension method is used).

   Do not make this value too large; the results are undefined if
   YYSTACK_ALLOC_MAXIMUM < YYSTACK_BYTES (YYMAXDEPTH)
   evaluated with infinite-precision integer arithmetic.  */

#ifndef YYMAXDEPTH
# define YYMAXDEPTH 10000
#endif






/*-----------------------------------------------.
| Release the memory associated to this symbol.  |
`-----------------------------------------------*/

static void
yydestruct (const char *yymsg,
            yysymbol_kind_t yykind, YYSTYPE *yyvaluep, YYLTYPE *yylocationp, DateInfo* info)
{
  YY_USE (yyvaluep);
  YY_USE (yylocationp);
  YY_USE (info);
  if (!yymsg)
    yymsg = "Deleting";
  YY_SYMBOL_PRINT (yymsg, yykind, yyvaluep, yylocationp);

  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  YY_USE (yykind);
  YY_IGNORE_MAYBE_UNINITIALIZED_END
}






/*----------.
| yyparse.  |
`----------*/

int
yyparse (DateInfo* info)
{
/* Lookahead token kind.  */
int yychar;


/* The semantic value of the lookahead symbol.  */
/* Default value used for initialization, for pacifying older GCCs
   or non-GCC compilers.  */
YY_INITIAL_VALUE (static YYSTYPE yyval_default;)
YYSTYPE yylval YY_INITIAL_VALUE (= yyval_default);

/* Location data for the lookahead symbol.  */
static YYLTYPE yyloc_default
# if defined YYLTYPE_IS_TRIVIAL && YYLTYPE_IS_TRIVIAL
  = { 1, 1, 1, 1 }
# endif
;
YYLTYPE yylloc = yyloc_default;

    /* Number of syntax errors so far.  */
    int yynerrs = 0;

    yy_state_fast_t yystate = 0;
    /* Number of tokens to shift before error messages enabled.  */
    int yyerrstatus = 0;

    /* Refer to the stacks through separate pointers, to allow yyoverflow
       to reallocate them elsewhere.  */

    /* Their size.  */
    YYPTRDIFF_T yystacksize = YYINITDEPTH;

    /* The state stack: array, bottom, top.  */
    yy_state_t yyssa[YYINITDEPTH];
    yy_state_t *yyss = yyssa;
    yy_state_t *yyssp = yyss;

    /* The semantic value stack: array, bottom, top.  */
    YYSTYPE yyvsa[YYINITDEPTH];
    YYSTYPE *yyvs = yyvsa;
    YYSTYPE *yyvsp = yyvs;

    /* The location stack: array, bottom, top.  */
    YYLTYPE yylsa[YYINITDEPTH];
    YYLTYPE *yyls = yylsa;
    YYLTYPE *yylsp = yyls;

  int yyn;
  /* The return value of yyparse.  */
  int yyresult;
  /* Lookahead symbol kind.  */
  yysymbol_kind_t yytoken = YYSYMBOL_YYEMPTY;
  /* The variables used to return semantic value and location from the
     action routines.  */
  YYSTYPE yyval;
  YYLTYPE yyloc;

  /* The locations where the error started and ended.  */
  YYLTYPE yyerror_range[3];



#define YYPOPSTACK(N)   (yyvsp -= (N), yyssp -= (N), yylsp -= (N))

  /* The number of symbols on the RHS of the reduced rule.
     Keep to zero when no symbol should be popped.  */
  int yylen = 0;

  YYDPRINTF ((stderr, "Starting parse\n"));

  yychar = YYEMPTY; /* Cause a token to be read.  */

  yylsp[0] = yylloc;
  goto yysetstate;


/*------------------------------------------------------------.
| yynewstate -- push a new state, which is found in yystate.  |
`------------------------------------------------------------*/
yynewstate:
  /* In all cases, when you get here, the value and location stacks
     have just been pushed.  So pushing a state here evens the stacks.  */
  yyssp++;


/*--------------------------------------------------------------------.
| yysetstate -- set current state (the top of the stack) to yystate.  |
`--------------------------------------------------------------------*/
yysetstate:
  YYDPRINTF ((stderr, "Entering state %d\n", yystate));
  YY_ASSERT (0 <= yystate && yystate < YYNSTATES);
  YY_IGNORE_USELESS_CAST_BEGIN
  *yyssp = YY_CAST (yy_state_t, yystate);
  YY_IGNORE_USELESS_CAST_END
  YY_STACK_PRINT (yyss, yyssp);

  if (yyss + yystacksize - 1 <= yyssp)
#if !defined yyoverflow && !defined YYSTACK_RELOCATE
    YYNOMEM;
#else
    {
      /* Get the current used size of the three stacks, in elements.  */
      YYPTRDIFF_T yysize = yyssp - yyss + 1;

# if defined yyoverflow
      {
        /* Give user a chance to reallocate the stack.  Use copies of
           these so that the &'s don't force the real ones into
           memory.  */
        yy_state_t *yyss1 = yyss;
        YYSTYPE *yyvs1 = yyvs;
        YYLTYPE *yyls1 = yyls;

        /* Each stack pointer address is followed by the size of the
           data in use in that stack, in bytes.  This used to be a
           conditional around just the two extra args, but that might
           be undefined if yyoverflow is a macro.  */
        yyoverflow (YY_("memory exhausted"),
                    &yyss1, yysize * YYSIZEOF (*yyssp),
                    &yyvs1, yysize * YYSIZEOF (*yyvsp),
                    &yyls1, yysize * YYSIZEOF (*yylsp),
                    &yystacksize);
        yyss = yyss1;
        yyvs = yyvs1;
        yyls = yyls1;
      }
# else /* defined YYSTACK_RELOCATE */
      /* Extend the stack our own way.  */
      if (YYMAXDEPTH <= yystacksize)
        YYNOMEM;
      yystacksize *= 2;
      if (YYMAXDEPTH < yystacksize)
        yystacksize = YYMAXDEPTH;

      {
        yy_state_t *yyss1 = yyss;
        union yyalloc *yyptr =
          YY_CAST (union yyalloc *,
                   YYSTACK_ALLOC (YY_CAST (YYSIZE_T, YYSTACK_BYTES (yystacksize))));
        if (! yyptr)
          YYNOMEM;
        YYSTACK_RELOCATE (yyss_alloc, yyss);
        YYSTACK_RELOCATE (yyvs_alloc, yyvs);
        YYSTACK_RELOCATE (yyls_alloc, yyls);
#  undef YYSTACK_RELOCATE
        if (yyss1 != yyssa)
          YYSTACK_FREE (yyss1);
      }
# endif

      yyssp = yyss + yysize - 1;
      yyvsp = yyvs + yysize - 1;
      yylsp = yyls + yysize - 1;

      YY_IGNORE_USELESS_CAST_BEGIN
      YYDPRINTF ((stderr, "Stack size increased to %ld\n",
                  YY_CAST (long, yystacksize)));
      YY_IGNORE_USELESS_CAST_END

      if (yyss + yystacksize - 1 <= yyssp)
        YYABORT;
    }
#endif /* !defined yyoverflow && !defined YYSTACK_RELOCATE */


  if (yystate == YYFINAL)
    YYACCEPT;

  goto yybackup;


/*-----------.
| yybackup.  |
`-----------*/
yybackup:
  /* Do appropriate processing given the current state.  Read a
     lookahead token if we need one and don't already have one.  */

  /* First try to decide what to do without reference to lookahead token.  */
  yyn = yypact[yystate];
  if (yypact_value_is_default (yyn))
    goto yydefault;

  /* Not known => get a lookahead token if don't already have one.  */

  /* YYCHAR is either empty, or end-of-input, or a valid lookahead.  */
  if (yychar == YYEMPTY)
    {
      YYDPRINTF ((stderr, "Reading a token\n"));
      yychar = yylex (&yylval, &yylloc, info);
    }

  if (yychar <= YYEOF)
    {
      yychar = YYEOF;
      yytoken = YYSYMBOL_YYEOF;
      YYDPRINTF ((stderr, "Now at end of input.\n"));
    }
  else if (yychar == YYerror)
    {
      /* The scanner already issued an error message, process directly
         to error recovery.  But do not keep the error token as
         lookahead, it is too special and may lead us to an endless
         loop in error recovery. */
      yychar = YYUNDEF;
      yytoken = YYSYMBOL_YYerror;
      yyerror_range[1] = yylloc;
      goto yyerrlab1;
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
      if (yytable_value_is_error (yyn))
        goto yyerrlab;
      yyn = -yyn;
      goto yyreduce;
    }

  /* Count tokens shifted since error; after three, turn off error
     status.  */
  if (yyerrstatus)
    yyerrstatus--;

  /* Shift the lookahead token.  */
  YY_SYMBOL_PRINT ("Shifting", yytoken, &yylval, &yylloc);
  yystate = yyn;
  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  *++yyvsp = yylval;
  YY_IGNORE_MAYBE_UNINITIALIZED_END
  *++yylsp = yylloc;

  /* Discard the shifted token.  */
  yychar = YYEMPTY;
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
| yyreduce -- do a reduction.  |
`-----------------------------*/
yyreduce:
  /* yyn is the number of a rule to reduce with.  */
  yylen = yyr2[yyn];

  /* If YYLEN is nonzero, implement the default value of the action:
     '$$ = $1'.

     Otherwise, the following line sets YYVAL to garbage.
     This behavior is undocumented and Bison
     users should not rely upon it.  Assigning to YYVAL
     unconditionally makes the parser a bit smaller, and it avoids a
     GCC warning that YYVAL may be used uninitialized.  */
  yyval = yyvsp[1-yylen];

  /* Default location. */
  YYLLOC_DEFAULT (yyloc, (yylsp - yylen), yylen);
  yyerror_range[1] = yyloc;
  YY_REDUCE_PRINT (yyn);
  switch (yyn)
    {
  case 4: /* item: time  */
               {
	    yyIncrFlags(CLF_TIME);
	}
    break;

  case 5: /* item: zone  */
               {
	    yyIncrFlags(CLF_ZONE);
	}
    break;

  case 6: /* item: date  */
               {
	    yyIncrFlags(CLF_HAVEDATE);
	}
    break;

  case 7: /* item: ordMonth  */
                   {
	    yyIncrFlags(CLF_ORDINALMONTH);
	    info->flags |= CLF_RELCONV;
	}
    break;

  case 8: /* item: day  */
              {
	    yyIncrFlags(CLF_DAYOFWEEK);
	    info->flags |= CLF_RELCONV;
	}
    break;

  case 9: /* item: relspec  */
                  {
	    info->flags |= CLF_RELCONV;
	}
    break;

  case 10: /* item: iso  */
              {
	    yyIncrFlags(CLF_TIME|CLF_HAVEDATE);
	}
    break;

  case 11: /* item: trek  */
               {
	    yyIncrFlags(CLF_TIME|CLF_HAVEDATE);
	    info->flags |= CLF_TREK;
	}
    break;

  case 13: /* iextime: tUNUMBER ':' tUNUMBER ':' tUNUMBER  */
                                             {
	    yyHour = (yyvsp[-4].Number);
	    yyMinutes = (yyvsp[-2].Number);
	    yySeconds = (yyvsp[0].Number);
	}
    break;

  case 14: /* iextime: tUNUMBER ':' tUNUMBER  */
                                {
	    yyHour = (yyvsp[-2].Number);
	    yyMinutes = (yyvsp[0].Number);
	    yySeconds = 0;
	}
    break;

  case 15: /* time: tUNUMBER tMERIDIAN  */
                             {
	    yyHour = (yyvsp[-1].Number);
	    yyMinutes = 0;
	    yySeconds = 0;
	    yyMeridian = (yyvsp[0].Meridian);
	}
    break;

  case 16: /* time: iextime o_merid  */
                          {
	    yyMeridian = (yyvsp[0].Meridian);
	}
    break;

  case 17: /* zone: tZONE tDST  */
                     {
	    yyTimezone = (yyvsp[-1].Number);
	    yyDSTmode = DSTon;
	}
    break;

  case 18: /* zone: tZONE  */
                {
	    yyTimezone = (yyvsp[0].Number);
	    yyDSTmode = DSToff;
	}
    break;

  case 19: /* zone: tDAYZONE  */
                   {
	    yyTimezone = (yyvsp[0].Number);
	    yyDSTmode = DSTon;
	}
    break;

  case 20: /* zone: tZONEwO4 sign INTNUM  */
                               { /* GMT+0100, GMT-1000, etc. */
	    yyTimezone = (yyvsp[-2].Number) - (yyvsp[-1].Number)*((yyvsp[0].Number) % 100 + ((yyvsp[0].Number) / 100) * 60);
	    yyDSTmode = DSToff;
	}
    break;

  case 21: /* zone: tZONEwO2 sign INTNUM  */
                               { /* GMT+1, GMT-10, etc. */
	    yyTimezone = (yyvsp[-2].Number) - (yyvsp[-1].Number)*((yyvsp[0].Number) * 60);
	    yyDSTmode = DSToff;
	}
    break;

  case 22: /* zone: sign INTNUM  */
                      { /* +0100, -0100 */
	    yyTimezone = -(yyvsp[-1].Number)*((yyvsp[0].Number) % 100 + ((yyvsp[0].Number) / 100) * 60);
	    yyDSTmode = DSToff;
	}
    break;

  case 25: /* day: tDAY  */
               {
	    yyDayOrdinal = 1;
	    yyDayOfWeek = (yyvsp[0].Number);
	}
    break;

  case 26: /* day: tDAY comma  */
                     {
	    yyDayOrdinal = 1;
	    yyDayOfWeek = (yyvsp[-1].Number);
	}
    break;

  case 27: /* day: tUNUMBER tDAY  */
                        {
	    yyDayOrdinal = (yyvsp[-1].Number);
	    yyDayOfWeek = (yyvsp[0].Number);
	}
    break;

  case 28: /* day: sign SP tUNUMBER tDAY  */
                                {
	    yyDayOrdinal = (yyvsp[-3].Number) * (yyvsp[-1].Number);
	    yyDayOfWeek = (yyvsp[0].Number);
	}
    break;

  case 29: /* day: sign tUNUMBER tDAY  */
                             {
	    yyDayOrdinal = (yyvsp[-2].Number) * (yyvsp[-1].Number);
	    yyDayOfWeek = (yyvsp[0].Number);
	}
    break;

  case 30: /* day: tNEXT tDAY  */
                     {
	    yyDayOrdinal = 2;
	    yyDayOfWeek = (yyvsp[0].Number);
	}
    break;

  case 31: /* iexdate: tUNUMBER '-' tUNUMBER '-' tUNUMBER  */
                                             {
	    yyMonth = (yyvsp[-2].Number);
	    yyDay = (yyvsp[0].Number);
	    yyYear = (yyvsp[-4].Number);
	}
    break;

  case 32: /* date: tUNUMBER '/' tUNUMBER  */
                                {
	    yyMonth = (yyvsp[-2].Number);
	    yyDay = (yyvsp[0].Number);
	}
    break;

  case 33: /* date: tUNUMBER '/' tUNUMBER '/' tUNUMBER  */
                                             {
	    yyMonth = (yyvsp[-4].Number);
	    yyDay = (yyvsp[-2].Number);
	    yyYear = (yyvsp[0].Number);
	}
    break;

  case 35: /* date: tUNUMBER '-' tMONTH '-' tUNUMBER  */
                                           {
	    yyDay = (yyvsp[-4].Number);
	    yyMonth = (yyvsp[-2].Number);
	    yyYear = (yyvsp[0].Number);
	}
    break;

  case 36: /* date: tMONTH tUNUMBER  */
                          {
	    yyMonth = (yyvsp[-1].Number);
	    yyDay = (yyvsp[0].Number);
	}
    break;

  case 37: /* date: tMONTH tUNUMBER comma tUNUMBER  */
                                         {
	    yyMonth = (yyvsp[-3].Number);
	    yyDay = (yyvsp[-2].Number);
	    yyYear = (yyvsp[0].Number);
	}
    break;

  case 38: /* date: tUNUMBER tMONTH  */
                          {
	    yyMonth = (yyvsp[0].Number);
	    yyDay = (yyvsp[-1].Number);
	}
    break;

  case 39: /* date: tEPOCH  */
                 {
	    yyMonth = 1;
	    yyDay = 1;
	    yyYear = EPOCH;
	}
    break;

  case 40: /* date: tUNUMBER tMONTH tUNUMBER  */
                                   {
	    yyMonth = (yyvsp[-1].Number);
	    yyDay = (yyvsp[-2].Number);
	    yyYear = (yyvsp[0].Number);
	}
    break;

  case 41: /* ordMonth: tNEXT tMONTH  */
                       {
	    yyMonthOrdinalIncr = 1;
	    yyMonthOrdinal = (yyvsp[0].Number);
	}
    break;

  case 42: /* ordMonth: tNEXT tUNUMBER tMONTH  */
                                {
	    yyMonthOrdinalIncr = (yyvsp[-1].Number);
	    yyMonthOrdinal = (yyvsp[0].Number);
	}
    break;

  case 45: /* isodate: tISOBAS8  */
                   { /* YYYYMMDD */
	    yyYear = (yyvsp[0].Number) / 10000;
	    yyMonth = ((yyvsp[0].Number) % 10000)/100;
	    yyDay = (yyvsp[0].Number) % 100;
	}
    break;

  case 46: /* isodate: tISOBAS6  */
                   { /* YYMMDD */
	    yyYear = (yyvsp[0].Number) / 10000;
	    yyMonth = ((yyvsp[0].Number) % 10000)/100;
	    yyDay = (yyvsp[0].Number) % 100;
	}
    break;

  case 48: /* isotime: tISOBAS6  */
                   {
	    yyHour = (yyvsp[0].Number) / 10000;
	    yyMinutes = ((yyvsp[0].Number) % 10000)/100;
	    yySeconds = (yyvsp[0].Number) % 100;
	}
    break;

  case 51: /* iso: tISOBASL tISOBAS6  */
                            { /* YYYYMMDDhhmmss */
	    yyYear = (yyvsp[-1].Number) / 10000;
	    yyMonth = ((yyvsp[-1].Number) % 10000)/100;
	    yyDay = (yyvsp[-1].Number) % 100;
	    yyHour = (yyvsp[0].Number) / 10000;
	    yyMinutes = ((yyvsp[0].Number) % 10000)/100;
	    yySeconds = (yyvsp[0].Number) % 100;
	}
    break;

  case 52: /* iso: tISOBASL tUNUMBER  */
                            { /* YYYYMMDDhhmm */
	    if (yyDigitCount != 4) YYABORT; /* normally unreached */
	    yyYear = (yyvsp[-1].Number) / 10000;
	    yyMonth = ((yyvsp[-1].Number) % 10000)/100;
	    yyDay = (yyvsp[-1].Number) % 100;
	    yyHour = (yyvsp[0].Number) / 100;
	    yyMinutes = ((yyvsp[0].Number) % 100);
	    yySeconds = 0;
	}
    break;

  case 53: /* trek: tSTARDATE INTNUM '.' tUNUMBER  */
                                        {
	    /*
	     * Offset computed year by -377 so that the returned years will be
	     * in a range accessible with a 32 bit clock seconds value.
	     */

	    yyYear = (yyvsp[-2].Number)/1000 + 2323 - 377;
	    yyDay  = 1;
	    yyMonth = 1;
	    yyRelDay += (((yyvsp[-2].Number)%1000)*(365 + IsLeapYear(yyYear)))/1000;
	    yyRelSeconds += (yyvsp[0].Number) * (144LL * 60LL);
	    info->flags |= CLF_RELCONV;
	}
    break;

  case 54: /* relspec: relunits tAGO  */
                        {
	    yyRelSeconds *= -1;
	    yyRelMonth *= -1;
	    yyRelDay *= -1;
	}
    break;

  case 56: /* relunits: sign SP INTNUM unit  */
                               {
	    *yyRelPointer += (yyvsp[-3].Number) * (yyvsp[-1].Number) * (yyvsp[0].Number);
	}
    break;

  case 57: /* relunits: sign INTNUM unit  */
                           {
	    *yyRelPointer += (yyvsp[-2].Number) * (yyvsp[-1].Number) * (yyvsp[0].Number);
	}
    break;

  case 58: /* relunits: INTNUM unit  */
                      {
	    *yyRelPointer += (yyvsp[-1].Number) * (yyvsp[0].Number);
	}
    break;

  case 59: /* relunits: tNEXT unit  */
                     {
	    *yyRelPointer += (yyvsp[0].Number);
	}
    break;

  case 60: /* relunits: tNEXT INTNUM unit  */
                            {
	    *yyRelPointer += (yyvsp[-1].Number) * (yyvsp[0].Number);
	}
    break;

  case 61: /* relunits: unit  */
               {
	    *yyRelPointer += (yyvsp[0].Number);
	}
    break;

  case 62: /* sign: '-'  */
              {
	    (yyval.Number) = -1;
	}
    break;

  case 63: /* sign: '+'  */
              {
	    (yyval.Number) =  1;
	}
    break;

  case 64: /* unit: tSEC_UNIT  */
                    {
	    (yyval.Number) = (yyvsp[0].Number);
	    yyRelPointer = &yyRelSeconds;
	    /* no flag CLF_RELCONV needed by seconds */
	}
    break;

  case 65: /* unit: tDAY_UNIT  */
                    {
	    (yyval.Number) = (yyvsp[0].Number);
	    yyRelPointer = &yyRelDay;
	    info->flags |= CLF_RELCONV;
	}
    break;

  case 66: /* unit: tMONTH_UNIT  */
                      {
	    (yyval.Number) = (yyvsp[0].Number);
	    yyRelPointer = &yyRelMonth;
	    info->flags |= CLF_RELCONV;
	}
    break;

  case 67: /* INTNUM: tUNUMBER  */
                   {
	    (yyval.Number) = (yyvsp[0].Number);
	}
    break;

  case 68: /* INTNUM: tISOBAS6  */
                   {
	    (yyval.Number) = (yyvsp[0].Number);
	}
    break;

  case 69: /* INTNUM: tISOBAS8  */
                   {
	    (yyval.Number) = (yyvsp[0].Number);
	}
    break;

  case 70: /* numitem: tUNUMBER  */
                   {
	    if ((info->flags & (CLF_TIME|CLF_HAVEDATE|CLF_TREK)) == (CLF_TIME|CLF_HAVEDATE)) {
		yyYear = (yyvsp[0].Number);
	    } else {
		yyIncrFlags(CLF_TIME);
		if (yyDigitCount <= 2) {
		    yyHour = (yyvsp[0].Number);
		    yyMinutes = 0;
		} else {
		    yyHour = (yyvsp[0].Number) / 100;
		    yyMinutes = (yyvsp[0].Number) % 100;
		}
		yySeconds = 0;
		yyMeridian = MER24;
	    }
	}
    break;

  case 71: /* o_merid: %empty  */
                     {
	    (yyval.Meridian) = MER24;
	}
    break;

  case 72: /* o_merid: tMERIDIAN  */
                    {
	    (yyval.Meridian) = (yyvsp[0].Meridian);
	}
    break;



      default: break;
    }
  /* User semantic actions sometimes alter yychar, and that requires
     that yytoken be updated with the new translation.  We take the
     approach of translating immediately before every use of yytoken.
     One alternative is translating here after every semantic action,
     but that translation would be missed if the semantic action invokes
     YYABORT, YYACCEPT, or YYERROR immediately after altering yychar or
     if it invokes YYBACKUP.  In the case of YYABORT or YYACCEPT, an
     incorrect destructor might then be invoked immediately.  In the
     case of YYERROR or YYBACKUP, subsequent parser actions might lead
     to an incorrect destructor call or verbose syntax error message
     before the lookahead is translated.  */
  YY_SYMBOL_PRINT ("-> $$ =", YY_CAST (yysymbol_kind_t, yyr1[yyn]), &yyval, &yyloc);

  YYPOPSTACK (yylen);
  yylen = 0;

  *++yyvsp = yyval;
  *++yylsp = yyloc;

  /* Now 'shift' the result of the reduction.  Determine what state
     that goes to, based on the state we popped back to and the rule
     number reduced by.  */
  {
    const int yylhs = yyr1[yyn] - YYNTOKENS;
    const int yyi = yypgoto[yylhs] + *yyssp;
    yystate = (0 <= yyi && yyi <= YYLAST && yycheck[yyi] == *yyssp
               ? yytable[yyi]
               : yydefgoto[yylhs]);
  }

  goto yynewstate;


/*--------------------------------------.
| yyerrlab -- here on detecting error.  |
`--------------------------------------*/
yyerrlab:
  /* Make sure we have latest lookahead translation.  See comments at
     user semantic actions for why this is necessary.  */
  yytoken = yychar == YYEMPTY ? YYSYMBOL_YYEMPTY : YYTRANSLATE (yychar);
  /* If not already recovering from an error, report this error.  */
  if (!yyerrstatus)
    {
      ++yynerrs;
      yyerror (&yylloc, info, YY_("syntax error"));
    }

  yyerror_range[1] = yylloc;
  if (yyerrstatus == 3)
    {
      /* If just tried and failed to reuse lookahead token after an
         error, discard it.  */

      if (yychar <= YYEOF)
        {
          /* Return failure if at end of input.  */
          if (yychar == YYEOF)
            YYABORT;
        }
      else
        {
          yydestruct ("Error: discarding",
                      yytoken, &yylval, &yylloc, info);
          yychar = YYEMPTY;
        }
    }

  /* Else will try to reuse lookahead token after shifting the error
     token.  */
  goto yyerrlab1;


/*---------------------------------------------------.
| yyerrorlab -- error raised explicitly by YYERROR.  |
`---------------------------------------------------*/
yyerrorlab:
  /* Pacify compilers when the user code never invokes YYERROR and the
     label yyerrorlab therefore never appears in user code.  */
  if (0)
    YYERROR;
  ++yynerrs;

  /* Do not reclaim the symbols of the rule whose action triggered
     this YYERROR.  */
  YYPOPSTACK (yylen);
  yylen = 0;
  YY_STACK_PRINT (yyss, yyssp);
  yystate = *yyssp;
  goto yyerrlab1;


/*-------------------------------------------------------------.
| yyerrlab1 -- common code for both syntax error and YYERROR.  |
`-------------------------------------------------------------*/
yyerrlab1:
  yyerrstatus = 3;      /* Each real token shifted decrements this.  */

  /* Pop stack until we find a state that shifts the error token.  */
  for (;;)
    {
      yyn = yypact[yystate];
      if (!yypact_value_is_default (yyn))
        {
          yyn += YYSYMBOL_YYerror;
          if (0 <= yyn && yyn <= YYLAST && yycheck[yyn] == YYSYMBOL_YYerror)
            {
              yyn = yytable[yyn];
              if (0 < yyn)
                break;
            }
        }

      /* Pop the current state because it cannot handle the error token.  */
      if (yyssp == yyss)
        YYABORT;

      yyerror_range[1] = *yylsp;
      yydestruct ("Error: popping",
                  YY_ACCESSING_SYMBOL (yystate), yyvsp, yylsp, info);
      YYPOPSTACK (1);
      yystate = *yyssp;
      YY_STACK_PRINT (yyss, yyssp);
    }

  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  *++yyvsp = yylval;
  YY_IGNORE_MAYBE_UNINITIALIZED_END

  yyerror_range[2] = yylloc;
  ++yylsp;
  YYLLOC_DEFAULT (*yylsp, yyerror_range, 2);

  /* Shift the error token.  */
  YY_SYMBOL_PRINT ("Shifting", YY_ACCESSING_SYMBOL (yyn), yyvsp, yylsp);

  yystate = yyn;
  goto yynewstate;


/*-------------------------------------.
| yyacceptlab -- YYACCEPT comes here.  |
`-------------------------------------*/
yyacceptlab:
  yyresult = 0;
  goto yyreturnlab;


/*-----------------------------------.
| yyabortlab -- YYABORT comes here.  |
`-----------------------------------*/
yyabortlab:
  yyresult = 1;
  goto yyreturnlab;


/*-----------------------------------------------------------.
| yyexhaustedlab -- YYNOMEM (memory exhaustion) comes here.  |
`-----------------------------------------------------------*/
yyexhaustedlab:
  yyerror (&yylloc, info, YY_("memory exhausted"));
  yyresult = 2;
  goto yyreturnlab;


/*----------------------------------------------------------.
| yyreturnlab -- parsing is finished, clean up and return.  |
`----------------------------------------------------------*/
yyreturnlab:
  if (yychar != YYEMPTY)
    {
      /* Make sure we have latest lookahead translation.  See comments at
         user semantic actions for why this is necessary.  */
      yytoken = YYTRANSLATE (yychar);
      yydestruct ("Cleanup: discarding lookahead",
                  yytoken, &yylval, &yylloc, info);
    }
  /* Do not reclaim the symbols of the rule whose action triggered
     this YYABORT or YYACCEPT.  */
  YYPOPSTACK (yylen);
  YY_STACK_PRINT (yyss, yyssp);
  while (yyssp != yyss)
    {
      yydestruct ("Cleanup: popping",
                  YY_ACCESSING_SYMBOL (+*yyssp), yyvsp, yylsp, info);
      YYPOPSTACK (1);
    }
#ifndef yyoverflow
  if (yyss != yyssa)
    YYSTACK_FREE (yyss);
#endif

  return yyresult;
}


/*
 * Month and day table.
 */

static const TABLE MonthDayTable[] = {
    { "january",	tMONTH,	 1 },
    { "february",	tMONTH,	 2 },
    { "march",		tMONTH,	 3 },
    { "april",		tMONTH,	 4 },
    { "may",		tMONTH,	 5 },
    { "june",		tMONTH,	 6 },
    { "july",		tMONTH,	 7 },
    { "august",		tMONTH,	 8 },
    { "september",	tMONTH,	 9 },
    { "sept",		tMONTH,	 9 },
    { "october",	tMONTH, 10 },
    { "november",	tMONTH, 11 },
    { "december",	tMONTH, 12 },
    { "sunday",		tDAY, 7 },
    { "monday",		tDAY, 1 },
    { "tuesday",	tDAY, 2 },
    { "tues",		tDAY, 2 },
    { "wednesday",	tDAY, 3 },
    { "wednes",		tDAY, 3 },
    { "thursday",	tDAY, 4 },
    { "thur",		tDAY, 4 },
    { "thurs",		tDAY, 4 },
    { "friday",		tDAY, 5 },
    { "saturday",	tDAY, 6 },
    { NULL, 0, 0 }
};

/*
 * Time units table.
 */

static const TABLE UnitsTable[] = {
    { "year",		tMONTH_UNIT,	12 },
    { "month",		tMONTH_UNIT,	 1 },
    { "fortnight",	tDAY_UNIT,	14 },
    { "week",		tDAY_UNIT,	 7 },
    { "day",		tDAY_UNIT,	 1 },
    { "hour",		tSEC_UNIT, 60 * 60 },
    { "minute",		tSEC_UNIT,	60 },
    { "min",		tSEC_UNIT,	60 },
    { "second",		tSEC_UNIT,	 1 },
    { "sec",		tSEC_UNIT,	 1 },
    { NULL, 0, 0 }
};

/*
 * Assorted relative-time words.
 */

static const TABLE OtherTable[] = {
    { "tomorrow",	tDAY_UNIT,	1 },
    { "yesterday",	tDAY_UNIT,	-1 },
    { "today",		tDAY_UNIT,	0 },
    { "now",		tSEC_UNIT,	0 },
    { "last",		tUNUMBER,	-1 },
    { "this",		tSEC_UNIT,	0 },
    { "next",		tNEXT,		1 },
    { "ago",		tAGO,		1 },
    { "epoch",		tEPOCH,		0 },
    { "stardate",	tSTARDATE,	0 },
    { NULL, 0, 0 }
};

/*
 * The timezone table. (Note: This table was modified to not use any floating
 * point constants to work around an SGI compiler bug).
 */

static const TABLE TimezoneTable[] = {
    { "gmt",	tZONE,	   HOUR( 0) },	    /* Greenwich Mean */
    { "ut",	tZONE,	   HOUR( 0) },	    /* Universal (Coordinated) */
    { "utc",	tZONE,	   HOUR( 0) },
    { "uct",	tZONE,	   HOUR( 0) },	    /* Universal Coordinated Time */
    { "wet",	tZONE,	   HOUR( 0) },	    /* Western European */
    { "bst",	tDAYZONE,  HOUR( 0) },	    /* British Summer */
    { "wat",	tZONE,	   HOUR( 1) },	    /* West Africa */
    { "at",	tZONE,	   HOUR( 2) },	    /* Azores */
#if	0
    /* For completeness.  BST is also British Summer, and GST is
     * also Guam Standard. */
    { "bst",	tZONE,	   HOUR( 3) },	    /* Brazil Standard */
    { "gst",	tZONE,	   HOUR( 3) },	    /* Greenland Standard */
#endif
    { "nft",	tZONE,	   HOUR( 7/2) },    /* Newfoundland */
    { "nst",	tZONE,	   HOUR( 7/2) },    /* Newfoundland Standard */
    { "ndt",	tDAYZONE,  HOUR( 7/2) },    /* Newfoundland Daylight */
    { "ast",	tZONE,	   HOUR( 4) },	    /* Atlantic Standard */
    { "adt",	tDAYZONE,  HOUR( 4) },	    /* Atlantic Daylight */
    { "est",	tZONE,	   HOUR( 5) },	    /* Eastern Standard */
    { "edt",	tDAYZONE,  HOUR( 5) },	    /* Eastern Daylight */
    { "cst",	tZONE,	   HOUR( 6) },	    /* Central Standard */
    { "cdt",	tDAYZONE,  HOUR( 6) },	    /* Central Daylight */
    { "mst",	tZONE,	   HOUR( 7) },	    /* Mountain Standard */
    { "mdt",	tDAYZONE,  HOUR( 7) },	    /* Mountain Daylight */
    { "pst",	tZONE,	   HOUR( 8) },	    /* Pacific Standard */
    { "pdt",	tDAYZONE,  HOUR( 8) },	    /* Pacific Daylight */
    { "yst",	tZONE,	   HOUR( 9) },	    /* Yukon Standard */
    { "ydt",	tDAYZONE,  HOUR( 9) },	    /* Yukon Daylight */
    { "akst",	tZONE,	   HOUR( 9) },	    /* Alaska Standard */
    { "akdt",	tDAYZONE,  HOUR( 9) },	    /* Alaska Daylight */
    { "hst",	tZONE,	   HOUR(10) },	    /* Hawaii Standard */
    { "hdt",	tDAYZONE,  HOUR(10) },	    /* Hawaii Daylight */
    { "cat",	tZONE,	   HOUR(10) },	    /* Central Alaska */
    { "ahst",	tZONE,	   HOUR(10) },	    /* Alaska-Hawaii Standard */
    { "nt",	tZONE,	   HOUR(11) },	    /* Nome */
    { "idlw",	tZONE,	   HOUR(12) },	    /* International Date Line West */
    { "cet",	tZONE,	  -HOUR( 1) },	    /* Central European */
    { "cest",	tDAYZONE, -HOUR( 1) },	    /* Central European Summer */
    { "met",	tZONE,	  -HOUR( 1) },	    /* Middle European */
    { "mewt",	tZONE,	  -HOUR( 1) },	    /* Middle European Winter */
    { "mest",	tDAYZONE, -HOUR( 1) },	    /* Middle European Summer */
    { "swt",	tZONE,	  -HOUR( 1) },	    /* Swedish Winter */
    { "sst",	tDAYZONE, -HOUR( 1) },	    /* Swedish Summer */
    { "fwt",	tZONE,	  -HOUR( 1) },	    /* French Winter */
    { "fst",	tDAYZONE, -HOUR( 1) },	    /* French Summer */
    { "eet",	tZONE,	  -HOUR( 2) },	    /* Eastern Europe, USSR Zone 1 */
    { "bt",	tZONE,	  -HOUR( 3) },	    /* Baghdad, USSR Zone 2 */
    { "it",	tZONE,	  -HOUR( 7/2) },    /* Iran */
    { "zp4",	tZONE,	  -HOUR( 4) },	    /* USSR Zone 3 */
    { "zp5",	tZONE,	  -HOUR( 5) },	    /* USSR Zone 4 */
    { "ist",	tZONE,	  -HOUR(11/2) },    /* Indian Standard */
    { "zp6",	tZONE,	  -HOUR( 6) },	    /* USSR Zone 5 */
#if	0
    /* For completeness.  NST is also Newfoundland Standard, and SST is
     * also Swedish Summer. */
    { "nst",	tZONE,	  -HOUR(13/2) },    /* North Sumatra */
    { "sst",	tZONE,	  -HOUR( 7) },	    /* South Sumatra, USSR Zone 6 */
#endif	/* 0 */
    { "wast",	tZONE,	  -HOUR( 7) },	    /* West Australian Standard */
    { "wadt",	tDAYZONE, -HOUR( 7) },	    /* West Australian Daylight */
    { "jt",	tZONE,	  -HOUR(15/2) },    /* Java (3pm in Cronusland!) */
    { "cct",	tZONE,	  -HOUR( 8) },	    /* China Coast, USSR Zone 7 */
    { "jst",	tZONE,	  -HOUR( 9) },	    /* Japan Standard, USSR Zone 8 */
    { "jdt",	tDAYZONE, -HOUR( 9) },	    /* Japan Daylight */
    { "kst",	tZONE,	  -HOUR( 9) },	    /* Korea Standard */
    { "kdt",	tDAYZONE, -HOUR( 9) },	    /* Korea Daylight */
    { "cast",	tZONE,	  -HOUR(19/2) },    /* Central Australian Standard */
    { "cadt",	tDAYZONE, -HOUR(19/2) },    /* Central Australian Daylight */
    { "east",	tZONE,	  -HOUR(10) },	    /* Eastern Australian Standard */
    { "eadt",	tDAYZONE, -HOUR(10) },	    /* Eastern Australian Daylight */
    { "gst",	tZONE,	  -HOUR(10) },	    /* Guam Standard, USSR Zone 9 */
    { "nzt",	tZONE,	  -HOUR(12) },	    /* New Zealand */
    { "nzst",	tZONE,	  -HOUR(12) },	    /* New Zealand Standard */
    { "nzdt",	tDAYZONE, -HOUR(12) },	    /* New Zealand Daylight */
    { "idle",	tZONE,	  -HOUR(12) },	    /* International Date Line East */
    /* ADDED BY Marco Nijdam */
    { "dst",	tDST,	  HOUR( 0) },	    /* DST on (hour is ignored) */
    /* End ADDED */
    { NULL, 0, 0 }
};

/*
 * Military timezone table.
 */

static const TABLE MilitaryTable[] = {
    { "a",	tZONE,	-HOUR( 1) },
    { "b",	tZONE,	-HOUR( 2) },
    { "c",	tZONE,	-HOUR( 3) },
    { "d",	tZONE,	-HOUR( 4) },
    { "e",	tZONE,	-HOUR( 5) },
    { "f",	tZONE,	-HOUR( 6) },
    { "g",	tZONE,	-HOUR( 7) },
    { "h",	tZONE,	-HOUR( 8) },
    { "i",	tZONE,	-HOUR( 9) },
    { "k",	tZONE,	-HOUR(10) },
    { "l",	tZONE,	-HOUR(11) },
    { "m",	tZONE,	-HOUR(12) },
    { "n",	tZONE,	HOUR(  1) },
    { "o",	tZONE,	HOUR(  2) },
    { "p",	tZONE,	HOUR(  3) },
    { "q",	tZONE,	HOUR(  4) },
    { "r",	tZONE,	HOUR(  5) },
    { "s",	tZONE,	HOUR(  6) },
    { "t",	tZONE,	HOUR(  7) },
    { "u",	tZONE,	HOUR(  8) },
    { "v",	tZONE,	HOUR(  9) },
    { "w",	tZONE,	HOUR( 10) },
    { "x",	tZONE,	HOUR( 11) },
    { "y",	tZONE,	HOUR( 12) },
    { "z",	tZONE,	HOUR( 0) },
    { NULL, 0, 0 }
};

static inline const char *
bypassSpaces(
    const char *s)
{
    while (TclIsSpaceProc(*s)) {
	s++;
    }
    return s;
}

/*
 * Dump error messages in the bit bucket.
 */

static void
TclDateerror(
    YYLTYPE* location,
    DateInfo* infoPtr,
    const char *s)
{
    Tcl_Obj* t;
    if (!infoPtr->messages) {
	TclNewObj(infoPtr->messages);
    }
    Tcl_AppendToObj(infoPtr->messages, infoPtr->separatrix, -1);
    Tcl_AppendToObj(infoPtr->messages, s, -1);
    Tcl_AppendToObj(infoPtr->messages, " (characters ", -1);
    TclNewIntObj(t, location->first_column);
    Tcl_IncrRefCount(t);
    Tcl_AppendObjToObj(infoPtr->messages, t);
    Tcl_DecrRefCount(t);
    Tcl_AppendToObj(infoPtr->messages, "-", -1);
    TclNewIntObj(t, location->last_column);
    Tcl_IncrRefCount(t);
    Tcl_AppendObjToObj(infoPtr->messages, t);
    Tcl_DecrRefCount(t);
    Tcl_AppendToObj(infoPtr->messages, ")", -1);
    infoPtr->separatrix = "\n";
}

int
TclToSeconds(
    int Hours,
    int Minutes,
    int Seconds,
    MERIDIAN Meridian)
{
    switch (Meridian) {
    case MER24:
	return (Hours * 60 + Minutes) * 60 + Seconds;
    case MERam:
	return (((Hours / 24) * 24 + (Hours % 12)) * 60 + Minutes) * 60 + Seconds;
    case MERpm:
	return (((Hours / 24) * 24 + (Hours % 12) + 12) * 60 + Minutes) * 60 + Seconds;
    }
    return -1;			/* Should never be reached */
}

static int
LookupWord(
    YYSTYPE* yylvalPtr,
    char *buff)
{
    char *p;
    char *q;
    const TABLE *tp;
    int i, abbrev;

    /*
     * Make it lowercase.
     */

    Tcl_UtfToLower(buff);

    if (*buff == 'a' && (strcmp(buff, "am") == 0 || strcmp(buff, "a.m.") == 0)) {
	yylvalPtr->Meridian = MERam;
	return tMERIDIAN;
    }
    if (*buff == 'p' && (strcmp(buff, "pm") == 0 || strcmp(buff, "p.m.") == 0)) {
	yylvalPtr->Meridian = MERpm;
	return tMERIDIAN;
    }

    /*
     * See if we have an abbreviation for a month.
     */

    if (strlen(buff) == 3) {
	abbrev = 1;
    } else if (strlen(buff) == 4 && buff[3] == '.') {
	abbrev = 1;
	buff[3] = '\0';
    } else {
	abbrev = 0;
    }

    for (tp = MonthDayTable; tp->name; tp++) {
	if (abbrev) {
	    if (strncmp(buff, tp->name, 3) == 0) {
		yylvalPtr->Number = tp->value;
		return tp->type;
	    }
	} else if (strcmp(buff, tp->name) == 0) {
	    yylvalPtr->Number = tp->value;
	    return tp->type;
	}
    }

    for (tp = TimezoneTable; tp->name; tp++) {
	if (strcmp(buff, tp->name) == 0) {
	    yylvalPtr->Number = tp->value;
	    return tp->type;
	}
    }

    for (tp = UnitsTable; tp->name; tp++) {
	if (strcmp(buff, tp->name) == 0) {
	    yylvalPtr->Number = tp->value;
	    return tp->type;
	}
    }

    /*
     * Strip off any plural and try the units table again.
     */

    i = strlen(buff) - 1;
    if (i > 0 && buff[i] == 's') {
	buff[i] = '\0';
	for (tp = UnitsTable; tp->name; tp++) {
	    if (strcmp(buff, tp->name) == 0) {
		yylvalPtr->Number = tp->value;
		return tp->type;
	    }
	}
    }

    for (tp = OtherTable; tp->name; tp++) {
	if (strcmp(buff, tp->name) == 0) {
	    yylvalPtr->Number = tp->value;
	    return tp->type;
	}
    }

    /*
     * Military timezones.
     */

    if (buff[1] == '\0' && !(*buff & 0x80)
	    && isalpha(UCHAR(*buff))) {			/* INTL: ISO only */
	for (tp = MilitaryTable; tp->name; tp++) {
	    if (strcmp(buff, tp->name) == 0) {
		yylvalPtr->Number = tp->value;
		return tp->type;
	    }
	}
    }

    /*
     * Drop out any periods and try the timezone table again.
     */

    for (i = 0, p = q = buff; *q; q++) {
	if (*q != '.') {
	    *p++ = *q;
	} else {
	    i++;
	}
    }
    *p = '\0';
    if (i) {
	for (tp = TimezoneTable; tp->name; tp++) {
	    if (strcmp(buff, tp->name) == 0) {
		yylvalPtr->Number = tp->value;
		return tp->type;
	    }
	}
    }

    return tID;
}

static int
TclDatelex(
    YYSTYPE* yylvalPtr,
    YYLTYPE* location,
    DateInfo *info)
{
    char c;
    char *p;
    char buff[20];
    int Count;
    const char *tokStart;

    location->first_column = yyInput - info->dateStart;
    for ( ; ; ) {

	if (isspace(UCHAR(*yyInput))) {
	    yyInput = bypassSpaces(yyInput);
	    /* ignore space at end of text and before some words */
	    c = *yyInput;
	    if (c != '\0' && !isalpha(UCHAR(c))) {
		return SP;
	    }
	}
	tokStart = yyInput;

	if (isdigit(UCHAR(c = *yyInput))) { /* INTL: digit */

	    /*
	     * Count the number of digits.
	     */
	    p = (char *)yyInput;
	    while (isdigit(UCHAR(*++p))) {};
	    yyDigitCount = p - yyInput;
	    /*
	     * A number with 12 or 14 digits is considered an ISO 8601 date.
	     */
	    if (yyDigitCount == 14 || yyDigitCount == 12) {
		/* long form of ISO 8601 (without separator), either
		 * YYYYMMDDhhmmss or YYYYMMDDhhmm, so reduce to date
		 * (8 chars is isodate) */
		p = (char *)yyInput+8;
		if (TclAtoWIe(&yylvalPtr->Number, yyInput, p, 1) != TCL_OK) {
		    return tID; /* overflow*/
		}
		yyDigitCount = 8;
		yyInput = p;
		location->last_column = yyInput - info->dateStart - 1;
		return tISOBASL;
	    }
	    /*
	     * Convert the string into a number
	     */
	    if (TclAtoWIe(&yylvalPtr->Number, yyInput, p, 1) != TCL_OK) {
		return tID; /* overflow*/
	    }
	    yyInput = p;
	    /*
	     * A number with 6 or more digits is considered an ISO 8601 base.
	     */
	    location->last_column = yyInput - info->dateStart - 1;
	    if (yyDigitCount >= 6) {
		if (yyDigitCount == 8) {
		    return tISOBAS8;
		}
		if (yyDigitCount == 6) {
		    return tISOBAS6;
		}
	    }
	    /* ignore spaces after digits (optional) */
	    yyInput = bypassSpaces(yyInput);
	    return tUNUMBER;
	}
	if (!(c & 0x80) && isalpha(UCHAR(c))) {		  /* INTL: ISO only. */
	    int ret;
	    for (p = buff; isalpha(UCHAR(c = *yyInput++)) /* INTL: ISO only. */
		     || c == '.'; ) {
		if (p < &buff[sizeof(buff) - 1]) {
		    *p++ = c;
		}
	    }
	    *p = '\0';
	    yyInput--;
	    location->last_column = yyInput - info->dateStart - 1;
	    ret = LookupWord(yylvalPtr, buff);
	    /*
	     * lookahead:
	     *	for spaces to consider word boundaries (for instance
	     *	literal T in isodateTisotimeZ is not a TZ, but Z is UTC);
	     *	for +/- digit, to differentiate between "GMT+1000 day" and "GMT +1000 day";
	     * bypass spaces after token (but ignore by TZ+OFFS), because should
	     * recognize next SP token, if TZ only.
	     */
	    if (ret == tZONE || ret == tDAYZONE) {
		c = *yyInput;
		if (isdigit(UCHAR(c))) { /* literal not a TZ  */
		    yyInput = tokStart;
		    return *yyInput++;
		}
		if ((c == '+' || c == '-') && isdigit(UCHAR(*(yyInput+1)))) {
		    if ( !isdigit(UCHAR(*(yyInput+2)))
		      || !isdigit(UCHAR(*(yyInput+3)))) {
			/* GMT+1, GMT-10, etc. */
			return tZONEwO2;
		    }
		    if ( isdigit(UCHAR(*(yyInput+4)))
		      && !isdigit(UCHAR(*(yyInput+5)))) {
			/* GMT+1000, etc. */
			return tZONEwO4;
		    }
		}
	    }
	    yyInput = bypassSpaces(yyInput);
	    return ret;

	}
	if (c != '(') {
	    location->last_column = yyInput - info->dateStart;
	    return *yyInput++;
	}
	Count = 0;
	do {
	    c = *yyInput++;
	    if (c == '\0') {
		location->last_column = yyInput - info->dateStart - 1;
		return c;
	    } else if (c == '(') {
		Count++;
	    } else if (c == ')') {
		Count--;
	    }
	} while (Count > 0);
    }
}

int
TclClockFreeScan(
    Tcl_Interp *interp,		/* Tcl interpreter */
    DateInfo *info)		/* Input and result parameters */
{
    int status;

  #if YYDEBUG
    /* enable debugging if compiled with YYDEBUG */
    yydebug = 1;
  #endif

    /*
     * yyInput = stringToParse;
     *
     * ClockInitDateInfo(info) should be executed to pre-init info;
     */

    yyDSTmode = DSTmaybe;

    info->separatrix = "";

    info->dateStart = yyInput;

    /* ignore spaces at begin */
    yyInput = bypassSpaces(yyInput);

    /* parse */
    status = yyparse(info);
    if (status == 1) {
	const char *msg = NULL;
	if (info->errFlags & CLF_HAVEDATE) {
	    msg = "more than one date in string";
	} else if (info->errFlags & CLF_TIME) {
	    msg = "more than one time of day in string";
	} else if (info->errFlags & CLF_ZONE) {
	    msg = "more than one time zone in string";
	} else if (info->errFlags & CLF_DAYOFWEEK) {
	    msg = "more than one weekday in string";
	} else if (info->errFlags & CLF_ORDINALMONTH) {
	    msg = "more than one ordinal month in string";
	}
	if (msg) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(msg, -1));
	    Tcl_SetErrorCode(interp, "TCL", "VALUE", "DATE", "MULTIPLE", (char *)NULL);
	} else {
	    Tcl_SetObjResult(interp,
		info->messages ? info->messages : Tcl_NewObj());
	    info->messages = NULL;
	    Tcl_SetErrorCode(interp, "TCL", "VALUE", "DATE", "PARSE", (char *)NULL);
	}
	status = TCL_ERROR;
    } else if (status == 2) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("memory exhausted", -1));
	Tcl_SetErrorCode(interp, "TCL", "MEMORY", (char *)NULL);
	status = TCL_ERROR;
    } else if (status != 0) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("Unknown status returned "
						  "from date parser. Please "
						  "report this error as a "
						  "bug in Tcl.", -1));
	Tcl_SetErrorCode(interp, "TCL", "BUG", (char *)NULL);
	status = TCL_ERROR;
    }
    if (info->messages) {
	Tcl_DecrRefCount(info->messages);
    }
    return status;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
