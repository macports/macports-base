## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Copyright (c) 2004 Kevin Kenny
## Origin http://wiki.tcl.tk/13094
## Modified for Tcl 8.5 only (eval -> {*}).

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package provide clock::iso8601 0.1
namespace eval ::clock::iso8601 {}

# # ## ### ##### ######## ############# #####################
## API

# iso8601::parse_date --
#
#       Parse an ISO8601 date/time string in an unknown variant.
#
# Parameters:
#       string -- String to parse
#       args -- Arguments as for [clock scan]; may include any of
#               the '-base', '-gmt', '-locale' or '-timezone options.
#
# Results:
#       Returns the given date in seconds from the Posix epoch.

proc ::clock::iso8601::parse_date { string args } {
    variable DatePatterns
    variable Repattern
    foreach { regex interpretation } $DatePatterns {
	if { [regexp "^$regex\$" $string] } {
	    #puts A|$string|\t|$regex|\t|$interpretation|

	    # For incomplete dates (month and/or day missing), we have
	    # to set our own default values to overcome clock scan's
	    # settings. We do this by switching to a different pattern
	    # and extending the input properly for that pattern.

	    if {[dict exists $Repattern $interpretation]} {
		lassign [dict get $Repattern $interpretation] interpretation adjust modifier
		{*}$modifier
		# adjust irrelevant here, see parse_time for use.
	    }

	    #puts B|$string|\t|$regex|\t|$interpretation|
	    return [clock scan $string -format $interpretation {*}$args]
	}
    }
    return -code error "not an iso8601 date string"
}

# iso8601::parse_time --
#
#       Parse a point-in-time in ISO8601 format
#
# Parameters:
#       string -- String to parse
#       args -- Arguments as for [clock scan]; may include any of
#               the '-base', '-gmt', '-locale' or '-timezone options.
#
# Results:
#       Returns the given time in seconds from the Posix epoch.

proc ::clock::iso8601::parse_time { string args } {
    variable DatePatterns
    variable Repattern
    if {![MatchTime $string field]} {
	return -code error "not an iso8601 time string"
    }

    #parray field
    #puts A|$string|

    set pattern {}
    foreach {regex interpretation} $DatePatterns {
	if {[Has $interpretation tstart]} {
	    append pattern $interpretation
	}
    }

    if {[dict exists $Repattern $pattern]} {
	lassign [dict get $Repattern $pattern] interpretation adjust modifier
	{*}$modifier
	incr tstart $adjust
    }

    append pattern [Get T len]
    incr tstart $len

    if {[Has %H tstart]} {
	append pattern %H [Get Hcolon len]
	incr tstart $len

	if {[Has %M tstart]} {
	    append pattern %M [Get Mcolon len]
	    incr tstart $len

	    if {[Has %S tstart]} {
		append pattern %S
	    } else {
		# No seconds, default to start of minute.
		append pattern %S
		Insert string $tstart 00
	    }
	} else {
	    # No minutes, nor seconds, default to start of hour.
	    append pattern %M%S
	    Insert string $tstart 0000
	}
    } else {
	# No time information, default to midnight.
	append pattern %H%M%S
	Insert string $tstart 000000
    }
    if {[Has %Z _]} {
	append pattern %Z
    }

    #puts B|$string|\t|$pattern|
    return [clock scan $string -format $pattern {*}$args]
}

# # ## ### ##### ######## ############# #####################

proc ::clock::iso8601::Get {x lv} {
    upvar 1 field field string string $lv len
    lassign $field($x) s e
    if {($s >= 0) && ($e >= 0)} {
	set len [expr {$e - $s + 1}]
	return [string range $string $s $e]
    }
    set len 0
    return ""

}

proc ::clock::iso8601::Has {x nv} {
    upvar 1 field field string string $nv next
    lassign $field($x) s e
    if {($s >= 0) && ($e >= 0)} {
	set  next $e
	incr next
	return 1
    }
    return 0
}

