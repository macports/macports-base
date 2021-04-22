# ip.tcl - Copyright (C) 2004 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# Internet address manipulation.
#
# RFC 3513: IPv6 addressing.
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

# @mdgen EXCLUDE: ipMoreC.tcl

package require Tcl 8.2;                # tcl minimum version

namespace eval ip {
    namespace export is version normalize equal type contract mask collapse subtract
    #catch {namespace ensemble create}

    variable IPv4Ranges
    if {![info exists IPv4Ranges]} {
        array set IPv4Ranges {
            0/8        private
            10/8       private
            127/8      private
            172.16/12  private
            192.168/16 private
            223/8      reserved
            224/3      reserved
        }
    }

    variable IPv6Ranges
    if {![info exists IPv6Ranges]} {
        # RFC 3513: 2.4
        # RFC 3056: 2
        array set IPv6Ranges {
            2002::/16 "6to4 unicast"
            fe80::/10 "link local"
            fec0::/10 "site local"
            ff00::/8  "multicast"
            ::/128    "unspecified"
            ::1/128   "localhost"
        }
    }
}

proc ::ip::is {class ip} {
    foreach {ip mask} [split $ip /] break
    switch -exact -- $class {
        ipv4 - IPv4 - 4 {
            return [IPv4? $ip]
        }
        ipv6 - IPv6 - 6 {
            return [IPv6? $ip]
        }
        default {
            return -code error "bad class \"$class\": must be ipv4 or ipv6"
        }
    }
}

proc ::ip::version {ip} {
    set version -1
    if {[string equal $ip {}]} { return $version}
    foreach {addr mask} [split $ip /] break
    if {[IPv4? $addr]} {
        set version 4
    } elseif {[IPv6? $addr]} {
        set version 6
    }
    return $version
}

proc ::ip::equal {lhs rhs} {
    foreach {LHS LM} [SplitIp $lhs] break
    foreach {RHS RM} [SplitIp $rhs] break
    if {[set version [version $LHS]] != [version $RHS]} {
        return -code error "type mismatch:\
            cannot compare different address types"
    }
    if {$version == 4} {set fmt I} else {set fmt I4}
    set LHS [Mask$version [Normalize $LHS $version] $LM]
    set RHS [Mask$version [Normalize $RHS $version] $RM]
    binary scan $LHS $fmt LLL
    binary scan $RHS $fmt RRR
    foreach L $LLL R $RRR {
        if {$L != $R} {return 0}
    }
    return 1
}

proc ::ip::collapse {prefixlist} {
    #puts **[llength $prefixlist]||$prefixlist

    # Force mask parts into length notation for the following merge
    # loop to work.
    foreach ip $prefixlist {
        foreach {addr mask} [SplitIp $ip] break
        set nip $addr/[maskToLength [maskToInt $mask]]
        #puts "prefix $ip = $nip"
        lappend tmp $nip
    }
    set prefixlist $tmp

    #puts @@[llength $prefixlist]||$prefixlist

    set ret {}
    set can_normalize_more 1
    while {$can_normalize_more} {
        set prefixlist [lsort -dict $prefixlist]

        #puts ||[llength $prefixlist]||$prefixlist

        set can_normalize_more 0

        for {set idx 0} {$idx < [llength $prefixlist]} {incr idx} {
            set nextidx [expr {$idx + 1}]

            set item     [lindex $prefixlist $idx]
            set nextitem [lindex $prefixlist $nextidx]

            if {$nextitem eq ""} {
                lappend ret $item
                continue
            }

            set itemmask     [mask $item]
            set nextitemmask [mask $nextitem]

            set item [prefix $item]

            if {$itemmask ne $nextitemmask} {
                lappend ret $item/$itemmask
                continue
            }

            set adjacentitem [intToString [nextNet $item $itemmask]]/$itemmask

            if {$nextitem ne $adjacentitem} {
                lappend ret $item/$itemmask
                continue
            }

            set upmask [expr {$itemmask - 1}]
            set upitem "$item/$upmask"

            # Maybe just checking the llength of the result is enough ?
            if {[reduceToAggregates [list $item $nextitem $upitem]] != [list $upitem]} {
                lappend ret $item/$itemmask
                continue
            }

            set can_normalize_more 1

            incr idx
            lappend ret $upitem
        }

	set prefixlist $ret
        set ret {}
    }

    return $prefixlist
}


