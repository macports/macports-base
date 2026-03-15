
set step "  "

proc main {} {
    global step
    set version 35.3
    
    set srcdir [file dirname [file normalize [file join [pwd] [info script]]]]
    set moddir [file dirname $srcdir]

    puts "Tooling: $srcdir"
    puts "Sources: $moddir"
    puts "Writing: $moddir/wcswidth.tcl"

    # Read full mapping from the unicode database file
    
    lassign [read_eaw $srcdir] types widths
    # types  :: dict (codepoint -> code)
    # widths :: dict (codepoint -> int)

    puts Types:Points:[dict size $types]
    puts Width:Points:[dict size $widths]

    # Compress mapping into ordered list of runs/ranges for the same value
    
    lassign [ranges $types $widths] types widths
    # types  :: list (range), range :: list (from to code)
    # widths :: list (range), range :: list (from to int)

    puts Types:Ranges:[llength $types]
    puts Width:Ranges:[llength $widths]

    # Convert linear list of ranges into a binary tree of same
    
    set types  [tree $types]
    set widths [tree $widths]

    puts Types_______________ ; set td [dump $types  $step]
    puts Widths______________ ; set wd [dump $widths $step]

    # The depth is important to know as the maximum number of decisions to make to determine the
    # result for a specific code point.
    
    puts Types:Depth:$td
    puts Width:Depth:$wd

    # Convert the trees into equivalent nested if-commands

    set types  [join [lindex [tclcode $types  $step] 0] \n]
    set widths [join [lindex [tclcode $widths $step] 0] \n]

    puts Types:Code:C/[string length $types]:L/[llength [split $types \n]]
    puts Width:Code:C/[string length $widths]:L/[llength [split $widths \n]]

    # Emit final code, with the conversion code templated into it
    
    emit $version $moddir $types $widths

    puts Done
    
    # Done
    return
}

proc tclcode {tree {indent {}}} {
    global step
    # ensure proper tabs for multiple levels of indent
    set indent [string map [list "        " \t] $indent]

    set simple no
    set lines {}
    
    set kind [lindex $tree 0]
    switch -exact -- $kind {
	split {
	    lassign $tree _ leftmin leftmax left rightmin rightmax right

	    set decider $leftmax
	    set down "${indent}$step"

	    lassign [tclcode $left  $down] left lsimple
	    lassign [tclcode $right $down] right rsimple
	    
	    if {$lsimple && $rsimple} {
		lappend lines "${indent}if \{\$c <= $decider\} \{ [lindex $left 0] \} else \{ [lindex $right 0] \}"
		#lappend lines "if \{\$c <= $decider\} \{ [lindex $left 0] \} else \{ [lindex $right 0] \}"
	    } else {
		if {$lsimple} { set left  [list ${down}[lindex $left  0]] }
		if {$rsimple} { set right [list ${down}[lindex $right 0]] }
		#lappend lines "${indent}# $leftmin ... $rightmax"
		lappend lines "${indent}if \{\$c <= $decider\} \{"
		lappend lines {*}$left
		lappend lines "${indent}\} else \{"
		lappend lines {*}$right
		lappend lines "${indent}\}"
	    }

	    #set simple yes
	}
	leaf {
	    lassign $tree _ start to value
	    set n [expr {$to - $start + 1}]
	    
	    #lappend lines "${indent}return $value\t;# $start ... $to ($n)"
	    lappend lines "return $value"
	    set simple yes
	}
    }

    return [list $lines $simple]
}

proc dump {tree {indent {}}} {
    set kind [lindex $tree 0]
    switch -exact -- $kind {
	split {
	    lassign $tree _ leftmin leftmax left rightmin rightmax right
	    set node [list $kind - $leftmin $leftmax - $rightmin $rightmax]
	    puts $indent$node
	    append indent "  "
	    set left  [dump $left  $indent]
	    set right [dump $right $indent]
	    return [expr {1+max($left,$right)}]
	}
	leaf {
	    puts $indent$tree
	    return 1
	}
    }
}

proc tree {ranges} {
    set n [llength $ranges]

    if {$n == 0} {
	error XXX
    } elseif {$n == 1} {
	lassign $ranges range
	lassign $range start to value
	return [list leaf {*}$range]
    } elseif {$n == 2} {
	lassign $ranges left right
	# inline n == 1
	set leftmin  [lindex $left 0]
	set leftmax  [lindex $left 1]
	set left     [list leaf {*}$left]

	# inline n == 1
	set rightmin [lindex $right 0]
	set rightmax [lindex $right 1]
	set right    [list leaf {*}$right]

	# inline branch
	return [list split $leftmin $leftmax $left $rightmin $rightmax $right]
    }

    set h       [expr {$n >> 1}]
    set leftmin [lindex $ranges 0  0]
    set leftmax [lindex $ranges $h 1]
    set left    [lrange $ranges 0 $h]

    incr h
    set rightmin [lindex $ranges $h  0]
    set rightmax [lindex $ranges end 1]
    set right    [lrange $ranges $h end]
    
    set left  [tree $left]
    set right [tree $right]

    return [list split $leftmin $leftmax $left $rightmin $rightmax $right]
}

proc ranges {ctype cwidth} {

    set types  {}
    set widths {}

    set trange {}
    set wrange {}

    set tlast .
    set wlast .

    set max [max]
    for {set codepoint 0} {$codepoint <= $max} {incr codepoint} {
	set t [dict get $ctype  $codepoint]
	set w [dict get $cwidth $codepoint] 

	#puts T/$tlast|$t|$codepoint|
	#puts W/$wlast|$w|$codepoint|

	if {$t eq $tlast} {
	    lappend trange $codepoint
	} else {
	    if {[llength $trange]} {
		#puts T/close
		lappend types [list [lindex $trange 0] [lindex $trange end] $tlast]
		set trange {}
	    }
	    lappend trange $codepoint
	}
	set tlast $t
	
	if {$w eq $wlast} {
	    lappend wrange $codepoint
	} else {
	    if {[llength $wrange]} {
		#puts W/close
		lappend widths [list [lindex $wrange 0] [lindex $wrange end] $wlast]
		set wrange {}
	    }
	    lappend wrange $codepoint
	}
	set wlast $w
    }

    # Close final ranges
    
    if {[llength $trange]} {
	#puts T/final
	lappend types [list [lindex $trange 0] [lindex $trange end] $t]
    }

    if {[llength $wrange]} {
	#puts W/final
	lappend widths [list [lindex $wrange 0] [lindex $wrange end] $w]
    }

    return [list $types $widths]
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
	package require Tcl 8.5 9
	package provide textutil::wcswidth :version
	namespace eval ::textutil {}

	proc ::textutil::wcswidth_type c {
:types
	}

	proc ::textutil::wcswidth_char c {
:widths
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
