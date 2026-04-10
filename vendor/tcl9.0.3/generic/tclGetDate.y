/*
 * tclGetDate.y --
 *
 *	Contains yacc grammar for parsing date and time strings. The output of
 *	this file should be the file tclDate.c which is used directly in the
 *	Tcl sources. Note that this file is largely obsolete in Tcl 8.5; it is
 *	only used when doing free-form date parsing, an ill-defined process
 *	anyway.
 *
 * Copyright © 1992-1995 Karl Lehenbauer & Mark Diekhans.
 * Copyright © 1995-1997 Sun Microsystems, Inc.
 * Copyright © 2015 Sergey G. Brester aka sebres.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

%parse-param {DateInfo* info}
%lex-param {DateInfo* info}
%define api.pure
 /* %error-verbose would be nice, but our token names are meaningless */
%locations

%{
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

%}

%union {
    Tcl_WideInt Number;
    MERIDIAN Meridian;
}

%{

/*
 * Prototypes of internal functions.
 */

static int		LookupWord(YYSTYPE* yylvalPtr, char *buff);
static void		TclDateerror(YYLTYPE* location,
				     DateInfo* info, const char *s);
static int		TclDatelex(YYSTYPE* yylvalPtr, YYLTYPE* location,
				   DateInfo* info);
MODULE_SCOPE int	yyparse(DateInfo*);

%}

%token	tAGO
%token	tDAY
%token	tDAYZONE
%token	tID
%token	tMERIDIAN
%token	tMONTH
%token	tMONTH_UNIT
%token	tSTARDATE
%token	tSEC_UNIT
%token	tUNUMBER
%token	tZONE
%token	tZONEwO4
%token	tZONEwO2
%token	tEPOCH
%token	tDST
%token	tISOBAS8
%token	tISOBAS6
%token	tISOBASL
%token	tDAY_UNIT
%token	tNEXT
%token	SP

%type	<Number>	tDAY
%type	<Number>	tDAYZONE
%type	<Number>	tMONTH
%type	<Number>	tMONTH_UNIT
%type	<Number>	tDST
%type	<Number>	tSEC_UNIT
%type	<Number>	tUNUMBER
%type	<Number>	INTNUM
%type	<Number>	tZONE
%type	<Number>	tZONEwO4
%type	<Number>	tZONEwO2
%type	<Number>	tISOBAS8
%type	<Number>	tISOBAS6
%type	<Number>	tISOBASL
%type	<Number>	tDAY_UNIT
%type	<Number>	unit
%type	<Number>	sign
%type	<Number>	tNEXT
%type	<Number>	tSTARDATE
%type	<Meridian>	tMERIDIAN
%type	<Meridian>	o_merid

%%

spec	: /* NULL */
	| spec item
	/* | spec SP item */
	;

item	: time {
	    yyIncrFlags(CLF_TIME);
	}
	| zone {
	    yyIncrFlags(CLF_ZONE);
	}
	| date {
	    yyIncrFlags(CLF_HAVEDATE);
	}
	| ordMonth {
	    yyIncrFlags(CLF_ORDINALMONTH);
	    info->flags |= CLF_RELCONV;
	}
	| day {
	    yyIncrFlags(CLF_DAYOFWEEK);
	    info->flags |= CLF_RELCONV;
	}
	| relspec {
	    info->flags |= CLF_RELCONV;
	}
	| iso {
	    yyIncrFlags(CLF_TIME|CLF_HAVEDATE);
	}
	| trek {
	    yyIncrFlags(CLF_TIME|CLF_HAVEDATE);
	    info->flags |= CLF_TREK;
	}
	| numitem
	;

iextime : tUNUMBER ':' tUNUMBER ':' tUNUMBER {
	    yyHour = $1;
	    yyMinutes = $3;
	    yySeconds = $5;
	}
	| tUNUMBER ':' tUNUMBER {
	    yyHour = $1;
	    yyMinutes = $3;
	    yySeconds = 0;
	}
	;
