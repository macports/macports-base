# cfront.tcl --
#
#	Generator frontend for compiler of magic(5) files into recognizers
#	based on the 'rtcore'. Parses magic(5) into a basic 'script'.
#
# Copyright (c) 2016      Poor Yorick     <tk.tcl.core.tcllib@pooryorick.com>
# Copyright (c) 2004-2005 Colin McCormack <coldstore@users.sourceforge.net>
# Copyright (c) 2005      Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: cfront.tcl,v 1.7 2008/03/22 01:10:32 andreas_kupries Exp $

#####
#
# "mime type recognition in pure tcl"
# http://wiki.tcl.tk/12526
#
# Tcl code harvested on:  10 Feb 2005, 04:06 GMT
# Wiki page last updated: ???
#
#####

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.5

# file to compile the magic file from magic(5) into a tcl program
package require fileutil              ; # File processing (input)
package require fileutil::magic::cgen ; # Code generator.
package require fileutil::magic::rt   ; # Runtime (typemap)
package require struct::list          ; # lrepeat.
package require struct::tree          ; #

package provide fileutil::magic::cfront 1.3.0

# ### ### ### ######### ######### #########
## Implementation

namespace eval ::fileutil::magic::cfront {
    # Configuration flag. (De)activate debugging output.
    # This is done during initialization.
    # Changes at runtime have no effect.

    variable debug 0

    # Make backend functionality accessible
    namespace import ::fileutil::magic::cgen

    namespace export compile generate install

    namespace upvar ::fileutil::magic::rt typemap typemap

    variable floattestops {= < > !}
    variable inttestops {= < > & ^ ~ !}
    variable stringtestops { > < = !}
    variable offsetopts {& | ^ + - * / %}
    variable stringmodifiers {W w c C t b T}
    variable typemodifiers [dict create \
	indirect r \
	search $stringmodifiers \
	string $stringmodifiers \
	pstring [list {*}$stringmodifiers B H h L l J] \
	regex {c s l} \
    ]
    set numeric_modifier_allowed {regex search}

    variable types_numeric_short
    foreach {shortname name} {
	dC byte d1 byte C byte 1 byte ds short d2 short S short 2 short dI long
	dL long d4 long I long L long 4 long d8 quad 8 quad dQ quad Q quad
    } {
	dict set types_numeric_short $shortname $name
	dict set types_numeric_short u$shortname u$name
    }

    variable types_numeric_all [list {*}[
	array names typemap] {*}[dict keys $types_numeric_short]]

    variable types_string_short [dict create s string] 
    variable types_string_short [dict create us ustring] 

    variable types_string {
	bestring clear indirect lestring lestring16 pstring regex search
	string ustring
    }
    variable types_string_all [list {*}[
	dict keys $types_string_short] {*}$types_string]

    variable types_verbatim {name use}

    variable types_notimplemented {der}

    variable types_numeric_real
    foreach name {float double befloat bedouble lefloat ledouble} {
	lappend types_numeric_real $name u$name
    }

    variable indir_typemap [dict create \
	b byte c byte e ledouble f ledouble g ledouble i leid3 h leshort \
	s leshort l lelong B byte C byte E bedouble F bedouble G bedouble \
	H beshort I beid3 L belong m ME S beshort]

}


proc ::fileutil::magic::cfront::advance {len args} {
    upvar node node tree tree
    if {[llength args]} {
	upvar [lindex $args 0] res
    }
    set res {}
    set line [$tree get $node line]
    set cursor [$tree get $node cursor]
    if {[string index $len 0] eq {w}} {
	regexp -start $cursor {\A(\s*)} $line match res
	incr cursor [string length $match]
	set len [string range $len 1 end]
    }
    if {$len ne {}} {
	if {[regexp -start $cursor "\\A(.{[
	    scan $len %lld]})" $line match res]} {
	    incr cursor [string length $match]
	}
    }
    set line [$tree get $node line]
    $tree set $node cursor $cursor
    return $res
}


