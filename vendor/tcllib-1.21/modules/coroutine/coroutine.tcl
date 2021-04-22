## -- Tcl Module -- -*- tcl -*-
# # ## ### ##### ######## #############

# @@ Meta Begin
# Package coroutine 1.3
# Meta platform        tcl
# Meta require         {Tcl 8.6}
# Meta license         BSD
# Meta as::author      {Andreas Kupries}
# Meta as::author      {Colin Macleod}
# Meta as::author      {Colin McCormack}
# Meta as::author      {Donal Fellows}
# Meta as::author      {Kevin Kenny}
# Meta as::author      {Neil Madden}
# Meta as::author      {Peter Spjuth}
# Meta as::origin      http://wiki.tcl.tk/21555
# Meta summary         Coroutine Event and Channel Support
# Meta description     This package provides coroutine-aware
# Meta description     implementations of various event- and
# Meta description     channel related commands. It can be
# Meta description     in multiple modes: (1) Call the
# Meta description     commands through their ensemble, in
# Meta description     code which is explicitly written for
# Meta description     use within coroutines. (2) Import
# Meta description     the commands into a namespace, either
# Meta description     directly, or through 'namespace path'.
# Meta description     This allows the use from within code
# Meta description     which is not coroutine-aware per se
# Meta description     and restricted to specific namespaces.
# Meta description     A more agressive form of making code
# Meta description     coroutine-oblivious than (2) above is
# Meta description     available through the package
# Meta description     coroutine::auto, which intercepts
# Meta description     the relevant builtin commands and changes
# Meta description     their implementation dependending on the
# Meta description     context they are run in, i.e. inside or
# Meta description     outside of a coroutine.
# @@ Meta End

# Copyright (c) 2009,2014-2015 Andreas Kupries
# Copyright (c) 2009 Colin Macleod
# Copyright (c) 2009 Colin McCormack
# Copyright (c) 2009 Donal Fellows
# Copyright (c) 2009 Kevin Kenny
# Copyright (c) 2009 Neil Madden
# Copyright (c) 2009 Peter Spjuth

## $Id: coroutine.tcl,v 1.2 2011/04/18 20:23:58 andreas_kupries Exp $
# # ## ### ##### ######## #############
## Requisites, and ensemble setup.

package require Tcl 8.6

namespace eval ::coroutine::util {

    namespace export \
	create global after exit vwait update gets read puts socket await

    namespace ensemble create
}

# # ## ### ##### ######## #############
## API. Spawn coroutines, automatic naming
##      (like thread::create).

proc ::coroutine::util::create {args} {
    ::coroutine [ID] {*}$args
}

# # ## ### ##### ######## #############
## API.
#
# global (coroutine globals (like thread global storage))
# after  (synchronous).
# exit
# update ?idletasks? [1]
# vwait
# gets               [1]
# read               [1]
# puts               [1]
# socket             [1]
#
# [1] These commands call on their builtin counterparts to get some of
#     their functionality (like proper error messages for syntax errors).

# - -- --- ----- -------- -------------