time	: tUNUMBER tMERIDIAN {
	    yyHour = $1;
	    yyMinutes = 0;
	    yySeconds = 0;
	    yyMeridian = $2;
	}
	| iextime o_merid {
	    yyMeridian = $2;
	}
	;

zone	: tZONE tDST {
	    yyTimezone = $1;
	    yyDSTmode = DSTon;
	}
	| tZONE {
	    yyTimezone = $1;
	    yyDSTmode = DSToff;
	}
	| tDAYZONE {
	    yyTimezone = $1;
	    yyDSTmode = DSTon;
	}
	| tZONEwO4 sign INTNUM { /* GMT+0100, GMT-1000, etc. */
	    yyTimezone = $1 - $2*($3 % 100 + ($3 / 100) * 60);
	    yyDSTmode = DSToff;
	}
	| tZONEwO2 sign INTNUM { /* GMT+1, GMT-10, etc. */
	    yyTimezone = $1 - $2*($3 * 60);
	    yyDSTmode = DSToff;
	}
	| sign INTNUM { /* +0100, -0100 */
	    yyTimezone = -$1*($2 % 100 + ($2 / 100) * 60);
	    yyDSTmode = DSToff;
	}
	;

comma	: ','
	| ',' SP
	;

day	: tDAY {
	    yyDayOrdinal = 1;
	    yyDayOfWeek = $1;
	}
	| tDAY comma {
	    yyDayOrdinal = 1;
	    yyDayOfWeek = $1;
	}
	| tUNUMBER tDAY {
	    yyDayOrdinal = $1;
	    yyDayOfWeek = $2;
	}
	| sign SP tUNUMBER tDAY {
	    yyDayOrdinal = $1 * $3;
	    yyDayOfWeek = $4;
	}
	| sign tUNUMBER tDAY {
	    yyDayOrdinal = $1 * $2;
	    yyDayOfWeek = $3;
	}
	| tNEXT tDAY {
	    yyDayOrdinal = 2;
	    yyDayOfWeek = $2;
	}
	;

iexdate	: tUNUMBER '-' tUNUMBER '-' tUNUMBER {
	    yyMonth = $3;
	    yyDay = $5;
	    yyYear = $1;
	}
	;
date	: tUNUMBER '/' tUNUMBER {
	    yyMonth = $1;
	    yyDay = $3;
	}
	| tUNUMBER '/' tUNUMBER '/' tUNUMBER {
	    yyMonth = $1;
	    yyDay = $3;
	    yyYear = $5;
	}
	| isodate
	| tUNUMBER '-' tMONTH '-' tUNUMBER {
	    yyDay = $1;
	    yyMonth = $3;
	    yyYear = $5;
	}
	| tMONTH tUNUMBER {
	    yyMonth = $1;
	    yyDay = $2;
	}
	| tMONTH tUNUMBER comma tUNUMBER {
	    yyMonth = $1;
	    yyDay = $2;
	    yyYear = $4;
	}
	| tUNUMBER tMONTH {
	    yyMonth = $2;
	    yyDay = $1;
	}
	| tEPOCH {
	    yyMonth = 1;
	    yyDay = 1;
	    yyYear = EPOCH;
	}
	| tUNUMBER tMONTH tUNUMBER {
	    yyMonth = $2;
	    yyDay = $1;
	    yyYear = $3;
	}
	;

ordMonth: tNEXT tMONTH {
	    yyMonthOrdinalIncr = 1;
	    yyMonthOrdinal = $2;
	}
	| tNEXT tUNUMBER tMONTH {
	    yyMonthOrdinalIncr = $2;
	    yyMonthOrdinal = $3;
	}
	;

isosep	: 'T'|SP
	;
isodate	: tISOBAS8 { /* YYYYMMDD */
	    yyYear = $1 / 10000;
	    yyMonth = ($1 % 10000)/100;
	    yyDay = $1 % 100;
	}
	| tISOBAS6 { /* YYMMDD */
	    yyYear = $1 / 10000;
	    yyMonth = ($1 % 10000)/100;
	    yyDay = $1 % 100;
	}
	| iexdate
	;
