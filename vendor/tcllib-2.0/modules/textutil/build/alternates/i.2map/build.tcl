
proc main {} {
    set version 35.2
    
    set srcdir [file dirname [file normalize [file join [pwd] [info script]]]]
    set moddir [file dirname $srcdir]

    puts "Tooling: $srcdir"
    puts "Sources: $moddir"

    # Read full mapping from the unicode database file
    
    lassign [read_eaw $srcdir] types widths
    # types  :: dict (codepoint -> code)
    # widths :: dict (codepoint -> int)

    puts Types:Points:[dict size $types]
    puts Width:Points:[dict size $widths]

    # Generate single stage maps from codepoint to value ...

    set types  [tclcode $types]
    set widths [tclcode $widths]

    puts Types:Code:C/[string length $types]:L/[llength [split $types \n]]
    puts Width:Code:C/[string length $widths]:L/[llength [split $widths \n]]

    # Emit final code, with the conversion code templated into it
    
    emit $version $moddir $types $widths

    puts Done
    
    # Done
    return
}

proc tclcode {map} {
    lappend lines "    return \[lindex \{"
    
    set max [max]

    set lines ""
    set blocks {}
    set group {}
    set blockmap {}

    lappend blocks "    set blocks \{"
    
    for {set j 0} {$j <= 0x10FF} {incr j} {
	set points {}
	for {set k 0} {$k <= 0xFF} {incr k} {
	    set codepoint [expr {$j << 8 | $k}]
	    lappend points [dict get $map $codepoint]
	}

	#puts $j:[llength $points]
	
	if {[dict exists $blockmap $points]} {
	    set g [dict get $blockmap $points]
	} else {
	    set g [dict size $blockmap]
	    dict set blockmap $points $g
	    lappend blocks "\t\{ [lrange $points   0  63]"
	    lappend blocks  "\t  [lrange $points  64 127]"
	    lappend blocks  "\t  [lrange $points 128 191]"
	    lappend blocks  "\t  [lrange $points 192 end] \}"
	}

	lappend group $g
    }

    lappend blocks "    \}"

    set groups {}
    foreach g $group {
	lappend p $g ; incr id
	if {$id == 64} {
	    lappend groups "\t$p"
	    set id 0
	    set p {}
	}
    }
    #lappend groups "\t$p"

    lappend lines {*}$blocks
    lappend lines "    set group \{"
    lappend lines {*}$groups
    lappend lines "    \}"

    puts "Block Map:     [expr 0x10FF]"
    puts "Unique Blocks: [dict size $blockmap]"
    
    return [join $lines \n]
}

proc max {} { return 1114111 }

proc read_eaw {srcdir} {
    set fin [open [file join $srcdir EastAsianWidth.txt] r]
    set hash #

    while {[gets $fin line]>=0} {
	set commentidx [string first $hash $line]
	if {$commentidx==0} continue

	set data    [string trim [string range $line 0 [expr {$commentidx-1}]]]
	set comment              [string range $line [expr {$commentidx+1}] end]

	if {[scan $line {%6x..%6x;%1s} start end code]==3} {
	} elseif {[scan $line {%5x..%5x;%1s} start end code]==3} {
	} elseif {[scan $line {%4x..%4x;%1s} start end code]==3} {
	} elseif {[scan $line  {%5x;%1s} start code]==2} {
	    set end $start
	} elseif {[scan $line  {%4x;%1s} start code]==2} {
	    set end $start
	} else {
	    puts "Ignored line: '$line'"
	    continue
	}

	###
	# Per the unicode recommendations:
	# http://www.unicode.org/reports/tr11/
	#
	# When processing or displaying data:
	#
	# * Wide characters behave like ideographs in important ways, such as layout. Except for
	#   certain punctuation characters, they are not rotated when appearing in vertical text
	#   runs. In fixed-pitch fonts, they take up one Em of space.
	#
	# * Halfwidth characters behave like ideographs in some ways, however, they are rotated
	#   like narrow characters when appearing in vertical text runs. In fixed-pitch fonts,
	#   they take up 1/2 Em of space.
	#
	# * Narrow characters behave like Western characters, for example, in line breaking.
	#   They are rotated sideways, when appearing in vertical text. In fixed-pitch East
	#   Asian fonts, they take up 1/2 Em of space, but in rendering, a non-East Asian,
	#   proportional font is often substituted.
	#
	# * Ambiguous characters behave like wide or narrow characters depending on the context
	#   (language tag, script identification, associated font, source of data, or explicit
	#   markup; all can provide the context). If the context cannot be established reliably,
	#   they should be treated as narrow characters by default.
	#
	# * [UTS51] emoji presentation sequences behave as though they were East Asian Wide,
	#   regardless of their assigned East_Asian_Width property value. (Not implemented here)

	###
	set width 1
	switch $code {
	    W - F          { set width 2 }
	    A - N - Na - H { }
	}
	
	for {set codepoint $start} {$codepoint <= $end} {incr codepoint} {
	    dict set ctype  $codepoint $code
	    dict set cwidth $codepoint $width
	}
    }

    set max [max]
    for {set codepoint 0} {$codepoint <= $max} {incr codepoint} {
	if {![dict exists $ctype  $codepoint]} { dict set ctype  $codepoint N }
	if {![dict exists $cwidth $codepoint]} { dict set cwidth $codepoint 1 }
    }
    
    return [list $ctype $cwidth]
}

proc emit {version moddir types widths} {
    lappend map \n\t     \n
    lappend map "\n    " ""
    lappend map :types   $types
    lappend map :widths  $widths
    lappend map :version $version
    
    set fout [open [file join $moddir wcswidth.tcl] w]
    puts $fout [string map $map {###
	# This file is automatically generated by the build/build.tcl file
	# based on information in the following database:
	# http://www.unicode.org/Public/UCD/latest/ucd/EastAsianWidth.txt
	#
	# (This is the 35th edition, thus version 35 for our package)
	#
	# Author: Sean Woods <yoda@etoyoc.com>
	# Author: Andreas Kupries <andreas.kupries@gmail.com>
	###
	# This code uses 2-stage table compression.
	#
	# The code point is split into high 16 bit, and low 8 bit.
	# The low bits define a block of 256 codepoints.
	# The high bits select which block.
	#
	# The compressor determines for each block the set of results. It records only unique result
	# sets, and records per block the id of that unique set.
	#
	# Decoding uses the high bits to select the result block, and the low bits to select the
	# result in the block.
	
	package require Tcl 8.5 9
	package provide textutil::wcswidth :version
	namespace eval ::textutil {}
	
	proc ::textutil::wcswidth_type char {
:types
	    return [lindex $blocks [lindex $group [expr {$char >> 8}]] [expr {$char & 0xFF}]]
	}

	proc ::textutil::wcswidth_char char {
:widths
	    return [lindex $blocks [lindex $group [expr {$char >> 8}]] [expr {$char & 0xFF}]]
	}

	proc ::textutil::wcswidth {string} {
	    set width 0
	    set len [string length $string]
	    foreach c [split $string {}] {
		scan $c %c char
		set n [::textutil::wcswidth_char $char]
		if {$n < 0} {
		    return -1
		}
		incr width $n
	    }
	    return $width
	}

	# This file is automatically generated by the build/build.tcl file
	# based on information in the following database:
	# http://www.unicode.org/Public/UCD/latest/ucd/EastAsianWidth.txt
	return
    }]
}

# go
main
