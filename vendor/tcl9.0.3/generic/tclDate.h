/*
 * tclDate.h --
 *
 *	This header file handles common usage of clock primitives
 *	between tclDate.c (yacc), tclClock.c and tclClockFmt.c.
 *
 * Copyright (c) 2014 Serg G. Brester (aka sebres)
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#ifndef _TCLCLOCK_H
#define _TCLCLOCK_H

/*
 * Constants
 */

#define JULIAN_DAY_POSIX_EPOCH		2440588
#define GREGORIAN_CHANGE_DATE		2361222
#define SECONDS_PER_DAY			86400
#define JULIAN_SEC_POSIX_EPOCH	      (((Tcl_WideInt) JULIAN_DAY_POSIX_EPOCH) \
					* SECONDS_PER_DAY)
#define FOUR_CENTURIES			146097	/* days */
#define JDAY_1_JAN_1_CE_JULIAN		1721424
#define JDAY_1_JAN_1_CE_GREGORIAN	1721426
#define ONE_CENTURY_GREGORIAN		36524	/* days */
#define FOUR_YEARS			1461	/* days */
#define ONE_YEAR			365	/* days */

#define RODDENBERRY			1946	/* Another epoch (Hi, Jeff!) */

enum DateInfoFlags {
    CLF_OPTIONAL = 1 << 0,	/* token is non mandatory */
    CLF_POSIXSEC = 1 << 1,
    CLF_LOCALSEC = 1 << 2,
    CLF_JULIANDAY = 1 << 3,
    CLF_TIME = 1 << 4,
    CLF_ZONE = 1 << 5,
    CLF_CENTURY = 1 << 6,
    CLF_DAYOFMONTH = 1 << 7,
    CLF_DAYOFYEAR = 1 << 8,
    CLF_MONTH = 1 << 9,
    CLF_YEAR = 1 << 10,
    CLF_DAYOFWEEK = 1 << 11,
    CLF_ISO8601YEAR = 1 << 12,
    CLF_ISO8601WEEK = 1 << 13,
    CLF_ISO8601CENTURY = 1 << 14,

    CLF_SIGNED = 1 << 15,

    /* Compounds */

    CLF_HAVEDATE = (CLF_DAYOFMONTH | CLF_MONTH | CLF_YEAR),
    CLF_DATE = (CLF_JULIANDAY | CLF_DAYOFMONTH | CLF_DAYOFYEAR
	    | CLF_MONTH | CLF_YEAR | CLF_ISO8601YEAR
	    | CLF_DAYOFWEEK | CLF_ISO8601WEEK),

    /*
     * Extra flags used outside of scan/format-tokens too (int, not a short).
     */

    CLF_RELCONV = 1 << 17,
    CLF_ORDINALMONTH = 1 << 18,
    CLF_TREK = 1 << 19,

    /* On demand (lazy) assemble flags */

    CLF_ASSEMBLE_DATE = 1 << 28,/* assemble year, month, etc. using julianDay */
    CLF_ASSEMBLE_JULIANDAY = 1 << 29,
				/* assemble julianDay using year, month, etc. */
    CLF_ASSEMBLE_SECONDS = 1 << 30
				/* assemble localSeconds (and seconds at end) */
};

#define TCL_MIN_SECONDS		-0x00F0000000000000LL
#define TCL_MAX_SECONDS		 0x00F0000000000000LL
#define TCL_INV_SECONDS		(TCL_MIN_SECONDS - 1)

/*
 * Enumeration of the string literals used in [clock]
 */

typedef enum {
    LIT__NIL,
    LIT__DEFAULT_FORMAT,
    LIT_SYSTEM,		LIT_CURRENT,		LIT_C,
    LIT_BCE,		LIT_CE,
    LIT_DAYOFMONTH,	LIT_DAYOFWEEK,		LIT_DAYOFYEAR,
    LIT_ERA,		LIT_GMT,		LIT_GREGORIAN,
    LIT_INTEGER_VALUE_TOO_LARGE,
    LIT_ISO8601WEEK,	LIT_ISO8601YEAR,
    LIT_JULIANDAY,	LIT_LOCALSECONDS,
    LIT_MONTH,
    LIT_SECONDS,	LIT_TZNAME,		LIT_TZOFFSET,
    LIT_YEAR,
    LIT_TZDATA,
    LIT_GETSYSTEMTIMEZONE,
    LIT_SETUPTIMEZONE,
    LIT_MCGET,
    LIT_GETSYSTEMLOCALE, LIT_GETCURRENTLOCALE,
    LIT_LOCALIZE_FORMAT,
    LIT__END
} ClockLiteral;

