#! /usr/bin/env tclsh
# -*- tcl -*-

# @@ Meta Begin
# Application tcldocstrip 1.0.1
# Meta platform     tcl
# Meta summary      TeX's docstrip written in Tcl
# Meta description  This application is an implementation
# Meta description  of TeX's docstrip application in Tcl.
# Meta description  It provides commands to convert a docstrip
# Meta description  weave according to a set of guards, to
# Meta description  assemble an output based on several sets
# Meta description  guards and input files, i.e. of a document
# Meta description  spread over several inputs and/or guards,
# Meta description  and to extract and list all unique guard
# Meta description  expressions found in a document.
# Meta category     Processing docstrip documents
# Meta subject      docstrip TeX LaTeX
# Meta require      docstrip
# Meta author       Andreas Kupries
# Meta license      BSD
# @@ Meta End

package provide tcldocstrip 1.0.1

# TODO __________________________
# Add handling of pre- and postambles.

# tcldocstrip - Docstrip written in Tcl
# =========== = =======================
#
# Use cases
# ---------
#
# (-)	Providing access to the functionality of the tcllib/docstrip
#	package from within shell and other scripts which are not Tcl.
#
# (1)	Conversion of a single input file according to the listed
#	guards into the stripped output.
#
#	This handles the most simple case of a set of guards
#	specifying a single document found in a single input file.
#
# (2)	Stitching, or the assembly of an output from several sets of
#	guards, in a specific order, and possibly from different
#	files. This is the second common case. One document spread
#	over several inputs, and/or spread over different guard sets.
#
# (3)	Extraction and listing of all the unique guard expressions and
#	guards used within a document to help a person which did not
#	author the document in question in familiarizing itself with
#	it.
# 
# Command syntax
# --------------
# 
# Ad 1)	tcldocstrip output|"-" ?options? input ?guards?
#
#	Converts the input file according to the specified guards and
#	options. The result is written to the named output. Usage of
#	the string "-" as output signals that the result should be
#	written to stdout. The guards are document-specific and have
#	to be known to the caller. The options are the same as
#	accepted by docstrip::extract.
#
#	-metaprefix string
#	-onerror    mode   {ignore,puts,throw}
#	-trimlines  bool
#
#	Additional options understood are
#
#	-premamble text
#	-postamble text
#	-nopremamble
#	-nopostamble
#
#	These are processed by the application itself. The -no*amble
#	options deactivate pre- and postambles altogether, whereas the
#	-*amble specify the _user_ part of pre- and postambles. This
#	part can be empty, in that case only the standard parts are
#	shown. This is the default.
#
# Ad 2)	tcldocstrip ?options? output|"-" (?options? input|"." guards)...
#
#	Extracts data from the various input files, according to the
#	specified options and guards, and writes the result to the
#	given output, in the order of their specification on the
#	command line. Options specified before the output are global
#	settings, whereas the options specified before each input are
#	valid only just for this input file. Unspecified values are
#	taken from the global settings. As in (1) "-" as output causes
#	the application to write to stdout. Using "." for an input
#	file signals that the last input file should be used
#	again. This enables the assembly of the output from one input
#	file using multiple and different sets of guards.
#
# Ad 3) tcldocstrip -guards input
#
#	Determines the guards, and unique guard expressions used
#	within the input document. The found strings are written to
#	stdout, one string per line.
#

lappend auto_path [file join [file dirname [file dirname [info script]]] modules]
package require docstrip

# ### ### ### ######### ######### #########
## Internal data and status

namespace eval ::tcldocstrip {

    # List of global options and their arguments found in the command
    # line. No checking was done on them, they are simply passed to
    # the extraction command.

    variable options {}

    # List of input specifications. Each element is a list specifying
    # the extraction options, input file, and guard set, in this
    # order.

    variable stitch {}

    # Name of the file to write to. "-" signals that output has to be
    # written to stdout.

    variable output {}

    # Mode of operation: Conversion, or guard retrieval

    variable mode Extract

    # The input file for guard retrieval mode.

    variable input {}

    # Standard preamble to preambles

    variable preamble {}
    append   preamble                                           \n
    append   preamble "This is file `@output@',"                \n
    append   preamble "generated with the tcldocstrip utility." \n
    append   preamble                                           \n
    append   preamble "The original source files were:"         \n
    append   preamble                                           \n
    append   preamble "@input@  (with options: `@guards@')"     \n
    append   preamble                                           \n

    # Standard postamble to postambles