# compile up magic files or directories of magic files into a single recognizer.
proc ::fileutil::magic::cfront::compile {args} {
    set tree [tree]

    foreach arg $args {
   	if {[file type $arg] eq  {directory}} {
   	    foreach file [glob [file join $arg *]] {
		if {[file tail $file] eq {make}} {
		    set chan [open $file r+]
		    set data [read $chan]
		    seek $chan 0
		    regsub {\\\^\\\.BEGIN} $data {^\\\\.BEGIN} data
		    regsub {\\\^\\\.PRECIOUS} $data {^\\\\.PRECIOUS} data
		    regsub {\\\^\\\.include} $data {^\\\\.include} data
		    puts $chan $data
		    close $chan
		}
   		process $tree $file
   	    }
	    #append tcl "magic::file_start $file" \n
	    #append tcl [run $script1] \n
   	} else {
   	    set file $arg
   	    process $tree $file
	    #append tcl "magic::file_start $file" \n
	    #append tcl [run $script1] \n
   	}
    }

    #puts stderr $script
    ::fileutil::magic::cfront::Debug {puts "\# $args"}

    # Historically, this command converted the output of [process] , which was
    # a list , into a tree . Now it post-processes the tree .
    cgen 2tree $tree

    set tests [cgen treegen $tree root]
    set named [$tree get root named]

    ::fileutil::magic::cfront::Debug {puts [treedump $t]}
    #set tcl [run $script]

    return [list $named $tests]
}


proc ::fileutil::magic::cfront::generate args {

    set indent {}
    set pline {}

    while {[llength $args]} {
	set args [lassign $args[set args {}] key]
	switch $key {
	    compressed {
		set args [lassign $args[set args {}] val]
		if {$val} {
		    set indent {}
		    set pline {}
		} else {
		    set indent \t
		    set pline \n
		}
	    }
	    -- break
	    default {
		error [list {unknown argument}]
	    }
	}
    }

    lassign [compile {*}$args] named tests

    append script "variable named {\n"
	dict for {key val} $named {
	    append script "${indent}[list $key]"
		append script "$pline${indent}${indent}[list [string map [
		    list \n \n${indent}] $val]]\n"
	    }
    append script "$pline}\n"

    append script "proc analyze {} {\n"
	    foreach item $tests {
		append script "${indent}[string map [
		    list \n \n${indent}] $item]\n"
	    }
    append script "$pline}\n"

    return $script 
}


proc ::fileutil::magic::cfront::install args {
    foreach arg $args {
	set path [file tail $arg]
	eval [generate compressed 1 -- ::fileutil::magic::/$path $arg]
    }
    return
}


proc ::fileutil::magic::cfront::parseerror args {
    upvar node node tree tree
    set cursor [$tree get $node cursor]
    set line [$tree get $node line]
    set files [$tree get root files]
    set file [lindex $files [$tree get $node file]]
    return -code error -errorcode [list fumagic {parse error}] [
	list [lmap arg $args {string trim $arg}] \
	file $file \
	linenenum [$tree get $node linenum] \
	cursor $cursor \
	line [list \
	    [string range $line 0 ${cursor}-1] \
	    [string range $line $cursor end]]]
}


proc ::fileutil::magic::cfront::parsewarning args {
    upvar node node tree tree
    catch {parseerror {*}$args} res options
    puts stderr [list parse warning $res]
    #puts stderr [dict get $options -errorinfo]
}


# parse an individual line
variable ::fileutil::magic::cfront::parsedkeys {
}
proc ::fileutil::magic::cfront::parseline {tree node} {
    variable parsedkeys
    set line [$tree get $node line]
    $tree set $node cursor 0 
    parseoffset $tree $node
    parsetype $tree $node
    parsetest $tree $node
    parsemsg $tree $node

    set record [$tree getall $node]
    foreach key $parsedkeys {
	if {![dict exists $record $key]} {
	    return -code error [list {missing key} $key]
	}
    }
    ::fileutil::magic::cfront::Debug {
   	puts [list parsed $record]
    }
}


proc ::fileutil::magic::cfront::parsefloat {tree node} {
    set line [$tree get $node line]
    set cursor [$tree get $node cursor]
    # If only [scan] had a @ conversion character like [binary scan]
    set line2 [string range $line $cursor end]
    if {[scan $line2 %e%n num count] < 0} {
	parseerror {invalid floating point number}
    }
    set cursor [expr {$cursor + $count}]
    $tree set $node cursor $cursor

    # These suffixes are not used in magic files
    #if {[regexp -start $cursor {\A([fFlL)} -> modifier]} {
    #    advance [string length $modifier]]
    #}
    return $num
}


