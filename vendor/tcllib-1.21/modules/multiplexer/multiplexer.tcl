# multiplexer.tcl -- one-to-many comunication with sockets
#
#	Implementation of a one-to-many multiplexer in Tcl utilizing
#	sockets.

# Copyright (c) 2001-2003 by David N. Welton <davidw@dedasys.com>

# This file may be distributed under the same terms as Tcl.

# $Id: multiplexer.tcl,v 1.4 2004/01/15 06:36:13 andreas_kupries Exp $

package provide multiplexer 0.2
package require logger

namespace eval ::multiplexer {
    variable Unique 0
}

proc ::multiplexer::create {} {
    variable Unique
    set ns ::multiplexer::mp$Unique

    namespace eval $ns {
	# Use the namespace as the logger name.
	set log [logger::init [string trimleft [namespace current] ::]]
	# list of connected clients
	array set clients {}

	# filters to run at access (socket accept) time
	set accessfilters {}

	# filters to run on data
	set filters {}

	# hook to run at exit time
	set exitfilters {}

	# config options
	array set config {}
	set config(sendtoorigin) 0
	set config(debuglevel) warn
	${log}::disable $config(debuglevel)
	${log}::enable $config(debuglevel)

	# AddAccessFilter --
	#
	# Command to add an access filter that will be called like so:
	#
	# AccessFilter chan clientaddress clientport
	#
	# Arguments:
	#
	# function: proc to filter access to the multiplexer.  Takes chan,
	# clientaddress and clientport arguments.  Returns 0 on success, -1 on
	# failure.

	proc AddAccessFilter { function } {
	    variable accessfilters
	    lappend accessfilters $function
	}

	# AddFilter --

	# Command to add a filter for data that passes through the
	# multiplexer.  The filter proc is called like this:

	# Filter data chan clientaddress clientport

	# Arguments:

	# function: proc to filter data that arrives to the
	# multiplexer.
	# Takes data, chan, clientaddress, and clientport arguments.  Returns
	# filtered version of data.

	proc AddFilter { function } {
	    variable filters
	    lappend filters $function
	}

	# AddExitFilter --

	# Adds filter to be run when client socket generates an EOF condition.
	# ExitFilter functions look like the following:

	# ExitFilter chan clientaddress clientport

	# Arguments:

	# function: hook to be run when clients exit by generating an EOF.
	# Takes chan, clientaddress and clientport arguments, and returns
	# nothing.

	proc AddExitFilter { function } {
	    variable exitfilters
	    lappend exitfilters $function
	}

	# DelClient --

	# Deletes a client from the client list, and runs exit filters.

	# Arguments:

	# chan: channel that is closed.

	# client: address of client

	# clientport: port number of client.

	proc DelClient { chan client clientport } {
	    variable clients
	    variable exitfilters
	    variable config
	    variable log
	    foreach ef $exitfilters {
		catch {
		    $ef $chan $client $clientport
		} err
		${log}::debug "Error in DelClient: $err"
	    }
	    unset clients($chan)
	    close $chan
	}


	# MultiPlex --

	# Multiplex data

	# Arguments:

	# data - data to multiplex

	proc MultiPlex { data {chan ""} } {
	    variable clients
	    variable config
	    variable log

	    foreach c [array names clients] {
		if { $config(sendtoorigin) } {
		    puts -nonewline $c "$data"
		} else {
		    if { $chan != $c } {
			${log}::debug "Sending '$data' to $c"
			puts -nonewline $c "$data"
		    }
		}
	    }
	}


	# GetData --

	# Get data from clients, filter it, redistribute it.

	# Arguments:

	# chan: open channel

	# client: client address

	# clientport: port number of client

	proc GetData { chan client clientport } {
	    variable filters
	    variable clients
	    variable config
	    variable log
	    if { ! [eof $chan] } {
		set data [read $chan]
	#	gets $chan data
		${log}::debug "Tcl chan $chan from host $client and port $clientport sends: $data"
		# do data filters
		foreach f $filters {
		    catch {
			set data [$f $data $chan $client $clientport]
		    } err
		    ${log}::debug "GetData filter: $err"
		}
		set chans [array names clients]
		MultiPlex $data $chan
	    } else {
		${log}::debug "Deleting client $chan from host $client and port $clientport."
		DelClient $chan $client $clientport
	    }
	}

	# NewClient --

	# Sets up newly created connection after running access filters

	# Arguments:

	# chan: open channel

	# client: client address

	# clientport: port number of client

	proc NewClient { chan client clientport } {
	    variable clients
	    variable config
	    variable accessfilters
	    variable log
	    # run through access filters
	    foreach af $accessfilters {
		if { [$af $chan $client $clientport] == -1 } {
		    ${log}::debug "Access denied to $chan $client $clientport"
		    close $chan
		    return
		}
	    }
	    set clients($chan) $client

	    # We want to read data and immediately send it out again.
	    fconfigure $chan -blocking 0
	    fconfigure $chan -buffering none
	    fconfigure $chan -translation binary
	    fileevent $chan readable [list [namespace current]::GetData $chan $client $clientport]
	    ${log}::debug "Tcl channel $chan is host $client and port $clientport."
	}

	# Config --
	#
	# Configure global options, which currently include the
	# following:
	#
	# sendtoorigin: if 1, resend the data to all clients, including the
	# sender.  Defaults to 0
	#
	# debuglevel: a debug level understood by logger.
	#
	# Arguments:
	#
	# key: name of option to configure
	#
	# value: value for option.

	proc Config { key value } {
	    variable config
	    variable log
	    if { $key == "debuglevel" } {
		${log}::disable $config(debuglevel)
		${log}::enable $value
	    }
	    set config($key) $value
	}

	# Init --
	#
	# Start the server
	#
	# Arguments:
	#
	# port: port to listen on.

	proc Init { port } {
	    variable serversock
	    set serversock [socket -server [namespace current]::NewClient $port]
	}

	# destroy --
	#
	#	Destroy multiplexer instance.  It is important to do
	#	this, to free the resources used.
	#
	# Side Effects:
	#	Deletes namespace associated with multiplexer
	#	instance.


	proc destroy { } {
	    variable serversock
	    foreach c [array names clients] {
	        catch { close $c }
	    }
	    catch {
		close $serversock
	    }
	    namespace delete [namespace current]
	}

    }
    incr Unique
    return $ns
}

namespace eval multiplexer {
    namespace export create destroy
}