proc ::clock::iso8601::Insert {sv index str} {
    upvar 1 $sv string
    append r [string range $string 0 ${index}-1]
    append r $str
    append r [string range $string $index end]
    set string $r
    return
}

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::clock::iso8601 {

    namespace export parse_date parse_time
    namespace ensemble create

    # Enumerate the patterns that we recognize for an ISO8601 date as both
    # the regexp patterns that match them and the [clock] patterns that scan
    # them.

    variable DatePatterns {
	{\d\d\d\d-\d\d-\d\d}            {%Y-%m-%d}
	{\d\d\d\d\d\d\d\d}              {%Y%m%d}
	{\d\d\d\d-\d\d\d}               {%Y-%j}
	{\d\d\d\d\d\d\d}                {%Y%j}
	{\d\d-\d\d-\d\d}                {%y-%m-%d}
	{\d\d\d\d-\d\d}                 {%Y-%m}
	{\d\d\d\d\d\d}                  {%y%m%d}
	{\d\d-\d\d\d}                   {%y-%j}
	{\d\d\d\d\d}                    {%y%j}
	{--\d\d-\d\d}                   {--%m-%d}
	{--\d\d\d\d}                    {--%m%d}
	{--\d\d\d}                      {--%j}
	{---\d\d}                       {---%d}
	{\d\d\d\d-W\d\d-\d}             {%G-W%V-%u}
	{\d\d\d\dW\d\d\d}               {%GW%V%u}
	{\d\d-W\d\d-\d}                 {%g-W%V-%u}
	{\d\dW\d\d\d}                   {%gW%V%u}
	{\d\d\d\d-W\d\d}                {%G-W%V}
	{\d\d\d\dW\d\d}                 {%GW%V}
	{-W\d\d-\d}                     {-W%V-%u}
	{-W\d\d\d}                      {-W%V%u}
	{-W-\d}                         {%u}
	{\d\d\d\d}                      {%Y}
    }

    # Dictionary of the patterns requiring modifications to the input
    # for proper month and/or day defaults.
    variable Repattern {
	%Y-%m  {%Y-%m-%d  3 {Insert string 7 -01}}
	%Y     {%Y-%m-%d  5 {Insert string 4 -01-01}}
	%G-W%V {%G-W%V-%u 1 {Insert string 8 -1}}
	%GW%V  {%GW%V%u   1 {Insert string 6 1}}
    }
}

# # ## ### ##### ######## ############# #####################
## Initialization

apply {{} {
    # MatchTime -- (constructed procedure)
    #
    #   Match an ISO8601 date/time string and indicate how it matched.
    #
    # Parameters:
    #   string -- String to match.
    #   fieldArray -- Name of an array in caller's scope that will receive
    #                 parsed fields of the time.
    #
    # Results:
    #   Returns 1 if the time was scanned successfully, 0 otherwise.
    #
    # Side effects:
    #   Initializes the field array.  The keys that are significant:
    #           - Any date pattern in 'DatePatterns' indicates that the
    #             corresponding value, if non-empty, contains a date string
    #             in the given format.
    #           - The patterns T, Hcolon, and Mcolon indicate a literal
    #             T preceding the time, a colon following the hour, or
    #             a colon following the minute.
    #           - %H, %M, %S, and %Z indicate the presence of the
    #             corresponding parts of the time.

    variable DatePatterns

    set cmd {regexp -indices -expanded -nocase -- {PATTERN} $timeString ->}
    set re \(?:\(?:
    set sep {}
    foreach {regex interpretation} $DatePatterns {
	append re $sep \( $regex \)
	append cmd " " [list field($interpretation)]
	set sep |
    }
    append re \) {(T|[[:space:]]+)} \)?
    append cmd { field(T)}
    append re {(\d\d)(?:(:?)(\d\d)(?:(:?)(\d\d)?))?}
    append cmd { field(%H) field(Hcolon) } {field(%M) field(Mcolon) field(%S)}
    append re {[[:space:]]*(Z|[-+]\d\d:?\d\d)?}
    append cmd { field(%Z)}
    set cmd [string map [list {{PATTERN}} [list $re]] \
		 $cmd]

    proc MatchTime { timeString fieldArray } "
             upvar 1 \$fieldArray field
             $cmd
         "

    #puts [info body MatchTime]

} ::clock::iso8601}

# # ## ### ##### ######## ############# #####################

return
# Usage examples, disabled.

if { [info exists ::argv0] && ( $::argv0 eq [info script] ) } {
    puts "::clock::iso8601::parse_date"
    puts [::clock::iso8601::parse_date 1970-01-02 -timezone :UTC]
    puts [::clock::iso8601::parse_date 1970-W01-5 -timezone :UTC]
    puts [time {::clock::iso8601::parse_date 1970-01-02 -timezone :UTC} 1000]
    puts [time {::clock::iso8601::parse_date 1970-W01-5 -timezone :UTC} 1000]
    puts "::clock::iso8601::parse_time"
    puts [clock format [::clock::iso8601::parse_time 2004-W33-2T18:52:24Z] \
	      -format {%X %x %z} -locale system]
    puts [clock format [::clock::iso8601::parse_time 18:52:24Z] \
	      -format {%X %x %z} -locale system]
    puts [time {::clock::iso8601::parse_time 2004-W33-2T18:52:24Z} 1000]
    puts [time {::clock::iso8601::parse_time 18:52:24Z} 1000]
}
