# -*- tcl -*-
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Parser Generator / Frontend - Read halfbaked PEG container.

# ### ### ### ######### ######### #########
## Requisites

namespace eval ::page::parse::peghb {
    variable fixup {}
    variable definitions
}

# ### ### ### ######### ######### #########
## API

proc ::page::parse::peghb {halfbaked t} {
    variable peghb::fixup
    variable peghb::definitions
    array set definitions {}

    set fixup {}

    interp create -safe sb
    # Should remove everything.
    interp alias  sb Start  {} ::page::parse::peghb::Start  $t
    interp alias  sb Define {} ::page::parse::peghb::Define $t
    interp eval   sb $halfbaked
    interp delete sb

    array set undefined {}
    array set users     {}
    foreach {n sym} $fixup {
	if {[info exists definitions($sym)]} {
	    set def $definitions($sym)
	    $t set $n def $def
	    lappend users($def) $n
	} else {
	    lappend undefined($sym) $n
	}
    }

    foreach def [array names users] {
	$t set $def users $users($def)
    }

    $t set root definitions [array get definitions]
    $t set root undefined   [array get undefined]
    $t set root symbol <StartExpression>
    $t set root name   <HalfBaked>

    return
}

# ### ### ### ######### ######### #########
## Internal. Helpers

proc ::page::parse::peghb::Start {t pe} {
    variable fixup
    $t set root start [treeOf $t root $pe fixup]
    return
}

proc ::page::parse::peghb::Define {t mode sym pe} {
    variable fixup
    variable definitions

    set def [$t insert root end]

    $t set $def users  {}
    $t set $def symbol $sym
    $t set $def label  $sym
    $t set $def mode   $mode

    treeOf $t $def $pe fixup

    set definitions($sym) $def
    return
}

proc ::page::parse::peghb::treeOf {t root pe fv} {
    upvar 1 $fv fixup

    set n  [$t insert $root end]
    set op [lindex $pe 0]
    $t set $n op $op

    if {$op eq "t"} {
	$t set $n char [lindex $pe 1]

    } elseif {$op eq ".."} {
	$t set $n begin [lindex $pe 1]
	$t set $n end   [lindex $pe 2]

    } elseif {$op eq "n"} {

	set sym [lindex $pe 1]
	$t set $n sym $sym
	$t set $n def ""

	lappend fixup $n $sym
    } else {
	foreach sub [lrange $pe 1 end] {
	    treeOf $t $n $sub fixup
	}
    }
    return $n
}

# ### ### ### ######### ######### #########
## Internal. Strings.

namespace eval ::page::parse::peghb {}

# ### ### ### ######### ######### #########
## Ready

package provide page::parse::peghb 0.1
