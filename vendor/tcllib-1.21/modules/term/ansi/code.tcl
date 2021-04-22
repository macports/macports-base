# -*- tcl -*-
# ### ### ### ######### ######### #########
## Terminal packages - ANSI
## Generic commands to define commands for code sequences.

# ### ### ### ######### ######### #########
## Requirements

namespace eval ::term::ansi::code {}

# ### ### ### ######### ######### #########
## API. Escape clauses, plain and bracket
##      Used by 'define'd commands.

proc ::term::ansi::code::esc  {str} {return \033$str}
proc ::term::ansi::code::escb {str} {esc    \[$str}

# ### ### ### ######### ######### #########
## API. Define command for named control code, or constant.
##      (Simple definitions without arguments)

proc ::term::ansi::code::define {name escape code} {
    proc [Qualified $name] {} [list ::term::ansi::code::$escape $code]
}

proc ::term::ansi::code::const {name code} {
    proc [Qualified $name] {} [list return $code]
}

# ### ### ### ######### ######### #########
## Internal helper to construct fully-qualified names.

proc ::term::ansi::code::Qualified {name} {
    if {![string match ::* $name]} {
        # Get the caller's namespace; append :: if it is not the
	# global namespace, for separation from the actual name.
        set ns [uplevel 2 [list namespace current]]
        if {$ns ne "::"} {append ns ::}
        set name $ns$name
    }
    return $name
}

# ### ### ### ######### ######### #########

namespace eval ::term::ansi::code {
    namespace export esc escb define const
}

# ### ### ### ######### ######### #########
## Ready

package provide term::ansi::code 0.2

##
# ### ### ### ######### ######### #########
