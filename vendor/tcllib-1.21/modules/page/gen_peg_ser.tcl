# -*- tcl -*-
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Parser Generator / Backend - PEG as serialized PEG container.

# ### ### ### ######### ######### #########
## Requisites

package require grammar::peg
package require page::util::quote
package require page::util::peg

namespace eval ::page::gen::peg::ser {
    # Get the peg char de/encoder commands.
    # (unquote, quote'tcl), and other utilities.

    namespace import ::page::util::quote::*
    namespace import ::page::util::peg::*
}

# ### ### ### ######### ######### #########
## API

proc ::page::gen::peg::ser {t chan} {
    ser::printWarnings [ser::getWarnings $t]

    ::grammar::peg gr

    set gstart [$t get root start]
    if {$gstart ne ""} {
	gr start [ser::peOf $t $gstart]
    } else {
	page_info "No start expression."
    }

    foreach {sym def} [$t get root definitions] {
	set eroot [lindex [$t children $def] 0]

	gr nonterminal add  $sym [ser::peOf $t $eroot]
	gr nonterminal mode $sym [$t get $def mode]
    }

    puts $chan [gr serialize]
    gr destroy
    return
}

# ### ### ### ######### ######### #########
## Internal. Helpers

proc ::page::gen::peg::ser::GetRules {t} {
    return $res
}

# ### ### ### ######### ######### #########
## Internal. Strings.

namespace eval ::page::gen::peg::ser {}

# ### ### ### ######### ######### #########
## Ready

package provide page::gen::peg::ser 0.1
