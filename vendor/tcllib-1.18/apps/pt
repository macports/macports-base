#!/usr/bin/env tclsh
# -*- tcl -*-

package require Tcl 8.5
# activate commands below for execution from within the pt directory
set self    [file normalize [info script]]
set selfdir [file dirname $self]
lappend auto_path $selfdir [file dirname $selfdir]
# When debugging package loading trouble, show the search paths
#puts [join $auto_path \n]

# # ## ### ##### ######## ############# #####################

package require pt::pgen 1.0.3
package require pt::util
package require fileutil
package require try

namespace eval ::pt::app {
    namespace export generate help
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################

proc main {} {
    global argv argv0 errorInfo
    if {![llength $argv]} { lappend argv help }
    if {[catch {
	set status [::pt::app {*}$argv]
    } msg]} {
	set elines [split $errorInfo \n]
	if {[llength $elines] == 3} {
	    if {[string match *unknown* $msg]} {
		#puts stderr "$argv0 $msg"
		::pt::app help
		exit 1
	    } elseif {[string match {*wrong # args*} $msg]} {
		#puts $msg
		# Extracting the command name from the error message,
		# because there a prefix will have been expanded to
		# the actual command.  <lindex argv 0> OTOH would be a
		# possible prefix, without a properly matching topic.
		puts stderr Usage:
		::pt::app help [lindex $msg 5 1]
		exit 1
	    }
	}
	set prefix {INTERNAL ERROR :: }
	puts ${prefix}[join $elines \n$prefix]
	exit 1
    }
    exit $status
}

# # ## ### ##### ######## ############# #####################

proc ::pt::app::helpHelp {} {
    return {
	@ help ?TOPIC?

	Provides general help, or specific to the given topic.
    }
}
proc ::pt::app::help {{topic {}}} {
    global argv0
    if {[llength [info level 0]] == 1} {
	puts stderr "Usage: $argv0 command ...\n\nKnown commands:\n"
	foreach topic [Topics] {
	    ::pt::app help $topic
	}
    } elseif {$topic ni [Topics]} {
	puts stderr "$argv0: Unknown help topic '$topic'"
	puts stderr "\tUse one of [linsert [join [Topics] {, }] end-1 or]"
	puts stderr ""
    } else {
	puts stderr \t[join [split [string map [list @ $argv0] [string trim [::pt::app::${topic}Help]]] \n] \n\t]
	puts stderr ""
    }
    return 0
}

proc ::pt::app::Topics {} {
    namespace eval ::TEMP { namespace import ::pt::app::* }
    set commands [info commands ::TEMP::*]
    namespace delete ::TEMP

    set res {}
    foreach c $commands {
	lappend res [regsub ^::TEMP:: $c {}]
    }
    proc ::pt::app::Topics {} [list return $res]
    return $res
}

# # ## ### ##### ######## ############# #####################

proc ::pt::app::generateHelp {} {
    return {
	@ generate PFORMAT ?-option value...? PFILE INFORMAT GFILE

	Generate data in format PFORMAT and write it to PFILE.  Read
	the grammar to be processed from GFILE (assuming the format
	GFORMAT). Use any options to configure the generator. The are
	dependent on PFORMAT.
    }
}
proc ::pt::app::generate {args} {
    # args = parserformat ?...? parserfile grammarformat grammarfile 

    if {[llength $args] < 4} {
	# Just enough that the help code can extract the method name
	return -code error "wrong # args, should be \"@ generate ...\""
    }

    set args [lassign $args parserformat]
    lassign [lrange $args end-2 end] \
	parserfile grammarformat grammarfile
    set args [Template [lrange $args 0 end-3]]
    lappend args -file $grammarfile

    puts "Reading $grammarformat $grammarfile ..."
    set grammar [fileutil::cat $grammarfile]

    puts "Generating a $parserformat parser ..."
    try {
	set parser [::pt::pgen $grammarformat $grammar $parserformat {*}$args]
    } trap {PT RDE SYNTAX} {e o} {
	puts [pt::util error2readable $e $grammar]
	return 1
    }

    puts "Saving to  $parserfile ..."
    fileutil::writeFile $parserfile $parser

    puts OK
    return 0
}

# Lift template specifications from file paths to the file's contents.

proc ::pt::app::Template {optiondict} {
    set res {}
    foreach {option value} $optiondict {
	if {$option eq "-template"} {
	    set value [fileutil::cat $value]
	}
	lappend res $option $value
    }
    return $res
}

# # ## ### ##### ######## ############# #####################

main
exit
