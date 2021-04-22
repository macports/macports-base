#! /usr/bin/env tclsh
# -*- tcl -*-

# @@ Meta Begin
# Application nnsd 1.0.1
# Meta platform     tcl
# Meta summary      Nano Name Service Demon
# Meta description  This application is a simple demon on top
# Meta description  of the nano name service facilities
# Meta subject      {name service} server demon
# Meta require      {Tcl 8.4}
# Meta require      comm
# Meta require      logger
# Meta require      interp
# Meta require      nameserv::common
# Meta require      nameserv::server
# Meta author       Andreas Kupries
# Meta license      BSD
# @@ Meta End

package provide nnsd 1.0.1

# nnsd - Nano Name Service Demon
# ==== = =======================
#
# Use cases
# ---------
# 
# (1)	Run a simple trusted name service on some host.
#	
# Command syntax
# --------------
#
# Ad 1) nnsd ?-localonly BOOL? ?-port PORT?
#
#       Run the server. If no port is specified the default port 38573
#       is used to listen for client. The option -localonly determines
#       what connections are acceptable, local only (default), or
#       remote connections as well. Local connections are whose
#       originating from the same host which is running the server.
#       Remote connections come from other hosts.

lappend auto_path [file join [file dirname [file dirname [file normalize [info script]]]] modules]

package require nameserv::server

namespace eval ::nnsd {}

proc ::nnsd::ProcessCommandLine {} {
    global argv

    # Process the options, perform basic validation.

    while {[llength $argv]} {
	set opt [lindex $argv 0]
	if {![string match "-*" $opt]} break

	switch -exact -- $opt {
	    -localonly {
		if {[llength $argv] % 2 == 1} Usage

		# Todo: Check boolean 
		set local [lindex $argv 1]
		set argv [lrange $argv 2 end]

		nameserv::server::configure -localonly $local
	    }
	    -port {
		if {[llength $argv] % 2 == 1} Usage

		# Todo: Check non-zero unsigned short integer
		set port [lindex $argv 1]
		set argv [lrange $argv 2 end]

		nameserv::server::configure -port $port
	    }
	    -debug {
		# Undocumented. Activate the logger services provided
		# by various packages.
		logger::setlevel debug
		set argv [lrange $argv 1 end]
	    }
	    default {
		Usage
	    }
	}
    }

    # Additional validation, and extraction of the non-option
    # arguments. Of which this application has none.

    if {[llength $argv]} Usage

    return
}

proc ::nnsd::Usage {} {
    global argv0
    puts stderr "$argv0 wrong#args, expected:\
	    ?-localonly BOOL? ?-port PORT?"
    exit 1
}

proc ::nnsd::ArgError {text} {
    global argv0
    puts stderr "$argv0: $text"
    exit 1
}

proc bgerror {args} {
    puts stderr $args
    puts stderr $::errorInfo
    return
}

# ### ### ### ######### ######### #########
## Main

proc ::nnsd::Headline {} {
    global argv0 
    set p        [nameserv::server::cget -port]
    set l [expr {[nameserv::server::cget -localonly]
		 ? "local only"
		 : "local & remote"}]

    puts "$argv0 [package require nnsd], listening on $p ($l)"
    return
}

proc ::nnsd::Do {} {
    global argv0 

    ProcessCommandLine

    nameserv::server::start
    Headline

    vwait forever
    return
}

# ### ### ### ######### ######### #########
## Invoking the functionality.

if {[catch {
    ::nnsd::Do
} msg]} {
    puts $::errorInfo
    #::nnsd::ArgError $msg
}

# ### ### ### ######### ######### #########
exit
