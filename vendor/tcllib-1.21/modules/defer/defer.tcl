#! /usr/bin/env tclsh

# Copyright (c) 2017 Roy Keene
# 
# Permission is hereby granted, free of charge, to any person obtaining a 
# copy of this software and associated documentation files (the "Software"), 
# to deal in the Software without restriction, including without limitation 
# the rights to use, copy, modify, merge, publish, distribute, sublicense, 
# and/or sell copies of the Software, and to permit persons to whom the 
# Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in 
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
# DEALINGS IN THE SOFTWARE.

package require Tcl 8.6

namespace eval ::defer {
	namespace export defer

	variable idVar "<defer>\n<trace variable>"
}

proc ::defer::with {args} {
	if {[llength $args] == 1} {
		set varlist [list]
		set code [lindex $args 0]
	} elseif {[llength $args] == 2} {
		set varlist [lindex $args 0]
		set code [lindex $args 1]
	} else {
		return -code error "wrong # args: defer::with ?varlist? script"
	}

	if {[info level] == 1} {
		set global true
	} else {
		set global false
	}

	# We can't reliably handle cleanup from the global scope, don't let people
	# register ineffective handlers for now
	if {$global} {
		return -code error "defer may not be used from the global scope"
	}

	# Generate an ID to un-defer if requested
	set id [clock clicks]
	for {set i 0} {$i < 5} {incr i} {
		append id [expr rand()]
	}

	# If a list of variable names has been supplied, slurp up their values
	# and add the appropriate script to set those variables in the lambda
	## Generate a list of commands to create the variables
	foreach var $varlist {
		if {![uplevel 1 [list info exists $var]]} {
			continue
		}

		if {[uplevel 1 [list array exists $var]]} {
			set val [uplevel 1 [list array get $var]]
			lappend codeSetVars [list unset -nocomplain $var]
			lappend codeSetVars [list array set $var $val]
		} else {
			set val [uplevel 1 [list set $var]]
			lappend codeSetVars [list set $var $val]
		}
	}

	## Format the above commands in the structure of a Tcl command
	if {[info exists codeSetVars]} {
		set codeSetVars [join $codeSetVars "; "]
		set code "${codeSetVars}; ${code}"
	}

	## Unset the "args" variable, which is just an artifact of the lambda
	set code "# ${id}\nunset args; ${code}"

	# Register our interest in a variable to monitor for it to disappear

	uplevel 1 [list trace add variable $::defer::idVar unset [list apply [list args $code]]]

	return $id
}

proc ::defer::defer {args} {
	set code $args
	tailcall ::defer::with $code
}

proc ::defer::autowith {script} {
	tailcall ::defer::with [uplevel 1 {info vars}] $script
}

proc ::defer::cancel {args} {
	set idList $args

	set traces [uplevel 1 [list trace info variable $::defer::idVar]]

	foreach trace $traces {
		set action [lindex $trace 0]
		set code   [lindex $trace 1]

		foreach id $idList {
			if {[string match "*# $id*" $code]} {
				uplevel 1 [list trace remove variable $::defer::idVar $action $code]
			}
		}
	}
}

package provide defer 1