proc ::coroutine::util::global {args} {
    # Frame #1 is the coroutine-specific stack frame at its
    # bottom. Variables there are out of view of the main code, and
    # can be made visible in the entire coroutine underneath.

    # Ticket [bf8b80af]. Nothing needs to be done when the command is
    # invoked by the main procedure of the coroutine. Such code
    # already runs in frame #1, i.e. the variables are already in
    # scope, automatically.
    if {[info level] < 2} {
	return
    }

    set cmd [list upvar #1]
    foreach var $args {
	lappend cmd $var $var
    }
    tailcall {*}$cmd
}

# - -- --- ----- -------- -------------

proc ::coroutine::util::after delay {
    ::after $delay [list [info coroutine]]
    yield
    return
}

# - -- --- ----- -------- -------------

proc ::coroutine::util::exit {{status 0}} {
    return -level [info level] $status
}

# - -- --- ----- -------- -------------

proc ::coroutine::util::vwait varname {
    upvar 1 $varname var
    set callback [list [namespace current]::VWaitTrace [info coroutine]]

    # Step 1. Wait for a write to the variable, using a trace to
    # restart the coroutine

    trace add    variable var write $callback
    yield
    trace remove variable var write $callback

    # Step 2. To prevent the next section of the coroutine code from
    # running entirely within the variable trace (*) we now use an
    # idle handler to defer it until the trace is definitely
    # done. This trick by Peter Spjuth.
    #
    # (*) At this point we are in VWaitTrace running the coroutine.

    ::after idle [list [info coroutine]]
    yield
    return
}


proc ::coroutine::util::VWaitTrace {coroutine args} {
    $coroutine
    return
}

# - -- --- ----- -------- -------------

proc ::coroutine::util::update {{what {}}} {
    if {$what eq {idletasks}} {
        ::after idle [list [info coroutine]]
    } elseif {$what ne {}} {
        # Force proper error message for bad call.
        tailcall ::tcl::update $what
    } else {
        ::after 0 [list [info coroutine]]
    }
    yield
    return
}

# - -- --- ----- -------- -------------

proc ::coroutine::util::gets args {
    # Process arguments.
    # Acceptable syntax:
    # * gets CHAN ?VARNAME?

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
	tailcall ::chan gets {*}$args
    }

    # Loop until we have a complete line. Yield to the event loop
    # where necessary. During
    set blocking [::chan configure $chan -blocking]
    set readable [::chan event $chan readable]
    ::chan event $chan readable [list [info coroutine]]
    ::chan configure $chan -blocking 0
    try {
	while 1 {
	    try {
		set result [::chan gets $chan line]
	    } on error {result opts} {
		return -code $result -options $opts
	    }

	    if {[::chan blocked $chan]} {
		yield
	    } else {
		if {[llength $args] == 2} {
		    return $result
		} else {
		    return $line
		}
	    }
	}
    } finally {
	::chan configure $chan -blocking $blocking
	::chan event $chan readable $readable
    }
}


proc ::coroutine::util::gets_safety {chan limit varname {timeout 120000}} {
    # Process arguments.
    # Acceptable syntax:
    # * gets CHAN ?VARNAME?

    # Loop until we have a complete line. Yield to the event loop
    # where necessary. During
    upvar 1 $varname line
    set blocking [::chan configure $chan -blocking]
    ::chan configure $chan -blocking 0
    set readable [::chan event $chan readable]
    ::chan event $chan readable [list [info coroutine] readable]
    try {
	while 1 {
	    if {[::chan pending input $chan] >= $limit} {
		error {Too many notes, Mozart. Too many notes}
	    }
	    try {
		set result [::chan gets $chan line]
	    } on error {result opts} {
		return -code $result -options $opts
	    }

	    if {[::chan blocked $chan]} {
		set timeoutevent [::after $timeout [list [info coroutine] timeout]]
		set event [yield]
		if {$event eq {timeout}} {
		  error {Connection Timed Out}
		}
		::after cancel $timeoutevent
	    } else {
		return $result
	    }
	}
    } finally {
	::chan configure $chan -blocking $blocking
	::chan event $chan readable $readable
    }
}


# - -- --- ----- -------- -------------