proc ::ip::normalize {ip {Ip4inIp6 0}} {
    foreach {ip mask} [SplitIp $ip] break
    set version [version $ip]
    set s [ToString [Normalize $ip $version] $Ip4inIp6]
    if {($version == 6 && $mask != 128) || ($version == 4 && $mask != 32)} {
        append s /$mask
    }
    return $s
}

proc ::ip::contract {ip} {
    foreach {ip mask} [SplitIp $ip] break
    set version [version $ip]
    set s [ToString [Normalize $ip $version]]
    if {$version == 6} {
        set r ""
        foreach o [split $s :] {
            append r [format %x: 0x$o]
        }
        set r [string trimright $r :]
        regsub {(?:^|:)0(?::0)+(?::|$)} $r {::} r
    } else {
        set r [string trimright $s .0]
    }
    return $r
}

proc ::ip::subtract {hosts} {
    set positives {}
    set negatives {}

    foreach host $hosts {
        foreach {addr mask} [SplitIp $host] break
        set host $addr/[maskToLength [maskToInt $mask]]

	if {[string match "-*" $host]} {
	    set host [string trimleft $host "-"]
	    lappend negatives $host
	} else {
	    lappend positives $host
	}
    }

    # Reduce to aggregates if needed
    if {[llength $positives] > 1} {
	set positives [reduceToAggregates $positives]
    }

    if {![llength $positives]} {
	return {}
    }

    if {[llength $negatives] > 1} {
	set negatives [reduceToAggregates $negatives]
    }

    if {![llength $negatives]} {
	return $positives
    }

    # Remove positives that are cancelled out entirely
    set new_positives {}
    foreach positive $positives {
	set found 0
	foreach negative $negatives {
            # Do we need the exact check, i.e. ==, or 'eq', or would
            # checking the length of result == 1 be good enough?
	    if {[reduceToAggregates [list $positive $negative]] == [list $negative]} {
		set found 1
		break
	    }
	}

	if {!$found} {
	    lappend new_positives $positive
	}
    }
    set positives $new_positives

    set retval {}
    foreach positive $positives {
	set negatives_found {}
	foreach negative $negatives {
	    if {[isOverlap $positive $negative]} {
		lappend negatives_found $negative
	    }
	}

	if {![llength $negatives_found]} {
	    lappend retval $positive
	    continue
	}

	# Convert the larger subnet
	## Determine smallest subnet involved
	set maxmask 0
	foreach subnet [linsert $negatives 0 $positive] {
	    set mask [mask $subnet]
	    if {$mask > $maxmask} {
		set maxmask $mask
	    }
	}

	set positive_list [ExpandSubnet $positive $maxmask]
	set negative_list {}
	foreach negative $negatives_found {
	    foreach negative_subnet [ExpandSubnet $negative $maxmask] {
		lappend negative_list $negative_subnet
	    }
	}

	foreach positive_sub $positive_list {
	    if {[lsearch -exact $negative_list $positive_sub] < 0} {
		lappend retval $positive_sub
	    }
	}
    }

    return $retval
}

proc ::ip::ExpandSubnet {subnet newmask} {
    #set oldmask [maskToLength [maskToInt [mask $subnet]]]
    set oldmask [mask $subnet]
    set subnet  [prefix $subnet]

    set numsubnets [expr {round(pow(2, ($newmask - $oldmask)))}]

    set ret {}
    for {set idx 0} {$idx < $numsubnets} {incr idx} {
	lappend ret "${subnet}/${newmask}"
	set subnet [intToString [nextNet $subnet $newmask]]
    }

    return $ret
}

