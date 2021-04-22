# -*- tcl -*-
#
# Copyright (c) 2006 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Parser Generator / Backend - Generate a grammar::me::cpu based parser.

# This package assumes to be used from within a PAGE plugin. It uses
# the API commands listed below. These are identical across the major
# types of PAGE plugins, allowing this package to be used in reader,
# transform, and writer plugins. It cannot be used in a configuration
# plugin, and this makes no sense either.
#
# To ensure that our assumption is ok we require the relevant pseudo
# package setup by the PAGE plugin management code.
#
# -----------------+--
# page_info        | Reporting to the user.
# page_warning     |
# page_error       |
# -----------------+--
# page_log_error   | Reporting of internals.
# page_log_warning |
# page_log_info    |
# -----------------+--

# ### ### ### ######### ######### #########

## The input is a grammar, not as tree, but as a list of instructions
## (symbolic form). This backend converts that into machinecode for
## grammar::m::cpu::core and inserts the result into a template file.

## The translation from grammar tree to assembler code was done in a
## preceding transformation.

# ### ### ### ######### ######### #########
## Requisites

# @mdgen NODEP: page::plugin

package require page::plugin ; # S.a. pseudo-package.

package require grammar::me::cpu::core
package require textutil

#package require page::analysis::peg::emodes
#package require page::util::quote
#package require page::util::peg

namespace eval ::page::gen::peg::mecpu {}

# ### ### ### ######### ######### #########
## API

proc ::page::gen::peg::mecpu::package {text} {
    variable package $text
    return
}

proc ::page::gen::peg::mecpu::copyright {text} {
    variable copyright $text
    return
}

proc ::page::gen::peg::mecpu::template {path} {
    variable template $path
    return
}

proc ::page::gen::peg::mecpu::cmarker {list} {
    variable cmarker $list
    return
}

proc ::page::gen::peg::mecpu {asmcode chan} {

    # asmcode     = list (name code)
    # code        = list (instruction)
    # instruction = list (label name arg...)

    variable mecpu::package
    variable mecpu::copyright
    variable mecpu::cmarker
    variable mecpu::template
    variable mecpu::template_file

    # Import the config options, provide fallback to defaults for the
    # unspecified parts.

    set gname [lindex $asmcode 0]
    set gcode [lindex $asmcode 1]

    if {$package eq ""} {set package $gname}

    page_info "  Grammar:   $gname"
    page_info "  Package:   $package"

    if {$copyright ne ""} {
	page_info "  Copyright: $copyright"
	set copyright "\#\# (C) $copyright\n"
    }

    if {$template eq ""} {
	set template $template_file
    }

    page_info "  Template:  $template"

    # Translate the incoming assembler to machine code.

    set mcode [grammar::me::cpu::core::asm $gcode]

    # We know that the machine code has three parts (instructions,
    # string pool, token map). We take the data apart to allow separate
    # insertion if the template so chooses (like for readability).

    foreach {minsn mpool mtmap} $mcode break

    set fminsn {} ; set i 0 ; set j 19
    while {$i < [llength $minsn]} {
	append fminsn "         [lrange $minsn $i $j]\n"
	incr i 20 ; incr j 20
    }

    set fmpool {} ; set i 0 ; set j 4
    while {$i < [llength $mpool]} {
	append fmpool "         [lrange $mpool $i $j]\n"
	incr i 5 ; incr j 5
    }

    # ------------------------------------
    # We also generate a readable representation of the assembler
    # instructions for insertion into a comment area.

    set asmp [mecpu::2readable $gcode $minsn]

    # ------------------------------------

    # And write the modified template
    puts $chan [string map [list  \
		@NAME@ $gname     \
	        @PKG@  $package   \
	        @COPY@ $copyright \
		@CODE@ $mcode     \
		@INSN@ $minsn     \
		@FNSN@ $fminsn    \
		@POOL@ $mpool     \
		@FPOL@ $fmpool    \
		@TMAP@ $mtmap     \
		@ASMP@ $asmp      \
	       ] [mecpu::Template]]
    return
}

proc ::page::gen::peg::mecpu::Template {} {
    variable template
    return [string trimright [read [set ch [open $template r]]][close $ch]]
}

