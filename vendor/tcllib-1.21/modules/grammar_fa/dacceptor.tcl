# -*- tcl -*-
# Grammar / Finite Automatons / Acceptance checker, DFA only

# ### ### ### ######### ######### #########
## Package description

## A class whose instances take a FA and are able to check strings of
## symbols for acceptance. This class is restricted to deterministic
## FAs. The FA can be either a reference to some external FA container
## object, or a copy of such. The latter makes the acceptor impervious
## to changes in the original definition.

# ### ### ### ######### ######### #########
## Requisites

package require snit        ; # Tcllib | OO system used
package require struct::set ; # Tcllib | Extended set operations.

# ### ### ### ######### ######### #########
## Implementation

snit::type ::grammar::fa::dacceptor {
    # ### ### ### ######### ######### #########
    ## Type API. 

    # ### ### ### ######### ######### #########
    ## Instance API.

    #constructor {fa args} {}
    #destructor  {}

    method accept? {symbolstring} {}

    option -any     {}

    # ### ### ### ######### ######### #########
    ## Internal data structures.

    ## We take the relevant information from the FA specified during
    ## construction, i.e. start state, final states, and transition
    ## table in form for direct indexing and keep it local. No need to
    ## access or even the full FA. We require a deterministic one, and
    ## will complete it, if necessary.

    variable start ; # Name of start state.
    variable final ; # Array, existence = state is final.
    variable trans ; # Transition array: state x symbol -> state
    variable sym   ; # Symbol set (as array), for checking existence.
    variable any   ; # Symbol to map any unknown symbol to. If not
    #              ; # specified (eq "") then unknown symbols will  cause non-
    #              ; # acceptance.
    variable stop  ; # Stop state, causing immediate non-acceptance when entered.

    # ### ### ### ######### ######### #########
    ## Instance API Implementation.

    constructor {fa args} {
	set any {}
	$self configurelist $args

	if {![$fa is deterministic]} {
	    return -code error "Source FA is not deterministic"
	}
	if {($any ne "") && ![$fa symbol exists $any]} {
	    return -code error "Chosen any symbol \"$any\" does not exist"
	}

	if {![$fa is complete]} {
	    set istmp 1
	    set tmp [grammar::fa ${selfns}::fa = $fa]
	    set before [$tmp states]
	    $tmp complete
	    # Our sink is a stop state.
	    set stop [struct::set difference [$tmp states] $before]
	} else {
	    set istmp 0
	    set tmp $fa
	    # We don't know if there is a sink, so no quickstop.
	    set stop {}
	}

	set start [lindex [$tmp startstates] 0]
	foreach s [$tmp finalstates]        {set final($s) .}
	foreach s [set syms [$tmp symbols]] {set sym($s) .}

	foreach s [$tmp states] {
	    foreach sy $syms {
		set trans($s,$sy) [lindex [$tmp next $s $sy] 0]
	    }
	}

	if {$istmp} {$tmp destroy}
	return
    }

    #destructor {}

    onconfigure -any {value} {
	set options(-any) $value
	set any           $value
	return
    }

    # --- --- --- --------- --------- ---------

    method accept? {symbolstring} {
	set state $start

	## puts "\n====================== ($symbolstring)"

	if {$any eq ""} {
	    # No any mapping of unknown symbols.

	    foreach sy $symbolstring {
		if {![info exists sym($sy)]} {
		    # Bad symbol in input. String is not accepted,
		    # abort immediately.
		    ## puts " \[$state\] -- Unknown symbol ($sy)"
		    return 0
		}

		## puts " \[$state\] --($sy)--> "

		set state $trans($state,$sy)
		# state == "" cannot happen, as our FA is complete.
		if {$state eq $stop} {
		    # This is a known sink, we can stop processing input now.
		    ## puts " \[$state\] FULL STOP"
		    return 0
		}
	    }

	} else {
	    # Mapping of unknown symbols to any.

	    foreach sy $symbolstring {
		if {![info exists sym($sy)]} {set sy $any}
		## puts " \[$state\] --($sy)--> "
		set state $trans($state,$sy)
		# state == "" cannot happen, as our FA is complete.
		if {$state eq $stop} {
		    # This is a known sink, we can stop processing input now.
		    ## puts " \[$state\] FULL STOP"
		    return 0
		}
	    }
	}

	## puts " \[$state\][expr {[info exists final($state)] ? " ACCEPT" : ""}]"

	return [info exists final($state)]
    }

    # ### ### ### ######### ######### #########
    ## Type API implementation.

    # ### ### ### ######### ######### #########
    ## Type Internals.

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Package Management

package provide grammar::fa::dacceptor 0.1.1