#define CLOCK_LITERAL_ARRAY(litarr) static const char *const litarr[] = { \
    "", \
    "%a %b %d %H:%M:%S %Z %Y", \
    "system",		"current",		"C", \
    "BCE",		"CE", \
    "dayOfMonth",	"dayOfWeek",		"dayOfYear", \
    "era",		":GMT",			"gregorian", \
    "integer value too large to represent", \
    "iso8601Week",	"iso8601Year", \
    "julianDay",	"localSeconds", \
    "month", \
    "seconds",		"tzName",		"tzOffset", \
    "year", \
    "::tcl::clock::TZData", \
    "::tcl::clock::GetSystemTimeZone", \
    "::tcl::clock::SetupTimeZone", \
    "::tcl::clock::mcget", \
    "::tcl::clock::GetSystemLocale", "::tcl::clock::mclocale", \
    "::tcl::clock::LocalizeFormat" \
}

/*
 * Enumeration of the msgcat literals used in [clock]
 */

typedef enum {
    MCLIT__NIL, /* placeholder */
    MCLIT_MONTHS_FULL,	MCLIT_MONTHS_ABBREV,  MCLIT_MONTHS_COMB,
    MCLIT_DAYS_OF_WEEK_FULL,  MCLIT_DAYS_OF_WEEK_ABBREV,  MCLIT_DAYS_OF_WEEK_COMB,
    MCLIT_AM,  MCLIT_PM,
    MCLIT_LOCALE_ERAS,
    MCLIT_BCE,	 MCLIT_CE,
    MCLIT_BCE2,	 MCLIT_CE2,
    MCLIT_BCE3,	 MCLIT_CE3,
    MCLIT_LOCALE_NUMERALS,
    MCLIT__END
} ClockMsgCtLiteral;

#define CLOCK_LOCALE_LITERAL_ARRAY(litarr, pref) static const char *const litarr[] = { \
    pref "", \
    pref "MONTHS_FULL", pref "MONTHS_ABBREV", pref "MONTHS_COMB", \
    pref "DAYS_OF_WEEK_FULL", pref "DAYS_OF_WEEK_ABBREV", pref "DAYS_OF_WEEK_COMB", \
    pref "AM", pref "PM", \
    pref "LOCALE_ERAS", \
    pref "BCE",	   pref "CE", \
    pref "b.c.e.", pref "c.e.", \
    pref "b.c.",   pref "a.d.", \
    pref "LOCALE_NUMERALS", \
}

/*
 * Structure containing the fields used in [clock format] and [clock scan]
 */

enum TclDateFieldsFlags {
    CLF_CTZ = (1 << 4)
};

typedef struct {
    /* Cacheable fields:	 */

    Tcl_WideInt seconds;	/* Time expressed in seconds from the Posix
				 * epoch */
    Tcl_WideInt localSeconds;	/* Local time expressed in nominal seconds
				 * from the Posix epoch */
    int tzOffset;		/* Time zone offset in seconds east of
				 * Greenwich */
    Tcl_WideInt julianDay;	/* Julian Day Number in local time zone */
    int isBce;			/* 1 if BCE */
    int gregorian;		/* Flag == 1 if the date is Gregorian */
    int year;			/* Year of the era */
    int dayOfYear;		/* Day of the year (1 January == 1) */
    int month;			/* Month number */
    int dayOfMonth;		/* Day of the month */
    int iso8601Year;		/* ISO8601 week-based year */
    int iso8601Week;		/* ISO8601 week number */
    int dayOfWeek;		/* Day of the week */
    int hour;			/* Hours of day (in-between time only calculation) */
    int minutes;		/* Minutes of hour (in-between time only calculation) */
    Tcl_WideInt secondOfMin;	/* Seconds of minute (in-between time only calculation) */
    Tcl_WideInt secondOfDay;	/* Seconds of day (in-between time only calculation) */

    int flags;			/* 0 or CLF_CTZ */

    /* Non cacheable fields:	 */

    Tcl_Obj *tzName;		/* Name (or corresponding DST-abbreviation) of the
				 * time zone, if set the refCount is incremented */
} TclDateFields;

#define ClockCacheableDateFieldsSize \
    offsetof(TclDateFields, tzName)

/*
 * Meridian: am, pm, or 24-hour style.
 */

typedef enum {
    MERam, MERpm, MER24
} MERIDIAN;

/*
 * Structure contains return parsed fields.
 */

