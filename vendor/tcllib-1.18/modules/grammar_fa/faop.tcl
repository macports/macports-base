# -*- tcl -*-
# Grammar / FA / Operations

# ### ### ### ######### ######### #########
## Package description

# ### ### ### ######### ######### #########
## Requisites

package require struct::list ; # Extended list operations.
package require struct::set  ; # Extended set operations.

# ### ### ### ######### ######### #########
## Implementation

namespace eval ::grammar::fa::op {

    # ### ### ### ######### ######### #########
    ## API. Structure / Language / Compilation

    proc reverse     {fa} {}
    proc complete    {fa {sink {}}} {}
    proc remove_eps  {fa} {}
    proc trim        {fa {what !reachable|!useful}} {}
    proc determinize {fa {mapvar {}} {idstart 0}} {}
    proc minimize    {fa {mapvar {}}} {}

    proc complement  {fa} {}
    proc kleene      {fa} {}
    proc optional    {fa} {}
    proc union       {fa fb {mapvar {}}} {}
    proc intersect   {fa fb {mapvar {}} {idstart 0}} {}
    proc difference  {fa fb {mapvar {}}} {}
    proc concatenate {fa fb {mapvar {}}} {}

    proc fromRegex   {fa regex {over {}}} {}

    proc toRegexp    {fa} {}
    proc toRegexp2   {fa} {}

    proc simplifyRegexp {rex} {}
    proc toTclRegexp    {rex symdict} {}

    # ### ### ### ######### ######### #########

    namespace export reverse complete remove_eps trim \
	    determinize minimize complement kleene \
	    optional union intersect difference \
	    concatenate fromRegex toRegexp toRegexp2 \
	    simplifyRegexp toTclRegexp

    # ### ### ### ######### ######### #########
    ## Internal data structures.

