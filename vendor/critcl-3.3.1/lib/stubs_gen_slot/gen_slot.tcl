# -*- tcl -*-
# STUBS handling -- Code generation: Writing SLOT code.
#
# (c) 2011,2022-2023 Andreas Kupries http://wiki.tcl.tk/andreas%20kupries

# # ## ### ##### ######## #############
## Requisites

package require Tcl 8.6 9
package require stubs::gen

namespace eval ::stubs::gen::slot::g {
    namespace import ::stubs::gen::*
}

# # ## ### ##### ######## #############
## Implementation.

proc ::stubs::gen::slot::gen {table name} {
    return [g::forall $table $name [namespace current]::Make 1 \
		"    void (*reserved@@)(void);\n"]
}

# # ## ### #####
## Internal helpers.

proc ::stubs::gen::slot::Make {name decl index} {
    #puts "SLOT($name $index) = |$decl|"

    lassign $decl rtype fname args

    set capName [g::uncap $fname]

    set text "    "
    if {![llength $args]} {
	append text $rtype " *" $capName "; /* $index */\n"
	return $text
    }

    if {[string range $rtype end-7 end] eq "CALLBACK"} {
	append text \
	    [string trim [string range $rtype 0 end-8]] \
	    " (CALLBACK *" $capName ") "
    } else {
	append text $rtype " (*" $capName ") "
    }

    set arg1 [lindex $args 0]
    switch -exact -- $arg1 {
	void {
	    append text "(void)"
	}
	TCL_VARARGS {
	    append text [MakeArgs [lrange $args 1 end] ", ..."]
	}
	default {
	    append text [MakeArgs $args]
	}
    }

    append text "; /* $index */\n"
    return $text
}

proc ::stubs::gen::slot::MakeArgs {arguments {suffix {}}} {
    set text ""
    set sep "("
    foreach arg $arguments {
	lassign $arg atype aname aind
	append text $sep $atype
	if {[string index $text end] ne "*"} {
	    append text " "
	}
	append text $aname $aind
	set sep ", "
    }
    append text "$suffix)"

    if {[lindex $arguments end] eq "\{const char *\} format"} {
	# TCL_VARARGS case... arguments list already shrunken.
	set n [llength $arguments]
	append text " TCL_FORMAT_PRINTF(" $n ", " [expr {$n + 1}] ")"
    }

    return $text
}

# # ## ### #####
namespace eval ::stubs::gen::slot {
    namespace export gen
}

# # ## ### #####
package provide stubs::gen::slot 1.1.1
return