# Returns an IP address prefix.
# For instance:
#  prefix 192.168.1.4/16 => 192.168.0.0
#  prefix fec0::4/16     => fec0:0:0:0:0:0:0:0
#  prefix fec0::4/ffff:: => fec0:0:0:0:0:0:0:0
#
proc ::ip::prefix {ip} {
    foreach {addr mask} [SplitIp $ip] break
    set version [version $addr]
    set addr [Normalize $addr $version]
    return [ToString [Mask$version $addr $mask]]
}

# Return the address type. For IPv4 this is one of private, reserved
# or normal
# For IPv6 it is one of site local, link local, multicast, unicast,
# unspecified or loopback.
proc ::ip::type {ip} {
    set version [version $ip]
    upvar [namespace current]::IPv${version}Ranges types
    set ip [prefix $ip]
    foreach prefix [array names types] {
        set mask [mask $prefix]
        if {[equal $ip/$mask $prefix]} {
            return $types($prefix)
        }
    }
    if {$version == 4} {
        return "normal"
    } else {
        return "unicast"
    }
}

proc ::ip::mask {ip} {
    foreach {addr mask} [split $ip /] break
    return $mask
}

# -------------------------------------------------------------------------

# Returns true is the argument can be converted into an IPv4 address.
#
proc ::ip::IPv4? {ip} {
    if {[string first : $ip] >= 0} {
        return 0
    }
    if {[catch {Normalize4 $ip}]} {
        return 0
    }
    return 1
}

proc ::ip::IPv6? {ip} {
    set octets [split $ip :]
    if {[llength $octets] < 3 || [llength $octets] > 8} {
        return 0
    }
    set ndx 0
    foreach octet $octets {
        incr ndx
        if {[string length $octet] < 1} continue
        if {[regexp {^[a-fA-F\d]{1,4}$} $octet]} continue
        if {$ndx >= [llength $octets] && [IPv4? $octet]} continue
        if {$ndx == 2 && [lindex $octets 0] == 2002 && [IPv4? $octet]} continue
        #"Invalid IPv6 address \"$ip\""
        return 0
    }
    if {[regexp {^:[^:]} $ip]} {
        #"Invalid ipv6 address \"$ip\" (starts with :)"
        return 0
    }
    if {[regexp {[^:]:$} $ip]} {
        # "Invalid IPv6 address \"$ip\" (ends with :)"
        return 0
    }
    if {[regsub -all :: $ip "|" junk] > 1} {
        # "Invalid IPv6 address \"$ip\" (more than one :: pattern)"
        return 0
    }
    return 1
}

proc ::ip::Mask4 {ip {bits {}}} {
    if {[string length $bits] < 1} { set bits 32 }
    binary scan $ip I ipx
    if {[string is integer $bits]} {
        set mask [expr {(0xFFFFFFFF << (32 - $bits)) & 0xFFFFFFFF}]
    } else {
        binary scan [Normalize4 $bits] I mask
    }
    return [binary format I [expr {$ipx & $mask}]]
}

proc ::ip::Mask6 {ip {bits {}}} {
    if {[string length $bits] < 1} { set bits 128 }
    if {[string is integer $bits]} {
        set mask [binary format B128 [string repeat 1 $bits]]
    } else {
        binary scan [Normalize6 $bits] I4 mask
    }
    binary scan $ip I4 Addr
    binary scan $mask I4 Mask
    foreach A $Addr M $Mask {
        lappend r [expr {$A & $M}]
    }
    return [binary format I4 $r]
}



