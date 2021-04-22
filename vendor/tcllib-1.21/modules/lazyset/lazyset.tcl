#! /usr/bin/env tclsh

package require Tcl 8.5

namespace eval ::lazyset {}

proc ::lazyset::variable {args} {
	lassign [lrange $args end-1 end] varName commandPrefix
	set args [lrange $args 0 end-2]

	set appendArgs true
	foreach {arg val} $args {
		switch -exact -- $arg {
			"-array" {
				set isArray [expr {!!$val}]
			}
			"-appendArgs" {
				set appendArgs [expr {!!$val}]
			}
			default {
				error "Valid options -array, -appendArgs: Invalid option \"$arg\""
			}
		}
	}

	set trace [uplevel 1 [list trace info variable $varName]]
	if {$trace ne ""} {
		uplevel 1 [list [list trace remove variable $varName $trace]]
	}

	if {![info exists isArray]} {
		set isArray false
		if {[uplevel 1 [list ::array exists $varName]]} {
			set isArray true
		}
	}

	set finalCode ""
	if {$isArray} {
		append finalCode {
			set varname "$name1\($name2\)"
			if {[uplevel 1 [list info exists $varname]]} {
				return
			}
		}
	} else {
		append finalCode {
			set varname $name1
		}
	}

	if {$appendArgs} {
		append finalCode {
			set args [lrange $args 1 end]
		}
		if {$isArray} {
			append finalCode {
				append code " " [list $name1 $name2 {*}$args]
			}
		} else {
			append finalCode {
				append code " " [list $name1 {*}$args]
			}
		}
	}

	append finalCode {
		set result [uplevel 1 $code]

		uplevel 1 [list unset -nocomplain $varname]
		uplevel 1 [list set $varname $result]
	}

	set code [list apply [list {code name1 name2 args} $finalCode] $commandPrefix]

	if {$isArray} {
		uplevel 1 [list unset -nocomplain $varName]
		uplevel 1 [list ::array set $varName [list]]
	} else {
		uplevel 1 [list set $varName ""]
	}

	uplevel 1 [list trace add variable $varName read $code]

	return
}

package provide lazyset 1
