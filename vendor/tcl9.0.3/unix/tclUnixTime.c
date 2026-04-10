/*
 * tclUnixTime.c --
 *
 *	Contains Unix specific versions of Tcl functions that obtain time
 *	values from the operating system.
 *
 * Copyright © 1995 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#if defined(TCL_WIDE_CLICKS) && defined(MAC_OSX_TCL)
#include <mach/mach_time.h>
#endif

/*
 * Static functions declared in this file.
 */

static void		NativeScaleTime(Tcl_Time *timebuf,
			    void *clientData);
static void		NativeGetTime(Tcl_Time *timebuf,
			    void *clientData);

/*
 * TIP #233 (Virtualized Time): Data for the time hooks, if any.
 */

Tcl_GetTimeProc *tclGetTimeProcPtr = NativeGetTime;
Tcl_ScaleTimeProc *tclScaleTimeProcPtr = NativeScaleTime;
void *tclTimeClientData = NULL;

/*
 * Inlined version of Tcl_GetTime.
 */

static inline void
GetTime(
    Tcl_Time *timePtr)
{
    tclGetTimeProcPtr(timePtr, tclTimeClientData);
}

#if defined(NO_GETTOD) || defined(TCL_WIDE_CLICKS)
static inline int
IsTimeNative(void)
{
    return tclGetTimeProcPtr == NativeGetTime;
}
#endif

/*
 *----------------------------------------------------------------------
 *
 * TclpGetSeconds --
 *
 *	This procedure returns the number of seconds from the epoch. On most
 *	Unix systems the epoch is Midnight Jan 1, 1970 GMT.
 *
 * Results:
 *	Number of seconds from the epoch.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

unsigned long long
TclpGetSeconds(void)
{
    return (unsigned long long) time(NULL);
}

/*
 *----------------------------------------------------------------------
 *
 * TclpGetMicroseconds --
 *
 *	This procedure returns the number of microseconds from the epoch.
 *	On most Unix systems the epoch is Midnight Jan 1, 1970 GMT.
 *
 * Results:
 *	Number of microseconds from the epoch.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

long long
TclpGetMicroseconds(void)
{
    Tcl_Time time;

    GetTime(&time);
    return time.sec * 1000000 + time.usec;
}

/*
 *----------------------------------------------------------------------
 *
 * TclpGetClicks --
 *
 *	This procedure returns a value that represents the highest resolution
 *	clock available on the system. There are no guarantees on what the
 *	resolution will be. In Tcl we will call this value a "click". The
 *	start time is also system dependent.
 *
 * Results:
 *	Number of clicks from some start time.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

unsigned long long
TclpGetClicks(void)
{
    unsigned long long now;

#ifdef NO_GETTOD
    if (!IsTimeNative()) {
	Tcl_Time time;

	GetTime(&time);
	now = ((unsigned long long)(time.sec)*1000000ULL) +
		(unsigned long long)(time.usec);
    } else {
	/*
	 * A semi-NativeGetTime, specialized to clicks.
	 */
	struct tms dummy;

	now = (unsigned long long) times(&dummy);
    }
#else /* !NO_GETTOD */
    Tcl_Time time;

    GetTime(&time);
    now = ((unsigned long long)(time.sec)*1000000ULL) +
	    (unsigned long long)(time.usec);
#endif /* NO_GETTOD */

    return now;
}
#ifdef TCL_WIDE_CLICKS

/*
 *----------------------------------------------------------------------
 *
 * TclpGetWideClicks --
 *
 *	This procedure returns a WideInt value that represents the highest
 *	resolution clock available on the system. There are no guarantees on
 *	what the resolution will be. In Tcl we will call this value a "click".
 *	The start time is also system dependent.
 *
 * Results:
 *	Number of WideInt clicks from some start time.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

long long
TclpGetWideClicks(void)
{
    long long now;

    if (!IsTimeNative()) {
	Tcl_Time time;

	GetTime(&time);
	now = ((long long) time.sec)*1000000 + time.usec;
    } else {
#ifdef MAC_OSX_TCL
	now = (long long) (mach_absolute_time() & INT64_MAX);
#else
#error Wide high-resolution clicks not implemented on this platform
#endif /* MAC_OSX_TCL */
    }

    return now;
}