proc ::coroutine::util::read args {
    # Process arguments.
    # Acceptable syntax:
    # * read ?-nonewline ? CHAN
    # * read               CHAN ?n?

    if {[llength $args] > 2} {
	# Calling the builtin read command with the bogus arguments
	# gives us the necessary error with the proper message.
	::chan read {*}$args
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

    set blocking [::chan configure $chan -blocking]
    set readable [::chan event $chan readable]
    ::chan event $chan readable [list [info coroutine]]
    ::chan configure $chan -blocking 0
    try {
	if {$total eq {Inf}} {
	    # Loop until eof.
	    while 1 {
		if {[::chan eof $chan]} {
		    break
		} elseif {[::chan blocked $chan]} {
		    yield
		}

		try {
		    set result [::chan read $chan]
		} on error {result opts} {
		    return -code $result -options $opts
		} 
		append buf $result
	    }
	} else {
	    # Loop until total characters have been read, or eof found,
	    # whichever is first.

	    set left $total
	    while 1 {
		if {[::chan eof $chan]} {
		    break
		} elseif {[::chan blocked $chan]} {
		    yield
		}

		try {
		    set result [::chan read $chan $left]
		} on error {result opts} {
		    return -code $result -options $opts
		}

		append buf $result
		incr left -[string length $result]
		if {!$left} {
		    break
		}
	    }
	}
    } finally {
	::chan configure $chan -blocking $blocking
	::chan event $chan readable $readable
    }

    if {$chop && [string index $buf end] eq "\n"} {
	set buf [string range $buf 0 end-1]
    }

    return $buf
}

# - -- --- ----- -------- -------------

## Yields until the channel is writable before actually writing, as
## suggested by the documentation for non-blocking puts
proc ::coroutine::util::puts args {
    # Process arguments.
    # Acceptable syntax:
    # * puts ?-nonewline? ?CHAN? string

    switch [llength $args] {
        1 {
            set ch stdout
        }
        2 {
            set ch [lindex $args 0]
            if {[string match {-*} $ch]} {
                if {$ch ne {-nonewline}} {
                    # Force proper error message for bad call
                    tailcall ::chan puts {*}$args
                }
                set ch stdout
            }
        }
        3 {
            lassign $args opt ch
            if {$opt ne {-nonewline}} {
                # Force proper error message for bad call
                tailcall ::chan puts {*}$args
            }
        }
        default {
            # Force proper error message for bad call
            tailcall ::chan puts {*}$args
        }
    }
    set blocking [::chan configure $ch -blocking]
    ::chan event $ch writable [info coroutine]
    yield
    ::chan event $ch writable {}
    try {
        ::chan puts {*}$args
    } on error {result opts} {
        return -code $result -options $opts
    } finally {
        ::chan configure $ch -blocking $blocking
    }
    return
}

# - -- --- ----- -------- -------------
## Does a non-blocking connect in the background and yields until finished.

proc ::coroutine::util::socket args {
    # Process arguments.
    # Acceptable syntax:
    # * socket ?options? host port

    if {[lsearch -exact $args -server] >= 0} {
        error "[namespace current]::socket cannot be used for server sockets."
    }
    set s [::socket -async {*}$args]
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


# - -- --- ----- -------- -------------
## This goes beyond the builtin vwait, wait for multiple variables,
## result is the name of the variable which was written.
## This code mainly by Neil Madden.

proc ::coroutine::util::await args {
    set callback [list [namespace current]::AWaitSignal [info coroutine]]

    # Step 1. Wait for a write to any of the variable, using a trace
    # to restart the coroutine, and the variable written to is
    # propagated into it.

    foreach varName $args {
        upvar 1 $varName var
        trace add variable var write $callback
    }

    set choice [yield]

    foreach varName $args {
	#checker exclude warnShadowVar
        upvar 1 $varName var
        trace remove variable var write $callback
    }

    # Step 2. To prevent the next section of the coroutine code from
    # running entirely within the variable trace (*) we now use an
    # idle handler to defer it until the trace is definitely
    # done. This trick by Peter Spjuth.
    #
    # (*) At this point we are in AWaitSignal running the coroutine.

    ::after idle [list [info coroutine]]
    yield

    return $choice
}


proc ::coroutine::util::AWaitSignal {coroutine var index op} {
    if {$op ne {write}} return
    set fullvar $var
    if {$index ne {}} {append fullvar ($index)}
    $coroutine $fullvar
}

# # ## ### ##### ######## #############
## Internal (package specific) commands

proc ::coroutine::util::ID {} {
    variable counter
    return [namespace current]::C[incr counter]
}

# # ## ### ##### ######## #############
## Internal (package specific) state

namespace eval ::coroutine::util {
    #checker exclude warnShadowVar
    variable counter 0
}

# # ## ### ##### ######## #############
## Ready
package provide coroutine 1.3
return
