# -*- tcl -*-
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Parser Generator / Backend - PEG in half baked form for PEG container.

# ### ### ### ######### ######### #########
## Requisites

package require page::util::peg

namespace eval ::page::gen::peg::hb {
    # Get various utilities.

    namespace import ::page::util::peg::*
}

# ### ### ### ######### ######### #########
## API

proc ::page::gen::peg::hb {t chan} {
    hb::printWarnings [hb::getWarnings $t]

    set gstart [$t get root start]
    if {$gstart ne ""} {
	set gstart [hb::peOf $t $gstart]
    } else {
	puts stderr "No start expression."
    }

    hb::Start $chan $gstart

    set temp {}
    set max -1
    foreach {sym def} [$t get root definitions] {
	set eroot [lindex [$t children $def] 0]
	set l [string length [list $sym]]
	if {$l > $max} {set max $l}
	lappend temp \
	    [list $sym [$t get $def mode] [hb::peOf $t $eroot] $l]
    }

    foreach e [lsort -dict -index 0 $temp] {
	foreach {sym mode rule l} $e break
	hb::Rule $chan $sym $mode $rule [expr {$max - $l}]
    }
    return
}

# ### ### ### ######### ######### #########
## Internal. Helpers

proc ::page::gen::peg::hb::Start {chan pe} {
    puts $chan "Start  [printTclExpr $pe]\n"
    return
}

proc ::page::gen::peg::hb::Rule {chan sym mode pe off} {
    variable ms
    set off [string repeat " " $off]
    puts $chan "Define $ms($mode) $sym$off [printTclExpr $pe]"
    return
}

# ### ### ### ######### ######### #########
## Internal. Strings.

namespace eval ::page::gen::peg::hb {
    variable ms ; array set ms {
	value   {value  }
	discard {discard}
	match   {match  }
	leaf    {leaf   }
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide page::gen::peg::hb 0.1