proc ::fileutil::magic::cfront::parseint {tree node} {
    set line [$tree get $node line]
    set cursor [$tree get $node cursor]
    # If only [scan] had a @ conversion character like [binary scan]
    set line2 [string range $line $cursor end]
    if {[set scanres [scan $line2 %lli%n num n]] < 1} {
	parseerror [list {invalid number} $line2]
    }
    set cursor [expr {$cursor + $n}]
    $tree set $node cursor $cursor
    # Thse suffixes are not used in magic files
    #if {[regexp -start $cursor {\A([uU]?[lL]{1,2})} -> modifier]} {
    #    advance [string length $modifier]]
    #}
    return $num
}


proc ::fileutil::magic::cfront::parsetype {tree node} {
    variable types_numeric_all
    variable types_numeric_short
    variable types_string_all
    variable types_string_short
    variable types_notimplemented
    set line [$tree get $node line]
    set cursor [$tree get $node cursor]
    $tree set $node mod {}
    $tree set $node mand {}
    set num_or_string {
    }
    if {[regexp -start $cursor {\A\s*(\w+)} $line match type]} {
	advance [string length $match]
	if {$type in $types_numeric_all} {
	    if {[dict exists $types_numeric_short $type]} {
		set type [dict get $types_numeric_short $type]
	    }
	    $tree set $node type $type
	    parsetypenummod $tree $node
	} elseif {$type in $types_string_all} {
	    if {[dict exists $types_string_short $type]} {
		set type [dict get $types_string_short $type]
	    }
	    $tree set $node type $type
	    # No modifying operator for strings
	    parsetypemod $tree $node

	    if {$type eq {search} && [$tree get $node mand] eq {}} {
		parsewarning {search has no number}
		# set the same default that file(1) sets
		$tree set $node mand 100
	    }
	} elseif {$type in {default name use}} {
	    $tree set $node type $type
	} elseif {$type in $types_notimplemented} {
	    parseerror {type not implemented}
	} else {
	    parseerror {unknown type}
	}
    } else {
	parseerror {no type}
    }
}


proc ::fileutil::magic::cfront::parsetypemod {tree node} {
    # For numeric types , $mod is a list of modifiers and $mand is either a
    # number or the empty string .
    variable typemodifiers
    variable numeric_modifier_allowed
    set type [$tree get $node type]
    if {[advance 1 char] ne {/}} {
	rewind 1
	return
    }
    set res [dict create] 
    while 1 {
	if {[advance 1 char] eq {/}} {
	    continue
	}
	if {[string is space $char]} {
	    break
	}
	if {[dict exists $typemodifiers $type] && $char in [dict get $typemodifiers $type]} {
	    dict set res $char {}
	} elseif {$type in $numeric_modifier_allowed} {
	    rewind 1
	    if {[catch {parseint $tree $node} mand]} {
		# Whatever it is, it isn't a number.  Let the next parsing step
		# handle it .
		break
	    } else {
		$tree set $node mand $mand  ; # numeric modifier
	    }
	} else {
	    parseerror {bad modifier}
	}
    }
    $tree set $node mod [dict keys $res]
}


proc ::fileutil::magic::cfront::parsetypenummod {tree node} {
    variable typemap
    # For numeric types, $mod is an operator and $mand is a number
    set line [$tree get $node line]
    set type [$tree get $node type]
    set cursor [$tree get $node cursor]
    if {[regexp -start $cursor {\A([-&|^+*/%=])} $line match mod]} {
	advance [string length $match]
	$tree set $node mod $mod
	# {to do} {parse floats?}
	set mand [parseint $tree $node] ; # mod operand
	if {[info exists typemap($type)]} {
	    lassign $typemap($type) dummy scan

	    # the modifier for a numeric type is a number of the same
	    # type
	    binary scan [binary format $scan $mand] $scan mand
	}
	$tree set $node mand $mand 
    } else {
	$tree set $node mod {}
	$tree set $node mand {}
    }
}