isotime	: tISOBAS6 {
	    yyHour = $1 / 10000;
	    yyMinutes = ($1 % 10000)/100;
	    yySeconds = $1 % 100;
	}
	| iextime
	;
iso	: isodate isosep isotime
	| tISOBASL tISOBAS6 { /* YYYYMMDDhhmmss */
	    yyYear = $1 / 10000;
	    yyMonth = ($1 % 10000)/100;
	    yyDay = $1 % 100;
	    yyHour = $2 / 10000;
	    yyMinutes = ($2 % 10000)/100;
	    yySeconds = $2 % 100;
	}
	| tISOBASL tUNUMBER { /* YYYYMMDDhhmm */
	    if (yyDigitCount != 4) YYABORT; /* normally unreached */
	    yyYear = $1 / 10000;
	    yyMonth = ($1 % 10000)/100;
	    yyDay = $1 % 100;
	    yyHour = $2 / 100;
	    yyMinutes = ($2 % 100);
	    yySeconds = 0;
	}
	;

trek	: tSTARDATE INTNUM '.' tUNUMBER {
	    /*
	     * Offset computed year by -377 so that the returned years will be
	     * in a range accessible with a 32 bit clock seconds value.
	     */

	    yyYear = $2/1000 + 2323 - 377;
	    yyDay  = 1;
	    yyMonth = 1;
	    yyRelDay += (($2%1000)*(365 + IsLeapYear(yyYear)))/1000;
	    yyRelSeconds += $4 * (144LL * 60LL);
	    info->flags |= CLF_RELCONV;
	}
	;

relspec : relunits tAGO {
	    yyRelSeconds *= -1;
	    yyRelMonth *= -1;
	    yyRelDay *= -1;
	}
	| relunits
	;

relunits : sign SP INTNUM unit {
	    *yyRelPointer += $1 * $3 * $4;
	}
	| sign INTNUM unit {
	    *yyRelPointer += $1 * $2 * $3;
	}
	| INTNUM unit {
	    *yyRelPointer += $1 * $2;
	}
	| tNEXT unit {
	    *yyRelPointer += $2;
	}
	| tNEXT INTNUM unit {
	    *yyRelPointer += $2 * $3;
	}
	| unit {
	    *yyRelPointer += $1;
	}
	;

sign	: '-' {
	    $$ = -1;
	}
	| '+' {
	    $$ =  1;
	}
	;

unit	: tSEC_UNIT {
	    $$ = $1;
	    yyRelPointer = &yyRelSeconds;
	    /* no flag CLF_RELCONV needed by seconds */
	}
	| tDAY_UNIT {
	    $$ = $1;
	    yyRelPointer = &yyRelDay;
	    info->flags |= CLF_RELCONV;
	}
	| tMONTH_UNIT {
	    $$ = $1;
	    yyRelPointer = &yyRelMonth;
	    info->flags |= CLF_RELCONV;
	}
	;

INTNUM	: tUNUMBER {
	    $$ = $1;
	}
	| tISOBAS6 {
	    $$ = $1;
	}
	| tISOBAS8 {
	    $$ = $1;
	}
	;

numitem	: tUNUMBER {
	    if ((info->flags & (CLF_TIME|CLF_HAVEDATE|CLF_TREK)) == (CLF_TIME|CLF_HAVEDATE)) {
		yyYear = $1;
	    } else {
		yyIncrFlags(CLF_TIME);
		if (yyDigitCount <= 2) {
		    yyHour = $1;
		    yyMinutes = 0;
		} else {
		    yyHour = $1 / 100;
		    yyMinutes = $1 % 100;
		}
		yySeconds = 0;
		yyMeridian = MER24;
	    }
	}
	;

o_merid : /* NULL */ {
	    $$ = MER24;
	}
	| tMERIDIAN {
	    $$ = $1;
	}
	;

%%
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
