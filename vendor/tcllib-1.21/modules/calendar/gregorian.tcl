#----------------------------------------------------------------------
#
# gregorian.tcl --
#
#	Routines for manipulating dates on the Gregorian calendar.
#
# Copyright (c) 2002 by Kevin B. Kenny.  All rights reserved.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: gregorian.tcl,v 1.5 2004/01/15 06:36:12 andreas_kupries Exp $
#
#----------------------------------------------------------------------

package require Tcl 8.2;		# Not tested with earlier releases

#----------------------------------------------------------------------
#
# Many of the routines in this file accept the name of a "date array"
# in the caller's scope.  This array is used to hold the various fields
# of a civil date.  While few if any routines use or set all the fields,
# the fields, where used or set, are always interpreted the same way.
# The complete listing of fields used is:
#
#	ERA -- The era in the given calendar to which a year refers.
#	       In the Julian and Gregorian calendars, the ERA is one
#	       of the constants, BCE or CE (Before the Common Era,
#	       or Common Era).  The conventional names, BC and AD
#	       are also accepted.  In other local calendars, the ERA
#	       may be some other value, for instance, the name of
#	       an emperor, AH (anno Hegirae or anno Hebraica), AM
#	       (anno mundi), etc.
#
#	YEAR - The number of the year within the given era.
#
#	FISCAL_YEAR - The year to which 'WEEK_OF_YEAR' (see below)
#		      refers.  Near the beginning or end of a given
#		      calendar year, the fiscal week may be the first
#		      week of the following year or the last week of the
#		      preceding year.
#
#	MONTH - The number of the month within the given year.  Month
#	        numbers run from 1 to 12 in the common calendar; some
#		local calendars include a thirteenth month in some years.
#
#	WEEK_OF_YEAR - The week number in the given year.  On the usual
#		       fiscal calendar, the week may range from 1 to 53.
#
#	DAY_OF_WEEK_IN_MONTH - The ordinal number of a weekday within
#			       the given month.  Used in conjunction
#			       with DAY_OF_WEEK to express constructs like,
#			       'the fourth Thursday in November'.
#			       Values run from 1 to the number of weeks in
#			       the month.  Negative values are interpreted
#			       from the end of the month; allowing
#			       for 'the last Sunday of October'; 'the
#			       next-to-last Sunday of October', etc.
#
#	DAY_OF_YEAR - The day of the given year.  (The first day of a year
#		      is day number 1.)
#
#	DAY_OF_MONTH - The day of the given month.
#
#	DAY_OF_WEEK - The number of the day of the week.  Sunday = 0,
#		      Monday = 1, ..., Saturday = 6.  In locales where
#		      a day other than Sunday is the first day of the week,
#		      the values of the days before it are incremented by
#		      seven; thus, in an ISO locale, Monday = 1, ...,
#		      Sunday == 7.
#
# The following fields in a date array change the behavior of FISCAL_YEAR
# and WEEK_OF_YEAR:
#
#	DAYS_IN_FIRST_WEEK - The minimum number of days that a week must
#			     have before it is accounted the first week
#			     of a year.  For the ISO fiscal calendar, this
#			     number is 4.
#
#	FIRST_DAY_OF_WEEK - The day of the week (Sunday = 0, ..., Saturday = 6)
#			    on which a new fiscal year begins.  Days greater
#			    than 6 are reduced modulo 7.
# 
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#
# The calendar::CommonCalendar namespace contains code for handling
# dates on the 'common calendar' -- the civil calendar in virtually
# the entire Western world.  The common calendar is the Julian
# calendar prior to a certain date that varies with the locale, and
# the Gregorian calendar thereafter.
#
#----------------------------------------------------------------------

namespace eval ::calendar::CommonCalendar {

    namespace export WeekdayOnOrBefore
    namespace export CivilYearToAbsolute

    # Number of days in the months in a common year and a leap year

    variable daysInMonth           [list 31 28 31 30 31 30 31 31 30 31 30 31]
    variable daysInMonthInLeapYear [list 31 29 31 30 31 30 31 31 30 31 30 31]

    # Number of days preceding the start of a given month in a leap year
    # and common year.  For convenience, these lists are zero based and
    # contain a thirteenth month; [lindex $daysInPriorMonths 3], for instance
    # gives the number of days preceding 1 March, and
    # [lindex $daysInPriorMonths 13] gives the number of days in a common
    # year.

