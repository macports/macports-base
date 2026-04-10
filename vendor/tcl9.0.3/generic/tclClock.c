/*
 * tclClock.c --
 *
 *	Contains the time and date related commands. This code is derived from
 *	the time and date facilities of TclX, by Mark Diekhans and Karl
 *	Lehenbauer.
 *
 * Copyright © 1991-1995 Karl Lehenbauer & Mark Diekhans.
 * Copyright © 1995 Sun Microsystems, Inc.
 * Copyright © 2004 Kevin B. Kenny. All rights reserved.
 * Copyright © 2015 Sergey G. Brester aka sebres. All rights reserved.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#include "tclTomMath.h"
#include "tclStrIdxTree.h"
#include "tclDate.h"
#if defined(_WIN32) && defined (__clang__) && (__clang_major__ > 20)
#pragma clang diagnostic ignored "-Wc++-keyword"
#endif

/*
 * Table of the days in each month, leap and common years
 */

static const int hath[2][12] = {
    {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31},
    {31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
};
static const int daysInPriorMonths[2][13] = {
    {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365},
    {0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366}
};

/*
 * Enumeration of the string literals used in [clock]
 */

CLOCK_LITERAL_ARRAY(Literals);

/* Msgcat literals for exact match (mcKey) */
CLOCK_LOCALE_LITERAL_ARRAY(MsgCtLiterals, "");
/* Msgcat index literals prefixed with _IDX_, used for quick dictionary search */
CLOCK_LOCALE_LITERAL_ARRAY(MsgCtLitIdxs, "_IDX_");

static const char *const eras[] = { "CE", "BCE", NULL };

/*
 * Thread specific data block holding a 'struct tm' for the 'gmtime' and
 * 'localtime' library calls.
 */

static Tcl_ThreadDataKey tmKey;

/*
 * Mutex protecting 'gmtime', 'localtime' and 'mktime' calls and the statics
 * in the date parsing code.
 */

TCL_DECLARE_MUTEX(clockMutex)

/*
 * Function prototypes for local procedures in this file:
 */

static int		ConvertUTCToLocalUsingTable(Tcl_Interp *,
			    TclDateFields *, Tcl_Size, Tcl_Obj *const[],
			    Tcl_WideInt *rangesVal);
static int		ConvertUTCToLocalUsingC(Tcl_Interp *,
			    TclDateFields *, int);
static int		ConvertLocalToUTC(ClockClientData *, Tcl_Interp *,
			    TclDateFields *, Tcl_Obj *timezoneObj, int);
static int		ConvertLocalToUTCUsingTable(Tcl_Interp *,
			    TclDateFields *, int, Tcl_Obj *const[],
			    Tcl_WideInt *rangesVal);
static int		ConvertLocalToUTCUsingC(Tcl_Interp *,
			    TclDateFields *, int);
static Tcl_ObjCmdProc	ClockConfigureObjCmd;
static void		GetYearWeekDay(TclDateFields *, int);
static void		GetGregorianEraYearDay(TclDateFields *, int);
static void		GetJulianDayFromEraYearMonthDay(
			    TclDateFields *fields, int changeover);
static void		GetMonthDay(TclDateFields *);
static Tcl_WideInt	WeekdayOnOrBefore(int, Tcl_WideInt);
static Tcl_ObjCmdProc	ClockClicksObjCmd;
static Tcl_ObjCmdProc	ClockConvertlocaltoutcObjCmd;
static int		ClockGetDateFields(ClockClientData *,
			    Tcl_Interp *interp, TclDateFields *fields,
			    Tcl_Obj *timezoneObj, int changeover);
static void		GetJulianDayFromEraYearWeekDay(
			    TclDateFields *fields, int changeover);
static Tcl_ObjCmdProc	ClockGetdatefieldsObjCmd;
static Tcl_ObjCmdProc	ClockGetjuliandayfromerayearmonthdayObjCmd;
static Tcl_ObjCmdProc	ClockGetjuliandayfromerayearweekdayObjCmd;
static Tcl_ObjCmdProc	ClockGetenvObjCmd;
static Tcl_ObjCmdProc	ClockMicrosecondsObjCmd;
static Tcl_ObjCmdProc	ClockMillisecondsObjCmd;
static Tcl_ObjCmdProc	ClockSecondsObjCmd;
static Tcl_ObjCmdProc	ClockFormatObjCmd;
static Tcl_ObjCmdProc	ClockScanObjCmd;
static int		ClockScanCommit(DateInfo *info,
			    ClockFmtScnCmdArgs *opts);
static int		ClockFreeScan(DateInfo *info,
			    Tcl_Obj *strObj, ClockFmtScnCmdArgs *opts);
static int		ClockCalcRelTime(DateInfo *info,
			    ClockFmtScnCmdArgs *opts);
static Tcl_ObjCmdProc	ClockAddObjCmd;
static int		ClockValidDate(DateInfo *,
			    ClockFmtScnCmdArgs *, int stage);
static struct tm *	ThreadSafeLocalTime(const time_t *);
static size_t		TzsetIfNecessary(void);
static void		ClockDeleteCmdProc(void *);
static Tcl_ObjCmdProc	ClockSafeCatchCmd;
static void		ClockFinalize(void *);
/*
 * Structure containing description of "native" clock commands to create.
 */

struct ClockCommand {
    const char *name;		/* The tail of the command name. The full name
				 * is "::tcl::clock::<name>". When NULL marks
				 * the end of the table. */
    Tcl_ObjCmdProc *objCmdProc;	/* Function that implements the command. This
				 * will always have the ClockClientData sent
				 * to it, but may well ignore this data. */
    CompileProc *compileProc;	/* The compiler for the command. */
    void *clientData;		/* Any clientData to give the command (if NULL
				 * a reference to ClockClientData will be sent) */
};

static const struct ClockCommand clockCommands[] = {
    {"add",		ClockAddObjCmd,		TclCompileBasicMin1ArgCmd, NULL},
    {"clicks",		ClockClicksObjCmd,	TclCompileClockClicksCmd,  NULL},
    {"format",		ClockFormatObjCmd,	TclCompileBasicMin1ArgCmd, NULL},
    {"getenv",		ClockGetenvObjCmd,	TclCompileBasicMin1ArgCmd, NULL},
    {"microseconds",	ClockMicrosecondsObjCmd,TclCompileClockReadingCmd, INT2PTR(1)},
    {"milliseconds",	ClockMillisecondsObjCmd,TclCompileClockReadingCmd, INT2PTR(2)},
    {"scan",		ClockScanObjCmd,	TclCompileBasicMin1ArgCmd, NULL},
    {"seconds",		ClockSecondsObjCmd,	TclCompileClockReadingCmd, INT2PTR(3)},
    {"ConvertLocalToUTC", ClockConvertlocaltoutcObjCmd,		NULL, NULL},
    {"GetDateFields",	  ClockGetdatefieldsObjCmd,		NULL, NULL},
    {"GetJulianDayFromEraYearMonthDay",
		ClockGetjuliandayfromerayearmonthdayObjCmd,	NULL, NULL},
    {"GetJulianDayFromEraYearWeekDay",
		ClockGetjuliandayfromerayearweekdayObjCmd,	NULL, NULL},
    {"catch",		ClockSafeCatchCmd,	TclCompileBasicMin1ArgCmd, NULL},
    {NULL, NULL, NULL, NULL}
};

/*
 *----------------------------------------------------------------------
 *
 * TclClockInit --
 *
 *	Registers the 'clock' subcommands with the Tcl interpreter and
 *	initializes its client data (which consists mostly of constant
 *	Tcl_Obj's that it is too much trouble to keep recreating).
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Installs the commands and creates the client data
 *
 *----------------------------------------------------------------------
 */

void
TclClockInit(
    Tcl_Interp *interp)		/* Tcl interpreter */
{
    const struct ClockCommand *clockCmdPtr;
    char cmdName[50];		/* Buffer large enough to hold the string
				 *::tcl::clock::GetJulianDayFromEraYearMonthDay
				 * plus a terminating NUL. */
    Command *cmdPtr;
    ClockClientData *data;
    int i;

    static int initialized = 0;	/* global clock engine initialized (in process) */
    /*
     * Register handler to finalize clock on exit.
     */
    if (!initialized) {
	Tcl_CreateExitHandler(ClockFinalize, NULL);
	initialized = 1;
    }

    /*
     * Safe interps get [::clock] as alias to a parent, so do not need their
     * own copies of the support routines.
     */

    if (Tcl_IsSafe(interp)) {
	return;
    }

    /*
     * Create the client data, which is a refcounted literal pool.
     */

    data = (ClockClientData *)Tcl_Alloc(sizeof(ClockClientData));
    data->refCount = 0;
    data->literals = (Tcl_Obj **)Tcl_Alloc(LIT__END * sizeof(Tcl_Obj*));
    for (i = 0; i < LIT__END; ++i) {
	TclInitObjRef(data->literals[i], Tcl_NewStringObj(
		Literals[i], TCL_AUTO_LENGTH));
    }
    data->mcLiterals = NULL;
    data->mcLitIdxs = NULL;
    data->mcDicts = NULL;
    data->lastTZEpoch = 0;
    data->currentYearCentury = ClockDefaultYearCentury;
    data->yearOfCenturySwitch = ClockDefaultCenturySwitch;
    data->validMinYear = INT_MIN;
    data->validMaxYear = INT_MAX;
    /* corresponds max of JDN in sqlite - 9999-12-31 23:59:59 per default */
    data->maxJDN = 5373484.499999994;

    data->systemTimeZone = NULL;
    data->systemSetupTZData = NULL;
    data->gmtSetupTimeZoneUnnorm = NULL;
    data->gmtSetupTimeZone = NULL;
    data->gmtSetupTZData = NULL;
    data->gmtTZName = NULL;
    data->lastSetupTimeZoneUnnorm = NULL;
    data->lastSetupTimeZone = NULL;
    data->lastSetupTZData = NULL;
    data->prevSetupTimeZoneUnnorm = NULL;
    data->prevSetupTimeZone = NULL;
    data->prevSetupTZData = NULL;

    data->defaultLocale = NULL;
    data->defaultLocaleDict = NULL;
    data->currentLocale = NULL;
    data->currentLocaleDict = NULL;
    data->lastUsedLocaleUnnorm = NULL;
    data->lastUsedLocale = NULL;
    data->lastUsedLocaleDict = NULL;
    data->prevUsedLocaleUnnorm = NULL;
    data->prevUsedLocale = NULL;
    data->prevUsedLocaleDict = NULL;

    data->lastBase.timezoneObj = NULL;

    memset(&data->lastTZOffsCache, 0, sizeof(data->lastTZOffsCache));

    data->defFlags = CLF_VALIDATE;

    /*
     * Install the commands.
     */

#define TCL_CLOCK_PREFIX_LEN 14 /* == strlen("::tcl::clock::") */
    memcpy(cmdName, "::tcl::clock::", TCL_CLOCK_PREFIX_LEN);
    for (clockCmdPtr=clockCommands ; clockCmdPtr->name!=NULL ; clockCmdPtr++) {
	void *clientData;

	strcpy(cmdName + TCL_CLOCK_PREFIX_LEN, clockCmdPtr->name);
	if (!(clientData = clockCmdPtr->clientData)) {
	    clientData = data;
	    data->refCount++;
	}
	cmdPtr = (Command *)Tcl_CreateObjCommand(interp, cmdName,
		clockCmdPtr->objCmdProc, clientData,
		clockCmdPtr->clientData ? NULL : ClockDeleteCmdProc);
	cmdPtr->compileProc = clockCmdPtr->compileProc ?
		clockCmdPtr->compileProc : TclCompileBasicMin0ArgCmd;
    }
    cmdPtr = (Command *) Tcl_CreateObjCommand(interp,
	    "::tcl::unsupported::clock::configure",
	    ClockConfigureObjCmd, data, ClockDeleteCmdProc);
    data->refCount++;
    cmdPtr->compileProc = TclCompileBasicMin0ArgCmd;
}

/*
 *----------------------------------------------------------------------
 *
 * ClockConfigureClear --
 *
 *	Clean up cached resp. run-time storages used in clock commands.
 *
 *	Shared usage for clean-up (ClockDeleteCmdProc) and "configure -clear".
 *
 * Results:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static void
ClockConfigureClear(
    ClockClientData *data)
{
    TclClockFrmScnClearCaches();

    data->lastTZEpoch = 0;
    TclUnsetObjRef(data->systemTimeZone);
    TclUnsetObjRef(data->systemSetupTZData);
    TclUnsetObjRef(data->gmtSetupTimeZoneUnnorm);
    TclUnsetObjRef(data->gmtSetupTimeZone);
    TclUnsetObjRef(data->gmtSetupTZData);
    TclUnsetObjRef(data->gmtTZName);
    TclUnsetObjRef(data->lastSetupTimeZoneUnnorm);
    TclUnsetObjRef(data->lastSetupTimeZone);
    TclUnsetObjRef(data->lastSetupTZData);
    TclUnsetObjRef(data->prevSetupTimeZoneUnnorm);
    TclUnsetObjRef(data->prevSetupTimeZone);
    TclUnsetObjRef(data->prevSetupTZData);

    TclUnsetObjRef(data->defaultLocale);
    data->defaultLocaleDict = NULL;
    TclUnsetObjRef(data->currentLocale);
    data->currentLocaleDict = NULL;
    TclUnsetObjRef(data->lastUsedLocaleUnnorm);
    TclUnsetObjRef(data->lastUsedLocale);
    data->lastUsedLocaleDict = NULL;
    TclUnsetObjRef(data->prevUsedLocaleUnnorm);
    TclUnsetObjRef(data->prevUsedLocale);
    data->prevUsedLocaleDict = NULL;

    TclUnsetObjRef(data->lastBase.timezoneObj);

    TclUnsetObjRef(data->lastTZOffsCache[0].timezoneObj);
    TclUnsetObjRef(data->lastTZOffsCache[0].tzName);
    TclUnsetObjRef(data->lastTZOffsCache[1].timezoneObj);
    TclUnsetObjRef(data->lastTZOffsCache[1].tzName);

    TclUnsetObjRef(data->mcDicts);
}

/*
 *----------------------------------------------------------------------
 *
 * ClockDeleteCmdProc --
 *
 *	Remove a reference to the clock client data, and clean up memory
 *	when it's all gone.
 *
 * Results:
 *	None.
 *
 *----------------------------------------------------------------------
 */
static void
ClockDeleteCmdProc(
    void *clientData)		/* Opaque pointer to the client data */
{
    ClockClientData *data = (ClockClientData *)clientData;
    int i;

    if (data->refCount-- <= 1) {
	for (i = 0; i < LIT__END; ++i) {
	    Tcl_DecrRefCount(data->literals[i]);
	}
	if (data->mcLiterals != NULL) {
	    for (i = 0; i < MCLIT__END; ++i) {
		Tcl_DecrRefCount(data->mcLiterals[i]);
	    }
	    Tcl_Free(data->mcLiterals);
	    data->mcLiterals = NULL;
	}
	if (data->mcLitIdxs != NULL) {
	    for (i = 0; i < MCLIT__END; ++i) {
		Tcl_DecrRefCount(data->mcLitIdxs[i]);
	    }
	    Tcl_Free(data->mcLitIdxs);
	    data->mcLitIdxs = NULL;
	}

	ClockConfigureClear(data);

	Tcl_Free(data->literals);
	Tcl_Free(data);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * SavePrevTimezoneObj --
 *
 *	Used to store previously used/cached time zone (makes it reusable).
 *
 *	This enables faster switch between time zones (e. g. to convert from
 *	one to another).
 *
 * Results:
 *	None.
 *
 *----------------------------------------------------------------------
 */
static inline void
SavePrevTimezoneObj(
    ClockClientData *dataPtr)	/* Client data containing literal pool */
{
    Tcl_Obj *timezoneObj = dataPtr->lastSetupTimeZone;

    if (timezoneObj && timezoneObj != dataPtr->prevSetupTimeZone) {
	TclSetObjRef(dataPtr->prevSetupTimeZoneUnnorm, dataPtr->lastSetupTimeZoneUnnorm);
	TclSetObjRef(dataPtr->prevSetupTimeZone, timezoneObj);
	TclSetObjRef(dataPtr->prevSetupTZData, dataPtr->lastSetupTZData);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * NormTimezoneObj --
 *
 *	Normalizes the timezone object (used for caching puposes).
 *
 *	If already cached time zone could be found, returns this
 *	object (last setup or last used, system (current) or gmt).
 *
 * Results:
 *	Normalized tcl object pointer.
 *
 *----------------------------------------------------------------------
 */

static Tcl_Obj *
NormTimezoneObj(
    ClockClientData *dataPtr,	/* Client data containing literal pool */
    Tcl_Obj *timezoneObj,	/* Name of zone to find */
    int *loaded)		/* Used to recognized TZ was loaded */
{
    const char *tz;

    *loaded = 1;
    if (timezoneObj == dataPtr->lastSetupTimeZoneUnnorm
	    && dataPtr->lastSetupTimeZone != NULL) {
	return dataPtr->lastSetupTimeZone;
    }
    if (timezoneObj == dataPtr->prevSetupTimeZoneUnnorm
	    && dataPtr->prevSetupTimeZone != NULL) {
	return dataPtr->prevSetupTimeZone;
    }
    if (timezoneObj == dataPtr->gmtSetupTimeZoneUnnorm
	    && dataPtr->gmtSetupTimeZone != NULL) {
	return dataPtr->literals[LIT_GMT];
    }
    if (timezoneObj == dataPtr->lastSetupTimeZone
	    || timezoneObj == dataPtr->prevSetupTimeZone
	    || timezoneObj == dataPtr->gmtSetupTimeZone
	    || timezoneObj == dataPtr->systemTimeZone) {
	return timezoneObj;
    }

    tz = TclGetString(timezoneObj);
    if (dataPtr->lastSetupTimeZone != NULL
	    && strcmp(tz, TclGetString(dataPtr->lastSetupTimeZone)) == 0) {
	TclSetObjRef(dataPtr->lastSetupTimeZoneUnnorm, timezoneObj);
	return dataPtr->lastSetupTimeZone;
    }
    if (dataPtr->prevSetupTimeZone != NULL
	    && strcmp(tz, TclGetString(dataPtr->prevSetupTimeZone)) == 0) {
	TclSetObjRef(dataPtr->prevSetupTimeZoneUnnorm, timezoneObj);
	return dataPtr->prevSetupTimeZone;
    }
    if (dataPtr->systemTimeZone != NULL
	    && strcmp(tz, TclGetString(dataPtr->systemTimeZone)) == 0) {
	return dataPtr->systemTimeZone;
    }
    if (strcmp(tz, Literals[LIT_GMT]) == 0) {
	TclSetObjRef(dataPtr->gmtSetupTimeZoneUnnorm, timezoneObj);
	if (dataPtr->gmtSetupTimeZone == NULL) {
	    *loaded = 0;
	}
	return dataPtr->literals[LIT_GMT];
    }
    /* unknown/unloaded tz - recache/revalidate later as last-setup if needed */
    *loaded = 0;
    return timezoneObj;
}

/*
 *----------------------------------------------------------------------
 *
 * ClockGetSystemLocale --
 *
 *	Returns system locale.
 *
 *	Executes ::tcl::clock::GetSystemLocale in given interpreter.
 *
 * Results:
 *	Returns system locale tcl object.
 *
 *----------------------------------------------------------------------
 */

static inline Tcl_Obj *
ClockGetSystemLocale(
    ClockClientData *dataPtr,	/* Opaque pointer to literal pool, etc. */
    Tcl_Interp *interp)		/* Tcl interpreter */
{
    if (Tcl_EvalObjv(interp, 1, &dataPtr->literals[LIT_GETSYSTEMLOCALE], 0) != TCL_OK) {
	return NULL;
    }

    return Tcl_GetObjResult(interp);
}
/*
 *----------------------------------------------------------------------
 *
 * ClockGetCurrentLocale --
 *
 *	Returns current locale.
 *
 *	Executes ::tcl::clock::mclocale in given interpreter.
 *
 * Results:
 *	Returns current locale tcl object.
 *
 *----------------------------------------------------------------------
 */

static inline Tcl_Obj *
ClockGetCurrentLocale(
    ClockClientData *dataPtr,	/* Client data containing literal pool */
    Tcl_Interp *interp)		/* Tcl interpreter */
{
    if (Tcl_EvalObjv(interp, 1, &dataPtr->literals[LIT_GETCURRENTLOCALE], 0) != TCL_OK) {
	return NULL;
    }

    TclSetObjRef(dataPtr->currentLocale, Tcl_GetObjResult(interp));
    dataPtr->currentLocaleDict = NULL;
    Tcl_ResetResult(interp);

    return dataPtr->currentLocale;
}

/*
 *----------------------------------------------------------------------
 *
 * SavePrevLocaleObj --
 *
 *	Used to store previously used/cached locale (makes it reusable).
 *
 *	This enables faster switch between locales (e. g. to convert from one to another).
 *
 * Results:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static inline void
SavePrevLocaleObj(
    ClockClientData *dataPtr)	/* Client data containing literal pool */
{
    Tcl_Obj *localeObj = dataPtr->lastUsedLocale;

    if (localeObj && localeObj != dataPtr->prevUsedLocale) {
	TclSetObjRef(dataPtr->prevUsedLocaleUnnorm, dataPtr->lastUsedLocaleUnnorm);
	TclSetObjRef(dataPtr->prevUsedLocale, localeObj);
	/* mcDicts owns reference to dict */
	dataPtr->prevUsedLocaleDict = dataPtr->lastUsedLocaleDict;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * NormLocaleObj --
 *
 *	Normalizes the locale object (used for caching puposes).
 *
 *	If already cached locale could be found, returns this
 *	object (current, system (OS) or last used locales).
 *
 * Results:
 *	Normalized tcl object pointer.
 *
 *----------------------------------------------------------------------
 */

static Tcl_Obj *
NormLocaleObj(
    ClockClientData *dataPtr,	/* Client data containing literal pool */
    Tcl_Interp *interp,		/* Tcl interpreter */
    Tcl_Obj *localeObj,
    Tcl_Obj **mcDictObj)
{
    const char *loc, *loc2;

    if (localeObj == NULL
	    || localeObj == dataPtr->literals[LIT_C]
	    || localeObj == dataPtr->defaultLocale) {
	*mcDictObj = dataPtr->defaultLocaleDict;
	return dataPtr->defaultLocale ?
		dataPtr->defaultLocale : dataPtr->literals[LIT_C];
    }

    if (localeObj == dataPtr->currentLocale
	    || localeObj == dataPtr->literals[LIT_CURRENT]) {
	if (dataPtr->currentLocale == NULL) {
	    ClockGetCurrentLocale(dataPtr, interp);
	}
	*mcDictObj = dataPtr->currentLocaleDict;
	return dataPtr->currentLocale;
    }

    if (localeObj == dataPtr->lastUsedLocale
	    || localeObj == dataPtr->lastUsedLocaleUnnorm) {
	*mcDictObj = dataPtr->lastUsedLocaleDict;
	return dataPtr->lastUsedLocale;
    }

    if (localeObj == dataPtr->prevUsedLocale
	    || localeObj == dataPtr->prevUsedLocaleUnnorm) {
	*mcDictObj = dataPtr->prevUsedLocaleDict;
	return dataPtr->prevUsedLocale;
    }

    loc = TclGetString(localeObj);
    if (dataPtr->currentLocale != NULL
	    && (localeObj == dataPtr->currentLocale
	    || (localeObj->length == dataPtr->currentLocale->length
	    && strcasecmp(loc, TclGetString(dataPtr->currentLocale)) == 0))) {
	*mcDictObj = dataPtr->currentLocaleDict;
	return dataPtr->currentLocale;
    }

    if (dataPtr->lastUsedLocale != NULL
	    && (localeObj == dataPtr->lastUsedLocale
	    || (localeObj->length == dataPtr->lastUsedLocale->length
	    && strcasecmp(loc, TclGetString(dataPtr->lastUsedLocale)) == 0))) {
	*mcDictObj = dataPtr->lastUsedLocaleDict;
	TclSetObjRef(dataPtr->lastUsedLocaleUnnorm, localeObj);
	return dataPtr->lastUsedLocale;
    }

    if (dataPtr->prevUsedLocale != NULL
	    && (localeObj == dataPtr->prevUsedLocale
	    || (localeObj->length == dataPtr->prevUsedLocale->length
	    && strcasecmp(loc, TclGetString(dataPtr->prevUsedLocale)) == 0))) {
	*mcDictObj = dataPtr->prevUsedLocaleDict;
	TclSetObjRef(dataPtr->prevUsedLocaleUnnorm, localeObj);
	return dataPtr->prevUsedLocale;
    }

    if ((localeObj->length == 1 /* C */
	    && strcasecmp(loc, Literals[LIT_C]) == 0)
	    || (dataPtr->defaultLocale && (loc2 = TclGetString(dataPtr->defaultLocale))
	    && localeObj->length == dataPtr->defaultLocale->length
	    && strcasecmp(loc, loc2) == 0)) {
	*mcDictObj = dataPtr->defaultLocaleDict;
	return dataPtr->defaultLocale ?
		dataPtr->defaultLocale : dataPtr->literals[LIT_C];
    }

    if (localeObj->length == 7 /* current */
	    && strcasecmp(loc, Literals[LIT_CURRENT]) == 0) {
	if (dataPtr->currentLocale == NULL) {
	    ClockGetCurrentLocale(dataPtr, interp);
	}
	*mcDictObj = dataPtr->currentLocaleDict;
	return dataPtr->currentLocale;
    }

    if ((localeObj->length == 6 /* system */
	    && strcasecmp(loc, Literals[LIT_SYSTEM]) == 0)) {
	SavePrevLocaleObj(dataPtr);
	TclSetObjRef(dataPtr->lastUsedLocaleUnnorm, localeObj);
	localeObj = ClockGetSystemLocale(dataPtr, interp);
	TclSetObjRef(dataPtr->lastUsedLocale, localeObj);
	*mcDictObj = NULL;
	return localeObj;
    }

    *mcDictObj = NULL;
    return localeObj;
}

/*
 *----------------------------------------------------------------------
 *
 * TclClockMCDict --
 *
 *	Retrieves a localized storage dictionary object for the given
 *	locale object.
 *
 *	This corresponds with call `::tcl::clock::mcget locale`.
 *	Cached representation stored in options (for further access).
 *
 * Results:
 *	Tcl-object contains smart reference to msgcat dictionary.
 *
 *----------------------------------------------------------------------
 */
Tcl_Obj *
TclClockMCDict(
    ClockFmtScnCmdArgs *opts)
{
    ClockClientData *dataPtr = opts->dataPtr;

    /* if dict not yet retrieved */
    if (opts->mcDictObj == NULL) {

	/* if locale was not yet used */
	if (!(opts->flags & CLF_LOCALE_USED)) {
	    opts->localeObj = NormLocaleObj(dataPtr, opts->interp,
		    opts->localeObj, &opts->mcDictObj);

	    if (opts->localeObj == NULL) {
		Tcl_SetObjResult(opts->interp, Tcl_NewStringObj(
			"locale not specified and no default locale set",
			TCL_AUTO_LENGTH));
		Tcl_SetErrorCode(opts->interp, "CLOCK", "badOption", (char *)NULL);
		return NULL;
	    }
	    opts->flags |= CLF_LOCALE_USED;

	    /* check locale literals already available (on demand creation) */
	    if (dataPtr->mcLiterals == NULL) {
		int i;

		dataPtr->mcLiterals = (Tcl_Obj **)
			Tcl_Alloc(MCLIT__END * sizeof(Tcl_Obj*));
		for (i = 0; i < MCLIT__END; ++i) {
		    TclInitObjRef(dataPtr->mcLiterals[i], Tcl_NewStringObj(
			    MsgCtLiterals[i], TCL_AUTO_LENGTH));
		}
	    }
	}

	/* check or obtain mcDictObj (be sure it's modifiable) */
	if (opts->mcDictObj == NULL || opts->mcDictObj->refCount > 1) {
	    Tcl_Size ref = 1;

	    /* first try to find locale catalog dict */
	    if (dataPtr->mcDicts == NULL) {
		TclSetObjRef(dataPtr->mcDicts, Tcl_NewDictObj());
	    }
	    Tcl_DictObjGet(NULL, dataPtr->mcDicts,
		    opts->localeObj, &opts->mcDictObj);

	    if (opts->mcDictObj == NULL) {
		/* get msgcat dictionary - ::tcl::clock::mcget locale */
		Tcl_Obj *callargs[2];

		callargs[0] = dataPtr->literals[LIT_MCGET];
		callargs[1] = opts->localeObj;

		if (Tcl_EvalObjv(opts->interp, 2, callargs, 0) != TCL_OK) {
		    return NULL;
		}

		opts->mcDictObj = Tcl_GetObjResult(opts->interp);
		Tcl_ResetResult(opts->interp);
		ref = 0; /* new object is not yet referenced */
	    }

	    /* be sure that object reference doesn't increase (dict changeable) */
	    if (opts->mcDictObj->refCount > ref) {
		/* smart reference (shared dict as object with no ref-counter) */
		opts->mcDictObj = TclDictObjSmartRef(opts->interp,
			opts->mcDictObj);
	    }

	    /* create exactly one reference to catalog / make it searchable for future */
	    Tcl_DictObjPut(NULL, dataPtr->mcDicts, opts->localeObj,
		    opts->mcDictObj);

	    if (opts->localeObj == dataPtr->literals[LIT_C]
		    || opts->localeObj == dataPtr->defaultLocale) {
		dataPtr->defaultLocaleDict = opts->mcDictObj;
	    }
	    if (opts->localeObj == dataPtr->currentLocale) {
		dataPtr->currentLocaleDict = opts->mcDictObj;
	    } else if (opts->localeObj == dataPtr->lastUsedLocale) {
		dataPtr->lastUsedLocaleDict = opts->mcDictObj;
	    } else {
		SavePrevLocaleObj(dataPtr);
		TclSetObjRef(dataPtr->lastUsedLocale, opts->localeObj);
		TclUnsetObjRef(dataPtr->lastUsedLocaleUnnorm);
		dataPtr->lastUsedLocaleDict = opts->mcDictObj;
	    }
	}
    }

    return opts->mcDictObj;
}

/*
 *----------------------------------------------------------------------
 *
 * TclClockMCGet --
 *
 *	Retrieves a msgcat value for the given literal integer mcKey
 *	from localized storage (corresponding given locale object)
 *	by mcLiterals[mcKey] (e. g. MONTHS_FULL).
 *
 * Results:
 *	Tcl-object contains localized value.
 *
 *----------------------------------------------------------------------
 */
Tcl_Obj *
TclClockMCGet(
    ClockFmtScnCmdArgs *opts,
    int mcKey)
{
    Tcl_Obj *valObj = NULL;

    if (opts->mcDictObj == NULL) {
	TclClockMCDict(opts);
	if (opts->mcDictObj == NULL) {
	    return NULL;
	}
    }

    Tcl_DictObjGet(opts->interp, opts->mcDictObj,
	    opts->dataPtr->mcLiterals[mcKey], &valObj);
    return valObj; /* or NULL in obscure case if Tcl_DictObjGet failed */
}

/*
 *----------------------------------------------------------------------
 *
 * TclClockMCGetIdx --
 *
 *	Retrieves an indexed msgcat value for the given literal integer mcKey
 *	from localized storage (corresponding given locale object)
 *	by mcLitIdxs[mcKey] (e. g. _IDX_MONTHS_FULL).
 *
 * Results:
 *	Tcl-object contains localized indexed value.
 *
 *----------------------------------------------------------------------
 */
Tcl_Obj *
TclClockMCGetIdx(
    ClockFmtScnCmdArgs *opts,
    int mcKey)
{
    ClockClientData *dataPtr = opts->dataPtr;
    Tcl_Obj *valObj = NULL;

    if (opts->mcDictObj == NULL) {
	TclClockMCDict(opts);
	if (opts->mcDictObj == NULL) {
	    return NULL;
	}
    }

    /* try to get indices object */
    if (dataPtr->mcLitIdxs == NULL) {
	return NULL;
    }

    if (Tcl_DictObjGet(NULL, opts->mcDictObj,
	    dataPtr->mcLitIdxs[mcKey], &valObj) != TCL_OK) {
	return NULL;
    }
    return valObj;
}

/*
 *----------------------------------------------------------------------
 *
 * TclClockMCSetIdx --
 *
 *	Sets an indexed msgcat value for the given literal integer mcKey
 *	in localized storage (corresponding given locale object)
 *	by mcLitIdxs[mcKey] (e. g. _IDX_MONTHS_FULL).
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 *----------------------------------------------------------------------
 */
int
TclClockMCSetIdx(
    ClockFmtScnCmdArgs *opts,
    int mcKey,
    Tcl_Obj *valObj)
{
    ClockClientData *dataPtr = opts->dataPtr;

    if (opts->mcDictObj == NULL) {
	TclClockMCDict(opts);
	if (opts->mcDictObj == NULL) {
	    return TCL_ERROR;
	}
    }

    /* if literal storage for indices not yet created */
    if (dataPtr->mcLitIdxs == NULL) {
	int i;

	dataPtr->mcLitIdxs = (Tcl_Obj **)Tcl_Alloc(MCLIT__END * sizeof(Tcl_Obj*));
	for (i = 0; i < MCLIT__END; ++i) {
	    TclInitObjRef(dataPtr->mcLitIdxs[i],
		    Tcl_NewStringObj(MsgCtLitIdxs[i], TCL_AUTO_LENGTH));
	}
    }

    return Tcl_DictObjPut(opts->interp, opts->mcDictObj,
	    dataPtr->mcLitIdxs[mcKey], valObj);
}

static void
TimezoneLoaded(
    ClockClientData *dataPtr,
    Tcl_Obj *timezoneObj,	/* Name of zone was loaded */
    Tcl_Obj *tzUnnormObj)	/* Name of zone was loaded */
{
    /* don't overwrite last-setup with GMT (special case) */
    if (timezoneObj == dataPtr->literals[LIT_GMT]) {
	/* mark GMT zone loaded */
	if (dataPtr->gmtSetupTimeZone == NULL) {
	    TclSetObjRef(dataPtr->gmtSetupTimeZone,
		    dataPtr->literals[LIT_GMT]);
	}
	TclSetObjRef(dataPtr->gmtSetupTimeZoneUnnorm, tzUnnormObj);
	return;
    }

    /* last setup zone loaded */
    if (dataPtr->lastSetupTimeZone != timezoneObj) {
	SavePrevTimezoneObj(dataPtr);
	TclSetObjRef(dataPtr->lastSetupTimeZone, timezoneObj);
	TclUnsetObjRef(dataPtr->lastSetupTZData);
    }
    TclSetObjRef(dataPtr->lastSetupTimeZoneUnnorm, tzUnnormObj);
}
/*
 *----------------------------------------------------------------------
 *
 * ClockConfigureObjCmd --
 *
 *	This function is invoked to process the Tcl "::tcl::unsupported::clock::configure"
 *	(internal, unsupported) command.
 *
 * Usage:
 *	::tcl::unsupported::clock::configure ?-option ?value??
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
ClockConfigureObjCmd(
    void *clientData,		/* Client data containing literal pool */
    Tcl_Interp *interp,		/* Tcl interpreter */
    int objc,			/* Parameter count */
    Tcl_Obj *const objv[])	/* Parameter vector */
{
    ClockClientData *dataPtr = (ClockClientData *)clientData;
    static const char *const options[] = {
	"-default-locale",	"-clear",	  "-current-locale",
	"-year-century",  "-century-switch",
	"-min-year", "-max-year", "-max-jdn", "-validate",
	"-init-complete",	  "-setup-tz", "-system-tz", NULL
    };
    enum optionInd {
	CLOCK_DEFAULT_LOCALE, CLOCK_CLEAR_CACHE, CLOCK_CURRENT_LOCALE,
	CLOCK_YEAR_CENTURY, CLOCK_CENTURY_SWITCH,
	CLOCK_MIN_YEAR, CLOCK_MAX_YEAR, CLOCK_MAX_JDN, CLOCK_VALIDATE,
	CLOCK_INIT_COMPLETE,  CLOCK_SETUP_TZ, CLOCK_SYSTEM_TZ
    };
    int optionIndex;		/* Index of an option. */
    Tcl_Size i;

    for (i = 1; i < objc; i++) {
	if (Tcl_GetIndexFromObj(interp, objv[i++], options,
		"option", 0, &optionIndex) != TCL_OK) {
	    Tcl_SetErrorCode(interp, "CLOCK", "badOption",
		    TclGetString(objv[i - 1]), (char *)NULL);
	    return TCL_ERROR;
	}
	switch (optionIndex) {
	case CLOCK_SYSTEM_TZ: {
	    /* validate current tz-epoch */
	    size_t lastTZEpoch = TzsetIfNecessary();

	    if (i < objc) {
		if (dataPtr->systemTimeZone != objv[i]) {
		    TclSetObjRef(dataPtr->systemTimeZone, objv[i]);
		    TclUnsetObjRef(dataPtr->systemSetupTZData);
		}
		if (dataPtr->lastTZEpoch != lastTZEpoch) {
		    dataPtr->lastTZEpoch = lastTZEpoch;
		    /* TZ epoch changed - invalidate base-cache */
		    TclUnsetObjRef(dataPtr->lastBase.timezoneObj);
		}
	    }
	    if (i + 1 >= objc && dataPtr->systemTimeZone != NULL
		    && dataPtr->lastTZEpoch == lastTZEpoch) {
		Tcl_SetObjResult(interp, dataPtr->systemTimeZone);
	    }
	    break;
	}
	case CLOCK_SETUP_TZ:
	    if (i < objc) {
		int loaded;
		Tcl_Obj *timezoneObj = NormTimezoneObj(dataPtr, objv[i], &loaded);

		if (!loaded) {
		    TimezoneLoaded(dataPtr, timezoneObj, objv[i]);
		}
		Tcl_SetObjResult(interp, timezoneObj);
	    } else if (i + 1 >= objc && dataPtr->lastSetupTimeZone != NULL) {
		Tcl_SetObjResult(interp, dataPtr->lastSetupTimeZone);
	    }
	    break;
	case CLOCK_DEFAULT_LOCALE:
	    if (i < objc) {
		if (dataPtr->defaultLocale != objv[i]) {
		    TclSetObjRef(dataPtr->defaultLocale, objv[i]);
		    dataPtr->defaultLocaleDict = NULL;
		}
	    }
	    if (i + 1 >= objc) {
		Tcl_SetObjResult(interp, dataPtr->defaultLocale ?
			dataPtr->defaultLocale : dataPtr->literals[LIT_C]);
	    }
	    break;
	case CLOCK_CURRENT_LOCALE:
	    if (i < objc) {
		if (dataPtr->currentLocale != objv[i]) {
		    TclSetObjRef(dataPtr->currentLocale, objv[i]);
		    dataPtr->currentLocaleDict = NULL;
		}
	    }
	    if (i + 1 >= objc && dataPtr->currentLocale != NULL) {
		Tcl_SetObjResult(interp, dataPtr->currentLocale);
	    }
	    break;
	case CLOCK_YEAR_CENTURY:
	    if (i < objc) {
		int year;

		if (TclGetIntFromObj(interp, objv[i], &year) != TCL_OK) {
		    return TCL_ERROR;
		}
		dataPtr->currentYearCentury = year;
		if (i + 1 >= objc) {
		    Tcl_SetObjResult(interp, objv[i]);
		}
		continue;
	    }
	    if (i + 1 >= objc) {
		Tcl_SetObjResult(interp,
			Tcl_NewWideIntObj(dataPtr->currentYearCentury));
	    }
	    break;
	case CLOCK_CENTURY_SWITCH:
	    if (i < objc) {
		int year;

		if (TclGetIntFromObj(interp, objv[i], &year) != TCL_OK) {
		    return TCL_ERROR;
		}
		dataPtr->yearOfCenturySwitch = year;
		Tcl_SetObjResult(interp, objv[i]);
		continue;
	    }
	    if (i + 1 >= objc) {
		Tcl_SetObjResult(interp,
			Tcl_NewWideIntObj(dataPtr->yearOfCenturySwitch));
	    }
	    break;
	case CLOCK_MIN_YEAR:
	    if (i < objc) {
		int year;

		if (TclGetIntFromObj(interp, objv[i], &year) != TCL_OK) {
		    return TCL_ERROR;
		}
		dataPtr->validMinYear = year;
		Tcl_SetObjResult(interp, objv[i]);
		continue;
	    }
	    if (i + 1 >= objc) {
		Tcl_SetObjResult(interp,
			Tcl_NewWideIntObj(dataPtr->validMinYear));
	    }
	    break;
	case CLOCK_MAX_YEAR:
	    if (i < objc) {
		int year;

		if (TclGetIntFromObj(interp, objv[i], &year) != TCL_OK) {
		    return TCL_ERROR;
		}
		dataPtr->validMaxYear = year;
		Tcl_SetObjResult(interp, objv[i]);
		continue;
	    }
	    if (i + 1 >= objc) {
		Tcl_SetObjResult(interp,
			Tcl_NewWideIntObj(dataPtr->validMaxYear));
	    }
	    break;
	case CLOCK_MAX_JDN:
	    if (i < objc) {
		double jd;

		if (Tcl_GetDoubleFromObj(interp, objv[i], &jd) != TCL_OK) {
		    return TCL_ERROR;
		}
		dataPtr->maxJDN = jd;
		Tcl_SetObjResult(interp, objv[i]);
		continue;
	    }
	    if (i + 1 >= objc) {
		Tcl_SetObjResult(interp, Tcl_NewDoubleObj(dataPtr->maxJDN));
	    }
	    break;
	case CLOCK_VALIDATE:
	    if (i < objc) {
		int val;

		if (Tcl_GetBooleanFromObj(interp, objv[i], &val) != TCL_OK) {
		    return TCL_ERROR;
		}
		if (val) {
		    dataPtr->defFlags |= CLF_VALIDATE;
		} else {
		    dataPtr->defFlags &= ~CLF_VALIDATE;
		}
	    }
	    if (i + 1 >= objc) {
		Tcl_SetObjResult(interp,
			Tcl_NewBooleanObj(dataPtr->defFlags & CLF_VALIDATE));
	    }
	    break;
	case CLOCK_CLEAR_CACHE:
	    ClockConfigureClear(dataPtr);
	    break;
	case CLOCK_INIT_COMPLETE: {
	    /*
	     * Init completed.
	     * Compile clock ensemble (performance purposes).
	     */
	    Tcl_Command token = Tcl_FindCommand(interp, "::clock",
		    NULL, TCL_GLOBAL_ONLY);
	    if (!token) {
		return TCL_ERROR;
	    }
	    int ensFlags = 0;
	    if (Tcl_GetEnsembleFlags(interp, token, &ensFlags) != TCL_OK) {
		return TCL_ERROR;
	    }
	    ensFlags |= ENSEMBLE_COMPILE;
	    if (Tcl_SetEnsembleFlags(interp, token, ensFlags) != TCL_OK) {
		return TCL_ERROR;
	    }
	    break;
	}
	default:
	    TCL_UNREACHABLE();
	}
    }

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ClockGetTZData --
 *
 *	Retrieves tzdata table for given normalized timezone.
 *
 * Results:
 *	Returns a tcl object with tzdata.
 *
 * Side effects:
 *	The tzdata can be cached in ClockClientData structure.
 *
 *----------------------------------------------------------------------
 */

static inline Tcl_Obj *
ClockGetTZData(
    ClockClientData *dataPtr,	/* Opaque pointer to literal pool, etc. */
    Tcl_Interp *interp,		/* Tcl interpreter */
    Tcl_Obj *timezoneObj)	/* Name of the timezone */
{
    Tcl_Obj *ret, **out = NULL;

    /* if cached (if already setup this one) */
    if (timezoneObj == dataPtr->lastSetupTimeZone
	    || timezoneObj == dataPtr->lastSetupTimeZoneUnnorm) {
	if (dataPtr->lastSetupTZData != NULL) {
	    return dataPtr->lastSetupTZData;
	}
	out = &dataPtr->lastSetupTZData;
    }
    /* differentiate GMT and system zones, because used often */
    /* simple caching, because almost used the tz-data of last timezone
     */
    if (timezoneObj == dataPtr->systemTimeZone) {
	if (dataPtr->systemSetupTZData != NULL) {
	    return dataPtr->systemSetupTZData;
	}
	out = &dataPtr->systemSetupTZData;
    } else if (timezoneObj == dataPtr->literals[LIT_GMT]
	    || timezoneObj == dataPtr->gmtSetupTimeZoneUnnorm) {
	if (dataPtr->gmtSetupTZData != NULL) {
	    return dataPtr->gmtSetupTZData;
	}
	out = &dataPtr->gmtSetupTZData;
    } else if (timezoneObj == dataPtr->prevSetupTimeZone
	    || timezoneObj == dataPtr->prevSetupTimeZoneUnnorm) {
	if (dataPtr->prevSetupTZData != NULL) {
	    return dataPtr->prevSetupTZData;
	}
	out = &dataPtr->prevSetupTZData;
    }

    ret = Tcl_ObjGetVar2(interp, dataPtr->literals[LIT_TZDATA],
	    timezoneObj, TCL_LEAVE_ERR_MSG);

    /* cache using corresponding slot and as last used */
    if (out != NULL) {
	TclSetObjRef(*out, ret);
    } else if (dataPtr->lastSetupTimeZone != timezoneObj) {
	SavePrevTimezoneObj(dataPtr);
	TclSetObjRef(dataPtr->lastSetupTimeZone, timezoneObj);
	TclUnsetObjRef(dataPtr->lastSetupTimeZoneUnnorm);
	TclSetObjRef(dataPtr->lastSetupTZData, ret);
    }
    return ret;
}

/*
 *----------------------------------------------------------------------
 *
 * ClockGetSystemTimeZone --
 *
 *	Returns system (current) timezone.
 *
 *	If system zone not yet cached, it executes ::tcl::clock::GetSystemTimeZone
 *	in given interpreter and caches its result.
 *
 * Results:
 *	Returns normalized timezone object.
 *
 *----------------------------------------------------------------------
 */

static Tcl_Obj *
ClockGetSystemTimeZone(
    ClockClientData *dataPtr,	/* Pointer to literal pool, etc. */
    Tcl_Interp *interp)		/* Tcl interpreter */
{
    /* if known (cached and same epoch) - return now */
    if (dataPtr->systemTimeZone != NULL
	    && dataPtr->lastTZEpoch == TzsetIfNecessary()) {
	return dataPtr->systemTimeZone;
    }

    TclUnsetObjRef(dataPtr->systemTimeZone);
    TclUnsetObjRef(dataPtr->systemSetupTZData);

    if (Tcl_EvalObjv(interp, 1, &dataPtr->literals[LIT_GETSYSTEMTIMEZONE], 0) != TCL_OK) {
	return NULL;
    }
    if (dataPtr->systemTimeZone == NULL) {
	TclSetObjRef(dataPtr->systemTimeZone, Tcl_GetObjResult(interp));
    }
    Tcl_ResetResult(interp);
    return dataPtr->systemTimeZone;
}

/*
 *----------------------------------------------------------------------
 *
 * TclClockSetupTimeZone --
 *
 *	Sets up the timezone. Loads tzdata, etc.
 *
 * Results:
 *	Returns normalized timezone object.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
TclClockSetupTimeZone(
    ClockClientData *dataPtr,	/* Pointer to literal pool, etc. */
    Tcl_Interp *interp,		/* Tcl interpreter */
    Tcl_Obj *timezoneObj)
{
    int loaded;
    Tcl_Obj *callargs[2];

    /* if cached (if already setup this one) */
    if (timezoneObj == dataPtr->literals[LIT_GMT]
	    && dataPtr->gmtSetupTZData != NULL) {
	return timezoneObj;
    }
    if ((timezoneObj == dataPtr->lastSetupTimeZone
	    || timezoneObj == dataPtr->lastSetupTimeZoneUnnorm)
	    && dataPtr->lastSetupTimeZone != NULL) {
	return dataPtr->lastSetupTimeZone;
    }
    if ((timezoneObj == dataPtr->prevSetupTimeZone
	    || timezoneObj == dataPtr->prevSetupTimeZoneUnnorm)
	    && dataPtr->prevSetupTimeZone != NULL) {
	return dataPtr->prevSetupTimeZone;
    }

    /* differentiate normalized (last, GMT and system) zones, because used often and already set */
    callargs[1] = NormTimezoneObj(dataPtr, timezoneObj, &loaded);
    /* if loaded (setup already called for this TZ) */
    if (loaded) {
	return callargs[1];
    }

    /* before setup just take a look in TZData variable */
    if (Tcl_ObjGetVar2(interp, dataPtr->literals[LIT_TZDATA], timezoneObj, 0)) {
	/* put it to last slot and return normalized */
	TimezoneLoaded(dataPtr, callargs[1], timezoneObj);
	return callargs[1];
    }
    /* setup now */
    callargs[0] = dataPtr->literals[LIT_SETUPTIMEZONE];
    if (Tcl_EvalObjv(interp, 2, callargs, 0) == TCL_OK) {
	/* save unnormalized last used */
	TclSetObjRef(dataPtr->lastSetupTimeZoneUnnorm, timezoneObj);
	return callargs[1];
    }
    return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * ClockFormatNumericTimeZone --
 *
 *	Formats a time zone as +hhmmss
 *
 * Parameters:
 *	z - Time zone in seconds east of Greenwich
 *
 * Results:
 *	Returns the time zone object (formatted in a numeric form)
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */
static Tcl_Obj *
ClockFormatNumericTimeZone(
    int z)
{
    char buf[12 + 1], *p;

    if (z < 0) {
	z = -z;
	*buf = '-';
    } else {
	*buf = '+';
    }
    TclItoAw(buf + 1, z / 3600, '0', 2);
    z %= 3600;
    p = TclItoAw(buf + 3, z / 60, '0', 2);
    z %= 60;
    if (z != 0) {
	p = TclItoAw(buf + 5, z, '0', 2);
    }
    return Tcl_NewStringObj(buf, p - buf);
}

/*
 *----------------------------------------------------------------------
 *
 * ClockConvertlocaltoutcObjCmd --
 *
 *	Tcl command that converts a UTC time to a local time by whatever means
 *	is available.
 *
 * Usage:
 *	::tcl::clock::ConvertUTCToLocal dictionary timezone changeover
 *
 * Parameters:
 *	dict - Dictionary containing a 'localSeconds' entry.
 *	timezone - Time zone
 *	changeover - Julian Day of the adoption of the Gregorian calendar.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	On success, sets the interpreter result to the given dictionary
 *	augmented with a 'seconds' field giving the UTC time. On failure,
 *	leaves an error message in the interpreter result.
 *
 *----------------------------------------------------------------------
 */

static int
ClockConvertlocaltoutcObjCmd(
    void *clientData,		/* Literal table */
    Tcl_Interp *interp,		/* Tcl interpreter */
    int objc,			/* Parameter count */
    Tcl_Obj *const *objv)	/* Parameter vector */
{
    ClockClientData *dataPtr = (ClockClientData *)clientData;
    Tcl_Obj *secondsObj;
    Tcl_Obj *dict;
    int changeover;
    TclDateFields fields;
    int created = 0;
    int status;

    fields.tzName = NULL;
    /*
     * Check params and convert time.
     */

    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "dict timezone changeover");
	return TCL_ERROR;
    }
    dict = objv[1];
    if (Tcl_DictObjGet(interp, dict, dataPtr->literals[LIT_LOCALSECONDS],
	    &secondsObj)!= TCL_OK) {
	return TCL_ERROR;
    }
    if (secondsObj == NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("key \"localseconds\" not "
		"found in dictionary", TCL_AUTO_LENGTH));
	return TCL_ERROR;
    }
    if ((TclGetWideIntFromObj(interp, secondsObj, &fields.localSeconds) != TCL_OK)
	    || (TclGetIntFromObj(interp, objv[3], &changeover) != TCL_OK)
	    || ConvertLocalToUTC(dataPtr, interp, &fields, objv[2], changeover)) {
	return TCL_ERROR;
    }

    /*
     * Copy-on-write; set the 'seconds' field in the dictionary and place the
     * modified dictionary in the interpreter result.
     */

    if (Tcl_IsShared(dict)) {
	dict = Tcl_DuplicateObj(dict);
	created = 1;
	Tcl_IncrRefCount(dict);
    }
    status = Tcl_DictObjPut(interp, dict, dataPtr->literals[LIT_SECONDS],
	    Tcl_NewWideIntObj(fields.seconds));
    if (status == TCL_OK) {
	Tcl_SetObjResult(interp, dict);
    }
    if (created) {
	Tcl_DecrRefCount(dict);
    }
    return status;
}

/*
 *----------------------------------------------------------------------
 *
 * ClockGetdatefieldsObjCmd --
 *
 *	Tcl command that determines the values that [clock format] will use in
 *	formatting a date, and populates a dictionary with them.
 *
 * Usage:
 *	::tcl::clock::GetDateFields seconds timezone changeover
 *
 * Parameters:
 *	seconds - Time expressed in seconds from the Posix epoch.
 *	timezone - Time zone in which time is to be expressed.
 *	changeover - Julian Day Number at which the current locale adopted
 *		     the Gregorian calendar
 *
 * Results:
 *	Returns a dictonary populated with the fields:
 *		seconds - Seconds from the Posix epoch
 *		localSeconds - Nominal seconds from the Posix epoch in the
 *			       local time zone.
 *		tzOffset - Time zone offset in seconds east of Greenwich
 *		tzName - Time zone name
 *		julianDay - Julian Day Number in the local time zone
 *
 *----------------------------------------------------------------------
 */

int
ClockGetdatefieldsObjCmd(
    void *clientData,		/* Opaque pointer to literal pool, etc. */
    Tcl_Interp *interp,		/* Tcl interpreter */
    int objc,			/* Parameter count */
    Tcl_Obj *const *objv)	/* Parameter vector */
{
    TclDateFields fields;
    Tcl_Obj *dict;
    ClockClientData *dataPtr = (ClockClientData *)clientData;
    Tcl_Obj *const *lit = dataPtr->literals;
    int changeover;

    fields.tzName = NULL;

    /*
     * Check params.
     */

    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "seconds timezone changeover");
	return TCL_ERROR;
    }
    if (TclGetWideIntFromObj(interp, objv[1], &fields.seconds) != TCL_OK
	    || TclGetIntFromObj(interp, objv[3], &changeover) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * fields.seconds could be an unsigned number that overflowed. Make sure
     * that it isn't.
     */

    if (TclHasInternalRep(objv[1], &tclBignumType)) {
	Tcl_SetObjResult(interp, lit[LIT_INTEGER_VALUE_TOO_LARGE]);
	return TCL_ERROR;
    }

    /* Extract fields */

    if (ClockGetDateFields(dataPtr, interp, &fields, objv[2],
	    changeover) != TCL_OK) {
	return TCL_ERROR;
    }

    /* Make dict of fields */

    dict = Tcl_NewDictObj();
    Tcl_DictObjPut(NULL, dict, lit[LIT_LOCALSECONDS],
	    Tcl_NewWideIntObj(fields.localSeconds));
    Tcl_DictObjPut(NULL, dict, lit[LIT_SECONDS],
	    Tcl_NewWideIntObj(fields.seconds));
    Tcl_DictObjPut(NULL, dict, lit[LIT_TZNAME], fields.tzName);
    Tcl_DecrRefCount(fields.tzName);
    Tcl_DictObjPut(NULL, dict, lit[LIT_TZOFFSET],
	    Tcl_NewWideIntObj(fields.tzOffset));
    Tcl_DictObjPut(NULL, dict, lit[LIT_JULIANDAY],
	    Tcl_NewWideIntObj(fields.julianDay));
    Tcl_DictObjPut(NULL, dict, lit[LIT_GREGORIAN],
	    Tcl_NewWideIntObj(fields.gregorian));
    Tcl_DictObjPut(NULL, dict, lit[LIT_ERA],
	    lit[fields.isBce ? LIT_BCE : LIT_CE]);
    Tcl_DictObjPut(NULL, dict, lit[LIT_YEAR],
	    Tcl_NewWideIntObj(fields.year));
    Tcl_DictObjPut(NULL, dict, lit[LIT_DAYOFYEAR],
	    Tcl_NewWideIntObj(fields.dayOfYear));
    Tcl_DictObjPut(NULL, dict, lit[LIT_MONTH],
	    Tcl_NewWideIntObj(fields.month));
    Tcl_DictObjPut(NULL, dict, lit[LIT_DAYOFMONTH],
	    Tcl_NewWideIntObj(fields.dayOfMonth));
    Tcl_DictObjPut(NULL, dict, lit[LIT_ISO8601YEAR],
	    Tcl_NewWideIntObj(fields.iso8601Year));
    Tcl_DictObjPut(NULL, dict, lit[LIT_ISO8601WEEK],
	    Tcl_NewWideIntObj(fields.iso8601Week));
    Tcl_DictObjPut(NULL, dict, lit[LIT_DAYOFWEEK],
	    Tcl_NewWideIntObj(fields.dayOfWeek));
    Tcl_SetObjResult(interp, dict);

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ClockGetDateFields --
 *
 *	Converts given UTC time (seconds in a TclDateFields structure)
 *	to local time and determines the values that clock routines will
 *	use in scanning or formatting a date.
 *
 * Results:
 *	Date-time values are stored in structure "fields".
 *	Returns a standard Tcl result.
 *
 *----------------------------------------------------------------------
 */

int
ClockGetDateFields(
    ClockClientData *dataPtr,	/* Literal pool, etc. */
    Tcl_Interp *interp,		/* Tcl interpreter */
    TclDateFields *fields,	/* Pointer to result fields, where
				 * fields->seconds contains date to extract */
    Tcl_Obj *timezoneObj,	/* Time zone object or NULL for gmt */
    int changeover)		/* Julian Day Number */
{
    /*
     * Convert UTC time to local.
     */

    if (TclConvertUTCToLocal(dataPtr, interp, fields, timezoneObj,
	    changeover) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * Extract Julian day and seconds of the day.
     */

    ClockExtractJDAndSODFromSeconds(fields->julianDay, fields->secondOfDay,
	    fields->localSeconds);

    /*
     * Convert to Julian or Gregorian calendar.
     */

    GetGregorianEraYearDay(fields, changeover);
    GetMonthDay(fields);
    GetYearWeekDay(fields, changeover);

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ClockGetjuliandayfromerayearmonthdayObjCmd --
 *
 *	Tcl command that converts a time from era-year-month-day to a Julian
 *	Day Number.
 *
 * Parameters:
 *	dict - Dictionary that contains 'era', 'year', 'month' and
 *	       'dayOfMonth' keys.
 *	changeover - Julian Day of changeover to the Gregorian calendar
 *
 * Results:
 *	Result is either TCL_OK, with the interpreter result being the
 *	dictionary augmented with a 'julianDay' key, or TCL_ERROR,
 *	with the result being an error message.
 *
 *----------------------------------------------------------------------
 */

static int
FetchEraField(
    Tcl_Interp *interp,
    Tcl_Obj *dict,
    Tcl_Obj *key,
    int *storePtr)
{
    Tcl_Obj *value = NULL;

    if (Tcl_DictObjGet(interp, dict, key, &value) != TCL_OK) {
	return TCL_ERROR;
    }
    if (value == NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"expected key(s) not found in dictionary", TCL_AUTO_LENGTH));
	return TCL_ERROR;
    }
    return Tcl_GetIndexFromObj(interp, value, eras, "era", TCL_EXACT, storePtr);
}

static int
FetchIntField(
    Tcl_Interp *interp,
    Tcl_Obj *dict,
    Tcl_Obj *key,
    int *storePtr)
{
    Tcl_Obj *value = NULL;

    if (Tcl_DictObjGet(interp, dict, key, &value) != TCL_OK) {
	return TCL_ERROR;
    }
    if (value == NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"expected key(s) not found in dictionary", TCL_AUTO_LENGTH));
	return TCL_ERROR;
    }
    return TclGetIntFromObj(interp, value, storePtr);
}

static int
ClockGetjuliandayfromerayearmonthdayObjCmd(
    void *clientData,		/* Opaque pointer to literal pool, etc. */
    Tcl_Interp *interp,		/* Tcl interpreter */
    int objc,			/* Parameter count */
    Tcl_Obj *const *objv)	/* Parameter vector */
{
    TclDateFields fields;
    Tcl_Obj *dict;
    ClockClientData *data = (ClockClientData *)clientData;
    Tcl_Obj *const *lit = data->literals;
    int changeover;
    int copied = 0;
    int status;
    int isBce = 0;

    fields.tzName = NULL;

    /*
     * Check params.
     */

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "dict changeover");
	return TCL_ERROR;
    }
    dict = objv[1];
    if (FetchEraField(interp, dict, lit[LIT_ERA], &isBce) != TCL_OK
	    || FetchIntField(interp, dict, lit[LIT_YEAR], &fields.year)
		!= TCL_OK
	    || FetchIntField(interp, dict, lit[LIT_MONTH], &fields.month)
		!= TCL_OK
	    || FetchIntField(interp, dict, lit[LIT_DAYOFMONTH],
		&fields.dayOfMonth) != TCL_OK
	    || TclGetIntFromObj(interp, objv[2], &changeover) != TCL_OK) {
	return TCL_ERROR;
    }
    fields.isBce = isBce;

    /*
     * Get Julian day.
     */

    GetJulianDayFromEraYearMonthDay(&fields, changeover);

    /*
     * Store Julian day in the dictionary - copy on write.
     */

    if (Tcl_IsShared(dict)) {
	dict = Tcl_DuplicateObj(dict);
	Tcl_IncrRefCount(dict);
	copied = 1;
    }
    status = Tcl_DictObjPut(interp, dict, lit[LIT_JULIANDAY],
	    Tcl_NewWideIntObj(fields.julianDay));
    if (status == TCL_OK) {
	Tcl_SetObjResult(interp, dict);
    }
    if (copied) {
	Tcl_DecrRefCount(dict);
    }
    return status;
}

