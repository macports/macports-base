## -- Tcl Module -- -*- tcl -*-
# # ## ### ##### ######## #############

# @@ Meta Begin
# Package coroutine::auto 1.2
# Meta platform        tcl
# Meta require         {Tcl 8.6}
# Meta require         {coroutine 1.3}
# Meta license         BSD
# Meta as::author      {Andreas Kupries}
# Meta as::origin      http://wiki.tcl.tk/21555
# Meta summary         Coroutine Event and Channel Support
# Meta description     Built on top of coroutine, this
# Meta description     package intercepts various builtin
# Meta description     commands to make the code using them
# Meta description     coroutine-oblivious, i.e. able to run
# Meta description     inside and outside of a coroutine
# Meta description     without changes.
# @@ Meta End

# Copyright (c) 2009-2014 Andreas Kupries

# # ## ### ##### ######## #############
## Requisites, and ensemble setup.

package require Tcl 8.6
package require coroutine 1.3

namespace eval ::coroutine::auto {}

# # ## ### ##### ######## #############
## API implementations. Uses the coroutine commands where
## possible.

proc ::coroutine::auto::wrap_global args {
    if {[info coroutine] eq {}} {
	tailcall ::coroutine::auto::core_global {*}$args
    }

    tailcall ::coroutine::util::global {*}$args
}

# - -- --- ----- -------- -------------

proc ::coroutine::auto::wrap_after {delay args} {
    if {
	([info coroutine] eq {}) ||
	([llength $args] > 0)
    } {
	# We use the core builtin when called from either outside of a
	# coroutine, or for an asynchronous delay.
	tailcall ::coroutine::auto::core_after $delay {*}$args
    }

    # Inside of coroutine, and synchronous delay (args == {}).
    tailcall ::coroutine::util::after $delay
}

# - -- --- ----- -------- -------------

proc ::coroutine::auto::wrap_exit {{status 0}} {
    if {[info coroutine] eq {}} {
	tailcall ::coroutine::auto::core_exit $status
    }

    tailcall ::coroutine::util::exit $status
}

# - -- --- ----- -------- -------------

proc ::coroutine::auto::wrap_vwait varname {
    if {[info coroutine] eq {}} {
	tailcall ::coroutine::auto::core_vwait $varname
    }
    tailcall ::coroutine::util::vwait $varname
}

# - -- --- ----- -------- -------------

proc ::coroutine::auto::wrap_update {{what {}}} {
    if {[info coroutine] eq {}} {
	tailcall ::coroutine::auto::core_update {*}$what
    }

    # This is a full re-implementation of mode (1), because the
    # coroutine-aware part uses the builtin itself for some
    # functionality, and this part cannot be taken as is.

    if {$what eq {idletasks}} {
        after idle [info coroutine]
    } elseif {$what ne {}} {
        # Force proper error message for bad call.
        tailcall ::coroutine::auto::core_update $what
    } else {
        after 0 [info coroutine]
    }
    yield
    return
}

# - -- --- ----- -------- -------------

proc ::coroutine::auto::wrap_gets args {
    # Process arguments.
    # Acceptable syntax:
    # * gets CHAN ?VARNAME?

    if {[info coroutine] eq {}} {
	tailcall ::coroutine::auto::core_gets {*}$args
    }

    # This is a full re-implementation of mode (1), because the
    # coroutine-aware part uses the builtin itself for some
    # functionality, and this part cannot be taken as is.

    if {[llength $args] == 2} {
	# gets CHAN VARNAME
	lassign $args chan varname
        upvar 1 $varname line
    } elseif {[llength $args] == 1} {
	# gets CHAN
	lassign $args chan
    } else {
	# not enough, or too many arguments (0, or > 2): Calling the
	# builtin gets command with the bogus arguments gives us the
	# necessary error with the proper message.
	tailcall ::coroutine::auto::core_gets {*}$args
    }

    # Loop until we have a complete line. Yield to the event loop
    # where necessary. During

    while 1 {
        set blocking [::chan configure $chan -blocking]
        ::chan configure $chan -blocking 0

	try {
	    set result [::coroutine::auto::core_gets $chan line]
	} on error {result opts} {
            ::chan configure $chan -blocking $blocking
            return -code $result -options $opts
	}

	if {[::chan blocked $chan]} {
            ::chan event $chan readable [list [info coroutine]]
            yield
            ::chan event $chan readable {}
        } else {
            ::chan configure $chan -blocking $blocking

            if {[llength $args] == 2} {
                return $result
            } else {
                return $line
            }
        }
    }
}

# - -- --- ----- -------- -------------

