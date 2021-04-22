# json.tcl --
#
#	JSON parser for Tcl. Management code, Tcl/C detection and selection.
#
# Copyright (c) 2013 by Andreas Kupries

# @mdgen EXCLUDE: jsonc.tcl

package require Tcl 8.4
namespace eval ::json {}

# ### ### ### ######### ######### #########
## Management of json implementations.

# ::json::LoadAccelerator --
#
#	Loads a named implementation, if possible.
#
# Arguments:
#	key	Name of the implementation to load.
#
# Results:
#	A boolean flag. True if the implementation
#	was successfully loaded; and False otherwise.

proc ::json::LoadAccelerator {key} {
    variable accel
    set r 0
    switch -exact -- $key {
	critcl {
	    # Critcl implementation of json requires Tcl 8.4.
	    if {![package vsatisfies [package provide Tcl] 8.4]} {return 0}
	    if {[catch {package require tcllibc}]} {return 0}
	    # Check for the jsonc 1.1.1 API we are fixing later.
	    set r [llength [info commands ::json::many_json2dict_critcl]]
	}
	tcl {
	    variable selfdir
	    source [file join $selfdir json_tcl.tcl]
	    set r 1
	}
        default {
            return -code error "invalid accelerator/impl. package $key:\
                must be one of [join [KnownImplementations] {, }]"
        }
    }
    set accel($key) $r
    return $r
}

# ::json::SwitchTo --
#
#	Activates a loaded named implementation.
#
# Arguments:
#	key	Name of the implementation to activate.
#
# Results:
#	None.

proc ::json::SwitchTo {key} {
    variable accel
    variable loaded
    variable apicmds

    if {[string equal $key $loaded]} {
	# No change, nothing to do.
	return
    } elseif {![string equal $key ""]} {
	# Validate the target implementation of the switch.

	if {![info exists accel($key)]} {
	    return -code error "Unable to activate unknown implementation \"$key\""
	} elseif {![info exists accel($key)] || !$accel($key)} {
	    return -code error "Unable to activate missing implementation \"$key\""
	}
    }

    # Deactivate the previous implementation, if there was any.

    if {![string equal $loaded ""]} {
	foreach c $apicmds {
	    rename ::json::${c} ::json::${c}_$loaded
	}
    }

    # Activate the new implementation, if there is any.

    if {![string equal $key ""]} {
	foreach c $apicmds {
	    rename ::json::${c}_$key ::json::${c}
	}
    }

    # Remember the active implementation, for deactivation by future
    # switches.

    set loaded $key
    return
}

# ::json::Implementations --
#
#	Determines which implementations are
#	present, i.e. loaded.
#
# Arguments:
#	None.
#
# Results:
#	A list of implementation keys.

proc ::json::Implementations {} {
    variable accel
    set res {}
    foreach n [array names accel] {
	if {!$accel($n)} continue
	lappend res $n
    }
    return $res
}

# ::json::KnownImplementations --
#
#	Determines which implementations are known
#	as possible implementations.
#
# Arguments:
#	None.
#
# Results:
#	A list of implementation keys. In the order
#	of preference, most prefered first.

proc ::json::KnownImplementations {} {
    return {critcl tcl}
}

proc ::json::Names {} {
    return {
	critcl {tcllibc based}
	tcl    {pure Tcl}
    }
}

# ### ### ### ######### ######### #########
## Initialization: Data structures.

namespace eval ::json {
    variable  selfdir [file dirname [info script]]
    variable  accel
    array set accel   {tcl 0 critcl 0}
    variable  loaded  {}

    variable apicmds {
	json2dict
	many-json2dict
    }
}

# ### ### ### ######### ######### #########
## Wrapper fix for the jsonc package to match APIs.

proc ::json::many-json2dict_critcl {args} {
    eval [linsert $args 0 ::json::many_json2dict_critcl]
}

# ### ### ### ######### ######### #########
## Initialization: Choose an implementation,
## most prefered first. Loads only one of the
## possible implementations. And activates it.

