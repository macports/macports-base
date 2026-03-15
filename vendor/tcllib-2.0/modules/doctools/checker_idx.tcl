# -*- tcl -*-
# checker_idx.tcl
#
# Code used inside of a checker interpreter to ensure correct usage of
# docidx formatting commands.
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
# idx_begin	| idx_begin		| -> contents
# --------------+-----------------------+----------------------
# contents	| key			| -> ref_series
# --------------+-----------------------+----------------------
# ref_series	| manpage		| -> refkey_series
#		| url			|
# --------------+-----------------------+----------------------
# refkey_series	| manpage		| -> refkey_series
#		| url			|
#		+-----------------------+-----------
#		| key			| -> ref_series
#		+-----------------------+-----------
#		| idx_end		| -> done
# --------------+-----------------------+----------------------

# State machine, as above ... Command centered
# --------------+-----------------------+----------------------
# state		| allowed commands	| new state (if any)
# --------------+-----------------------+----------------------
# all except	| include vset		|
# ==============+=======================+======================
# idx_begin	| idx_begin		| -> contents
# --------------+-----------------------+----------------------
# contents	| key			| -> ref_series
# refkey_series	|			|
# --------------+-----------------------+----------------------
# ref_series	| manpage		| -> refkey_series
# refkey_series	|			|
# --------------+-----------------------+----------------------
# ref_series	| url			| -> refkey_series
# refkey_series	|			|
# --------------+-----------------------+----------------------
# refkey_series	| idx_end		| -> done
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

    dt_error "IDX error ($code), \"$cmd\" : ${msg}."
    return
}
proc Warn {code text} {
    set msg [::msgcat::mc $code]
    dt_warning "IDX warning ($code): [join [split [format $msg $text] \n] "\nIDX warning ($code): "]"
    return
}

proc Is    {s} {global state ; return [string equal $state $s]}
proc IsNot {s} {global state ; return [expr {![string equal $state $s]}]}
proc Go    {s} {Log " >>\[$s\]" ; global state ; set state $s; return}
proc Push  {s} {Log " //\[$s\]" ; global state stack ; lappend stack $state ; set state $s; return}
proc Pop   {}  {Log* " pop" ;  global state stack ; set state [lindex $stack end] ; set stack [lrange $stack 0 end-1] ; Log " \\\\\[$state\]" ; return}
proc State {} {global state ; return $state}

proc Enter {cmd} {Log* "\[[State]\] $cmd"}

#proc Log* {text} {puts -nonewline $text}
#proc Log  {text} {puts            $text}
proc Log* {text} {}
proc Log  {text} {}

# -------------------------------------------------------------
# Framing
proc ck_initialize {} {
    global state   ; set state idx_begin
    global stack   ; set stack [list]
}
proc ck_complete {} {
    if {[Is done]} {
	return
    } else {
	Error end/open/idx
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
    Error idx/plaintext
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
proc index_begin {label title} {
    Enter index_begin
    if {[IsNot idx_begin]} {Error idx/begincmd}
    Go contents
    fmt_index_begin $label $title
}
proc index_end {} {
    Enter index_end
    if {[IsNot refkey_series] && [IsNot contents]} {Error idx/endcmd}
    Go done
    fmt_index_end
}
proc key {text} {
    Enter key
    if {[IsNot contents] && [IsNot refkey_series]} {Error idx/keycmd}
    Go ref_series
    fmt_key $text
}
proc manpage {file label} {
    Enter manpage
    if {[IsNot ref_series] && [IsNot refkey_series]} {Error idx/manpagecmd}
    Go refkey_series
    fmt_manpage $file $label
}
proc url {url label} {
    Enter url
    if {[IsNot ref_series] && [IsNot refkey_series]} {Error idx/urlcmd}
    Go refkey_series
    fmt_url $url $label
}
proc comment {text} {
    if {[Is done]} {Error idx/nodonecmd}
    return ; #fmt_comment $text
}

# -------------------------------------------------------------
