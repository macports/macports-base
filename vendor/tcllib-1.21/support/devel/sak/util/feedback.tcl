# -*- tcl -*-
# (C) 2008 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

# Feedback modes
#
# [short]   Animated short feedback on stdout, no logging
# [log]     Animated short feedback on stdout, logging to multiple files.
# [verbose] Logging to stdout
#
# Output commands for various destinations:
#
# <v> Verbose Log
# <s> Short Log
#
# Handling of the destinations per mode
#
#           <s>        <v>
# [short]   stdout,    /dev/null
# [log]     stdout,    file
# [verbose] /dev/null, stdout

# Log files for different things are opened on demand, i.e. on the
# first write to them. We can configure (per possible log) a string to
# be written before the first write. Reconfiguring that string for a
# log clears the flag for that log and causes the string to be
# rewritten on the next write.

package require sak::animate

namespace eval ::sak::feedback {
    namespace import ::sak::animate::next ; rename next aNext
    namespace import ::sak::animate::last ; rename last aLast
}

# ###

proc ::sak::feedback::init {mode stem} {
    variable  prefix  ""
    variable  short   [expr {$mode ne "verbose"}]
    variable  verbose [expr {$mode ne "short"}]
    variable  tofile  [expr {$mode eq "log"}]
    variable  lstem   $stem
    variable  dst     ""
    variable  lfirst
    unset     lfirst
    array set lfirst {}
    # Note: lchan is _not_ reset. We keep channels, allowing us to
    #       merge output from different modules, if they are run as
    #       one unit (Example: validate and its various parts, which
    #       can be run separately, and together).
    return
}

proc ::sak::feedback::first {dst string} {
    variable lfirst
    set lfirst($dst) $string
    return
}

###

proc ::sak::feedback::summary {text} {
    #=|  $text
    #log $text

    variable short
    variable verbose
    if {$short}   { puts                $text }
    if {$verbose} { puts [_channel log] $text }
    return
}


proc ::sak::feedback::log {text {ext log}} {
    variable verbose
    if {!$verbose} return
    set    c [_channel $ext]
    puts  $c $text
    flush $c
    return
}

###

proc ::sak::feedback::! {} {
    variable short
    if {!$short} return
    variable prefix ""
    sak::animate::init
    return
}

proc ::sak::feedback::+= {string} {
    variable short
    if {!$short} return
    variable prefix
    append   prefix " " $string
    aNext               $prefix
    return
}

proc ::sak::feedback::= {string} {
    variable short
    if {!$short} return
    variable prefix
    aNext  "$prefix $string"
    return
}

proc ::sak::feedback::=| {string} {
    variable short
    if {!$short} return

    variable prefix
    aLast  "$prefix $string"

    variable verbose
    if {$verbose} {
	variable dst
	if {[string length $dst]} {
	    # inlined 'log'
	    set    c [_channel $dst]
	    puts  $c "$prefix $string"
	    flush $c
	    set dst ""
	}
    }

    set prefix ""
    return
}

proc ::sak::feedback::>> {string} {
    variable dst $string
    return
}

# ###

proc ::sak::feedback::_channel {dst} {
    variable tofile
    if {!$tofile} { return stdout }
    variable lchan
    if {[info exists lchan($dst)]} {
	set c $lchan($dst)
    } else {
	variable lstem
	set c [open ${lstem}.$dst w]
	set lchan($dst) $c
    }
    variable lfirst
    if {[info exists lfirst($dst)]} {
	puts $c $lfirst($dst)
	unset lfirst($dst)
    }
    return $c
}

# ###

namespace eval ::sak::feedback {
    namespace export >> ! += = =| init log summary

    variable  dst      ""
    variable  prefix   ""
    variable  short    ""
    variable  verbose  ""
    variable  tofile   ""
    variable  lstem    ""
    variable  lchan
    array set lchan {}

    variable  lfirst
    array set lfirst {}
}

##
# ###

package provide sak::feedback 1.0
