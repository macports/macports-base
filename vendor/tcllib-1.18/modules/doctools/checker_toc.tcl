# -*- tcl -*-
# checker_toc.tcl
#
# Code used inside of a checker interpreter to ensure correct usage of
# doctoc formatting commands.
#
# Copyright (c) 2003-2009 Andreas Kupries <andreas_kupries@sourceforge.net>

# L10N

package require msgcat

proc ::msgcat::mcunknown {locale code} {
    return "unknown error code \"$code\" (for locale $locale)"
}

if {0} {
    puts stderr "Locale [::msgcat::mcpreferences]"
    foreach path [dt_search] {
	puts stderr "Catalogs: [::msgcat::mcload $path] - $path"
    }
} else {
    foreach path [dt_search] {
	::msgcat::mcload $path
    }
}

# State, and checker commands.
# -------------------------------------------------------------
#
# Note that the code below assumes that a command XXX provided by the
# formatter engine is accessible under the name 'fmt_XXX'.
#
# -------------------------------------------------------------

global state

# State machine ... State centered
# --------------+-----------------------+----------------------
# state		| allowed commands	| new state (if any)
# --------------+-----------------------+----------------------
# all except	| include vset		|
# ==============+=======================+======================
# toc_begin	| toc_begin		| -> contents
# --------------+-----------------------+----------------------
# contents	| item			| -> contents //
#		+-----------------------+-----------
#		| division_start	| -> end, PUSH division
#		+-----------------------+-----------
#		| toc_end		| -> done
# --------------+-----------------------+----------------------
# division	| item			| -> division //
#		+-----------------------+-----------
#		| division_start	| -> division, PUSH division
#		+-----------------------+-----------
#		| division_end		| POP (-> division / -> end)
# --------------+-----------------------+----------------------
# end		| toc_end		| -> done
#		+-----------------------+-----------
#		| division_start	| PUSH division
# --------------+-----------------------+----------------------

# State machine, as above ... Command centered
# --------------+-----------------------+----------------------
# state		| allowed commands	| new state (if any)
# --------------+-----------------------+----------------------
# all except	| include vset		|
# ==============+=======================+======================
# toc_begin	| toc_begin		| -> contents
# --------------+-----------------------+----------------------
# contents	| item			| -> contents
# division	|			| -> division
# --------------+-----------------------+----------------------
# contents	| division_start	| -> end, PUSH division
# division	|			| -> divison, PUSH division
# end		|			| PUSH division
# --------------+-----------------------+----------------------
# division	| division_end		| POP (-> division / -> end)
# --------------+-----------------------+----------------------
# contents	| toc_end		| -> done
# end		|			| -> done
# --------------+-----------------------+----------------------

# -------------------------------------------------------------
# Helpers
proc Error {code {text {}}} {
    global state

    # Problematic command with all arguments (we strip the "ck_" prefix!)
    # -*- future -*- count lines of input, maintain history buffer, use
    # -*- future -*- that to provide some context here.

    set cmd  [lindex [info level 1] 0]
    set args [lrange [info level 1] 1 end]
    if {$args != {}} {append cmd " [join $args]"}

    # Use a message catalog to map the error code into a legible message.
    set msg [::msgcat::mc $code]

    if {$text != {}} {
	set msg [string map [list @ $text] $msg]
    }

    dt_error "TOC error ($code), \"$cmd\" : ${msg}."
    return
}
proc Warn {code text} {
    set msg [::msgcat::mc $code]
    dt_warning "TOC warning ($code): [join [split [format $msg $text] \n] "\nTOC warning ($code): "]"
    return
}

proc Is    {s} {global state ; return [string equal $state $s]}
proc IsNot {s} {global state ; return [expr {![string equal $state $s]}]}
proc Go    {s} {Log " >>\[$s\]" ; global state ; set state $s; return}
proc Push  {s} {Log " //\[$s\]" ; global state stack ; lappend stack $state ; set state $s; return}
proc Pop   {}  {Log* " pop" ;  global state stack ; set state [lindex $stack end] ; set stack [lrange $stack 0 end-1] ; Log " \\\\\[$state\]" ; return}
proc State {} {global state stack ; return "$stack || $state"}

proc Enter {cmd} {Log* "\[[State]\] $cmd"}

#proc Log* {text} {puts -nonewline $text}
#proc Log  {text} {puts            $text}
proc Log* {text} {}
proc Log  {text} {}

# -------------------------------------------------------------
# Framing
proc ck_initialize {} {
    global state   ; set state toc_begin
    global stack   ; set stack [list]
}
proc ck_complete {} {
    if {[Is done]} {
	return
    } else {
	Error end/open/toc
    }
    return
}
# -------------------------------------------------------------
# Plain text
proc plain_text {text} {
    # Ignore everything which is only whitespace ...
    # Beyond that plain text is not allowed.

    set redux [string map [list " " "" "\t" "" "\n" ""] $text]
    if {$redux == {}} {return [fmt_plain_text $text]}
    Error toc/plaintext
    return ""
}

# -------------------------------------------------------------
# Variable handling ...

proc vset {var args} {
    switch -exact -- [llength $args] {
	0 {
	    # Retrieve contents of variable VAR
	    upvar #0 __$var data
	    return $data
	}
	1 {
	    # Set contents of variable VAR
	    global __$var
	    set    __$var [lindex $args 0]
	    return "" ; # Empty string ! Nothing for output.
	}
	default {
	    return -code error "wrong#args: set var ?value?"
	}
    }
}

# -------------------------------------------------------------
# Formatting commands
proc toc_begin {label title} {
    Enter toc_begin
    if {[IsNot toc_begin]} {Error toc/begincmd}
    Go contents
    fmt_toc_begin $label $title
}
proc toc_end {} {
    Enter toc_end
    if {[IsNot end] && [IsNot contents]} {Error toc/endcmd}
    Go done
    fmt_toc_end
}
proc division_start {title {symfile {}}} {
    Enter division_start
    if {
	[IsNot contents] && [IsNot end] && [IsNot division]
    } {Error toc/sectcmd}
    if {[Is contents] || [Is end]} {Go end} else {Go division}
    Push division
    fmt_division_start $title $symfile
}
proc division_end {} {
    Enter division_end
    if {[IsNot division]} {Error toc/sectecmd [State]}
    Pop
    fmt_division_end
}
proc item {file label desc} {
    Enter item
    if {[IsNot contents] && [IsNot division]} { Error toc/itemcmd }
    fmt_item $file $label $desc
}
proc comment {text} {
    if {[Is done]} {Error toc/nodonecmd}
    return ; #fmt_comment $text
}

# -------------------------------------------------------------
