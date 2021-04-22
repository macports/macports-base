# -*- tcl -*-
# ### ### ### ######### ######### #########
## Terminal packages - string -> action mappings
## (bind objects). For use with 'receive listen'.
## In essence a DFA with tree structure.

# ### ### ### ######### ######### #########
## Requirements

package require  snit
package require  term::receive
namespace eval ::term::receive::bind {}

# ### ### ### ######### ######### #########

snit::type ::term::receive::bind {

    constructor {{dict {}}} {
	foreach {str cmd} $dict {Register $str $cmd}
	return
    }

    method map {str cmd} {
	Register $str $cmd
	return
    }

    method default {cmd} {
	set default $cmd
	return
    }

    # ### ### ### ######### ######### #########
    ##

    method listen {{chan stdin}} {
	#parray dfa
	::term::receive::listen $self $chan
	return
    }

    method unlisten {{chan stdin}} {
	::term::receive::unlisten $chan
	return
    }

    # ### ### ### ######### ######### #########
    ##

    variable default {}
    variable state   {}

    method reset {} {
	set state {}
	return
    }

    method next {c} {Next $c ; return}
    method process {str} {
	foreach c [split $str {}] {Next $c}
	return
    }

    method eof {} {Eof ; return}

    proc Next {c} {
	upvar 1 dfa dfa state state default default
	set key [list $state $c]

	#puts -nonewline stderr "('$state' x '$c')"

	if {![info exists dfa($key)]} {
	    # Unknown sequence. Reset. Restart.
	    # Run it through the default action.

	    if {$default ne ""} {
		uplevel #0 [linsert $default end $state$c]
	    }

	    #puts stderr =\ RESET
	    set state {}
	} else {
	    foreach {what detail} $dfa($key) break
	    #puts -nonewline stderr "= $what '$detail'"
	    if {$what eq "t"} {
		# Incomplete sequence. Next state.
		set state $detail
		#puts stderr " goto ('$state')"
	    } elseif {$what eq "a"} {
		# Action, then reset.
		set state {}
		#puts stderr " run ($detail)"
		uplevel #0 [linsert $detail end $state$c]
	    } else {
		return -code error \
			"Internal error. Bad DFA."
	    }
	}
	return
    }

    proc Eof {} {}

    # ### ### ### ######### ######### #########
    ##

    proc Register {str cmd} {
	upvar 1 dfa dfa
	set prefix {}
	set last   {{} {}}
	foreach c [split $str {}] {
	    set key [list $prefix $c]
	    set next $prefix$c
	    set dfa($key) [list t $next]
	    set last $key
	    set prefix $next
	}
	set dfa($last) [list a $cmd]
    }
    variable dfa -array {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide term::receive::bind 0.1

##
# ### ### ### ######### ######### #########
