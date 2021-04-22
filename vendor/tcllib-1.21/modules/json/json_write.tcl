# json_write.tcl --
#
#	Commands for the generation of JSON (Java Script Object Notation).
#
# Copyright (c) 2009-2011,2022 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5

namespace eval ::json::write {
    namespace export \
	string array array-strings object object-strings indented aligned

    namespace ensemble create
}

# ### ### ### ######### ######### #########
## API.

proc ::json::write::indented {{bool {}}} {
    variable indented

    if {[llength [info level 0]] > 2} {
	return -code error {wrong # args: should be "json::write indented ?bool?"}
    } elseif {[llength [info level 0]] == 2} {
	if {![::string is boolean -strict $bool]} {
	    return -code error "Expected boolean, got \"$bool\""
	}
	set indented $bool
	if {!$indented} {
	    variable aligned 0
	}
    }

    return $indented
}

proc ::json::write::aligned {{bool {}}} {
    variable aligned

    if {[llength [info level 0]] > 2} {
	return -code error {wrong # args: should be "json::write aligned ?bool?"}
    } elseif {[llength [info level 0]] == 2} {
	if {![::string is boolean -strict $bool]} {
	    return -code error "Expected boolean, got \"$bool\""
	}
	set aligned $bool
	if {$aligned} {
	    variable indented 1
	}
    }

    return $aligned
}

proc ::json::write::string {s} {
    variable quotes
    return "\"[::string map $quotes $s]\""
}

proc ::json::write::array {args} {
    # always compact form.
    return "\[[join $args ,]\]"
}

proc ::json::write::array-strings {args} {
    # convenience command for an array of strings.
    set words {}
    foreach w $args { lappend words [string $w] }
    return [array {*}$words]
}

proc ::json::write::object-strings {args} {
    # convenience command for an object of string fields.
    set words {}
    foreach {k v} $args { lappend words $k [string $v] }
    return [object {*}$words]
}

proc ::json::write::object {args} {
    # The dict in args maps string keys to json-formatted data. I.e.
    # we have to quote the keys, but not the values, as the latter are
    # already in the proper format.

    variable aligned
    variable indented

    if {[llength $args] %2 == 1} {
	return -code error {wrong # args, expected an even number of arguments}
    }

    set dict {}
    foreach {k v} $args {
	lappend dict [string $k] $v
    }

    if {$aligned} {
	set max [MaxKeyLength $dict]
    }

    if {$indented} {
	set content {}
	foreach {k v} $dict {
	    if {$aligned} {
		set k [AlignLeft $max $k]
	    }
	    if {[::string match *\n* $v]} {
		# multi-line value
		lappend content "    $k : [Indent $v {    } 1]"
	    } else {
		# single line value.
		lappend content "    $k : $v"
	    }
	}
	if {[llength $content]} {
	    return "\{\n[join $content ,\n]\n\}"
	} else {
	    return "\{\}"
	}
    } else {
	# ultra compact form.
	set tmp {}
	foreach {k v} $dict {
	    lappend tmp "$k:$v"
	}
	return "\{[join $tmp ,]\}"
    }
}

# ### ### ### ######### ######### #########
## Internals.

proc ::json::write::Indent {text prefix skip} {
    set pfx ""
    set result {}
    foreach line [split $text \n] {
	if {!$skip} { set pfx $prefix } else { incr skip -1 }
	lappend result ${pfx}$line
    }
    return [join $result \n]
}

proc ::json::write::MaxKeyLength {dict} {
    # Find the max length of the keys in the dictionary.

    set lengths 0 ; # This will be the max if the dict is empty, and
		    # prevents the mathfunc from throwing errors for
		    # that case.

    foreach str [dict keys $dict] {
	lappend lengths [::string length $str]
    }

    return [tcl::mathfunc::max {*}$lengths]
}

proc ::json::write::AlignLeft {fieldlen str} {
    return [format %-${fieldlen}s $str]
    #return $str[::string repeat { } [expr {$fieldlen - [::string length $str]}]]
}

# ### ### ### ######### ######### #########

namespace eval ::json::write {
    # Configuration of the layout to write.

    # indented = boolean. objects are indented.
    # aligned  = boolean. object keys are aligned vertically.

    # aligned  => indented.

    # Combinations of the format specific entries
    # I A |
    # - - + ---------------------
    # 0 0 | Ultracompact (no whitespace, single line)
    # 1 0 | Indented
    # 0 1 | Not possible, per the implications above.
    # 1 1 | Indented + vertically aligned keys
    # - - + ---------------------

    variable indented 1
    variable aligned  1

    variable quotes \
	[list "\"" "\\\"" \\ \\\\ \b \\b \f \\f \n \\n \r \\r \t \\t \
	     \x00 \\u0000 \x01 \\u0001 \x02 \\u0002 \x03 \\u0003 \
	     \x04 \\u0004 \x05 \\u0005 \x06 \\u0006 \x07 \\u0007 \
	     \x0b \\u000b \x0e \\u000e \x0f \\u000f \x10 \\u0010 \
	     \x11 \\u0011 \x12 \\u0012 \x13 \\u0013 \x14 \\u0014 \
	     \x15 \\u0015 \x16 \\u0016 \x17 \\u0017 \x18 \\u0018 \
	     \x19 \\u0019 \x1a \\u001a \x1b \\u001b \x1c \\u001c \
	     \x1d \\u001d \x1e \\u001e \x1f \\u001f \x7f \\u007f \
	     \x80 \\u0080 \x81 \\u0081 \x82 \\u0082 \x83 \\u0083 \
	     \x84 \\u0084 \x85 \\u0085 \x86 \\u0086 \x87 \\u0087 \
	     \x88 \\u0088 \x89 \\u0089 \x8a \\u008a \x8b \\u008b \
	     \x8c \\u008c \x8d \\u008d \x8e \\u008e \x8f \\u008f \
	     \x90 \\u0090 \x91 \\u0091 \x92 \\u0092 \x93 \\u0093 \
	     \x94 \\u0094 \x95 \\u0095 \x96 \\u0096 \x97 \\u0097 \
	     \x98 \\u0098 \x99 \\u0099 \x9a \\u009a \x9b \\u009b \
	     \x9c \\u009c \x9d \\u009d \x9e \\u009e \x9f \\u009f ]
}

# ### ### ### ######### ######### #########
## Ready

package provide json::write 1.0.4
return
