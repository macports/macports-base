# -*- tcl -*-
# ### ### ### ######### ######### #########
## Name Service - Client side connection monitor

# ### ### ### ######### ######### #########
## Requirements

package require nameserv 0.4.1 ; # Name service client-side core
package require uevent   ; # Watch for connection-loss

namespace eval ::nameserv::auto {}

# ### ### ### ######### ######### #########
## API: Write, Read, Search

proc ::nameserv::auto::bind {name data} {
    # See nameserv::bind. Remembers the information, for re-binding
    # when the connection was lost, and later restored.

    # Note: Enter has a return value we do not want, bind has no
    # return value. Otherwise 'Enter' would not be necessary and
    # simply be 'bind'.

    Enter $name $data normal
    return
}

proc ::nameserv::auto::release {} {
    # Releases all names the application has registered at the
    # configured name service.
    variable bindings
    variable timer

    array unset bindings *
    if {$timer ne ""} {
	# Actually release the data only if the connection is
	# currently not lost. Otherwise they are gone already, and
	# just forgetting them here (see above) was enough.
	nameserv::release
    }
    return
}

proc ::nameserv::auto::search {args} {
    variable searches

    # Note: Here we are using a semi-public command of 'nameserv' to
    # parse the search arguments on our own to determine if we need
    # the persistence or not.

    array set a [nameserv::search-parseargs $args]
    upvar 0 a(oneshot)    oneshot
    upvar 0 a(continuous) continuous
    upvar 0 a(pattern)    pattern

    if {!$continuous} {
	# Result is direct result of the search, pass through to
	# caller, nothing to persist.

	return [eval [linsert $args 0 ::nameserv::search]]
	# 8.5: return [nameserv::search {*}$args]
    }

    # Continuous or async search. The result we got is a receiver
    # object. Wrap our own persistent receiver around it so that it
    # can handle a loss of connection while we are waiting for the
    # search result.

    return [receiver %AUTO% $oneshot $args]
}

proc ::nameserv::auto::protocol {} {
    return [nameserv::protocol]
}

proc ::nameserv::auto::server_protocol {} {
    return [nameserv::server_protocol]
}

proc ::nameserv::auto::server_features {} {
    return [nameserv::server_features]
}

# ### ### ### ######### ######### #########
## Internal helper commands.

proc ::nameserv::auto::Reconnect {args} {
    # args = <>|<tags event details>
    # <tag,event> = <'nameserv','lost'>
    #     details = dict ('reason' -> string)

    StopReconnect

    if {![catch {
	::nameserv::server_features
    }]} {
	# Note: Reloss of connection during Rebind will also
	# StartReconnect
	Rebind
	return
    }

    StartReconnect
    return
}

proc ::nameserv::auto::Rebind {} {
    variable bindings
    variable searches

    foreach {name data} [array get bindings] {
	if {![Enter $name $data restore]} return
    }

    foreach receiver [array names searches] {
	if {![$receiver restore]} return
    }

    # Fully restored, time to notify interested parties
    uevent::generate nameserv re-connection {}
    return
}

proc ::nameserv::auto::Enter {name data how} {
    variable bindings

    # Remember locally for possible loss of connection ...
    set bindings($name) $data

    # ... then forward to name server
    if {[catch {
	nameserv::bind $name $data
    } msg]} {
	# Problem with server while (re)binding a name.

	if {[string match {*No name server*} $msg]} {
	    # Lost the server (again), while (re)binding a name. Abort
	    # and restart the watcher waiting for the server to come
	    # back.
	    StartReconnect
	    return 0
	}

	# Other error => (name already bound). This means that someone
	# else took the name while we were not connected to the
	# service, or the name was bound before the call anyway. The
	# reaction depends on our entry point. For regular bind we
	# return the error as is to keep API compatibility. During
	# restoration OTOH the best effort we can do is to deliver a
	# note about the total loss of this binding to all interested
	# observers via event. Additionally remove the lost item from
	# the set of names to remember. Note that there is no need to
	# restart the watcher, the server was _not_ lost.

	unset bindings($name)
	if {$how eq "normal"} {
	    return -code $msg
	} else {
	    uevent::generate nameserv lost-name [list name $name data $data]
	    return 1
	}
    }

    # Success, nothing further to do.
    return 1
}

# ### ### ### ######### ######### #########
## Management of the reconnect timer.

proc ::nameserv::auto::StartReconnect {} {
    variable timer
    variable delay
    if {$timer ne ""} return
    set timer [after $delay ::nameserv::auto::Reconnect]
    return
}

proc ::nameserv::auto::StopReconnect {} {
    variable timer ""
    return
}

# ### ### ### ######### ######### #########
## Persistent receiver for continuous and async searches.