    variable daysInPriorMonths
    variable daysInPriorMonthsInLeapYear

    set dp 0
    set dply 0
    set daysInPriorMonths [list {} 0]
    set daysInPriorMonthsInLeapYear [list {} 0]
    foreach d $daysInMonth dly $daysInMonthInLeapYear {
	lappend daysInPriorMonths [incr dp $d]
	lappend daysInPriorMonthsInLeapYear [incr dply $dly]
    }
    unset d dly dp dply

}

#----------------------------------------------------------------------
#
# ::calendar::CommonCalendar::WeekdayOnOrBefore --
#
#	Determine the last time that a given day of the week occurs
#	on or before a given date (e.g., Sunday on or before January 2).
#
# Parameters:
#	weekday -- Day of the week (Sunday = 0 .. Saturday = 6)
#		   Days greater than 6 are interpreted modulo 7.
#	j -- Julian day number.
#
# Results:
#	Returns the Julian day number of the desired day.
#
# Side effects:
#	None.
#
#----------------------------------------------------------------------

proc ::calendar::CommonCalendar::WeekdayOnOrBefore { weekday j } {
    # Normalize weekday, Monday=0
    set k [expr { ($weekday + 6) % 7 }]
    return [expr { $j - ( $j - $k ) % 7 }]
}

#----------------------------------------------------------------------
#
# ::calendar::CommonCalendar::CivilYearToAbsolute --
#
#	Calculate an "absolute" year number, that is, the count of
#	years from the common epoch, 1 B.C.E.
#
# Parameters:
#	dateVar -- Name of an array in caller's scope containing the
#		   fields ERA (BCE or CE) and YEAR.
#
# Results:
#	Returns an absolute year number.  The years in the common era
#	have their natural numbers; the year 1 BCE returns 0, 2 BCE returns
#	-1, and so on.
#
# Side effects:
#	None.
#
# The popular names BC and AD are accepted as synonyms for BCE and CE.
#
#----------------------------------------------------------------------

proc ::calendar::CommonCalendar::CivilYearToAbsolute { dateVar } {

    upvar 1 $dateVar date
    switch -exact $date(ERA) {
	BCE - BC {
	    return [expr { 1 - $date(YEAR) }]
	}
	CE - AD {
	    return $date(YEAR)
	}
	default {
	    return -code error "Unknown era \"$date(ERA)\""
	}
    }
}

#----------------------------------------------------------------------
#
# The calendar::GregorianCalendar namespace contains codes specific to the
# Gregorian calendar.  These codes deal specifically with dates after
# the conversion from the Julian to Gregorian calendars (which are
# various dates in various locales; 1582 in most Catholic countries,
# 1752 in most English-speaking countries, 1917 in Russia, ...).
# If presented with earlier dates, these codes will compute based on
# a hypothetical proleptic calendar.
#
#----------------------------------------------------------------------

namespace eval calendar::GregorianCalendar {

    namespace import ::calendar::CommonCalendar::WeekdayOnOrBefore
    namespace import ::calendar::CommonCalendar::CivilYearToAbsolute

    namespace export IsLeapYear

    namespace export EYMDToJulianDay
    namespace export EYDToJulianDay
    namespace export EFYWDToJulianDay
    namespace export EYMWDToJulianDay
    
    namespace export JulianDayToEYD
    namespace export JulianDayToEYMD
    namespace export JulianDayToEFYWD
    namespace export JulianDayToEYMWD

    # The Gregorian epoch -- 31 December, 1 B.C.E, Gregorian, expressed
    # as a Julian day number.  (This date is 2 January, 1 C.E., in the
    # proleptic Julian calendar.)

    variable epoch 1721425

    # Common years - these years, mod 400, are the irregular common years
    # of the Gregorian calendar

    variable commonYears
    array set commonYears { 100 {} 200 {} 300 {} }

}

#----------------------------------------------------------------------
#
# ::calendar::GregorianCalendar::IsLeapYear
#
#	Tests whether a year is a leap year.
#
# Parameters:
#
#	y - Year number of the common era.  The year 0 represents
#	    1 BCE of the proleptic calendar, -1 represents 2 BCE, etc.
#
# Results:
#
#	Returns 1 if the given year is a leap year, 0 otherwise.
#
# Side effects:
#
#	None.
#
#----------------------------------------------------------------------

