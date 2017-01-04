# base64.tcl --
#
# Encode/Decode base64 for a string
# Stephen Uhler / Brent Welch (c) 1997 Sun Microsystems
# The decoder was done for exmh by Chris Garrigues
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: base64.tcl,v 1.32 2010/07/06 19:15:40 andreas_kupries Exp $

# Version 1.0   implemented Base64_Encode, Base64_Decode
# Version 2.0   uses the base64 namespace
# Version 2.1   fixes various decode bugs and adds options to encode
# Version 2.2   is much faster, Tcl8.0 compatible
# Version 2.2.1 bugfixes
# Version 2.2.2 bugfixes
# Version 2.3   bugfixes and extended to support Trf

# @mdgen EXCLUDE: base64c.tcl

package require Tcl 8.2
namespace eval ::base64 {
    namespace export encode decode
}

if {![catch {package require Trf 2.0}]} {
    # Trf is available, so implement the functionality provided here
    # in terms of calls to Trf for speed.

    # ::base64::encode --
    #
    #	Base64 encode a given string.
    #
    # Arguments:
    #	args	?-maxlen maxlen? ?-wrapchar wrapchar? string
    #	
    #		If maxlen is 0, the output is not wrapped.
    #
    # Results:
    #	A Base64 encoded version of $string, wrapped at $maxlen characters
    #	by $wrapchar.
    
    proc ::base64::encode {args} {
	# Set the default wrapchar and maximum line length to match
	# the settings for MIME encoding (RFC 3548, RFC 2045). These
	# are the settings used by Trf as well. Various RFCs allow for
	# different wrapping characters and wraplengths, so these may
	# be overridden by command line options.
	set wrapchar "\n"
	set maxlen 76

	if { [llength $args] == 0 } {
	    error "wrong # args: should be \"[lindex [info level 0] 0]\
		    ?-maxlen maxlen? ?-wrapchar wrapchar? string\""
	}

	set optionStrings [list "-maxlen" "-wrapchar"]
	for {set i 0} {$i < [llength $args] - 1} {incr i} {
	    set arg [lindex $args $i]
	    set index [lsearch -glob $optionStrings "${arg}*"]
	    if { $index == -1 } {
		error "unknown option \"$arg\": must be -maxlen or -wrapchar"
	    }
	    incr i
	    if { $i >= [llength $args] - 1 } {
		error "value for \"$arg\" missing"
	    }
	    set val [lindex $args $i]

	    # The name of the variable to assign the value to is extracted
	    # from the list of known options, all of which have an
	    # associated variable of the same name as the option without
	    # a leading "-". The [string range] command is used to strip
	    # of the leading "-" from the name of the option.
	    #
	    # FRINK: nocheck
	    set [string range [lindex $optionStrings $index] 1 end] $val
	}
    
	# [string is] requires Tcl8.2; this works with 8.0 too
	if {[catch {expr {$maxlen % 2}}]} {
	    return -code error "expected integer but got \"$maxlen\""
	} elseif {$maxlen < 0} {
	    return -code error "expected positive integer but got \"$maxlen\""
	}

	set string [lindex $args end]
	set result [::base64 -mode encode -- $string]

	# Trf's encoder implicitly uses the settings -maxlen 76,
	# -wrapchar \n for its output. We may have to reflow this for
	# the settings chosen by the user. A second difference is that
	# Trf closes the output with the wrap char sequence,
	# always. The code here doesn't. Therefore 'trimright' is
	# needed in the fast cases.

	if {($maxlen == 76) && [string equal $wrapchar \n]} {
	    # Both maxlen and wrapchar are identical to Trf's
	    # settings. This is the super-fast case, because nearly
	    # nothing has to be done. Only thing to do is strip a
	    # terminating wrapchar.
	    set result [string trimright $result]
	} elseif {$maxlen == 76} {
	    # wrapchar has to be different here, length is the
	    # same. We can use 'string map' to transform the wrap
	    # information.
	    set result [string map [list \n $wrapchar] \
			    [string trimright $result]]
	} elseif {$maxlen == 0} {
	    # Have to reflow the output to no wrapping. Another fast
	    # case using only 'string map'. 'trimright' is not needed
	    # here.

	    set result [string map [list \n ""] $result]
	} else {
	    # Have to reflow the output from 76 to the chosen maxlen,
	    # and possibly change the wrap sequence as well.

	    # Note: After getting rid of the old wrap sequence we
	    # extract the relevant segments from the string without
	    # modifying the string. Modification, i.e. removal of the
	    # processed part, means 'shifting down characters in
	    # memory', making the algorithm O(n^2). By avoiding the
	    # modification we stay in O(n).
	    
	    set result [string map [list \n ""] $result]
	    set l [expr {[string length $result]-$maxlen}]
	    for {set off 0} {$off < $l} {incr off $maxlen} {
		append res [string range $result $off [expr {$off+$maxlen-1}]] $wrapchar
	    }
	    append res [string range $result $off end]
	    set result $res
	}

	return $result
    }

    # ::base64::decode --
    #
    #	Base64 decode a given string.
    #
    # Arguments:
    #	string	The string to decode.  Characters not in the base64
    #		alphabet are ignored (e.g., newlines)
    #
    # Results:
    #	The decoded value.

    proc ::base64::decode {string} {
	regsub -all {\s} $string {} string
	::base64 -mode decode -- $string
    }

} else {
    # Without Trf use a pure tcl implementation

    namespace eval base64 {
	variable base64 {}
	variable base64_en {}

	# We create the auxiliary array base64_tmp, it will be unset later.
	variable base64_tmp
	variable i

	set i 0
	foreach char {A B C D E F G H I J K L M N O P Q R S T U V W X Y Z \
		a b c d e f g h i j k l m n o p q r s t u v w x y z \
		0 1 2 3 4 5 6 7 8 9 + /} {
	    set base64_tmp($char) $i
	    lappend base64_en $char
	    incr i
	}

	#
	# Create base64 as list: to code for instance C<->3, specify
	# that [lindex $base64 67] be 3 (C is 67 in ascii); non-coded
	# ascii chars get a {}. we later use the fact that lindex on a
	# non-existing index returns {}, and that [expr {} < 0] is true
	#

	# the last ascii char is 'z'
	variable char
	variable len
	variable val

	scan z %c len
	for {set i 0} {$i <= $len} {incr i} {
	    set char [format %c $i]
	    set val {}
	    if {[info exists base64_tmp($char)]} {
		set val $base64_tmp($char)
	    } else {
		set val {}
	    }
	    lappend base64 $val
	}

	# code the character "=" as -1; used to signal end of message
	scan = %c i
	set base64 [lreplace $base64 $i $i -1]

	# remove unneeded variables
	unset base64_tmp i char len val

	namespace export encode decode
    }

    # ::base64::encode --
    #
    #	Base64 encode a given string.
    #
    # Arguments:
    #	args	?-maxlen maxlen? ?-wrapchar wrapchar? string
    #	
    #		If maxlen is 0, the output is not wrapped.
    #
    # Results:
    #	A Base64 encoded version of $string, wrapped at $maxlen characters
    #	by $wrapchar.
    
    proc ::base64::encode {args} {
	set base64_en $::base64::base64_en
	
	# Set the default wrapchar and maximum line length to match
	# the settings for MIME encoding (RFC 3548, RFC 2045). These
	# are the settings used by Trf as well. Various RFCs allow for
	# different wrapping characters and wraplengths, so these may
	# be overridden by command line options.
	set wrapchar "\n"
	set maxlen 76

	if { [llength $args] == 0 } {
	    error "wrong # args: should be \"[lindex [info level 0] 0]\
		    ?-maxlen maxlen? ?-wrapchar wrapchar? string\""
	}

	set optionStrings [list "-maxlen" "-wrapchar"]
	for {set i 0} {$i < [llength $args] - 1} {incr i} {
	    set arg [lindex $args $i]
	    set index [lsearch -glob $optionStrings "${arg}*"]
	    if { $index == -1 } {
		error "unknown option \"$arg\": must be -maxlen or -wrapchar"
	    }
	    incr i
	    if { $i >= [llength $args] - 1 } {
		error "value for \"$arg\" missing"
	    }
	    set val [lindex $args $i]

	    # The name of the variable to assign the value to is extracted
	    # from the list of known options, all of which have an
	    # associated variable of the same name as the option without
	    # a leading "-". The [string range] command is used to strip
	    # of the leading "-" from the name of the option.
	    #
	    # FRINK: nocheck
	    set [string range [lindex $optionStrings $index] 1 end] $val
	}
    
	# [string is] requires Tcl8.2; this works with 8.0 too
	if {[catch {expr {$maxlen % 2}}]} {
	    return -code error "expected integer but got \"$maxlen\""
	} elseif {$maxlen < 0} {
	    return -code error "expected positive integer but got \"$maxlen\""
	}

	set string [lindex $args end]

	set result {}
	set state 0
	set length 0


	# Process the input bytes 3-by-3

	binary scan $string c* X

	foreach {x y z} $X {
	    ADD [lindex $base64_en [expr {($x >>2) & 0x3F}]]
	    if {$y != {}} {
		ADD [lindex $base64_en [expr {(($x << 4) & 0x30) | (($y >> 4) & 0xF)}]]
		if {$z != {}} {
		    ADD [lindex $base64_en [expr {(($y << 2) & 0x3C) | (($z >> 6) & 0x3)}]]
		    ADD [lindex $base64_en [expr {($z & 0x3F)}]]
		} else {
		    set state 2
		    break
		}
	    } else {
		set state 1
		break
	    }
	}
	if {$state == 1} {
	    ADD [lindex $base64_en [expr {(($x << 4) & 0x30)}]]
	    ADD =
	    ADD =
	} elseif {$state == 2} {
	    ADD [lindex $base64_en [expr {(($y << 2) & 0x3C)}]]
	    ADD =
	}
	return $result
    }

    proc ::base64::ADD {x} {
	# The line length check is always done before appending so
	# that we don't get an extra newline if the output is a
	# multiple of $maxlen chars long.

	upvar 1 maxlen maxlen length length result result wrapchar wrapchar
	if {$maxlen && $length >= $maxlen} {
	    append result $wrapchar
	    set length 0
	}
	append result $x
	incr length
	return
    }

    # ::base64::decode --
    #
    #	Base64 decode a given string.
    #
    # Arguments:
    #	string	The string to decode.  Characters not in the base64
    #		alphabet are ignored (e.g., newlines)
    #
    # Results:
    #	The decoded value.

    proc ::base64::decode {string} {
	if {[string length $string] == 0} {return ""}

	set base64 $::base64::base64
	set output "" ; # Fix for [Bug 821126]

	binary scan $string c* X
	foreach x $X {
	    set bits [lindex $base64 $x]
	    if {$bits >= 0} {
		if {[llength [lappend nums $bits]] == 4} {
		    foreach {v w z y} $nums break
		    set a [expr {($v << 2) | ($w >> 4)}]
		    set b [expr {(($w & 0xF) << 4) | ($z >> 2)}]
		    set c [expr {(($z & 0x3) << 6) | $y}]
		    append output [binary format ccc $a $b $c]
		    set nums {}
		}		
	    } elseif {$bits == -1} {
		# = indicates end of data.  Output whatever chars are left.
		# The encoding algorithm dictates that we can only have 1 or 2
		# padding characters.  If x=={}, we must (*) have 12 bits of input 
		# (enough for 1 8-bit output).  If x!={}, we have 18 bits of
		# input (enough for 2 8-bit outputs).
		#
		# (*) If we don't then the input is broken (bug 2976290).

		foreach {v w z} $nums break

		# Bug 2976290
		if {$w == {}} {
		    return -code error "Not enough data to process padding"
		}

		set a [expr {($v << 2) | (($w & 0x30) >> 4)}]
		if {$z == {}} {
		    append output [binary format c $a ]
		} else {
		    set b [expr {(($w & 0xF) << 4) | (($z & 0x3C) >> 2)}]
		    append output [binary format cc $a $b]
		}		
		break
	    } else {
		# RFC 2045 says that line breaks and other characters not part
		# of the Base64 alphabet must be ignored, and that the decoder
		# can optionally emit a warning or reject the message.  We opt
		# not to do so, but to just ignore the character. 
		continue
	    }
	}
	return $output
    }
}

package provide base64 2.4.2
