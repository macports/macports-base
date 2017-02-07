#####
#
# "BibTeX parser"
# http://wiki.tcl.tk/13719
#
# Tcl code harvested on:   7 Mar 2005, 23:55 GMT
# Wiki page last updated: ???
#
#####

# bibtex.tcl --
#
#      A basic parser for BibTeX bibliography databases.
#
# Copyright (c) 2005 Neil Madden.
# Copyright (c) 2005 Andreas Kupries.
# License: Tcl/BSD style.

### NOTES
###
### Need commands to introspect parser state. Especially the string
### map (for testing of 'addStrings', should be useful in general as
### well).

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.4
package require cmdline

# ### ### ### ######### ######### #########
## Implementation: Public API

namespace eval ::bibtex {}

# bibtex::parse --
#
#	Parse a bibtex file.
#
# parse ?options? ?bibtex?

proc ::bibtex::parse {args} {
    variable data
    variable id

    # Argument processing
    if {[llength $args] < 1} {
	set err "[lindex [info level 0] 0] ?options? ?bibtex?"
	return -code error "wrong # args: should be \"$err\""
    }

    array set state {}
    GetOptions $args state

    # Initialize the parser state from the options, fill in default
    # values, and handle the input according the specified mode.

    set token bibtex[incr id]
    foreach {k v} [array get state] {
	set data($token,$k) $v
    }

    if {$state(stream)} {
	# Text not in memory
	if {!$state(bg)} {
	    # Text from a channel, no async processing. We read everything
	    # into memory and the handle it as before.

	    set blockmode [fconfigure $state(-channel) -blocking]
	    fconfigure $state(-channel) -blocking 1
	    set data($token,buffer) [read $state(-channel)]
	    fconfigure $state(-channel) -blocking $blockmode

	    # Tell upcoming processing that the text is in memory.
	    set state(stream) 0
	} else {
	    # Text from a channel, and processing is async. Create an
	    # event handler for the incoming data.

	    set data($token,done) 0
	    fileevent $state(-channel) readable \
		    [list ::bibtex::ReadChan $token]

	    # Initialize the parser internal result buffer if we use plain
	    # -command, and not the SAX api.
	    if {!$state(sax)} {
		set data($token,result) {}
	    }
	}
    }

    # Initialize the string mappings (none known), and the result
    # accumulator.
    set data($token,strings) {}
    set data($token,result)  {}

    if {!$state(stream)} {
	ParseRecords $token 1
	if {$state(sax)} {
	    set result $token
	} else {
	    set result $data($token,result)
	    destroy $token
	}
	return $result
    }

    # Assert: Processing is in background.
    return $token
}

# Cleanup a parser, cancelling any callbacks etc.

proc ::bibtex::destroy {token} {
    variable data

    if {![info exists data($token,stream)]} {
	return -code error "Illegal bibtex parser \"$token\""
    }
    if {$data($token,stream)} {
	fileevent $data($token,-channel) readable {}
    }

    array unset data $token,*
    return
}


proc ::bibtex::wait {token} {
    variable data

    if {![info exists data($token,stream)]} {
	return -code error "Illegal bibtex parser \"$token\""
    }
    vwait ::bibtex::data($token,done)
    return
}

# bibtex::addStrings --
#
#	Add strings to the map for a particular parser. All strings are
#	expanded at parse time.

proc ::bibtex::addStrings {token strings} {
    variable data
    eval [linsert $strings 0 lappend data($token,strings)]
    return
}

# ### ### ### ######### ######### #########
## Implementation: Private utility routines

proc ::bibtex::AddRecord {token type key recdata} {
    variable data
    lappend  data($token,result) [list $type $key $recdata]
    return
}

