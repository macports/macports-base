# -*- tcl -*-
# ### ### ### ######### ######### #########
## Name Service - Server (Singleton)

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.4
package require comm             ; # Generic message transport
package require interp           ; # Interpreter helpers.
package require logger           ; # Tracing internal activity
package require nameserv::common ; # Common/shared utilities

namespace eval ::nameserv::server {}

# ### ### ### ######### ######### #########
## API: Start, Stop

proc ::nameserv::server::start {} {
    variable comm
    variable port
    variable localonly

    log::debug "start"
    if {$comm ne ""} return

    log::debug "start /granted"

    set     interp [interp::createEmpty]
    foreach msg {
	Bind
	Release
	Search
	Search/Continuous/Start
	Search/Continuous/Stop
	ProtocolVersion
	ProtocolFeatures
    } {
	interp alias $interp $msg {} ::nameserv::server::$msg
    }

    set comm [comm::comm new ::nameserv::server::COMM \
		  -interp $interp \
		  -port   $port \
		  -listen 1 \
		  -local  $localonly]

    $comm hook lost ::nameserv::server::LOST

    log::debug "UP @$port local-only $localonly"
    return
}

proc ::nameserv::server::stop {} {
    variable comm
    variable names
    variable data

    log::debug "stop"
    if {$comm eq ""} return

    log::debug "stop /granted"

    # This kills all existing connection and destroys the configured
    # -interp as well.

    $comm destroy
    set comm ""

    array unset names *
    array unset data  *

    log::debug "DOWN"
    return
}

proc ::nameserv::server::active? {} {
    variable comm
    return [expr {$comm ne ""}]
}

# ### ### ### ######### ######### #########
## INT: Protocol operations

proc ::nameserv::server::ProtocolVersion  {} {return 1}
proc ::nameserv::server::ProtocolFeatures {} {return {Core Search/Continuous}}

proc ::nameserv::server::Bind {name cdata} {
    variable comm
    variable names
    variable data

    set id [$comm remoteid]

    log::debug "bind ([list $name -> $cdata]), for $id"

    if {[info exists data($name)]} {
	log::debug "bind failed, \"$name\" is already bound"
	return -code error "Name \"$name\" is already bound"
    }

    lappend names($id)  $name
    set     data($name) $cdata

    Search/Continuous/NotifyAdd $name $cdata
    return
}

proc ::nameserv::server::Release {} {
    variable comm
    ReleaseId [$comm remoteid]
    return
}

proc ::nameserv::server::Search {pattern} {
    variable data
    return [array get data $pattern]
}

proc ::nameserv::server::ReleaseId {id} {
    variable names
    variable data
    variable searchi

    log::debug "release id $id"

    # Two steps. Release all searches the client may have open, then
    # all names it may have bound. That last step may trigger
    # notifications for searches by other clients. It must not trigger
    # searches from the client just going away, hence their release
    # first.

    foreach k [array names searchi [list $id *]] {
	Search/Release $k
    }

    if {[info exists names($id)]} {
	set gone {}
	foreach n $names($id) {
	    lappend gone $n $data($n)
	    catch {unset data($n)}

	    log::debug "release name <$n>"
	}
	unset names($id)

	Search/Continuous/NotifyRelease $gone
    }
    return
}

# ### ### ### ######### ######### #########
## Support for continuous and async searches

proc ::nameserv::server::Search/Continuous/Start {tag pattern} {
    variable data
    variable searchi
    variable searchp
    variable comm

    set id [$comm remoteid]

    # Register the search, then generate the initial response.
    # Non-unique tags are silently discarded. Clients will wait
    # forever.

    set k [list $id $tag]

    log::debug "search <$k>"

    if {[info exists searchi($k)]} {
	log::debug "search already known"
	return
    }

    log::debug "search added"

    set searchi($k) $pattern
    lappend searchp($pattern) $k

    $comm send -async $id [list Search/Continuous/Change \
			       $tag add [array get data $pattern]]
    return
}

proc ::nameserv::server::Search/Continuous/Stop {tag} {
    Search/Release [list [$comm remoteid] $tag]
    return
}

proc ::nameserv::server::Search/Release {k} {
    variable searchi
    variable searchp

    # Remove search information from the data store

    if {![info exists searchi($k)]} return

    log::debug "release search <$k>"

    set pattern $searchi($k)
    unset searchi($k)

    set pos [lsearch -exact $searchp($pattern) $k]
    if {$pos < 0} return
    set new [lreplace $searchp($pattern) $pos $pos]
    if {[llength $new]} {
	# Shorten the callback list.
	set searchp($pattern) $new
    } else {
	# Nothing monitors that pattern anymore, remove it completely.
	unset searchp($pattern)
    }
    return
}