snit::type ::nameserv::auto::receiver {

    option -command -default {}

    constructor {once search} {
	set mysingleshot $once
	set mysearch     $search
	$self restore ; # Create internal volatile receiver.
	return
    }

    destructor {
	if {$myreceiver ne ""} { $myreceiver destroy }
	if {$mysingleshot} return
	Callback stop {}
	return
    }

    method restore {} {
	set nameserv::auto::searches($self) .

	if {[catch {
	    set result [eval [linsert $mysearch 0 ::nameserv::search]]
	    # 8.5: set result [nameserv::search {*}$mysearch]
	} msg]} {
	    # Problem with server while restoring a search.

	    if {[string match {*No name server*} $msg]} {
		# Lost the server (again), while restoring the search.
		# Abort and restart the watcher waiting for the server
		# to come back.
		::nameserv::auto::StartReconnect
		return 0
	    }

	    # Rethrow other problems.
	    return -code error $msg
	}

	# Restored, prepare ourselves
	set myreceiver $result
	set myclear    1       ; # Have to clear previous data when
				 # the new set comes in.
	$myreceiver configure -command [mymethod DATA]
	return 1
    }

    method get {k} {
	if {![info exists mycurrent($k)]} {return -code error "Unknown key \"$k\""}
	return $current($k)
    }

    method names {} {
	return [array names mycurrent]
    }

    method size {} {
	return [array size mycurrent]
    }

    method getall {{pattern *}} {
	return [array get mycurrent $pattern]
    }

    method filled {} {
	return $myfilled
    }

    # Handler for events coming from the breakable search.

    method {DATA stop} {args} {
	# Ignore the response dict, it is empty anyway.
	# Get rid of the volatile receiver.
	if {$myreceiver ne ""} { $myreceiver destroy }
	#  Oneshot handling happened already.
	return
    }

    method {DATA add} {response} {
	# New entries to handle
	set myfilled 1
	if {$mysingleshot} {
	    # The search was async and is now done, therefore we can
	    # get rid of the volatile receiver and do not have to care
	    # about the loss of the connection any longer.
	    $myreceiver destroy
	    set myreceiver ""
	    unset ::nameserv::auto::searches($self)
	}
	if {$myclear} {
	    # Handle a refill after a connection loss, the new data
	    # overwrites everything known before.
	    array unset mycurrent *
	    set myclear 0
	}
	array set mycurrent $response
	Callback add $response
	if {$mysingleshot} {
	    Callback stop {}
	}
	return
    }

    method {DATA remove} {response} {
	set myfilled 1
	foreach {k v} $response {
	    unset -nocomplain mycurrent($k)
	}
	Callback remove $response
	return
    }

    # Run our own callback.

    proc Callback {type response} {
	upvar 1 options options
	if {$options(-command) eq ""} return
	# Defer execution to event loop
	after 0 [linsert $options(-command) end $type $response]
	return
    }

    # Search state

    variable mysingleshot     0  ; # Bool flag, set if search is
				   # async, not continous.
    variable mycurrent -array {} ; # Current state of search results
    variable myfilled         0  ; # Bool flag, set when result has arrived.

    variable mysearch         "" ; # Copy of search definition, for
				   # its restoration after our
				   # connection to the service was
				   # restored.
    variable myclear          0  ; # Bool flag, set when state has to
				   # be cleared before adding new
				   # data, for refill after a
				   # connection has been restored.
    variable myreceiver       "" ; # Volatile breakable regular search
				   # receiver.
}

# ### ### ### ######### ######### #########
## Initialization - System state

namespace eval ::nameserv::auto {
    # In-memory database of bindings to restore after connection was
    # lost and restored.

    variable bindings ; array set bindings {}

    # In-memory database of continuous and unfulfilled async searches
    # to restore after the connection was lost and restored.

    variable searches ; array set searches {}

    # Handle of the timer used to periodically try to reconnect with
    # the server in the case it was lost.

    variable timer ""
}

# ### ### ### ######### ######### #########
## API: Configuration management (host, port)

proc ::nameserv::auto::cget {option} {
    return [configure $option]
}

proc ::nameserv::auto::configure {args} {
    variable delay

    if {![llength $args]} {
	# Merge the underlying configuration with the local settings
	# before returning.
	return [linsert [nameserv::configure] 0 -delay $delay]
    }
    if {[llength $args] == 1} {
	# cget
	set opt [lindex $args 0]
	switch -exact -- $opt {
	    -delay { return $delay }
	    default {
		# Not a local option, check with underlying package
		# before throwing an error.
		if {![catch {
		    nameserv::cget $opt
		} v]} {
		    return $v
		}
		return -code error "[string map {{expected } {expected -delay, }} $v]"
	    }
	}
    }

    while {[llength $args]} {
	set opt [lindex $args 0]
	switch -exact -- $opt {
	    -delay {
		if {[llength $args] < 2} {
		    return -code error "value for \"$opt\" is missing"
		}
		set delay [lindex $args 1]
		set args  [lrange $args 2 end]

		# Using the 'incr' hack instead of 'string is integer'
		# allows delays larger than 32bit in Tcl 8.5.
		if {[catch {incr delay 0}]} {
		    return -code error "bad value for \"$opt\", expected integer, got \"$delay\""
		} elseif {$delay <= 0} {
		    return -code error "bad value for \"$opt\", is not greater than zero"
		}
	    }
	    default {
		# Not a local option, check with underlying package
		# before throwing an error.
		if {[catch {
		    nameserv::configure $opt [lindex $args 1]
		} v]} {
		    if {[string match {bad option*} $v]} {
			# Fix list of options in error before rethrowing.
			return -code error "[string map {{expected } {expected -delay, }} $v]"
		    } else {
			# Rethrow error unchanged
			return -code error $v
		    }
		}
		# No error, option is processed, continue after it.
		set args [lrange $args 2 end]
	    }
	}
    }
    return
}

# ### ### ### ######### ######### #########
## Initialization - Tracing, Configuration

logger::initNamespace ::nameserv::auto
namespace eval        ::nameserv::auto {
    # Interval between reconnection attempts when connection was lost.

    variable delay 1000 ; # One second

    namespace export bind release search protocol \
	server_protocol server_features configure cget
}

# Watch the base client for the loss of the connection.
uevent::bind nameserv lost-connection ::nameserv::auto::Reconnect

# ### ### ### ######### ######### #########
## Ready

package provide nameserv::auto 0.3

##
# ### ### ### ######### ######### #########
