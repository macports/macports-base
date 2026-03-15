# -*- tcl -*-
# STUBS handling -- Code generation: Writing the stub headers.
#
# (c) 2011,2022-2023 Andreas Kupries http://wiki.tcl.tk/andreas%20kupries

# A stubs table is represented by a dictionary value.
# A gen is a variable holding a stubs table value.

# # ## ### ##### ######## #############
## Requisites

package require Tcl 8.6 9
package require stubs::gen
package require stubs::container
package require stubs::gen::slot
package require stubs::gen::macro
package require stubs::gen::decl

namespace eval ::stubs::gen::header::g {
    namespace import ::stubs::gen::*
}
namespace eval ::stubs::gen::header::c {
    namespace import ::stubs::container::*
}
namespace eval ::stubs::gen::header::s {
    namespace import ::stubs::gen::slot::*
}
namespace eval ::stubs::gen::header::m {
    namespace import ::stubs::gen::macro::*
}
namespace eval ::stubs::gen::header::d {
    namespace import ::stubs::gen::decl::*
}

# # ## ### ##### ######## #############
## Implementation.

proc ::stubs::gen::header::multiline {{flag 1}} {
    return [m::multiline $flag]
}

proc ::stubs::gen::header::gen {table name} {
    set capName [g::cap $name]

    set epoch [c::epoch? $table]
    if {$epoch ne ""} {
	set CAPName [string toupper $name]
	append text "\n"
	append text "#define ${CAPName}_STUBS_EPOCH $epoch\n"
	append text "#define ${CAPName}_STUBS_REVISION [c::revision? $table]\n"
    }

    # declarations...
    append text [d::gen $table $name]

    if {[c::hooks? $table $name]} {
	append text "\ntypedef struct ${capName}StubHooks {\n"
	foreach hook [c::hooksof $table $name] {
	    set capHook [g::cap $hook]
	    append text "    const struct ${capHook}Stubs *${hook}Stubs;\n"
	}
	append text "} ${capName}StubHooks;\n"
    }

    # stub table type definition, including field definitions aka slots...
    append text "\ntypedef struct ${capName}Stubs {\n"
    append text "    int magic;\n"
    if {$epoch ne ""} {
	append text "    int epoch;\n"
	append text "    int revision;\n"
    }
    append text "    const struct ${capName}StubHooks *hooks;\n\n"
    append text [s::gen $table $name]
    append text "} ${capName}Stubs;\n"

    # stub table global variable
    append text "\n#ifdef __cplusplus\nextern \"C\" {\n#endif\n"
    append text "extern const ${capName}Stubs *${name}StubsPtr;\n"
    append text "#ifdef __cplusplus\n}\n#endif\n"

    # last, the series of macros for stub users which will route
    # function calls through the table.
    append text [m::gen $table $name]

    return $text
}

proc ::stubs::gen::header::rewrite@ {basedir table name} {
    rewrite [path $basedir $name] $table $name
}

proc ::stubs::gen::header::rewrite {path table name} {
    g::rewrite $path [gen $table $name]
}

proc ::stubs::gen::header::path {basedir name} {
    return [file join $basedir ${name}Decls.h]
}

# # ## ### #####
## Internal helpers.

# # ## ### #####
namespace eval ::stubs::gen::header {
    namespace export gen multiline rewrite@ rewrite path
}

# # ## ### ##### ######## #############
package provide stubs::gen::header 1.1.1
return