typedef struct DateInfo {
    const char *dateStart;
    const char *dateInput;
    const char *dateEnd;

    TclDateFields date;

    int flags;			/* Signals parts of date/time get found */
    int errFlags;		/* Signals error (part of date/time found twice) */

    MERIDIAN dateMeridian;

    int dateTimezone;
    int dateDSTmode;

    Tcl_WideInt dateRelMonth;
    Tcl_WideInt dateRelDay;
    Tcl_WideInt dateRelSeconds;

    int dateMonthOrdinalIncr;
    int dateMonthOrdinal;

    int dateDayOrdinal;

    Tcl_WideInt *dateRelPointer;

    int dateSpaceCount;
    int dateDigitCount;

    int dateCentury;

    Tcl_Obj *messages;		/* Error messages */
    const char* separatrix;	/* String separating messages */
} DateInfo;

#define yydate	    (info->date)  /* Date fields used for converting */

#define yyDay	    (info->date.dayOfMonth)
#define yyMonth	    (info->date.month)
#define yyYear	    (info->date.year)

#define yyHour	    (info->date.hour)
#define yyMinutes   (info->date.minutes)
#define yySeconds   (info->date.secondOfMin)
#define yySecondOfDay (info->date.secondOfDay)

#define yyDSTmode   (info->dateDSTmode)
#define yyDayOrdinal	(info->dateDayOrdinal)
#define yyDayOfWeek (info->date.dayOfWeek)
#define yyMonthOrdinalIncr  (info->dateMonthOrdinalIncr)
#define yyMonthOrdinal	(info->dateMonthOrdinal)
#define yyTimezone  (info->dateTimezone)
#define yyMeridian  (info->dateMeridian)
#define yyRelMonth  (info->dateRelMonth)
#define yyRelDay    (info->dateRelDay)
#define yyRelSeconds	(info->dateRelSeconds)
#define yyRelPointer	(info->dateRelPointer)
#define yyInput	    (info->dateInput)
#define yyDigitCount	(info->dateDigitCount)
#define yySpaceCount	(info->dateSpaceCount)

static inline void
ClockInitDateInfo(
    DateInfo *info)
{
    memset(info, 0, sizeof(DateInfo));
}

/*
 * Structure containing the command arguments supplied to [clock format] and [clock scan]
 */

enum ClockFmtScnCmdArgsFlags {
    CLF_VALIDATE_S1 = (1 << 0),
    CLF_VALIDATE_S2 = (1 << 1),
    CLF_VALIDATE = (CLF_VALIDATE_S1|CLF_VALIDATE_S2),
    CLF_EXTENDED = (1 << 4),
    CLF_STRICT = (1 << 8),
    CLF_LOCALE_USED = (1 << 15)
};

typedef struct ClockClientData ClockClientData;

typedef struct ClockFmtScnCmdArgs {
    ClockClientData *dataPtr;	/* Pointer to literal pool, etc. */
    Tcl_Interp *interp;		/* Tcl interpreter */
    Tcl_Obj *formatObj;		/* Format */
    Tcl_Obj *localeObj;		/* Name of the locale where the time will be expressed. */
    Tcl_Obj *timezoneObj;	/* Default time zone in which the time will be expressed */
    Tcl_Obj *baseObj;		/* Base (scan and add) or clockValue (format) */
    int flags;			/* Flags control scanning */
    Tcl_Obj *mcDictObj;		/* Current dictionary of tcl::clock package for given localeObj*/
} ClockFmtScnCmdArgs;

/* Last-period cache for fast UTC to local and backwards conversion */
typedef struct ClockLastTZOffs {
    /* keys */
    Tcl_Obj *timezoneObj;
    int changeover;
    Tcl_WideInt localSeconds;
    Tcl_WideInt rangesVal[2];   /* Bounds for cached time zone offset */
    /* values */
    int tzOffset;
    Tcl_Obj *tzName;		/* Name (abbreviation) of this area in TZ */
} ClockLastTZOffs;

/*
 * Structure containing the client data for [clock]
 */

