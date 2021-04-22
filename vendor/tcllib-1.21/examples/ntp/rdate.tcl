#!/usr/bin/env tclsh
## -*- tcl -*-

# rdate.tcl - Copyright (C) 2003 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# This is a sample implementation of the rdate(8) utility written using the
# tcllib ntp time package.
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------
#
# $Id: rdate.tcl,v 1.4 2009/01/30 04:18:14 andreas_kupries Exp $

package require time;                   # tcllib 1.4

proc usage {} {
    set s {usage: rdate [-psa] [-utS] host
  -p    Do not set, just print the remote time.
  -s    Do not print the time. [NOT IMPLEMENTED]
  -a    Use the adjtime(2) call to gradually skew the local time to the
        remote time instead of just jumping. [NOT IMPLEMENTED]
  -u    Use UDP (default if available)
  -t    Use TCP
  -S    Use SNTP protocol (RFC 2030) (default is TIME, RFC 868)
}
    return $s
}

proc Error {message} {
    puts stderr $message
    exit 1
}

proc rdate {args} {
    # process the command line options.
    array set opts {-p 0 -s 0 -a 0 -t 0 -u x -S 0}
    while {[string match -* [set option [lindex $args 0]]]} {
        switch -exact -- $option {
            -p { set opts(-p) 1 }
            -u { set opts(-t) 0 }
            -t { set opts(-t) 1 }
            -s { Error "not implemented: use rdate(8)" }
            -a { Error "not implemented: use rdate(8)" }
            -S { set opts(-S) 1 }
            -T { set opts(-S) 0 }
            -- { ::time::Pop args; break }
            default {
                set err [join [lsort [array names opts -*]] ", "]
                Error "bad option $option: must be $err"
            }
        }
        ::time::Pop args
    }

    # Check that we have a host to talk to.
    if {[llength $args] != 1} {
        Error [usage]
    }
    set host [lindex $args 0]

    # Construct the time command - optionally force the protocol to tcp
    set cmd ::time::gettime
    if {$opts(-S)} {
        set cmd ::time::getsntp
    }
    if {$opts(-t)} {
        lappend cmd -protocol tcp
    }
    lappend cmd $host

    # Perform the RFC 868 query (synchronously)
    set tok [eval $cmd]

    # Check for errors or extract the time in the unix epoch.
    set t 0
    if {[::time::status $tok] == "ok"} {
        set t [::time::unixtime $tok]
        ::time::cleanup $tok
    } else {
        set msg [::time::error $tok]
        ::time::cleanup $tok
        Error $msg 
    }

    # Display the time.
    if {$opts(-p)} {
        puts [clock format $t]
    }

    return 0
}

if {! $tcl_interactive} {
    eval rdate $argv
}

