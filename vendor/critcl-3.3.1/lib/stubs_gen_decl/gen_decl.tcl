# -*- tcl -*-
# STUBS handling -- Code generation: Writing declarations.
#
# (c) 2011,2022-2023 Andreas Kupries http://wiki.tcl.tk/andreas%20kupries

# A stubs table is represented by a dictionary value.
# A gen is a variable holding a stubs table value.

# # ## ### ##### ######## #############
## Requisites

package require Tcl 8.6 9
package require stubs::gen
package require stubs::container

namespace eval ::stubs::gen::decl::g {
    namespace import ::stubs::gen::*
}

namespace eval ::stubs::gen::decl::c {
    namespace import ::stubs::container::*
}

# # ## ### ##### ######## #############
## Implementation.

proc ::stubs::gen::decl::gen {table name} {
    set text "\n/*\n * Exported function declarations:\n */\n\n"
    append text [g::forall $table $name [list [namespace current]::Make $table] 0]
    return $text
}

# # ## ### #####
## Internal helpers.

proc ::stubs::gen::decl::Make {table name decl index} {
    #puts "DECL($name $index) = |$decl|"

    lassign $decl rtype fname args

    append text "/* $index */\n"

    set    line  "[c::scspec? $table] $rtype"
    set    count [expr {2 - ([string length $line] / 8)}]
    append line [string range "\t\t\t" 0 $count]

    set pad [expr {24 - [string length $line]}]
    if {$pad <= 0} {
	append line " "
	set pad 0
    }

    if {![llength $args]} {
	append text $line $fname ";\n"
	return $text
    }

    set arg1 [lindex $args 0]
    switch -exact -- $arg1 {
	void {
	    append text $line $fname "(void)"
	}
	TCL_VARARGS {
	    append line $fname
	    append text [MakeArgs $line $pad [lrange $args 1 end] ", ..."]
	}
	default {
	    append line $fname
	    append text [MakeArgs $line $pad $args]
	}
    }
    append text ";\n"
    return $text
}

proc ::stubs::gen::decl::MakeArgs {line pad arguments {suffix {}}} {
    #checker -scope local exclude warnArgWrite
    set text ""
    set sep "("
    foreach arg $arguments {
	append line $sep
	set next {}

	lassign $arg atype aname aind

	append next $atype
	if {[string index $next end] ne "*"} {
	    append next " "
	}
	append next $aname $aind

	if {([string length $line] + [string length $next] + $pad) > 76} {
	    append text [string trimright $line] \n
	    set line "\t\t\t\t"
	    set pad 28
	}
	append line $next
	set sep ", "
    }
    append line "$suffix)"

    if {[lindex $arguments end] eq "{const char *} format"} {
	# TCL_VARARGS case... arguments list already shrunken.
	set n [llength $arguments]
	append line " TCL_FORMAT_PRINTF(" $n ", " [expr {$n + 1}] ")"
    }

    return $text$line
}

# # ## ### #####
namespace eval ::stubs::gen::decl {
    namespace export gen
}

# # ## ### #####
package provide stubs::gen::decl 1.1.1
return
