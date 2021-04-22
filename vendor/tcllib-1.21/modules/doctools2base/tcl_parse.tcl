# -*- tcl -*-
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>

# Recursive descent parser for Tcl commands embedded in a string.  (=>
# subst -novariables, without actual evaluation of the embedded
# commands). Useful for processing templates, etc. The result is an
# abstract syntax tree of strings and commands, which in turn have
# strings and commands as arguments.

# The tree can be processed further. The nodes of the tree are
# annotated with line/column/offset information to allow later stages
# the reporting of higher-level syntax and semantic errors with exact
# locations in the input.

# TODO :: Add ability to report progress through the
# TODO :: input. Callback. Invoked in 'Initialize', 'Step', and
# TODO :: 'Finalize'.

# TODO :: Investigate possibility of using tclparser package
# TODO :: ('parser') to handle the command pieces embedded in the
# TODO :: text.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.4         ; # Required runtime.
package require snit            ; # OO system.
package require fileutil        ; # File utilities.
package require logger          ; # User feedback.
package require struct::list    ; # Higher-order list operations.
package require struct::stack   ; # Stacks
package require struct::set     ; # Finite sets
package require treeql          ; # Tree queries and transformation.

# # ## ### ##### ######## ############# #####################
##

logger::initNamespace ::doctools::tcl::parse
snit::type            ::doctools::tcl::parse {
    # # ## ### ##### ######## #############
    ## Public API

    typemethod file {t path {root {}}} {
	$type text $t [fileutil::cat -translation binary -encoding binary $path] $root
    }

    typemethod text {t text {root {}}} {
	# --- --- --- --------- --------- ---------
	# Phase 1. Lexical processing.
	#          The resulting tree contains the raw tokens. See
	#          below for the specification of the resulting tree
	#          structure.
	#
	# This part is a recursive descent parser using Tcl's 12 rules
	# for processing the input. Note: Variable references are not
	# recognized, they are processed like regular text.

	Initialize $t $text $root
        String
	Finalize

	# Tree structure
	# - All nodes but the root have the attributes 'type', 'range', 'line', and 'col'.
	#
	#   * 'type' in { Command, Text, Backslash, Word, Quote, Continuation, QBrace }
	#   * 'range' is 2-element list (offset start, offset end)
	#   * 'line' is integer number > 0
	#   * 'col' is integer number >= 0
	#
	#   'type' specifies what sort of token the node contains.
	#
	#   'range' is the location of the token as offsets in
	#           characters from the beginning of the string, for
	#           first and last character in the token. EOL markers
	#           count as one character. This can be empty.
	#
	#   'line', 'col' are the location of the first character
	#   AFTER the token, as the line and column the character is
	#   on and at.
	#
	# Meaning of the various node types
	#
	# Command .... : A command begins here, the text in the range
	# .............. is the opening bracket.
	# Text ....... : A text segment in a word, anything up to the
	# .............. beginning of a backslash sequence or of an
	# .............. embedded command. 
	# Backslash .. : A backslash sequence. The text under the
	# .............. range is the whole sequence.
	# Word ....... : The beginning of an unquoted, quoted or
	# .............. braced word. The text under the range is the
	# .............. opening quote or brace, if any. The range is
	# .............. empty for an unquoted word.
	# Quote ...... : An embedded double-quote character which is
	# .............. not the end of a quoted string (a special
	# .............. type of backslash sequence). The range is the
	# .............. whole sequence.
	# Continuation : A continuation line in an unquoted, quoted,
	# .............. or braced string. The range covers the whole
	# .............. sequence, including the whitespace trailing
	# .............. it.
	# QBrace ..... : A quoted brace in a braced string. A special
	# .............. kind of backslash sequence. The range covers
	# .............. the whole sequence.

	# --- --- --- --------- --------- ---------
	# Phase 2. Convert the token tree into a syntax tree.
	#          This phase simplifies the tree by converting and
	#          eliminating special tokens, and further decouples
	#          it from the input by storing the relevant string
	#          ranges of the input in the tree. For the the
	#          specification of the resulting structure see method
	#          'Verify'.
	#
	# The sub-phases are and do
	#
	# (a) Extract the string information from the input and store
	#     them in their Text tokens.
	# (b) Convert the special tokens (QBrace, Backslash, Quote,
	#     Continuation) into equivalent 'Text' tokens, with proper
	#     string information.
	# (c) Merge adjacent 'Text' tokens.
	# (d) Remove irrelevant 'Word' tokens. These are tokens with a
	#     single Text token as child. Word tokens without children
	#     however represent empty strings. They are converted into
	#     an equivalent Text node instead.
	# (e) Pull the first word of commands into the command token,
	#     and ensure that it is not dynamic, i.e not an embedded
	#     command.

	ShowTree $t "Raw tree"

	set q [treeql %AUTO% -tree $t]

	# (a)
	foreach n [$q query tree withatt type Text] {
	    struct::list assign [$t get $n range] a e
	    #$t unset $n range
	    $t set   $n text [string range $mydata $a $e]
	}
	ShowTree $t "Text annotation"

	# (b1)
	foreach n [$q query tree withatt type QBrace] {
	    struct::list assign [$t get $n range] a e
	    incr a ; # Skip backslash
	    #$t unset $n range
	    $t set   $n text [string range $mydata $a $e]
	    $t set   $n type Text
	}
	ShowTree $t "Special conversion 1, quoted braces"

	# (b2)
	foreach n [$q query tree withatt type Backslash] {
	    struct::list assign [$t get $n range] a e
	    #$t unset $n range
	    $t set   $n text [subst -nocommands -novariables [string range $mydata $a $e]]

	    #puts <'[string range $mydata $a $e]'>
	    #puts _'[subst -nocommands -novariables [string range $mydata $a $e]]'_

	    $t set   $n type Text
	}
	ShowTree $t "Special conversion 2, backslash sequences"

	# (b3)
	foreach n [$q query tree withatt type Quote] {
	    #$t unset $n range
	    $t set $n text "\""
	    $t set $n type Text
	}
	ShowTree $t "Special conversion 3, quoted double quotes"

	# (b4)
	foreach n [$q query tree withatt type Continuation] {
	    #$t unset $n range
	    $t set   $n text { }
	    $t set   $n type Text
	}
	ShowTree $t "Special conversion 4, continuation lines"

	# (c)
	foreach n [$q query tree withatt type Text right withatt type Text] {
	    set left [$t previous $n]
	    $t append $left text [$t get $n text]

	    # Extend covered range. Copy location.
	    struct::list assign [$t get $left range] a _
	    struct::list assign [$t get $n    range] _ e
	    $t set $left range [list $a $e]
	    $t set $left line  [$t get $n line]
	    $t set $left col   [$t get $n col]

	    $t delete $n
	}
	ShowTree $t "Merged adjacent texts"

	# (d)
	foreach n [$q query tree withatt type Word] {
	    if {![$t numchildren $n]} {
		$t set $n type Text
		$t set $n text {}
	    } elseif {[$t numchildren $n] == 1} {
		$t cut $n
	    }
	}
	ShowTree $t "Dropped simple words"

	# (e)
	foreach n [$q query tree withatt type Command] {
	    set first [lindex [$t children $n] 0]
	    if {[$t get $first type] eq "Word"} {
		error {Dynamic command name}
	    }
	    $t set $n text  [$t get $first text]
	    $t set $n range [$t get $first range]
	    $t set $n line  [$t get $first line]
	    $t set $n col   [$t get $first col]
	    $t delete $first
	}
	ShowTree $t "Command lifting"

	$q destroy

	Verify $t
	return
    }

    proc Verify {t} {
	# Tree structure ...
	# Attributes Values
	# - type     string in {'Command','Text','Word'} (phase 2)
	# - range    2-tuple (integer, integer), can be empty. start and end offset of the word in the input string.
	# - line     integer, line the node starts on. First line is 1
	# - col      integer, column the node starts on (#char since start of line, first char is 0)
	# Constraints
	# .(i)    The root node has no attributes at all.
	# .(ii)   The children of the root are Command and Text nodes in semi-alternation.
	#         I.e.: After a Text node a Command has to follow.
	#         After a Command node either Text or Command can follow.
	# .(iii)  The children of a Command node are Text, Word, and Command nodes, the command arguments. If any.
	# .(iv)   The children of a Word node are Command and Text nodes in semi-alternation.
	# .(v)    All Text nodes are leafs.
	# .(vi)   Any Command node can be a leaf.
	# .(vii)  Word nodes cannot be leafs.
	# .(viii) All non-root nodes have the attributes 'type', 'range', 'col', and 'line'.

	foreach n [$t nodes] {
	    if {[$t parent $n] eq ""} {
		# (ii)
		set last {}
		foreach c [$t children $n] {
		    set type [$t get $c type]
		    if {![struct::set contains {Command Text} $type]} {
			return -code error "$c :: Bad node type $type in child of root node"
		    } elseif {($type eq $last) && ($last eq "Text")} {
			return -code error "$c :: Bad node $type, not semi-alternating"
		    }
		    set last $type
		}
		# (i)
		if {[llength [$t getall $n]]} {
		    return -code error "$n :: Bad root node, has attributes, should not"
		}
		continue
	    } else {
		# (viii)
		foreach k {range line col} {
		    if {![$t keyexists $n $k]} {
			return -code error "$n :: Bad node, attribute '$k' missing"
		    }
		}
	    }
	    set type [$t get $n type]
	    switch -exact -- $type {
		Command {
		    # (vi)
		    # No need to check children. May have some or not,
		    # and no specific sequence is required.
		}
		Word {
		    # (vii)
		    if {![llength [$t children $n]]} {
			return -code error "$n :: Bad word node is leaf"
		    }
		    # (iv)
		    set last {}
		    foreach c [$t children $n] {
			set type [$t get $c type]
			if {![struct::set contains {Command Text} $type]} {
			    return -code error "$n :: Bad node type $type in word node"
			} elseif {($type eq $last) && ($last eq "Text")} {
			    return -code error "$c :: Bad node $type, not semi-alternating"
			}
			set last $type
		    }
		}
		Text {
		    # (v)
		    if {[llength [$t children $n]]} {
			return -code error "$n :: Bad text node is not leaf"
		    }
		}
		default {
		    # (iii)
		    return -code error "$n :: Bad node type $type"
		}
	    }
	}
	return
    }

    # # ## ### ##### ######## #############
    ## Internal methods, lexical processing

    proc String {} {
	while 1 {
	    Note @String
	    if {[EOF]}         break
	    if {[Command]}     continue
	    if {[TextSegment]} continue
	    if {[Backslash]}   continue

	    Stop ;# Unexpected character
	}
	Note @EOF
	return
    }

    proc Command {} {
	# A command starts with an opening bracket.
	Note ?Command
	if {![Match "\\A(\\\[)" range]} {
	    Note \t%No-Command
	    return 0
	}
	Note !Command

	PushRoot [Node Command $range]
	while {[Word]} {
	    # Step over any whitespace after the last word
	    Whitespace
	    # Command ends at the closing bracket
	    if {[Match "\\A(\\])" range]} break
	    if {![EOF]} continue

	    Stop ;# Unexpected end of input
	}

	Note !CommandStop
	PopRoot
	return 1
    }

    proc TextSegment {} {
	# A text segment is anything up to a command start or start of
	# a back slash sequence.
	Note ?TextSegment
	if {![Match "\\A(\[^\\\[\]+)" range]} {
	    Note \t%No-TextSegment
	    return 0
	}
	Note !TextSegment
	Node Text $range
	return 1
    }

    proc TextSegmentWithoutQuote {} {
	Note ?TextSegmentWithoutQuote
	# A text segment without quote is anything up to a command
	# start or start of a back slash sequence, or a double-quote
	# character.
	if {![Match "\\A(\[^\"\\\\\[\]+)" range]} {
	    Note \t%No-TextSegmentWithoutQuote
	    return 0
	}
	Note !TextSegment
	Node Text $range
	return 1
    }

    proc Backslash {} {
	Note ?Backslash
	if {
	    ![Match "\\A(\\\\x\[a-fA-F0-9\]+)"     range] &&
	    ![Match "\\A(\\\\u\[a-fA-F0-9\]{1,4})" range] &&
	    ![Match "\\A(\\\\\[0-2\]\[0-7\]{2})"   range] &&
	    ![Match "\\A(\\\\\[0-7\]{1,2})"        range] &&
	    ![Match {\A(\\[abfnrtv])}          range]
	} {
	    Note \t%No-Backslash
	    return 0
	}
	Note !Backslash
	Node Backslash $range
	return 1
    }

    proc Word {} {
	Note ?Word
	if {[QuotedWord]}   {return 1}
	if {[BracedWord 0]} {return 1}
	return [UnquotedWord]
    }

    proc Whitespace {} {
	Note ?Whitespace
	if {![Match {\A([ \t]|(\\\n[ \t]*))+} range]} {
	    Note \t%No-Whitespace
	    return 0
	}
	Note !Whitespace
	return 1
    }

    proc QuotedWord {} {
	# A quoted word starts with a double quote.
	Note ?QuotedWord
	if {![Match "\\A(\")" range]} {
	    Note \t%No-QuotedWord
	    return 0
	}
	Note !QuotedWord
	PushRoot [Node Word $range]
	QuotedString
	PopRoot
	return 1
    }

    proc BracedWord {keepclose} {
	# A braced word starts with an opening brace.
	Note ?BracedWord/$keepclose
	if {![Match "\\A(\{)" range]} {
	    Note \t%No-BracedWord/$keepclose
	    return 0
	}
	Note !BracedWord/$keepclose
	PushRoot [Node Word $range]
	BracedString $keepclose
	PopRoot
	return 1
    }

    proc UnquotedWord {} {
	Note !UnquotedWord
	PushRoot [Node Word {}]
	UnquotedString
	PopRoot
	return 1
    }

    proc QuotedString {} {
	Note !QuotedString
	while 1 {
	    Note !QuotedStringPart
	    # A quoted word (and thus the embedded string) ends with
	    # double quote.
	    if {[Match "\\A(\")" range]} {
		return
	    }
	    # Now try to match possible pieces of the string. This is
	    # a repetition of the code in 'String', except for the
	    # different end condition above, and the possible embedded
	    # double quotes and continuation lines the outer string
	    # can ignore.
	    if {[Command]}      continue
	    if {[Quote]}        continue
	    if {[QuotedBraces]} continue
	    if {[Continuation]} continue
	    if {[Backslash]}    continue
            # Check after backslash recognition and processing
	    if {[TextSegmentWithoutQuote]}  continue

	    Stop ;# Unexpected character or end of input
	}
	return
    }

    proc BracedString {keepclose} {
	while 1 {
	    Note !BracedStringPart
	    # Closing brace encountered. keepclose is set if we are in
	    # a nested braced string. Only then do we have to put the
	    # brace as a regular text piece into the string
	    if {[Match "\\A(\})" range]} {
		if {$keepclose} {
		    Node Text $range
		}
		return
	    }
	    # Special sequences.
	    if {[QuotedBraces]} continue
	    if {[Continuation]} continue
	    if {[BracedWord 1]} continue
	    # A backslash without a brace coming after is regular a
	    # character.
	    if {[Match {\A(\\)} range]} {
		Node Text $range
		continue
	    }
	    # Gooble sequence of regular characters. Stops at
	    # backslash and braces. Backslash stop is needed to handle
	    # the case of them starting a quoted brace.
	    if {[Match {\A([^\\\{\}]*)} range]} {
		Node Text $range
		continue
	    }
	    Stop ;# Unexpected character or end of input.
	}
    }

    proc UnquotedString {} {
	while 1 {
	    Note !UnquotedStringPart
	    # Stop conditions
	    # - end of string
	    # - whitespace
	    # - Closing bracket (end of command the word is in)
	    if {[EOF]}                    return
	    if {[Whitespace]}             return
	    if {[Peek "\\A(\\\])" range]} return

	    # Match each possible type of part
	    if {[Command]}              continue
	    if {[Quote]}                continue
	    if {[Continuation]}         continue
	    if {[Backslash]}            continue
            # Last, capture backslash sequences first.
	    if {[UnquotedTextSegment]}  continue

	    Stop ;# Unexpected character or end of input.
	}
	return
    }

    proc UnquotedTextSegment {} {
	# All chars but whitespace and brackets (start or end of
	# command).
	Note ?UnquotedTextSegment
	if {![Match {\A([^\]\[\t\n ]+)} range]} {
	    Note \t%No-UnquotedTextSegment
	    return 0
	}
	Note !UnquotedTextSegment
	Node Text $range
	return 1
    }

    proc Quote {} {
	Note ?EmdeddedQuote
	if {![Match "\\A(\\\")" range]} {
	    Note \t%No-EmdeddedQuote
	    return 0
	}
	# Embedded double quote, not the end of the quoted string.
	Note !EmdeddedQuote
	Node Quote $range
	return 1
    }

    proc Continuation {} {
	Note ?ContinuationLine
	if {![Match "\\A(\\\\\n\[ \t\]*)" range]} {
	    Note \t%No-ContinuationLine
	    return 0
	}
	Note !ContinuationLine
	Node Continuation $range
	return 1
    }

    proc QuotedBraces {} {
	Note ?QuotedBrace
	if {
	    ![Match "\\A(\\\\\{)" range] &&
	    ![Match "\\A(\\\\\})" range]
	} {
	    Note \t%No-QuotedBrace
	    return 0
	}
	Note !QuotedBrace
	Node QBrace $range
	return 1
    }

    # # ## ### ##### ######## #############
    ## Tree construction helper commands.

    proc Node {what range} {
	set n [lindex [$mytree insert $myroot end] 0]

	Note "+\tNode $n @ $myroot $what"

	$mytree set $n type  $what
	$mytree set $n range $range
	$mytree set $n line  $myline
	$mytree set $n col   $mycol

	return $n
    }

    proc PushRoot {x} {
	Note "Push Root = $x"
	$myrootstack push $myroot
	set     myroot $x
	return
    }

    proc PopRoot {} {
	set myroot      [$myrootstack pop]
	Note "Pop Root = $myroot"
	return
    }

    # # ## ### ##### ######## #############
    ## Error reporting

    proc Stop {} {
	::variable myerr
	set ahead  [string range $mydata $mypos [expr {$mypos + 30}]]
	set err    [expr {![string length $ahead] ? "eof" : "char"}]
	set ahead  [string map [list \n \\n \t \\t \r \\r] [string range $ahead 0 0]]
	set caller [lindex [info level -1] 0]
	set msg   "[format $myerr($err) $ahead $caller] at line ${myline}.$mycol"
	set err    [list doctools::tcl::parse $err $mypos $myline $mycol]

	return -code error -errorcode $err $msg
    }

    # # ## ### ##### ######## #############
    ## Input processing. Match/peek lexemes, update location after
    ## stepping over a range. Match = Peek + Step.

    proc EOF {} {
	Note "?EOF($mypos >= $mysize) = [expr {$mypos >= $mysize}]"
	return [expr {$mypos >= $mysize}]
    }

    proc Match {pattern rv} {
	upvar 1 $rv range
	set ok [Peek $pattern range]
	if {$ok} {Step $range}
	return $ok
    }

    proc Peek {pattern rv} {
	upvar 1 $rv range

	Note Peek($pattern)----|[string map [list "\n" "\\n"  "\t" "\\t"] [string range $mydata $mypos [expr {$mypos + 30}]]]|

	if {[regexp -start $mypos -indices -- $pattern $mydata -> range]} {
	    Note \tOK
	    return 1
	} else {
	    Note \tFAIL
	    return 0
	}
    }

    proc Step {range} {
	struct::list assign $range a e

	set  mylastpos $mypos

	set  mypos $e
	incr mypos

	set pieces [split [string range $mydata $a $e] \n]
        set delta  [string length [lindex $pieces end]]
        set nlines [expr {[llength $pieces] - 1}]

	if {$nlines} {
	    incr myline $nlines
	    set  mycol  $delta 
	} else {
	    incr mycol  $delta
	}
	return
    }

    # # ## ### ##### ######## #############
    ## Setup / Shutdown of parser/lexer

    proc Initialize {t text root} {
	set mytree $t
	if {$root eq {}} {
	    set myroot [$t rootname]
	} else {
	    set myroot $root
	}

	if {$myrootstack ne {}} Finalize
	set myrootstack [struct::stack %AUTO%]
	$myrootstack clear

	set mydata $text
	set mysize [string length $mydata]

	set mypos  0
	set myline 1
	set mycol  0
	return
    }

    proc Finalize {} {
	$myrootstack destroy
	set myrootstack {}
	return
    }

    # # ## ### ##### ######## #############
    ## Debugging helper commands
    ## Add ability to disable these.
    ## For the tree maybe add ability to dump through a callback ?

    proc Note {text} {
	upvar 1 range range
	set m {}
	append m "$text "
	if {[info exists range]} {
	    append m "($range) "
	    if {$range != {}} {
		foreach {a e} $range break
		append m " = \"[string map [list "\n" "\\n"  "\t" "\\t"] \
                                   [string range $mydata $a $e]]\""
	    }
	} else {
	    append m "@$mypos ($myline/$mycol)"
	}
	#log::debug $m
        puts $m
	return
    }

    #proc ShowTreeX {args} {}
    proc ShowTreeX {t x} {
	puts "=== \[ $x \] [string repeat = [expr {72 - [string length $x] - 9}]]"
	$t walk root -order pre -type dfs n {
	    set prefix [string repeat .... [$t depth $n]]
	    puts "$prefix$n <[DictSort [$t getall $n]]>"
	}
	return
    }

    proc Note     {args} {}
    proc ShowTree {args} {}

    # # ## ### ##### ######## #############

    proc DictSort {dict} {
	array set tmp $dict
	set res {}
	foreach k [lsort -dict [array names tmp]] {
	    lappend res $k $tmp($k)
	}
	return $res
    }

    # # ## ### ##### ######## #############
    ## Parser state

    typevariable mytree      {} ; # Tree we are working on
    typevariable myroot      {} ; # Current root to add nodes to.
    typevariable myrootstack {} 

    typevariable mydata {} ; # String to parse.
    typevariable mysize 0  ; # Length of string to parse, cache

    typevariable mylastpos ; # Last current position.
    typevariable mypos  0  ; # Current parse location, offset from
    typevariable myline 1  ; # the beginning of the string, line
    typevariable mycol  0  ; # we are on, and the column within the
                             # line.

    typevariable myerr -array {
	char {Unexpected character '%1$s' in %2$s}
	eof  {Unexpected end of input in %2$s}
    }


    # # ## ### ##### ######## #############
    ## Configuration

    pragma -hasinstances   no ; # singleton
    pragma -hastypeinfo    no ; # no introspection
    pragma -hastypedestroy no ; # immortal

    ##
    # # ## ### ##### ######## #############
}

namespace eval ::doctools::tcl {
    namespace export parse
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide doctools::tcl::parse 0.1
return
