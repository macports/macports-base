# cfront.tcl --
#
#	Generator frontend for compiler of magic(5) files into recognizers
#	based on the 'rtcore'. Parses magic(5) into a basic 'script'.
#
# Copyright (c) 2004-2005 Colin McCormack <coldstore@users.sourceforge.net>
# Copyright (c) 2005      Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: cfront.tcl,v 1.7 2008/03/22 01:10:32 andreas_kupries Exp $

#####
#
# "mime type recognition in pure tcl"
# http://wiki.tcl.tk/12526
#
# Tcl code harvested on:  10 Feb 2005, 04:06 GMT
# Wiki page last updated: ???
#
#####

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.4

# file to compile the magic file from magic(5) into a tcl program
package require fileutil              ; # File processing (input)
package require fileutil::magic::cgen ; # Code generator.
package require fileutil::magic::rt   ; # Runtime (typemap)
package require struct::list          ; # lrepeat.

package provide fileutil::magic::cfront 1.0

# ### ### ### ######### ######### #########
## Implementation

namespace eval ::fileutil::magic::cfront {
    # Configuration flag. (De)activate debugging output.
    # This is done during initialization.
    # Changes at runtime have no effect.

    variable debug 0

    # Constants

    variable hashprotection  [list "\#" "\\#" \" \\\" \{ \\\{ \} \\\}]      ;#"
    variable hashprotectionB [list "\#" "\\\#" \" \\\" \} \\\} ( \\( ) \\)] ;#"

    # Make backend functionality accessible
    namespace import ::fileutil::magic::cgen::*

    namespace export compile procdef install
}

# parse an individual line
proc ::fileutil::magic::cfront::parseline {line {maxlevel 10000}} {
    # calculate the line's level
    set unlevel [string trimleft $line >]
    set level   [expr {[string length $line] - [string length $unlevel]}]
    if {$level > $maxlevel} {
   	return -code continue "Skip - too high a level"
    }

    # regexp parse line into (offset, type, value, command)
    set parse [regexp -expanded -inline {^(\S+)\s+(\S+)\s*((\S|(\B\s))*)\s*(.*)$} $unlevel]
    if {$parse == {}} {
   	error "Can't parse: '$unlevel'"
    }

    # unpack parsed line
    set value   ""
    set command ""
    foreach {junk offset type value junk1 junk2 command} $parse break

    # handle trailing spaces
    if {[string index $value end] eq "\\"} {
   	append value " "
    }
    if {[string index $command end] eq "\\"} {
   	append command " "
    }

    if {$value eq ""} {
	# badly formatted line
   	return -code error "no value"
    }

    ::fileutil::magic::cfront::Debug {
   	puts "level:$level offset:$offset type:$type value:'$value' command:'$command'"
    }

    # return the line's fields
    return [list $level $offset $type $value $command]
}

# process a magic file
proc ::fileutil::magic::cfront::process {file {maxlevel 10000}} {
    variable hashprotection
    variable hashprotectionB
    variable level	;# level of line
    variable linenum	;# line number

    set level  0
    set script {}

    set linenum 0
    ::fileutil::foreachLine line $file {
   	incr linenum
   	set line [string trim $line " "]
   	if {[string index $line 0] eq "#"} {
   	    continue	;# skip comments
   	} elseif {$line == ""} {
   	    continue	;# skip blank lines
   	} else {
   	    # parse line
   	    if {[catch {parseline $line $maxlevel} parsed]} {
   		continue	;# skip erroring lines
   	    }

   	    # got a valid line
   	    foreach {level offset type value message} $parsed break

   	    # strip comparator out of value field,
   	    # (they are combined)
   	    set compare [string index $value 0]
   	    switch -glob --  $value {
   		[<>]=* {
   		    set compare [string range $value 0 1]
   		    set value   [string range $value 2 end]
   		}

   		<* - >* - &* - ^* {
   		    set value [string range $value 1 end]
   		}

   		=* {
   		    set compare "=="
   		    set value   [string range $value 1 end]
   		}

   		!* {
   		    set compare "!="
   		    set value   [string range $value 1 end]
   		}

   		x {
   		    # this is the 'don't care' match
   		    # used for collecting values
   		    set value ""
   		}

   		default {
   		    # the default comparator is equals
   		    set compare "=="
   		    if {[string match {\\[<!>=]*} $value]} {
   			set value [string range $value 1 end]
   		    }
   		}
   	    }

   	    # process type field
   	    set qual ""
   	    switch -glob -- $type {
   		pstring* - string* {
   		    # String or Pascal string type

   		    # extract string match qualifiers
		    foreach {type qual} [split $type /] break

   		    # convert pstring to string + qualifier
   		    if {$type eq "pstring"} {
   			append qual "p"
   			set type "string"
   		    }

   		    # protect hashes in output script value
   		    set value [string map $hashprotection $value]

   		    if {($value eq "\\0") && ($compare eq ">")} {
   			# record 'any string' match
   			set value   ""
   			set compare x
   		    } elseif {$compare eq "!="} {
   			# string doesn't allow !match
   			set value   !$value
   			set compare "=="
   		    }

   		    if {$type ne "string"} {
   			# don't let any odd string types sneak in
   			puts stderr "Reject String: ${file}:$linenum $type - $line"
   			continue
   		    }
   		}

   		regex {
   		    # I am *not* going to handle regex
   		    puts stderr "Reject Regex: ${file}:$linenum $type - $line"
   		    continue
   		}

   		*byte* - *short* - *long* - *date* {
   		    # Numeric types

   		    # extract numeric match &qualifiers
   		    set type [split  $type &]
   		    set qual [lindex $type 1]

   		    if {$qual ne ""} {
   			# this is an &-qualifier
   			set qual &$qual
   		    } else {
   			# extract -qualifier from type
   			set type [split  $type -]
   			set qual [lindex $type 1]
   			if {$qual ne ""} {
   			    set qual -$qual
   			}
   		    }
   		    set type [lindex $type 0]

   		    # perform value adjustments
   		    if {$compare ne "x"} {
   			# trim redundant Long value qualifier
   			set value [string trimright $value L]

   			if {[catch {set value [expr $value]} x]} {
			    upvar #0 errorInfo eo
   			    # check that value is representable in tcl
   			    puts stderr "Reject Value Error: ${file}:$linenum '$value' '$line' - $eo"
   			    continue;
   			}

   			# coerce numeric value into hex
   			set value [format "0x%x" $value]
   		    }
   		}

   		default {
   		    # this is not a type we can handle
   		    puts stderr "Reject Unknown Type: ${file}:$linenum $type - $line"
   		    continue
   		}
   	    }
   	}

   	# collect some summaries
   	::fileutil::magic::cfront::Debug {
   	    variable types
   	    set types($type) $type
   	    variable quals
   	    set quals($qual) $qual
   	}

   	#puts $linenum level:$level offset:$offset type:$type
	#puts qual:$qual compare:$compare value:'$value' message:'$message'

   	# protect hashes in output script message
   	set message [string map $hashprotectionB $message]

   	if {![string match "(*)" $offset]} {
   	    catch {set offset [expr $offset]}
   	}

   	# record is the complete match command,
   	# encoded for tcl code generation
   	set record [list $linenum $type $qual $compare $offset $value $message]
   	if {$script == {}} {
   	    # the original script has level 0,
   	    # regardless of what the script says
   	    set level 0
   	}

   	if {$level == 0} {
   	    # add a new 0-level record
   	    lappend script $record
   	} else {
   	    # find the growing edge of the script
   	    set depth [::struct::list repeat [expr $level] end]
   	    while {[catch {
   		# get the insertion point
   		set insertion [eval [linsert $depth 0 lindex $script]]
		# 8.5 #	set insertion [lindex $script {*}$depth]
   	    }]} {
   		# handle scripts which jump levels,
   		# reduce depth to current-depth+1
   		set depth [lreplace $depth end end]
   	    }

   	    # add the record at the insertion point
   	    lappend insertion $record

   	    # re-insert the record into its correct position
   	    eval [linsert [linsert $depth 0 lset script] end $insertion]
   	    # 8.5 # lset script {*}$depth $insertion
   	}
    }
    #puts "Script: $script"
    return $script
}

# compile up magic files or directories of magic files into a single recognizer.
proc ::fileutil::magic::cfront::compile {args} {
    set tcl ""
    set script {}
    foreach arg $args {
   	if {[file type $arg] == "directory"} {
   	    foreach file [glob [file join $arg *]] {
   		set script1 [process $file]
		eval [linsert $script1 0 lappend script [list file $file]]
   		# 8.5 # lappend script [list file $file] {*}$script1

   		#append tcl "magic::file_start $file" \n
   		#append tcl [run $script1] \n
   	    }
   	} else {
   	    set file $arg
   	    set script1 [process $file]
   	     eval [linsert $script1 0 lappend script [list file $file]]
   	    # 8.5 # lappend script [list file $file] {*}$script1

   	    #append tcl "magic::file_start $file" \n
   	    #append tcl [run $script1] \n
   	}
    }

    #puts stderr $script
    ::fileutil::magic::cfront::Debug {puts "\# $args"}

    set    t   [2tree $script]
    set    tcl [treegen $t root]
    append tcl "\nreturn \{\}"

    ::fileutil::magic::cfront::Debug {puts [treedump $t]}
    #set tcl [run $script]

    return $tcl
}

proc ::fileutil::magic::cfront::procdef {procname args} {

    set pspace [namespace qualifiers $procname]

    if {$pspace eq ""} {
	return -code error "Cannot generate recognizer in the global namespace"
    }

    set     script {}
    lappend script "package require fileutil::magic::rt"
    lappend script "namespace eval [list ${pspace}] \{"
    lappend script "    namespace import ::fileutil::magic::rt::*"
    lappend script "\}"
    lappend script ""
    lappend script [list proc ${procname} {} \n[eval [linsert $args 0 compile]]\n]
    return [join $script \n]
}

proc ::fileutil::magic::cfront::install {args} {
    foreach arg $args {
	set path [file tail $arg]
	eval [procdef ::fileutil::magic::/${path}::run $arg]
    }
    return
}

# ### ### ### ######### ######### #########
## Internal, debugging.

if {!$::fileutil::magic::cfront::debug} {
    # This procedure definition is optimized out of using code by the
    # core bcc. It knows that neither argument checks are required,
    # nor is anything done. So neither results, nor errors are
    # possible, a true no-operation.
    proc ::fileutil::magic::cfront::Debug {args} {}

} else {
    proc ::fileutil::magic::cfront::Debug {script} {
	# Run the commands in the debug script. This usually generates
	# some output. The uplevel is required to ensure the proper
	# resolution of all variables found in the script.
	uplevel 1 $script
	return
    }
}

#set script [magic::compile {} /usr/share/misc/file/magic]
#puts "\# types:[array names magic::types]"
#puts "\# quals:[array names magic::quals]"
#puts "Script: $script"

# ### ### ### ######### ######### #########
## Ready for use.
# EOF
