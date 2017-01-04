# -*- tcl -*-
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Parser Generator / Backend - PEG as Tcl script.

# ### ### ### ######### ######### #########
## Requisites

package require page::util::peg

namespace eval ::page::gen::peg::cpkg {
    # Get various utilities.

    namespace import ::page::util::peg::*
}

# ### ### ### ######### ######### #########
## API

proc ::page::gen::peg::cpkg {t chan} {
    cpkg::printWarnings [cpkg::getWarnings $t]

    set grname [$t get root name]

    cpkg::Header  $chan $grname

    set gstart [$t get root start]
    if {$gstart ne ""} {
	set gstart [cpkg::peOf $t $gstart]
    } else {
	puts stderr "No start expression."
    }

    cpkg::Start   $chan $gstart

    set temp {}
    set max -1

    foreach {sym def} [$t get root definitions] {
	set eroot [lindex [$t children $def] 0]
	set l [string length [list $sym]]
	if {$l > $max} {set max $l}
	lappend temp \
	    [list $sym [$t get $def mode] [cpkg::peOf $t $eroot] $l]
    }

    foreach e [lsort -dict -index 0 $temp] {
	foreach {sym mode rule l} $e break
	cpkg::Rule $chan $sym $mode $rule [expr {$max - $l}]
    }

    cpkg::Trailer $chan $grname
    return
}

# ### ### ### ######### ######### #########
## Internal. Helpers

proc ::page::gen::peg::cpkg::Header {chan grname} {
    variable header
    variable headerb

    set stem [namespace tail $grname]
    puts $chan [string map \
		    [list \
			 @@ [list $grname] \
			 @stem@ [list $stem] \
			 "\n\t" "\n"
			] \
		    $header\n$headerb]
}

proc ::page::gen::peg::cpkg::Start {chan pe} {
    puts $chan "    Start  [printTclExpr $pe]\n"
    return
}

proc ::page::gen::peg::cpkg::Rule {chan sym mode pe off} {
    variable ms
    set off [string repeat " " $off]
    puts $chan "    Define $ms($mode) $sym$off [printTclExpr $pe]"
    return
}

proc ::page::gen::peg::cpkg::Trailer {chan grname} {
    variable trailer
    variable trailerb
    puts $chan [string map \
		    [list \
			 @@ [list $grname] \
			 "\n\t" "\n"
			] \
		    $trailer\n$trailerb]
}

# ### ### ### ######### ######### #########
## Internal. Strings.

namespace eval ::page::gen::peg::cpkg {
    variable ms ; array set ms {
	value   {value  }
	discard {discard}
	match   {match  }
	leaf    {leaf   }
    }
    variable header {# -*- tcl -*-
	## Parsing Expression Grammar '@@'.

	# ### ### ### ######### ######### #########
	## Package description

	## It provides a single command returning the handle of a
	## grammar container in which the grammar '@@'
	## is stored. The container is usable by a PEG interpreter
	## or other packages taking PE grammars.

	# ### ### ### ######### ######### #########
	## Requisites.
	## - PEG container type

	package require grammar::peg

	namespace eval ::@@ {}

	# ### ### ### ######### ######### #########
	## API

	proc ::@@ {} {
	    return $@stem@::gr
	}

	# ### ### ### ######### ######### #########
	# ### ### ### ######### ######### #########
	## Data and helpers.

	namespace eval ::@@ {
	    # Grammar container
	    variable gr [::grammar::peg gr]
	}

	proc ::@@::Start {pe} {
	    variable gr
	    $gr start $pe
	    return
	}

	proc ::@@::Define {mode sym pe} {
	    variable gr
	    $gr nonterminal add  $sym $pe
	    $gr nonterminal mode $sym $mode
	    return
	}

	# ### ### ### ######### ######### #########
	## Initialization = Grammar definition
    }
    variable headerb	"namespace eval ::@@ \{"

    variable trailer "\}"
    variable trailerb {
	# ### ### ### ######### ######### #########
	## Package Management - Ready

	package provide @@ 0.1
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide page::gen::peg::cpkg 0.1
