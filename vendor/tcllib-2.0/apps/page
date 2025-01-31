#! /usr/bin/env tclsh
# -*- tcl -*-

# @@ Meta Begin
# Application page 1.0
# Meta platform     tcl
# Meta summary      Tool for general text transformation
# Meta description  While the name is an allusion to parser
# Meta description  generation, the modular plugin-based
# Meta description  nature of this application allows for
# Meta description  any type of text transformation which
# Meta description  can be put into a plugin. Still, the
# Meta description  plugins coming with Tcllib all deal
# Meta description  with parser generation.
# Meta category     Processing text files
# Meta subject      {parser generation} {text transformation}
# Meta require      page::pluginmgr
# Meta require      logger
# Meta require      struct::matrix
# Meta author       Andreas Kupries
# Meta license      BSD
# @@ Meta End

package provide page 1.0

lappend auto_path [file join [lindex $tcl_pkgPath end] page]
lappend auto_path [file join [file dirname [file dirname [file normalize [info script]]]] modules]

#lappend auto_path [file join [file dirname [info script]] .. modules]
#source [file join [file dirname [info script]] .. modules struct tree.tcl]

# /=
#  $Id: page,v 1.3 2011/11/10 21:16:02 andreas_kupries Exp $
# \=
#
# PAGE - PArser GEnerator | GTT - General Text Transformation
# ==== = ================ + === = ===========================
#
# Use cases
# ---------
#
# (1)	Read a grammar specification and write out code implementing a
#	parser for that grammar.
#
# (2)	As (1), and additionally allow the user to select between a
#	number of different backends for writing the results.
#	Different forms for the same parser, pretty printing the
#	grammar, different parser types (LL vs LR vs ...). Etc.
#
# (3)	As (1) and/or (2), and additionally allow the user to select
#	the frontend, i.e. the part reading the grammar. This allows
#	the use of different input grammars for the specification of
#	grammars, i.e. PEG, Yacc, Tyacc, Coco, etc.
#
#	Note: For grammars it may be possible to write a unifying
#	frontend whose reader grammar is able to recognize many
#	different grammar formats without requiring the user to
#	specify which format the supplied input is in.
#
# (4)	As (1) and/or (2), and/or (3), and additionally allow the user
#	to select the transformations to execute on the data provided
#	by the frontend before it is given to the backend. At this
#	point the parser generator has transformed into a general tool
#	for the reading, transformation, and writing of any type of
#	structured information.
#
# Note:	For the use cases from (1) to (3) the representations returned
#	by the frontend, and taken by the backend have to be fully
#	specified to ensure that all the parts are working together.
#	For the use case (4) it becomes the responsibility of the user
#	of the tool to specify frontend, backed, and transformations
#	which work properly together.

# Command syntax
# --------------
# 
# Ad 1)	page ?-rd peg|hb|ser? ?-gen tpcp|hb|ser|tree|peg|me|null? ?-min no|reach|use|all? [input|"-" [output|"-"]]
#
#	The tool reads the grammar from the specified inputfile,
#	transforms it as needed and then writes the resulting parser
#	to the outputfile. Usage of "-" for the input signals that the
#	grammar should be read from stdin. Analoguously usage of "-"
#	for the output signals that the results should be written to
#	stdout.
#
#	Unspecified parts of the command line default to "-".
#
# Ad 2)	Not specified yet.
# Ad 3) S.a.
# Ad 4) S.a.

# ### ### ### ######### ######### #########
## Requisites

package require page::pluginmgr ; # Management of the PAGE plugins.
package require logger          ; # Logging subsystem for debugging.
package require struct::matrix  ; # Matrices. For statistics report

# ### ### ### ######### ######### #########
## Internal data and status

namespace eval ::page {
    # Path to where the output goes to. The name of a file, or "-" for
    # stdout.

    variable  output ""

    # Path to where the input comes from. The name of a file, or "-"
    # for stdin.

    variable  input  ""

    # Boolean flag. Input processing is timed.