/*
 *----------------------------------------------------------------------
 *
 * ClockGetjuliandayfromerayearweekdayObjCmd --
 *
 *	Tcl command that converts a time from the ISO calendar to a Julian Day
 *	Number.
 *
 * Parameters:
 *	dict - Dictionary that contains 'era', 'iso8601Year', 'iso8601Week'
 *	       and 'dayOfWeek' keys.
 *	changeover - Julian Day of changeover to the Gregorian calendar
 *
 * Results:
 *	Result is either TCL_OK, with the interpreter result being the
 *	dictionary augmented with a 'julianDay' key, or TCL_ERROR, with the
 *	result being an error message.
 *
 *----------------------------------------------------------------------
 */

static int
ClockGetjuliandayfromerayearweekdayObjCmd(
    void *clientData,		/* Opaque pointer to literal pool, etc. */
    Tcl_Interp *interp,		/* Tcl interpreter */
    int objc,			/* Parameter count */
    Tcl_Obj *const *objv)	/* Parameter vector */
{
    TclDateFields fields;
    Tcl_Obj *dict;
    ClockClientData *data = (ClockClientData *)clientData;
    Tcl_Obj *const *lit = data->literals;
    int changeover;
    int copied = 0;
    int status;
    int isBce = 0;

    fields.tzName = NULL;

    /*
     * Check params.
     */

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "dict changeover");
	return TCL_ERROR;
    }
    dict = objv[1];
    if (FetchEraField(interp, dict, lit[LIT_ERA], &isBce) != TCL_OK
	    || FetchIntField(interp, dict, lit[LIT_ISO8601YEAR],
		&fields.iso8601Year) != TCL_OK
	    || FetchIntField(interp, dict, lit[LIT_ISO8601WEEK],
		&fields.iso8601Week) != TCL_OK
	    || FetchIntField(interp, dict, lit[LIT_DAYOFWEEK],
		&fields.dayOfWeek) != TCL_OK
	    || TclGetIntFromObj(interp, objv[2], &changeover) != TCL_OK) {
	return TCL_ERROR;
    }
    fields.isBce = isBce;

    /*
     * Get Julian day.
     */

    GetJulianDayFromEraYearWeekDay(&fields, changeover);

    /*
     * Store Julian day in the dictionary - copy on write.
     */

    if (Tcl_IsShared(dict)) {
	dict = Tcl_DuplicateObj(dict);
	Tcl_IncrRefCount(dict);
	copied = 1;
    }
    status = Tcl_DictObjPut(interp, dict, lit[LIT_JULIANDAY],
	    Tcl_NewWideIntObj(fields.julianDay));
    if (status == TCL_OK) {
	Tcl_SetObjResult(interp, dict);
    }
    if (copied) {
	Tcl_DecrRefCount(dict);
    }
    return status;
}