proc ::calendar::GregorianCalendar::IsLeapYear { y } {

    variable commonYears
    return [expr { ( $y % 4 ) == 0
		   && ![info exists commonYears([expr { $y % 400 }])] }]

}

#----------------------------------------------------------------------
#
# ::calendar::GregorianCalendar::EYMDToJulianDay
#
#    	Convert a date on the Gregorian calendar expressed as
#	era (BCE or CE), year in the era, month number (January = 1)
#	and day of the month to a Julian Day Number.
#
# Parameters:
#
#	dateArray -- Name of an array in caller's scope containing
#		     keys ERA, YEAR, MONTH, and DAY_OF_MONTH
#
# Results:
#
#	Returns the Julian Day Number of the day that starts with
#	noon of the given date.
#
# Side effects:
#
#	None.
#
#----------------------------------------------------------------------

proc ::calendar::GregorianCalendar::EYMDToJulianDay { dateArray } {

    upvar 1 $dateArray date
    
    variable epoch
    variable ::calendar::CommonCalendar::daysInPriorMonths
    variable ::calendar::CommonCalendar::daysInPriorMonthsInLeapYear
    
    # Convert era and year to an absolute year number

    set y [calendar::CommonCalendar::CivilYearToAbsolute date]
    set ym1 [expr { $y - 1 }]
    
    # Calculate the Julian day

    return [expr { $epoch
		   + $date(DAY_OF_MONTH)
		   + ( [IsLeapYear $y] ?
		       [lindex $daysInPriorMonthsInLeapYear $date(MONTH)]
		       : [lindex $daysInPriorMonths $date(MONTH)] )
		   + ( 365 * $ym1 )
		   + ( $ym1 / 4 )
		   - ( $ym1 / 100 )
		   + ( $ym1 / 400 ) }]

}

#----------------------------------------------------------------------
#
# ::calendar::GregorianCalendar::EYDToJulianDay --
#
#	Convert a date expressed in the Gregorian calendar as era (BCE or CE),
#	year, and day-of-year to a Julian Day Number.
#
# Parameters:
#
#	dateArray -- Name of an array in caller's scope containing
#		     keys ERA, YEAR, and DAY_OF_YEAR
#
# Results:
#
#	Returns the Julian Day Number corresponding to noon of the given
#	day.
#
# Side effects:
#
#	None.
#
#----------------------------------------------------------------------

proc ::calendar::GregorianCalendar::EYDToJulianDay { dateArray } {

    upvar 1 $dateArray date
    variable epoch

    set y [CivilYearToAbsolute date]
    set ym1 [expr { $y - 1 }]
    
    return [expr { $epoch
		   + $date(DAY_OF_YEAR)
		   + ( 365 * $ym1 )
		   + ( $ym1 / 4 )
		   - ( $ym1 / 100 )
		   + ( $ym1 / 400 ) }]

}

#----------------------------------------------------------------------
#
# ::calendar::GregorianCalendar::EFYWDToJulianDay --
#
#	Convert a date expressed in the system of era, fiscal year,
#	week number and day number to a Julian Day Number.
#
# Parameters:
#
#	dateArray -- Name of an array in caller's scope that contains
#		     keys ERA, FISCAL_YEAR, WEEK_OF_YEAR, and DAY_OF_WEEK,
#		     and optionally contains DAYS_IN_FIRST_WEEK
#		     and FIRST_DAY_OF_WEEK.
#	daysInFirstWeek -- Minimum number of days that a week must
#			   have to be considered the first week of a
#			   fiscal year.  Default is 4, which gives
#			   ISO8601:1988 semantics.  The parameter is
#			   used only if the 'dateArray' does not
#			   contain a DAYS_IN_FIRST_WEEK key.
#	firstDayOfWeek -- Ordinal number of the first day of the week
#			  (Sunday = 0, Monday = 1, etc.)  Default is
#			  1, which gives ISO8601:1988 semantics.  The
#			  parameter is used only if 'dateArray' does not
#			  contain a DAYS_IN_FIRST_WEEK key.n
#
# Results:
#
#	Returns the Julian Calendar Day corresponding to noon of the given
#	day.
#
# Side effects:
#
#	None.
#
# The ERA element of the array is BCE or CE.
# The FISCAL_YEAR is the year number in the given era.  The year is relative
# to the fiscal week; hence days that are early in January or late in
# December may belong to a different year than the calendar year.
# The WEEK_OF_YEAR is the ordinal number of the week within the year.
# Week 1 is the week beginning on the specified FIRST_DAY_OF_WEEK
# (Sunday = 0, Monday = 1, etc.) and containing at least DAYS_IN_FIRST_WEEK
# days (or, equivalently, containing January DAYS_IN_FIRST_WEEK)
# The DAY_OF_WEEK is Sunday=0, Monday=1, ..., if FIRST_DAY_OF_WEEK
# is 0, or Monday=1, Tuesday=2, ..., Sunday=7 if FIRST_DAY_OF_WEEK
# is 1.
#
#----------------------------------------------------------------------