# A network address specification is an IPv4 address with an optional bitmask
# Split an address specification into a IPv4 address and a network bitmask.
# This doesn't validate the address portion.
# If a spec with no mask is provided then the mask will be 32
# (all bits significant).
# Masks may be either integer number of significant bits or dotted-quad
# notation.
#
proc ::ip::SplitIp {spec} {
    set slash [string last / $spec]
    if {$slash != -1} {
        incr slash -1
        set ip [string range $spec 0 $slash]
        incr slash 2
        set bits [string range $spec $slash end]
    } else {
        set ip $spec
        if {[string length $ip] > 0 && [version $ip] == 6} {
            set bits 128
        } else {
            set bits 32
        }
    }
    return [list $ip $bits]
}

# Given an IP string from the user, convert to a normalized internal rep.
# For IPv4 this is currently a hex string (0xHHHHHHHH).
# For IPv6 this is a binary string or 16 chars.
proc ::ip::Normalize {ip {version 0}} {
    if {$version < 0} {
        set version [version $ip]
        if {$version < 0} {
            return -code error "invalid address \"$ip\":\
                value must be a valid IPv4 or IPv6 address"
        }
    }
    return [Normalize$version $ip]
}

proc ::ip::Normalize4 {ip} {
    set octets [split $ip .]
    if {[llength $octets] > 4} {
        return -code error "invalid ip address \"$ip\""
    } elseif {[llength $octets] < 4} {
        set octets [lrange [concat $octets 0 0 0] 0 3]
    }
    set normalized {}
    foreach oct $octets {
        set oct [scan $oct %d]
        if {$oct < 0 || $oct > 255} {
            return -code error "invalid ip address"
        }
        lappend normalized $oct
    }
    return [binary format c4 $normalized]
}

proc ::ip::Normalize6 {ip} {
    set octets [split $ip :]
    set ip4embed [string first . $ip]
    set len [llength $octets]
    if {$len < 0 || $len > 8} {
        return -code error "invalid address: this is not an IPv6 address"
    }
    set result ""
    for {set n 0} {$n < $len} {incr n} {
        set octet [lindex $octets $n]
        if {$octet == {}} {
            if {$n == 0 || $n == ($len - 1)} {
                set octet \0\0
            } else {
                set missing [expr {9 - $len}]
                if {$ip4embed != -1} {incr missing -1}
                set octet [string repeat \0\0 $missing]
            }
        } elseif {[string first . $octet] != -1} {
            set octet [Normalize4 $octet]
        } else {
            set m [expr {4 - [string length $octet]}]
            if {$m != 0} {
                set octet [string repeat 0 $m]$octet
            }
            set octet [binary format H4 $octet]
        }
        append result $octet
    }
    if {[string length $result] != 16} {
        return -code error "invalid address: \"$ip\" is not an IPv6 address"
    }
    return $result
}


# This will convert a full ipv4/ipv6 in binary format into a normal
# expanded string rep.
proc ::ip::ToString {bin {Ip4inIp6 0}} {
    set len [string length $bin]
    set r ""
    if {$len == 4} {
        binary scan $bin c4 octets
        foreach octet $octets {
            lappend r [expr {$octet & 0xff}]
        }
        return [join $r .]
    } elseif {$len == 16} {
        if {$Ip4inIp6 == 0} {
            binary scan $bin H32 hex
            for {set n 0} {$n < 32} {incr n} {
                append r [string range $hex $n [incr n 3]]:
            }
            return [string trimright $r :]
        } else {
            binary scan $bin H24c4 hex octets
            for {set n 0} {$n < 24} {incr n} {
                append r [string range $hex $n [incr n 3]]:
            }
            foreach octet $octets {
                append r [expr {$octet & 0xff}].
            }
            return [string trimright $r .]
        }
    } else {
        return -code error "invalid binary address:\
            argument is neither an IPv4 nor an IPv6 address"
    }
}

# -------------------------------------------------------------------------
# Load extended command set.

source [file join [file dirname [info script]] ipMore.tcl]

# -------------------------------------------------------------------------

package provide ip 1.4

# -------------------------------------------------------------------------
# Local Variables:
#   indent-tabs-mode: nil
# End:
