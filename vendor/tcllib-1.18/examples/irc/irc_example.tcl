#!/usr/bin/env tclsh
## -*- tcl -*-

# irc example script, by David N. Welton <davidw@dedasys.com>
# $Id: irc_example.tcl,v 1.10 2009/01/30 04:18:14 andreas_kupries Exp $

set scriptDir [file dirname [info script]]
package require irc 0.4

namespace eval ircclient {
    variable channel \#tcl

    # Pick up a nick from the command line, or default to TclIrc.
    if { [lindex $::argv 0] != "" } {
	set nick [lindex $::argv 0]
    } else {
	set nick TclIrc
    }

    set cn [::irc::connection]
    # Connect to the server.
    $cn connect irc.freenode.net 6667
    $cn user $nick localhost domain "www.tcl.tk"
    $cn nick $nick
    while { 1 } {
	source [file join $::scriptDir mainloop.tcl]
	vwait ::ircclient::RELOAD
    }
}