/*
 *----------------------------------------------------------------------
 *
 * ConvertLocalToUTC --
 *
 *	Converts a time (in a TclDateFields structure) from the local wall
 *	clock to UTC.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	Populates the 'seconds' field if successful; stores an error message
 *	in the interpreter result on failure.
 *
 *----------------------------------------------------------------------
 */

static int
ConvertLocalToUTC(
    ClockClientData *dataPtr,	/* Literal pool, etc. */
    Tcl_Interp *interp,		/* Tcl interpreter */
    TclDateFields *fields,	/* Fields of the time */
    Tcl_Obj *timezoneObj,	/* Time zone */
    int changeover)		/* Julian Day of the Gregorian transition */
{
    Tcl_Obj *tzdata;		/* Time zone data */
    Tcl_Size rowc;		/* Number of rows in tzdata */
    Tcl_Obj **rowv;		/* Pointers to the rows */
    Tcl_WideInt seconds;
    ClockLastTZOffs * ltzoc = NULL;

    /* fast phase-out for shared GMT-object (don't need to convert UTC 2 UTC) */
    if (timezoneObj == dataPtr->literals[LIT_GMT]) {
	fields->seconds = fields->localSeconds;
	fields->tzOffset = 0;
	return TCL_OK;
    }

    /*
     * Check cacheable conversion could be used
     * (last-period UTC2Local cache within the same TZ and seconds)
     */
    for (rowc = 0; rowc < 2; rowc++) {
	ltzoc = &dataPtr->lastTZOffsCache[rowc];
	if (timezoneObj != ltzoc->timezoneObj || changeover != ltzoc->changeover) {
	    ltzoc = NULL;
	    continue;
	}
	seconds = fields->localSeconds - ltzoc->tzOffset;
	if (seconds >= ltzoc->rangesVal[0]
		&& seconds < ltzoc->rangesVal[1]) {
	    /* the same time zone and offset (UTC time inside the last minute) */
	    fields->tzOffset = ltzoc->tzOffset;
	    fields->seconds = seconds;
	    return TCL_OK;
	}
	/* in the DST-hole (because of the check above) - correct localSeconds */
	if (fields->localSeconds == ltzoc->localSeconds) {
	    /* the same time zone and offset (but we'll shift local-time) */
	    fields->tzOffset = ltzoc->tzOffset;
	    fields->seconds = seconds;
	    goto dstHole;
	}
    }

    /*
     * Unpack the tz data.
     */

    tzdata = ClockGetTZData(dataPtr, interp, timezoneObj);
    if (tzdata == NULL) {
	return TCL_ERROR;
    }

    if (TclListObjGetElements(interp, tzdata, &rowc, &rowv) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * Special case: If the time zone is :localtime, the tzdata will be empty.
     * Use 'mktime' to convert the time to local
     */

    if (rowc == 0) {
	if (ConvertLocalToUTCUsingC(interp, fields, changeover) != TCL_OK) {
	    return TCL_ERROR;
	}

	/* we cannot cache (ranges unknown yet) - todo: check later the DST-hole here */
	return TCL_OK;
    } else {
	Tcl_WideInt rangesVal[2];

	if (ConvertLocalToUTCUsingTable(interp, fields, rowc, rowv,
		rangesVal) != TCL_OK) {
	    return TCL_ERROR;
	}

	seconds = fields->seconds;

	/* Cache the last conversion */
	if (ltzoc != NULL) { /* slot was found above */
	    /* timezoneObj and changeover are the same */
	    TclSetObjRef(ltzoc->tzName, fields->tzName); /* may be NULL */
	} else {
	    /* no TZ in cache - just move second slot down and use the first one */
	    ltzoc = &dataPtr->lastTZOffsCache[0];
	    TclUnsetObjRef(dataPtr->lastTZOffsCache[1].timezoneObj);
	    TclUnsetObjRef(dataPtr->lastTZOffsCache[1].tzName);
	    memcpy(&dataPtr->lastTZOffsCache[1], ltzoc, sizeof(*ltzoc));
	    TclInitObjRef(ltzoc->timezoneObj, timezoneObj);
	    ltzoc->changeover = changeover;
	    TclInitObjRef(ltzoc->tzName, fields->tzName); /* may be NULL */
	}
	ltzoc->localSeconds = fields->localSeconds;
	ltzoc->rangesVal[0] = rangesVal[0];
	ltzoc->rangesVal[1] = rangesVal[1];
	ltzoc->tzOffset = fields->tzOffset;
    }

    /* check DST-hole: if retrieved seconds is out of range */
    if (ltzoc->rangesVal[0] > seconds || seconds >= ltzoc->rangesVal[1]) {
    dstHole:
#if 0
	printf("given local-time is outside the time-zone (in DST-hole): "
		"%" TCL_LL_MODIFIER "d - offs %d => %" TCL_LL_MODIFIER "d <= %" TCL_LL_MODIFIER "d < %" TCL_LL_MODIFIER "d\n",
		fields->localSeconds, fields->tzOffset,
		ltzoc->rangesVal[0], seconds, ltzoc->rangesVal[1]);
#endif
	/* because we don't know real TZ (we're outsize), just invalidate local
	 * time (which could be verified in ClockValidDate later) */
	fields->localSeconds = TCL_INV_SECONDS; /* not valid seconds */
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ConvertLocalToUTCUsingTable --
 *
 *	Converts a time (in a TclDateFields structure) from local time in a
 *	given time zone to UTC.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	Stores an error message in the interpreter if an error occurs; if
 *	successful, stores the 'seconds' field in 'fields.
 *
 *----------------------------------------------------------------------
 */

static int
ConvertLocalToUTCUsingTable(
    Tcl_Interp *interp,		/* Tcl interpreter */
    TclDateFields *fields,	/* Time to convert, with 'seconds' filled in */
    int rowc,			/* Number of points at which time changes */
    Tcl_Obj *const rowv[],	/* Points at which time changes */
    Tcl_WideInt *rangesVal)	/* Return bounds for time period */
{
    Tcl_Obj *row;
    Tcl_Size cellc;
    Tcl_Obj **cellv;
    struct {
	Tcl_Obj *tzName;
	int tzOffset;
    } have[8];
    int nHave = 0;
    Tcl_Size i;

    /*
     * Perform an initial lookup assuming that local == UTC, and locate the
     * last time conversion prior to that time. Get the offset from that row,
     * and look up again. Continue until we find an offset that we found
     * before. This definition, rather than "the same offset" ensures that we
     * don't enter an endless loop, as would otherwise happen when trying to
     * convert a non-existent time such as 02:30 during the US Spring Daylight
     * Saving Time transition.
     */

    fields->tzOffset = 0;
    fields->seconds = fields->localSeconds;
    while (1) {
	row = TclClockLookupLastTransition(interp, fields->seconds, rowc, rowv,
		rangesVal);
	if ((row == NULL)
		|| TclListObjGetElements(interp, row, &cellc,
		    &cellv) != TCL_OK
		|| TclGetIntFromObj(interp, cellv[1],
		    &fields->tzOffset) != TCL_OK) {
	    return TCL_ERROR;
	}
	for (i = 0; i < nHave; ++i) {
	    if (have[i].tzOffset == fields->tzOffset) {
		goto found;
	    }
	}
	if (nHave == 8) {
	    Tcl_Panic("loop in ConvertLocalToUTCUsingTable");
	}
	have[nHave].tzName = cellv[3];
	have[nHave++].tzOffset = fields->tzOffset;
	fields->seconds = fields->localSeconds - fields->tzOffset;
    }

  found:
    fields->tzOffset = have[i].tzOffset;
    fields->seconds = fields->localSeconds - fields->tzOffset;
    TclSetObjRef(fields->tzName, have[i].tzName);

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ConvertLocalToUTCUsingC --
 *
 *	Converts a time from local wall clock to UTC when the local time zone
 *	cannot be determined. Uses 'mktime' to do the job.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	Stores an error message in the interpreter if an error occurs; if
 *	successful, stores the 'seconds' field in 'fields.
 *
 *----------------------------------------------------------------------
 */

static int
ConvertLocalToUTCUsingC(
    Tcl_Interp *interp,		/* Tcl interpreter */
    TclDateFields *fields,	/* Time to convert, with 'seconds' filled in */
    int changeover)		/* Julian Day of the Gregorian transition */
{
    struct tm timeVal;
    int localErrno;
    int secondOfDay;

    /*
     * Convert the given time to a date.
     */

    ClockExtractJDAndSODFromSeconds(fields->julianDay, secondOfDay,
	    fields->localSeconds);

    GetGregorianEraYearDay(fields, changeover);
    GetMonthDay(fields);

    /*
     * Convert the date/time to a 'struct tm'.
     */

    timeVal.tm_year = fields->year - 1900;
    timeVal.tm_mon = fields->month - 1;
    timeVal.tm_mday = fields->dayOfMonth;
    timeVal.tm_hour = (secondOfDay / 3600) % 24;
    timeVal.tm_min = (secondOfDay / 60) % 60;
    timeVal.tm_sec = secondOfDay % 60;
    timeVal.tm_isdst = -1;
    timeVal.tm_wday = -1;
    timeVal.tm_yday = -1;

    /*
     * Get local time. It is rumored that mktime is not thread safe on some
     * platforms, so seize a mutex before attempting this.
     */

    TzsetIfNecessary();
    Tcl_MutexLock(&clockMutex);
    errno = 0;
    fields->seconds = (Tcl_WideInt) mktime(&timeVal);
    localErrno = (fields->seconds == -1) ? errno : 0;
    Tcl_MutexUnlock(&clockMutex);

    /*
     * If conversion fails, report an error.
     */

    if (localErrno != 0
	    || (fields->seconds == -1 && timeVal.tm_yday == -1)) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"time value too large/small to represent", TCL_AUTO_LENGTH));
	return TCL_ERROR;
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TclConvertUTCToLocal --
 *
 *	Converts a time (in a TclDateFields structure) from UTC to local time.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	Populates the 'tzName' and 'tzOffset' fields.
 *
 *----------------------------------------------------------------------
 */

int
TclConvertUTCToLocal(
    ClockClientData *dataPtr,	/* Literal pool, etc. */
    Tcl_Interp *interp,		/* Tcl interpreter */
    TclDateFields *fields,	/* Fields of the time */
    Tcl_Obj *timezoneObj,	/* Time zone */
    int changeover)		/* Julian Day of the Gregorian transition */
{
    Tcl_Obj *tzdata;		/* Time zone data */
    Tcl_Size rowc;		/* Number of rows in tzdata */
    Tcl_Obj **rowv;		/* Pointers to the rows */
    ClockLastTZOffs * ltzoc = NULL;

    /* fast phase-out for shared GMT-object (don't need to convert UTC 2 UTC) */
    if (timezoneObj == dataPtr->literals[LIT_GMT]) {
	fields->localSeconds = fields->seconds;
	fields->tzOffset = 0;
	if (dataPtr->gmtTZName == NULL) {
	    Tcl_Obj *tzName;

	    tzdata = ClockGetTZData(dataPtr, interp, timezoneObj);
	    if (TclListObjGetElements(interp, tzdata, &rowc, &rowv) != TCL_OK
		    || Tcl_ListObjIndex(interp, rowv[0], 3, &tzName) != TCL_OK) {
		return TCL_ERROR;
	    }
	    TclSetObjRef(dataPtr->gmtTZName, tzName);
	}
	TclSetObjRef(fields->tzName, dataPtr->gmtTZName);
	return TCL_OK;
    }

    /*
     * Check cacheable conversion could be used
     * (last-period UTC2Local cache within the same TZ and seconds)
     */
    for (rowc = 0; rowc < 2; rowc++) {
	ltzoc = &dataPtr->lastTZOffsCache[rowc];
	if (timezoneObj != ltzoc->timezoneObj || changeover != ltzoc->changeover) {
	    ltzoc = NULL;
	    continue;
	}
	if (fields->seconds >= ltzoc->rangesVal[0]
		&& fields->seconds < ltzoc->rangesVal[1]) {
	    /* the same time zone and offset (UTC time inside the last minute) */
	    fields->tzOffset = ltzoc->tzOffset;
	    fields->localSeconds = fields->seconds + fields->tzOffset;
	    TclSetObjRef(fields->tzName, ltzoc->tzName);
	    return TCL_OK;
	}
    }

    /*
     * Unpack the tz data.
     */

    tzdata = ClockGetTZData(dataPtr, interp, timezoneObj);
    if (tzdata == NULL) {
	return TCL_ERROR;
    }

    if (TclListObjGetElements(interp, tzdata, &rowc, &rowv) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * Special case: If the time zone is :localtime, the tzdata will be empty.
     * Use 'localtime' to convert the time to local
     */

    if (rowc == 0) {
	if (ConvertUTCToLocalUsingC(interp, fields, changeover) != TCL_OK) {
	    return TCL_ERROR;
	}

	/* signal we need to revalidate TZ epoch next time fields gets used. */
	fields->flags |= CLF_CTZ;

	/* we cannot cache (ranges unknown yet) */
    } else {
	Tcl_WideInt rangesVal[2];

	if (ConvertUTCToLocalUsingTable(interp, fields, rowc, rowv,
		rangesVal) != TCL_OK) {
	    return TCL_ERROR;
	}

	/* converted using table (TZ isn't :localtime) */
	fields->flags &= ~CLF_CTZ;

	/* Cache the last conversion */
	if (ltzoc != NULL) { /* slot was found above */
	    /* timezoneObj and changeover are the same */
	    TclSetObjRef(ltzoc->tzName, fields->tzName);
	} else {
	    /* no TZ in cache - just move second slot down and use the first one */
	    ltzoc = &dataPtr->lastTZOffsCache[0];
	    TclUnsetObjRef(dataPtr->lastTZOffsCache[1].timezoneObj);
	    TclUnsetObjRef(dataPtr->lastTZOffsCache[1].tzName);
	    memcpy(&dataPtr->lastTZOffsCache[1], ltzoc, sizeof(*ltzoc));
	    TclInitObjRef(ltzoc->timezoneObj, timezoneObj);
	    ltzoc->changeover = changeover;
	    TclInitObjRef(ltzoc->tzName, fields->tzName);
	}
	ltzoc->localSeconds = fields->localSeconds;
	ltzoc->rangesVal[0] = rangesVal[0];
	ltzoc->rangesVal[1] = rangesVal[1];
	ltzoc->tzOffset = fields->tzOffset;
    }

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ConvertUTCToLocalUsingTable --
 *
 *	Converts UTC to local time, given a table of transition points
 *
 * Results:
 *	Returns a standard Tcl result
 *
 * Side effects:
 *	On success, fills fields->tzName, fields->tzOffset and
 *	fields->localSeconds. On failure, places an error message in the
 *	interpreter result.
 *
 *----------------------------------------------------------------------
 */

static int
ConvertUTCToLocalUsingTable(
    Tcl_Interp *interp,		/* Tcl interpreter */
    TclDateFields *fields,	/* Fields of the date */
    Tcl_Size rowc,		/* Number of rows in the conversion table
				 * (>= 1) */
    Tcl_Obj *const rowv[],	/* Rows of the conversion table */
    Tcl_WideInt *rangesVal)	/* Return bounds for time period */
{
    Tcl_Obj *row;		/* Row containing the current information */
    Tcl_Size cellc;		/* Count of cells in the row (must be 4) */
    Tcl_Obj **cellv;		/* Pointers to the cells */

    /*
     * Look up the nearest transition time.
     */

    row = TclClockLookupLastTransition(interp, fields->seconds, rowc, rowv, rangesVal);
    if (row == NULL
	    || TclListObjGetElements(interp, row, &cellc, &cellv) != TCL_OK
	    || TclGetIntFromObj(interp, cellv[1], &fields->tzOffset) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * Convert the time.
     */

    TclSetObjRef(fields->tzName, cellv[3]);
    fields->localSeconds = fields->seconds + fields->tzOffset;
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ConvertUTCToLocalUsingC --
 *
 *	Converts UTC to localtime in cases where the local time zone is not
 *	determinable, using the C 'localtime' function to do it.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	On success, fills fields->tzName, fields->tzOffset and
 *	fields->localSeconds. On failure, places an error message in the
 *	interpreter result.
 *
 *----------------------------------------------------------------------
 */

static int
ConvertUTCToLocalUsingC(
    Tcl_Interp *interp,		/* Tcl interpreter */
    TclDateFields *fields,	/* Time to convert, with 'seconds' filled in */
    int changeover)		/* Julian Day of the Gregorian transition */
{
    time_t tock;
    struct tm *timeVal;		/* Time after conversion */
    int diff;			/* Time zone diff local-Greenwich */
    char buffer[16], *p;	/* Buffer for time zone name */

    /*
     * Use 'localtime' to determine local year, month, day, time of day.
     */

    tock = (time_t) fields->seconds;
    if ((Tcl_WideInt) tock != fields->seconds) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"number too large to represent as a Posix time", TCL_AUTO_LENGTH));
	Tcl_SetErrorCode(interp, "CLOCK", "argTooLarge", (char *)NULL);
	return TCL_ERROR;
    }
    TzsetIfNecessary();
    timeVal = ThreadSafeLocalTime(&tock);
    if (timeVal == NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"localtime failed (clock value may be too "
		"large/small to represent)", TCL_AUTO_LENGTH));
	Tcl_SetErrorCode(interp, "CLOCK", "localtimeFailed", (char *)NULL);
	return TCL_ERROR;
    }

    /*
     * Fill in the date in 'fields' and use it to derive Julian Day.
     */

    fields->isBce = 0;
    fields->year = timeVal->tm_year + 1900;
    fields->month = timeVal->tm_mon + 1;
    fields->dayOfMonth = timeVal->tm_mday;
    GetJulianDayFromEraYearMonthDay(fields, changeover);

    /*
     * Convert that value to seconds.
     */

    fields->localSeconds = (((fields->julianDay * 24LL
	    + timeVal->tm_hour) * 60 + timeVal->tm_min) * 60
	    + timeVal->tm_sec) - JULIAN_SEC_POSIX_EPOCH;

    /*
     * Determine a time zone offset and name; just use +hhmm for the name.
     */

    diff = (int) (fields->localSeconds - fields->seconds);
    fields->tzOffset = diff;
    if (diff < 0) {
	*buffer = '-';
	diff = -diff;
    } else {
	*buffer = '+';
    }
    TclItoAw(buffer + 1, diff / 3600, '0', 2);
    diff %= 3600;
    p = TclItoAw(buffer + 3, diff / 60, '0', 2);
    diff %= 60;
    if (diff != 0) {
	p = TclItoAw(buffer + 5, diff, '0', 2);
    }
    TclSetObjRef(fields->tzName, Tcl_NewStringObj(buffer, p - buffer));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TclClockLookupLastTransition --
 *
 *	Given a UTC time and a tzdata array, looks up the last transition on
 *	or before the given time.
 *
 * Results:
 *	Returns a pointer to the row, or NULL if an error occurs.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
TclClockLookupLastTransition(
    Tcl_Interp *interp,		/* Interpreter for error messages */
    Tcl_WideInt tick,		/* Time from the epoch */
    Tcl_Size rowc,		/* Number of rows of tzdata */
    Tcl_Obj *const *rowv,	/* Rows in tzdata */
    Tcl_WideInt *rangesVal)	/* Return bounds for time period */
{
    Tcl_Size l, u;
    Tcl_Obj *compObj;
    Tcl_WideInt compVal, fromVal = LLONG_MIN, toVal = LLONG_MAX;

    /*
     * Examine the first row to make sure we're in bounds.
     */

    if (Tcl_ListObjIndex(interp, rowv[0], 0, &compObj) != TCL_OK
	    || TclGetWideIntFromObj(interp, compObj, &compVal) != TCL_OK) {
	return NULL;
    }

    /*
     * Bizarre case - first row doesn't begin at MIN_WIDE_INT. Return it
     * anyway.
     */

    if (tick < (fromVal = compVal)) {
	if (rangesVal) {
	    rangesVal[0] = fromVal;
	    rangesVal[1] = toVal;
	}
	return rowv[0];
    }

    /*
     * Binary-search to find the transition.
     */

    l = 0;
    u = rowc - 1;
    while (l < u) {
	Tcl_Size m = (l + u + 1) / 2;

	if (Tcl_ListObjIndex(interp, rowv[m], 0, &compObj) != TCL_OK ||
		TclGetWideIntFromObj(interp, compObj, &compVal) != TCL_OK) {
	    return NULL;
	}
	if (tick >= compVal) {
	    l = m;
	    fromVal = compVal;
	} else {
	    u = m - 1;
	    toVal = compVal;
	}
    }

    if (rangesVal) {
	rangesVal[0] = fromVal;
	rangesVal[1] = toVal;
    }
    return rowv[l];
}

/*
 *----------------------------------------------------------------------
 *
 * GetYearWeekDay --
 *
 *	Given a date with Julian Calendar Day, compute the year, week, and day
 *	in the ISO8601 calendar.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Stores 'iso8601Year', 'iso8601Week' and 'dayOfWeek' in the date
 *	fields.
 *
 *----------------------------------------------------------------------
 */

static void
GetYearWeekDay(
    TclDateFields *fields,	/* Date to convert, must have 'julianDay' */
    int changeover)		/* Julian Day Number of the Gregorian
				 * transition */
{
    TclDateFields temp;
    int dayOfFiscalYear;

    temp.tzName = NULL;

    /*
     * Find the given date, minus three days, plus one year. That date's
     * iso8601 year is an upper bound on the ISO8601 year of the given date.
     */

    temp.julianDay = fields->julianDay - 3;
    GetGregorianEraYearDay(&temp, changeover);
    if (temp.isBce) {
	temp.iso8601Year = temp.year - 1;
    } else {
	temp.iso8601Year = temp.year + 1;
    }
    temp.iso8601Week = 1;
    temp.dayOfWeek = 1;
    GetJulianDayFromEraYearWeekDay(&temp, changeover);

    /*
     * temp.julianDay is now the start of an ISO8601 year, either the one
     * corresponding to the given date, or the one after. If we guessed high,
     * move one year earlier
     */

    if (fields->julianDay < temp.julianDay) {
	if (temp.isBce) {
	    temp.iso8601Year += 1;
	} else {
	    temp.iso8601Year -= 1;
	}
	GetJulianDayFromEraYearWeekDay(&temp, changeover);
    }

    fields->iso8601Year = temp.iso8601Year;
    dayOfFiscalYear = (int)(fields->julianDay - temp.julianDay);
    fields->iso8601Week = (dayOfFiscalYear / 7) + 1;
    fields->dayOfWeek = (dayOfFiscalYear + 1) % 7;
    if (fields->dayOfWeek < 1) { /* Mon .. Sun == 1 .. 7 */
	fields->dayOfWeek += 7;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * GetGregorianEraYearDay --
 *
 *	Given a Julian Day Number, extracts the year and day of the year and
 *	puts them into TclDateFields, along with the era (BCE or CE) and a
 *	flag indicating whether the date is Gregorian or Julian.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Stores 'era', 'gregorian', 'year', and 'dayOfYear'.
 *
 *----------------------------------------------------------------------
 */

static void
GetGregorianEraYearDay(
    TclDateFields *fields,	/* Date fields containing 'julianDay' */
    int changeover)		/* Gregorian transition date */
{
    Tcl_WideInt jday = fields->julianDay;
    Tcl_WideInt day;
    int year;
    int n;

    if (jday >= changeover) {
	/*
	 * Gregorian calendar.
	 */

	fields->gregorian = 1;
	year = 1;

	/*
	 * n = Number of 400-year cycles since 1 January, 1 CE in the
	 * proleptic Gregorian calendar. day = remaining days.
	 */

	day = jday - JDAY_1_JAN_1_CE_GREGORIAN;
	n = (int)(day / FOUR_CENTURIES);
	day %= FOUR_CENTURIES;
	if (day < 0) {
	    day += FOUR_CENTURIES;
	    n--;
	}
	year += 400 * n;

	/*
	 * n = number of centuries since the start of (year);
	 * day = remaining days
	 */

	n = (int)(day / ONE_CENTURY_GREGORIAN);
	day %= ONE_CENTURY_GREGORIAN;
	if (n > 3) {
	    /*
	     * 31 December in the last year of a 400-year cycle.
	     */

	    n = 3;
	    day += ONE_CENTURY_GREGORIAN;
	}
	year += 100 * n;
    } else {
	/*
	 * Julian calendar.
	 */

	fields->gregorian = 0;
	year = 1;
	day = jday - JDAY_1_JAN_1_CE_JULIAN;
    }

    /*
     * n = number of 4-year cycles; days = remaining days.
     */

    n = (int)(day / FOUR_YEARS);
    day %= FOUR_YEARS;
    if (day < 0) {
	day += FOUR_YEARS;
	n--;
    }
    year += 4 * n;

    /*
     * n = number of years; days = remaining days.
     */

    n = (int)(day / ONE_YEAR);
    day %= ONE_YEAR;
    if (n > 3) {
	/*
	 * 31 December of a leap year.
	 */

	n = 3;
	day += 365;
    }
    year += n;

    /*
     * store era/year/day back into fields.
     */

    if (year <= 0) {
	fields->isBce = 1;
	fields->year = 1 - year;
    } else {
	fields->isBce = 0;
	fields->year = year;
    }
    fields->dayOfYear = (int)day + 1;
}

/*
 *----------------------------------------------------------------------
 *
 * GetMonthDay --
 *
 *	Given a date as year and day-of-year, find month and day.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Stores 'month' and 'dayOfMonth' in the 'fields' structure.
 *
 *----------------------------------------------------------------------
 */

static void
GetMonthDay(
    TclDateFields *fields)	/* Date to convert */
{
    int day = fields->dayOfYear;
    int month;
    const int *dipm = daysInPriorMonths[TclIsGregorianLeapYear(fields)];

    /*
     * Estimate month by calculating `dayOfYear / (365/12)`
     */
    month = (day*12) / dipm[12];
    /* then do forwards backwards correction */
    while (1) {
	if (day > dipm[month]) {
	    if (month >= 11 || day <= dipm[month + 1]) {
		break;
	    }
	    month++;
	} else {
	    if (month == 0) {
		break;
	    }
	    month--;
	}
    }
    day -= dipm[month];
    fields->month = month + 1;
    fields->dayOfMonth = day;
}

/*
 *----------------------------------------------------------------------
 *
 * GetJulianDayFromEraYearWeekDay --
 *
 *	Given a TclDateFields structure containing era, ISO8601 year, ISO8601
 *	week, and day of week, computes the Julian Day Number.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Stores 'julianDay' in the fields.
 *
 *----------------------------------------------------------------------
 */

void
GetJulianDayFromEraYearWeekDay(
    TclDateFields *fields,	/* Date to convert */
    int changeover)		/* Julian Day Number of the Gregorian
				 * transition */
{
    Tcl_WideInt firstMonday;	/* Julian day number of week 1, day 1 in the
				 * given year */
    TclDateFields firstWeek;

    firstWeek.tzName = NULL;

    /*
     * Find January 4 in the ISO8601 year, which will always be in week 1.
     */

    firstWeek.isBce = fields->isBce;
    firstWeek.year = fields->iso8601Year;
    firstWeek.month = 1;
    firstWeek.dayOfMonth = 4;
    GetJulianDayFromEraYearMonthDay(&firstWeek, changeover);

    /*
     * Find Monday of week 1.
     */

    firstMonday = WeekdayOnOrBefore(1, firstWeek.julianDay);

    /*
     * Advance to the given week and day.
     */

    fields->julianDay = firstMonday + 7 * (fields->iso8601Week - 1)
	    + fields->dayOfWeek - 1;
}

/*
 *----------------------------------------------------------------------
 *
 * GetJulianDayFromEraYearMonthDay --
 *
 *	Given era, year, month, and dayOfMonth (in TclDateFields), and the
 *	Gregorian transition date, computes the Julian Day Number.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Stores day number in 'julianDay'
 *
 *----------------------------------------------------------------------
 */

void
GetJulianDayFromEraYearMonthDay(
    TclDateFields *fields,	/* Date to convert */
    int changeover)		/* Gregorian transition date as a Julian Day */
{
    Tcl_WideInt ym1, ym1o4, ym1o100, ym1o400;
    int year, month, mm1, q, r;

    if (fields->isBce) {
	year = 1 - fields->year;
    } else {
	year = fields->year;
    }

    /*
     * Reduce month modulo 12.
     */

    month = fields->month;
    mm1 = month - 1;
    q = mm1 / 12;
    r = (mm1 % 12);
    if (r < 0) {
	r += 12;
	q -= 1;
    }
    year += q;
    month = r + 1;
    ym1 = year - 1;

    /*
     * Adjust the year after reducing the month.
     */

    fields->gregorian = 1;
    if (year < 1) {
	fields->isBce = 1;
	fields->year = 1 - year;
    } else {
	fields->isBce = 0;
	fields->year = year;
    }

    /*
     * Try an initial conversion in the Gregorian calendar.
     */

#if 0 /* BUG https://core.tcl-lang.org/tcl/tktview?name=da340d4f32 */
    ym1o4 = ym1 / 4;
#else
    /*
     * Have to make sure quotient is truncated towards 0 when negative.
     * See above bug for details. The casts are necessary.
     */
    if (ym1 >= 0) {
	ym1o4 = ym1 / 4;
    } else {
	ym1o4 = - (int) (((unsigned int) -ym1) / 4);
    }
#endif
    if (ym1 % 4 < 0) {
	ym1o4--;
    }
    ym1o100 = ym1 / 100;
    if (ym1 % 100 < 0) {
	ym1o100--;
    }
    ym1o400 = ym1 / 400;
    if (ym1 % 400 < 0) {
	ym1o400--;
    }
    fields->julianDay = JDAY_1_JAN_1_CE_GREGORIAN - 1
	    + fields->dayOfMonth
	    + daysInPriorMonths[TclIsGregorianLeapYear(fields)][month - 1]
	    + (ONE_YEAR * ym1)
	    + ym1o4
	    - ym1o100
	    + ym1o400;

    /*
     * If the resulting date is before the Gregorian changeover, convert in
     * the Julian calendar instead.
     */

    if (fields->julianDay < changeover) {
	fields->gregorian = 0;
	fields->julianDay = JDAY_1_JAN_1_CE_JULIAN - 1
		+ fields->dayOfMonth
		+ daysInPriorMonths[year%4 == 0][month - 1]
		+ (365 * ym1)
		+ ym1o4;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclGetJulianDayFromEraYearDay --
 *
 *	Given era, year, and dayOfYear (in TclDateFields), and the
 *	Gregorian transition date, computes the Julian Day Number.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Stores day number in 'julianDay'
 *
 *----------------------------------------------------------------------
 */

void
TclGetJulianDayFromEraYearDay(
    TclDateFields *fields,	/* Date to convert */
    int changeover)		/* Gregorian transition date as a Julian Day */
{
    Tcl_WideInt year, ym1;

    /* Get absolute year number from the civil year */
    if (fields->isBce) {
	year = 1 - fields->year;
    } else {
	year = fields->year;
    }

    ym1 = year - 1;

    /* Try the Gregorian calendar first. */
    fields->gregorian = 1;
    fields->julianDay =
	    1721425
	    + fields->dayOfYear
	    + (365 * ym1)
	    + (ym1 / 4)
	    - (ym1 / 100)
	    + (ym1 / 400);

    /* If the date is before the Gregorian change, use the Julian calendar. */

    if (fields->julianDay < changeover) {
	fields->gregorian = 0;
	fields->julianDay =
		1721423
		+ fields->dayOfYear
		+ (365 * ym1)
		+ (ym1 / 4);
    }
}
/*
 *----------------------------------------------------------------------
 *
 * TclIsGregorianLeapYear --
 *
 *	Tests whether a given year is a leap year, in either Julian or
 *	Gregorian calendar.
 *
 * Results:
 *	Returns 1 for a leap year, 0 otherwise.
 *
 *----------------------------------------------------------------------
 */

int
TclIsGregorianLeapYear(
    TclDateFields *fields)	/* Date to test */
{
    Tcl_WideInt year = fields->year;

    if (fields->isBce) {
	year = 1 - year;
    }
    if (year % 4 != 0) {
	return 0;
    } else if (!(fields->gregorian)) {
	return 1;
    } else if (year % 400 == 0) {
	return 1;
    } else if (year % 100 == 0) {
	return 0;
    } else {
	return 1;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * WeekdayOnOrBefore --
 *
 *	Finds the Julian Day Number of a given day of the week that falls on
 *	or before a given date, expressed as Julian Day Number.
 *
 * Results:
 *	Returns the Julian Day Number
 *
 *----------------------------------------------------------------------
 */

static Tcl_WideInt
WeekdayOnOrBefore(
    int dayOfWeek,		/* Day of week; Sunday == 0 or 7 */
    Tcl_WideInt julianDay)	/* Reference date */
{
    int k = (dayOfWeek + 6) % 7;
    if (k < 0) {
	k += 7;
    }
    return julianDay - ((julianDay - k) % 7);
}

/*
 *----------------------------------------------------------------------
 *
 * ClockGetenvObjCmd --
 *
 *	Tcl command that reads an environment variable from the system
 *
 * Usage:
 *	::tcl::clock::getEnv NAME
 *
 * Parameters:
 *	NAME - Name of the environment variable desired
 *
 * Results:
 *	Returns a standard Tcl result. Returns an error if the variable does
 *	not exist, with a message left in the interpreter. Returns TCL_OK and
 *	the value of the variable if the variable does exist,
 *
 *----------------------------------------------------------------------
 */

int
ClockGetenvObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
#ifdef _WIN32
    const WCHAR *varName;
    const WCHAR *varValue;
    Tcl_DString ds;
#else
    const char *varName;
    const char *varValue;
#endif

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
#ifdef _WIN32
    Tcl_DStringInit(&ds);
    varName = Tcl_UtfToWCharDString(TclGetString(objv[1]), -1, &ds);
    varValue = _wgetenv(varName);
    if (varValue == NULL) {
	Tcl_DStringFree(&ds);
    } else {
	Tcl_DStringSetLength(&ds, 0);
	Tcl_WCharToUtfDString(varValue, -1, &ds);
	Tcl_DStringResult(interp, &ds);
    }
#else
    varName = TclGetString(objv[1]);
    varValue = getenv(varName);
    if (varValue != NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		varValue, TCL_AUTO_LENGTH));
    }
#endif
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ThreadSafeLocalTime --
 *
 *	Wrapper around the 'localtime' library function to make it thread
 *	safe.
 *
 * Results:
 *	Returns a pointer to a 'struct tm' in thread-specific data.
 *
 * Side effects:
 *	Invokes localtime or localtime_r as appropriate.
 *
 *----------------------------------------------------------------------
 */

static struct tm *
ThreadSafeLocalTime(
    const time_t *timePtr)	/* Pointer to the number of seconds since the
				 * local system's epoch */
{
    /*
     * Get a thread-local buffer to hold the returned time.
     */

    struct tm *tmPtr = (struct tm *)Tcl_GetThreadData(&tmKey, sizeof(struct tm));
#ifdef HAVE_LOCALTIME_R
    tmPtr = localtime_r(timePtr, tmPtr);
#else
    struct tm *sysTmPtr;

    Tcl_MutexLock(&clockMutex);
    sysTmPtr = localtime(timePtr);
    if (sysTmPtr == NULL) {
	Tcl_MutexUnlock(&clockMutex);
	return NULL;
    }
    memcpy(tmPtr, sysTmPtr, sizeof(struct tm));
    Tcl_MutexUnlock(&clockMutex);
#endif
    return tmPtr;
}

/*----------------------------------------------------------------------
 *
 * ClockClicksObjCmd --
 *
 *	Returns a high-resolution counter.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 * This function implements the 'clock clicks' Tcl command. Refer to the user
 * documentation for details on what it does.
 *
 *----------------------------------------------------------------------
 */

int
ClockClicksObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Tcl interpreter */
    int objc,			/* Parameter count */
    Tcl_Obj *const *objv)	/* Parameter values */
{
    static const char *const clicksSwitches[] = {
	"-milliseconds", "-microseconds", NULL
    };
    enum ClicksSwitch {
	CLICKS_MILLIS, CLICKS_MICROS, CLICKS_NATIVE
    };
    int index = CLICKS_NATIVE;
    Tcl_Time now;
    Tcl_WideInt clicks = 0;

    switch (objc) {
    case 1:
	break;
    case 2:
	if (Tcl_GetIndexFromObj(interp, objv[1], clicksSwitches, "option", 0,
		&index) != TCL_OK) {
	    return TCL_ERROR;
	}
	break;
    default:
	Tcl_WrongNumArgs(interp, 0, objv, "clock clicks ?-switch?");
	return TCL_ERROR;
    }

    switch (index) {
    case CLICKS_MILLIS:
	Tcl_GetTime(&now);
	clicks = now.sec * 1000LL + now.usec / 1000;
	break;
    case CLICKS_NATIVE:
#ifdef TCL_WIDE_CLICKS
	clicks = TclpGetWideClicks();
#else
	clicks = (Tcl_WideInt)TclpGetClicks();
#endif
	break;
    case CLICKS_MICROS:
	clicks = TclpGetMicroseconds();
	break;
    default:
	TCL_UNREACHABLE();
    }

    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(clicks));
    return TCL_OK;
}

/*----------------------------------------------------------------------
 *
 * ClockMillisecondsObjCmd -
 *
 *	Returns a count of milliseconds since the epoch.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 * This function implements the 'clock milliseconds' Tcl command. Refer to the
 * user documentation for details on what it does.
 *
 *----------------------------------------------------------------------
 */

int
ClockMillisecondsObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Tcl interpreter */
    int objc,			/* Parameter count */
    Tcl_Obj *const *objv)	/* Parameter values */
{
    Tcl_Time now;
    Tcl_Obj *timeObj;

    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 0, objv, "clock milliseconds");
	return TCL_ERROR;
    }
    Tcl_GetTime(&now);
    TclNewUIntObj(timeObj, (Tcl_WideUInt)
	    now.sec * 1000 + now.usec / 1000);
    Tcl_SetObjResult(interp, timeObj);
    return TCL_OK;
}

/*----------------------------------------------------------------------
 *
 * ClockMicrosecondsObjCmd -
 *
 *	Returns a count of microseconds since the epoch.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 * This function implements the 'clock microseconds' Tcl command. Refer to the
 * user documentation for details on what it does.
 *
 *----------------------------------------------------------------------
 */

int
ClockMicrosecondsObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Tcl interpreter */
    int objc,			/* Parameter count */
    Tcl_Obj *const *objv)	/* Parameter values */
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 0, objv, "clock microseconds");
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(TclpGetMicroseconds()));
    return TCL_OK;
}