    variable postamble {}
    append   postamble                           \n
    append   postamble                           \n
    append   postamble "End of file `@output@'."

    # Default values for the options which are relevant to the
    # application itself and thus have to be defined always.
    # They are processed as global options, as part of argv.

    variable defaults {-metaprefix {%} -preamble {} -postamble {}}
}

# ### ### ### ######### ######### #########
## External data and status
#
## This tool does not depend on external data and/or status.

# ### ### ### ######### ######### #########
## Option processing.
## Validate command line.
## Full command line syntax.
##
# tcldocstrip ?-option value...? input ?guard...?
##

proc ::tcldocstrip::processCmdline {} {
    global argv

    variable defaults
    variable preamble
    variable postamble
    variable options
    variable stitch
    variable output
    variable input
    variable mode

    # Process the options, perform basic validation.

    set optbuf    {}
    set stitchbuf {}
    set get output

    if {![llength $argv]} {
	set argv $defaults
    } else {
	set argv [eval [linsert $argv 0 linsert $defaults end]]
    }

    while {[llength $argv]} {
	set opt [lindex $argv 0]
	if {($opt eq "-") || ![string match "-*" $opt]} {
	    # Non option state machine. Output first. Then input and
	    # guards alternating.

	    set argv [lrange $argv 1 end]
	    switch -exact -- $get {
		output {
		    set output $opt
		    set get input
		}
		input {
		    lappend stitchbuf $optbuf $opt
		    set optbuf {}
		    set get guards
		}
		guards {
		    lappend stitchbuf $opt
		    set get input
		    lappend stitch $stitchbuf
		    set stitchbuf {}
		}
	    }
	    continue
	}

	switch -exact -- $opt {
	    -guards {
		if {
		    ($get ne "output") ||
		    ([llength $argv] != 2)
		} Usage

		set mode Guards
		set input [lindex $argv 1]
		break
	    }
	    -nopreamble -
	    -nopostamble {
		set o -[string range $opt 3 end]
		if {$get eq "output"} {
		    lappend options $o ""
		} else {
		    lappend optbuf  $o ""
		}
	    }
	    -preamble {
		set val $preamble[lindex $argv 1]
		if {$get eq "output"} {
		    lappend options $opt $val
		} else {
		    lappend optbuf  $opt $val
		}
		set argv [lrange $argv 2 end]
	    }
	    -postamble {
		set val [lindex $argv 1]$postamble
		if {$get eq "output"} {
		    lappend options $opt $val
		} else {
		    lappend optbuf  $opt $val
		}
		set argv [lrange $argv 2 end]
	    }
	    default {
		set val [lindex $argv 1]
		if {$get eq "output"} {
		    lappend options $opt $val
		} else {
		    lappend optbuf $opt $val
		}

		set argv [lrange $argv 2 end]
	    }
	}
    }

    if {$get eq "guards"} {
	# Complete last input spec, may have no guards.
	lappend stitchbuf {}
	lappend stitch $stitchbuf
	set stitchbuf {}
    }

    # Additional validation.

    if {$mode eq "Guards"} {
	CheckInput $input {Input path}
	return
    }

    if {![llength $stitch]} {
	Usage
    }

    set first 1
    foreach in $stitch {
	foreach {o i g} $in break
	if {$first || ($i ne ".")} {
	    # First input file must not be ".".
	    CheckInput $i {Input path}
	}
	set first 0
    }

    CheckTheOutput
    return
}

# ### ### ### ######### ######### #########
## Option processing.
## Helpers: Generation of error messages.
## I.  General usage/help message.
## II. Specific messages.
#
# Both write their messages to stderr and then
# exit the application with status 1.
##

proc ::tcldocstrip::Usage {} {
    global argv0
    puts stderr "$argv0: ?options? output (?options? input guards)..."
    puts stderr "$argv0: -guards input"
    exit 1
}

proc ::tcldocstrip::ArgError {text} {
    global argv0
    puts stderr "$argv0: $text"
    exit 1
}

proc in {list item} {
    expr {([lsearch -exact $list $item] >= 0)}
}

# ### ### ### ######### ######### #########
## Check existence and permissions of an input/output file or
## directory.

proc ::tcldocstrip::CheckInput {f label} {
    if {![file exists $f]} {
	ArgError "Unable to find $label \"$f\""
    } elseif {![file readable $f]} {
	ArgError "$label \"$f\" not readable (permission denied)"
    } elseif {![file isfile $f]} {
	ArgError "$label \"$f\" is not a file"
    }
    return
}