proc ::page::gen::peg::mecpu::2readable {asmcode mecode} {
    return [2print $asmcode $mecode max [widths $asmcode max]]
}

proc ::page::gen::peg::mecpu::widths {asmcode mv} {
    upvar 1 $mv max

    # First iteration, column widths (instructions, and arguments).
    # Ignore comments, they go across all columns.
    # Also ignore labels (lrange 1 ..).

    set mc 0
    foreach insn $asmcode {
	set i [lindex $insn 1]
	if {$i eq ".C"} continue
	set col 0

	foreach x [lrange $insn 1 end] {
	    set xlen [string length $x]
	    if {![info exists max($col)] || ($xlen > $max($col))} {set max($col) $xlen}
	    incr col

	    # Shift the strings of various commands into the third
	    # column, if they are not already there.

	    if {$i eq "ier_nonterminal"}        {incr col ; set i ""}
	    if {$i eq "isv_nonterminal_leaf"}   {incr col ; set i ""}
	    if {$i eq "isv_nonterminal_range"}  {incr col ; set i ""}
	    if {$i eq "isv_nonterminal_reduce"} {incr col ; set i ""}
	    if {$i eq "inc_save"}               {incr col ; set i ""}
	    if {$i eq "ict_advance"}            {incr col ; set i ""}
	}
	if {$col > $mc} {set mc $col}
    }

    set max($mc) 0
    return $mc
}

proc ::page::gen::peg::mecpu::2print {asmcode mecode mv mc} {
    variable cmarker
    upvar 1 $mv max

    set lines {}
    set pc    0

    foreach insn $asmcode {
	foreach {label name} $insn break
	if {$name  eq ".C"} {lappend lines "" "--  [join [lrange $insn 2 end] " "]" ""}
	if {$label ne ""}   {lappend lines "       ${label}:" }
	if {$name  eq ".C"} continue

	set line  " [format %05d $pc]      "

	set  pcs $pc
	incr pc [llength $insn] ; incr pc -1
	set  pce $pc ; incr pce -1
	set  imecode [lrange $mecode $pcs $pce]

	if {
	    ($name eq "ier_nonterminal") ||
	    ($name eq "isv_nonterminal_leaf") ||
	    ($name eq "isv_nonterminal_range") ||
	    ($name eq "isv_nonterminal_reduce") ||
	    ($name eq "inc_save") ||
	    ($name eq "ict_advance")
	} {
	    # Shift first argument into 2nd column, and quote it as well.
	    set insn [lreplace $insn 2 2 "" '[lindex $insn 2]']
	} elseif {
	    ($name eq "inc_restore") ||
	    ($name eq "ict_match_token") ||
	    ($name eq "ict_match_tokclass")
	} {
	    # Command with quoted arguments, no shifting.
	    set insn [lreplace $insn 3 3 '[lindex $insn 3]']
	} elseif {
	    ($name eq "ict_match_tokrange")
	} {
	    # Command with quoted arguments, no shifting.
	    set insn [lreplace $insn 4 4 '[lindex $insn 4]']
	}

	while {[llength $insn] <= $mc} {lappend insn ""}
	lappend insn "-- $imecode"

	set col 0
	foreach x [lrange $insn 1 end] {
	    set xlen [string length $x]
	    append line " "
	    append line $x
	    append line [string repeat " " [expr {$max($col) - $xlen}]]
	    incr col
	}

	lappend lines $line
    }

    # Wrap the lines into a comment.

    if {$cmarker eq ""} {set cmarker "\#"}

    if {[llength $cmarker] > 1} {
	# Comments are explictly closed as well.

	foreach {cs ce} $cmarker break
	return "$cs [join $lines " $ce\n$cs "] $ce"
    } else {
	# Comments are not explicitly closed. Implicit by end-of-line

	return "$cmarker [join $lines "\n$cmarker "]"
    }
}

# ### ### ### ######### ######### #########
## Internal. Strings.

namespace eval ::page::gen::peg::mecpu {

    variable here          [file dirname [info script]]
    variable template_file [file join $here gen_peg_mecpu.template]

    variable package   ""
    variable copyright ""
    variable template  ""
    variable cmarker   ""
}

# ### ### ### ######### ######### #########
## Ready

package provide page::gen::peg::mecpu 0.1
