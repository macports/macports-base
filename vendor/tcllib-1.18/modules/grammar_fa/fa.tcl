# -*- tcl -*-
# (c) 2004-2013 Andreas Kupries
# Grammar / Finite Automatons / Container

# ### ### ### ######### ######### #########
## Package description

## A class whose instances hold all the information describing a
## single finite automaton (states, symbols, start state, set of
## accepting states, transition function), and operations to define,
## manipulate, and query this information.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.4
if {[package vcompare [package present Tcl] 8.5] >= 0} {
    # Tcl 8.5+, extended package version numbers.
    # Require 1.3 and beyond, regardless of major version number.
    package require snit 1.3- ; # OO system in use (Using hierarchical methods)
} else {
    # Tcl 8.4, emulate, ask for 2.x first, then 1.3+.
    if {[catch {
	package require snit 2   ; # OO system in use (Using hierarchical methods)
    }]} {
	package require snit 1.3 ; # OO system in use (Using hierarchical methods)
    }
}

package require grammar::fa::op ; # Heavy FA operations.
package require struct::list    ; # Extended list operations.
package require struct::set     ; # Extended set operations.

# ### ### ### ######### ######### #########
## Implementation

snit::type ::grammar::fa {
    # ### ### ### ######### ######### #########
    ## Type API. A number of operations on FAs

    # ### ### ### ######### ######### #########
    ## Instance API

    #constructor {args} {}
    #destructor  {}

    method =   {b} {}
    method --> {b} {}

    method serialize {} {}
    method deserialize {value} {}
    method deserialize_merge {value} {}

    method states {} {}
    #method state {cmd s args} {}

    method startstates {} {}
    method start?      {s} {}
    method start?set   {states} {}
    #method start       {cmd args} {}

    method finalstates {} {}
    method final?      {s} {}
    method final?set   {states} {}
    #method final       {cmd args} {}

    method symbols     {} {}
    method symbols@    {state} {}
    method symbols@set {states} {}
    #method symbol      {cmd sym} {}

    method next  {s sym args} {}
    method !next {s sym args} {}
    method nextset {states sym} {}

    method is {cmd} {}

    method reachable_states   {} {}
    method unreachable_states {} {}
    method reachable          {s} {}

    method useful_states   {} {}
    method unuseful_states {} {}
    method useful          {s} {}

    method epsilon_closure {s} {}

    method clear {} {}

    # ### ### ### ######### ######### #########
    ## Instance API. Complex FA operations.
    ## The heavy lifting is done by the operations package.

    method reverse    {}                          {op::reverse    $self}
    method complete   {{sink {}}}                 {op::complete   $self $sink}
    method remove_eps {}                          {op::remove_eps $self}
    method trim       {{what !reachable|!useful}} {op::trim       $self $what}
    method complement {}                          {op::complement $self}
    method kleene     {}                          {op::kleene     $self}
    method optional   {}                          {op::optional   $self}
    method fromRegex  {regex {over {}}}           {op::fromRegex  $self $regex $over}

    method determinize {{mapvar {}}} {
	if {$mapvar ne ""} {upvar 1 $mapvar map}
	op::determinize $self map
    }

    method minimize {{mapvar {}}} {
	if {$mapvar ne ""} {upvar 1 $mapvar map}
	op::minimize $self map
    }

    method union {fa {mapvar {}}} {
	if {$mapvar ne ""} {upvar 1 $mapvar map}
	op::union $self $fa map
    }

    method intersect {fa {mapvar {}}} {
	if {$mapvar ne ""} {upvar 1 $mapvar map}
	op::intersect $self $fa map
    }

    method difference {fa {mapvar {}}} {
	if {$mapvar ne ""} {upvar 1 $mapvar map}
	op::difference $self $fa map
    }

    method concatenate {fa {mapvar {}}} {
	if {$mapvar ne ""} {upvar 1 $mapvar map}
	op::concatenate $self $fa map
    }

    # ### ### ### ######### ######### #########
    ## Internal data structures.

    ## State information:
    ## - Order    : Defined for all states, values provide creation order.
    ## - Start    : Defined for states which are "start" (Input processing begins in).
    ## - Final    : Defined for states which are "final" ("accept" input).
    ## - Transinv : Inverse transitions. Per state the set of (state,sym)'s
    ##              which have transitions into the state. Defined only for
    ##              states which have inbound transitions.
    ##
    ## Transinv is maintained to make state deletion easier: Direct
    ## access to the states and transitions which are inbound, for
    ## their deletion.

    variable order        ; # Map : State -> Order of creation
    variable final        ; # Map : State -> .   Exists <=> Is a final State
    variable start        ; # Map : State -> .   Exists <=> Is a start State
    variable transinv     ; # Map : State -> {(State, Sym)}

    ## Global information:
    ## - Scount     : Counter for creation order of states.

    variable scount     0  ; # Counter for orderering states.

    ## Symbol information:
    ## - Symbol : Defined for all symbols, values irrelevant.

    variable symbol       ; # Map : Symbol -> . Exists = Symbol declared.

    ## Transition data:
    ## - TransN  : Dynamically created instance variables. Transition tables
    ##             for single states. Defined only for states which have
    ##             transitions.
    ## - Transym : List of states having transitions on that symbol.

    ## Transym is maintained for symbol deletion. Direct access to the transitions
    ## we have to delete as well.

    ## selfns::trans_$order(state) : Per state map : symbol -> list of destinations.
    variable transym      ; # Map : Sym -> {State}

    ## Derived information:
    ## - Reach       : Cache for set of states reachable from start.
    ## - Reachvalid  : Boolean flag. True iff the reach cache contains valid data
    ## - Useful      : Cache for set of states able to reach final.
    ## - Usefulvalid : Boolean flag. True iff the useful cache contains valid data
    ## - Nondete     : Set of states which are non-deterministic, because they have
    #                  epsilon-transitions.
    # -  EC          : Cache of epsilon-closures

    variable reach      {} ; # Set of states reachable from 'start'.
    variable reachvalid 0  ; # Boolean flag, if 'reach' is valid.

    variable useful      {} ; # Set of states able to reach 'final'.
    variable usefulvalid 0  ; # Boolean flag, if 'useful' is valid.

    variable nondete    {} ; # Set of non-deterministic states, by epsilon/non-epsilon.
    variable nondets       ; # Per non-det state the set of symbols it is non-det in.

    variable ec            ; # Cache of epsilon-closures for states.


    # ### ### ### ######### ######### #########
    ## Instance API Implementation.

    constructor {args} {
	set alen [llength $args]
	if {($alen != 2) && ($alen != 0) && ($alen != 3)} {
	    return -code error "wrong#args: $self ?=|:=|<--|as|deserialize a'|fromRegex re ?over??"
	}

	array set order    {} ; set nondete     {}
	array set start    {} ; set scount      0
	array set final    {} ; set reach       {}
	array set symbol   {} ; set reachvalid  0
	array set transym  {} ; set useful      {}
	array set transinv {} ; set usefulvalid 0
	array set nondets  {}
	array set ec       {}

	if {$alen == 0} return

	foreach {cmd object} $args break
	switch -exact -- $cmd {
	    = - := - <-- - as {
		if {$alen != 2} {
		    return -code error "wrong#args: $self ?=|:=|<--|as|deserialize a'|fromRegex re ?over??"
		}
		$self = $object
	    }
	    deserialize {
		if {$alen != 2} {
		    return -code error "wrong#args: $self ?=|:=|<--|as|deserialize a'|fromRegex re ?over??"
		}
		# Object is actually a value, the deserialization to use.
		$self deserialize $object
	    }
	    fromRegex {
		# Object is actually a value, the regular expression to use.
		if {$alen == 2} {
		    $self fromRegex $object
		} else {
		    $self fromRegex $object [lindex $args 2]
		}
	    }
	    default {
		return -code error "bad assignment: $self ?=|:=|<--|as|deserialize a'|fromRegex re ?over??"
	    }
	}
	return
    }

    # destructor {}

    # --- --- --- --------- --------- ---------

    method = {b} {
	$self deserialize [$b serialize]
    }

    method --> {b} {
	$b deserialize [$self serialize]
    }

    # --- --- --- --------- --------- ---------

    method serialize {} {
	set ord {}
	foreach {s n} [array get order] {
	    lappend ord [list $s $n]
	}
	set states {} ; # Dictionary
	foreach item [lsort -index 1 -integer -increasing $ord] {
	    set s [lindex $item 0]
	    set sdata {}

	    # Dict data per state :

	    lappend sdata [info exists start($s)]
	    lappend sdata [info exists final($s)]

	    # Transitions from the state.

	    upvar #0 ${selfns}::trans_$order($s) jump

	    if {![info exists jump]} {
		lappend sdata {}
	    } else {
		lappend sdata [array get jump]
	    }

	    # ----------------------
	    lappend states $s $sdata
	}

	return [::list \
		grammar::fa \
		[array names symbol] \
		$states \
		]
    }

    method deserialize {value} {
	$self CheckSerialization $value st states acc tr newsymbols
	$self clear

	foreach s   $states     {set order($s)    [incr scount]}
	foreach sym $newsymbols {set symbol($sym) .}
	foreach s   $acc        {set final($s)    .}
	foreach s   $st         {set start($s)    .}

	foreach {sa sym se} $tr {$self Next $sa $sym $se}
	return
    }

    method deserialize_merge {value} {
	$self CheckSerialization $value st states acc tr newsymbols

	foreach s   $states     {set order($s)    [incr scount]}
	foreach sym $newsymbols {set symbol($sym) .}
	foreach s   $acc        {set final($s)    .}
	foreach s   $st         {set start($s)    .}

	foreach {sa sym se} $tr {$self Next $sa $sym $se}
	return
    }

    # --- --- --- --------- --------- ---------

    method states {} {
	return [array names order]
    }

    method {state add} {s args} {
	set args [linsert $args 0 $s]
	foreach s $args {
	    if {[info exists order($s)]} {
		return -code error "State \"$s\" is already known"
	    }
	}
	foreach s $args {set order($s) [incr scount]}
	return
    }

    method {state delete} {s args} {
	set args [linsert $args 0 $s]
	$self StateCheckSet $args

	foreach s $args {
	    unset -nocomplain start($s)                   ; # Start/Initial indicator
	    unset -nocomplain final($s)                   ; # Final/Accept indicator

	    # Remove all inbound transitions.
	    if {[info exists transinv($s)]} {
		set src $transinv($s)
		unset    transinv($s)

		foreach srcitem $src {
		    struct::list assign $srcitem sin sym
		    $self !Next $sin $sym $s
		}
	    }

	    # We remove transition data only after the inbound
	    # ones. Otherwise we screw up the removal of
	    # looping transitions. We have to consider the
	    # backpointers to us in transinv as well.

	    upvar #0  ${selfns}::trans_$order($s) jump
	    if {[info exists jump]} {
		foreach sym [array names jump] {
		    $self !Transym $s $sym
		    foreach nexts $jump($sym) {
			$self !Transinv $s $sym $nexts
		    }
		}

		unset ${selfns}::trans_$order($s) ; # Transitions from s
	    }
	    unset order($s)                               ; # State ordering

	    # Removal of a state may break the automaton into
	    # disconnected pieces. This means that the set of
	    # reachable and useful states may change, and the
	    # cache cannot be used from now on.

	    $self InvalidateReach
	    $self InvalidateUseful
	}
	return
    }

    method {state rename} {s snew} {
	$self StateCheck $s
	if {[info exists order($snew)]} {
	    return -code error "State \"$snew\" is already known"
	}

	set o $order($s)
	unset order($s)                               ; # State ordering
	set   order($snew) $o

	# Start/Initial indicator
	if {[info exists start($s)]} {
	    set   start($snew) $start($s)
	    unset start($s)
	}
	# Final/Accept indicator
	if {[info exists final($s)]} {
	    set   final($snew) $final($s)
	    unset final($s)
	}
	# Update all inbound transitions.
	if {[info exists transinv($s)]} {
	    set   transinv($snew) $transinv($s)
	    unset transinv($s)

	    # We have to perform a bit more here. We have to
	    # go through the inbound transitions and change the
	    # listed destination state to the new name.

	    foreach srcitem $transinv($snew) {
		struct::list assign $srcitem sin sym
		# For loops access the 'order' array under the
		# new name, the old entry is already gone. See
		# above. See bug SF 2595296.
		if {$sin eq $s} {
		    set sin $snew
		}
		upvar #0 ${selfns}::trans_$order($sin) jump
		upvar 0 jump($sym) destinations
		set pos [lsearch -exact $destinations $s]
		set destinations [lreplace $destinations $pos $pos $snew]
	    }
	}

	# Another place to change are the back pointers from
	# all the states we have transitions to, i.e. transinv
	# for all outbound states.

	upvar #0 ${selfns}::trans_$o jump
	if {[info exists jump]} {
	    foreach sym [array names jump] {
		foreach sout $jump($sym) {
		    upvar 0 transinv($sout) backpointer
		    set pos [lsearch -exact $backpointer [list $s $sym]]
		    set backpointer [lreplace $backpointer $pos $pos [list $snew $sym]]
		}

		# And also to update: Transym information for the symbol.
		upvar 0 transym($sym) users
		set pos [lsearch -exact $users $s]
		set users [lreplace $users $pos $pos $snew]
	    }
	}

	# Changing the name of a state does not change the
	# reachables / useful states per se. We just may have
	# to replace the name in the caches as well.

	# - Invalidation will do the same, at the expense of a
	# - larger computation later.

	$self InvalidateReach
	$self InvalidateUseful
	return
    }

    method {state exists} {s} {
	return [info exists order($s)]
    }

    # --- --- --- --------- --------- ---------

    method startstates {} {
	return [array names start]
    }

    method start? {s} {
	$self StateCheck $s
	return [info exists start($s)]
    }

    method start?set {states} {
	$self StateCheckSet $states
	foreach s $states {
	    if {[info exists start($s)]} {return 1}
	}
	return 0
    }

    # Note: Adding or removing start states does not change
    # usefulness, only reachability

    method {start add} {state args} {
	set args [linsert $args 0 $state]
	$self StateCheckSet $args
	foreach s $args {set start($s) .}
	$self InvalidateReach
	return
    }

    method {start set} {states} {
	$self StateCheckSet $states
	array unset start
	foreach s $states {set start($s) .}
	$self InvalidateReach
	return
    }

    method {start remove} {state args} {
	set args [linsert $args 0 $state]
	$self StateCheckSet $args
	foreach s $args {
	    unset -nocomplain start($s)
	}
	$self InvalidateReach
	return
    }

    method {start clear} {} {
	array unset start
	$self InvalidateReach
	return
    }

    # --- --- --- --------- --------- ---------

    method finalstates {} {
	return [array names final]
    }

    method final? {s} {
	$self StateCheck $s
	return [info exists final($s)]
    }

    method final?set {states} {
	$self StateCheckSet $states
	foreach s $states {
	    if {[info exists final($s)]} {return 1}
	}
	return 0
    }

    # Note: Adding or removing final states does not change
    # reachability, only usefulness

    method {final add} {state args} {
	set args [linsert $args 0 $state]
	$self StateCheckSet $args
	foreach s $args {set final($s) .}
	$self InvalidateUseful
	return
    }

    method {final set} {states} {
	$self StateCheckSet $states
	array unset final
	foreach s $states {set final($s) .}
	$self InvalidateReach
	return
    }

    method {final remove} {state args} {
	set args [linsert $args 0 $state]
	$self StateCheckSet $args
	foreach s $args {
	    unset -nocomplain final($s)
	}
	$self InvalidateUseful
	return
    }

    method {final clear} {} {
	array unset final
	$self InvalidateReach
	return
    }

    # --- --- --- --------- --------- ---------

    method symbols {} {
	return [array names symbol]
    }

    method symbols@ {s {t {}}} {
	$self StateCheck $s
	if {$t ne ""} {	$self StateCheck $t}
	upvar #0 ${selfns}::trans_$order($s) jump
	if {![info exists jump]} {return {}}
	if {$t eq ""} {
	    # No destination, all symbols.
	    return [array names jump]
	}
	# Specific destination, locate the symbols going there.
	set result {}
	foreach sym [array names jump] {
	    if {[lsearch -exact $jump($sym) $t] < 0} continue
	    lappend result $sym
	}
	return [lsort -uniq $result]
    }

    method symbols@set {states} {
	# Union (fa symbol@ s, f.a. s in states)

	$self StateCheckSet $states
	set result {}
	foreach s $states {
	    upvar #0 ${selfns}::trans_$order($s) jump
	    if {![info exists jump]} continue
	    foreach sym [array names jump] {
		lappend result $sym
	    }
	}
	return [lsort -uniq $result]
    }

    method {symbol add} {sym args} {
	set args [linsert $args 0 $sym]
	foreach sym $args {
	    if {$sym eq ""} {
		return -code error "Cannot add illegal empty symbol \"\""
	    }
	    if {[info exists symbol($sym)]} {
		return -code error "Symbol \"$sym\" is already known"
	    }
	}
	foreach sym $args {set symbol($sym) .}
	return
    }

    method {symbol delete} {sym args} {
	set args [linsert $args 0 $sym]
	$self SymbolCheckSetNE $args
	foreach sym $args {
	    unset symbol($sym)

	    # Delete all transitions using the removed symbol.

	    if {[info exists transym($sym)]} {
		foreach s $transym($sym) {
		    $self !Next $s $sym
		}
	    }
	}
	return
    }

    method {symbol rename} {sym newsym} {
	$self SymbolCheckNE $sym
	if {$newsym eq ""} {
	    return -code error "Cannot add illegal empty symbol \"\""
	}
	if {[info exists symbol($newsym)]} {
	    return -code error "Symbol \"$newsym\" is already known"
	}

	unset symbol($sym)
	set symbol($newsym) .

	if {[info exists transym($sym)]} {
	    set   transym($newsym) [set states $transym($sym)]
	    unset transym($sym)

	    foreach s $states {
		# Update the jump tables for each of the states
		# using this symbol, and the reverse tables as
		# well.

		upvar #0 ${selfns}::trans_$order($s) jump
		set   jump($newsym) [set destinations $jump($sym)]
		unset jump($sym)

		foreach sd $destinations {
		    upvar 0 transinv($sd) backpointer
		    set pos [lsearch -exact $backpointer [list $s $sym]]
		    set backpointer [lreplace $backpointer $pos $pos [list $s $newsym]]
		}
	    }
	}
	return
    }

    method {symbol exists} {sym} {
	return [info exists symbol($sym)]
    }

    # --- --- --- --------- --------- ---------

    method next {s sym args} {
	## Split into checking and functionality ...

	set alen [llength $args]
	if {($alen != 2) && ($alen != 0)} {
	    return -code error "wrong#args: [list $self] next s sym ?--> s'?"
	}
	$self StateCheck  $s
	$self SymbolCheck $sym

	if {($alen == 2) && [set cmd [lindex $args 0]] ne "-->"} {
	    return -code error "Expected -->, got \"$cmd\""
	}

	if {$alen == 0} {
	    # Query transition table.
	    upvar #0 ${selfns}::trans_$order($s) jump
	    if {![info exists jump($sym)]} {return {}}
	    return $jump($sym)
	}

	set nexts [lindex $args 1]
	$self StateCheck $nexts

	upvar #0 ${selfns}::trans_$order($s) jump
	if {[info exists jump($sym)] && [struct::set contains $jump($sym) $nexts]} {
	    return -code error "Transition \"($s, ($sym)) --> $nexts\" is already known"
	}

	$self Next $s $sym $nexts
	return
    }

    method !next {s sym args} {
	set alen [llength $args]
	if {($alen != 2) && ($alen != 0)} {
	    return -code error "wrong#args: [list $self] !next s sym ?--> s'?"
	}
	$self StateCheck  $s
	$self SymbolCheck $sym

	if {$alen == 2} {
	    if {[lindex $args 0] ne "-->"} {
		return -code error "Expected -->, got \"[lindex $args 0]\""
	    }
	    set nexts [lindex $args 1]
	    $self StateCheck $nexts
	    $self !Next $s $sym $nexts
	} else {
	    $self !Next $s $sym
	}
    }

    method nextset {states sym} {
	$self SymbolCheck   $sym
	$self StateCheckSet $states

	set result {}
	foreach s $states {
	    upvar #0 ${selfns}::trans_$order($s) jump
	    if {![info exists jump($sym)]} continue
	    struct::set add result $jump($sym)
	}
	return $result
    }

    # --- --- --- --------- --------- ---------

    method is {cmd} {
	switch -exact -- $cmd {
	    complete {
		# The FA is complete if Trans(State, Sym) != {} for all
		# states and symbols (Not counting epsilon transitions).
		# Without symbols the FA is deemed complete. Note:
		# States with epsilon transitions can use symbols
		# indirectly! Need their closures for exact
		# computation.

		set nsymbols [llength [array names symbol]]
		if {$nsymbols == 0} {return 1}
		foreach s [array names order] {
		    upvar #0 ${selfns}::trans_$order($s) jump
		    if {![info exists jump]} {return 0}
		    set njsym [array size jump]
		    if {[info exists jump()]} {
			set  njsym [llength [$self symbols@set [$self epsilon_closure $s]]]
			incr njsym -1
		    }
		    if {$njsym != $nsymbols}  {return 0}
		}
		return 1
	    }
	    deterministic {
		# The FA is deterministic if it has on start state, no
		# epsilon transitions, and the transition function is
		# State x Symbol -> State, and not
		# State x Symbol -> P(State).

		return [expr {
		    ([array size start] == 1) &&
		    ![llength $nondete] &&
		    ![array size nondets]
		}] ;#{}
	    }
	    epsilon-free {
		# FA is epsion-free if there are no states having epsilon transitions.
		return [expr {![llength $nondete]}]
	    }
	    useful {
		# The FA is useful if and only if we have states and
		# all states are reachable and useful.

		set states [$self states]
		return [expr {
		    [struct::set size $states] &&
		    [struct::set equal $states [$self reachable_states]] &&
		    [struct::set equal $states [$self useful_states]]
		}] ;# {}
	    }
	}
	return -code error "Expected complete, deterministic, epsilon-free, or useful, got \"$cmd\""
    }

    # --- --- --- --------- --------- ---------

    method reachable_states {} {
	if {$reachvalid} {return $reach}
	if {![array size start]} {
	    set reach {}
	} else {
	    # Basic algorithm like for epsilon_closure, except that we
	    # process all transitions, not only epsilons, and that
	    # the initial state is fixed to start.

	    set reach   [array names start]
	    set pending $reach
	    array set visited {}
	    while {[llength $pending]} {
		set s [struct::list shift pending]
		if {[info exists visited($s)]} continue
		set visited($s) .
		upvar #0 ${selfns}::trans_$order($s) jump
		if {![info exists jump]} continue
		if {![array size  jump]} continue
		foreach sym [array names jump] {
		    struct::set add reach   $jump($sym)
		    struct::set add pending $jump($sym)
		}
	    }
	}
	set reachvalid 1
	return $reach
    }

    method unreachable_states {} {
	# unreachable = states - reachables
	return [struct::set difference \
		[$self states] [$self reachable_states]]
    }

    method reachable {s} {
	$self StateCheck $s
	return [struct::set contains [$self reachable_states] $s]
    }

    # --- --- --- --------- --------- ---------

    method useful_states {} {
	if {$usefulvalid} {return $useful}

	# A state is useful if a final state
	# can be reached from it.

	if {![array size final]} {
	    set useful {}
	} else {
	    # Basic algorithm like for epsilon_closure, except that we
	    # process all transitions, not only epsilons, and that
	    # the initial set of states is fixed to final.

	    set useful      [array names final]
	    array set known [array get final]
	    set pending $useful
	    array set visited {}
	    while {[llength $pending]} {
		set s [struct::list shift pending]
		if {[info exists visited($s)]} continue
		set visited($s) .

		# All predecessors are useful, and have to be visited as well.
		# We get the predecessors from the transinv structure.

		if {![info exists transinv($s)]} continue
		foreach before $transinv($s) {
		    set before [lindex $before 0]
		    if {[info exists visited($before)]} continue
		    lappend pending $before
		    if {[info exists known($before)]} continue
		    lappend useful $before
		    set known($before) .
		}
	    }
	}
	set usefulvalid 1
	return $useful
    }

    method unuseful_states {} {
	# unuseful = states - useful
	return [struct::set difference \
		[$self states] [$self useful_states]]
    }

    method useful {s} {
	$self StateCheck $s
	return [struct::set contains [$self useful_states] $s]
    }

    # --- --- --- --------- --------- ---------

    method epsilon_closure {s} {
	# Iterative graph traversal. Keeps a set of states to look at,
	# and adds to them everything it can reach from the current
	# state via epsilon-transitions. Loops are handled through the
	# visited array to weed out all the states already processed.

	$self StateCheck $s

	# Prefer cached information
	if {[info exists ec($s)]} {
	    return $ec($s)
	}

	set closure [list $s]
	set pending [list $s]
	array set visited {}
	while {[llength $pending]} {
	    set t [struct::list shift pending]
	    if {[info exists visited($t)]} continue
	    set visited($t) .
	    upvar #0 ${selfns}::trans_$order($t) jump
	    if {![info exists jump()]} continue
	    struct::set add closure $jump()
	    struct::set add pending $jump()
	}
	set ec($s) $closure
	return $closure
    }

    # --- --- --- --------- --------- ---------

    method clear {} {
	array unset order    ; set nondete     {}
	array unset start    ; set scount      0
	array unset final    ; set reach       {}
	array unset symbol   ; set reachvalid  0
	array unset transym  ; set useful      {}
	array unset transinv ; set usefulvalid 0
	array unset nondets
	array unset ec

	# Locate all 'trans_' arrays and remove them as well.

	foreach v [info vars ${selfns}::trans_*] {
	    unset $v
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Instance Internals.

    method StateCheck {s} {
	if {![info exists order($s)]} {
	    return -code error "Illegal state \"$s\""
	}
    }

    method StateCheckSet {states} {
	foreach s $states {
	    if {![info exists order($s)]} {
		return -code error "Illegal state \"$s\""
	    }
	}
    }

    method SymbolCheck {sym} {
	if {$sym eq ""} return
	if {![info exists symbol($sym)]} {
	    return -code error "Illegal symbol \"$sym\""
	}
    }

    method SymbolCheckNE {sym} {
	if {($sym eq "") || ![info exists symbol($sym)]} {
	    return -code error "Illegal symbol \"$sym\""
	}
    }

    if 0 {
	# Unused. Activate when needed.
	method SymbolCheckSet {symbols} {
	    foreach sym $symbols {
		if {$sym eq ""} continue
		if {![info exists symbol($sym)]} {
		    return -code error "Illegal symbol \"$sym\""
		}
	    }
	}
    }

    method SymbolCheckSetNE {symbols} {
	foreach sym $symbols {
	    if {($sym eq "") || ![info exists symbol($sym)]} {
		return -code error "Illegal symbol \"$sym\""
	    }
	}
    }

    method Next {s sym nexts} {
	# Modify transition table. May update the set of
	# non-deterministic states. Invalidates reachable
	# cache, as states may become reachable. Updates
	# the transym and transinv mappings.

	upvar #0 ${selfns}::trans_$order($s) jump

	$self InvalidateReach
	$self InvalidateUseful
	# Clear closure cache when epsilons change.
	if {$sym eq ""} {array unset ec}

	if {[info exists transym($sym)]} {
	    struct::set include transym($sym) $s
	} else {
	    set transym($sym) [list $s]
	}

	if {[info exists transinv($nexts)]} {
	    struct::set include transinv($nexts) [list $s $sym]
	} else {
	    set transinv($nexts) [list [list $s $sym]]
	}

	if {![info exists jump($sym)]} {
	    set jump($sym) [list $nexts]
	} else {
	    struct::set include jump($sym) $nexts
	}
	$self NonDeterministic $s $sym
	return
    }

    method !Next {s sym args} {
	upvar #0 ${selfns}::trans_$order($s) jump
	# Anything to do at all ?
	if {![info exists jump($sym)]} return
	$self InvalidateReach
	$self InvalidateUseful
	# Clear closure cache when epsilons change.
	if {$sym eq ""} {array unset ec}

	if {![llength $args]} {
	    # Unset all transitions for (s, sym)
	    # Update transym and transinv mappings as well, if existing.

	    $self !Transym $s $sym
	    foreach nexts $jump($sym) {
		$self !Transinv $s $sym $nexts
	    }

	    unset jump($sym)
	} else {
	    # Remove the single transition (s, sym) -> nexts
	    set nexts [lindex $args 0]

	    struct::set exclude jump($sym) $nexts
	    $self !Transinv $s $sym $nexts

	    if {![struct::set size $jump($sym)]} {
		$self !Transym $s $sym
		unset jump($sym)
		if {![array size jump]} {
		    unset jump
		}
	    }
	}

	$self NonDeterministic $s $sym
	return
    }

    method !Transym {s sym} {
	struct::set exclude transym($sym) $s
	if {![struct::set size $transym($sym)]} {
	    unset transym($sym)
	}
    }

    method !Transinv {s sym nexts} {
	if {[info exists transinv($nexts)]} {
	    struct::set exclude transinv($nexts) [list $s $sym]
	    if {![struct::set size $transinv($nexts)]} {
		unset transinv($nexts)
	    }
	}
    }

    method InvalidateReach {} {
	set reachvalid 0
	set reach      {}
	return
    }

    method InvalidateUseful {} {
	set usefulvalid 0
	set useful     {}
	return
    }

    method NonDeterministic {s sym} {
	upvar #0 ${selfns}::trans_$order($s) jump

	# Epsilon rule, whole state check. Epslion present <=> Not a DFA.

	if {[info exists jump()]} {
	    struct::set include nondete $s
	} else {
	    struct::set exclude nondete $s
	}

	# Non-determinism over a symbol.

	upvar #0 ${selfns}::trans_$order($s) jump

	if {[info exists jump($sym)] && [struct::set size $jump($sym)] > 1} {
	    if {![info exists nondets($s)]} {
		set nondets($s) [list $sym]
	    } else {
		struct::set include nondets($s) $sym
	    }
	    return
	} else {
	    if {![info exists nondets($s)]} return
	    struct::set exclude nondets($s) $sym
	    if {![struct::set size $nondets($s)]} {
		unset nondets($s)
	    }
	}
	return
    }

    method CheckSerialization {value startst states acc trans syms} {
	# value is list/3 ('grammar::fa' symbols states)
	# !("" in symbols)
	# states is ordered dict (key is state, value is statedata)
	# statedata is list/3 (start final trans|"")
	# start is boolean
	# final is boolean
	# trans is dict (key in symbols, value is destinations)
	# destinations is set of states

	upvar 1 $startst startstates \
		$states  sts \
		$acc     a \
		$trans   t \
		$syms    symbols

	set prefix "error in serialization:"
	if {[llength $value] != 3} {
	    return -code error "$prefix list length not 3"
	}

	struct::list assign $value   stype symbols statedata

	if {$stype ne "grammar::fa"} {
	    return -code error "$prefix unknown type \"$stype\""
	}
	if {[struct::set contains $symbols ""]} {
	    return -code error "$prefix empty symbol is not legal"
	}

	if {[llength $statedata] % 2 == 1} {
	    return -code error "$prefix state data is not a dictionary"
	}
	array set _states $statedata
	if {[llength $statedata] != (2*[array size _states])} {
	    return -code error "$prefix state data contains duplicate states"
	}
	set startstates {}
	set sts {}
	set p   {}
	set a   {}
	set e   {}
	set l   {}
	set m   {}
	set t   {}
	foreach {k v} $statedata {
	    lappend sts $k
	    if {[llength $v] != 3} {
		return -code error "$prefix state list length not 3"
	    }

	    struct::list assign $v begin accept trans

	    if {![string is boolean -strict $begin]} {
		return -code error "$prefix expected boolean for start, got \"$begin\""
	    }
	    if {$begin} {lappend startstates $k}
	    if {![string is boolean -strict $accept]} {
		return -code error "$prefix expected boolean for final, got \"$accept\""
	    }
	    if {$accept} {lappend a $k}

	    if {[llength $trans] % 2 == 1} {
		return -code error "$prefix transition data is not a dictionary"
	    }
	    array set _trans $trans
	    if {[llength $trans] != (2*[array size _trans])} {
		return -code error "$prefix transition data contains duplicate symbols"
	    }
	    unset _trans

	    foreach {sym destinations} $trans {
		# destinations = list of state
		if {($sym ne "") && ![struct::set contains $symbols $sym]} {
		    return -code error "$prefix illegal symbol \"$sym\" in transition"
		}
		foreach dest $destinations {
		    if {![info exists _states($dest)]} {
			return -code error "$prefix illegal destination state \"$dest\""
		    }
		    lappend t $k $sym $dest
		}
	    }
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
## Initialization. Specify the container constructor command to use by
## the operations package.

::grammar::fa::op::constructor ::grammar::fa

# ### ### ### ######### ######### #########
## Package Management

package provide grammar::fa 0.5
