# -*- tcl -*-
# ### ### ### ######### ######### #########
##
# Transfer class built on top of the basic facilities. Accepts many
# transfer requests, any time, and executes them serially. Each
# request has its own progress and completion commands.
#
# Note: The output channel used is part of the queue, and not
#       contained in the transfer requests themselves. Otherwise
#       we would not need a queue and serialized execution.
#
# Instances also have a general callback to report the instance status
# (#pending transfer requests, busy).

# ### ### ### ######### ######### #########
## Requirements

package require transfer::copy ; # Basic transfer facilities
package require struct::queue  ; # Request queue
package require snit           ; # OO system
package require Tcl 8.4

namespace eval ::transfer::copy::queue {
    namespace import ::transfer::copy::options
    namespace import ::transfer::copy::doChan
    namespace import ::transfer::copy::doString
}

# ### ### ### ######### ######### #########
## Implementation

snit::type ::transfer::copy::queue {
    # ### ### ### ######### ######### #########
    ## API

    option -on-status-change {}

    constructor {thechan args} {}
    method put     {request} {}
    method busy    {} {}
    method pending {} {}

    # ### ### ### ######### ######### #########
    ## Implementation

    constructor {thechan args} {
	if {![llength [file channels $chan]]} {
	    return -code error "Channel \"$chan\" does not exist"
	}

	set chan  $thechan
	set queue [struct::queue ${selfns}::queue]
	set busy  0

	$self configurelist $args
	return
    }

    destructor {
	if {$queue eq ""} return
	$queue destroy
	return
    }

    method put {request} {
	# Request syntax: type dataref ?options?
	# Accepted options are those of 'transfer::transmit::copy',
	# etc.

	# We parse out the completion callback so that we can use it
	# directly. This also checks the request for basic validity.

	if {[llength $request] < 2} {
	    return -code error "Bad request: Not enough elements"
	}

	set type [lindex $request 0]
	switch -exact -- $type {
	    chan - string {}
	    default {
		return -code error "Bad request: Unknown type \"$type\", expected chan, or string"
	    }
	}

	set options [lrange $request 2 end]
	if {[catch {
	    options $chan $options opts
	} res]} {
	    return -code error "Bad request: $res"
	}

	set ref [lindex $request 1]

	# We store the fully parsed request. Later
	# we call lower-level copy functionality
	# which avoids a reparsing.

	$queue put [list $type $ref [array get opts]]

	# Start the engine executing transfers in the background, if
	# it is not already running.

	if {!$busy} {
	    after 0 [mymethod Transfer]
	}

	$self ReportStatus
	return
    }

    method busy {} {
	return $busy
    }

    method pending {} {
	return [$queue size]
    }

    # ### ### ### ######### ######### #########
    ## Internal helper commands

    method Transfer {} {
	# Get the next pending request. It is already fully-parsed.

	foreach {type ref o} [$queue get] break
	array set opts $o

	# Save the actual completion callback and redirect the
	# completion of the copy operation to ourselves for proper
	# management.

	set opts(-command) [mymethod \
		Done $opts(-command)]

	# Start the transfer. We catch this as it can fail immediately
	# (example: string-type copy and not enough data). We go
	# through 'Done' for the reporting of such errors to avoid
	# forgetting all the other management stuff (like the engine
	# forced to stop).

	set busy 1
	$self ReportStatus

	switch -exact -- $type {
	    chan {
		set code [catch {
		    doChan $ref $chan opts
		} res]
	    }
	    string {
		set code [catch {
		    doString $ref $chan opts
		} res]
	    }
	}

	if {$code} {
	    $self Done $command 0 $res
	}

	return
    }

    method Done {command args} {
	# args is either (n)
	#             or (n errormessage)

	# A transfer ending in an error causes the instance to stop
	# processing requests. I.e. all requests waiting after the
	# failed one are not executed anymore.

	if {[llength $args] == 2} {
	    set busy 0
	    $self ReportStatus
	    $self Notify $command $args
	    return
	}

	# Depending on the status of the queue of pending requests we
	# either trigger the start of the next transfer, or stop the
	# engine. The completion of the current transfer however is
	# unconditionally reported through its completion callback.

	if {[$queue size]} {
	    after 0 [mymethod Transfer]
	} else {
	    set busy 0
	    $self ReportStatus
	}

	$self Notify $command $args
	return
    }

    method ReportStatus {} {
	if {![llength $options(-on-status-change)]} return
	uplevel #0 [linsert $options(-on-status-change) end $self [$queue size] $busy]
	return
    }

    method Notify {cmd alist} {
	foreach a $args {lappend cmd $a}
	uplevel #0 $cmd
    }

    # ### ### ### ######### ######### #########
    ## Data structures
    ## - Channel the transfered data is written to
    ## - Queue of pending requests.

    variable chan  {}
    variable queue {}
    variable busy  0

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide transfer::copy::queue 0.1