/*
 *----------------------------------------------------------------------
 *
 * TclpWideClicksToNanoseconds --
 *
 *	This procedure converts click values from the TclpGetWideClicks native
 *	resolution to nanosecond resolution.
 *
 * Results:
 *	Number of nanoseconds from some start time.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

double
TclpWideClicksToNanoseconds(
    long long clicks)
{
    double nsec;

    if (!IsTimeNative()) {
	nsec = clicks * 1000;
    } else {
#ifdef MAC_OSX_TCL
	static mach_timebase_info_data_t tb;
	static uint64_t maxClicksForUInt64;

	if (!tb.denom) {
	    mach_timebase_info(&tb);
	    maxClicksForUInt64 = UINT64_MAX / tb.numer;
	}
	if ((uint64_t) clicks < maxClicksForUInt64) {
	    nsec = ((uint64_t) clicks) * tb.numer / tb.denom;
	} else {
	    nsec = ((long double) (uint64_t) clicks) * tb.numer / tb.denom;
	}
#else
#error Wide high-resolution clicks not implemented on this platform
#endif /* MAC_OSX_TCL */
    }

    return nsec;
}

/*
 *----------------------------------------------------------------------
 *
 * TclpWideClickInMicrosec --
 *
 *	This procedure return scale to convert click values from the
 *	TclpGetWideClicks native resolution to microsecond resolution
 *	and back.
 *
 * Results:
 *	1 click in microseconds as double.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

double
TclpWideClickInMicrosec(void)
{
    if (!IsTimeNative()) {
	return 1.0;
    } else {
#ifdef MAC_OSX_TCL
	static int initialized = 0;
	static double scale = 0.0;

	if (!initialized) {
	    mach_timebase_info_data_t tb;

	    mach_timebase_info(&tb);
	    /* value of tb.numer / tb.denom = 1 click in nanoseconds */
	    scale = ((double) tb.numer) / tb.denom / 1000;
	    initialized = 1;
	}
	return scale;
#else
#error Wide high-resolution clicks not implemented on this platform
#endif /* MAC_OSX_TCL */
    }
}
#endif /* TCL_WIDE_CLICKS */

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetTime --
 *
 *	Gets the current system time in seconds and microseconds since the
 *	beginning of the epoch: 00:00 UCT, January 1, 1970.
 *
 *	This function is hooked, allowing users to specify their own virtual
 *	system time.
 *
 * Results:
 *	Returns the current time in timePtr.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_GetTime(
    Tcl_Time *timePtr)		/* Location to store time information. */
{
    GetTime(timePtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SetTimeProc --
 *
 *	TIP #233 (Virtualized Time): Registers two handlers for the
 *	virtualization of Tcl's access to time information.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Remembers the handlers, alters core behaviour.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_SetTimeProc(
    Tcl_GetTimeProc *getProc,
    Tcl_ScaleTimeProc *scaleProc,
    void *clientData)
{
    tclGetTimeProcPtr = getProc;
    tclScaleTimeProcPtr = scaleProc;
    tclTimeClientData = clientData;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_QueryTimeProc --
 *
 *	TIP #233 (Virtualized Time): Query which time handlers are registered.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_QueryTimeProc(
    Tcl_GetTimeProc **getProc,
    Tcl_ScaleTimeProc **scaleProc,
    void **clientData)
{
    if (getProc) {
	*getProc = tclGetTimeProcPtr;
    }
    if (scaleProc) {
	*scaleProc = tclScaleTimeProcPtr;
    }
    if (clientData) {
	*clientData = tclTimeClientData;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * NativeScaleTime --
 *
 *	TIP #233: Scale from virtual time to the real-time. For native scaling
 *	the relationship is 1:1 and nothing has to be done.
 *
 * Results:
 *	Scales the time in timePtr.
 *
 * Side effects:
 *	See above.
 *
 *----------------------------------------------------------------------
 */

static void
NativeScaleTime(
    TCL_UNUSED(Tcl_Time *),
    TCL_UNUSED(void *))
{
    /* Native scale is 1:1. Nothing is done */
}

/*
 *----------------------------------------------------------------------
 *
 * NativeGetTime --
 *
 *	TIP #233: Gets the current system time in seconds and microseconds
 *	since the beginning of the epoch: 00:00 UCT, January 1, 1970.
 *
 * Results:
 *	Returns the current time in timePtr.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static void
NativeGetTime(
    Tcl_Time *timePtr,
    TCL_UNUSED(void *))
{
    struct timeval tv;

    (void) gettimeofday(&tv, NULL);
    timePtr->sec = tv.tv_sec;
    timePtr->usec = tv.tv_usec;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