proc ::calendar::GregorianCalendar::EFYWDToJulianDay { dateArray
						     {daysInFirstWeek 4}
						     {firstDayOfWeek 1}  } {
    upvar 1 $dateArray date

    # Use parameters to supply defaults if the array doesn't
    # have conversion rules.

    if { ![info exists date(DAYS_IN_FIRST_WEEK)] } {
	set date(DAYS_IN_FIRST_WEEK) $daysInFirstWeek
    }
    if { ![info exists date(FIRST_DAY_OF_WEEK)] } {
	set date(FIRST_DAY_OF_WEEK) $firstDayOfWeek
    }

    # Find the start of the fiscal year
    
    set date2(ERA) $date(ERA)
    set date2(YEAR) $date(FISCAL_YEAR)
    set date2(MONTH) 1
    set date2(DAY_OF_MONTH) $date(DAYS_IN_FIRST_WEEK)
    set jd [WeekdayOnOrBefore \
		$date(FIRST_DAY_OF_WEEK) \
		[EYMDToJulianDay date2]]

    # Add the weeks and days.
    
    return [expr { $jd
		   + ( 7 * ( $date(WEEK_OF_YEAR) - 1 ) )
		   + $date(DAY_OF_WEEK) - $date(FIRST_DAY_OF_WEEK) }]

}

#----------------------------------------------------------------------
#
# ::calendar::GregorianCalendar::EYMWDToJulianDay --
#
#	Given era, year, month, and day of week in month (e.g. "first Tuesday")
#	derive a Julian day number.
#
# Parameters:
#	dateVar -- Name of an array in caller's scope containing the
#		   date fields.
#
# Results:
#	Returns the desired Julian day number.
#
# Side effects:
#	None.
#
# The 'dateVar' array is expected to contain the following keys:
#	+ ERA - The constant 'BCE' or 'CE'.
#	+ YEAR - The Gregorian calendar year
#	+ MONTH - The month of the year (1 = January .. 12 = December)
#	+ DAY_OF_WEEK - The day of the week (Sunday = 0 .. Saturday = 6)
#			If day of week is 7 or greater, it is interpreted
#			modulo 7.
#	+ DAY_OF_WEEK_IN_MONTH - The day of week within the month
#				 (1 = first XXXday, 2 = second XXDday, ...
#				 also -1 = last XXXday, -2 = next-to-last
#				 XXXday, ...)
#
#----------------------------------------------------------------------

proc ::calendar::GregorianCalendar::EYMWDToJulianDay { dateVar } {
    
    upvar 1 $dateVar date
    
    variable epoch
    
    # Are we counting from the beginning or the end of the month?

    array set date2 [array get date]
    if { $date(DAY_OF_WEEK_IN_MONTH) >= 0 } {

	# When counting from the start of the month, begin by
	# finding the 'zeroeth' - the last day of the prior month.
	# Note that it's ok to give EYMDToJulianDay a zero day-of-month!
    
	set date2(DAY_OF_MONTH) 0

    } else {

	# When counting from the end of the month, the 'zeroeth'
	# is the seventh of the following month.  Note that it's ok
	# to give EYMDToJulianDay a thirteenth month!

	incr date2(MONTH)
	set date2(DAY_OF_MONTH) 7

    }

    set zeroethDayOfMonth [EYMDToJulianDay date2]

    # Find the zeroeth weekday in the given month
	
    set wd0 [WeekdayOnOrBefore $date(DAY_OF_WEEK) $zeroethDayOfMonth]
	
    # Add the requisite number of weeks
	
    return [expr { $wd0 + 7 * $date(DAY_OF_WEEK_IN_MONTH) }]

}

