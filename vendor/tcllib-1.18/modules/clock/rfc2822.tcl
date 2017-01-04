## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Copyright (c) 2004 Kevin Kenny
## Origin http://wiki.tcl.tk/24074

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package provide clock::rfc2822 0.1
namespace eval ::clock::rfc2822 {}

# # ## ### ##### ######## ############# #####################
## API

# ::clock::rfc2822::parse_date --
#
#       Parses a date expressed in RFC2822 format
#
# Parameters:
#       date - The date to parse
#
# Results:
#       Returns the date expressed in seconds from the Epoch, or throws
#       an error if the date could not be parsed.

proc ::clock::rfc2822::parse_date { date } {
    variable datepats

    # Strip comments and excess whitespace from the date field

    regsub -all -expanded {
        \(              # open parenthesis
        (:?
	 [^()[.\.]]     # character other than ()\
	     |\\.       # or backslash escape
	 )*             # any number of times
        \)              # close paren
    } $date {} date
    set date [string trim $date]

    # Match the patterns in order of preference, returning the first success

    foreach {regexp pat} $datepats {
        if { [regexp -nocase $regexp $date] } {
            return [clock scan $date -format $pat]
        }
    }

    return -code error -errorcode {CLOCK RFC2822 BADDATE} \
        "expected an RFC2822 date, got \"$date\""
}


# # ## ### ##### ######## ############# #####################
## Internals, transient, removed after initialization.

# AddDatePat --
#
#       Internal procedure that adds a date pattern to the pattern list
#
# Parameters:
#       wpat - Regexp pattern that matches the weekday
#       wgrp - Format group that matches the weekday
#       ypat - Regexp pattern that matches the year
#       ygrp - Format group that matches the year
#       mdpat - Regexp pattern that matches month and day
#       mdgrp - Format group that matches month and day
#       spat - Regexp pattern that matches the seconds of the minute
#       sgrp - Format group that matches the seconds of the minute
#       zpat - Regexp pattern that matches the time zone
#       zgrp - Format group that matches the time zone
#
# Results:
#       None
#
# Side effects:
#       Adds a complete regexp and a complete [clock scan] pattern to
#       'datepats'

proc ::clock::rfc2822::AddDatePat { wpat wgrp ypat ygrp mdpat mdgrp
				    spat sgrp zpat zgrp } {
    variable datepats

    set regexp {^[[:space:]]*}
    set pat {}
    append regexp $wpat $mdpat {[[:space:]]+} $ypat
    append pat $wgrp $mdgrp $ygrp
    append regexp {[[:space:]]+\d\d?:\d\d} $spat
    append pat { %H:%M} $sgrp
    append regexp $zpat
    append pat $zgrp
    append regexp {[[:space:]]*$}
    lappend datepats $regexp $pat
    return
}

# InitDatePats --
#
#       Internal procedure that initializes the set of date patterns
# 	allowed in an RFC2822 date
#
# Parameters:
#       permissible - 1 if erroneous (but common) time zones are to be
#                     allowed, 0 if they are to be rejected
#
# Results:
#       None.
#
# Side effects:

proc ::clock::rfc2822::InitDatePats { permissible } {
    # Produce formats for the observed variants of ISO2822 dates.
    # Permissible variants come first in the list; impermissible ones
    # come later.

    # The month and day may be "%b %d" or "%d %b"

    foreach mdpat {{[[:alpha:]]+[[:space:]]+\d\d?}
        {\d\d?[[:space:]]+[[:alpha:]]+}} \
        mdgrp {{%b %d} {%d %b}} \
        mdperm {0 1} {
            # The year may be two digits, or four. Four digit year is
            # done first.

            foreach ypat {{\d\d\d\d} {\d\d}} ygrp {%Y %y} {
                # The seconds of the minute may be provided, or
                # omitted.

                foreach spat {{:\d\d} {}} sgrp {:%S {}} {
                    # The weekday may be provided or omitted. It is
                    # common but impermissible to omit the comma after
                    # the weekday name.

                    foreach wpat {
                        {(?:Mon|T(?:ue|hu)|Wed|Fri|S(?:at|un)),[[:space:]]+}
                        {(?:Mon|T(?:ue|hu)|Wed|Fri|S(?:at|un))[[:space:]]+}
                        {}
                    } wgrp {
                        {%a, }
                        {%a }
                        {}
                    } wperm {
                        1
                        0
                        1
                    } {
                        # Time zone is defined as +/- hhmm, or as a
                        # named time zone.  Other common but buggy
                        # formats are GMT+-hh:mm, a time zone name in
                        # quotation marks, and complete omission of
                        # the time zone.

                        foreach zpat {
                            {[[:space:]]+(?:[-+]\d\d\d\d|[[:alpha:]]+)}
                            {[[:space:]]+GMT[-+]\d\d:?\d\d}
                            {[[:space:]]+"[[:alpha:]]+"}
                            {}
                        } zgrp {
                            { %Z}
                            { GMT%Z}
                            { "%Z"}
                            {}
                        } zperm {
                            1
                            0
                            0
                            0
                        } {
                            if { ($zperm && $wperm && $mdperm)
                                 == $permissible } {
                                AddDatePat $wpat $wgrp $ypat $ygrp \
                                    $mdpat $mdgrp \
                                    $spat $sgrp $zpat $zgrp
                            }
                        }
                    }
                }
            }
        }
    return
}

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::clock::rfc2822 {
    namespace export parse_date
    namespace ensemble create

    variable datepats {}
}

# # ## ### ##### ######## ############# #####################
# Initialize the date patterns

namespace eval ::clock::rfc2822 {
    InitDatePats 1
    InitDatePats 0
    rename AddDatePat {}
    rename InitDatePats {}
    #puts [join $datepats \n]
}

# # ## ### ##### ######## ############# #####################

return
# Usage example, disabled

if {![info exists ::argv0] || [info script] ne $::argv0} return
puts [clock format \
          [::clock::rfc2822::parse_date {Mon(day), 23 Aug(ust) 2004 01:23:45 UT}]]
puts [clock format \
          [::clock::rfc2822::parse_date "Tue, Jul 21 2009 19:37:47 GMT-0400"]]
