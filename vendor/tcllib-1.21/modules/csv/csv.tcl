# csv.tcl --
#
#	Tcl implementations of CSV reader and writer
#
# Copyright (c) 2001      by Jeffrey Hobbs
# Copyright (c) 2001-2013 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: csv.tcl,v 1.28 2011/11/23 02:22:10 andreas_kupries Exp $

package require Tcl 8.4
package provide csv 0.8.1

namespace eval ::csv {
    namespace export join joinlist read2matrix read2queue report 
    namespace export split split2matrix split2queue writematrix writequeue
}

# ::csv::join --
#
#	Takes a list of values and generates a string in CSV format.
#
# Arguments:
#	values	A list of the values to join
#	sepChar	The separator character, defaults to comma
#	delChar	The delimiter character, defaults to quote
#	delMode	If set to 'always', values are always surrounded by delChar
#
# Results:
#	A string containing the values in CSV format.

proc ::csv::join {values {sepChar ,} {delChar \"} {delMode auto}} {
    set out ""
    set sep {}
    foreach val $values {
	if {($delMode eq "always") || [string match "*\[${delChar}$sepChar\r\n\]*" $val]} {
	    append out $sep${delChar}[string map [list $delChar ${delChar}${delChar}] $val]${delChar}
	} else {
	    append out $sep${val}
	}
	set sep $sepChar
    }
    return $out
}

# ::csv::joinlist --
#
#	Takes a list of lists of values and generates a string in CSV
#	format. Each item in the list is made into a single CSV
#	formatted record in the final string, the records being
#	separated by newlines.
#
# Arguments:
#	values	A list of the lists of the values to join
#	sepChar	The separator character, defaults to comma
#	delChar	The delimiter character, defaults to quote
#	delMode	If set to 'always', values are always surrounded by delChar
#
# Results:
#	A string containing the values in CSV format, the records
#	separated by newlines.

proc ::csv::joinlist {values {sepChar ,} {delChar \"} {delMode auto}} {
    set out ""
    foreach record $values {
	# note that this is ::csv::join
	append out "[join $record $sepChar $delChar $delMode]\n"
    }
    return $out
}

# ::csv::joinmatrix --
#
#	Takes a matrix object following the API specified for the
#	struct::matrix package. Each row of the matrix is converted
#	into a single CSV formatted record in the final string, the
#	records being separated by newlines.
#
# Arguments:
#	matrix	Matrix object command.
#	sepChar	The separator character, defaults to comma
#	delChar	The delimiter character, defaults to quote
#	delMode	If set to 'always', values are always surrounded by delChar
#
# Results:
#	A string containing the values in CSV format, the records
#	separated by newlines.

proc ::csv::joinmatrix {matrix {sepChar ,} {delChar \"} {delMode auto}} {
    return [joinlist [$matrix get rect 0 0 end end] $sepChar $delChar $delMode]
}

# ::csv::iscomplete --
#
#	A predicate checking if the argument is a complete csv record.
#
# Arguments
#	data	The (partial) csv record to check.
#
# Results:
#	A boolean flag indicating the completeness of the data. The
#	result is true if the data is complete.

proc ::csv::iscomplete {data} {
    expr {1 - [regexp -all \" $data] % 2}
}

# ::csv::read2matrix --
#
#	A wrapper around "Split2matrix" reading CSV formatted
#	lines from the specified channel and adding it to the given
#	matrix.
#
# Arguments:
#	m		The matrix to add the read data too.
#	chan		The channel to read from.
#	sepChar		The separator character, defaults to comma
#	expand		The expansion mode. The default is none
#
# Results:
#	A list of the values in 'line'.

proc ::csv::read2matrix {args} {
    # FR #481023
    # See 'split2matrix' for the available expansion modes.

    # Argument syntax:
    #
    #2)            chan m
    #3)            chan m sepChar
    #3) -alternate chan m
    #4) -alternate chan m sepChar
    #4)            chan m sepChar expand
    #5) -alternate chan m sepChar expand

    set alternate 0
    set sepChar   ,
    set expand    none

    switch -exact -- [llength $args] {
	2 {
	    foreach {chan m} $args break
	}
	3 {
	    foreach {a b c} $args break
	    if {[string equal $a "-alternate"]} {
		set alternate 1
		set chan      $b
		set m         $c
	    } else {
		set chan    $a
		set m       $b
		set sepChar $c
	    }
	}
	4 {
	    foreach {a b c d} $args break
	    if {[string equal $a "-alternate"]} {
		set alternate 1
		set chan      $b
		set m         $c
		set sepChar   $d
	    } else {
		set chan    $a
		set m       $b
		set sepChar $c
		set expand  $d
	    }
	}
	5 {
	    foreach {a b c d e} $args break
	    if {![string equal $a "-alternate"]} {
		return -code error "wrong#args: Should be ?-alternate? chan m ?separator? ?expand?"
	    }
	    set alternate 1

	    set chan    $b
	    set m       $c
	    set sepChar $d
	    set expand  $e
	}
	0 - 1 -
	default {
	    return -code error "wrong#args: Should be ?-alternate? chan m ?separator? ?expand?"
	}
    }

    if {[string length $sepChar] < 1} {
	return -code error "illegal separator character \"$sepChar\", is empty"
    } elseif {[string length $sepChar] > 1} {
	return -code error "illegal separator character \"$sepChar\", is a string"
    }

    set data ""
    while {![eof $chan]} {
	if {[gets $chan line] < 0} {continue}

	# Why skip empty lines? They may be in data. Except if the
	# buffer is empty, i.e. we are between records.
	if {$line == {} && $data == {}} {continue}

       append data $line
       if {![iscomplete $data]} {
           # Odd number of quotes - must have embedded newline
           append data \n
           continue
       }

       Split2matrix $alternate $m $data $sepChar $expand
       set data ""
    }
    return
}

# ::csv::read2queue --
#
#	A wrapper around "::csv::split2queue" reading CSV formatted
#	lines from the specified channel and adding it to the given
#	queue.
#
# Arguments:
#	q		The queue to add the read data too.
#	chan		The channel to read from.
#	sepChar		The separator character, defaults to comma
#
# Results:
#	A list of the values in 'line'.

proc ::csv::read2queue {args} {
    # Argument syntax:
    #
    #2)            chan q
    #3)            chan q sepChar
    #3) -alternate chan q
    #4) -alternate chan q sepChar

    set alternate 0
    set sepChar   ,

    switch -exact -- [llength $args] {
	2 {
	    foreach {chan q} $args break
	}
	3 {
	    foreach {a b c} $args break
	    if {[string equal $a "-alternate"]} {
		set alternate 1
		set chan      $b
		set q         $c
	    } else {
		set chan    $a
		set q       $b
		set sepChar $c
	    }
	}
	4 {
	    foreach {a b c d} $args break
	    if {![string equal $a "-alternate"]} {
		return -code error "wrong#args: Should be ?-alternate? chan q ?separator?"
	    }
	    set alternate 1
	    set chan    $b
	    set q       $c
	    set sepChar $d
	}
	0 - 1 -
	default {
	    return -code error "wrong#args: Should be ?-alternate? chan q ?separator?"
	}
    }

    if {[string length $sepChar] < 1} {
	return -code error "illegal separator character \"$sepChar\", is empty"
    } elseif {[string length $sepChar] > 1} {
	return -code error "illegal separator character \"$sepChar\", is a string"
    }

    set data ""
    while {![eof $chan]} {
	if {[gets $chan line] < 0} {continue}

	# Why skip empty lines? They may be in data. Except if the
	# buffer is empty, i.e. we are between records.
	if {$line == {} && $data == {}} {continue}

	append data $line
	if {![iscomplete $data]} {
	    # Odd number of quotes - must have embedded newline
	    append data \n
	    continue
	}

	$q put [Split $alternate $data $sepChar]
	set data ""
    }
    return
}

# ::csv::report --
#
#	A report command which can be used by the matrix methods
#	"format-via" and "format2chan-via". For the latter this
#	command delegates the work to "::csv::writematrix". "cmd" is
#	expected to be either "printmatrix" or
#	"printmatrix2channel". The channel argument, "chan", has to
#	be present for the latter and must not be present for the first.
#
# Arguments:
#	cmd		Either 'printmatrix' or 'printmatrix2channel'
#	matrix		The matrix to format.
#	args		0 (chan): The channel to write to
#
# Results:
#	None for 'printmatrix2channel', else the CSV formatted string.

proc ::csv::report {cmd matrix args} {
    switch -exact -- $cmd {
	printmatrix {
	    if {[llength $args] > 0} {
		return -code error "wrong # args:\
			::csv::report printmatrix matrix"
	    }
	    return [joinlist [$matrix get rect 0 0 end end]]
	}
	printmatrix2channel {
	    if {[llength $args] != 1} {
		return -code error "wrong # args:\
			::csv::report printmatrix2channel matrix chan"
	    }
	    writematrix $matrix [lindex $args 0]
	    return ""
	}
	default {
	    return -code error "Unknown method $cmd"
	}
    }
}

# ::csv::split --
#
#	Split a string according to the rules for CSV processing.
#	This assumes that the string contains a single line of CSVs
#
# Arguments:
#	line		The string to split
#	sepChar		The separator character, defaults to comma
#
# Results:
#	A list of the values in 'line'.

proc ::csv::split {args} {
    # Argument syntax:
    #
    # (1)            line
    # (2)            line sepChar
    # (2) -alternate line
    # (3) -alternate line sepChar

    # (3)            line sepChar delChar
    # (4) -alternate line sepChar delChar

    set alternate 0
    set sepChar   ,
    set delChar   \"

    switch -exact -- [llength $args] {
	1 {
	    set line [lindex $args 0]
	}
	2 {
	    foreach {a b} $args break
	    if {[string equal $a "-alternate"]} {
		set alternate 1
		set line     $b
	    } else {
		set line    $a
		set sepChar $b
	    }
	}
	3 {
	    foreach {a b c} $args break
	    if {[string equal $a "-alternate"]} {
	        set alternate 1
		set line    $b
		set sepChar $c
	    } else {
		set line    $a
		set sepChar $b
		set delChar $c
            }
	}
	4 {
	    foreach {a b c d} $args break
	    if {![string equal $a "-alternate"]} {
		return -code error "wrong#args: Should be ?-alternate? line ?separator? ?delimiter?"
	    }
	    set alternate 1
	    set line    $b
	    set sepChar $c
	    set delChar $d
	}
	0 -
	default {
	    return -code error "wrong#args: Should be ?-alternate? line ?separator? ?delimiter?"
	}
    }

    if {[string length $sepChar] < 1} {
	return -code error "illegal separator character ${delChar}$sepChar${delChar}, is empty"
    } elseif {[string length $sepChar] > 1} {
	return -code error "illegal separator character ${delChar}$sepChar${delChar}, is a string"
    }

    if {[string length $delChar] < 1} {
	return -code error "illegal separator character \"$delChar\", is empty"
    } elseif {[string length $delChar] > 1} {
	return -code error "illegal separator character \"$delChar\", is a string"
    }

    return [Split $alternate $line $sepChar $delChar]
}

proc ::csv::Split {alternate line sepChar {delChar \"}} {
    # Protect the sepchar from special interpretation by
    # the regex calls below.

    set sepRE \[\[.${sepChar}.]]
    set delRE \[\[.${delChar}.]]

    if {$alternate} {
	# The alternate syntax requires a different parser.
	# A variation of the string map / regsub parser for the
	# regular syntax was tried but does not handle embedded
	# doubled " well (testcase csv-91.3 was 'knownBug', sole
	# one, still a bug). Now we just tokenize the input into
	# the primary parts (sep char, "'s and the rest) and then
	# use an explicitly coded state machine (DFA) to parse
	# and convert token sequences.

	## puts 1->>$line<<
	set line [string map [list \
		$sepChar \0$sepChar\0 \
		$delChar \0${delChar}\0 \
		] $line]

	## puts 2->>$line<<
	set line [string map [list \0\0 \0] $line]
	regsub "^\0" $line {} line
	regsub "\0$" $line {} line

	## puts 3->>$line<<

	set val ""
	set res ""
	set state base

	## puts 4->>[::split $line \0]
	foreach token [::split $line \0] {

	    ## puts "\t*= $state\t>>$token<<"
	    switch -exact -- $state {
		base {
		    if {[string equal $token "${delChar}"]} {
			set state qvalue
			continue
		    }
		    if {[string equal $token $sepChar]} {
			lappend res $val
			set val ""
			continue
		    }
		    append val $token
		}
		qvalue {
		    if {[string equal $token "${delChar}"]} {
			# May end value, may be a doubled "
			set state endordouble
			continue
		    }
		    append val $token
		}
		endordouble {
		    if {[string equal $token "${delChar}"]} {
			# Doubled ", append to current value
			append val ${delChar} 
			set state qvalue
			continue
		    }
		    # Last " was end of quoted value. Close it.
		    # We expect current as $sepChar

		    lappend res $val
		    set          val ""
		    set state base

		    if {[string equal $token $sepChar]} {continue}

		    # Undoubled " in middle of text. Just assume that
		    # remainder is another qvalue.
		    set state qvalue
		}
		default {
		    return -code error "Internal error, illegal parsing state"
		}
	    }
	}

	## puts "/= $state\t>>$val<<"

	lappend res $val

	## puts 5->>$res<<
	return $res
    } else {
	regsub -- "$sepRE${delRE}${delRE}$" $line $sepChar\0${delChar}${delChar}\0 line
	regsub -- "^${delRE}${delRE}$sepRE" $line \0${delChar}${delChar}\0$sepChar line
	regsub -all -- {(^${delChar}|${delChar}$)} $line \0 line

	set line [string map [list \
		$sepChar${delChar}${delChar}${delChar} $sepChar\0${delChar} \
		${delChar}${delChar}${delChar}$sepChar ${delChar}\0$sepChar \
		${delChar}${delChar}           ${delChar} \
		${delChar}             \0 \
		] $line]

	set end 0
	while {[regexp -indices -start $end -- {(\0)[^\0]*(\0)} $line \
		-> start end]} {
	    set start [lindex $start 0]
	    set end   [lindex $end 0]
	    set range [string range $line $start $end]
	    if {[string first $sepChar $range] >= 0} {
		set line [string replace $line $start $end \
			[string map [list $sepChar \1] $range]]
	    }
	    incr end
	}
	set line [string map [list $sepChar \0 \1 $sepChar \0 {} ] $line]
	return [::split $line \0]

    }
}

# ::csv::split2matrix --
#
#	Split a string according to the rules for CSV processing.
#	This assumes that the string contains a single line of CSVs.
#	The resulting list of values is appended to the specified
#	matrix, as a new row. The code assumes that the matrix provides
#	the same interface as the queue provided by the 'struct'
#	module of tcllib, "add row" in particular.
#
# Arguments:
#	m		The matrix to write the resulting list to.
#	line		The string to split
#	sepChar		The separator character, defaults to comma
#	expand		The expansion mode. The default is none
#
# Results:
#	A list of the values in 'line', written to 'q'.

proc ::csv::split2matrix {args} {
    # FR #481023

    # Argument syntax:
    #
    #2)            m line
    #3)            m line sepChar
    #3) -alternate m line
    #4) -alternate m line sepChar
    #4)            m line sepChar expand
    #5) -alternate m line sepChar expand

    set alternate 0
    set sepChar   ,
    set expand    none

    switch -exact -- [llength $args] {
	2 {
	    foreach {m line} $args break
	}
	3 {
	    foreach {a b c} $args break
	    if {[string equal $a "-alternate"]} {
		set alternate 1
		set m         $b
		set line      $c
	    } else {
		set m       $a
		set line    $b
		set sepChar $c
	    }
	}
	4 {
	    foreach {a b c d} $args break
	    if {[string equal $a "-alternate"]} {
		set alternate 1
		set m         $b
		set line      $c
		set sepChar   $d
	    } else {
		set m       $a
		set line    $b
		set sepChar $c
		set expand  $d
	    }
	}
	4 {
	    foreach {a b c d e} $args break
	    if {![string equal $a "-alternate"]} {
		return -code error "wrong#args: Should be ?-alternate? m line ?separator? ?expand?"
	    }
	    set alternate 1

	    set m       $b
	    set line    $c
	    set sepChar $d
	    set expand  $e
	}
	0 - 1 -
	default {
	    return -code error "wrong#args: Should be ?-alternate? m line ?separator? ?expand?"
	}
    }

    if {[string length $sepChar] < 1} {
	return -code error "illegal separator character \"$sepChar\", is empty"
    } elseif {[string length $sepChar] > 1} {
	return -code error "illegal separator character \"$sepChar\", is a string"
    }

    Split2matrix $alternate $m $line $sepChar $expand
    return
}

proc ::csv::Split2matrix {alternate m line sepChar expand} {
    set csv [Split $alternate $line $sepChar]

    # Expansion modes
    # - none  : default, behaviour of original implementation.
    #           no expansion is done, lines are silently truncated
    #           to the number of columns in the matrix.
    #
    # - empty : A matrix without columns is expanded to the number
    #           of columns in the first line added to it. All
    #           following lines are handled as if "mode == none"
    #           was set.
    #
    # - auto  : Full auto-mode. The matrix is expanded as needed to
    #           hold all columns of all lines.

    switch -exact -- $expand {
	none {}
	empty {
	    if {[$m columns] == 0} {
		$m add columns [llength $csv]
	    }
	}
	auto {
	    if {[$m columns] < [llength $csv]} {
		$m add columns [expr {[llength $csv] - [$m columns]}]
	    }
	}
    }
    $m add row $csv
    return
}

# ::csv::split2queue --
#
#	Split a string according to the rules for CSV processing.
#	This assumes that the string contains a single line of CSVs.
#	The resulting list of values is appended to the specified
#	queue, as a single item. IOW each item in the queue represents
#	a single CSV record. The code assumes that the queue provides
#	the same interface as the queue provided by the 'struct'
#	module of tcllib, "put" in particular.
#
# Arguments:
#	q		The queue to write the resulting list to.
#	line		The string to split
#	sepChar		The separator character, defaults to comma
#
# Results:
#	A list of the values in 'line', written to 'q'.

proc ::csv::split2queue {args} {
    # Argument syntax:
    #
    #2)            q line
    #3)            q line sepChar
    #3) -alternate q line
    #4) -alternate q line sepChar

    set alternate 0
    set sepChar   ,

    switch -exact -- [llength $args] {
	2 {
	    foreach {q line} $args break
	}
	3 {
	    foreach {a b c} $args break
	    if {[string equal $a "-alternate"]} {
		set alternate 1
		set q         $b
		set line      $c
	    } else {
		set q       $a
		set line    $b
		set sepChar $c
	    }
	}
	4 {
	    foreach {a b c d} $args break
	    if {![string equal $a "-alternate"]} {
		return -code error "wrong#args: Should be ?-alternate? q line ?separator?"
	    }
	    set alternate 1

	    set q       $b
	    set line    $c
	    set sepChar $d
	}
	0 - 1 -
	default {
	    return -code error "wrong#args: Should be ?-alternate? q line ?separator?"
	}
    }

    if {[string length $sepChar] < 1} {
	return -code error "illegal separator character \"$sepChar\", is empty"
    } elseif {[string length $sepChar] > 1} {
	return -code error "illegal separator character \"$sepChar\", is a string"
    }

    $q put [Split $alternate $line $sepChar]
    return
}

# ::csv::writematrix --
#
#	A wrapper around "::csv::join" taking the rows in a matrix and
#	writing them as CSV formatted lines into the channel.
#
# Arguments:
#	m		The matrix to take the data to write from.
#	chan		The channel to write into.
#	sepChar		The separator character, defaults to comma
#
# Results:
#	None.

proc ::csv::writematrix {m chan {sepChar ,} {delChar \"}} {
    set n [$m rows]
    for {set r 0} {$r < $n} {incr r} {
	puts $chan [join [$m get row $r] $sepChar $delChar]
    }

    # Memory intensive alternative:
    # puts $chan [joinlist [m get rect 0 0 end end] $sepChar $delChar]
    return
}

# ::csv::writequeue --
#
#	A wrapper around "::csv::join" taking the rows in a queue and
#	writing them as CSV formatted lines into the channel.
#
# Arguments:
#	q		The queue to take the data to write from.
#	chan		The channel to write into.
#	sepChar		The separator character, defaults to comma
#
# Results:
#	None.

proc ::csv::writequeue {q chan {sepChar ,} {delChar \"}} {
    while {[$q size] > 0} {
	puts $chan [join [$q get] $sepChar $delChar]
    }

    # Memory intensive alternative:
    # puts $chan [joinlist [$q get [$q size]] $sepChar $delChar]
    return
}