static inline void
ClockInitFmtScnArgs(
    ClockClientData *dataPtr,
    Tcl_Interp *interp,
    ClockFmtScnCmdArgs *opts)
{
    memset(opts, 0, sizeof(*opts));
    opts->dataPtr = dataPtr;
    opts->interp = interp;
}

/*
 *-----------------------------------------------------------------------------
 *
 * ClockParseFmtScnArgs --
 *
 *	Parses the arguments for sub-commands "scan", "format" and "add".
 *
 *	Note:	common options table used here, because for the options often used
 *		the same literals (objects), so it avoids permanent "recompiling" of
 *		option object representation to indexType with another table.
 *
 * Results:
 *	Returns a standard Tcl result, and stores parsed options
 *	(format, the locale, timezone and base) in structure "opts".
 *
 *-----------------------------------------------------------------------------
 */

typedef enum ClockOperation {
    CLC_OP_FMT = 0,		/* Doing [clock format] */
    CLC_OP_SCN,			/* Doing [clock scan] */
    CLC_OP_ADD			/* Doing [clock add] */
} ClockOperation;

static int
ClockParseFmtScnArgs(
    ClockFmtScnCmdArgs *opts,	/* Result vector: format, locale, timezone... */
    TclDateFields *date,	/* Extracted date-time corresponding base
				 * (by scan or add) resp. clockval (by format) */
    Tcl_Size objc,		/* Parameter count */
    Tcl_Obj *const objv[],	/* Parameter vector */
    ClockOperation operation,	/* What operation are we doing: format, scan, add */
    const char *syntax)		/* Syntax of the current command */
{
    Tcl_Interp *interp = opts->interp;
    ClockClientData *dataPtr = opts->dataPtr;
    int gmtFlag = 0;
    static const char *const options[] = {
	"-base", "-format", "-gmt", "-locale", "-timezone", "-validate", NULL
    };
    enum optionInd {
	CLC_ARGS_BASE, CLC_ARGS_FORMAT, CLC_ARGS_GMT, CLC_ARGS_LOCALE,
	CLC_ARGS_TIMEZONE, CLC_ARGS_VALIDATE
    };
    int optionIndex;		/* Index of an option. */
    int saw = 0;		/* Flag == 1 if option was seen already. */
    Tcl_Size i, baseIdx;
    Tcl_WideInt baseVal;	/* Base time, expressed in seconds from the Epoch */

    if (operation == CLC_OP_SCN) {
	/* default flags (from configure) */
	opts->flags |= dataPtr->defFlags & CLF_VALIDATE;
    } else {
	/* clock value (as current base) */
	opts->baseObj = objv[(baseIdx = 1)];
	saw |= 1 << CLC_ARGS_BASE;
    }

    /*
     * Extract values for the keywords.
     */

    for (i = 2; i < objc; i+=2) {
	/* bypass integers (offsets) by "clock add" */
	if (operation == CLC_OP_ADD) {
	    Tcl_WideInt num;

	    if (TclGetWideIntFromObj(NULL, objv[i], &num) == TCL_OK) {
		continue;
	    }
	}
	/* get option */
	if (Tcl_GetIndexFromObj(interp, objv[i], options,
		"option", 0, &optionIndex) != TCL_OK) {
	    goto badOptionMsg;
	}
	/* if already specified */
	if (saw & (1 << optionIndex)) {
	    if (operation != CLC_OP_SCN && optionIndex == CLC_ARGS_BASE) {
		goto badOptionMsg;
	    }
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "bad option \"%s\": doubly present",
		    TclGetString(objv[i])));
	    goto badOption;
	}
	switch (optionIndex) {
	case CLC_ARGS_FORMAT:
	    if (operation == CLC_OP_ADD) {
		goto badOptionMsg;
	    }
	    opts->formatObj = objv[i + 1];
	    break;
	case CLC_ARGS_GMT:
	    if (Tcl_GetBooleanFromObj(interp, objv[i + 1], &gmtFlag) != TCL_OK){
		return TCL_ERROR;
	    }
	    break;
	case CLC_ARGS_LOCALE:
	    opts->localeObj = objv[i + 1];
	    break;
	case CLC_ARGS_TIMEZONE:
	    opts->timezoneObj = objv[i + 1];
	    break;
	case CLC_ARGS_BASE:
	    opts->baseObj = objv[(baseIdx = i + 1)];
	    break;
	case CLC_ARGS_VALIDATE:
	    if (operation != CLC_OP_SCN) {
		goto badOptionMsg;
	    } else {
		int val;

		if (Tcl_GetBooleanFromObj(interp, objv[i + 1], &val) != TCL_OK) {
		    return TCL_ERROR;
		}
		if (val) {
		    opts->flags |= CLF_VALIDATE;
		} else {
		    opts->flags &= ~CLF_VALIDATE;
		}
	    }
	    break;
	default:
	    TCL_UNREACHABLE();
	}
	saw |= 1 << optionIndex;
    }

    /*
     * Check options.
     */

    if ((saw & (1 << CLC_ARGS_GMT))
	    && (saw & (1 << CLC_ARGS_TIMEZONE))) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"cannot use -gmt and -timezone in same call", TCL_AUTO_LENGTH));
	Tcl_SetErrorCode(interp, "CLOCK", "gmtWithTimezone", (char *)NULL);
	return TCL_ERROR;
    }
    if (gmtFlag) {
	opts->timezoneObj = dataPtr->literals[LIT_GMT];
    } else if (opts->timezoneObj == NULL
	    || TclGetString(opts->timezoneObj) == NULL
	    || opts->timezoneObj->length == 0) {
	/* If time zone not specified use system time zone */
	opts->timezoneObj = ClockGetSystemTimeZone(dataPtr, interp);
	if (opts->timezoneObj == NULL) {
	    return TCL_ERROR;
	}
    }

    /* Setup timezone (normalize object if needed and load TZ on demand) */

    opts->timezoneObj = TclClockSetupTimeZone(dataPtr, interp, opts->timezoneObj);
    if (opts->timezoneObj == NULL) {
	return TCL_ERROR;
    }

    /* Base (by scan or add) or clock value (by format) */

    if (opts->baseObj != NULL) {
	Tcl_Obj *baseObj = opts->baseObj;

	/* bypass integer recognition if looks like "now" or "-now" */
	if ((baseObj->bytes &&
		((baseObj->length == 3 && baseObj->bytes[0] == 'n') ||
		 (baseObj->length == 4 && baseObj->bytes[1] == 'n')))
		|| TclGetWideIntFromObj(NULL, baseObj, &baseVal) != TCL_OK) {
	    /* we accept "now" and "-now" as current date-time */
	    static const char *const nowOpts[] = {
		"now", "-now", NULL
	    };
	    int idx;

	    if (Tcl_GetIndexFromObj(NULL, baseObj, nowOpts, "seconds",
		    TCL_EXACT, &idx) == TCL_OK) {
		goto baseNow;
	    }

	    if (TclHasInternalRep(baseObj, &tclBignumType)) {
		goto baseOverflow;
	    }

	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "bad seconds \"%s\": must be now or integer",
		    TclGetString(baseObj)));
	    i = baseIdx;
	    goto badOption;
	}
	/*
	 * Seconds could be an unsigned number that overflowed. Make sure
	 * that it isn't. Additionally it may be too complex to calculate
	 * julianday etc (forwards/backwards) by too large/small values, thus
	 * just let accept a bit shorter values to avoid overflow.
	 * Note the year is currently an integer, thus avoid to overflow it also.
	 */

	if (TclHasInternalRep(baseObj, &tclBignumType)
		|| baseVal < TCL_MIN_SECONDS || baseVal > TCL_MAX_SECONDS) {
	baseOverflow:
	    Tcl_SetObjResult(interp, dataPtr->literals[LIT_INTEGER_VALUE_TOO_LARGE]);
	    i = baseIdx;
	    goto badOption;
	}
    } else {
	Tcl_Time now;

    baseNow:
	Tcl_GetTime(&now);
	baseVal = (Tcl_WideInt) now.sec;
    }

    /*
     * Extract year, month and day from the base time for the parser to use as
     * defaults
     */

    /* check base fields already cached (by TZ, last-second cache) */
    if (dataPtr->lastBase.timezoneObj == opts->timezoneObj
	    && dataPtr->lastBase.date.seconds == baseVal
	    && (!(dataPtr->lastBase.date.flags & CLF_CTZ)
	    || dataPtr->lastTZEpoch == TzsetIfNecessary())) {
	memcpy(date, &dataPtr->lastBase.date, ClockCacheableDateFieldsSize);
    } else {
	/* extact fields from base */
	date->seconds = baseVal;
	if (ClockGetDateFields(dataPtr, interp, date, opts->timezoneObj,
		GREGORIAN_CHANGE_DATE) != TCL_OK) {
	    /* TODO - GREGORIAN_CHANGE_DATE should be locale-dependent */
	    return TCL_ERROR;
	}
	/* cache last base */
	memcpy(&dataPtr->lastBase.date, date, ClockCacheableDateFieldsSize);
	TclSetObjRef(dataPtr->lastBase.timezoneObj, opts->timezoneObj);
    }

    return TCL_OK;

  badOptionMsg:
    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "bad option \"%s\": must be %s",
	    TclGetString(objv[i]), syntax));

  badOption:
    Tcl_SetErrorCode(interp, "CLOCK", "badOption",
	    (i < objc) ? TclGetString(objv[i]) : (char *)NULL, (char *)NULL);
    return TCL_ERROR;
}