proc ::fileutil::magic::cfront::parsestringval {tree node} {
    variable floattestops
    variable inttestops
    variable stringtestops
    advance w1 char 
    set val {}
    set nodetype [$tree get $node type]
    set line [$tree get $node line]
    while 1 {
	# break on whitespace or empty string
	if {[string is space $char] || $char eq {}} break
	switch $char [dict create  \
	    \\ {
		advance 1 char
		if {[string is space $char]} {
		    append val \\$char
		} else {
		    # extra backslashes because of interaction with glob
		    switch -glob -- $char {
			\\\\ {
			    append val {\\}
			} \t {
			    parsewarning {use \t instead of \<tab>}
			    append val \\t
			} > - < - & - ^ - = - ! - ( - ) - . {
			    if {$char in [list {*}$stringtestops \
				{*}$floattestops {*}$inttestops]} {
				parsewarning {no need to escape operators}
			    }
			    append val $char 
			} a - b - f - n - r - t - v {
			    append val \\$char
			} x {
			    set cursor [$tree get $node cursor]
			    if {[regexp -start $cursor \
				{\A([0-9A-Fa-f]{1,2})} $line match char2]} {
				advance [string length $match] 
				append val \\x$char2
			    } else {
				parseerror {malformed \x escape sequence}
			    }
			} [0-7] {
			    set cursor [$tree get $node cursor]
			    append val \\$char
			    if {[regexp -start $cursor \
				{\A([0-7]{1,2})} $line match char2]} {
				advance [string length $match] 
				append val $char2
			    }
			} default {
			    if {$nodetype eq {regex}} {
				if {$char ni {[ ] ( ) . * ? ^ $ | \{ \}}} {
				    parsewarning [list {no need to escape}]
				}
			    } elseif {[string is print $char]} {
				if {$char ni {< > & ^ = !}} {
				    parsewarning [list {no need to escape}]
				}
			    }
			    append val [tclescape $char]
			}
		    }
		}
	    } default {
		append val [tclescape $char]
	    }
	]
	advance 1 char
    }
    $tree set $node val $val
}