proc ::coroutine::auto::wrap_read args {
    # Process arguments.
    # Acceptable syntax:
    # * read ?-nonewline ? CHAN
    # * read               CHAN ?n?

    if {[info coroutine] eq {}} {
	tailcall ::coroutine::auto::core_read {*}$args
    }

    # This is a full re-implementation of mode (1), because the
    # coroutine-aware part uses the builtin itself for some
    # functionality, and this part cannot be taken as is.

    if {[llength $args] > 2} {
	# Calling the builtin read command with the bogus arguments
	# gives us the necessary error with the proper message.
	::coroutine::auto::core_read {*}$args
	return
    }

    set total Inf ; # Number of characters to read. Here: Until eof.
    set chop  no  ; # Boolean flag. Determines if we have to trim a
    #               # \n from the end of the read string.

    if {[llength $args] == 2} {
	lassign $args a b
	if {$a eq {-nonewline}} {
	    set chan $b
	    set chop yes
	} else {
	    lassign $args chan total
	}
    } else {
	lassign $args chan
    }

    # Run the read loop. Yield to the event loop where
    # necessary. Differentiate between loop until eof, and loop until
    # n characters have been read (or eof reached).

    set buf {}

    if {$total eq {Inf}} {
	# Loop until eof.

	while 1 {
	    set blocking [::chan configure $chan -blocking]
	    ::chan configure $chan -blocking 0

	    try {
		set result [::coroutine::auto::core_read $chan]
	    } on error {result opts} {
		::chan configure $chan -blocking $blocking
		return -code $result -options $opts
	    }

	    if {[::chan blocked $chan]} {
		::chan event $chan readable [list [info coroutine]]
		yield
		::chan event $chan readable {}
	    } else {
		::chan configure $chan -blocking $blocking
		append buf $result

		if {[::chan eof $chan]} {
		    ::chan close $chan
		    break
		}
	    }
	}
    } else {
	# Loop until total characters have been read, or eof found,
	# whichever is first.

	set left $total
	while 1 {
	    set blocking [::chan configure $chan -blocking]
	    ::chan configure $chan -blocking 0

	    try {
		set result [::coroutine::auto::core_read $chan $left]
	    } on error {result opts} {
		::chan configure $chan -blocking $blocking
		return -code $result -options $opts
	    }

	    if {[::chan blocked $chan]} {
		::chan event $chan readable [list [info coroutine]]
		yield
		::chan event $chan readable {}
	    } else {
		::chan configure $chan -blocking $blocking
		append buf $result
		incr   left -[string length $result]

		if {[::chan eof $chan]} {
		    ::chan close $chan
		    break
		} elseif {!$left} {
		    break
		}
	    }
	}
    }

    if {$chop && [string index $buf end] eq "\n"} {
	set buf [string range $buf 0 end-1]
    }

    return $buf
}

# - -- --- ----- -------- -------------

proc ::coroutine::auto::wrap_puts args {
    # Process arguments.
    # Acceptable syntax:
    # * puts ?-nonewline? ?CHAN? string

    if {[info coroutine] eq {}} {
        tailcall ::coroutine::auto::core_puts {*}$args
    }

    # This is a full re-implementation of puts, because the
    # coroutine-aware part uses the builtin itself for some
    # functionality, and this part cannot be taken as is.

    # Calling the builtin puts command with the bogus arguments
    # gives us the necessary error with the proper message.

    switch [llength $args] {
        1 {
            set ch stdout
        }
        2 {
            set ch [lindex $args 0]
            if {[string match {-*} $ch]} {
                if {$ch ne {-nonewline}} {
                    # Force proper error message for bad call
                    tailcall ::coroutine::auto::core_puts {*}$args
                }
                set ch stdout
            }
        }
        3 {
            lassign $args opt ch
            if {$opt ne {-nonewline}} {
                # Force proper error message for bad call
                tailcall ::coroutine::auto::core_puts {*}$args
            }
        }
        default {
            # Force proper error message for bad call
            tailcall ::coroutine::auto::core_puts {*}$args
        }
    }
        set blocking [::chan configure $ch -blocking]
    ::chan event $ch writable [info coroutine]
    yield
    ::chan event $ch writable {}
    try {
        ::coroutine::auto::core_puts {*}$args
    } on error {result opts} {
        return -code $result -options $opts
    } finally {
        ::chan configure $ch -blocking $blocking
    }
    return
}

# - -- --- ----- -------- -------------

proc ::coroutine::auto::wrap_socket args {
    # Process arguments.
    # Acceptable syntax:
    # * connect ?options? host port
    # * connect -server command ?options? port

    if {[info coroutine] eq {} || [lsearch -exact $args -server] >= 0} {
        tailcall ::coroutine::auto::core_socket {*}$args
    }

    # This is a full re-implementation of socket, because the
    # coroutine-aware part uses the builtin itself for some
    # functionality, and this part cannot be taken as is.

    set s [::coroutine::auto::core_socket -async {*}$args]
    ::chan event $s writable [info coroutine]
    while {[::chan configure $s -connecting]} {
        yield
    }
    ::chan event $s writable {}
    set errmsg [::chan configure $s -error]
    if {$errmsg ne {}} {
        ::chan close $s
        error $errmsg
    }
    return $s
}

# # ## ### ##### ######## #############
## Internal. Setup.

::apply {{} {
    # Replaces the builtin commands with coroutine-aware
    # counterparts. We cannot use the coroutine commands directly,
    # because the replacements have to use the saved builtin commands
    # when called outside of a coroutine. And some (read, gets,
    # update) even need full re-implementations, as they use the
    # builtin command they replace themselves to implement their
    # functionality.

    foreach cmd {
	global
	exit
	after
	vwait
	update
        socket
    } {
	rename ::$cmd [namespace current]::core_$cmd
	rename [namespace current]::wrap_$cmd ::$cmd
    }

    foreach cmd {
	gets
	read
        puts
    } {
	rename ::tcl::chan::$cmd [namespace current]::core_$cmd
	rename [namespace current]::wrap_$cmd ::tcl::chan::$cmd
    }

    return
} ::coroutine::auto}

# # ## ### ##### ######## #############
## Ready

package provide coroutine::auto 1.2
return