#----------------------------------------------------------------------
#
# ::calendar::GregorianCalendar::JulianDayToEYD --
#
#	Given a Julian day number, compute era, year, and day of year.
#
# Parameters:
#	j - Julian day number
#	dateVar - Name of an array in caller's scope that will receive the
#	          date fields.
#
# Results:
#	Returns an absolute year; that is, returns the year number for
#	years in the Common Era; returns 0 for 1 B.C.E., -1 for 2 B.C.E.,
#	and so on.
#
# Side effects:
#	The 'dateVar' array is populated with the following:
#		+ ERA - The era corresponding to the given Julian Day.
#			(BCE or CE)
#		+ YEAR - The year of the given era.
#		+ DAY_OF_YEAR - The day within the given year (1 = 1 January,
#		  etc.)
#
#----------------------------------------------------------------------

proc ::calendar::GregorianCalendar::JulianDayToEYD { j dateVar } {

    upvar 1 $dateVar date
    
    variable epoch
    
    # Absolute day number relative to the Gregorian epoch
    
    set day [expr { $j - $epoch - 1}]
    
    # Count 400-year cycles
    
    set year 1
    set n [expr { $day  / 146097 }]
    incr year [expr { 400 * $n }]
    set day [expr { $day % 146097 }]
    
    # Count centuries
    
    set n [expr { $day / 36524 }]
    set day [expr { $day % 36524 }]
    if { $n > 3 } {			# Last day of 1600, 2000, 2400...
	set n 3
	incr day 36524
    }
    incr year [expr { 100 * $n }]
    
    # Count 4-year cycles
    
    set n [expr { $day / 1461 }]
    set day [expr { $day % 1461 }]
    incr year [expr { 4 * $n }]
    
    # Count years
    
    set n [expr { $day / 365 }]
    set day [expr { $day % 365 }]
    if { $n > 3 } {			# December 31 of a leap year
	set n 3
	incr day 365
    }
    incr year $n
    
    # Determine the era
    
    if { $year <= 0 } {
	set date(YEAR) [expr { 1 - $year }]
	set date(ERA) BCE
    } else {
	set date(YEAR) $year
	set date(ERA) CE
    }
    
    # Determine day of year.
    
    set date(DAY_OF_YEAR) [expr { $day + 1 }]
    return $year

}

#----------------------------------------------------------------------
#
# ::calendar::GregorianCalendar::JulianDayToEYMD --
#
#	Given a Julian day number, compute era, year, month, and day
#	of the Gregorian calendar.
#
# Parameters:
#	j - Julian day number
#	dateVar - Name of a variable in caller's scope that will be
#		  filled in with the fields, ERA, YEAR, MONTH, DAY_OF_MONTH,
#		  and DAY_OF_YEAR (this last comes as a side effect of how
#		  the calculations are performed, but is trustworthy).
#
# Results:
#	None.
#
# Side effects:
#	Requested fields of dateVar are filled in.
#
#----------------------------------------------------------------------

proc ::calendar::GregorianCalendar::JulianDayToEYMD  { j dateVar } {

    upvar 1 $dateVar date
    
    variable ::calendar::CommonCalendar::daysInMonth
    variable ::calendar::CommonCalendar::daysInMonthInLeapYear
    
    set year [JulianDayToEYD $j date]
    set day $date(DAY_OF_YEAR)
    
    if { [IsLeapYear $year] } {
	set hath $daysInMonthInLeapYear
    } else {
	set hath $daysInMonth
    }
    set month 1
    foreach n $hath {
	if { $day <= $n } {
	    break
	}
	incr month
	set day [expr { $day - $n }]
    }
    set date(MONTH) $month
    set date(DAY_OF_MONTH) $day
    
    return
    
}

