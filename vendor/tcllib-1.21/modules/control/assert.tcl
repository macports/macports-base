# assert.tcl --
#
#	The [assert] command of the package "control".
#
# RCS: @(#) $Id: assert.tcl,v 1.3 2004/01/15 06:36:12 andreas_kupries Exp $

namespace eval ::control {

    namespace eval assert {
	namespace export EnabledAssert DisabledAssert
	variable CallbackCmd [list return -code error]

	namespace import [namespace parent]::no-op
	rename no-op DisabledAssert

	proc EnabledAssert {expr args} {
	    variable CallbackCmd

	    set code [catch {uplevel 1 [list expr $expr]} res]
	    if {$code} {
		return -code $code $res
	    }
	    if {![string is boolean -strict $res]} {
		return -code error "invalid boolean expression: $expr"
	    }
	    if {$res} {return}
	    if {[llength $args]} {
		set msg [join $args]
	    } else {
		set msg "assertion failed: $expr"
	    }
	    # Might want to catch this
	    namespace eval :: $CallbackCmd [list $msg]
	}

	proc enabled {args} {
	    set n [llength $args]
	    if {$n > 1} {
		return -code error "wrong # args: should be\
			\"[lindex [info level 0] 0] ?boolean?\""
	    }
	    if {$n} {
		set val [lindex $args 0]
		if {![string is boolean -strict $val]} {
		    return -code error "invalid boolean value: $val"
		}
		if {$val} {
		    [namespace parent]::AssertSwitch Disabled Enabled
		} else {
		    [namespace parent]::AssertSwitch Enabled Disabled
		}
	    } else {
		return [string equal [namespace origin EnabledAssert] \
			[namespace origin [namespace parent]::assert]]
	    }
	    return ""
	}

	proc callback {args} {
	    set n [llength $args]
	    if {$n > 1} {
		return -code error "wrong # args: should be\
			\"[lindex [info level 0] 0] ?command?\""
	    }
	    if {$n} {
	        return [variable CallbackCmd [lindex $args 0]]
	    }
	    variable CallbackCmd
	    return $CallbackCmd
	}

    }

    proc AssertSwitch {old new} {
	if {[string equal [namespace origin assert] \
		[namespace origin assert::${new}Assert]]} {return}
	rename assert ${old}Assert
	rename ${new}Assert assert
    }

    namespace import assert::DisabledAssert assert::EnabledAssert

    # For indexer
    proc assert args #
    rename assert {}

    # Initial default: disabled asserts
    rename DisabledAssert assert

}

