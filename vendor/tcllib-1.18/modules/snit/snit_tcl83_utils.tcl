#--------------------------------------------------------------------------
# TITLE:
#	snit_tcl83_utils.tcl
#
# AUTHOR:
#	Kenneth Green, 28 Aug 2004
#
# DESCRIPTION:
#       Utilities to support the back-port of snit from Tcl 8.4 to 8.3
#
#--------------------------------------------------------------------------
# Copyright
#
# Copyright (c) 2005 Kenneth Green
# Modified by Andreas Kupries.
# All rights reserved. This code is licensed as described in license.txt.
#--------------------------------------------------------------------------
# This code is freely distributable, but is provided as-is with
# no warranty expressed or implied.
#--------------------------------------------------------------------------
# Acknowledgements
#   The changes described in this file are made to the awesome 'snit'
#   library as provided by William H. Duquette under the terms
#   defined in the associated 'license.txt'.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Namespace

namespace eval ::snit83 {}

#-----------------------------------------------------------------------
# Some Snit83 variables

namespace eval ::snit83 {
    variable  cmdTraceTable
    array set cmdTraceTable {}

    namespace eval private {}
}


#-----------------------------------------------------------------------
# Initialisation

#
# Override Tcl functions so we can mimic some behaviours. This is
# conditional on not having been done already. Otherwise loading snit
# twice will fail the second time.
#

if [info exists tk_version] {
    if {
	![llength [info procs destroy]] ||
	![regexp snit83 [info body destroy]]
    } {
	rename destroy __destroy__
    }
}
if {
    ![llength [info procs namespace]] ||
    ![regexp snit83 [info body namespace]]
} {
    rename namespace __namespace__
    rename rename    __rename__ ;# must be last one renamed!
}

#-----------------------------------------------------------------------
# Global namespace functions


# destroy -
#
# Perform delete tracing and then invoke the actual Tk destroy command

if [info exists tk_version] {
    proc destroy { w } {
	variable ::snit83::cmdTraceTable

	set index "delete,$w"
	if [info exists cmdTraceTable($index)] {
	    set cmd $cmdTraceTable($index)
	    ::unset cmdTraceTable($index) ;# prevent recursive tracing
	    if [catch {eval $cmd $oldName \"$newName\" delete} err] { ; # "
		error $err
	    }
	}

	return [__destroy__ $w]
    }
}

# namespace -
#
# Add limited support for 'namespace exists'. Must be a fully
# qualified namespace name (pattern match support not provided).

proc namespace { cmd args } {
    if {[string equal $cmd "exists"]} {
        set ptn [lindex $args 0]
        return [::snit83::private::NamespaceIsDescendantOf :: $ptn]
    } elseif {[string equal $cmd "delete"]} {
        if [namespace exists [lindex $args 0]] {
            return [uplevel 1 [subst {__namespace__ $cmd $args}]]
        }
    } else {
        return [uplevel 1 [subst {__namespace__ $cmd $args}]]
    }
}

# rename -
#
# Perform rename tracing and then invoke the actual Tcl rename command

proc rename { oldName newName } {
    variable ::snit83::cmdTraceTable

    # Get caller's namespace since rename must be performed
    # in the context of the caller's namespace
    set callerNs "::"
    set callerLevel [expr {[info level] - 1}]
    if { $callerLevel > 0 } {
        set callerInfo [info level $callerLevel]
        set procName   [lindex $callerInfo 0]
        set callerNs   [namespace qualifiers $procName]
    }

    #puts "rename: callerNs: $callerNs"
    #puts "rename: '$oldName' -> '$newName'"
    #puts "rename: rcds - [join [array names cmdTraceTable] "\nrename: rcds - "]"

    set result [namespace eval $callerNs [concat __rename__ [list $oldName $newName]]]

    set index1 "rename,$oldName"
    set index2 "rename,::$oldName"

    foreach index [list $index1 $index2] {
        if [info exists cmdTraceTable($index)] {
            set cmd $cmdTraceTable($index)

	    #puts "rename: '$cmd' { $oldName -> $newName }"

            ::unset cmdTraceTable($index) ;# prevent recursive tracing
            if {![string equal $newName ""]} {
                # Create a new trace record under the new name
                set cmdTraceTable(rename,$newName) $cmd
            }
            if [catch {eval $cmd $oldName \"$newName\" rename} err] {
                error $err
            }
            break
        }
    }

    return $result
}


#-----------------------------------------------------------------------
# Private functions

proc ::snit83::private::NamespaceIsDescendantOf { parent child } {
    set result 0

    foreach ns [__namespace__ children $parent] {
        if [string match $ns $child] {
            set result 1
            break;
        } else {
            if [set result [NamespaceIsDescendantOf $ns $child]] {
                break
            }
        }
    }
    return $result
}


#-----------------------------------------------------------------------
# Utility functions

proc ::snit83::traceAddCommand {name ops command} {
    variable cmdTraceTable

    #puts "::snit83::traceAddCommand n/$name/ o/$ops/ c/$command/"
    #puts "XX [join [array names cmdTraceTable] "\nXX "]"

    foreach op $ops {
        set index "$op,$name"
	#puts "::snit83::traceAddCommand: index = $index cmd = $command"

        set cmdTraceTable($index) $command
    }
}

proc ::snit83::traceRemoveCommand {name ops command} {
    variable cmdTraceTable

    #puts "::snit83::traceRemoveCommand n/$name/ o/$ops/ c/$command/"
    #puts "YY [join [array names cmdTraceTable] "\nYY "]"

    foreach op $ops {
        set index "$op,$name"
	#puts "::snit83::traceRemoveCommand: index = $index cmd = $command"

	catch { ::unset cmdTraceTable($index) }
    }
}

# Add support for 'unset -nocomplain'
proc ::snit83::unset { args } {

    #puts "::snit83::unset - args: '$args'"

    set noComplain 0
    if {[string equal [lindex $args 0] "-nocomplain"]} {
        set noComplain 1
        set args [lrange $args 1 end]
    }
    if {[string equal [lindex $args 0] "--"]} {
        set args [lrange $args 1 end]
    }

    if [catch {
	uplevel 1 [linsert $args 0 ::unset]
    } err] {
        if { !$noComplain } {
            error $err
        }
    }
}