/*----------------------------------------------------------------------
 *
 * ClockFormatObjCmd -- , clock format --
 *
 *	This function is invoked to process the Tcl "clock format" command.
 *
 *	Formats a count of seconds since the Posix Epoch as a time of day.
 *
 *	The 'clock format' command formats times of day for output.  Refer
 *	to the user documentation to see what it does.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
ClockFormatObjCmd(
    void *clientData,		/* Client data containing literal pool */
    Tcl_Interp *interp,		/* Tcl interpreter */
    int objc,			/* Parameter count */
    Tcl_Obj *const objv[])	/* Parameter values */
{
    ClockClientData *dataPtr = (ClockClientData *)clientData;
    static const char *syntax = "clock format clockval|now "
	    "?-format string? "
	    "?-gmt boolean? "
	    "?-locale LOCALE? ?-timezone ZONE?";
    int ret;
    ClockFmtScnCmdArgs opts;	/* Format, locale, timezone and base */
    DateFormat dateFmt;		/* Common structure used for formatting */

    /* even number of arguments */
    if ((objc & 1) == 1) {
	Tcl_WrongNumArgs(interp, 0, objv, syntax);
	Tcl_SetErrorCode(interp, "CLOCK", "wrongNumArgs", (char *)NULL);
	return TCL_ERROR;
    }

    memset(&dateFmt, 0, sizeof(dateFmt));

    /*
     * Extract values for the keywords.
     */

    ClockInitFmtScnArgs(dataPtr, interp, &opts);
    ret = ClockParseFmtScnArgs(&opts, &dateFmt.date, objc, objv,
	    CLC_OP_FMT, "-format, -gmt, -locale, or -timezone");
    if (ret != TCL_OK) {
	goto done;
    }

    /* Default format */
    if (opts.formatObj == NULL) {
	opts.formatObj = dataPtr->literals[LIT__DEFAULT_FORMAT];
    }

    /* Use compiled version of Format - */
    ret = TclClockFormat(&dateFmt, &opts);

  done:
    TclUnsetObjRef(dateFmt.date.tzName);
    return ret;
}

