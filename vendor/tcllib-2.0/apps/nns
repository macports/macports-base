#! /usr/bin/env tclsh
# -*- tcl -*-

# @@ Meta Begin
# Application nns 1.2
# Meta platform     tcl
# Meta summary      Nano Name Service Client
# Meta description  This application connects to a name service demon
# Meta description  and either registers a name with associated data
# Meta description  (until exit) or searches for entries matching a
# Meta description  glob pattern. Operations to identify client and
# Meta description  server are made available as well. It will survive
# Meta description  the loss of the nameserver and automatically reconnect
# Meta description  and continue when it comes back (bind and search).
# Meta description  
# Meta subject      {name service} client
# Meta require      {Tcl 8.4}
# Meta require      logger
# Meta require      nameserv::auto
# Meta require      struct::matrix
# Meta author       Andreas Kupries
# Meta license      BSD
# @@ Meta End

package provide nns 1.2

# nns - Nano Name Service Client
# === = ========================
#
# Use cases
# ---------
# 
# (1)	Register something at a nano name service
# (2)   Query protocol and feature information.
# (3)   Provide application version, and protocol information
# (4)   Search service for entries matching a glob-pattern
#	
# Command syntax
# --------------
#
# (Ad 1) nns bind  ?-host NAME|IP? ?-port PORT? name data
# (Ad 2) nns ident ?-host NAME|IP? ?-port PORT?
# (Ad 3) nns who
# (Ad 4) nns search ?-host NAME|IP? ?-port PORT? ?-continuous? ?pattern?
#
#       Register a name with data. If no port is specified the default
# 	port 38573 is used to connect to it. If no host is specified
# 	the default (localhost) is used to connect to it.

# ### ### ### ######### ######### #########
## Requirements

lappend auto_path [file join [file dirname [file dirname \
			[file normalize [info script]]]] modules]

package require nameserv::auto 0.3 ;# Need auto-restoring search.
package require struct::matrix

logger::initNamespace ::nns
namespace eval        ::nns { log::setlevel info }

# ### ### ### ######### ######### #########
## Process application command line

proc ::nns::ProcessCommandLine {} {
    global argv
    variable xcmd
    variable xname
    variable xdata
    variable xpat   *
    variable xwatch 0

    # Process the options, perform basic validation.

    if {[llength $argv] < 1} Usage

    set cmd  [lindex $argv 0]
    set argv [lrange $argv 1 end]

    switch -exact -- $cmd {
	bind - ident - who - search {set xcmd $cmd}
	default Usage
    }

    while {[llength $argv]} {
	set opt [lindex $argv 0]
	if {![string match "-*" $opt]} break

	switch -exact -- $opt {
	    -host {
		if {$xcmd == "who"} Usage
		if {[llength $argv] < 2} Usage

		set host [lindex $argv 1]
		set argv [lrange $argv 2 end]

		nameserv::auto::configure -host $host
	    }
	    -port {
		if {$xcmd == "who"} Usage
		if {[llength $argv] < 2} Usage

		# Todo: Check non-zero unsigned short integer
		set port [lindex $argv 1]
		set argv [lrange $argv 2 end]

		nameserv::auto::configure -port $port
	    }
	    -continuous {
		set xwatch 1
		set argv [lrange $argv 1 end]
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

    # Additional validation, and extraction of the non-option
    # arguments. Of which this application has none.

    switch -exact -- $xcmd {
	bind {
	    if {[llength $argv] != 2} Usage
	    foreach {xname xdata} $argv break
	}
	search {
	    if {[llength $argv] > 1} Usage
	    if {[llength $argv] == 1} {
		set xpat [lindex $argv 0]
	    }
	}
	who - ident {
	    if {[llength $argv] != 0} Usage
	}
    }
    return
}

proc ::nns::Usage {{sfx {}}} {
    global argv0 ; append argv0 $sfx
    set    blank [blank $argv0]
    puts stderr "$argv0 wrong#args, expected: bind   ?-host NAME|IP? ?-port PORT? NAME DATA"
    puts stderr "$blank                       ident  ?-host NAME|IP? ?-port PORT?"
    puts stderr "$blank                       search ?-host NAME|IP? ?-port PORT? ?-continuous? ?PATTERN?"
    puts stderr "$blank                       who"
    exit 1
}

proc ::nns::ArgError {text} {
    global argv0
    puts stderr "$argv0: $text"
    #puts $::errorInfo
    exit 1
}

proc ::nns::blank {s} {
    regsub -all -- {[^	]} $s { } s
    return $s
}

# ### ### ### ######### ######### #########

proc ::nns::My {} {
    # Quick access to format the identity of the name service the
    # client talks to.
    return "[nameserv::auto::cget -host] @[nameserv::auto::cget -port]"
}

proc ::nns::Connection {message args} {
    # args = tag event details, ignored
    log::info $message
    return
}

proc ::nns::MonitorConnection {} {
    uevent::bind nameserv lost-connection [list ::nns::Connection "Disconnected name service at [My]"]
    uevent::bind nameserv re-connection   [list ::nns::Connection "Reconnected2 name service at [My]"]
    return
}

# ### ### ### ######### ######### #########
## Main

proc ::nns::Do.bind {} {
    global argv0
    variable xname
    variable xdata

    MonitorConnection
    log::info "Binding with name service at [My]: $xname = $xdata"
    nameserv::auto::bind $xname $xdata

    vwait ::forever
    # Not reached.
    return
}

proc ::nns::Do.ident {} {
    set sp [nameserv::auto::server_protocol]
    set sf [join [nameserv::auto::server_features] {, }]

    if {[llength $sf] > 1} {
	set sf [linsert $sf end-1 and]
    }

    puts "Server [My]"
    puts "  Protocol: $sp"
    puts "  Features: $sf"
    return
}

proc ::nns::Do.search {} {
    variable xpat
    variable xwatch

    struct::matrix M
    M add columns 2

    if {$xwatch} {
	MonitorConnection
	set contents [nameserv::auto::search -continuous $xpat]
	$contents configure -command [list ::nns::Do.search.change $contents]

	vwait ::forever
	# Not reached.
    } else {
	Do.search.print [nameserv::auto::search $xpat]
    }
    return
}

proc ::nns::Do.search.change {res type response} {
    # Ignoring the arguments, we simply print the full results every
    # time.

    if {$type eq "stop"} {
	# Cannot happen for nameserv::auto client, we are free to panic.
	$res destroy
	log::critical {Bad event 'stop' <=> Lost connection, search closed}
	return
    }

    # Clear screen ...
    puts -nonewline stdout "\033\[H\033\[J"; # Home + Erase Down
    flush           stdout

    ::nns::Do.search.print [$res getall]
    return
}

proc ::nns::Do.search.print {contents} {
    log::info "Searching at name service at [My]"

    if {![llength $contents]} {
	log info "Nothing found..."
	return
    }

    catch {M delete rows [M rows]}
    foreach {name data} $contents {
	M add row [list $name $data]
    }

    foreach line [split [M format 2string] \n] { log::info $line }
    return
}

proc ::nns::Do.who {} {
    # FUTURE: access and print the metadata contained in ourselves.
    global argv0
    puts "$argv0 [package require nns] (Client Protocol [nameserv::auto::protocol])"
    return
}

# ### ### ### ######### ######### #########
## Invoking the functionality.

::nns::ProcessCommandLine
if {[catch {
    ::nns::Do.$::nns::xcmd
} msg]} {
    ::nns::ArgError $msg
}

# ### ### ### ######### ######### #########
exit