proc ::tcldocstrip::CheckTheOutput {} {
    variable output

    if {$output eq ""} {
	ArgError "No output path specified"
    } elseif {$output eq "-"} {
	# Stdout. This is ok.
	return
    }

    set base [file dirname $output]
    if {[string equal $base ""]} {set base [pwd]}

    if {![file exists $output]} {
	if {![file exists $base]} {
	    ArgError "Output base path \"$base\" not found"
	}
	if {![file writable $base]} {
	    ArgError "Output base path \"$base\" not writable (permission denied)"
	}
    } elseif {![file writable $output]} {
	ArgError "Output path \"$output\" not writable (permission denied)"
    } elseif {![file isfile $output]} {
	ArgError "Output path \"$output\" is not a file"
    }
    return
}

# ### ### ### ######### ######### #########
## Helper commands. File reading and writing.

proc ::tcldocstrip::Get {f} {
    variable data
    if {[info exists data($f)]} {return $data($f)}
    return [set data($f) [read [set in [open $f r]]][close $in]]
}

proc ::tcldocstrip::Write {f data} {
    puts -nonewline [set out [open $f w]] $data
    close $out
    return
}

proc ::tcldocstrip::WriteStdout {data} {
    puts -nonewline stdout $data
    return
}

# ### ### ### ######### ######### #########
## Helper commands. Guard extraction.

proc ::tcldocstrip::Guards {text} {
    array set g {}
    set verbatim 0
    set verbtag  {}
    foreach line [split $text \n] {
	if {$verbatim} {
	    # End of verbatim mode
	    if {$line eq $verbtag} {set verbatim 0}
	    continue
	}
	switch -glob -- $line {
	    %<<* {
		# Start of verbatim mode.
		set verbatim 1
		set verbtag %[string range $line 3 end]
		continue
	    }
	    %<* {
		if {![regexp -- {^%<([*/+-]?)([^>]*)>(.*)$} \
			  $line --> modifier expression line]} {
		    # Malformed guard. FUTURE Handle via -onerror. For now: ignore.
		    continue
		}
		# Remember the guard. Hashtable ensures that
		# duplicates are removed automatically.
		set g($expression) .
	    }
	    default {continue}
	}
    }
    return [array names g]
}


# ### ### ### ######### ######### #########
## Configuation phase, validate command line.

::tcldocstrip::processCmdline

# ### ### ### ######### ######### #########
## Commands implementing the main functionality.

proc ::tcldocstrip::Do.Extract {} {
    variable stitch
    variable output
    variable options

    set text ""

    foreach in $stitch {
	foreach {opt input guards} $in break

	# Merge defaults, global and local options, then filch the
	# options handled in the application.

	unset -nocomplain o
	array set o $options
	array set o $opt
	
	set pre ""
	if {[info exists o(-preamble)]} {
	    set pre $o(-preamble)
	    unset o(-preamble)
	}
	set post ""
	if {[info exists o(-postamble)]} {
	    set post $o(-postamble)
	    unset o(-postamble)
	}

	set opt [array get o]
	set c $o(-metaprefix)

	set pmap [list \
		      @output@ $output \
		      @input@  $input  \
		      @guards@ $guards \
		     ]

	if {$pre ne ""} {
	    append text $c $c " " [join [split [string map $pmap $pre]  \n] "\n$c$c "]
	}

	append text [eval [linsert $opt 0 docstrip::extract [Get $input] $guards]]

	if {$post ne ""} {
	    append text $c $c " " [join [split [string map $pmap $post] \n] "\n$c$c "]
	}   
    }

    if {$output eq "-"} {
	WriteStdout $text
    } else {
	Write $output $text
    }
    return
}

proc ::tcldocstrip::Do.Guards {} {
    variable input

    WriteStdout [join [lsort [Guards [Get $input]]] \n]
    return
}

# ### ### ### ######### ######### #########
## Invoking the functionality.

if {[catch {
    set mode $::tcldocstrip::mode
    ::tcldocstrip::Do.$mode
} msg]} {
    ## puts $::errorInfo
    ::tcldocstrip::ArgError $msg
}

# ### ### ### ######### ######### #########
exit

# Generic internal command for error handling. Factored out of the
# implementation of extract into its own command.

proc HandleError {text attr lineno} {
    variable O

    switch -- [string tolower $O(-onerror)] "puts" {
	puts stderr "docstrip: $text on line $lineno."
    } "ignore" {} default {
	return \
	    -code      error \
	    -errorinfo "" \
	    -errorcode [linsert $attr end $lineno] \
	    $text
    }
}
