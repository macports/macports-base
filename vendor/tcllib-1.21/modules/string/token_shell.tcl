# # ## ### ##### ######## ############# #####################
## Copyright (c) 2013 Andreas Kupries, BSD licensed

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require string::token

# # ## ### ##### ######## ############# #####################
## API setup

namespace eval ::string::token {
    # Note: string::token claims the "text" and "file" commands.
    namespace export shell
    namespace ensemble create
}

proc ::string::token::shell {args} {
    # result = list (word)

    set partial 0
    set indices 0
    while {[llength $args]} {
	switch -glob -- [set o [lindex $args 0]] {
	    -partial { set partial 1 }
	    -indices { set indices 1 }
	    -- {
		set args [lrange $args 1 end]
		break
	    }
	    -* {
		# Unknown option.
		return -code error \
		    -errorcode {STRING TOKEN SHELL BAD OPTION} \
		    "Bad option $o, expected one of -indices, or -partial"
	    }
	    * {
		# Non-option, stop option processing.
		break
	    }
	}
	set args [lrange $args 1 end]
    }
    if {[llength $args] != 1} {
	return -code error \
	    -errorcode {STRING TOKEN WRONG ARGS} \
	    "wrong \# args: should be \"[lindex [info level 0] 0] ?-indices? ?-partial? ?--? text\""
    } else {
	set text [lindex $args 0]
    }

    set space    \\s
    set     lexer {}
    lappend lexer ${space}+                                  WSPACE
    lappend lexer {'[^']*'}                                  S:QUOTED
    lappend lexer "\"(\[^\"\]|(\\\\\")|(\\\\\\\\))*\""       D:QUOTED
    lappend lexer "((\[^ $space'\"\])|(\\\\\")|(\\\\\\\\))+" PLAIN

    if {$partial} {
	lappend lexer {'[^']*$}                             S:QUOTED:PART
	lappend lexer "\"(\[^\"\]|(\\\\\")|(\\\\\\\\))*$"   D:QUOTED:PART
    }

    lappend lexer {.*}                                       ERROR

    set dequote [list \\" \" \\\\ \\ ] ; #"

    set result {}

    # Parsing of a shell line is a simple grammar, RE-equivalent
    # actually, thus tractable with a plain finite state machine.
    #
    # States:
    # - WS-WORD : Expected whitespace or word.
    # - WS      : Expected whitespace
    # - WORD    : Expected word.

    # We may have leading whitespace.
    set state WS-WORD
    foreach token [text $lexer $text] {
	lassign $token type start end

	#puts "[format %7s $state] + ($token) = <<[string range $text $start $end]>>"

	set changed 0
	switch -glob -- ${type}/$state {
	    ERROR/* {
		return -code error \
		    -errorcode {STRING TOKEN SHELL BAD SYNTAX CHAR} \
		    "Unexpected character '[string index $text $start]' at offset $start"
	    }
	    WSPACE/WORD {
		# Impossible
		return -code error \
		    -errorcode {STRING TOKEN SHELL BAD SYNTAX WHITESPACE} \
		    "Expected start of word, got whitespace at offset $start."
	    }
	    PLAIN/WS -
	    *:QUOTED*/WS {
		return -code error \
		    -errorcode {STRING TOKEN SHELL BAD SYNTAX WORD} \
		    "Expected whitespace, got start of word at offset $start"
	    }
            WSPACE/WS* {
		# Ignore leading, inter-word, and trailing whitespace
		# Must be followed by a word
		set state WORD
	    }
	    S:QUOTED/*WORD {
		# Quoted word, single, extract it, ignore delimiters.
		# Must be followed by whitespace.
		incr start
		incr end -1
		lappend result [string range $text $start $end]
		set state WS
		set changed 1
	    }
	    S:QUOTED:PART/*WORD {
		# Quoted partial word (at end), single, extract it, ignore delimiter at start, none at end.
		# Must be followed by nothing.
		incr start
		lappend result [string range $text $start $end]
		set state WS
		set changed 1
	    }
	    D:QUOTED/*WORD {
		# Quoted word, double, extract it, ignore delimiters.
		# Have to check for and reduce escaped double quotes and backslashes.
		# Must be followed by whitespace.
		incr start
		incr end -1
		lappend result [string map $dequote [string range $text $start $end]]
		set state WS
		set changed 1
	    }
	    D:QUOTED:PART/*WORD {
		# Quoted word, double, extract it, ignore delimiter at start, none at end.
		# Have to check for and reduce escaped double quotes and backslashes.
		# Must be followed by nothing.
		incr start
		lappend result [string map $dequote [string range $text $start $end]]
		set state WS
		set changed 1
	    }
	    PLAIN/*WORD {
		# Unquoted word. extract.
		# Have to check for and reduce escaped double quotes and backslashes.
		# Must be followed by whitespace.
		lappend result [string map $dequote [string range $text $start $end]]
		set state WS
		set changed 1
	    }
	    * {
		return -code error \
		    -errorcode {STRING TOKEN SHELL INTERNAL} \
		    "Illegal token/state combination $type/$state"
	    }
        }
	if {$indices && $changed} {
	    set last [lindex $result end]
	    set result [lreplace $result end end [list {*}$token $last]]
	}
    }
    return $result
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide string::token::shell 1.2
return