/*----------------------------------------------------------------------
 *
 * ClockScanObjCmd -- , clock scan --
 *
 *	This function is invoked to process the Tcl "clock scan" command.
 *
 *	Inputs a count of seconds since the Posix Epoch as a time of day.
 *
 *	The 'clock scan' command scans times of day on input. Refer to the
 *	user documentation to see what it does.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
ClockScanObjCmd(
    void *clientData,		/* Client data containing literal pool */
    Tcl_Interp *interp,		/* Tcl interpreter */
    int objc,			/* Parameter count */
    Tcl_Obj *const objv[])	/* Parameter values */
{
    ClockClientData *dataPtr = (ClockClientData *)clientData;
    static const char *syntax = "clock scan string "
	    "?-base seconds? "
	    "?-format string? "
	    "?-gmt boolean? "
	    "?-locale LOCALE? ?-timezone ZONE? ?-validate boolean?";
    int ret;
    ClockFmtScnCmdArgs opts;	/* Format, locale, timezone and base */
    DateInfo yy;		/* Common structure used for parsing */
    DateInfo *info = &yy;

    /* even number of arguments */
    if ((objc & 1) == 1) {
	Tcl_WrongNumArgs(interp, 0, objv, syntax);
	Tcl_SetErrorCode(interp, "CLOCK", "wrongNumArgs", (char *)NULL);
	return TCL_ERROR;
    }

    ClockInitDateInfo(&yy);

    /*
     * Extract values for the keywords.
     */

    ClockInitFmtScnArgs(dataPtr, interp, &opts);
    ret = ClockParseFmtScnArgs(&opts, &yy.date, objc, objv,
	    CLC_OP_SCN, "-base, -format, -gmt, -locale, -timezone or -validate");
    if (ret != TCL_OK) {
	goto done;
    }

    /* seconds are in localSeconds (relative base date), so reset time here */
    yySecondOfDay = yySeconds = yyMinutes = yyHour = 0;
    yyMeridian = MER24;

    /* If free scan */
    if (opts.formatObj == NULL) {
	/* Use compiled version of FreeScan - */

	/* [SB] TODO: Perhaps someday we'll localize the legacy code. Right now,
	 * it's not localized. */
	if (opts.localeObj != NULL) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "legacy [clock scan] does not support -locale", TCL_AUTO_LENGTH));
	    Tcl_SetErrorCode(interp, "CLOCK", "flagWithLegacyFormat", (char *)NULL);
	    ret = TCL_ERROR;
	    goto done;
	}
	ret = ClockFreeScan(&yy, objv[1], &opts);
    } else {
	/* Use compiled version of Scan - */

	ret = TclClockScan(&yy, objv[1], &opts);
    }

    if (ret != TCL_OK) {
	goto done;
    }

    /* Convert date info structure into UTC seconds */

    ret = ClockScanCommit(&yy, &opts);
    if (ret != TCL_OK) {
	goto done;
    }

    /* Apply remaining validation rules, if expected */
    if (opts.flags & CLF_VALIDATE) {
	ret = ClockValidDate(&yy, &opts, opts.flags & CLF_VALIDATE);
	if (ret != TCL_OK) {
	    goto done;
	}
    }

  done:
    TclUnsetObjRef(yy.date.tzName);
    if (ret != TCL_OK) {
	return ret;
    }
    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(yy.date.seconds));
    return TCL_OK;
}