namespace eval ::json {
    variable e
    foreach e [KnownImplementations] {
	if {[LoadAccelerator $e]} {
	    SwitchTo $e
	    break
	}
    }
    unset e
}

# ### ### ### ######### ######### #########
## Tcl implementation of validation, shared for Tcl and C implementation.
##
## The regexp based validation is consistently faster than json-c.
## Suspected reasons: Tcl REs are mainly in C as well, and json-c has
## overhead in constructing its own data structures. While irrelevant
## to validation json-c still builds them, it has no mode doing pure
## syntax checking.

namespace eval ::json {
    # Regular expression for tokenizing a JSON text (cf. http://json.org/)

    # tokens consisting of a single character
    variable singleCharTokens { "{" "}" ":" "\\[" "\\]" "," }
    variable singleCharTokenRE "\[[join $singleCharTokens {}]\]"

    # quoted string tokens
    variable escapableREs { "[\\\"\\\\/bfnrt]" "u[[:xdigit:]]{4}" "." }
    variable escapedCharRE "\\\\(?:[join $escapableREs |])"
    variable unescapedCharRE {[^\\\"]}
    variable stringRE "\"(?:$escapedCharRE|$unescapedCharRE)*\""

    # as above, for validation
    variable escapableREsv { "[\\\"\\\\/bfnrt]" "u[[:xdigit:]]{4}" }
    variable escapedCharREv "\\\\(?:[join $escapableREsv |])"
    variable stringREv "\"(?:$escapedCharREv|$unescapedCharRE)*\""

    # (unquoted) words
    variable wordTokens { "true" "false" "null" }
    variable wordTokenRE [join $wordTokens "|"]

    # number tokens
    # negative lookahead (?!0)[[:digit:]]+ might be more elegant, but
    # would slow down tokenizing by a factor of up to 3!
    variable positiveRE {[1-9][[:digit:]]*}
    variable cardinalRE "-?(?:$positiveRE|0)"
    variable fractionRE {[.][[:digit:]]+}
    variable exponentialRE {[eE][+-]?[[:digit:]]+}
    variable numberREa "${cardinalRE}(?:$fractionRE)?(?:$exponentialRE)?"
    variable numberREb "${fractionRE}(?:$exponentialRE)?"
    variable numberREc "${cardinalRE}\[.\](?:$exponentialRE)?"
    variable numberRE  "$numberREa|$numberREb|$numberREc"
    variable numberRE  "$numberREa|$numberREb|$numberREc"

    # JSON token, and validation
    variable tokenRE "$singleCharTokenRE|$stringRE|$wordTokenRE|$numberRE"
    variable tokenREv "$singleCharTokenRE|$stringREv|$wordTokenRE|$numberRE"

    # 0..n white space characters
    set whiteSpaceRE {[[:space:]]*}

    # Regular expression for validating a JSON text
    variable validJsonRE "^(?:${whiteSpaceRE}(?:$tokenREv))*${whiteSpaceRE}$"
}


# Validate JSON text
# @param jsonText JSON text
# @return 1 iff $jsonText conforms to the JSON grammar
#           (@see http://json.org/)
proc ::json::validate {jsonText} {
    variable validJsonRE

    return [regexp -- $validJsonRE $jsonText]
}

# ### ### ### ######### ######### #########
## These three procedures shared between Tcl and Critcl implementations.
## See also package "json::write".

proc ::json::dict2json {dictVal} {
    # XXX: Currently this API isn't symmetrical, as to create proper
    # XXX: JSON text requires type knowledge of the input data
    set json ""
    set prefix ""

    foreach {key val} $dictVal {
	# key must always be a string, val may be a number, string or
	# bare word (true|false|null)
	if {0 && ![string is double -strict $val]
	    && ![regexp {^(?:true|false|null)$} $val]} {
	    set val "\"$val\""
	}
    	append json "$prefix\"$key\": $val" \n
	set prefix ,
    }

    return "\{${json}\}"
}

proc ::json::list2json {listVal} {
    return "\[[join $listVal ,]\]"
}

proc ::json::string2json {str} {
    return "\"$str\""
}

# ### ### ### ######### ######### #########
## Ready

package provide json 1.3.4
