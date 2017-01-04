# unicode.tcl                                                   -*- tcl -*-
#
#	Implementation of RFC 3454 "Preparation of Internationalized Strings"
#
# Copyright (c) 2007 Sergei Golovan
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: unicode.tcl,v 1.1 2008/01/29 02:18:10 patthoyts Exp $

package require unicode::data 1.0

namespace eval ::unicode {
    # Hangul constants
    set SBase 0xac00
    set LBase 0x1100
    set VBase 0x1161
    set TBase 0x11a7
    set LCount 19
    set VCount 21
    set TCount 28
    set NCount [expr {$VCount * $TCount}]
    set SCount [expr {$LCount * $NCount}]
}

########################################################################
# ::unicode::fromstring converts string to list of integers

proc ::unicode::fromstring {str} {
    set uclist {}
    foreach char [split $str ""] {
	lappend uclist [scan $char %c]
    }
    return $uclist
}

########################################################################
# ::unicode::tostring converts list of integers to string

proc ::unicode::tostring {uclist} {
    set res ""
    foreach num $uclist {
	append res [format %c $num]
    }
    return $res
}

########################################################################
# ::unicode::normalize normalizes list of integers according to
# http://unicode.org/reports/tr15/
# form is to be D, C, KD, or KC

proc ::unicode::normalize {form uclist} {
    switch -- $form {
	D  { return [normalizeD  $uclist] }
	C  { return [normalizeC  $uclist] }
	KD { return [normalizeKD $uclist] }
	KC { return [normalizeKC $uclist] }
	default {
	    return -code error \
		   "::unicode::normalize: Only D, C, KD and KC forms are\
		    allowed"
	}
    }
}

########################################################################
# ::unicode::normalizeS normalizes string according to
# http://unicode.org/reports/tr15/
# form is to be D, C, KD, or KC

proc ::unicode::normalizeS {form str} {
    switch -- $form {
	D  { return [tostring [normalizeD  [fromstring $str]]] }
	C  { return [tostring [normalizeC  [fromstring $str]]] }
	KD { return [tostring [normalizeKD [fromstring $str]]] }
	KC { return [tostring [normalizeKC [fromstring $str]]] }
	default {
	    return -code error \
		   "::unicode::normalizeS: Only D, C, KD and KC forms are\
		    allowed"
	}
    }
}

########################################################################

proc ::unicode::normalizeD {uclist} {
    set res {}
    foreach uc $uclist {
	set res [concat $res [decomposeCanonical $uc]]
    }

    canonicalOrdering $res
}

proc ::unicode::normalizeC {uclist} {
    composeCanonical [normalizeD $uclist]
}

proc ::unicode::normalizeKD {uclist} {
    set res {}
    foreach uc $uclist {
	set res [concat $res [decomposeCompat $uc]]
    }

    canonicalOrdering $res
}

proc ::unicode::normalizeKC {uclist} {
    composeCanonical [normalizeKD $uclist]
}

########################################################################
# Adjacent characters with nonzero character class should go in
# order of increasing character class

proc ::unicode::canonicalOrdering {uclist} {
    set res {}
    set slist {}
    foreach uc $uclist {
	set cclass [data::GetUniCharCClass $uc]
	if {$cclass != 0} {
	    lappend slist [list $uc $cclass]
	} else {
	    foreach s [lsort -integer -index 1 $slist] {
		lappend res [lindex $s 0]
	    }
	    set slist {}
	    lappend res $uc
	}
    }
    foreach s [lsort -integer -index 1 $slist] {
	lappend res [lindex $s 0]
    }

    return $res
}

########################################################################

proc ::unicode::decomposeHangul {uc} {
    variable SBase
    variable LBase
    variable VBase
    variable TBase
    variable LCount
    variable VCount
    variable TCount
    variable NCount
    variable SCount

    # Hangul decomposition is algorithmic
    set SIndex [expr {$uc - $SBase}]
    if {$SIndex >= 0 && $SIndex < $SCount} {
        set res {}
        set L [expr {$LBase + $SIndex / $NCount}]
        set V [expr {$VBase + ($SIndex % $NCount) / $TCount}]
        set T [expr {$TBase + $SIndex % $TCount}]
	set res [list $L $V]
        if {$T != $TBase} {
	    lappend res $T
	}
        return $res
    }
    return -1
}

########################################################################

proc ::unicode::decomposeCanonical {uc} {
    # Try to decompose Hangul first
    set res [decomposeHangul $uc]
    if {$res >= 0} {
	return $res
    }

    # For others do a lookup in data tables
    set info [data::GetUniCharDecompInfo $uc]
    if {$info >= 0} {
	set res {}
	foreach c [data::GetDecompList $info] {
	    set res [concat $res [decomposeCanonical $c]]
	}
	return $res
    } else {
	return [list $uc]
    }
}

########################################################################

proc ::unicode::decomposeCompat {uc} {
    # Try to decompose Hangul first
    set res [decomposeHangul $uc]
    if {$res >= 0} {
	return $res
    }

    # For others do a lookup in data tables
    set info [data::GetUniCharDecompCompatInfo $uc]
    if {$info >= 0} {
	set res {}
	foreach c [data::GetDecompList $info] {
	    set res [concat $res [decomposeCompat $c]]
	}
	return $res
    } else {
	return [list $uc]
    }
}

########################################################################

proc ::unicode::composeTwo {uc1 uc2} {
    variable SBase
    variable LBase
    variable VBase
    variable TBase
    variable LCount
    variable VCount
    variable TCount
    variable NCount
    variable SCount

    # Hangul composition is algorithmic
    if {$uc1 >= $LBase && $uc1 < $LBase + $LCount && \
	$uc2 >= $VBase && $uc2 < $VBase + $VCount} {
	return [expr {$SBase + (($uc1 - $LBase) * $VCount + \
		      ($uc2 - $VBase)) * $TCount}]
    }

    if {$uc1 >= $SBase && $uc1 < $SBase + $SCount && \
	(($uc1 - $SBase) % $TCount) == 0 && \
	$uc2 >= $TBase && $uc2 < $TBase + $TCount} {
	return [expr {$uc1 + $uc2 - $TBase}]
    }

    # For others do a lookup in data tables
    set info1 [data::GetUniCharCompInfo $uc1]
    set res [data::GetCompFirst $uc2 $info1]
    if {$res != -1} {
	return $res
    }

    set info2 [data::GetUniCharCompInfo $uc2]
    set res [data::GetCompSecond $uc1 $info2]
    if {$res != -1} {
	return $res
    }

    data::GetCompBoth $info1 $info2
}

########################################################################

proc ::unicode::composeCanonical {uclist} {
    if {[llength $uclist] == 0} {
	return {}
    }

    set res {}
    set comps {}
    set ch1 [lindex $uclist 0]
    set cclass_prev [data::GetUniCharCClass $ch1]
    foreach ch2 [lrange $uclist 1 end] {
	set cclass [data::GetUniCharCClass $ch2]
	if {($cclass_prev == 0 || $cclass > $cclass_prev) && \
		[set ruc [composeTwo $ch1 $ch2]]} {
	    set ch1 $ruc
	} else {
	    if {$cclass == 0} {
		lappend res $ch1
		set res [concat $res $comps]
		set comps {}
		set ch1 $ch2
		set cclass_prev 0
	    } else {
		lappend comps $ch2
		set cclass_prev $cclass
	    }
	}
    }
    lappend res $ch1
    concat $res $comps
}

########################################################################

package provide unicode 1.0.0