/*----------------------------------------------------------------------
 *
 * ClockScanCommit --
 *
 *	Converts date info structure into UTC seconds.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
ClockScanCommit(
    DateInfo *info,		/* Clock scan info structure */
    ClockFmtScnCmdArgs *opts)	/* Format, locale, timezone and base */
{
    /*
     * If no GMT and not free-scan (where valid stage 1 is done in-between),
     * validate with stage 1 before local time conversion, otherwise it may
     * adjust date/time tokens to valid values
     */
    if ((opts->flags & CLF_VALIDATE_S1)
	    && info->flags & (CLF_ASSEMBLE_SECONDS|CLF_LOCALSEC)) {
	if (ClockValidDate(info, opts, CLF_VALIDATE_S1) != TCL_OK) {
	    return TCL_ERROR;
	}
    }

    /* If needed assemble julianDay using year, month, etc. */
    if (info->flags & CLF_ASSEMBLE_JULIANDAY) {
	if (info->flags & CLF_ISO8601WEEK) {
	    GetJulianDayFromEraYearWeekDay(&yydate, GREGORIAN_CHANGE_DATE);
	} else if (!(info->flags & CLF_DAYOFYEAR) /* no day of year */
		|| (info->flags & (CLF_DAYOFMONTH|CLF_MONTH)) /* yymmdd over yyddd */
		== (CLF_DAYOFMONTH|CLF_MONTH)) {
	    GetJulianDayFromEraYearMonthDay(&yydate, GREGORIAN_CHANGE_DATE);
	} else {
	    TclGetJulianDayFromEraYearDay(&yydate, GREGORIAN_CHANGE_DATE);
	}
	info->flags |= CLF_ASSEMBLE_SECONDS;
	info->flags &= ~CLF_ASSEMBLE_JULIANDAY;
    }

    /* some overflow checks */
    if (info->flags & CLF_JULIANDAY) {
	double curJDN = (double)yydate.julianDay
		+ ((double)yySecondOfDay - SECONDS_PER_DAY/2) / SECONDS_PER_DAY;
	if (curJDN > opts->dataPtr->maxJDN) {
	    Tcl_SetObjResult(opts->interp, Tcl_NewStringObj(
		    "requested date too large to represent", TCL_AUTO_LENGTH));
	    Tcl_SetErrorCode(opts->interp, "CLOCK", "dateTooLarge", (char *)NULL);
	    return TCL_ERROR;
	}
    }

    /* If seconds overflows the day (not valide case, or 24:00), increase days */
    if (yySecondOfDay >= SECONDS_PER_DAY) {
	yydate.julianDay += (yySecondOfDay / SECONDS_PER_DAY);
	yySecondOfDay %= SECONDS_PER_DAY;
    }

    /* Local seconds to UTC (stored in yydate.seconds) */

    if (info->flags & CLF_ASSEMBLE_SECONDS) {
	yydate.localSeconds =
		-210866803200LL
		+ (SECONDS_PER_DAY * yydate.julianDay)
		+ yySecondOfDay;
    }

    if (info->flags & (CLF_ASSEMBLE_SECONDS | CLF_LOCALSEC)) {
	if (ConvertLocalToUTC(opts->dataPtr, opts->interp, &yydate,
		opts->timezoneObj, GREGORIAN_CHANGE_DATE) != TCL_OK) {
	    return TCL_ERROR;
	}
    }

    /* Increment UTC seconds with relative time */

    yydate.seconds += yyRelSeconds;
    return TCL_OK;
}

/*----------------------------------------------------------------------
 *
 * ClockValidDate --
 *
 *	Validate date info structure for wrong data (e. g. out of ranges).
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
ClockValidDate(
    DateInfo *info,		/* Clock scan info structure */
    ClockFmtScnCmdArgs *opts,	/* Scan options */
    int stage)			/* Stage to validate (1, 2 or 3 for both) */
{
    const char *errMsg = "", *errCode = "";
    TclDateFields temp;
    int tempCpyFlg = 0;
    ClockClientData *dataPtr = opts->dataPtr;

#if 0
    printf("yyMonth %d, yyDay %d, yyDayOfYear %d, yyHour %d, yyMinutes %d, yySeconds %" TCL_LL_MODIFIER "d, "
	    "yySecondOfDay %" TCL_LL_MODIFIER "d, sec %" TCL_LL_MODIFIER "d, daySec %" TCL_LL_MODIFIER "d, tzOffset %d\n",
	    yyMonth, yyDay, yydate.dayOfYear, yyHour, yyMinutes, yySeconds,
	    yySecondOfDay, yydate.localSeconds, yydate.localSeconds % SECONDS_PER_DAY,
	    yydate.tzOffset);
#endif

    if (!(stage & CLF_VALIDATE_S1) || !(opts->flags & CLF_VALIDATE_S1)) {
	goto stage_2;
    }
    opts->flags &= ~CLF_VALIDATE_S1; /* stage 1 is done */

    /* first year (used later in hath / daysInPriorMonths) */
    if ((info->flags & (CLF_YEAR | CLF_ISO8601YEAR))) {
	if ((info->flags & CLF_ISO8601YEAR)) {
	    if (yydate.iso8601Year < dataPtr->validMinYear
		    || yydate.iso8601Year > dataPtr->validMaxYear) {
		errMsg = "invalid iso year";
		errCode = "iso year";
		goto error;
	    }
	}
	if (info->flags & CLF_YEAR) {
	    if (yyYear < dataPtr->validMinYear
		    || yyYear > dataPtr->validMaxYear) {
		errMsg = "invalid year";
		errCode = "year";
		goto error;
	    }
	} else if ((info->flags & CLF_ISO8601YEAR)) {
	    yyYear = yydate.iso8601Year; /* used to recognize leap */
	}
	if ((info->flags & (CLF_ISO8601YEAR | CLF_YEAR))
		== (CLF_ISO8601YEAR | CLF_YEAR)) {
	    if (yyYear != yydate.iso8601Year) {
		errMsg = "ambiguous year";
		errCode = "year";
		goto error;
	    }
	}
    }
    /* and month (used later in hath) */
    if (info->flags & CLF_MONTH) {
	if (yyMonth < 1 || yyMonth > 12) {
	    errMsg = "invalid month";
	    errCode = "month";
	    goto error;
	}
    }
    /* day of month */
    if (info->flags & (CLF_DAYOFMONTH|CLF_DAYOFWEEK)) {
	if (yyDay < 1 || yyDay > 31) {
	    errMsg = "invalid day";
	    errCode = "day";
	    goto error;
	}
	if ((info->flags & CLF_MONTH)) {
	    const int *h = hath[TclIsGregorianLeapYear(&yydate)];

	    if (yyDay > h[yyMonth - 1]) {
		errMsg = "invalid day";
		errCode = "day";
		goto error;
	    }
	}
    }
    if (info->flags & CLF_DAYOFYEAR) {
	if (yydate.dayOfYear < 1
		|| yydate.dayOfYear > daysInPriorMonths[TclIsGregorianLeapYear(&yydate)][12]) {
	    errMsg = "invalid day of year";
	    errCode = "day of year";
	    goto error;
	}
    }

    /* mmdd !~ ddd */
    if ((info->flags & (CLF_DAYOFYEAR|CLF_DAYOFMONTH|CLF_MONTH))
	    == (CLF_DAYOFYEAR|CLF_DAYOFMONTH|CLF_MONTH)) {
	if (!tempCpyFlg) {
	    memcpy(&temp, &yydate, sizeof(temp));
	    tempCpyFlg = 1;
	}
	TclGetJulianDayFromEraYearDay(&temp, GREGORIAN_CHANGE_DATE);
	if (temp.julianDay != yydate.julianDay) {
	    errMsg = "ambiguous day";
	    errCode = "day";
	    goto error;
	}
    }

    if (info->flags & CLF_TIME) {
	/* hour */
	if (yyHour < 0 || yyHour > ((yyMeridian == MER24) ? 23 : 12)) {
	    /* allow 24:00:00 as special case, see [aee9f2b916afd976] */
	    if (yyMeridian == MER24 && yyHour == 24) {
		if (yyMinutes != 0 || yySeconds != 0) {
		    errMsg = "invalid time";
		    errCode = "time";
		    goto error;
		}
		/* 24:00 is next day 00:00, correct day of week if given */
		if (info->flags & CLF_DAYOFWEEK) {
		    if (++yyDayOfWeek > 7) { /* Mon .. Sun == 1 .. 7 */
			yyDayOfWeek = 1;
		    }
		}
	    } else {
		errMsg = "invalid time (hour)";
		errCode = "hour";
		goto error;
	    }
	}
	/* minutes */
	if (yyMinutes < 0 || yyMinutes > 59) {
	    errMsg = "invalid time (minutes)";
	    errCode = "minutes";
	    goto error;
	}
	/* oldscan could return secondOfDay -1 by invalid time (see TclToSeconds) */
	if (yySeconds < 0 || yySeconds > 59 || yySecondOfDay <= -1) {
	    errMsg = "invalid time";
	    errCode = "seconds";
	    goto error;
	}
    }

    if (!(stage & CLF_VALIDATE_S2) || !(opts->flags & CLF_VALIDATE_S2)) {
	return TCL_OK;
    }

    /*
     * Further tests expected ready calculated julianDay (inclusive relative),
     * and time-zone conversion (local to UTC time).
     */
  stage_2:

    opts->flags &= ~CLF_VALIDATE_S2; /* stage 2 is done */

    /* time, regarding the modifications by the time-zone (looks for given time
     * in between DST-time hole, so does not exist in this time-zone) */
    if (info->flags & CLF_TIME) {
	/*
	 * we don't need to do the backwards time-conversion (UTC to local) and
	 * compare results, because the after conversion (local to UTC) we
	 * should have valid localSeconds (was not invalidated to TCL_INV_SECONDS),
	 * so if it was invalidated - invalid time, outside the time-zone (in DST-hole)
	 */
	if (yydate.localSeconds == TCL_INV_SECONDS) {
	    errMsg = "invalid time (does not exist in this time-zone)";
	    errCode = "out-of-time";
	    goto error;
	}
    }

    /* day of week */
    if (info->flags & CLF_DAYOFWEEK) {
	if (!tempCpyFlg) {
	    memcpy(&temp, &yydate, sizeof(temp));
	    tempCpyFlg = 1;
	}
	GetYearWeekDay(&temp, GREGORIAN_CHANGE_DATE);
	if (temp.dayOfWeek != yyDayOfWeek) {
	    errMsg = "invalid day of week";
	    errCode = "day of week";
	    goto error;
	}
    }

    return TCL_OK;

  error:
    Tcl_SetObjResult(opts->interp, Tcl_ObjPrintf(
	    "unable to convert input string: %s", errMsg));
    Tcl_SetErrorCode(opts->interp, "CLOCK", "invInpStr", errCode, (char *)NULL);
    return TCL_ERROR;
}

/*----------------------------------------------------------------------
 *
 * ClockFreeScan --
 *
 *	Used by ClockScanObjCmd for free scanning without format.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
ClockFreeScan(
    DateInfo *info,		/* Date fields used for parsing & converting
				 * simultaneously a yy-parse structure of the
				 * TclClockFreeScan */
    Tcl_Obj *strObj,		/* String containing the time to scan */
    ClockFmtScnCmdArgs *opts)	/* Command options */
{
    Tcl_Interp *interp = opts->interp;
    ClockClientData *dataPtr = opts->dataPtr;

    /*
     * Parse the date. The parser will fill a structure "info" with date,
     * time, time zone, relative month/day/seconds, relative weekday, ordinal
     * month.
     * Notice that many yy-defines point to values in the "info" or "date"
     * structure, e. g. yySecondOfDay -> info->date.secondOfDay or
     *			yyMonth -> info->date.month (same as yydate.month)
     */
    yyInput = TclGetString(strObj);

    if (TclClockFreeScan(interp, info) != TCL_OK) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"unable to convert date-time string \"%s\": %s",
		TclGetString(strObj), Tcl_GetString(Tcl_GetObjResult(interp))));
	return TCL_ERROR;
    }

    /*
     * If the caller supplied a date in the string, update the date with
     * the value. If the caller didn't specify a time with the date, default to
     * midnight.
     */

    if (info->flags & CLF_YEAR) {
	if (yyYear < 100) {
	    if (yyYear >= dataPtr->yearOfCenturySwitch) {
		yyYear -= 100;
	    }
	    yyYear += dataPtr->currentYearCentury;
	}
	yydate.isBce = 0;
	info->flags |= CLF_ASSEMBLE_JULIANDAY|CLF_ASSEMBLE_SECONDS;
    }

    /*
     * If the caller supplied a time zone in the string, make it into a time
     * zone indicator of +-hhmm and setup this time zone.
     */

    if (info->flags & CLF_ZONE) {
	if (yyTimezone || !yyDSTmode) {
	    /* Real time zone from numeric zone */
	    Tcl_Obj *tzObjStor = NULL;
	    int minEast = -yyTimezone;
	    int dstFlag = 1 - yyDSTmode;

	    tzObjStor = ClockFormatNumericTimeZone(
		    60 * minEast + 3600 * dstFlag);
	    Tcl_IncrRefCount(tzObjStor);

	    opts->timezoneObj = TclClockSetupTimeZone(dataPtr, interp, tzObjStor);

	    Tcl_DecrRefCount(tzObjStor);
	} else {
	    /* simplest case - GMT / UTC */
	    opts->timezoneObj = TclClockSetupTimeZone(dataPtr, interp,
		    dataPtr->literals[LIT_GMT]);
	}
	if (opts->timezoneObj == NULL) {
	    return TCL_ERROR;
	}

	// TclSetObjRef(yydate.tzName, opts->timezoneObj);

	info->flags |= CLF_ASSEMBLE_SECONDS;
    }

    /*
     * For freescan apply validation rules (stage 1) before mixed with
     * relative time (otherwise always valid recalculated date & time).
     */
    if (opts->flags & CLF_VALIDATE) {
	if (ClockValidDate(info, opts, CLF_VALIDATE_S1) != TCL_OK) {
	    return TCL_ERROR;
	}
    }

    /*
     * Assemble date, time, zone into seconds-from-epoch
     */

    if ((info->flags & (CLF_TIME | CLF_HAVEDATE)) == CLF_HAVEDATE) {
	yySecondOfDay = 0;
	info->flags |= CLF_ASSEMBLE_SECONDS;
    } else if (info->flags & CLF_TIME) {
	yySecondOfDay = TclToSeconds(yyHour, yyMinutes, (int)yySeconds, yyMeridian);
	info->flags |= CLF_ASSEMBLE_SECONDS;
    } else if ((info->flags & (CLF_DAYOFWEEK | CLF_HAVEDATE)) == CLF_DAYOFWEEK
	    || (info->flags & CLF_ORDINALMONTH)
	    || ((info->flags & CLF_RELCONV)
	    && (yyRelMonth != 0 || yyRelDay != 0))) {
	yySecondOfDay = 0;
	info->flags |= CLF_ASSEMBLE_SECONDS;
    } else {
	yySecondOfDay = yydate.localSeconds % SECONDS_PER_DAY;
	if (yySecondOfDay < 0) { /* compiler fix for signed-mod */
	    yySecondOfDay += SECONDS_PER_DAY;
	}
    }

    /*
     * Do relative times if needed.
     */

    if (info->flags & CLF_RELCONV) {
	if (ClockCalcRelTime(info, opts) != TCL_OK) {
	    return TCL_ERROR;
	}
    }

    /* Free scanning completed - date ready */
    return TCL_OK;
}

/*----------------------------------------------------------------------
 *
 * ClockCalcRelTime --
 *
 *	Used for calculating of relative times.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */
