# -*- tcl -*-
# Grammar / Finite Automatons / Executor, DFA only

# ### ### ### ######### ######### #########
## Package description

## Instances take a DFA, keep a current state and update it in
## reaction incoming symbols. Notable events are reported via
## callback. Currently notable: Reset, reached a final state,
# reached an error.

## From the above description it should be clear that this class is
## run in a push fashion. If not the last sentence has made this
## explicit, right ? Right!

# ### ### ### ######### ######### #########
## Requisites

package require snit   ; # Tcllib | OO system used

# ### ### ### ######### ######### #########
## Implementation

snit::type ::grammar::fa::dexec {
    # ### ### ### ######### ######### #########
    ## Type API. 

    # ### ### ### ######### ######### #########
    ## Instance API.

    #constructor {fa args} {}
    #destructor  {}

    method reset {} {}
    method put  {sy} {}
    method state {} {}

    option -command {}
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
    variable cmd   ; # Command to call for various events. Required.
    variable any   ; # Symbol to map any unknown symbol to. If not
    #              ; # specified (eq "") then unknown symbols will  cause non-
    #              ; # acceptance.
    variable curr  ; # State the underlying DFA is currently in.
    variable inerr ; # Boolean flag. Set if an error was reached.


    # ### ### ### ######### ######### #########
    ## Instance API Implementation.

    constructor {fa args} {
	set any {}
	set cmd {}
	$self configurelist $args

	if {![$fa is deterministic]} {
	    return -code error "Source FA is not deterministic"
	}
	if {($any ne "") && ![$fa symbol exists $any]} {
	    return -code error "Chosen any symbol \"$any\" does not exist"
	}
	if {![llength $cmd]} {
	    return -code error "Command callback missing"
	}

	# In contrast to the acceptor we do not complete the FA. We
	# will later report BADTRANS errors instead if a non-existing
	# transition is attempted. For the acceptor it made sense as
	# it made the accept/!accept decision easier. However here for
	# the generic execution it is unreasonable interference with
	# whatever higher levels might wish to do when encountering
	# this.

	set start [lindex [$fa startstates] 0]
	foreach s [$fa finalstates]        {set final($s) .}
	foreach s [set syms [$fa symbols]] {set sym($s) .}

	foreach s [$fa states] {
	    foreach sy [$fa symbols@ $s] {
		set trans($s,$sy) [lindex [$fa next $s $sy] 0]
	    }
	}

	$self reset
	return
    }

    #destructor {}

    onconfigure -command {value} {
	set options(-command) $value
	set cmd               $value
	return
    }

    onconfigure -any {value} {
	set options(-any) $value
	set any           $value
	return
    }

    # --- --- --- --------- --------- ---------

    method reset {} {
	set curr  $start
	set inerr 0
	## puts -nonewline " \[$curr\]" ; flush stdout

	uplevel #0 [linsert $cmd end \
		reset]
	return
    }

    method state {} {
	return $curr
    }

    method put {sy} {
	if {$inerr} return
	## puts " --($sy)-->"

	if {![info exists sym($sy)]} {
	    if {$any eq ""} {
		# No any mapping of unknown symbols, report as error
		## puts " BAD SYMBOL"

		set inerr 1
		uplevel #0 [linsert $cmd end \
			error BADSYM "Bad symbol \"$sy\""]
		return
	    } else {
		# Mapping of unknown symbols to any.
		set sy $any
	    }
	}

	if {[catch {
	    set new $trans($curr,$sy)
	}]} {
	    ## puts " NO DESTINATION"
	    set inerr 1
	    uplevel #0 [linsert $cmd end \
		    error BADTRANS "Bad transition (\"$curr\" \"$sy\"), no destination"]
	    return
	}
	set curr $new
	
	uplevel #0 [linsert $cmd end \
		state $curr]
	
	## puts -nonewline " \[$curr\]" ; flush stdout

	if {[info exists final($curr)]} {
	    ## puts -nonewline " FINAL" ; flush stdout

	    uplevel #0 [linsert $cmd end \
		    final $curr]
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Type API implementation.

    # ### ### ### ######### ######### #########
    ## Type Internals.

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Package Management

package provide grammar::fa::dexec 0.2