typedef struct ClockClientData {
    size_t refCount;		/* Number of live references. */
    Tcl_Obj **literals;		/* Pool of object literals (common, locale independent). */
    Tcl_Obj **mcLiterals;	/* Msgcat object literals with mc-keys for search with locale. */
    Tcl_Obj **mcLitIdxs;	/* Msgcat object indices prefixed with _IDX_,
				 * used for quick dictionary search */
    Tcl_Obj *mcDicts;		/* Msgcat collection, contains weak pointers to locale
				 * catalogs, and owns it references (onetime referenced) */

    /* Cache for current clock parameters, imparted via "configure" */
    size_t lastTZEpoch;
    int currentYearCentury;
    int yearOfCenturySwitch;
    int validMinYear;
    int validMaxYear;
    double maxJDN;

    Tcl_Obj *systemTimeZone;
    Tcl_Obj *systemSetupTZData;
    Tcl_Obj *gmtSetupTimeZoneUnnorm;
    Tcl_Obj *gmtSetupTimeZone;
    Tcl_Obj *gmtSetupTZData;
    Tcl_Obj *gmtTZName;
    Tcl_Obj *lastSetupTimeZoneUnnorm;
    Tcl_Obj *lastSetupTimeZone;
    Tcl_Obj *lastSetupTZData;
    Tcl_Obj *prevSetupTimeZoneUnnorm;
    Tcl_Obj *prevSetupTimeZone;
    Tcl_Obj *prevSetupTZData;

    Tcl_Obj *defaultLocale;
    Tcl_Obj *defaultLocaleDict;
    Tcl_Obj *currentLocale;
    Tcl_Obj *currentLocaleDict;
    Tcl_Obj *lastUsedLocaleUnnorm;
    Tcl_Obj *lastUsedLocale;
    Tcl_Obj *lastUsedLocaleDict;
    Tcl_Obj *prevUsedLocaleUnnorm;
    Tcl_Obj *prevUsedLocale;
    Tcl_Obj *prevUsedLocaleDict;

    /* Cache for last base (last-second fast convert if base/tz not changed) */
    struct {
	Tcl_Obj *timezoneObj;
	TclDateFields date;
    } lastBase;

    /* Last-period cache for fast UTC to Local and backwards conversion */
    ClockLastTZOffs lastTZOffsCache[2];

    int defFlags;		    /* Default flags (from configure), ATM
				     * only CLF_VALIDATE supported */
} ClockClientData;

#define ClockDefaultYearCentury 2000
#define ClockDefaultCenturySwitch 38

/*
 * Clock scan and format facilities.
 */

#ifndef TCL_MEM_DEBUG
# define CLOCK_FMT_SCN_STORAGE_GC_SIZE 32
#else
# define CLOCK_FMT_SCN_STORAGE_GC_SIZE 0
#endif

#define CLOCK_MIN_TOK_CHAIN_BLOCK_SIZE 2

typedef struct ClockScanToken ClockScanToken;

typedef int ClockScanTokenProc(
	ClockFmtScnCmdArgs *opts,
	DateInfo *info,
	const ClockScanToken *tok);

typedef enum {
   CTOKT_INT = 1, CTOKT_WIDE, CTOKT_PARSER, CTOKT_SPACE, CTOKT_WORD, CTOKT_CHAR,
   CFMTT_PROC
} CLCKTOK_TYPE;

typedef struct ClockScanTokenMap {
    unsigned short type;
    unsigned short flags;
    unsigned short clearFlags;
    unsigned short minSize;
    unsigned short maxSize;
    unsigned short offs;
    ClockScanTokenProc *parser;
    const void *data;
} ClockScanTokenMap;

struct ClockScanToken {
    const ClockScanTokenMap *map;
    struct {
	const char *start;
	const char *end;
    } tokWord;
    unsigned short endDistance;
    unsigned short lookAhMin;
    unsigned short lookAhMax;
    unsigned short lookAhTok;
};

#define MIN_FMT_RESULT_BLOCK_ALLOC 80
#define MIN_FMT_RESULT_BLOCK_DELTA 0
/* Maximal permitted threshold (buffer size > result size) in percent,
 * to directly return the buffer without reallocate */
#define MAX_FMT_RESULT_THRESHOLD   2

typedef struct DateFormat {
    char *resMem;
    char *resEnd;
    char *output;
    TclDateFields date;
    Tcl_Obj *localeEra;
} DateFormat;

enum ClockFormatTokenMapFlags {
    CLFMT_INCR = (1 << 3),
    CLFMT_DECR = (1 << 4),
    CLFMT_CALC = (1 << 5),
    CLFMT_LOCALE_INDX = (1 << 8)
};

typedef struct ClockFormatToken ClockFormatToken;

typedef int ClockFormatTokenProc(
	ClockFmtScnCmdArgs *opts,
	DateFormat *dateFmt,
	ClockFormatToken *tok,
	int *val);

typedef struct ClockFormatTokenMap {
    unsigned short type;
    const char *tostr;
    unsigned short width;
    unsigned short flags;
    unsigned short divider;
    unsigned short divmod;
    unsigned short offs;
    ClockFormatTokenProc *fmtproc;
    void *data;
} ClockFormatTokenMap;

