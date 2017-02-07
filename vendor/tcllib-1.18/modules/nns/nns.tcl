# -*- tcl -*-
# ### ### ### ######### ######### #########
## Name Service - Client side access

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.4
package require comm             ; # Generic message transport
package require interp           ; # Interpreter helpers.
package require logger           ; # Tracing internal activity
package require nameserv::common ; # Common/shared utilities
package require snit             ; # OO support, for streaming search class
package require uevent           ; # Generate events for connection-loss

namespace eval ::nameserv {}

# ### ### ### ######### ######### #########
## API: Write, Read, Search

proc ::nameserv::bind {name data} {
    # Registers this application at the configured name service under
    # the specified name, and provides a value.
    #
    # Note: The application is allowed register multiple names.
    #
    # Note: A registered name is automatically removed by the server
    #       when the connection to it collapses.

    DO Bind $name $data
    return
}

proc ::nameserv::release {} {
    # Releases all names the application has registered at the
    # configured name service.

    DO Release
    return
}

proc ::nameserv::search {args} {
    # Searches the configured name service for applications whose name
    # matches the given pattern. Returns a dictionary mapping from the
    # names to the data they provided at 'bind' time.

    # In continuous and async modes it returns an object whose
    # contents reflect the current set of matching entries.

    array set a [search-parseargs $args]
    upvar 0 a(oneshot)    oneshot
    upvar 0 a(continuous) continuous
    upvar 0 a(pattern)    pattern

    if {$continuous} {
	variable search
	# This client uses the receiver object as tag for the search
	# in the service. This is easily unique, and makes dispatch of
	# incoming results later easy too.

	set receiver [receiver %AUTO% $oneshot]
	if {[catch {
	    ASYNC Search/Continuous/Start $receiver $pattern
	} err]} {
	    # Release the allocated object to prevent a leak, then
	    # rethrow the error.
	    $receiver destroy
	    return -code error $err
	}

	set search($receiver) .
	return $receiver
    } else {
	return [DO Search $pattern]
    }
}

proc ::nameserv::protocol {} {
    return 1
}

proc ::nameserv::server_protocol {} {
    return [DO ProtocolVersion]
}

proc ::nameserv::server_features {} {
    return [DO ProtocolFeatures]
}

# ### ### ### ######### ######### #########
## semi-INT: search argument processing.

proc ::nameserv::search-parseargs {arguments} {
    # This command is semi-public. It is not documented for public
    # use, however the package nameserv::auto uses as helper in its
    # implementation of the search command.

    switch -exact [llength $arguments] {
	0 {
	    set oneshot    0
	    set continuous 0
	    set pattern    *
	}
	1 {
	    set opt [lindex $arguments 0]
	    if {$opt eq "-continuous"} {
		set oneshot    0
		set continuous 1
		set pattern    *
	    } elseif {$opt eq "-async"} {
		set oneshot    1
		set continuous 1
		set pattern    *
	    } else {
		set oneshot    0
		set continuous 0
		set pattern    $opt
	    }
	}
	2 {
	    set opt [lindex $arguments 0]
	    if {$opt eq "-continuous"} {
		set oneshot    0
		set continuous 1
		set pattern    [lindex $arguments 1]
	    } elseif {$opt eq "-async"} {
		set oneshot    1
		set continuous 1
		set pattern    [lindex $arguments 1]
	    } else {
		return -code error "wrong\#args: Expected ?-continuous|-async? ?pattern?"
	    }
	}
	default {
	    return -code error "wrong\#args: Expected ?-continuous|-async? ?pattern?"
	}
    }

    return [list oneshot $oneshot continuous $continuous pattern $pattern]
}

# ### ### ### ######### ######### #########
## INT: Communication setup / teardown / use

proc ::nameserv::DO {args} {
    variable sid
    log::debug [linsert $args end @ $sid]

    if {[catch {
	[SERV] send $sid $args
	#eval [linsert $args 0 [SERV] send $sid] ;# $args
    } msg]} {
	if {[string match "*refused*" $msg]} {
	    return -code error "No name server present @ $sid"
	} else {
	    return -code error $msg
	}
    }
    # Result of the call
    return $msg
}

proc ::nameserv::ASYNC {args} {
    variable sid
    log::debug [linsert $args end @ $sid]

    if {[catch {
	[SERV] send -async $sid $args
	#eval [linsert $args 0 [SERV] send $sid] ;# $args
    } msg]} {
	if {[string match "*refused*" $msg]} {
	    return -code error "No name server present @ $sid"
	} else {
	    return -code error $msg
	}
    }
    # No result to return
    return
}

proc ::nameserv::SERV {} {
    variable comm
    variable sid
    variable host
    variable port
    if {$comm ne ""} {return $comm}

    # NOTE
    # -local 1 means that clients can only talk to a local
    #          name service. Might make sense to auto-force
    #          -local 0 for host ne "localhost".

    set     interp [interp::createEmpty]
    foreach msg {
	Search/Continuous/Change
    } {
	interp alias $interp $msg {} ::nameserv::$msg
    }

    set sid  [list $port $host]
    set comm [comm::comm new ::nameserv::CSERV \
		  -interp $interp \
		  -local  1 \
		  -listen 1]

    $comm hook lost ::nameserv::LOST

    log::debug [list SERV @ $sid : $comm]
    return $comm
}