proc ::nameserv::server::Search/Continuous/NotifyAdd {name val} {
    variable searchp

    # Abort quickly if there are no searches waiting.
    if {![array size searchp]} return

    foreach p [array names searchp] {
	if {![string match $p $name]} continue
	Notify $p add [list $name $val]
    }
    return
}

proc ::nameserv::server::Search/Continuous/NotifyRelease {gone} {
    variable searchp

    # Abort quickly if there are no searches waiting.
    if {![array size searchp]} return

    array set m $gone
    foreach p [array names searchp] {
	set response [array get m $p]
	if {![llength $response]} continue
	Notify $p remove $response
    }
    return
}

proc ::nameserv::server::Notify {p type response} {
    variable searchp
    variable comm

    foreach item $searchp($p) {
	foreach {id tag} $item break
	$comm send -async $id \
	    [list Search/Continuous/Change $tag $type $response]
    }
    return
}

# ### ### ### ######### ######### #########
## Initialization - In-memory database

namespace eval ::nameserv::server {
    # Database
    # search = list (id tag) : Searches are identified by client and a tag.
    #
    # array (id   -> list (name))      : Names under which a connection is known.
    # array (name -> data)             : Data associated with a name.
    #
    # array (pattern -> list (search)) : Per pattern the list of searches using it.
    # array (search -> pattern)        : Pattern per active search.
    #
    # searchp <~~> names
    # searchi <~~> data

    variable names   ; array set names {}
    variable data    ; array set data  {}
    variable searchp ; array set searchp {}
    variable searchi ; array set searchi {}
}

# ### ### ### ######### ######### #########
## INT: Connection management

proc ::nameserv::server::LOST {args} {
    # Currently just to see when a client goes away.

    upvar 1 id id chan chan reason reason
    ReleaseId $id
    return
}

# ### ### ### ######### ######### #########
## Initialization - System state

namespace eval ::nameserv::server {
    # Object command of the communication channel of the server.
    # If present re-configuration is not possible.

    variable comm {}
}

# ### ### ### ######### ######### #########
## API: Configuration management (host, port)

proc ::nameserv::server::cget {option} {
    return [configure $option]
}

proc ::nameserv::server::configure {args} {
    variable localonly
    variable port
    variable comm

    if {![llength $args]} {
	return [list -localonly $localonly -port $port]
    }
    if {[llength $args] == 1} {
	# cget
	set opt [lindex $args 0]
	switch -exact -- $opt {
	    -localonly { return $localonly }
	    -port      { return $port }
	    default {
		return -code error "bad option \"$opt\", expected -localonly, or -port"
	    }
	}
    }

    # Note: Should -port be made configurable after communication has
    # started it might be necessary to provide code to re-initialize
    # the connections to all known clients using the new
    # configuration.

    while {[llength $args]} {
	set opt [lindex $args 0]
	switch -exact -- $opt {
	    -localonly {
		if {[llength $args] < 2} {
		    return -code error "value for \"$opt\" is missing"
		}
		# Todo: Check boolean 
		set new  [lindex $args 1]
		set args [lrange $args 2 end]

		if {$new == $localonly} continue
		set localonly $new
		if {$comm eq ""} continue
		$comm configure -local $localonly
	    }
	    -port {
		if {$comm ne ""} {
		    return -code error "Unable to configure an active server"
		}
		if {[llength $args] < 2} {
		    return -code error "value for \"$opt\" is missing"
		}
		# Todo: Check non-zero unsigned short integer
		set port [lindex $args 1]
		set args [lrange $args 2 end]
	    }
	    default {
		return -code error "bad option \"$opt\", expected -localonly, or -port"
	    }
	}
    }
    return
}

# ### ### ### ######### ######### #########
## Initialization - Tracing, Configuration

logger::initNamespace ::nameserv::server
namespace eval        ::nameserv::server {
    # Port the server will listen on, and boolean flag determining
    # acceptance of non-local connections.

    variable port      [nameserv::common::port]
    variable localonly 1
}

# ### ### ### ######### ######### #########
## Ready

package provide nameserv::server 0.3.2

##
# ### ### ### ######### ######### #########