proc ::fileutil::magic::cfront::parsetest {tree node} {
    variable floattestops
    variable inttestops
    variable stringtestops
    variable types_numeric_real
    variable types_numeric_all
    variable types_string
    variable types_verbatim
    variable typemap
    set type [$tree get $node type]
    if {$type in $types_verbatim} {
	parsetestverbatim $tree $node
	return
    }
    $tree set $node compinvert 0
    set testinvert 0
    set comp ==
    advance w1 char
    if {$char eq {x}} {
	advance 1 char
	if {[string is space $char]} {
	    $tree set $node testinvert 0
	    $tree set $node comp x
	    $tree set $node val {}
	    return
	} else {
	    rewind 1
	}
    }

    if {$type in $types_string} {
	while 1  {
	    if {$char in $stringtestops} {
		if {$char eq {!}} {
		    set testinvert 1
		} else {
		    set comp $char
		    # Exclamation must precede any normal operator
		    break
		}
		advance w1 char
	    } else {
		rewind 1
		break
	    }
	}
	parsestringval $tree $node
    } elseif {$type in $types_numeric_all} {
	if {$type in $types_numeric_real} {
	    set ops $floattestops
	    set parsecmd parsefloat
	} else {
	    set ops $inttestops 
	    set parsecmd parseint
	}

	while 1 {
	    if {$char in $ops} {
		if {$char eq {~}} {
		    $tree set $node compinvert 1 
		} elseif {$char eq {!}} {
		    set testinvert 1
		} else {
		    set comp $char
		    # Exclamation and tilde must precede any normal operator
		    break
		}
		advance w1 char
	    } else {
		rewind 1
		break
	    }
	}
	set val [$parsecmd $tree $node]
	set scan [lindex $typemap([$tree get $node type]) 1]

	# get value in binary form, then back to numeric
	# this avoids problems with sign, as both values are
	# [binary scan]-converted identically
	binary scan [binary format $scan $val] $scan val
	$tree set $node val $val 
    } else {
	parseerror {don't know how to parse the test or this type}
    }
    switch $comp {
	= {
	    set comp ==
	}
    }
    # This facilitates Switch creation by [treegen1]
    if {$testinvert && ($comp eq {==})} {
	set comp !=
	set testinvert 0
    }
    $tree set $node testinvert $testinvert
    $tree set $node comp $comp 
}


proc ::fileutil::magic::cfront::parsetestverbatim {tree node} {
    switch [$tree get $node type] {
	name {
	    $tree set $node rel 1
	}
	use {
	    set cursor [$tree get $node cursor]
	    # order matters in regular expression : longest match must come
	    # first in parenthesized
	    if {[regexp -start $cursor {\A\s*(?:\\\^|\^)} [$tree get $node line] match]} {
		advance [string length $match]
		$tree set $node iendian 1
	    } else {
		$tree set $node iendian 0
	    }
	}

    }
    parsestringval $tree $node
}


proc ::fileutil::magic::cfront::parseoffset {tree node} {

    # Offset parser.
    # Syntax:
    #   ( ?&? number ?.[bslBSL]? ?[+-]? ?number? )

    # This was all fine and dandy, but didn't do spaces where spaces might
    # exist between lexical elements in the wild, and ididn't do offset
    # operators

    #set n {([-+]?[0-9]+|[-+]?0x[0-9A-Fa-f]+)[UL]*}

    ##"\\((&?)(${n})((\\.\[bslBSL])?)()(\[+-]?)(${n}?)\\)"
    #set o \
    #    "^(&?)${n}((?:\\.\[bslBSL])?)(?:(\[-+*/%&|^])${n})?(?:(\[+-])(\\()?${n}\\)?)?$"
    ##     |   |   |                     |            |        |      |    |
    ##     1   2   3                     4            5        6      7    8 
    ##                            1    2    3     4   5        6    7     8   
    #set ok [regexp $o $offset -> irel base type  iop ioperand sign ind idx]

    variable offsetopts
    variable indir_typemap
    $tree set $node rel 0 ;   # relative
    $tree set $node ind 0 ;   # indirect
    $tree set $node ir 0 ;    # indirect relative
    $tree set $node it {} ;   # indir_type
    $tree set $node ioi 0 ;   # indirect offset invert
    $tree set $node iir 0 ;   # indirect indirect relative 
    $tree set $node ioo + ;   # indirect_offset_op
    $tree set $node io 0 ;    # indirect offset
    advance w1 char
    if {$char eq {&}} {
	advance w1 char
	$tree set $node rel 1
    }

    if {$char eq {(}} {
	$tree set $node ind 1

	if {[advance w1] eq {&}} {
	    $tree set $node ir 1
	} else {
	    rewind 1
	}
	$tree set $node o [parseint $tree $node]

	# $char is used below if it's not "."
	if {[advance w1 char] in {. ,}} {
	    advance w1 it
	    if {[dict exists $indir_typemap $it]} {
		set it [
		    dict get $indir_typemap $it]
		    if {$char eq {.}} {
			set it u$it
		    } 
	    } else {
		parseerror {bad indirect offset type}
	    }
	    advance w1 char
	} else {
	    set it long
	}
	$tree set $node it $it


	# The C implementation does this, so we will , too .
	if {$char eq {~}} {
	    advance w1 char
	    $tree set $node ioi 1
	}

	if {$char in $offsetopts} {
	    $tree set $node ioo $char
	    if {[advance w1] in {(}} {
		$tree set $node iir 1
	    } else {
		rewind 1
	    }
	    $tree set $node io [parseint $tree $node]
	    if {[$tree get $node iir]} {
		if {[advance w1] ne {)}} {
		    parseerror {
			expected closing parenthesis for indirect indirect offset offset
		    }
		}
	    }
	    advance w1 char
	}

	if {$char ne {)}} {
	    parseerror {
		expected close parenthesis for indirect offset 
	    }
	}
    } else {
	rewind 1
	$tree set $node o [parseint $tree $node]
    }
}


proc ::fileutil::magic::cfront::parseoffsetmod {tree node} {
    advance w1 char
    if {$char eq {~}} {
	$tree set $node offset_invert 1
	advance w1 char
    } else {
	$tree set $node offset_invert 0
    }
    switch $char {
	+ - - - * - / - % - & - | - ^ {
	    $tree set $node offset_mod_op $char
	    $tree set $node offset_mod [parseint $tree $node]
	}
	default {
	    $tree set $node offset_mod_op {}
	    $tree set $node offset_mod {}
	    rewind 1
	    # no offset modifier
	}
    }
}


proc ::fileutil::magic::cfront::parsemsg {tree node} {
    advance w
    set line [$tree get $node line]
    set cursor [$tree get $node cursor]

    ##leave \b in the message for [emit] to parse
    #regexp -start $cursor {\A(\b|\\b)?(.*)$} $line match b line
    #if {$b ne {}} {
    #    $tree set $node space 0
    #} else {
    #    $tree set $node space 1
    #}

    set line [string range $line $cursor end]

    $tree set $node desc $line
}


# process a magic file
proc ::fileutil::magic::cfront::process {tree file {maxlevel 10000}} {
    variable level	;# level of line
    variable linenum	;# line number

    set level  0

    set linenum 0
    set records {}
    set rejected 0
    set script {}
    if {[$tree keyexists root files]} {
	set files [$tree get root files]
    } else {
	set files {}
    }
    set fileidx [llength $files] 
    if {$file in $files} {
	return -code error [list {already processed file} $file]
    }
    lappend files $file
    $tree set root files $files
    $tree set root level -1
    set node root
    ::fileutil::foreachLine line $file {
   	incr linenum
	# Only trim the left side . White space on the the right side could be
	# part of an escape sequence , and trimming would munge it .
   	set line [string trimleft $line]
   	if {[string index $line 0] eq {#}} {
   	    continue	;# skip comments
   	} elseif {$line eq {}} {
   	    continue	;# skip blank lines
   	} else {
   	    # parse line
	    if {[regexp {^\s*!:(\S+)\s*(.*?)\s*$} $line -> extname extdata]} {
		if {$rejected} {
		    continue
		}
		if {$node eq {root}} {
		    return -code error [list {malformed magic file}]
		}
		$tree set $node ext_$extname $extdata
	    } else {
		# calculate the line's level
		set unlevel [string trimleft $line >]
		set level   [expr {[string length $line] - [string length $unlevel]}]
		set line $unlevel
		if {$level > $maxlevel} {
		    return -code continue "Skip - too high a level"
		}
		if {$level > 0} {
		    if {$rejected} {
			continue
		    }
		    while {[$tree keyexists $node level] && [$tree get $node level] >= $level} {
			set node [$tree parent $node]
		    }
		    if {$level > [$tree get $node level]+1} {
			return -code error [
			    list {level more than one greater than parent level} \
				file $file linenum $linenum line $line]
		    }
		    set node [$tree insert $node end]
		} else {
		    set rejected 0
		    set node [$tree insert root end]
		    set node0 $node
		}
		$tree set $node file $fileidx
		$tree set $node line $line
		$tree set $node linenum $linenum
		$tree set $node level $level
		if {[catch {parseline $tree $node} cres copts]} {
		    set errorcode [dict get $copts -errorcode]
		    if {[lindex $errorcode 0] eq {fumagic} && [
			lindex $errorcode 1] eq {parse error}} {
			# don't delete the full node because the parts that
			# have been parsed so far might be useful
			#$tree delete $node0
			$tree delete $node
			set rejected 1
			puts stderr [list Rejected {bad parse}]
			puts stderr [dict get $copts -errorinfo]
			continue	;# skip erroring lines
		    } else {
			return -options $copts $cres
		    }

		}
	    }
   	}

   	# collect some summaries
   	::fileutil::magic::cfront::Debug {
   	    variable types
   	    set types($type) [$tree get $node type]
   	    variable quals
   	    set quals($qual) [$tree get $node qual]
   	}

   	#puts $linenum level:$level offset:$offset type:$type
	#puts qual:$qual compare:$compare val:'$val' desc:'$desc'

    }
}


proc ::fileutil::magic::cfront::rewind len {
    upvar node node tree tree
    set cursor [$tree get $node cursor]
    incr cursor -$len
    $tree set $node cursor $cursor
}


proc ::fileutil::magic::cfront::tclescape char {
	if {[string is space $char] || $char in [
	    list \# \{ \} \[  \] \" \$ \; \n]} {
	    append val \\
	}
	append val $char
	return $val
}


proc ::fileutil::magic::cfront::tree {} {
    set tree [::struct::tree]

    $tree set root path ""
    $tree set root otype Root
    $tree set root type root
    $tree set root named {}
    $tree set root message "unknown"
    return $tree
}


# ### ### ### ######### ######### #########
## Internal, debugging.

if {!$::fileutil::magic::cfront::debug} {
    # This procedure definition is optimized out of using code by the
    # core bcc. It knows that neither argument checks are required,
    # nor is anything done. So neither results, nor errors are
    # possible, a true no-operation.
    proc ::fileutil::magic::cfront::Debug {args} {}

} else {
    proc ::fileutil::magic::cfront::Debug {script} {
	# Run the commands in the debug script. This usually generates
	# some output. The uplevel is required to ensure the proper
	# resolution of all variables found in the script.
	uplevel 1 $script
	return
    }
}

#set script [magic::compile {} /usr/share/misc/file/magic]
#puts "\# types:[array names magic::types]"
#puts "\# quals:[array names magic::quals]"
#puts "Script: $script"

# ### ### ### ######### ######### #########
## Ready for use.
# EOF
