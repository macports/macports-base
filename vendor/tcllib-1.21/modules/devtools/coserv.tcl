# -*- tcl -*-
# CoServ - Comm Server
# Copyright (c) 2004, Andreas Kupries <andreas_kupries@users.sourceforge.net>

# ### ### ### ######### ######### #########
## Commands to create server processes ready to talk to their parent
## via 'comm'. They assume that the 'tcltest' environment is present
## without having to load it explicitly. We do load 'comm' explicitly.

## Can assume that tcltest is present, and its commands imported into
## the global namespace.

# ### ### ### ######### ######### #########
## Load "comm" into the master.

namespace eval ::coserv {variable subcode {}}

package forget comm
catch {namespace delete comm}

if {[package vsatisfies [package present Tcl] 8.5]} {
    set ::coserv::snitsrc [file join [file dirname [file dirname [info script]]] snit snit2.tcl]
} else {
    set ::coserv::snitsrc [file join [file dirname [file dirname [info script]]] snit snit.tcl]
}
set ::coserv::commsrc [file join [file dirname [file dirname [info script]]] comm comm.tcl]

if {[catch {source $::coserv::snitsrc} msg]} {
    puts "Error loading \"snit\": $msg"
    error ""
}
if {[catch {source $::coserv::commsrc} msg]} {
    puts "Error loading \"comm\": $msg"
    error ""
}

package require comm

puts "- coserv (comm server)"
#puts "Main       @ [::comm::comm self]"

# ### ### ### ######### ######### #########
## Core of all sub processes.

proc ::coserv::setup {} {
    variable subcode
    if {$subcode != {}} return
    set subcode [::tcltest::makeFile {
	#puts "Subshell is \"[info nameofexecutable]\""
	catch {wm withdraw .}

	# ### ### ### ######### ######### #########
	## Get main configuration data out of the command line, i.e.
	## - Id of the main process for sending information back.
	## - Path to the sources of comm.

	foreach {snitsrc commsrc main cookie} $argv break

	# ### ### ### ######### ######### #########
	## Load and initialize "comm" in the sub process. The latter
	## includes a report to main that we are ready.

	source $snitsrc
	source $commsrc
	::comm::comm send $main [list ::coserv::ready $cookie [::comm::comm self]]

	# ### ### ### ######### ######### #########
	## Now wait for scripts sent by main for execution in sub.

	#comm::comm debug 1
	vwait forever

	# ### ### ### ######### ######### #########
	exit
    } coserv.sub] ; # {}
    return
}

# ### ### ### ######### ######### #########
## Command used by sub processes to signal that they are ready.

proc ::coserv::ready {cookie id} {
    #puts "Sub server @ $id\t\[$cookie\]"
    set ::coserv::go $id
    return
}

# ### ### ### ######### ######### #########
## Start a new sub server process, talk to it.

proc ::coserv::start {cookie} {
    variable subcode
    variable snitsrc
    variable commsrc
    variable go

    set go {}

    setup
    exec [info nameofexecutable] $subcode \
	    $snitsrc $commsrc [::comm::comm self] $cookie &

    #puts "Waiting for sub server to boot"
    vwait ::coserv::go

    # We return the id of the server
    return $::coserv::go
}

proc ::coserv::run {id script} {
    return [comm::comm send $id $script]
}

proc ::coserv::task {id script} {
    comm::comm send -async $id $script
    return
}

proc ::coserv::shutdown {id} {
    variable subcode
    #puts "Sub server @ $id\tShutting down ..."
    task $id exit
    tcltest::removeFile $subcode
    set subcode {}
    return
}

# ### ### ### ######### ######### #########