    variable timed 0

    # Boolean flag. Input processing has progressbar.

    variable progress 0

    # Reader plugin and options.

    variable rd {}

    # List of transforms and their options.

    variable tr {}

    # Writer plugin an options.

    variable wr {}

    # ### ### ### ######### ######### #########

    # Statistics.
    # The number of characters read from the input.

    variable nread 0

    # Progress
    # Counter for when to print progress notification.

    variable ncount 0
    variable ndelta 100

    # Collected statistical output. A matrix object, for proper
    # columnar formatting when generating the report. And the last
    # non-empty string in the first column, to prevent repetition.

    variable statistics {}
    variable slast      {}

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## External data and status

# This tool does not use external files to save and load status
# information. It has no history. If history is required, or data
# beyond the regular input see use cases (2-4). These may allow the
# specification of options specific to the selected frontend, backend,
# and transformations.

# ### ### ### ######### ######### #########
## Option processing.
## Validate command line.
## Full command line syntax.
##
# page [input|"-" [output|"-"]]
##

proc ::page::ProcessCmdline {} {
    global argv

    variable output
    variable input

    set logging 0
    set n [ProcessArguments]

    # No options at all => Default -c peg.

    if {!$n} {
	set argv [linsert $argv 0 -c peg]
	ProcessArguments
    }

    # Additional validation, and extraction of the non-option
    # arguments.

    if {[llength $argv] > 2} Usage

    set input  [lindex $argv 0]
    set output [lindex $argv 1]

    # Final validation across the whole configuration.

    if {$input eq ""} {
	set input -
    } elseif {$input ne "-"} {
	CheckInputFile $input {Input file}
    }

    if {$output eq ""} {
	set output -
    } elseif {$output ne "-"} {
	CheckTheOutput
    }

    CheckReader
    CheckWriter
    CheckTransforms

    if {$logging} {   
	pluginmgr::log [::logger::init page]
    } else {
	pluginmgr::log {}
    }
    return
}

proc ::page::ProcessArguments {} {
    global argv
    upvar 1 logging logging

    variable rd       {}
    variable tr       {}
    variable wr       {}
    variable timed    0
    variable progress 0

    # Process the options, perform basic validation.

    set type     {}
    set name     {}
    set options  {}
    set mode     {}
    set nextmode {}

    set noptions 0

    while {[llength $argv]} {
	#puts ([join $argv ") ("])

	set opt [lindex $argv 0]
	if {![string match "-*" $opt]} {
	    # End of options reached.
	    break
	}
	incr noptions
	Shift
	switch -exact -- $opt {
	    --help - -h - -? {Usage}
	    --version - -V   {Version}

	    -v - --verbose - --log   {set logging 1}
	    -q - --quiet   - --nolog {set logging 0}

	    -P {set progress 1}
	    -T {set timed    1}

	    -D {
		# Activate logging in the safe base for better debugging.
		::safe::setLogCmd {puts stderr}
	    }

	    -r - -rd - --reader {
		Complete
		set type    rd
		set name    [Shift]
		set options {}
	    }
	    -w - -wr - --writer {
		Complete
		set type    wr
		set name    [Shift]
		set options {}
	    }
	    -t - -tr - --transform {
 		Complete
		set type    tr
		set name    [Shift]
		if {$mode eq ""} {set mode tail}
		set options {}
	    }
	    -c - --config {
		set configfile [Shift]
		if {($configfile eq "") || [catch {
		    set newargv [pluginmgr::configuration \
			    $configfile]
		} msg]} {
		    set msg [string map {
			{Unable to locate}
			{Unable to locate configuration}} $msg]

		    ArgError "Bad argument \"$configfile\".\n\t$msg"
		}

		if {[llength $newargv]} {
		    if {![llength $argv]} {
			set argv $newargv
		    } else {
			# linsert argv 0 {expanded}newargv
			# --------------
			#        linsert options 0 (linsert argv 0)

			set argv [eval [linsert $newargv 0 linsert $argv 0]]
			#set argv [linsert $argv 0 {expand}$options]
		    }
		}
	    }
	    -p - --prepend {set nextmode head}
	    -a - --append  {set nextmode tail}

	    --reset        {Complete ; set tr {}}

	    default {
		# All unknown options go into the
		# configuration of the last plugin
		# defined (-r, -w, -t)
		lappend options $opt [Shift]
	    }
	}
    }

    Complete
    return $noptions
}

proc ::page::Shift {} {
    upvar 1 argv argv
    if {![llength $argv]} {return {}}
    set first [lindex $argv 0]
    set argv [lrange $argv 1 end]
    return $first
}

proc ::page::Complete {} {
    upvar 1 type type name name options options mode mode \
	    nextmode nextmode rd rd wr wr tr tr

    #puts "$type $name ($options) \[$mode/$nextmode\]"

    set currentmode $mode
    if {$nextmode ne $mode} {
	set mode $nextmode
    }

    if {$type eq ""} return

    switch -exact -- $type {
	rd {set rd [list $name $options]}
	wr {set wr [list $name $options]}
	tr {
	    if {$currentmode eq "tail"} {
		lappend tr [list $name $options]
	    } else {
		set tr [linsert $tr 0  [list $name $options]]
	    }
	}
    }
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

proc ::page::Usage {} {
    global argv0
    puts stderr "Expected $argv0 ?options? ?inputpath|- ?outputpath|-??"

    puts stderr "    --help, -h, -?        This help"
    puts stderr "    --version, -V,        Version information"
    puts stderr "    -v, --verbose, --log  Activate logging in all loaded plugins"
    puts stderr "    -q, --quiet, --nolog  Disable logging in all loaded plugins"
    puts stderr "    -P                    Activate progress feedback"
    puts stderr "    -T                    Activate collection of timings"
    puts stderr "    -r reader             Specify input plugin"
    puts stderr "    -rd, --reader         See above"
    puts stderr "    -w writer             Specify output plugin"
    puts stderr "    -wr, --writer         See above"
    puts stderr "    -t transform          Specify processing plugin"
    puts stderr "    -tr, --transform      See above"
    puts stderr "    -p, --prepend         Place processing at front"
    puts stderr "    -a, --append          Place processing at end"
    puts stderr "    --reset               Clear list of transforms"
    puts stderr "    -c file               Read configuration file"
    puts stderr "    --configuration       See above."
    puts stderr "    "

    # --log, --nolog, -v, --verbose, -q, --quiet

    exit 1
}

proc ::page::Version {} {
    puts stderr {$Id: page,v 1.3 2011/11/10 21:16:02 andreas_kupries Exp $}
    exit 1
}

proc ::page::ArgError {text} {
    global argv0
    puts stderr "$argv0: $text"
    exit 1
}

proc in {list item} {
    expr {([lsearch -exact $list $item] >= 0)}
}

# ### ### ### ######### ######### #########
## Check existence and permissions of an input/output file

proc ::page::CheckReader {} {
    variable rd

    if {![llength $rd]} {
	ArgError "Input processing module is missing"
    }

    foreach {name options} $rd break

    if {[catch {
	set po [pluginmgr::reader $name]
    } msg]} {
	set msg [string map {
	    {Unable to locate}
	    {Unable to locate reader}} $msg]

	ArgError "Bad argument \"$name\".\n\t$msg"
    }

    set opt {}
    foreach {k v} $options {
	if {![in $po $k]} {
	    ArgError "Input plugin $name: Bad option $k"
	}
	lappend opt $k $v
    }

    pluginmgr::rconfigure $opt
    return
}

proc ::page::CheckWriter {} {
    variable wr

    if {![llength $wr]} {
	ArgError "Output module is missing"
    }

    foreach {name options} $wr break

    if {[catch {
	set po [pluginmgr::writer $name]
    } msg]} {
	set msg [string map {
	    {Unable to locate}
	    {Unable to locate writer}} $msg]

	ArgError "Bad argument \"$name\".\n\t$msg"
    }

    set opt {}
    foreach {k v} $options {
	if {![in $po $k]} {
	    ArgError "Output plugin $name: Bad option $k"
	}
	lappend opt $k $v
    }

    pluginmgr::wconfigure $opt
    return
}

proc ::page::CheckTransforms {} {
    variable tr

    set idlist {}
    foreach t $tr {
	foreach {name options} $t break

	if {[catch {
	    foreach {id po} \
		    [pluginmgr::transform $name] \
		    break
	} msg]} {
	    set msg [string map {
		{Unable to locate}
		{Unable to locate transformation}} $msg]

	    ArgError "Bad argument \"$name\".\n\t$msg"
	}

	set opt {}
	foreach {k v} $options {
	    if {![in $po $k]} {
		ArgError "Processing plugin $name: Bad option $k"
	    }
	    lappend opt $k $v
	}

	pluginmgr::tconfigure $id $opt
	lappend idlist $id
    }

    set tr $idlist
    return
}

proc ::page::CheckInputFile {f label} {
    if {![file exists $f]} {
	ArgError "Unable to find $label \"$f\""
    } elseif {![file isfile $f]} {
	ArgError "$label \"$f\" is not a file"
    } elseif {![file readable $f]} {
	ArgError "$label \"$f\" not readable (permission denied)"
    }
    return
}

proc ::page::CheckTheOutput {} {
    variable output

    set base [file dirname $output]
    if {$base eq ""} {set base [pwd]}

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
## Commands implementing the main functionality.

proc ::page::Read {} {
    variable input
    variable progress
    variable timed
    variable nread

    set    label \[[pluginmgr::rlabel]\]
    set    msg ""
    append msg $label  " "

    if {$input eq "-"} {
	append msg {Reading grammar from stdin}
	set chan stdin
    } else {
	append msg {Reading grammar from file "} $input {"}
	set chan [open $input r]
    }

    pluginmgr::report info $msg

    if {!$timed && !$progress} {
	# Regular run
	set data [pluginmgr::read \
		[list read $chan] [list eof $chan]]

    } elseif {$timed && $progress} {
	# Timed, with feedback
	if {[pluginmgr::rtimeable]} {
	    pluginmgr::rtime
	    set data [pluginmgr::read \
		    [list ::page::ReadPT $chan] [list eof $chan] \
		    ::page::ReadComplete]
	    set usec [pluginmgr::rgettime]
	} else {
	    set usec [lindex [time {
		set data [pluginmgr::read \
			[list ::page::ReadPT $chan] [list eof $chan] \
			::page::ReadComplete]
	    }] 0] ; # {}
	}
    } elseif {$timed} {
	# Timed only
	if {[pluginmgr::rtimeable]} {
	    pluginmgr::rtime
	    set data [pluginmgr::read \
		    [list ::page::ReadT $chan] [list eof $chan]]
	    set usec [pluginmgr::rgettime]
	} else {
	    set usec [lindex [time {
		set data [pluginmgr::read \
			[list ::page::ReadT $chan] [list eof $chan]]
	    }] 0] ; # {}
	}
    } else {
	# Feedback only ...
	set data [pluginmgr::read \
		[list ::page::ReadPT $chan] [list eof $chan] \
		::page::ReadComplete]
    }

    if {$input ne "-"} {
	close $chan
    }

    if {$timed} {
	Statistics $label "Characters:"    $nread
	Statistics $label "Seconds:"       [expr {double($usec)/1000000}]
	Statistics $label "Char/Seconds:"  [expr {1000000*double($nread)/$usec}]
	Statistics $label "Microseconds:"  $usec
	Statistics $label "Microsec/Char:" [expr {$usec/double($nread)}]
    } elseif {$progress} {
	pluginmgr::report info "  Read $nread [expr {$nread == 1 ? "character" : "characters"}]"
    }
    return $data
}

proc ::page::Transform {data} {
    variable timed
    variable tr

    if {$data eq ""} {return $data}

    if 0 {
	pluginmgr::report info ----------------------------
	foreach tid $tr {
	    set label "\[[pluginmgr::tlabel $tid]\]"
	    pluginmgr::report info $label
	}
	pluginmgr::report info ----------------------------
    }

    #puts /($data)/

    foreach tid $tr {
	set label "\[[pluginmgr::tlabel $tid]\]"

	pluginmgr::report info $label

	if {!$timed} {
	    set data [pluginmgr::transform_do $tid $data]
	} else {
	    if {[pluginmgr::ttimeable $tid]} {
		pluginmgr::ttime $tid
		set data [pluginmgr::transform_do $tid $data]
		set usec [pluginmgr::tgettime $tid]
	    } else {
		set usec [lindex [time {
		    set data [pluginmgr::transform_do $tid $data]
		}] 0]; #{}
	    }
	    Statistics $label Seconds: [expr {double($usec)/1000000}]
	}
    }
    return $data
}

proc ::page::Write {data} {
    variable timed
    variable output

    if {$data eq ""} {return $data}

    set    label \[[pluginmgr::wlabel]\]
    set    msg   ""
    append msg   $label " "

    if {$output eq "-"} {
	append msg {Writing to stdout}
	set chan stdout
    } else {
	append msg {Writing to file "} $output {"}
	set chan [open $output w]
    }

    pluginmgr::report info $msg

    if {!$timed} {
	pluginmgr::write $chan $data
    } else {
	if {[pluginmgr::wtimeable]} {
	    pluginmgr::wtime
	    pluginmgr::write $chan $data
	    set usec [pluginmgr::wgettime]
	} else {
	    set usec [lindex [time {
		pluginmgr::write $chan $data
	    }] 0]; #{}
	}
	Statistics $label Seconds: [expr {double($usec)/1000000}]
    }

    if {$output ne "-"} {
	close $chan
    }
    return
}

proc ::page::StatisticsBegin {} {
    variable timed
    variable statistics
    if {!$timed} return

    set statistics [struct::matrix ::page::STAT]

    Statistics _Statistics_________
    return
}

proc ::page::Statistics {module args} {
    variable statistics
    variable slast

    set n [expr {1+[llength $args]}]

    if {[$statistics columns] < $n} {
	$statistics add columns [expr {
	    $n - [$statistics columns]
	}] ; # {}
    }

    if {$module eq $slast} {
	set prefix ""
    } else {
	set prefix $module
	set slast  $module
    }

    $statistics add row [linsert $args 0 $prefix]
    return
}

proc ::page::StatisticsComplete {} {
    variable timed
    variable statistics
    if {!$timed} return

    pluginmgr::report info ""
    foreach line [split [$statistics \
	    format 2string] \n] {
	pluginmgr::report info $line
    }
    return
}

# ### ### ### ######### ######### #########
## Helper commands.

proc ::page::ReadPT {chan {n {}}} {
    variable nread
    variable ncount
    variable ndelta

    if {$n eq ""} {
	set data [read $chan]
    } else {
	set data [read $chan $n]
    }

    set  n [string length $data]
    incr nread $n

    while {$ncount < $nread} {
	puts -nonewline stderr .
	flush stderr
	incr ncount $ndelta
    }

    return $data
}

proc ::page::ReadComplete {} {
    puts  stderr ""
    flush stderr
    return
}

proc ::page::ReadT {chan {n {}}} {
    variable nread

    if {$n eq ""} {
	set data [read $chan]
    } else {
	set data [read $chan $n]
    }

    set  n [string length $data]
    incr nread $n

    return $data
}

# ### ### ### ######### ######### #########
## Invoking the functionality.

if {[catch {
    ::page::ProcessCmdline
    ::page::StatisticsBegin
    ::page::Write [::page::Transform [::page::Read]]
    ::page::StatisticsComplete
} msg]} {
    puts $::errorInfo
    #::page::ArgError $msg
}

# ### ### ### ######### ######### #########
exit
