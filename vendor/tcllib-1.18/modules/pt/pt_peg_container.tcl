# -*- tcl -*-
#
# Copyright (c) 2009 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Grammars / Parsing Expression Grammars / Container

# ### ### ### ######### ######### #########
## Package description

# A class whose instances hold all the information describing a single
# parsing expression grammar (terminal symbols, nonterminal symbols,
# nonterminal rules, start expression, parsing hints (called 'mode')),
# and operations to define, manipulate, and query this information.
#
# Note that the container provides no higher-level operations on the
# grammar, like the removal of unreachable nonterminals, rule
# rewriting, etc.
#
# The set of terminal symbols is the set of characters (i.e.
# implicitly defined). For Tcl this means that all the unicode
# characters are supported.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require snit               ; # Tcllib | OO system used
package require pt::pe             ; # PE serialization
package require pt::peg ; # PEG serialization

# ### ### ### ######### ######### #########
## Implementation

snit::type ::pt::peg::container {
    # Concepts:
    # - A parsing expression grammar consists of a start (parsing)
    #   expression, and a set of nonterminal symbol with their
    #   definitions.
    # - The definition of each nonterminal symbol consists of its
    #   name, semantic made, and sentennial structure, the latter
    #   provided by a parsing expression.
    # - The nonterminal symbols are identified by their name, and each
    #   can occur at most once.

    # ### ### ### ######### ######### #########
    ## Options

    ## None

    # ### ### ### ######### ######### #########
    ## Instance API

    constructor {args} {}

    # Bulk deletion.
    method clear {} {}

    # Bulk copying.
    method =                {source}           {} ; # Assign contents
						    # of source object
						    # to us.
    method -->              {destination}      {} ; # Assign our
						    # contents to the
						    # destination
						    # object.
    method serialize        {{format {}}}      {} ; # Return our
						    # contents in the
						    # specified format
						    # (By default the
						    # canonical
						    # serialization).
    method {deserialize =}  {data {format {}}} {} ; # Assign contents
						    # in format to us
						    # (By default a
						    # regular
						    # serialization).
    method {deserialize +=} {data {format {}}} {} ; # Add contents in
						    # format to us (By
						    # default a
						    # regular
						    # serialization).

    # Bulk queries
    method nonterminals {}          {} ; # Return set of known symbols
    method modes        {{dict {}}} {} ; # Query/set dict (sym -> mode)
    method rules        {{dict {}}} {} ; # Query/set dict (sym -> rhs)

    # Start expression
    method start {{pe {}}} {} ; # Query/set start expression.

    # Non-terminal manipulation and querying
    method add    {args}         {} ; # Add new nonterminals, default
				      # rhs and modes.
    method remove {args}         {} ; # Remove nonterminals, and
				      # associated data.
    method exists {nt}           {} ; # Check if nonterminal is known.
    method rename {nt ntnew}     {} ; # Rename a nonterminal
    method mode   {nt {mode {}}} {} ; # Query/set nonterminal mode
    method rule   {nt {rule {}}} {} ; # Query/set nonterminal rhs

    # Administrative data
    method importer {{object {}}} {} ; # Query/set import manager.
    method exporter {{object {}}} {} ; # Query/set export manager.

    # ### ### ### ######### ######### #########
    ## Instance API Implementation.

    constructor {args} {
	$self clear

	if {
	    (([llength $args] != 0) && ([llength $args] != 2)) ||
	    (([llength $args] == 2) && ([lindex $args 0] ni {= := <-- as deserialize}))
	} {
	    return -code error "wrong#args: $self ?=|:=|<--|as|deserialize a'?"
	}

	# Serialization arguments.
	# [llength args] in {0 2}
	#
	# =           src-obj
	# :=          src-obj
	# <--         src-obj
	# as          src-obj
	# deserialize src-value

	if {[llength $args] == 2} {
	    foreach {op val} $args break
	    switch -exact -- $op {
		= - := - <-- - as {
		    $self deserialize = [$val serialize]
		}
		deserialize {
		    $self deserialize = $val
		}
	    }
	}
	return
    }

    # Default destructor.

    # ### ### ### ######### ######### #########

    method invalidate {} {
	array unset mypeg *
	return
    }

    # ### ### ### ######### ######### #########
    ## Administrative data

    method exporter {{object {}}} {
	# TODO :: unlink/link change notification callbacks on the
	# config/include components so that we can invalidate our
	# cache when the settings change.

	if {[llength [info level 0]] == 6} {
	    set myexporter $object
	}
	return $myexporter
    }

    method importer {{object {}}} {
	if {[llength [info level 0]] == 6} {
	    set myimporter $object
	}
	return $myimporter
    }

    # ### ### ### ######### ######### #########
    ## Direct manipulation of the grammar.

    ## Bulk deletion

    method clear {} {
	array unset myrhs     *
	array unset mymode    *
	set mystartpe [pt::pe epsilon]
	return
    }

    ## Bulk queries

    method nonterminals {} {
	return [array names myrhs]
    }

    method modes {{dict {}}} {
	if {[llength [info level 0]] == 6} {
	    VerifyAsKnown [dict keys $dict]
	    foreach mode [dict values $dict] {
		if {![info exists ourmode($mode)]} {
		    set ours [linsert [join [lsort -dict [array names ourmode]] ", "] end-1 or]
		    return -code error "Expected one of $ours, got \"$mode\""
		}
	    }
	    array set mymode $dict
	    return
	}
	return [array get mymode]
    }

    method rules {{dict {}}} {
	if {[llength [info level 0]] == 6} {
	    VerifyAsKnown [dict keys $dict]
	    foreach {nt pe} $dict {
	        lappend tmp $nt [pt::pe canonicalize $pe]
	    }
	    array set myrhs $tmp
	    return
	}
	return [array get myrhs]
    }

    ## Start expression

    method start {{pe {}}} {
	if {[llength [info level 0]] == 6} {
	    set mystartpe [pt::pe canonicalize $pe]
	    return
	}
	return $mystartpe
    }

    ## Non-terminal manipulation and querying

    method add {args} {
	if {![llength $args]} return
	VerifyAsUnknown $args
	foreach nt $args {
	    set myrhs($nt)  [pt::pe epsilon]
	    set mymode($nt) value
	}
	return
    }

    method remove {args} {
	if {![llength $args]} return
	VerifyAsKnown $args
	foreach nt $args {
	    unset myrhs($nt)
	    unset mymode($nt)
	}
	return
    }

    method exists {nt} {
	if {$nt eq {}} {
	    return -code error "Expected nonterminal name, got the empty string"
	}
	return [info exists myrhs($nt)]
    }

    method rename {ntold ntnew} {
	VerifyAsKnown1   $ntold
	VerifyAsUnknown1 $ntnew

	# We have to go through all rules and rewrite their RHS to use
	# the new name of the nonterminal.

	set myrhs($ntnew)  $myrhs($ntold)
	unset               myrhs($ntold)
	set mymode($ntnew) $mymode($ntold)
	unset               mymode($ntold)

	foreach nt [array names myrhs] {
	    set myrhs($nt) [pt::pe rename \
			       $myrhs($nt) $ntold $ntnew]
	}
	return
    }

    method mode {nt {mode {}}} {
	VerifyAsKnown1 $nt
	if {[llength [info level 0]] == 7} {
	    if {![info exists ourmode($mode)]} {
		set ours [linsert [join [lsort -dict [array names ourmode]] ", "] end-1 or]
		return -code error "Expected one of $ours, got \"$mode\""
	    }
	    set mymode($nt) $mode
	}
	return $mymode($nt)
    }

    method rule {nt {pe {}}} {
	VerifyAsKnown1 $nt
	if {[llength [info level 0]] == 7} {
	    set myrhs($nt) [pt::pe canonicalize $pe]
	}
	return $myrhs($nt)
    }

    # ### ### ### ######### ######### #########
    ## Public methods. Bulk loading and merging.

    method = {source} {
	$self deserialize [$source serialize]
	return
    }

    method --> {destination} {
	$destination deserialize [$self serialize]
	return
    }

    # ### ### ### ######### ######### #########

    method serialize {{format {}}} {
	# Default format is the regular PEG serialization
	if {[llength [info level 0]] == 5} {
	    set format serial
	}

	# First check the cache for a remebered representation of the
	# index for the chosen format, and return it, if such is
	# known.

	if {[info exists mypeg($format)]} {
	    return $mypeg($format)
	}

	# If there is no cached representation we have to generate it
	# from it from our internal representation.

	if {$format eq "serial"} {
	    return [$self GenerateSerial]
	} else {
	    return [$self Generate $format]
	}

	return -code error "Internal error, reached unreachable location"
    }

    # ### ### ### ######### ######### #########

    method {deserialize =} {data {format {}}} {
	# Default format is the regular PEG serialization
	if {[llength [info level 0]] == 6} {
	    set format serial
	}

	if {$format ne "serial"} {
	    set data [$self Import $format $data]
	    # pt::peg verify-as-canonical $data
	    # ImportSerial verifies.
	}

	$self ImportSerial $data
	return
    }

    method {deserialize +=} {data {format {}}} {
	# Default format is the regular PEG serialization
	if {[llength [info level 0]] == 6} {
	    set format serial
	}

	if {$format ne "serial"} {
	    set data [$self Import $format $data]
	    # pt::peg verify-as-canonical $data
	    # merge or ImportSerial verify the structure.
	}

	set data [pt::peg merge [$self serialize] $data]
	# pt::peg verify-as-canonical $data
	# ImportSerial verifies.

	$self ImportSerial $data
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal methods

    proc VerifyAsKnown1 {nt} {
	upvar 1 myrhs myrhs
	if {$nt eq {}} {
	    return -code error "Expected nonterminal name, got the empty string"
	}
	if {![info exists myrhs($nt)]} {
	    return -code error "Invalid nonterminal \"$nt\""
	}
	return
    }

    proc VerifyAsUnknown1 {nt} {
	upvar 1 myrhs myrhs
	if {$nt eq {}} {
	    return -code error "Expected nonterminal name, got the empty string"
	}
	if {[info exists myrhs($nt)]} {
	    return -code error "Nonterminal \"$nt\" is already known"
	}
	return
    }

    proc VerifyAsKnown {ntlist} {
	upvar 1 myrhs myrhs
	foreach nt $ntlist {
	    if {$nt eq {}} {
		return -code error "Expected nonterminal name, got the empty string"
	    }
	    if {![info exists myrhs($nt)]} {
		return -code error "Invalid nonterminal \"$nt\""
	    }
	}
	return
    }

    proc VerifyAsUnknown {ntlist} {
	upvar 1 myrhs myrhs
	foreach nt $ntlist {
	    if {$nt eq {}} {
		return -code error "Expected nonterminal name, got the empty string"
	    }
	    if {[info exists myrhs($nt)]} {
		return -code error "Nonterminal \"$nt\" is already known"
	    }
	}
	return
    }

    # ### ### ### ######### ######### #########

    method GenerateSerial {} {
	# We can generate the list serialization easily from the
	# internal representation.

	# Construct result. inside out
	set rules {}
	foreach nt [lsort -dict [array names myrhs]] {
	    lappend rules $nt [list \
				   is   $myrhs($nt) \
				   mode $mymode($nt)]
	}

	set serial [list pt::grammar::peg \
			[list \
			     rules $rules \
			     start $mystartpe]]

	# This is just present to assert that the code above creates
	# correct serializations.
	pt::peg verify-as-canonical $serial

	set mypeg(serial) $serial
	return $serial
    }

    method Generate {format} {
	if {$myexporter eq {}} {
	    return -code error "Unable to export from \"$format\", no exporter configured"
	}
	set res [$myexporter export object $self $format]
	set mypeg($format) $res
	return $res
    }

    # ### ### ### ######### ######### #########

    method ImportSerial {serial} {
	pt::peg verify $serial iscanonical

	# Kill existing content
	$self clear

	# Unpack the serialization.
	array set peg $serial
	array set peg $peg(pt::grammar::peg)
	unset     peg(pt::grammar::peg)

	# We are setting the relevant variables directly instead of
	# going through the accessor methods.

	set mystartpe $peg(start)

	foreach {nt def} $peg(rules) {
	    array set sd $def
	    set myrhs($nt)  $sd(is)
	    set mymode($nt) $sd(mode)
	    unset sd
	}

	# Extend cache (only if canonical, as we return only canonical
	# data).
	if {$iscanonical} {
	    set mypeg(serial) $serial
	}
	return
    }

    method Import {format data} {
	if {$myimporter eq {}} {
	    return -code error "Unable to import from \"$format\", no importer configured"
	}

	return [$myimporter import text $data $format]
    }

    # ### ### ### ######### ######### #########
    ## State

    # References the to export/import managers extending the
    # (de)serialization abilities of the grammar.

    variable myexporter {}
    variable myimporter {}

    # Internal representation of the grammar.

    variable mystartpe        {} ; # Start parsing expression.
    variable myrhs     -array {} ; # Right hand side (parsing
				   # expression)s for the known
				   # nonterminal symbols.
    variable mymode    -array {} ; # Modes for the known nonterminal
				   # symols.

    typevariable ourmode -array {
	value   .
	leaf    .
	void    .
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Package Management

package provide pt::peg::container 1
