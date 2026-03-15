# -*- tcl -*-
# STUBS handling -- Code generation: Writing the stub macros.
#
# (c) 2011,2022-2023 Andreas Kupries http://wiki.tcl.tk/andreas%20kupries

# A stubs table is represented by a dictionary value.
# A gen is a variable holding a stubs table value.

# # ## ### ##### ######## #############
## Requisites

package require Tcl 8.6 9
package require stubs::gen
package require stubs::container

namespace eval ::stubs::gen::macro::g {
    namespace import ::stubs::gen::*
}

namespace eval ::stubs::gen::macro::c {
    namespace import ::stubs::container::*
}

# # ## ### ##### ######## #############
## Implementation.

proc ::stubs::gen::macro::multiline {{flag 1}} {
    variable multiline $flag
    return $flag
}

proc ::stubs::gen::macro::gen {table name} {
    set upName [string toupper [string map {:: _} [c::library? $table]]]
    set sguard "defined(USE_${upName}_STUBS)"

    append text "\n#if $sguard\n"
    append text "\n/*\n * Inline function declarations:\n */\n\n"
    append text [g::forall $table $name [namespace current]::Make 0]
    append text "\n#endif /* $sguard */\n"
    return $text
}

# # ## ### #####
## Internal helpers.

proc ::stubs::gen::macro::Make {name decl index} {
    variable multiline
    #puts "MACRO($name $index) = |$decl|"

    lassign $decl rtype fname args

    set capName [g::uncap $fname]

    append text "#define $fname "
    if {$multiline} { append text "\\\n\t" }
    append text "("
    if {![llength $args]} { append text "*" }
    append text "${name}StubsPtr->$capName)"
    append text " /* $index */\n"
    return $text
}

# # ## ### #####
namespace eval ::stubs::gen::macro {
    #checker exclude warnShadowVar
    variable multiline 1

    namespace export gen multiline
}

# # ## ### ##### ######## #############
package provide stubs::gen::macro 1.1.1
return