proc ::nameserv::LOST {args} {
    upvar 1 id id chan chan reason reason
    variable comm
    variable sid
    variable search

    log::debug [list LOST @ $sid - $reason]

    $comm destroy

    set comm {}
    set sid  {}

    # Notify async/cont search of the loss.
    foreach r [array names search] {
	$r DATA stop
	unset search($r)
    }

    uevent::generate nameserv lost-connection [list reason $reason]
    return
}

# ### ### ### ######### ######### #########
## Initialization - System state

namespace eval ::nameserv {
    # Object command of the communication channel to the server.
    # If present re-configuration is not possible. Also the comm
    # id of the server.

    variable comm {}
    variable sid  {}

    # Table of active async/cont searches

    variable search ; array set search {}
}

# ### ### ### ######### ######### #########
## API: Configuration management (host, port)

proc ::nameserv::cget {option} {
    return [configure $option]
}

proc ::nameserv::configure {args} {
    variable host
    variable port
    variable comm

    if {![llength $args]} {
	return [list -host $host -port $port]
    }
    if {[llength $args] == 1} {
	# cget
	set opt [lindex $args 0]
	switch -exact -- $opt {
	    -host { return $host }
	    -port { return $port }
	    default {
		return -code error "bad option \"$opt\", expected -host, or -port"
	    }
	}
    }

    if {$comm ne ""} {
	return -code error "Unable to configure an active connection"
    }

    # Note: Should -port/-host be made configurable after
    # communication has started it will be necessary to provide code
    # which retracts everything from the old server and re-initializes
    # the new one.

    while {[llength $args]} {
	set opt [lindex $args 0]
	switch -exact -- $opt {
	    -host {
		if {[llength $args] < 2} {
		    return -code error "value for \"$opt\" is missing"
		}
		set host [lindex $args 1]
		set args [lrange $args 2 end]
	    }
	    -port {
		if {[llength $args] < 2} {
		    return -code error "value for \"$opt\" is missing"
		}
		set port [lindex $args 1]
		# Todo: Check non-zero unsigned short integer
		set args [lrange $args 2 end]
	    }
	    default {
		return -code error "bad option \"$opt\", expected -host, or -port"
	    }
	}
    }
    return
}

# ### ### ### ######### ######### #########
## Receiver for continuous and async searches

proc ::nameserv::Search/Continuous/Change {tag type response} {

    # Ignore messages for searches which were canceled already.
    #
    # Due to the async nature of the messages for cont/async search
    # the client may have canceled the receiver object already, sent
    # the stop message already, but still has to process search
    # results which were already in flight. We ignore them.

    if {![llength [info commands $tag]]} return

    # This client uses the receiver object as tag, dispatch the
    # received notification to it.

    $tag DATA $type $response
    return
}

snit::type ::nameserv::receiver {
    option -command -default {}

    constructor {{once 0}} {
	set singleshot $once
	return
    }

    destructor {
	if {$singleshot} return
	::nameserv::ASYNC Search/Continuous/Stop $self
	Callback stop {}
	return
    }

    method get {k} {
	if {![info exists current($k)]} {return -code error "Unknown key \"$k\""}
	return $current($k)
    }

    method names {} {
	return [array names current]
    }

    method size {} {
	return [array size current]
    }

    method getall {{pattern *}} {
	return [array get current $pattern]
    }

    method filled {} {
	return $filled
    }

    method {DATA stop} {} {
	if {$filled && $singleshot} return
	set singleshot 1 ; # Prevent 'stop' again during destruction.
	Callback stop {}
	return
    }

    method {DATA add} {response} {
	set filled 1
	if {$singleshot} {
	    ASYNC Search/Continuous/Stop $self
	}
	array set current $response
	Callback add $response
	if {$singleshot} {
	    Callback stop {}
	}
	return
    }

    method {DATA remove} {response} {
	set filled 1
	foreach {k v} $response {
	    unset -nocomplain current($k)
	}
	Callback remove $response
	return
    }

    proc Callback {type response} {
	upvar 1 options options
	if {$options(-command) eq ""} return
	# Defer execution to event loop
	after 0 [linsert $options(-command) end $type $response]
	return
    }

    variable singleshot 0
    variable current -array {}
    variable filled 0
}

# ### ### ### ######### ######### #########
## Initialization - Tracing, Configuration

logger::initNamespace ::nameserv
namespace eval        ::nameserv {
    # Host and port to connect to, to get access to the nameservice.

    variable host localhost
    variable port [nameserv::common::port]

    namespace export bind release search protocol \
	server_protocol server_features configure cget
}

# ### ### ### ######### ######### #########
## Ready

package provide nameserv 0.4.2

##
# ### ### ### ######### ######### #########