struct ClockFormatToken {
    const ClockFormatTokenMap *map;
    struct {
	const char *start;
	const char *end;
    } tokWord;
};

typedef struct ClockFmtScnStorage ClockFmtScnStorage;

struct ClockFmtScnStorage {
    int objRefCount;		/* Reference count shared across threads */
    ClockScanToken *scnTok;
    unsigned scnTokC;
    unsigned scnSpaceCount;	/* Count of mandatory spaces used in format */
    ClockFormatToken *fmtTok;
    unsigned fmtTokC;
#if CLOCK_FMT_SCN_STORAGE_GC_SIZE > 0
    ClockFmtScnStorage *nextPtr;
    ClockFmtScnStorage *prevPtr;
#endif
    size_t fmtMinAlloc;
#if 0
    Tcl_HashEntry hashEntry		/* ClockFmtScnStorage is a derivate of Tcl_HashEntry,
					 * stored by offset +sizeof(self) */
#endif
};

/*
 * Clock macros.
 */

/*
 * Extracts Julian day and seconds of the day from posix seconds (tm).
 */
#define ClockExtractJDAndSODFromSeconds(jd, sod, tm) \
    do {								\
	jd = (tm + JULIAN_SEC_POSIX_EPOCH);				\
	if (jd >= SECONDS_PER_DAY || jd <= -SECONDS_PER_DAY) {		\
	    jd /= SECONDS_PER_DAY;					\
	    sod = (int)(tm % SECONDS_PER_DAY);				\
	} else {							\
	    sod = (int)jd, jd = 0;					\
	}								\
	if (sod < 0) {							\
	    sod += SECONDS_PER_DAY;					\
	    /* JD is affected, if switched into negative (avoid 24 hours difference) */ \
	    if (jd <= 0) {						\
		jd--;							\
	    }								\
	}								\
    } while(0)

/*
 * Prototypes of module functions.
 */

MODULE_SCOPE int	TclToSeconds(int Hours, int Minutes,
			    int Seconds, MERIDIAN Meridian);
MODULE_SCOPE int	TclIsGregorianLeapYear(TclDateFields *);
MODULE_SCOPE void	TclGetJulianDayFromEraYearDay(
			    TclDateFields *fields, int changeover);
MODULE_SCOPE int	TclConvertUTCToLocal(ClockClientData *dataPtr, Tcl_Interp *,
			    TclDateFields *, Tcl_Obj *timezoneObj, int);
MODULE_SCOPE Tcl_Obj *	TclClockLookupLastTransition(Tcl_Interp *, Tcl_WideInt,
			    Tcl_Size, Tcl_Obj *const *, Tcl_WideInt *rangesVal);
MODULE_SCOPE int	TclClockFreeScan(Tcl_Interp *interp, DateInfo *info);

/* tclClock.c module declarations */

MODULE_SCOPE Tcl_Obj *	TclClockSetupTimeZone(ClockClientData *dataPtr,
			    Tcl_Interp *interp, Tcl_Obj *timezoneObj);
MODULE_SCOPE Tcl_Obj *	TclClockMCDict(ClockFmtScnCmdArgs *opts);
MODULE_SCOPE Tcl_Obj *	TclClockMCGet(ClockFmtScnCmdArgs *opts, int mcKey);
MODULE_SCOPE Tcl_Obj *	TclClockMCGetIdx(ClockFmtScnCmdArgs *opts, int mcKey);
MODULE_SCOPE int	TclClockMCSetIdx(ClockFmtScnCmdArgs *opts, int mcKey,
			    Tcl_Obj *valObj);

/* tclClockFmt.c module declarations */

MODULE_SCOPE char *	TclItoAw(char *buf, int val, char padchar, unsigned short width);
MODULE_SCOPE int	TclAtoWIe(Tcl_WideInt *out, const char *p, const char *e, int sign);

MODULE_SCOPE ClockFmtScnStorage *Tcl_GetClockFrmScnFromObj(Tcl_Interp *interp,
			    Tcl_Obj *objPtr);
MODULE_SCOPE int	TclClockScan(DateInfo *info, Tcl_Obj *strObj,
			    ClockFmtScnCmdArgs *opts);
MODULE_SCOPE int	TclClockFormat(DateFormat *dateFmt,
			    ClockFmtScnCmdArgs *opts);
MODULE_SCOPE void	TclClockFrmScnClearCaches(void);
MODULE_SCOPE void	TclClockFrmScnFinalize();

#endif /* _TCLCLOCK_H */