    variable cons {}

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## API implementation. Structure

proc ::grammar::fa::op::reverse {fa} {
    # Reversal means that all transitions change their direction
    # and start and final states are swapped.

    # Note that reversed FA might not be deterministic, even if the FA
    # itself was.

    # One loop is not enough for this. If we reverse the
    # transitions for a state immediately we may modify a state
    # which has not been processed yet. And when we come to this
    # state we reverse already reversed transitions, creating a
    # complete mess. Thus two loops, one to collect the current
    # transitions (and also remove them), and a second to insert
    # the reversed transitions.

    set tmp [$fa finalstates]
    $fa final set [$fa startstates]
    $fa start set $tmp

    # FUTURE : Method to retrieve all transitions
    # FUTURE : Method to delete all transitions

    set trans {}
    foreach s [$fa states] {
	foreach sym [$fa symbols@ $s] {
	    lappend trans $s $sym [$fa next $s $sym]
	    $fa !next $s $sym
	}
    }
    foreach {s sym destinations} $trans {
	foreach d $destinations {
	    $fa next $d $sym --> $s
	}
    }
    return
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::complete {fa {sink {}}} {
    if {[$fa is complete]} return

    # We have an incomplete FA.

    if {$sink eq ""} {
	set sink [FindNewState $fa sink]
    } elseif {[$fa state exists $sink]} {
	return -code error "The chosen sink state exists already"
    }
    $fa state add $sink

    # Add transitions to it from all states which are not
    # complete. The sink state itself loops on all inputs. IOW it is a
    # non-useful state.

    set symbols [$fa symbols]
    foreach sym $symbols {
	$fa next $sink $sym --> $sink  
    }

    if {[$fa is epsilon-free]} {
	foreach s [$fa states] {
	    foreach missing [struct::set difference \
		    $symbols \
		    [$fa symbols@ $s]] {
		$fa next $s $missing --> $sink
	    }
	}
    } else {
	# For an FA with epsilon-transitions we cannot simply look at
	# the direct transitions to find the used symbols. We have to
	# determine this for the epsilon-closure of the state in
	# question. Oh, and we have to defer actually adding the
	# transitions after we have picked them all, or otherwise the
	# newly added transitions throw the symbol calculations for
	# epsilon closures off.

	set new {}
	foreach s [$fa states] {
	    foreach missing [struct::set difference \
		    $symbols \
		    [$fa symbols@set [$fa epsilon_closure $s]]] {
		lappend new $s $missing
	    }
	}

	foreach {s missing} $new {
	    $fa next $s $missing --> $sink
	}
    }
    return
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::remove_eps {fa} {
    # We eliminate all epsilon transitions by duplicating a number
    # of regular transitions, which we get through the epsilon
    # closure of the states having epsilon transitions. We do
    # nothing if the FA is epsilon free to begin with.

    if {[$fa is epsilon-free]} return

    # Note: Epsilon transitions touching start and final states
    # propagate the start markers forward and final markers
    # backward. We do this first by propagating start markers twice,
    # once with a reversed FA. This also gives us some
    # epsilon-closures as well.

    foreach n {1 2} {
	foreach s [$fa startstates] {
	    foreach e [$fa epsilon_closure $s] {
		$fa start add $e
	    }
	}
	reverse $fa
    }

    # Now duplicate all transitions which are followed or preceeded by
    # epsilon transitions of any number greater than zero.

    # Note: The closure computations done by the FA are cached in the
    # FA, so doing it multiple times is no big penalty.

    # FUTURE : Retrieve all transitions on one command.

    # FUTURE : Different algorithm ...
    # Retrieve non-eps transitions for all states ...
    # Iterate this list. Compute e-closures for endpoints, cache
    # them. Duplicate the transition if needed, in that case add it to
    # the end of the list, for possible more duplication (may touch
    # different e-closures). Stop when the list is empty again.

    set changed 1
    while {$changed} {
	set changed 0
	foreach s [$fa states] {
	    foreach sym [$fa symbols@ $s] {
		set dest [$fa next $s $sym]
		if {$sym eq ""} {
		    # Epsilon transitions.

		    # Get the closure, and duplicate all transitions for all
		    # non-empty symbols as transitions of the original state.
		    # This may lead to parallel transitions between states, hence
		    # the catch. It prevents the generated error from stopping the
		    # action, and no actual parallel transitions are created.

		    set clos [$fa epsilon_closure $s]
		    foreach csym [$fa symbols@set $clos] {
			if {$csym eq ""} continue
			foreach d [$fa nextset $clos $csym] {
			    if {![catch {$fa next $s $csym --> $d} msg]} {
				set changed 1
			    }
			}
		    }
		} else {
		    # Regular transition. Go through all destination
		    # states, compute their closures and replicate the
		    # transition if the closure contains more than the
		    # destination itself, to all states in the closure.

		    foreach d $dest {
			set clos [$fa epsilon_closure $d]
			if {[llength $clos] > 1} {
			    foreach e $clos {
				if {![catch {$fa next $s $sym --> $e}]} {
				    set changed 1
				}
			    }
			}
		    }
		}
	    }
	}
    }

    # At last, drop the epsilons for all states. Only now is this
    # possible because otherwise we might compute bad epsilon
    # closures in the previous loop.

    foreach s [$fa states] {
	$fa !next $s ""
    }
    return
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::trim {fa {what !reachable|!useful}} {
    # Remove various unwanted pices from the FA.

    switch -exact -- $what {
	!reachable {
	    set remove [$fa unreachable_states]
	}
	!useful {
	    set remove [$fa unuseful_states]
	}
	!reachable&!useful -
	!(reachable|useful) {
	    set remove [struct::set intersect [$fa unreachable_states] [$fa unuseful_states]]
	}
	!reachable|!useful -
	!(reachable&useful) {
	    set remove [struct::set union [$fa unreachable_states] [$fa unuseful_states]]
	}
	default {
	    return -code error "Expected !reachable, !useful, !reachable&!useful, !(reachable|useful), !reachable|!useful, or !(reachable&useful), got \"$what\""
	}
    }

    foreach s $remove {
	$fa state delete $s
    }
    return
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::determinize {fa {mapvar {}} {idstart 0}} {
    # We do the operation in several stages instead of jumping
    # directly in the subset construction. Basically we try the less
    # expensive operations first to see if they are enough. It does
    # help that they will us also bring nearer to the ultimate goal
    # even if they are not enough.

    set hasmap 0
    if {$mapvar ne ""} {
	upvar 1 $mapvar map ; set hasmap 1
    }

    # First, is the input already deterministic ?
    # There is nothing to do in that case.

    if {[$fa is deterministic]} {
	if {$hasmap} {set map {}}
	return
    }

    # Second, trim unreachable and unuseables. We are done if only
    # they carried the non-determinism. Otherwise we might have made
    # the FA smaller and was less time consuming to convert.

    if {[llength [$fa startstates]]} {trim $fa !reachable}
    if {[llength [$fa finalstates]]} {trim $fa !useful}
    if {[$fa is deterministic]} {
	if {$hasmap} {set map {}}
	return
    }

    # Third, remove any epsilon transitions, and stop if that was
    # enough. Of course, weed out again states which have become
    # irrelevant. The removal of the epsilons will at least ensure
    # that the subset construction won't have to deal with
    # closures. I.e. simpler.

    remove_eps $fa
    if {[llength [$fa startstates]]} {trim $fa !reachable}
    if {[llength [$fa finalstates]]} {trim $fa !useful}
    if {[$fa is deterministic]} {
	if {$hasmap} {set map {}}
	return
    }

    # Fourth. There is no way to avoid the subset construction.
    # Dive in. This is the only part of the algorithm which requires
    # us to keep a map. We construct the dfa in a transient container
    # and copy the result back to fa when completed.

    array set subsets {}
    set id      $idstart
    set pending {}
    set dfa [[cons] %AUTO%]
    # FUTURE : $dfa symbol set [$fa symbols]
    foreach sym [$fa symbols] {$dfa symbol add $sym}

    # If we have start states we can initialize the algorithm with
    # their set. Otherwise we have to the single-element sets of all
    # states as the beginning.

    set starts [$fa startstates]
    if {[llength $starts] > 0} {
	# Make the set of start states the initial stae of the result.

	set starts [lsort $starts] ; # Sort to get canonical form.
	$dfa state add $id
	$dfa start add $id

	# The start may also be a final state
	if {[$fa final?set $starts]} {
	    $dfa final add $id
	}

	set subsets(dfa,$starts) $id
	set subsets(nfa,$id) $starts
	
	lappend pending $id
	incr id
    } else {
	# Convert all states of the input into sets (of one element)
	# in the output. Do not forget to mark all final states we
	# come by. No start states, otherwise we wouldn't be here.

	foreach s [$fa states] {
	    set nfaset [list $s]

	    $dfa state add $id
	    if {[$fa final? $s]} {
		$dfa final add $id
	    }

	    set subsets(dfa,$nfaset) $id
	    set subsets(nfa,$id) $nfaset
	    lappend pending $id
	    incr id
	}
    }

    while {[llength $pending]} {
	set dfastate [struct::list shift pending]

	# We have to compute the transition function for this dfa state.

	set nfaset $subsets(nfa,$dfastate)

	foreach sym [$fa symbols@set $nfaset] {
	    set nfanext [lsort [$fa nextset $nfaset $sym]]

	    if {![info exists subsets(dfa,$nfanext)]} {
		# Unknown destination. Add it as a new state.

		$dfa state add $id
		if {[$fa final?set $nfanext]} {
		    $dfa final add $id
		}

		set subsets(dfa,$nfanext) $id
		set subsets(nfa,$id) $nfanext

		# Schedule the calculation of the transition function
		# of the new state.

		lappend pending $id
		incr id
	    }

	    # Add the transition
	    $dfa next $dfastate $sym --> $subsets(dfa,$nfanext)
	}
    }

    if {[llength [$fa startstates]]} {trim $fa !reachable}
    if {[llength [$fa finalstates]]} {trim $fa !useful}

    if {$hasmap} {
	# The map is from new dfa states to the sets of nfa states.

	set map {}
	foreach s [$dfa states] {
	    lappend map $s $subsets(nfa,$s)
	}
    }

    $fa = $dfa
    $dfa destroy

    # ASSERT : $fa is deterministic
    return
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::minimize {fa {mapvar {}}} {
    # Brzozowski's method:
    # Reverse, determinize, reverse again, determinize again.

    reverse     $fa
    determinize $fa mapa
    reverse     $fa
    determinize $fa mapb

    if {$mapvar ne ""} {
	upvar 1 $mapvar map

	if {![llength $mapa] && ![llength $mapb]} {
	    # No state reorganizations, signal up
	    set map {}
	} elseif {[llength $mapa] && ![llength $mapb]} {
	    # Only one reorg, this is the combined reorg as well.
	    set map $mapa
	} elseif {![llength $mapa] && [llength $mapb]} {
	    # Only one reorg, this is the combined reorg as well.
	    set map $mapb
	} else {
	    # Two reorgs. Compose the maps into the final map signaled
	    # up.

	    # mapb : final state -> set of states in mapa -> sets of original states.

	    set map {}
	    array set tmp $mapa
	    foreach {b aset} $mapb {
		set compose {}
		foreach a $aset {foreach o $tmp($a) {lappend compose $o}}
		lappend map $b [lsort -uniq $compose]
	    }
	}
    }

    # The FA is implicitly trimmed by the determinize's.
    return
}

# ### ### ### ######### ######### #########
## API implementation. Language.

proc ::grammar::fa::op::complement {fa} {
    # Complementing is possible if and only if the FA is complete,
    # and accomplished by swapping the final and non-final states.

    if {![$fa is complete]} {
	return -code error "Unable to complement incomplete FA"
    }
    if {![$fa is deterministic]} {
	return -code error "Unable to complement non-deterministic FA"
    }

    set newfinal [struct::set difference [$fa states] [$fa finalstates]]
    $fa final set $newfinal
    return
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::kleene {fa} {
    # The Kleene Closure of the FA makes no sense if we don't have
    # start and final states we can work from.

    set start [$fa startstates]
    set final [$fa finalstates]

    if {![llength $start] || ![llength $final]} {
	return -code error "Unable to add Kleene's closure to a FA without start/final states"
    }

    # FUTURE :: If final states have no outgoing transitions, and start
    # FUTURE :: states have no input transitions, then place the new
    # FUTURE :: transitions directly between start and final
    # FUTURE :: states. In that case we don't need new states.

    # We need new start/final states, like for optional (see below)

    set ns [NewState $fa s]
    set nf [NewState $fa f]

    foreach s $start {$fa next $ns "" --> $s}
    foreach f $final {$fa next $f  "" --> $nf}

    $fa start clear ; $fa start add $ns
    $fa final clear ; $fa final add $nf

    $fa next $ns "" --> $nf ; # Optionality
    $fa next $nf "" --> $ns ; # Loop for closure
    return
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::optional {fa} {
    # The Optionality of the FA makes no sense if we don't have
    # start and final states we can work from.

    set start [$fa startstates]
    set final [$fa finalstates]

    if {![llength $start] || ![llength $final]} {
	return -code error "Unable to make a FA without start/final states optional"
    }

    # We have to introduce new start and final states to ensure
    # that we do not get additional recognized words from the FA
    # due to epsilon transitions. IOW just placing epsilons from
    # all start to all final states is wrong. Consider unreachable
    # final states, they become reachable. Or final states able to
    # reach final states from. Again the epsilons would extend the
    # language. We have to detach our optional epsilon from anything
    # in the existing start/final states. Hence the new start/final.

    # FUTURE : Recognize if there are no problems with placing direct
    # FUTURE : epsilons from start to final.

    set ns [NewState $fa s]
    set nf [NewState $fa f]

    foreach s $start {$fa next $ns "" --> $s}
    foreach f $final {$fa next $f  "" --> $nf}

    $fa start clear ; $fa start add $ns
    $fa final clear ; $fa final add $nf

    $fa next $ns "" --> $nf ; # This is the transition which creates the optionality.
    return
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::union {fa fb {mapvar {}}} {
    # We union the input symbols, then add the states and
    # transitions of the second FA to the first, adding in
    # epsilons for the start and final states as well. When
    # adding states we make sure that the new states do not
    # intersect with the existing states.

    struct::list assign \
	    [MergePrepare $fa $fb union smap] \
	    astart afinal bstart bfinal

    if {$mapvar ne ""} {
	upvar 1 $mapvar map
	set map $smap
    }

    # And now the new start & final states

    set ns [NewState $fa s]
    set nf [NewState $fa f]

    eLink1N $fa $ns $astart
    eLink1N $fa $ns $bstart

    eLinkN1 $fa $afinal $nf
    eLinkN1 $fa $bfinal $nf

    $fa start clear ; $fa start add $ns
    $fa final clear ; $fa final add $nf
    return
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::intersect {fa fb {mapvar {}} {idstart 0}} {
    # Intersection has to run the two automata in parallel, using
    # paired states. If we have start states we begin the
    # construction with them. This leads to a smaller result as we
    # do not have create a full cross-crossproduct. The latter is
    # unfortunately required if there are no start states.

    struct::list assign [CrossPrepare $fa $fb intersection] tmp res

    # The start states of the new FA consist of the cross-product of
    # the start states of fa with fb. These are also the states used
    # to seed DoCross.

    set id $idstart
    set smap {}
    set bstart [$tmp startstates]
    foreach a [$fa startstates] {
	foreach b $bstart {
	    set pair [list $a $b]
	    lappend smap    $id $pair
	    lappend pending $pair $id
	    $res state add $id
	    $res start add $id
	    incr id
	}
    }

    set cp [DoCross $fa $tmp $res $id $pending smap]

    foreach {id pair} $smap {
	struct::list assign $pair a b
	if {[$fa final? $a] && [$tmp final? $b]} {
	    $res final add $id
	}
    }

    # Remove excess states (generated because of the sinks).
    trim $res
    if {$mapvar ne ""} {
	upvar 1 $mapvar map
	# The loop is required to filter out the mappings for all
	# states which were trimmed off.
	set map {}
	foreach {id pair} $smap {
	    if {![$res state exists $id]} continue
	    lappend map $id $pair
	}
    }

    # Copy result into permanent storage and delete all intermediaries
    $fa = $res
    $res destroy
    if {$tmp ne $fb} {$tmp destroy}
    return
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::difference {fa fb {mapvar {}}} {
    # Difference has to run the two automata in parallel, using
    # paired states. Only the final states are defined differently
    # than for intersection. It has to be final in fa and _not_ final
    # in fb to be a final state of the result. <=> Accepted by A, but
    # not B, to be in the difference.

    struct::list assign [CrossPrepare $fa $fb difference] tmp res

    # The start states of the new FA consist of the cross-product of
    # the start states of fa with fb. These are also the states used
    # to seed DoCross.

    set id 0
    set smap {}
    set bstart [$tmp startstates]
    foreach a [$fa startstates] {
	foreach b $bstart {
	    set pair [list $a $b]
	    lappend smap    $id $pair
	    lappend pending $pair $id
	    $res state add $id
	    $res start add $id
	    incr id
	}
    }

    set cp [DoCross $fa $tmp $res $id $pending smap]

    foreach {id pair} $smap {
	struct::list assign $pair a b
	if {[$fa final? $a] && ![$tmp final? $b]} {
	    $res final add $id
	}
    }

    # Remove excess states (generated because of the sinks).
    trim $res
    if {$mapvar ne ""} {
	upvar 1 $mapvar map
	# The loop is required to filter out the mappings for all
	# states which were trimmed off.
	set map {}
	foreach {id pair} $smap {
	    if {![$res state exists $id]} continue
	    lappend map $id $pair
	}
    }

    # Copy result into permanent storage and delete all intermediaries
    $fa = $res
    $res destroy
    if {$tmp ne $fb} {$tmp destroy}
    return
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::concatenate {fa fb {mapvar {}}} {
    # Like union, only the interconnect between existing and new FA is different.

    struct::list assign \
	    [MergePrepare $fa $fb concatenate smap] \
	    astart afinal bstart bfinal

    if {$mapvar ne ""} {
	upvar 1 $mapvar map
	set map $smap
    }

    set ns [NewState $fa s]
    set nm [NewState $fa m] ;# Midpoint.
    set nf [NewState $fa f]

    eLink1N $fa $ns $astart
    eLinkN1 $fa $afinal $nm

    eLink1N $fa $nm $bstart
    eLinkN1 $fa $bfinal $nf

    $fa start clear ; $fa start add $ns
    $fa final clear ; $fa final add $nf
    return
}

# ### ### ### ######### ######### #########
## API implementation. Compilation (regexp -> FA).

proc ::grammar::fa::op::fromRegex {fa regex {over {}}} {
    # Convert a regular expression into a FA. The regex is given as
    # parse tree in the form of a nested list.

    # {. A B ...} ... Concatenation (accepts zero|one arguments).
    # {| A B ...} ... Alternatives  (accepts zero|one arguments).
    # {? A}       ... Optional.
    # {* A}       ... Kleene.
    # {+ A}       ... Pos.Kleene.
    # {! A}       ... Complement/Negation.
    # {S Symbol}  ... Atom, Symbol
    #
    # Recursive descent with a helper ...

    if {![llength $regex]} {
	$fa clear
	return
    }

    set tmp [[cons] %AUTO%]

    if {![llength $over]} {
	set over [lsort -uniq [RESymbols $regex]]
    }
    foreach sym $over {
	$tmp symbol add $sym
    }

    set id 0
    struct::list assign [Regex $tmp $regex id] s f
    $tmp start set [list $s]
    $tmp final set [list $f]

    $fa = $tmp
    $tmp destroy
    return
}

# ### ### ### ######### ######### #########
## Internal helpers.

proc ::grammar::fa::op::RESymbols {regex} {
    set cmd [lindex $regex 0]
    switch -exact -- $cmd {
	? - * - ! - + {
	    return [RESymbols [lindex $regex 1]]
	}
	. - | - & {
	    set res {}
	    foreach sub [lrange $regex 1 end] {
		foreach sym [RESymbols $sub] {lappend res $sym}
	    }
	    return $res
	}
	S {
	    return [list [lindex $regex 1]]
	}
	default {
	    return -code error "Expected . ! ? * | &, or S, got \"$cmd\""
	}
    }
}

proc ::grammar::fa::op::Regex {fa regex idvar} {
    upvar 1 $idvar id
    set cmd [lindex $regex 0]
    switch -exact -- $cmd {
	? {
	    # Optional
	    set a $id ; incr id ; $fa state add $a
	    set b $id ; incr id ; $fa state add $b

	    struct::list assign [Regex $fa [lindex $regex 1] id] s f
	    $fa next $a "" --> $s
	    $fa next $f "" --> $b
	    $fa next $a "" --> $b
	}
	* {
	    # Kleene
	    set a $id ; incr id ; $fa state add $a
	    set b $a

	    struct::list assign [Regex $fa [lindex $regex 1] id] s f
	    $fa next $a "" --> $s
	    $fa next $f "" --> $a ;# == b
	}
	+ {
	    # Pos. Kleene
	    set a $id ; incr id ; $fa state add $a
	    set b $id ; incr id ; $fa state add $b

	    struct::list assign [Regex $fa [lindex $regex 1] id] s f
	    $fa next $a "" --> $s
	    $fa next $f "" --> $b
	    $fa next $b "" --> $a
	}
	! {
	    # Complement.
	    # Build up in a temp FA, complement, and
	    # merge nack into the current

	    set a $id ; incr id ; $fa state add $a
	    set b $id ; incr id ; $fa state add $b

	    set tmp [[cons] %AUTO%]
	    foreach sym [$fa symbols] {$tmp symbol add $sym}
	    struct::list assign [Regex $tmp [lindex $regex 1] id] s f
	    $tmp start add $s
	    $tmp final add $f

	    determinize $tmp {} $id
	    incr id [llength [$tmp states]]
	    if {![$tmp is complete]} {
		complete    $tmp $id
		incr id
	    }
	    complement  $tmp

	    # Merge and link.
	    $fa deserialize_merge [$tmp serialize]

	    eLink1N $fa $a [$tmp startstates]
	    eLinkN1 $fa [$tmp finalstates] $b
	    $tmp destroy
	}
	& {
	    # Intersection ... /And

	    if {[llength $regex] < 3} {
		# Optimized path. Intersection of one sub-expression
		# is the sub-expression itself.

		struct::list assign [Regex $fa [lindex $regex 1] id] a b
	    } else {
		set a $id ; incr id ; $fa state add $a
		set b $id ; incr id ; $fa state add $b

		set tmp [[cons] %AUTO%]
		foreach sym [$fa symbols] {$tmp symbol add $sym}
		set idsub 0
		struct::list assign [Regex $tmp [lindex $regex 1] idsub] s f
		$tmp start add $s
		$tmp final add $f

		set beta [[cons] %AUTO%]
		foreach sub [lrange $regex 2 end] {
		    foreach sym [$fa symbols] {$beta symbol add $sym}
		    struct::list assign [Regex $beta $sub idsub] s f
		    $beta start add $s
		    $beta final add $f
		    intersect $tmp $beta {} $id
		}
		$beta destroy
		determinize $tmp {} $id
		incr id [llength [$tmp states]]

		# Merge and link.
		$fa deserialize_merge [$tmp serialize]

		eLink1N $fa $a [$tmp startstates]
		eLinkN1 $fa [$tmp finalstates] $b
		$tmp destroy
	    }
	}
	. {
	    # Concatenation ...

	    if {[llength $regex] == 1} {
		# Optimized path. No sub-expressions. This represents
		# language containing only the empty string, aka
		# epsilon.

		set a $id ; incr id ; $fa state add $a
		set b $id ; incr id ; $fa state add $b
		$fa next $a "" --> $b

	    } elseif {[llength $regex] == 2} {
		# Optimized path. Concatenation of one sub-expression
		# is the sub-expression itself.

		struct::list assign [Regex $fa [lindex $regex 1] id] a b
	    } else {
		set first 1
		set last {}
		foreach sub [lrange $regex 1 end] {
		    struct::list assign [Regex $fa $sub id] s f
		    if {$first} {set first 0 ; set a $s}
		    if {$last != {}} {
			$fa next $last "" --> $s
		    }
		    set last $f
		}
		set b $f
	    }
	}
	| {
	    # Alternatives ... (Union)

	    if {[llength $regex] == 1} {
		# Optimized path. No sub-expressions. This represents
		# the empty language, i.e. the language without words.

		set a $id ; incr id ; $fa state add $a
		set b $id ; incr id ; $fa state add $b

	    } elseif {[llength $regex] == 2} {
		# Optimized path. Choice/Union of one sub-expression
		# is the sub-expression itself.

		struct::list assign [Regex $fa [lindex $regex 1] id] a b
	    } else {
		set a $id ; incr id ; $fa state add $a
		set b $id ; incr id ; $fa state add $b
		foreach sub [lrange $regex 1 end] {
		    struct::list assign [Regex $fa $sub id] s f
		    $fa next $a "" --> $s
		    $fa next $f "" --> $b
		}
	    }
	}
	S {
	    # Atom, base transition.
	    set sym [lindex $regex 1]
	    set a $id ; incr id ; $fa state add $a
	    set b $id ; incr id ; $fa state add $b
	    $fa next $a $sym --> $b
	}
	default {
	    return -code error "Expected . ! ? * | &, or S, got \"$cmd\""
	}
    }
    return [list $a $b]
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::CrossPrepare {fa fb label} {
    set starta [$fa startstates]
    set finala [$fa finalstates]
    set startb [$fb startstates]
    set finalb [$fb finalstates]
    if {
	![llength $starta] || ![llength $finala] ||
	![llength $startb] || ![llength $finalb]
    } {
	return -code error "Unable to perform the $label of two FAs without start/final states"
    }

    # The inputs are made complete over the union of their symbol
    # sets. A temp. container is used for the second input if necessary.

    set totals [struct::set union [$fa symbols] [$fb symbols]]
    foreach sym [struct::set difference $totals [$fa symbols]] {
	$fa symbol add $sym
    }
    if {![$fa is epsilon-free]} {
	remove_eps $fa
	trim       $fa
    }
    if {![$fa is complete]} {
	complete $fa
    }
    set tmp $fb
    set bnew [struct::set difference $totals [$fb symbols]]
    if {[llength $bnew]} {
	set tmp [[cons] %AUTO% = $fb]
	foreach sym $bnew {
	    $tmp symbol add $sym
	}    
    }
    if {![$fb is epsilon-free]} {
	if {$tmp eq $fb} {set tmp [[cons] %AUTO% = $fb]}
	remove_eps $tmp
	trim       $tmp
    }
    if {![$fb is complete]} {
	if {$tmp eq $fb} {set tmp [[cons] %AUTO% = $fb]}
	complete $tmp
    }

    set res [[cons] %AUTO%]
    foreach sym $totals {
	$res symbol add $sym
    } 

    return [list $tmp $res]
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::DoCross {fa fb res id seed smapvar} {
    upvar 1 $smapvar smap

    set symbols [$fa symbols]
    array set tmp $seed

    set pending $seed
    while {[llength $pending]} {
	set cpair [struct::list shift pending]
	set cid   [struct::list shift pending]

	struct::list assign $cpair a b

	# ASSERT: /res state exists /cid

	# Generate the transitions for the pair, add the resulting
	# destinations to the FA, and schedule them for a visit if
	# they are new.

	foreach sym $symbols {
	    set adestinations [$fa next $a $sym]
	    set bdestinations [$fb next $b $sym]

	    foreach ad $adestinations {
		foreach bd $bdestinations {
		    set dest [list $ad $bd]

		    if {![info exists tmp($dest)]} {
			$res state add $id
			lappend smap $id $dest
			lappend pending $dest $id
			set tmp($dest) $id
			incr id
		    }
		    $res next $cid $sym --> $tmp($dest)
		}
	    }
	}
    }
    return
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::MergePrepare {fa fb label mapvar} {
    upvar 1 $mapvar map

    set starta [$fa startstates]
    set finala [$fa finalstates]
    set startb [$fb startstates]
    set finalb [$fb finalstates]
    if {
	![llength $starta] || ![llength $finala] ||
	![llength $startb] || ![llength $finalb]
    } {
	return -code error "Unable to $label FAs without start/final states"
    }

    # FUTURE: add {*}[symbols], ignore dup's
    foreach sym [$fb symbols] {catch {$fa symbol add $sym}}

    set dup [struct::set intersect [$fa states] [$fb states]]
    if {![llength $dup]} {
	# The states do not overlap. A plain merge of fb is enough to
	# copy the information.

	$fa deserialize_merge [$fb serialize]
	set map {}
    } else {
	# We have duplicate states, therefore we have to remap fb to
	# prevent interference between the two.

	set map {}
	set tmp [[cons] %AUTO% = $fb]
	set id 0
	foreach s $dup {
	    # The renaming process has to ensure that the new name is
	    # in neither fa, nor already in fb as well.
	    while {
		[$fa  state exists $id] ||
		[$tmp state exists $id]
	    } {incr id}
	    $tmp state rename $s $id
	    lappend map $id $s
	    incr id
	}

	set startb [$tmp startstates]
	set finalb [$tmp finalstates]

	$fa deserialize_merge [$tmp serialize]
	$tmp destroy
    }

    return [list $starta $finala $startb $finalb]
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::eLink1N {fa from states} {
    foreach s $states {
	$fa next $from "" --> $s
    }
    return
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::eLinkN1 {fa states to} {
    foreach s $states {
	$fa next $s "" --> $to
    }
    return
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::NewState {fa prefix} {
    set newstate [FindNewState $fa $prefix]
    $fa state add $newstate
    return $newstate
}

# --- --- --- --------- --------- ---------

proc ::grammar::fa::op::FindNewState {fa prefix} {
    #if {![$fa state exists $prefix]} {return $prefix}
    set n 0
    while {[$fa state exists ${prefix}.$n]} {incr n}
    return ${prefix}.$n
}

# ### ### ### ######### ######### #########
## API implementation. Decompilation (FA -> regexp).

proc ::grammar::fa::op::toRegexp {fa} {
    # NOTE: FUTURE - Do not go through the serialization, nor through
    # a matrix. The algorithm can be expressed more directly as
    # operations on the automaton (states and transitions).

    set ET [ser_to_ematrix [$fa serialize]]
    while {[llength $ET] > 2} {
	set ET [matrix_drop_state $ET]
    }
    return [lindex $ET 0 1]
}

proc ::grammar::fa::op::toRegexp2 {fa} {
    # NOTE: FUTURE - See above.
    set ET [ser_to_ematrix [$fa serialize]]
    while {[llength $ET] > 2} {
	set ET [matrix_drop_state $ET re2]
    }
    return [lindex $ET 0 1]
}

# ### ### ### ######### ######### #########
## Internal helpers.

proc ::grammar::fa::op::ser_to_ematrix {ser} {
    if {[lindex $ser 0] ne "grammar::fa"} then {
	error "Expected grammar::fa automaton serialisation"
    }
    set stateL {}
    set n 2; foreach {state des} [lindex $ser 2] {
	lappend stateL $state
	set N($state) $n
	incr n
    }
    set row0 {}
    for {set k 0} {$k<$n} {incr k} {lappend row0 [list |]}
    set res [list $row0 $row0]
    foreach {from des} [lindex $ser 2] {
	set row [lrange $row0 0 1]
	if {[lindex $des 0]} then {lset res 0 $N($from) [list .]}
	if {[lindex $des 1]} then {lset row 1 [list .]}
	foreach to $stateL {set S($to) [list |]}
	foreach {symbol targetL} [lindex $des 2] {
	    if {$symbol eq ""} then {
		set atom [list .]
	    } else {
		set atom [list S $symbol]
	    }
	    foreach to $targetL {lappend S($to) $atom}
	}
	foreach to $stateL {
	    if {[llength $S($to)] == 2} then {
		lappend row [lindex $S($to) 1]
	    } else {
		lappend row $S($to)
	    }
	}
	lappend res $row
    }
    return $res
}

proc ::grammar::fa::op::matrix_drop_state {T_in {ns re1}} {
    set sumcmd ${ns}::|
    set prodcmd ${ns}::.
    set T1 {}
    set lastcol {}
    foreach row $T_in {
	lappend T1 [lreplace $row end end]
	lappend lastcol [lindex $row end]
    }
    set lastrow [lindex $T1 end]
    set T1 [lreplace $T1 end end]
    set b [${ns}::* [lindex $lastcol end]]
    set lastcol [lreplace $lastcol end end]
    set res {}
    foreach row $T1 a $lastcol {
	set newrow {}
	foreach pos $row c $lastrow {
	    lappend newrow [$sumcmd $pos [$prodcmd $a $b $c]]
	}
	lappend res $newrow
    }
    return $res
}

# ### ### ### ######### ######### #########
## Internal helpers. Regexp simplification I.

namespace eval ::grammar::fa::op::re1 {
    namespace export | . {\*}
}

proc ::grammar::fa::op::re1::| {args} {
    set L {}

    # | = Choices.
    # Sub-choices are lifted into the top expression (foreach).
    # Identical choices are reduced to a single term (lsort -uniq).

    foreach re $args {
	switch -- [lindex $re 0] "|" {
	    foreach term [lrange $re 1 end] {lappend L $term}
	} default {
	    lappend L $re
	}
    }
    set L [lsort -unique $L]
    if {[llength $L] == 1} then {
	return [lindex $L 0]
    } else {
	return [linsert $L 0 |]
    }
}

proc ::grammar::fa::op::re1::. {args} {
    set L {}

    # . = Sequence.
    # One element sub-choices are lifted into the top expression.
    # Sub-sequences are lifted into the top expression.

    foreach re $args {
	switch -- [lindex $re 0] "." {
	    foreach term [lrange $re 1 end] {lappend L $term}
	} "|" {
	    if {[llength $re] == 1} then {return $re}
	    lappend L $re
	} default {
	    lappend L $re
	}
    }
    if {[llength $L] == 1} then {
	return [lindex $L 0]
    } else {
	return [linsert $L 0 .]
    }
}

proc ::grammar::fa::op::re1::* {re} {
    # * = Kleene closure.
    # Sub-closures are lifted into the top expression.
    # One-element sub-(choices,sequences) are lifted into the top expression.

    switch -- [lindex $re 0] "|" - "." {
	if {[llength $re] == 1} then {
	    return [list .]
	} else {
	    return [list * $re]
	}
    } "*" {
	return $re
    } default {
	return [list * $re]
    }
}

# ### ### ### ######### ######### #########
## Internal helpers. Regexp simplification II.

namespace eval ::grammar::fa::op::re2 {
    # Inherit choices and kleene-closure from the basic simplifier.

    namespace import [namespace parent]::re1::|
    namespace import [namespace parent]::re1::\\*
}

proc ::grammar::fa::op::re2::. {args} {

    # . = Sequences
    # Sub-sequences are lifted into the top expression.
    # Sub-choices are multiplied out.
    # <Example a(b|c) => ab|ac >

    set L {}
    set n -1
    foreach re $args {
	incr n
	switch -- [lindex $re 0] "." {
	    foreach term [lrange $re 1 end] {lappend L $term}
	} "|" {
	    set res [list |]
	    set L2 [lreplace $args 0 $n]
	    foreach term [lrange $re 1 end] {
		lappend res [eval [list .] $L [list $term] $L2]
	    }
	    return [eval $res]
	} default {
	    lappend L $re
	}
    }
    if {[llength $L] == 1} then {
	return [lindex $L 0]
    } else {
	return [linsert $L 0 .]
    }
}

# ### ### ### ######### ######### #########
## API. Simplification of regular expressions.

proc ::grammar::fa::op::simplifyRegexp {RE0} {
    set RE1 [namespace inscope nonnull $RE0]
    if {[lindex $RE1 0] eq "S" || $RE1 eq "." || $RE1 eq "|"} then {
	return $RE1
    }
    set tmp [grammar::fa %AUTO% fromRegex $RE1]
    $tmp minimize
    set RE1 [toRegexp $tmp]
    $tmp destroy
    if {[string length $RE1] < [string length $RE0]} then {
	set RE0 $RE1
    }
    if {[lindex $RE0 0] eq "S"} then {return $RE0}
    set res [lrange $RE0 0 0]
    foreach branch [lrange $RE0 1 end] {
	lappend res [simplifyRegexp $branch]
    }
    return $res
}

# ### ### ### ######### ######### #########
## Internal helpers.

namespace eval ::grammar::fa::op::nonnull {}

proc ::grammar::fa::op::nonnull::| {args} {
    set also_empty false
    set res [list |]
    foreach branch $args {
	set RE [eval $branch]
	if {[lindex $RE 0] eq "?"} then {
	    set also_empty true
	    set RE [lindex $RE 1]
	}
	switch -- [lindex $RE 0] "|" {
	    eval [lreplace $RE 0 0 lappend res]
	} "." {
	    if {[llength $RE] == 1} then {
		set also_empty true
	    } else {
		lappend res $RE
	    }
	} default {
	    lappend res $RE
	}
    }
    if {!$also_empty} then {return $res}
    foreach branch [lrange $res 1 end] {
	if {[lindex $branch 0] eq "*"} then {return $res}
    }
    if {[llength $res] == 1} then {
	return [list .]
    } elseif {[llength $res] == 2} then {
	return [lreplace $res 0 0 ?]
    } else {
	return [list ? $res]
    }
}

proc ::grammar::fa::op::nonnull::. {args} {
    set res [list .]
    foreach branch $args {
	set RE [eval $branch]
	switch -- [lindex $RE 0] "|" {
	    if {[llength $RE] == 1} then {return $RE}
	    lappend res $RE
	} "." {
	    eval [lreplace $RE 0 0 lappend res]
	} default {
	    lappend res $RE
	}
    }
    return $res
}

proc ::grammar::fa::op::nonnull::* {sub} {
    set RE [eval $sub]
    switch -- [lindex $RE 0] "*" - "?" - "+" {
	return [lreplace $RE 0 0 *]
    } default {
	return [list * $RE]
    }
}

proc ::grammar::fa::op::nonnull::+ {sub} {
    set RE [eval $sub]
    switch -- [lindex $RE 0] "+" {
	return $RE
    } "*" - "?" {
	return [lreplace $RE 0 0 *]
    } default {
	return [list * $RE]
    }
}

proc ::grammar::fa::op::nonnull::? {sub} {
    set RE [eval $sub]
    switch -- [lindex $RE 0] "?" - "*" {
	return $RE
    } "+" {
	return [lreplace $RE 0 0 *]
    } default {
	return [list ? $RE]
    }
}

proc ::grammar::fa::op::nonnull::S {name} {
    return [list S $name]
}

# ### ### ### ######### ######### #########
## API. Translate RE of this package to Tcl REs

proc ::grammar::fa::op::toTclRegexp {re symdict} {
    return [lindex [namespace inscope tclre $re $symdict] 1]
}

# ### ### ### ######### ######### #########
## Internal helpers.

namespace eval ::grammar::fa::op::tclre {}

proc ::grammar::fa::op::tclre::S {name dict} {
    array set A $dict
    if {[info exists A($name)]} then {
	return $A($name)
    } elseif {[string length $name] == 1} then {
	if {[regexp {[\\\[\]{}.()*+?^$]} $name]} then {
	    return [list char \\$name]
	} else {
	    return [list char $name]
	}
    } else {
	return [list class "\[\[:${name}:\]\]"]
    }
}

proc ::grammar::fa::op::tclre::. {args} {
    set suffix [lrange $args end end]
    set L {}
    foreach factor [lrange $args 0 end-1] {
	set pair [eval $factor $suffix]
	switch -- [lindex $pair 0] "sum" {
	    lappend L ([lindex $pair 1])
	} default {
	    lappend L [lindex $pair 1]
	}
    }
    return [list prod [join $L ""]]
}

proc ::grammar::fa::op::tclre::* {re dict} {
    set pair [eval $re [list $dict]]
    switch -- [lindex $pair 0] "sum" - "prod" {
	return [list prod "([lindex $pair 1])*"]
    } default {
	return [list prod "[lindex $pair 1]*"]
    }
}

proc ::grammar::fa::op::tclre::+ {re dict} {
    set pair [eval $re [list $dict]]
    switch -- [lindex $pair 0] "sum" - "prod" {
	return [list prod "([lindex $pair 1])+"]
    } default {
	return [list prod "[lindex $pair 1]+"]
    }
}

proc ::grammar::fa::op::tclre::? {re dict} {
    set pair [eval $re [list $dict]]
    switch -- [lindex $pair 0] "sum" - "prod" {
	return [list prod "([lindex $pair 1])?"]
    } default {
	return [list prod "[lindex $pair 1]?"]
    }
}

proc ::grammar::fa::op::tclre::| {args} {
    set suffix [lrange $args end end]
    set charL {}
    set classL {}
    set prodL {}
    foreach factor [lrange $args 0 end-1] {
	set pair [eval $factor $suffix]
	switch -- [lindex $pair 0] "char" {
	    lappend charL [lindex $pair 1]
	} "class" {
	    lappend classL [string range [lindex $pair 1] 1 end-1]
	} default {
	    lappend prodL [lindex $pair 1]
	}
    }
    if {[llength $charL]>1 || [llength $classL]>0} then {
	while {[set n [lsearch $charL -]] >= 0} {
	    lset charL $n {\-}
	}
	set bracket "\[[join $charL ""][join $classL ""]\]"
	if {![llength $prodL]} then {
	    return [list atom $bracket]
	}
	lappend prodL $bracket
    } else {
	eval [list lappend prodL] $charL
    }
    return [list sum [join $prodL |]]
}

proc ::grammar::fa::op::tclre::& {args} {
    error "Cannot express language intersection in Tcl-RE's"

    # Note: This can be translated by constructing an automaton for
    # the intersection, and then translating its conversion to a
    # regular expression.
}

proc ::grammar::fa::op::tclre::! {args} {
    error "Cannot express language complementation in Tcl-RE's"

    # Note: This can be translated by constructing an automaton for
    # the complement, and then translating its conversion to a regular
    # expression. This however requires knowledge regarding the set of
    # symbols. Large (utf-8) for Tcl regexes.
}

# ### ### ### ######### ######### #########

proc ::grammar::fa::op::constructor {cmd} {
    variable cons $cmd
    return
}

proc ::grammar::fa::op::cons {} {
    variable cons
    if {$cons ne ""} {return $cons}
    return -code error "No constructor for FA container was established."
}

# ### ### ### ######### ######### #########
## Package Management

package provide grammar::fa::op 0.4.1