int
ClockCalcRelTime(
    DateInfo *info,		/* Date fields used for converting */
    ClockFmtScnCmdArgs *opts)	/* Command options */
{
    int prevDayOfWeek = yyDayOfWeek;	/* preserve unchanged day of week */

    /*
     * Because some calculations require in-between conversion of the
     * julian day, and fixed order due to tokens precedence,
     * we can repeat this processing multiple times
     */
  repeat_rel:

    /*
     * Relative conversion normally possible in UTC time only, because
     * of possible wrong local time increment if ignores in-between DST-hole.
     * (see tests clock-34.53, clock-34.54) or by jump across TZ (CET/CEST).
     * So increment date in julianDay, but time inside day in UTC (seconds).
     */

    /* add relative months (or years in months) */

    if (yyRelMonth != 0) {
	int m, h;

	/* if needed extract year, month, etc. again */
	if (info->flags & CLF_ASSEMBLE_DATE) {
	    GetGregorianEraYearDay(&yydate, GREGORIAN_CHANGE_DATE);
	    GetMonthDay(&yydate);
	    GetYearWeekDay(&yydate, GREGORIAN_CHANGE_DATE);
	    info->flags &= ~CLF_ASSEMBLE_DATE;
	}

	/* add the requisite number of months */
	yyMonth += (int)yyRelMonth - 1;
	yyYear += yyMonth / 12;
	m = yyMonth % 12;
	/* compiler fix for signed-mod - wrap y, m = (0, -1) -> (-1, 11) */
	if (m < 0) {
	    m += 12;
	    yyYear--;
	}
	yyMonth = m + 1;

	/* if the day doesn't exist in the current month, repair it */
	h = hath[TclIsGregorianLeapYear(&yydate)][m];
	if (yyDay > h) {
	    yyDay = h;
	}

	/* on demand (lazy) assemble julianDay using new year, month, etc. */
	info->flags |= CLF_ASSEMBLE_JULIANDAY | CLF_ASSEMBLE_SECONDS;

	yyRelMonth = 0;
    }

    /* add relative days (or other parts aligned to days) */
    if (yyRelDay) {
	/* assemble julianDay using new year, month, etc. */
	if (info->flags & CLF_ASSEMBLE_JULIANDAY) {
	    GetJulianDayFromEraYearMonthDay(&yydate, GREGORIAN_CHANGE_DATE);
	    info->flags &= ~CLF_ASSEMBLE_JULIANDAY;
	}
	yydate.julianDay += yyRelDay;

	/* julianDay was changed, on demand (lazy) extract year, month, etc. again */
	info->flags |= CLF_ASSEMBLE_DATE | CLF_ASSEMBLE_SECONDS;
	yyRelDay = 0;
    }

    /* do relative (ordinal) month */

    if (info->flags & CLF_ORDINALMONTH) {
	int monthDiff;

	/* if needed extract year, month, etc. again */
	if (info->flags & CLF_ASSEMBLE_DATE) {
	    GetGregorianEraYearDay(&yydate, GREGORIAN_CHANGE_DATE);
	    GetMonthDay(&yydate);
	    GetYearWeekDay(&yydate, GREGORIAN_CHANGE_DATE);
	    info->flags &= ~CLF_ASSEMBLE_DATE;
	}

	if (yyMonthOrdinalIncr > 0) {
	    monthDiff = yyMonthOrdinal - yyMonth;
	    if (monthDiff <= 0) {
		monthDiff += 12;
	    }
	    yyMonthOrdinalIncr--;
	} else {
	    monthDiff = yyMonth - yyMonthOrdinal;
	    if (monthDiff >= 0) {
		monthDiff -= 12;
	    }
	    yyMonthOrdinalIncr++;
	}

	/* process it further via relative times */
	yyYear += yyMonthOrdinalIncr;
	yyRelMonth += monthDiff;
	info->flags &= ~CLF_ORDINALMONTH;
	info->flags |= CLF_ASSEMBLE_JULIANDAY|CLF_ASSEMBLE_SECONDS;

	goto repeat_rel;
    }

    /* do relative weekday */

    if ((info->flags & (CLF_DAYOFWEEK|CLF_HAVEDATE)) == CLF_DAYOFWEEK) {
	/* restore scanned day of week */
	yyDayOfWeek = prevDayOfWeek;

	/* if needed assemble julianDay now */
	if (info->flags & CLF_ASSEMBLE_JULIANDAY) {
	    GetJulianDayFromEraYearMonthDay(&yydate, GREGORIAN_CHANGE_DATE);
	    info->flags &= ~CLF_ASSEMBLE_JULIANDAY;
	}

	yydate.isBce = 0;
	yydate.julianDay = WeekdayOnOrBefore(yyDayOfWeek, yydate.julianDay + 6)
		+ 7 * yyDayOrdinal;
	if (yyDayOrdinal > 0) {
	    yydate.julianDay -= 7;
	}
	info->flags |= CLF_ASSEMBLE_DATE|CLF_ASSEMBLE_SECONDS;
    }

    /* If relative time is there, adjust it in UTC as mentioned above. */
    if (yyRelSeconds) {
	/*
	 * If timezone is not GMT/UTC (due to DST-hole, local time offset),
	 * we shall do in-between conversion to UTC to append seconds there
	 * and hereafter convert back to TZ, otherwise apply it direct here.
	 */
	if (opts->timezoneObj != opts->dataPtr->literals[LIT_GMT]) {
	    /*
	     * Convert date info structure into UTC seconds and add relative
	     * seconds (happens in commit).
	     */
	    if (ClockScanCommit(info, opts) != TCL_OK) {
		return TCL_ERROR;
	    }
	    yyRelSeconds = 0;
	    /* Convert it back */
	    if (ClockGetDateFields(opts->dataPtr, opts->interp, &yydate,
		    opts->timezoneObj, GREGORIAN_CHANGE_DATE) != TCL_OK) {
		/* TODO - GREGORIAN_CHANGE_DATE should be locale-dependent */
		return TCL_ERROR;
	    }
	    /* time together as seconds of the day */
	    yySecondOfDay = yydate.localSeconds % SECONDS_PER_DAY;
	    if (yySecondOfDay < 0) { /* compiler fix for signed-mod */
		yySecondOfDay += SECONDS_PER_DAY;
	    }
	    /* restore scanned day of week */
	    yyDayOfWeek = prevDayOfWeek;
	} else {
	    /*
	     * GMT/UTC zone, so no DST and no offsets - apply it here, so that
	     * if time exceeds current date, do the day conversion and leave the
	     * rest of increment in yyRelSeconds (add it later in UTC by commit)
	     */
	    Tcl_WideInt newSecs = yySecondOfDay + yyRelSeconds;

	    /* if seconds increment outside of current date, increment day */
	    if (newSecs / SECONDS_PER_DAY != yySecondOfDay / SECONDS_PER_DAY) {
		yyRelDay += newSecs / SECONDS_PER_DAY;
		yySecondOfDay = 0;
		yyRelSeconds = (newSecs %= SECONDS_PER_DAY);
		if (newSecs < 0) { /* compiler fix for signed-mod */
		    yyRelSeconds += SECONDS_PER_DAY;
		    yyRelDay--;
		}

		goto repeat_rel;
	    }
	}
    }

    /* done, reset flag */
    info->flags &= ~CLF_RELCONV;

    return TCL_OK;
}

/*----------------------------------------------------------------------
 *
 * ClockWeekdaysOffs --
 *
 *	Get offset in days for the number of week days corresponding the
 *	given day of week (skipping Saturdays and Sundays).
 *
 *
 * Results:
 *	Returns a day increment adjusted the given weekdays
 *
 *----------------------------------------------------------------------
 */

static inline int
ClockWeekdaysOffs(
    int dayOfWeek,
    int offs)
{
    int weeks, resDayOfWeek;

    /* offset in days */
    weeks = offs / 5;
    offs = offs % 5;
    /* compiler fix for negative offs - wrap (0, -1) -> (-1, 4) */
    if (offs < 0) {
	offs += 5;
	weeks--;
    }
    offs += 7 * weeks;

    /* resulting day of week */
    {
	int day = (offs % 7);

	/* compiler fix for negative offs - wrap (0, -1) -> (-1, 6) */
	if (day < 0) {
	    day += 7;
	}
	resDayOfWeek = dayOfWeek + day;
    }

    /* adjust if we start from a weekend */
    if (dayOfWeek > 5) {
	int adj = 5 - dayOfWeek;

	offs += adj;
	resDayOfWeek += adj;
    }

    /* adjust if we end up on a weekend */
    if (resDayOfWeek > 5) {
	offs += 2;
    }

    return offs;
}

/*----------------------------------------------------------------------
 *
 * ClockAddObjCmd -- , clock add --
 *
 *	Adds an offset to a given time.
 *
 *	Refer to the user documentation to see what it exactly does.
 *
 * Syntax:
 *   clock add clockval ?count unit?... ?-option value?
 *
 * Parameters:
 *   clockval -- Starting time value
 *   count -- Amount of a unit of time to add
 *   unit -- Unit of time to add, must be one of:
 *	     years year months month weeks week
 *	     days day hours hour minutes minute
 *	     seconds second
 *
 * Options:
 *   -gmt BOOLEAN
 *	 Flag synonymous with '-timezone :GMT'
 *   -timezone ZONE
 *	 Name of the time zone in which calculations are to be done.
 *   -locale NAME
 *	 Name of the locale in which calculations are to be done.
 *	 Used to determine the Gregorian change date.
 *
 * Results:
 *	Returns a standard Tcl result with the given time adjusted
 *	by the given offset(s) in order.
 *
 * Notes:
 *   It is possible that adding a number of months or years will adjust the
 *   day of the month as well.	For instance, the time at one month after
 *   31 January is either 28 or 29 February, because February has fewer
 *   than 31 days.
 *
 *----------------------------------------------------------------------
 */

int
ClockAddObjCmd(
    void *clientData,		/* Client data containing literal pool */
    Tcl_Interp *interp,		/* Tcl interpreter */
    int objc,			/* Parameter count */
    Tcl_Obj *const objv[])	/* Parameter values */
{
    static const char *syntax = "clock add clockval|now ?number units?..."
	    "?-gmt boolean? "
	    "?-locale LOCALE? ?-timezone ZONE?";
    ClockClientData *dataPtr = (ClockClientData *)clientData;
    int ret;
    ClockFmtScnCmdArgs opts;	/* Format, locale, timezone and base */
    DateInfo yy;		/* Common structure used for parsing */
    DateInfo *info = &yy;

    /* add "week" to units also (because otherwise ambiguous) */
    static const char *const units[] = {
	"years",	"months",	    "week",	    "weeks",
	"days",		"weekdays",
	"hours",	"minutes",	    "seconds",
	NULL
    };
    enum unitInd {
	CLC_ADD_YEARS,	CLC_ADD_MONTHS,	    CLC_ADD_WEEK,   CLC_ADD_WEEKS,
	CLC_ADD_DAYS,	CLC_ADD_WEEKDAYS,
	CLC_ADD_HOURS,	CLC_ADD_MINUTES,    CLC_ADD_SECONDS
    };
    int unitIndex = CLC_ADD_SECONDS;	/* Index of an option. */
    Tcl_Size i;
    Tcl_WideInt offs;

    /* even number of arguments */
    if ((objc & 1) == 1) {
	Tcl_WrongNumArgs(interp, 0, objv, syntax);
	Tcl_SetErrorCode(interp, "CLOCK", "wrongNumArgs", (char *)NULL);
	return TCL_ERROR;
    }

    ClockInitDateInfo(&yy);

    /*
     * Extract values for the keywords.
     */

    ClockInitFmtScnArgs(dataPtr, interp, &opts);
    ret = ClockParseFmtScnArgs(&opts, &yy.date, objc, objv,
	    CLC_OP_ADD, "-gmt, -locale, or -timezone");
    if (ret != TCL_OK) {
	goto done;
    }

    /* time together as seconds of the day */
    yySecondOfDay = yydate.localSeconds % SECONDS_PER_DAY;
    if (yySecondOfDay < 0) { /* compiler fix for signed-mod */
	yySecondOfDay += SECONDS_PER_DAY;
    }
    yySeconds = yySecondOfDay;
    /* seconds are in localSeconds (relative base date), so reset time here */
    yyHour = 0;
    yyMinutes = 0;
    yyMeridian = MER24;

    ret = TCL_ERROR;

    /*
     * Find each offset and process date increment
     */

    for (i = 2; i < objc; i+=2) {
	/* bypass not integers (options, allready processed above in ClockParseFmtScnArgs) */
	if (TclGetWideIntFromObj(NULL, objv[i], &offs) != TCL_OK) {
	    continue;
	}
	/* get unit */
	if (Tcl_GetIndexFromObj(interp, objv[i + 1], units, "unit", 0,
		&unitIndex) != TCL_OK) {
	    goto done;
	}
	if (TclHasInternalRep(objv[i], &tclBignumType)
		|| offs > (unitIndex < CLC_ADD_HOURS ? 0x7fffffff : TCL_MAX_SECONDS)
		|| offs < (unitIndex < CLC_ADD_HOURS ? -0x7fffffff : TCL_MIN_SECONDS)) {
	    Tcl_SetObjResult(interp, dataPtr->literals[LIT_INTEGER_VALUE_TOO_LARGE]);
	    goto done;
	}

	/* nothing to do if zero quantity */
	if (!offs) {
	    continue;
	}

	/* if in-between conversion needed (already have relative date/time),
	 * correct date info, because the local date/time may be changed, so
	 * refresh it now (see test clock-30.34 "clock add jump over DST hole") */

	if ((info->flags & CLF_RELCONV) ||
	    (yyRelSeconds && unitIndex < CLC_ADD_HOURS)
	) {
	    if (ClockCalcRelTime(info, &opts) != TCL_OK) {
		goto done;
	    }
	}

	/* process increment by offset + unit */
	switch (unitIndex) {
	case CLC_ADD_YEARS:
	    yyRelMonth += offs * 12;
	    break;
	case CLC_ADD_MONTHS:
	    yyRelMonth += offs;
	    break;
	case CLC_ADD_WEEK:
	case CLC_ADD_WEEKS:
	    yyRelDay += offs * 7;
	    break;
	case CLC_ADD_DAYS:
	    yyRelDay += offs;
	    break;
	case CLC_ADD_WEEKDAYS:
	    /* add number of week days (skipping Saturdays and Sundays)
	     * to a relative days value. */
	    offs = ClockWeekdaysOffs(yy.date.dayOfWeek, (int)offs);
	    yyRelDay += offs;
	    break;
	case CLC_ADD_HOURS:
	    yyRelSeconds += offs * 60 * 60;
	    break;
	case CLC_ADD_MINUTES:
	    yyRelSeconds += offs * 60;
	    break;
	case CLC_ADD_SECONDS:
	    yyRelSeconds += offs;
	    break;
	default:
	    TCL_UNREACHABLE();
	}
	if (unitIndex < CLC_ADD_HOURS) { /* date units only */
	    info->flags |= CLF_RELCONV;
	}
    }

    /*
     * Do relative units (if not yet already processed interim),
     * thereby ignore relative time (it can be processed within commit).
     */

    if (info->flags & CLF_RELCONV) {
	if (ClockCalcRelTime(info, &opts) != TCL_OK) {
	    goto done;
	}
    }

    /* Convert date info structure into UTC seconds */

    ret = ClockScanCommit(&yy, &opts);

  done:
    TclUnsetObjRef(yy.date.tzName);
    if (ret != TCL_OK) {
	return ret;
    }
    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(yy.date.seconds));
    return TCL_OK;
}

/*----------------------------------------------------------------------
 *
 * ClockSecondsObjCmd -
 *
 *	Returns a count of microseconds since the epoch.
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 * This function implements the 'clock seconds' Tcl command. Refer to the user
 * documentation for details on what it does.
 *
 *----------------------------------------------------------------------
 */

int
ClockSecondsObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Tcl interpreter */
    int objc,			/* Parameter count */
    Tcl_Obj *const *objv)	/* Parameter values */
{
    Tcl_Time now;
    Tcl_Obj *timeObj;

    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 0, objv, "clock seconds");
	return TCL_ERROR;
    }
    Tcl_GetTime(&now);
    TclNewUIntObj(timeObj, (Tcl_WideUInt)now.sec);

    Tcl_SetObjResult(interp, timeObj);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ClockSafeCatchCmd --
 *
 *	Same as "::catch" command but avoids overwriting of interp state.
 *
 *	See [554117edde] for more info (and proper solution).
 *
 *----------------------------------------------------------------------
 */
int
ClockSafeCatchCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    typedef struct {
	int status;		/* return code status */
	int flags;		/* Each remaining field saves the */
	int returnLevel;	/* corresponding field of the Interp */
	int returnCode;		/* struct. These fields taken together are */
	Tcl_Obj *errorInfo;	/* the "state" of the interp. */
	Tcl_Obj *errorCode;
	Tcl_Obj *returnOpts;
	Tcl_Obj *objResult;
	Tcl_Obj *errorStack;
	int resetErrorStack;
    } InterpState;

    Interp *iPtr = (Interp *)interp;
    int ret, flags = 0;
    InterpState *statePtr;

    if (objc == 1) {
	/* wrong # args : */
	return Tcl_CatchObjCmd(NULL, interp, objc, objv);
    }

    statePtr = (InterpState *)Tcl_SaveInterpState(interp, 0);
    if (!statePtr->errorInfo) {
	/* todo: avoid traced get of errorInfo here */
	TclInitObjRef(statePtr->errorInfo,
		Tcl_ObjGetVar2(interp, iPtr->eiVar, NULL, 0));
	flags |= ERR_LEGACY_COPY;
    }
    if (!statePtr->errorCode) {
	/* todo: avoid traced get of errorCode here */
	TclInitObjRef(statePtr->errorCode,
		Tcl_ObjGetVar2(interp, iPtr->ecVar, NULL, 0));
	flags |= ERR_LEGACY_COPY;
    }

    /* original catch */
    ret = Tcl_CatchObjCmd(NULL, interp, objc, objv);

    if (ret == TCL_ERROR) {
	Tcl_DiscardInterpState((Tcl_InterpState)statePtr);
	return TCL_ERROR;
    }
    /* overwrite result in state with catch result */
    TclSetObjRef(statePtr->objResult, Tcl_GetObjResult(interp));
    /* set result (together with restore state) to interpreter */
    (void) Tcl_RestoreInterpState(interp, (Tcl_InterpState)statePtr);
    /* todo: unless ERR_LEGACY_COPY not set in restore (branch [bug-554117edde] not merged yet) */
    iPtr->flags |= (flags & ERR_LEGACY_COPY);
    return ret;
}

/*
 *----------------------------------------------------------------------
 *
 * TzsetIfNecessary --
 *
 *	Calls the tzset() library function if the contents of the TZ
 *	environment variable has changed.
 *
 * Results:
 *	An epoch counter to allow efficient checking if the timezone has
 *	changed.
 *
 * Side effects:
 *	Calls tzset.
 *
 *----------------------------------------------------------------------
 */

#ifdef _WIN32
#define getenv(x) _wgetenv(L##x)
#else
#define WCHAR char
#define wcslen strlen
#define wcscmp strcmp
#define wcscpy strcpy
#endif
#define TZ_INIT_MARKER	((WCHAR *) INT2PTR(-1))

typedef struct {
    WCHAR *was;			/* Previous value of TZ. */
#if TCL_MAJOR_VERSION > 8
    long long lastRefresh;	/* Used for latency before next refresh. */
#else
    long lastRefresh;		/* Used for latency before next refresh. */
#endif
    size_t epoch;		/* Epoch, signals that TZ changed. */
    size_t envEpoch;		/* Last env epoch, for faster signaling,
				 * that TZ changed via TCL */
} ClockTzStatic;
static ClockTzStatic tz = {	/* Global timezone info; protected by
				 * clockMutex.*/
    TZ_INIT_MARKER, 0, 0, 0
};

static size_t
TzsetIfNecessary(void)
{
    const WCHAR *tzNow;		/* Current value of TZ. */
    Tcl_Time now;		/* Current time. */
    size_t epoch;		/* The tz.epoch that the TZ was read at. */

    /*
     * Prevent performance regression on some platforms by resolving of system time zone:
     * small latency for check whether environment was changed (once per second)
     * no latency if environment was changed with tcl-env (compare both epoch values)
     */

    Tcl_GetTime(&now);
    if (now.sec == tz.lastRefresh && tz.envEpoch == TclEnvEpoch) {
	return tz.epoch;
    }

    tz.envEpoch = TclEnvEpoch;
    tz.lastRefresh = now.sec;

    /* check in lock */
    Tcl_MutexLock(&clockMutex);
    tzNow = getenv("TCL_TZ");
    if (tzNow == NULL) {
	tzNow = getenv("TZ");
    }
    if (tzNow != NULL && (tz.was == NULL || tz.was == TZ_INIT_MARKER
	    || wcscmp(tzNow, tz.was) != 0)) {
	tzset();
	if (tz.was != NULL && tz.was != TZ_INIT_MARKER) {
	    Tcl_Free(tz.was);
	}
	tz.was = (WCHAR *)Tcl_Alloc(sizeof(WCHAR) * (wcslen(tzNow) + 1));
	wcscpy(tz.was, tzNow);
	epoch = ++tz.epoch;
    } else if (tzNow == NULL && tz.was != NULL) {
	tzset();
	if (tz.was != TZ_INIT_MARKER) {
	    Tcl_Free(tz.was);
	}
	tz.was = NULL;
	epoch = ++tz.epoch;
    } else {
	epoch = tz.epoch;
    }
    Tcl_MutexUnlock(&clockMutex);

    return epoch;
}

static void
ClockFinalize(
    TCL_UNUSED(void *))
{
    TclClockFrmScnFinalize();

    if (tz.was && tz.was != TZ_INIT_MARKER) {
	Tcl_Free(tz.was);
    }

    Tcl_MutexFinalize(&clockMutex);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
