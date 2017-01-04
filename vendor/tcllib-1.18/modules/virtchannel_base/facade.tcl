# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2011 Andreas Kupries

# Facade wrapping around some other channel. All operations on the
# facade are delegated to the wrapped channel. This makes it useful
# for debugging of Tcl's activity on a channel. While a transform can
# be used for that as well it does not have access to some things of
# the base-channel, i.e. all the event managment is not visible to it,
# whereas the facade has access to even this.

# @@ Meta Begin
# Package tcl::chan::facade 1.0.1
# Meta as::author {Colin McCormack}
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2011
# Meta as::license BSD
# Meta description Facade wrapping around some other channel. All
# Meta description operations on the facade are delegated to the
# Meta description wrapped channel. This makes it useful for debugging
# Meta description of Tcl's activity on a channel. While a transform
# Meta description can be used for that as well it does not have
# Meta description access to some things of the base-channel, i.e. all
# Meta description the event managment is not visible to it, whereas
# Meta description the facade has access to even this.
# Meta platform tcl
# Meta require TclOO
# Meta require tcl::chan::core
# Meta require {Tcl 8.5}
# @@ Meta End

# # ## ### ##### ######## #############
## TODO document the special options of the facade
## TODO log integration.
## TODO document that facada takes ownership of the channel.

package require Tcl 8.5
package require TclOO
package require logger
package require tcl::chan::core

# # ## ### ##### ######## #############

namespace eval ::tcl::chan {}

logger::initNamespace ::tcl::chan::facade
proc ::tcl::chan::facade {args} {
    return [::chan create {read} [facade::implementation new {*}$args]]
}

# # ## ### ##### ######## #############

oo::class create ::tcl::chan::facade::implementation {
    superclass ::tcl::chan::core ; # -> initialize, finalize.

    # # ## ### ##### ######## #############

    # We are not using the standard event handling class, because here
    # it will not be timer-driven. We propagate anything related to
    # events to the wrapped channel instead and let it handle things.

    constructor {thechan} {
	# Access to the log(ger) commands.
	namespace path [list {*}[namespace path] ::tcl::chan::facade]

	set chan $thechan

	# set some configuration data
	set created [clock milliseconds]
	set used 0
	set user ""	;# user data - freeform

	# validate args
	if {$chan eq [self]} {
	    return -code error "recursive chan!  No good."
	} elseif {$chan eq ""} {
	    return -code error "Needs a chan argument"
	}

	set blocking [::chan configure $chan -blocking]
	return
    }

    destructor {
	log::debug {[self] destroyed}
	if {[catch { ::chan close $chan } e o]} {
	    log::debug {failed to close $chan [self] because "$e" ($o)}
	}
	return
    }

    variable chan used user created blocking

    method initialize {myself mode} {
	log::debug {$myself initialize $chan $mode}
	log::debug {$chan configured: ([::chan configure $chan])}
	return [next $chan $mode]
    }

    method finalize {myself} {
	log::debug {$myself finalize $chan}
	catch {::chan close $chan}
	catch {next $myself}
	catch {my destroy}
	return
    }

    method blocking {myself mode} {
	if {[catch {
	    ::chan configure $chan -blocking $mode
	    set blocking $mode
	} e o]} {
	    log::debug {$myself blocking $chan $mode -> error $e ($o)}
	} else {
	    log::debug {$myself blocking $chan $mode -> $e}
	}
	return
    }

    method watch {myself requestmask} {
	log::debug {$myself watch $chan $requestmask}

	if {"read" in $requestmask} {
	    fileevent readable $chan [my Callback Readable $myself]
	} else {
	    fileevent readable $chan {}
	}

	if {"write" in $requestmask} {
	    fileevent writable $chan [my Callback Writable $myself]
	} else {
	    fileevent writable $chan {}
	}
	return
    }

    method read {myself n} {
	log::debug {$myself read $chan begin eof: [::chan eof $chan], blocked: [::chan blocked $chan]}
	set used [clock milliseconds]

	if {[catch {
	    set data [::chan read $chan $n]
	} e o]} {
	    log::error {$myself read $chan $n -> error $e ($o)}
	} else {
	    log::debug {$myself read $chan $n -> [string length $data] bytes: [string map {\n \\n} "'[string range $data 0 20]...[string range $data end-20 end]"]'}
	    log::debug {$myself read $chan eof     = [::chan eof     $chan]}
	    log::debug {$myself read $chan blocked = [::chan blocked $chan]}
	    log::debug {$chan configured: ([::chan configure $chan])}

	    set gone [catch {chan eof $chan} eof]
	    if {
		($data eq {}) &&
		!$gone && !$eof && !$blocking
	    } {
		log::error {$myself EAGAIN}
		return -code error EAGAIN
	    }
	}

	log::debug {$myself read $chan result: [string length $data] bytes}
	return $data
    }

    method write {myself data} {
	log::debug {$myself write $chan [string length $data] / [::chan pending output $chan] / [::chan pending output $myself]}
	set used [clock milliseconds]
	::chan puts -nonewline $chan $data
	return [string length $data]
    }

    method configure {myself option value} {
	log::debug {[self] configure $myself $option -> $value}

	if {$option eq "-user"} {
	    set user $value
	    return
	}

	::chan configure $fd $option $value
	return
    }

    method cget {myself option} {
	switch -- $option {
	    -self    { return [self]   }
	    -fd      { return $chan    }
	    -used    { return $used    }
	    -created { return $created }
	    -user    { return $user    }
	    default  {
		return [::chan configure $chan $option]
	    }
	}
    }

    method cgetall {myself} {
	set result [::chan configure $chan]
	lappend result \
	    -self    [self] \
	    -fd      $chan \
	    -used    $used \
	    -created $created \
	    -user $user

	log::debug {[self] cgetall $myself -> $result}
	return $result
    }

    # # ## ### ##### ######## #############

    # Internals. Methods. Event generation.
    method Readable {myself} {
	log::debug {$myself readable $chan - [::chan pending input $chan]}
	::chan postevent $myself read
	return
    }

    method Writable {myself} {
	log::debug {$myself writable $chan - [::chan pending output $chan]}
	::chan postevent $myself write
	return
    }

    method Callback {method args} {
	list [uplevel 1 {namespace which my}] $method {*}$args
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## #############
package provide tcl::chan::facade 1.0.1
return