proc ::bibtex::GetOptions {argv statevar} {
    upvar 1 $statevar state

    # Basic processing of the argument list
    # and the options found therein.

    set opts [lrange [::cmdline::GetOptionDefaults {
	{command.arg              {}}
	{channel.arg              {}}
	{recordcommand.arg        {}}
	{preamblecommand.arg      {}}
	{stringcommand.arg        {}}
	{commentcommand.arg       {}}
	{progresscommand.arg      {}}
	{casesensitivestrings.arg {}}
    } result] 2 end] ;# Remove ? and help.

    set argc [llength $argv]
    while {[set err [::cmdline::getopt argv $opts opt arg]]} {
	if {$err < 0} {
	    set olist ""
	    foreach o [lsort $opts] {
		if {[string match *.arg $o]} {
		    set o [string range $o 0 end-4]
		}
		lappend olist -$o
	    }
	    return -code error "bad option \"$opt\",\
		    should be one of\
		    [linsert [join $olist ", "] end-1 or]"
	}
	set state(-$opt) $arg
    }

    # Check the information gained so far
    # for inconsistencies and/or missing
    # pieces.

    set sax [expr {
	[info exists state(-recordcommand)]   ||
	[info exists state(-preamblecommand)] ||
	[info exists state(-stringcommand)]   ||
	[info exists state(-commentcommand)]  ||
	[info exists state(-progresscommand)]
    }] ; # {}

    set bg [info exists state(-command)]

    if {$sax && $bg} {
	# Sax callbacks and channel completion callback exclude each
	# other.
	return -code error "The options -command and -TYPEcommand exclude each other"
    }

    set stream [info exists state(-channel)]

    if {$stream} {
	# Channel is present, a text is not allowed.
	if {[llength $argv]} {
	    return -code error "Option -channel and text exclude each other"
	}

	# The channel has to exist as well.
	if {[lsearch -exact [file channels] $state(-channel)] < 0} {
	    return -code error "Illegal channel handle \"$state(-channel)\""
	}
    } else {
	# Channel is not present, we have to have a text, and only
	# exactly one. And a general -command callback is not allowed.

	if {![llength $argv]} {
	    return -code error "Neither -channel nor text specified"
	} elseif {[llength $argv] > 1} {
	    return -code error "wrong # args: [lindex [info level 1] 0] ?options? ?bibtex?"
	}

	# Channel completion callback is not allowed if we are not
	# reading from a channel.

	if {$bg} {
	    return -code error "Option -command and text exclude each other"
	}

	set state(buffer) [lindex $argv 0]
    }

    set state(stream) $stream
    set state(sax)    $sax
    set state(bg)     [expr {$sax || $bg}]

    if {![info exists state(-stringcommand)]} {
	set state(-stringcommand) [list ::bibtex::addStrings]
    }
    if {![info exists state(-recordcommand)] && (!$sax)} {
	set state(-recordcommand) [list ::bibtex::AddRecord]
    }
    if {[info exists state(-casesensitivestrings)] &&
	$state(-casesensitivestrings)
    } {
	set state(casesensitivestrings) 1
    } else {
	set state(casesensitivestrings) 0
    }
    return
}

proc ::bibtex::Callback {token type args} {
    variable data

    #puts stdout "Callback ($token $type ($args))"

    if {[info exists data($token,-${type}command)]} {
	eval $data($token,-${type}command) [linsert $args 0 $token]
    }
    return
}

proc ::bibtex::ReadChan {token} {
    variable data

    # Read the waiting characters into our buffer and process
    # them. The records are saved either through a user supplied
    # record callback, or the standard callback for our non-sax
    # processing.

    set    chan $data($token,-channel)
    append data($token,buffer) [read $chan]

    if {[eof $chan]} {
	# Final processing. In non-SAX mode we have to deliver the
	# completed result before destroying the parser.

	ParseRecords $token 1
	set data($token,done) 1
	if {!$data($token,sax)} {
	    Callback $token {} $data($token,result)
	}
	return
    }

    # Processing of partial data.

    ParseRecords $token 0
    return
}

proc ::bibtex::Tidy {str} {
    return [string tolower [string trim $str]]
}

