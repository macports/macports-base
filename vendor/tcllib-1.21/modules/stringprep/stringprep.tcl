# stringprep.tcl                                                -*- tcl -*-
#
#	Implementation of RFC 3454 "Preparation of Internationalized Strings"
#
# Copyright (c) 2007 Sergei Golovan
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: stringprep.tcl,v 1.2 2009/11/02 00:26:44 patthoyts Exp $

package require stringprep::data 1.0
package require unicode 1.0

namespace eval ::stringprep {
    variable profiles
    array unset profiles
}

########################################################################
# Register new stringprep profile

proc ::stringprep::register {profile args} {
    variable profiles

    array set props [list -mapping "" \
			  -normalization "" \
			  -prohibited 0 \
			  -prohibitedList {} \
			  -prohibitedCommand "" \
			  -prohibitedBidi 0]

    foreach {opt val} $args {
	switch -- $opt {
	    -mapping {
		foreach tab $val {
		    switch -- $tab {
			B.1 - B.2 - B.3 {}
			default {
			    return -code error \
				   "::stringprep::register -mapping: Only\
				    B.1, B.2, B.3 tables are allowed"
			}
		    }
		}
		set props(-mapping) $val
	    }
	    -normalization {
		switch -- $val {
		    D - C - KD - KC - "" {
			set props(-normalization) $val
		    }
		    default {
			return -code error \
			       "::stringprep::register -normalization: Only\
				D, C, KD, KC or empty normalization is allowed"
		    }
		}
	    }
	    -prohibited {
		set mask 0
		set c39count 0
		foreach tab $val {
		    switch -- $tab {
			A.1 { set mask [expr {$mask | $data::A1Mask}] }
			C.1.1 { set mask [expr {$mask | $data::C11Mask}] }
			C.1.2 { set mask [expr {$mask | $data::C12Mask}] }
			C.2.1 { set mask [expr {$mask | $data::C21Mask}] }
			C.2.2 { set mask [expr {$mask | $data::C22Mask}] }
			C.3 - C.4 - C.5 - C.6 - C.7 - C.8 -
			C.9 { incr c39count }
			default {
			    return -code error \
				   "::stringprep::register -prohibited: Only\
				    tables A.1, C.* are allowed to prohibit"
			}
		    }
		}
		if {$c39count > 0 && $c39count < 7} {
		    return -code error \
			   "::stringprep::register -prohibited: Must prohibit\
			    all C.3--C.9 tables or none of them"
		}
		if {$c39count > 0} {
		    set mask [expr {$mask | $data::C39Mask}]
		}
		set props(-prohibited) $mask
	    }
	    -prohibitedList {
		if {[catch {
			foreach uc $val {
			    if {![string is integer -strict $uc]} {
				error not_integer
			    } else {
				lappend props(-prohibitedList) [expr {$uc}]
			    }
			}}]} {
		    return -code error \
			   "::stringprep::register -prohibitedList: List\
			    of integers expected"
		}
	    }
	    -prohibitedCommand {
		set props(-prohibitedCommand) $val
	    }
	    -prohibitedBidi {
		if {[string is true -strict $val]} {
		    set props(-prohibitedBidi) 1
		} elseif {[string is false -strict $val]} {
		    set props(-prohibitedBidi) 0
		} else {
		    return -code error \
			   "::stringprep::register -prohibitedBidi: Boolean\
			    value expected"
		}
	    }
	}
    }
    set profiles($profile) [array get props]
}

########################################################################
# Register identity profile

::stringprep::register none \
    -mapping {} \
    -normalization {} \
    -prohibited {} \
    -prohibitedBidi 0

########################################################################

proc ::stringprep::stringprep {profile str} {
    variable profiles

    if {![info exists profiles($profile)]} {
	return -code error invalid_profile
    }

    set uclist [::unicode::fromstring $str]

    set uclist [map $profile $uclist]
    if {[llength $uclist] == 0} {
	return ""
    }

    set uclist [normalize $profile $uclist]

    if {[prohibited $profile $uclist]} {
	return -code error prohibited_character
    }

    if {[prohibited_bidi $profile $uclist]} {
	return -code error prohibited_bidi
    }

    ::unicode::tostring $uclist
}

########################################################################

proc ::stringprep::compare {profile str1 str2} {
    string compare [stringprep $profile $str1] [stringprep $profile $str2]
}

########################################################################
# Mapping (section 3)

proc ::stringprep::map {profile uclist} {
    variable profiles

    array set props $profiles($profile)

    set B1Mask 0
    set B3Mask 0
    set B2 0
    foreach tab $props(-mapping) {
	switch -- $tab {
	    B.1 { set B1Mask $data::B1Mask }
	    B.2 { set B2 1 }
	    B.3 { set B3Mask $data::B3Mask }
	}
    }

    set res {}
    foreach uc $uclist {
	set info [data::GetUniCharInfo $uc]

	if {$info & $B1Mask} {
	    # Map to nothing
	    continue
	}

	if {$B2 || ($info & $B3Mask)} {
	    if {$info & $data::MCMask} {
		set res [concat $res [data::GetMC $info]]
	    } else {
		lappend res [expr {$uc + [data::GetDelta $info]}]
	    }
	} else {
	    lappend res $uc
	}
    }
    return $res
}

########################################################################
# Normalization (section 4)

proc ::stringprep::normalize {profile uclist} {
    variable profiles

    array set props $profiles($profile)

    switch -- $props(-normalization) {
	D - C - KD - KC {
	    return [::unicode::normalize $props(-normalization) $uclist]
	}
	default { return $uclist }
    }
}

########################################################################
# Prohibit (section 5)

proc ::stringprep::prohibited {profile uclist} {
    variable profiles

    array set props $profiles($profile)

    foreach uc $uclist {
	set info [data::GetUniCharInfo $uc]
	if {($info & $props(-prohibited)) || \
		[lsearch -exact $props(-prohibitedList) $uc] >= 0} {
	    return 1
	} elseif {$props(-prohibitedCommand) != "" && \
		[uplevel #0 $props(-prohibitedCommand) [list $uc]]} {
	    return 1
	}
    }
    return 0
}

########################################################################
# Check bidi (section 6)

proc ::stringprep::prohibited_bidi {profile uclist} {
    variable profiles

    array set props $profiles($profile)

    if {!$props(-prohibitedBidi)} {
	return 0
    }

    set info [data::GetUniCharInfo [lindex $uclist 0]]
    set first_ral [expr {$info & $data::D1Mask}]
    set last_ral 0
    set have_ral 0
    set have_l 0
    foreach uc $uclist {
	set info [data::GetUniCharInfo $uc]
	set last_ral [expr {$info & $data::D1Mask}]
	set have_ral [expr {$have_ral || $last_ral}]
	set have_l   [expr {$have_l || ($info & $data::D2Mask)}]
    }
    if {$have_ral && (!$first_ral || !$last_ral || $have_l)} {
	return 1
    } else {
	return 0
    }
}

########################################################################

package provide stringprep 1.0.1

########################################################################