#----------------------------------------------------------------------
#
# ::calendar::GregorianCalendar::JulianDayToEFYWD --
#
#	Given a julian day number, compute era, fiscal year, fiscal week,
#	and day of week in a fiscal calendar based on the Gregorian calendar.
#
# Parameters:
#	j - Julian day number
#	dateVar - Name of an array in caller's scope that is to receive the
#		  fields of the date.  The array may be prepared with
#		  DAYS_IN_FIRST_WEEK and FIRST_DAY_OF_WEEK fields to
#		  change the rule for computing the fiscal week.
#	daysInFirstWeek - (Optional) Parameter giving the minimum number
#			  of days in the first week of a year.  Default is 4.
#	firstDayOfWeek - (Optional) Parameter giving the day number of the
#			 first day of a fiscal week (Sunday = 0 .. 
#			 Saturday = 6).  Default is 1 (Monday).
#
# Results:
#	None.
#
# Side effects:
#	The ERA, YEAR, FISCAL_YEAR, DAY_OF_YEAR, WEEK_OF_YEAR, DAY_OF_WEEK,
#	DAYS_IN_FIRST_WEEK, and FIRST_DAY_OF_WEEK fields in the 'dateVar'
#	array are filled in.
#
# If DAYS_IN_FIRST_WEEK or FIRST_DAY_OF_WEEK fields are present in
# 'dateVar' prior to the call, they override any values passed on the
# command line.
#
#----------------------------------------------------------------------

proc ::calendar::GregorianCalendar::JulianDayToEFYWD { j
						     dateVar
						     {daysInFirstWeek 4}
						     {firstDayOfWeek 1}  } {
    upvar 1 $dateVar date
    
    if { ![info exists date(DAYS_IN_FIRST_WEEK)] } {
	set date(DAYS_IN_FIRST_WEEK) $daysInFirstWeek
    }
    if { ![info exists date(FIRST_DAY_OF_WEEK)] } {
	set date(FIRST_DAY_OF_WEEK) $firstDayOfWeek
    }
    
    # Determine the calendar year of $j - $daysInFirstWeek + 1.
    # Guess the fiscal year
    
    JulianDayToEYD [expr { $j - $daysInFirstWeek + 1 }] date1
    set date1(FISCAL_YEAR) [expr { $date1(YEAR) + 1 }]
    
    # Determine the start of the fiscal year that we guessed
    
    set date1(WEEK_OF_YEAR) 1
    set date1(DAY_OF_WEEK) $firstDayOfWeek
    set startOfFiscalYear [EFYWDToJulianDay \
			       date1 \
			       $date(DAYS_IN_FIRST_WEEK) \
			       $date(FIRST_DAY_OF_WEEK)]
    
    # If we guessed high, fix it.
    
    if { $j < $startOfFiscalYear } {
	incr date1(FISCAL_YEAR) -1
	set startOfFiscalYear [EFYWDToJulianDay date1]
    }
    
    set date(FISCAL_YEAR) $date1(FISCAL_YEAR)
    
    # Get the week number and the day within the week
    
    set dayOfFiscalYear [expr { $j - $startOfFiscalYear }]
    set date(WEEK_OF_YEAR) [expr { ( $dayOfFiscalYear / 7 ) + 1 }]
    set date(DAY_OF_WEEK) [expr { ( $dayOfFiscalYear + 1 ) % 7 }]
    if { $date(DAY_OF_WEEK) < $date(FIRST_DAY_OF_WEEK) } {
	incr date(DAY_OF_WEEK) 7
    }
    
    return
}

#----------------------------------------------------------------------
#
# GregorianCalendar::JulianDayToEYMWD --
#
#	Convert a Julian day number to year, month, day-of-week-in-month
#	(e.g., first Tuesday), and day of week.
#
# Parameters:
#	j - Julian day number
#	dateVar - Name of an array in caller's scope that holds the
#		  fields of the date.
#
# Results:
#	None.
#
# Side effects:
#	The ERA, YEAR, MONTH, DAY_OF_MONTH, DAY_OF_WEEK, and
#	DAY_OF_WEEK_IN_MONTH fields of the given date are all filled
#	in.
#
# Notes:
#	DAY_OF_WEEK_IN_MONTH is always positive on return.
#
#----------------------------------------------------------------------

proc ::calendar::GregorianCalendar::JulianDayToEYMWD { j dateVar } {

    upvar 1 $dateVar date

    # Compute era, year, month and day

    JulianDayToEYMD $j date

    # Find day of week

    set date(DAY_OF_WEEK) [expr { ( $j + 1 ) % 7 }]

    # Find day of week in month

    set date(DAY_OF_WEEK_IN_MONTH) \
	[expr { ( ( $date(DAY_OF_MONTH) - 1 ) / 7) + 1 }]

    return

}