proc ::bibtex::ParseRecords {token eof} {
    # A rough BibTeX grammar (case-insensitive):
    #
    # Database      ::= (Junk '@' Entry)*
    # Junk          ::= .*?
    # Entry         ::= Record
    #               |   Comment
    #               |   String
    #               |   Preamble
    # Comment       ::= "comment" [^\n]* \n         -- ignored
    # String        ::= "string" '{' Field* '}'
    # Preamble      ::= "preamble" '{' .* '}'       -- (balanced)
    # Record        ::= Type '{' Key ',' Field* '}'
    #               |   Type '(' Key ',' Field* ')' -- not handled
    # Type          ::= Name
    # Key           ::= Name
    # Field         ::= Name '=' Value
    # Name          ::= [^\s\"#%'(){}]*
    # Value         ::= [0-9]+
    #               |   '"' ([^'"']|\\'"')* '"'
    #               |   '{' .* '}'                  -- (balanced)

    # " - Fixup emacs hilit confusion from the grammar above.
    variable data
    set bibtex $data($token,buffer)

    # Split at each @ character which is at the beginning of a line,
    # modulo whitespace. This is a heuristic to distinguish the @'s
    # starting a new record from the @'s occuring inside a record, as
    # part of email addresses. Empty pices at beginning or end are
    # stripped before the split.

    regsub -line -all {^[\n\r\f\t ]*@} $bibtex \000 bibtex
    set db [split [string trim $bibtex \000] \000]

    if {$eof} {
	set total [llength $db]
	set step  [expr {double($total) / 100.0}]
	set istep [expr {$step > 1 ? int($step) : 1}]
	set count 0
    } else {
	if {[llength $db] < 2} {
	    # Nothing to process, or data which ay be incomplete.
	    return
	}

	set data($token,buffer) [lindex $db end]
	set db                  [lrange $db 0 end-1]

	# Fake progress meter.
	set count -1
    }

    foreach block $db {
	if {$count < 0} {
	    Callback $token progress -1
	} elseif {([incr count] % $istep) == 0} {
	    Callback $token progress [expr {int($count / $step)}]
	}
	if {[regexp -nocase {\s*comment([^\n])*\n(.*)} $block \
		-> cmnt rest]} {
	    # Are @comments blocks, or just 1 line?
	    # Does anyone care?
	    Callback $token comment $cmnt

	} elseif {[regexp -nocase {^\s*string[^\{]*\{(.*)\}[^\}]*} \
		$block -> rest]} {
	    # string macro defs
	    if {$data($token,casesensitivestrings)} {
		Callback $token string [ParseString $rest]
	    } else {
		Callback $token string [ParseBlock $rest]
	    }
	} elseif {[regexp -nocase {\s*preamble[^\{]*\{(.*)\}[^\}]*} \
		$block -> rest]} {
	    Callback $token preamble $rest

	} elseif {[regexp {([^\{]+)\{([^,]*),(.*)\}[^\}]*} \
		$block -> type key rest]} {
	    # Do any @string mappings
	    if {$data($token,casesensitivestrings)} {
		# puts $data($token,strings)
		set rest [string map $data($token,strings) $rest]
	    } else {
		set rest [string map -nocase $data($token,strings) $rest]
	    }
	    Callback $token record [Tidy $type] [string trim $key] \
		    [ParseBlock $rest]
	} else {
	    ## FUTURE: Use a logger.
	    puts stderr "Skipping: $block"
	}
    }
}

proc ::bibtex::ParseString {block} {
    regexp {(\S+)[^=]*=(.*)} $block -> key rest
    return [list $key $rest]
}

proc ::bibtex::ParseBlock {block} {
    set ret   [list]
    set index 0
    while {
	[regexp -start $index -indices -- \
		{(\S+)[^=]*=(.*)} $block -> key rest]
    } {
	foreach {ks ke} $key break
	set k [Tidy [string range $block $ks $ke]]
	foreach {rs re} $rest break
	foreach {v index} \
		[ParseBibString $rs [string range $block $rs $re]] \
		break
	lappend ret $k $v
    }
    return $ret
}

proc ::bibtex::ParseBibString {index str} {
    set count 0
    set retstr ""
    set escape 0
    set string 0
    foreach char [split $str ""] {
	incr index
	if {$escape} {
	    set escape 0
	} else {
	    if {$char eq "\{"} {
		incr count
		continue
	    } elseif {$char eq "\}"} {
		incr count -1
		if {$count < 0} {incr index -1; break}
		continue
	    } elseif {$char eq ","} {
		if {$count == 0} break
	    } elseif {$char eq "\\"} {
		set escape 1
		continue
	    } elseif {$char eq "\""} {
		# Managing the count ensures that comma inside of a
		# string is not considered as the end of the field.
		if {!$string} {
		    incr count
		    set string 1
		} else {
		    incr count -1
		    set string 0
		}
		continue
	    }
	    # else: Nothing
	}
	append retstr $char
    }
    regsub -all {\s+} $retstr { } retstr
    return [list [string trim $retstr] $index]
}


# ### ### ### ######### ######### #########
## Internal. Package configuration and state.

namespace eval bibtex {
    # Counter for the generation of parser tokens.
    variable id 0

    # State of all parsers. Keys for each parser are prefixed with the
    # parser token.
    variable  data
    array set data {}

    # Keys and their meaning (listed without token prefix)
    ##
    # buffer
    # eof
    # channel    <-\/- Difference ?
    # strings      |
    # -async       |
    # -blocksize   |
    # -channel   <-/
    # -recordcommand   -- callback for each record
    # -preamblecommand -- callback for @preamble blocks
    # -stringcommand   -- callback for @string macros
    # -commentcommand  -- callback for @comment blocks
    # -progresscommand -- callback to indicate progress of parse
    ##
}

# ### ### ### ######### ######### #########
## Ready to go
package provide bibtex 0.6
# EOF
