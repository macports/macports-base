#! /usr/bin/env tclsh
# -*- tcl -*-

# @@ Meta Begin
# Application nnslog 1.1
# Meta platform     tcl
# Meta summary      Nano Name Service Logger
# Meta description  This application connects to a name service demon
# Meta description  and then continuously logs all changes (new/removed
# Meta description  definitions) to the standard output. It will survive
# Meta description  the loss of the nameserver and automatically reconnect
# Meta description  and continue when it comes back.
# Meta subject      {name service} client log
# Meta require      {Tcl 8.4}
# Meta require      logger
# Meta require      nameserv::auto
# Meta author       Andreas Kupries
# Meta license      BSD
# @@ Meta End

package provide nnslog 1.0

# nns - Nano Name Service Logger
# === = ========================
#
# Use cases
# ---------
# 
# (1)	Continuously monitor a nameservice for changes.
#
# Command syntax
# --------------
#
# (Ad 1) nnslog ?-host NAME|IP? ?-port PORT? ?-color BOOL?
#
#       Monitor a name server. If no port is specified the default
# 	port 38573 is used to connect to it. If no host is specified
# 	the default (localhost) is used to connect to it.

# ### ### ### ######### ######### #########
## Requirements

lappend auto_path [file join [file dirname [file dirname \
			[file normalize [info script]]]] modules]

package require nameserv::auto 0.3 ;# Need auto-restoring search.

logger::initNamespace ::nnslog
namespace eval        ::nnslog { log::setlevel info }

# ### ### ### ######### ######### #########
## Process application command line

proc ::nnslog::ProcessCommandLine {} {
    global argv

    # Process the options, perform basic validation.
    set xcolor 0

    if {[llength $argv] < 1} return

    while {[llength $argv]} {
	set opt [lindex $argv 0]
	if {![string match "-*" $opt]} break

	switch -exact -- $opt {
	    -host {
		if {[llength $argv] < 2} Usage

		set host [lindex $argv 1]
		set argv [lrange $argv 2 end]

		nameserv::configure -host $host
	    }
	    -port {
		if {[llength $argv] < 2} Usage

		# Todo: Check non-zero unsigned short integer
		set port [lindex $argv 1]
		set argv [lrange $argv 2 end]

		nameserv::configure -port $port
	    }
	    -debug {
		# Undocumented. Activate the logger services provided
		# by various packages.
		logger::setlevel debug
		set argv [lrange $argv 1 end]
	    }
	    default Usage
	}
    }

    # Additional validation. no arguments should be left over.
    if {[llength $argv] > 1} Usage
    return
}

proc ::nnslog::Usage {{sfx {}}} {
    global argv0 ; append argv0 $sfx
    puts stderr "$argv0 wrong#args, expected: ?-host NAME|IP? ?-port PORT?"
    exit 1
}

proc ::nnslog::ArgError {text} {
    global argv0
    puts stderr "$argv0: $text"
    #puts $::errorInfo
    exit 1
}

# ### ### ### ######### ######### #########
## Setup a text|graphical report

proc ::nnslog::My {} {
    # Quick access to format the identity of the name service the
    # client talks to.
    return "[nameserv::auto::cget -host] @[nameserv::auto::cget -port]"
}

proc ::nnslog::Connection {message args} {
    # args = tag event details, ignored
    log::info $message
    return
}

proc ::nnslog::MonitorConnection {} {
    uevent::bind nameserv lost-connection [list ::nnslog::Connection "Disconnected name service at [My]"]
    uevent::bind nameserv re-connection   [list ::nnslog::Connection "Reconnected2 name service at [My]"]
    return
}

# ### ### ### ######### ######### #########
## Main

proc ::nnslog::Do.search {} {
    MonitorConnection
    set contents [nameserv::auto::search -continuous *]
    $contents configure -command [list ::nnslog::Do.search.change $contents]

    log::info "Logging      name service at [My]"
    vwait ::forever
    # Not reached.
    return
}

namespace eval ::nnslog {
    variable  map
    array set map {
	add    +++
	remove ---
    }
}

proc ::nnslog::Do.search.change {res type response} {
    variable map

    if {$type eq "stop"} {
	# Cannot happen for nameserv::auto client, we are free to panic.
	$res destroy
	log::critical {Bad event 'stop' <=> Lost connection, search closed}
	return
    }
    # Print events ...
    foreach {name value} $response {
	log::info "$map($type) : [list $name = $value]"
    }
    return
}

# ### ### ### ######### ######### #########
## Invoking the functionality.

::nnslog::ProcessCommandLine
if {[catch {
    ::nnslog::Do.search
} msg]} {
    ::nnslog::ArgError $msg
}

# ### ### ### ######### ######### #########
exit
