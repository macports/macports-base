#temporary home until this gets cleaned up for export to tcllib ip module

##Library Header
#
# Copyright (c) 2005 Cisco Systems, Inc.
#
# Name:
#       ipMore
#
# Purpose:
#       Additional commands for the tcllib ip package.
#
# Author:
#        Aamer Akhter / aakhter@cisco.com
#
# Support Alias:
#       aakhter@cisco.com
#
# Usage:
#       package require ip
#       (The command are loaded from the regular package).
#
# Description:
#       A detailed description of the functionality provided by the library.
#
# Requirements:
#
# Variables:
#       namespace   ::ip
#
# Notes:
#       1.
#
# Keywords:
#
#
# Category:
#
#
# End of Header

package require msgcat

# Try to load various C based accelerator packages for two of the
# commands.

if {[catch {package require ipMorec}]} {
    catch {package require tcllibc}
}

if {[llength [info commands ::ip::prefixToNativec]]} {
    # An accelerator is present, providing the C variants
    interp alias {} ::ip::prefixToNative  {} ::ip::prefixToNativec
    interp alias {} ::ip::isOverlapNative {} ::ip::isOverlapNativec
} else {
    # Link API to the Tcl variants, no accelerators are available.
    interp alias {} ::ip::prefixToNative  {} ::ip::prefixToNativeTcl
    interp alias {} ::ip::isOverlapNative {} ::ip::isOverlapNativeTcl
}

namespace eval ::ip {
    ::msgcat::mcload [file join [file dirname [info script]] msgs]
}

if {![llength [info commands lassign]]} {
    # Either an older tcl version, or tclx not loaded; have to use our
    # internal lassign from http://wiki.tcl.tk/1530 by Schelte Bron

    proc ::ip::lassign {values args} {
        uplevel 1 [list foreach $args $values break]
        lrange $values [llength $args] end
    }
}
if {![llength [info commands lvarpop]]} {
    # Define an emulation of Tclx's lvarpop if the command
    # is not present already.

    proc ::ip::lvarpop {upVar {index 0}} {
	upvar $upVar list;
	set top [lindex $list $index];
	set list [concat [lrange $list 0 [expr $index - 1]] \
		      [lrange $list [expr $index +1] end]];
	return $top;
    }
}

# Some additional aliases for backward compatability. Not
# documented. The old names are from previous versions while at Cisco.
#
#               Old command name -->      Documented command name
interp alias {} ::ip::ToInteger           {} ::ip::toInteger
interp alias {} ::ip::ToHex               {} ::ip::toHex
interp alias {} ::ip::MaskToInt           {} ::ip::maskToInt
interp alias {} ::ip::MaskToLength        {} ::ip::maskToLength
interp alias {} ::ip::LengthToMask        {} ::ip::lengthToMask
interp alias {} ::ip::IpToLayer2Multicast {} ::ip::ipToLayer2Multicast
interp alias {} ::ip::IpHostFromPrefix    {} ::ip::ipHostFromPrefix


##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::prefixToNative
#
# Purpose:
#        convert from dotted from to native (hex) form
#
# Synopsis:
#       prefixToNative <prefix>
#
# Arguments:
#        <prefix>
#            string in the <ipaddr>/<mask> format
#
# Return Values:
#        <prefix> in native format {<hexip> <hexmask>}
#
# Description:
#
# Examples:
#   % ip::prefixToNative 1.1.1.0/24
#   0x01010100 0xffffff00
#
# Sample Input:
#
# Sample Output:
# Notes:
#   fixed bug in C extension that modified
#    calling context variable
# See Also:
#
# End of Header

proc ip::prefixToNativeTcl {prefix} {
    set plist {}
    foreach p $prefix {
	set newPrefix [ip::toHex [ip::prefix $p]]
	if {[string equal [set mask [ip::mask $p]] ""]} {
	    set newMask 0xffffffff
	} else {
	    set newMask [format "0x%08x" [ip::maskToInt $mask]]
	}
	lappend plist [list $newPrefix $newMask]
    }
    if {[llength $plist]==1} {return [lindex $plist 0]}
    return $plist
}

##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::nativeToPrefix
#
# Purpose:
#        convert from native (hex) form to dotted form
#
# Synopsis:
#       nativeToPrefix <nativeList>|<native> [-ipv4]
#
# Arguments:
#        <nativeList>
#            list of native form ip addresses native form is:
#        <native>
#            tcllist in format {<hexip> <hexmask>}
#        -ipv4
#            the provided native format addresses are in ipv4 format (default)
#
# Return Values:
#        if nativeToPrefix is called with <native> a single (non-listified) address
#            is returned
#        if nativeToPrefix is called with a <nativeList> address list, then
#            a list of addresses is returned
#
#        return form is: <ipaddr>/<mask>
#
# Description:
#
# Examples:
#   % ip::nativeToPrefix {0x01010100 0xffffff00} -ipv4
#   1.1.1.0/24
#
# Sample Input:
#
# Sample Output:

# Notes:
#
# See Also:
#
# End of Header

proc ::ip::nativeToPrefix {nativeList args} {
    set pList 1
    set ipv4 1
    while {[llength $args]} {
	switch -- [lindex $args 0] {
	    -ipv4 {set args [lrange $args 1 end]}
	    default {
		return -code error [msgcat::mc "option %s not supported" [lindex $args 0]]
	    }
	}
    }

    # if a single native element is passed eg {0x01010100 0xffffff00}
    # instead of {{0x01010100 0xffffff00} {0x01010100 0xffffff00}...}
    # then return a (non-list) single entry
    if {[llength [lindex $nativeList 0]]==1} {set pList 0; set nativeList [list $nativeList]}
    foreach native $nativeList {
	lassign $native ip mask
	if {[string equal $mask ""]} {set mask 32}
	set pString ""
	append pString [ip::ToString [binary format I [expr {$ip}]]]
	append pString  "/"
	append pString [ip::maskToLength $mask]
	lappend rList $pString
    }
    # a multi (listified) entry was given
    # return the listified entry
    if {$pList} { return $rList }
    return $pString
}

##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::intToString
#
# Purpose:
#        convert from an integer/hex to dotted form
#
# Synopsis:
#       intToString <integer/hex> [-ipv4]
#
# Arguments:
#        <integer>
#            ip address in integer form
#        -ipv4
#            the provided integer addresses is ipv4 (default)
#
# Return Values:
#        ip address in dotted form
#
# Description:
#
# Examples:
#       ip::intToString 4294967295
#       255.255.255.255
#
# Sample Input:
#
# Sample Output:

# Notes:
#
# See Also:
#
# End of Header

proc ::ip::intToString {int args} {
    set ipv4 1
    while {[llength $args]} {
	switch -- [lindex $args 0] {
	    -ipv4 {set args [lrange $args 1 end]}
	    default {
		return -code error [msgcat::mc "option %s not supported" [lindex $args 0]]
	    }
	}
    }
    return [ip::ToString [binary format I [expr {$int}]]]
}


##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::toInteger
#
# Purpose:
#        convert dotted form ip to integer
#
# Synopsis:
#       toInteger <ipaddr>
#
# Arguments:
#        <ipaddr>
#            decimal dotted form ip address
#
# Return Values:
#        integer form of <ipaddr>
#
# Description:
#
# Examples:
#   % ::ip::toInteger 1.1.1.0
#   16843008
#
# Sample Input:
#
# Sample Output:

# Notes:
#
# See Also:
#
# End of Header

proc ::ip::toInteger {ip} {
    binary scan [ip::Normalize4 $ip] I out
    return [format %lu [expr {$out & 0xffffffff}]]
}

##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::toHex
#
# Purpose:
#        convert dotted form ip to hex
#
# Synopsis:
#       toHex <ipaddr>
#
# Arguments:
#        <ipaddr>
#            decimal dotted from ip address
#
# Return Values:
#        hex form of <ipaddr>
#
# Description:
#
# Examples:
#   % ::ip::toHex 1.1.1.0
#   0x01010100
#
# Sample Input:
#
# Sample Output:

# Notes:
#
# See Also:
#
# End of Header

proc ::ip::toHex {ip} {
    binary scan [ip::Normalize4 $ip] H8 out
    return "0x$out"
}

##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::maskToInt
#
# Purpose:
#        convert mask to integer
#
# Synopsis:
#       maskToInt <mask>
#
# Arguments:
#        <mask>
#            mask in either dotted form or mask length form (255.255.255.0 or 24)
#
# Return Values:
#        integer form of mask
#
# Description:
#
# Examples:
#   ::ip::maskToInt 24
#   4294967040
#
#
# Sample Input:
#
# Sample Output:

# Notes:
#
# See Also:
#
# End of Header

proc ::ip::maskToInt {mask} {
    if {[string is integer -strict $mask]} {
        set maskInt [expr {(0xFFFFFFFF << (32 - $mask))}]
    } else {
        binary scan [Normalize4 $mask] I maskInt
    }
    set maskInt [expr {$maskInt & 0xFFFFFFFF}]
    return [format %u $maskInt]
}

##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::broadcastAddress
#
# Purpose:
#        return broadcast address given prefix
#
# Synopsis:
#       broadcastAddress <prefix> [-ipv4]
#
# Arguments:
#        <prefix>
#            route in the form of <ipaddr>/<mask> or native form {<hexip> <hexmask>}
#        -ipv4
#            the provided native format addresses are in ipv4 format (default)
#            note: broadcast addresses are not valid in ipv6
#
#
# Return Values:
#        ipaddress of broadcast
#
# Description:
#
# Examples:
#   ::ip::broadcastAddress 1.1.1.0/24
#   1.1.1.255
#
#   ::ip::broadcastAddress {0x01010100 0xffffff00}
#   0x010101ff
#
# Sample Input:
#
# Sample Output:

# Notes:
#
# See Also:
#
# End of Header

proc ::ip::broadcastAddress {prefix args} {
    set ipv4 1
    while {[llength $args]} {
	switch -- [lindex $args 0] {
	    -ipv4 {set args [lrange $args 1 end]}
	    default {
		return -code error [msgcat::mc "option %s not supported" [lindex $args 0]]
	    }
	}
    }
    if {[llength $prefix] == 2} {
	lassign $prefix net mask
    } else {
	set net [maskToInt [ip::prefix $prefix]]
	set mask [maskToInt [ip::mask $prefix]]
    }
    set ba [expr {$net  | ((~$mask)&0xffffffff)}]

    if {[llength $prefix]==2} {
	return [format "0x%08x" $ba]
    }
    return [ToString [binary format I $ba]]
}

##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::maskToLength
#
# Purpose:
#        converts dotted or integer form of mask to length
#
# Synopsis:
#       maskToLength <dottedMask>|<integerMask>|<hexMask> [-ipv4]
#
# Arguments:
#        <dottedMask>
#        <integerMask>
#        <hexMask>
#            mask to convert to prefix length format (eg /24)
#         -ipv4
#            the provided integer/hex format masks are ipv4 (default)
#
# Return Values:
#        prefix length
#
# Description:
#
# Examples:
#   ::ip::maskToLength 0xffffff00 -ipv4
#   24
#
#   % ::ip::maskToLength 255.255.255.0
#   24
#
# Sample Input:
#
# Sample Output:
# Notes:
#
# See Also:
#
# End of Header

proc ::ip::maskToLength {mask args} {
    set ipv4 1
    while {[llength $args]} {
	switch -- [lindex $args 0] {
	    -ipv4 {set args [lrange $args 1 end]}
	    default {
		return -code error [msgcat::mc "option %s not supported" [lindex $args 0]]
	    }
	}
    }
    #pick the fastest method for either format
    if {[string is integer -strict $mask]} {
	binary scan [binary format I [expr {$mask}]] B32 maskB
	if {[regexp -all {^1+} $maskB ones]} {
	    return [string length $ones]
	} else {
	    return 0
	}
    } else {
	regexp {\/(.+)} $mask dumb mask
	set prefix 0
	foreach ipByte [split $mask {.}] {
	    switch $ipByte {
		255 {incr prefix 8; continue}
		254 {incr prefix 7}
		252 {incr prefix 6}
		248 {incr prefix 5}
		240 {incr prefix 4}
		224 {incr prefix 3}
		192 {incr prefix 2}
		128 {incr prefix 1}
		0   {}
		default {
		    return -code error [msgcat::mc "not an ip mask: %s" $mask]
		}
	    }
	    break
	}
	return $prefix
    }
}


##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::lengthToMask
#
# Purpose:
#        converts mask length to dotted mask form
#
# Synopsis:
#       lengthToMask <maskLength> [-ipv4]
#
# Arguments:
#        <maskLength>
#            mask length
#        -ipv4
#            the provided mask length is ipv4 (default)
#
# Return Values:
#        mask in dotted form
#
# Description:
#
# Examples:
#   ::ip::lengthToMask 24
#   255.255.255.0
#
# Sample Input:
#
# Sample Output:
# Notes:
#
# See Also:
#
# End of Header

proc ::ip::lengthToMask {masklen args} {
    while {[llength $args]} {
	switch -- [lindex $args 0] {
	    -ipv4 {set args [lrange $args 1 end]}
	    default {
		return -code error [msgcat::mc "option %s not supported" [lindex $args 0]]
	    }
	}
    }
    # the fastest method is just to look
    # thru an array
    return $::ip::maskLenToDotted($masklen)
}

##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::nextNet
#
# Purpose:
#        returns next an ipaddress in same position in next network
#
# Synopsis:
#       nextNet <ipaddr> <mask> [<count>] [-ipv4]
#
# Arguments:
#        <ipaddress>
#            in hex/integer/dotted format
#        <mask>
#            mask in hex/integer/dotted/maskLen format
#        <count>
#            number of nets to skip over (default is 1)
#        -ipv4
#            the provided hex/integer addresses are in ipv4 format (default)
#
# Return Values:
#        ipaddress in same position in next network in hex
#
# Description:
#
# Examples:
#
# Sample Input:
#
# Sample Output:
# Notes:
#
# See Also:
#
# End of Header

proc ::ip::nextNet {prefix mask args} {
    set count 1
    while {[llength $args]} {
	switch -- [lindex $args 0] {
	    -ipv4 {set args [lrange $args 1 end]}
	    default {
		set count [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	}
    }
    if {![string is integer -strict $prefix]} {
	set prefix [toInteger $prefix]
    }
    if {![string is integer -strict $mask] || ($mask < 33 && $mask > 0)} {
	set mask [maskToInt $mask]
    }
    set prefix [expr {$prefix + ((($mask ^ 0xFFffFFff) + 1) * $count) }]
    return [format "0x%08x" $prefix]
}


##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::isOverlap
#
# Purpose:
#        checks to see if prefixes overlap
#
# Synopsis:
#       isOverlap <prefix> <prefix1> <prefix2>...
#
# Arguments:
#        <prefix>
#            in form <ipaddr>/<mask> prefix to compare <prefixN> against
#        <prefixN>
#            in form <ipaddr>/<mask> prefixes to compare against
#
# Return Values:
#        1 if there is an overlap
#
# Description:
#
# Examples:
#        % ::ip::isOverlap 1.1.1.0/24 2.1.0.1/32
#        0
#
#        ::ip::isOverlap 1.1.1.0/24 2.1.0.1/32 1.1.1.1/32
#        1
# Sample Input:
#
# Sample Output:
# Notes:
#
# See Also:
#
# End of Header

proc ::ip::isOverlap {ip args} {
    lassign [SplitIp $ip] ip1 mask1
    set ip1int [toInteger $ip1]
    set mask1int [maskToInt $mask1]

    set overLap 0
    foreach prefix $args {
	lassign [SplitIp $prefix] ip2 mask2
	set ip2int [toInteger $ip2]
	set mask2int [maskToInt $mask2]
	set mask1mask2 [expr {$mask1int & $mask2int}]
	if {[expr {$ip1int & $mask1mask2}] ==  [expr {$ip2int & $mask1mask2}]} {
	    set overLap 1
	    break
	}
    }
    return $overLap
}


#optimized overlap, that accepts native format

##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::isOverlapNative
#
# Purpose:
#        checks to see if prefixes overlap (optimized native form)
#
# Synopsis:
#       isOverlap <hexipaddr> <hexmask> {{<hexipaddr1> <hexmask1>} {<hexipaddr2> <hexmask2>...}
#
# Arguments:
#        -all
#            return all overlaps rather than the first one
#        -inline
#            rather than returning index values, return the actual overlap prefixes
#        <hexipaddr>
#            ipaddress in hex/integer form
#        <hexMask>
#            mask in hex/integer form
#        -ipv4
#            the provided native format addresses are in ipv4 format (default)
#
# Return Values:
#        non-zero if there is an overlap, value is element # in list with overlap
#
# Description:
#        isOverlapNative is available both as a C extension and in a native tcl form
#        if the extension is loaded (tried automatically), isOverlapNative will be
#        linked to isOverlapNativeC. If an extension is not loaded, then isOverlapNative
#        will be linked to the native tcl proc: ipOverlapNativeTcl.
#
# Examples:
#        % ::ip::isOverlapNative 0x01010100 0xffffff00 {{0x02010001 0xffffffff}}
#        0
#
#        %::ip::isOverlapNative 0x01010100 0xffffff00 {{0x02010001 0xffffffff} {0x01010101 0xffffffff}}
#        2
#
# Sample Input:
#
# Sample Output:
# Notes:
#
# See Also:
#
# End of Header

proc ::ip::isOverlapNativeTcl {args} {
    set all 0
    set inline 0
    set notOverlap 0
    set ipv4 1
    foreach sw [lrange $args 0 end-3] {
	switch -exact -- $sw {
	    -all {
		set all 1
		set allList [list]
	    }
	    -inline {set inline 1}
	    -ipv4 {}
	}
    }
    set args [lassign [lrange $args end-2 end] ip1int mask1int prefixList]
    if {$inline} {
	set overLap [list]
    } else {
	set overLap 0
    }
    set count 0
    foreach prefix $prefixList {
	incr count
	lassign $prefix ip2int mask2int
	set mask1mask2 [expr {$mask1int & $mask2int}]
	if {[expr {$ip1int & $mask1mask2}] ==  [expr {$ip2int & $mask1mask2}]} {
	    if {$inline} {
		set overLap [list $prefix]
	    } else {
		set overLap $count
	    }
	    if {$all} {
		if {$inline} {
		    lappend allList $prefix
		} else {
		    lappend allList $count
		}
	    } else {
		break
	    }
	}
    }
    if {$all} {return $allList}
    return $overLap
}

##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::ipToLayer2Multicast
#
# Purpose:
#        converts ipv4 address to a layer 2 multicast address
#
# Synopsis:
#       ipToLayer2Multicast <ipaddr>
#
# Arguments:
#        <ipaddr>
#            ipaddress in dotted form
#
# Return Values:
#        mac address in xx.xx.xx.xx.xx.xx form
#
# Description:
#
# Examples:
#        % ::ip::ipToLayer2Multicast 224.0.0.2
#        01.00.5e.00.00.02
# Sample Input:
#
# Sample Output:
# Notes:
#
# See Also:
#
# End of Header

proc ::ip::ipToLayer2Multicast { ipaddr } {
    regexp "\[0-9\]+\.(\[0-9\]+)\.(\[0-9\]+)\.(\[0-9\]+)" $ipaddr junk ip2 ip3 ip4
    #remove MSB of 2nd octet of IP address for mcast L2 addr
    set mac2 [expr {$ip2 & 127}]
    return [format "01.00.5e.%02x.%02x.%02x" $mac2 $ip3 $ip4]
}


##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::ipHostFromPrefix
#
# Purpose:
#        gives back a host address from a prefix
#
# Synopsis:
#       ::ip::ipHostFromPrefix <prefix> [-exclude <list of prefixes>]
#
# Arguments:
#        <prefix>
#            prefix is <ipaddr>/<masklen>
#        -exclude <list of prefixes>
#            list if ipprefixes that host should not be in
# Return Values:
#        ip address
#
# Description:
#
# Examples:
# %::ip::ipHostFromPrefix  1.1.1.5/24
# 1.1.1.1
#
# %::ip::ipHostFromPrefix  1.1.1.1/32
# 1.1.1.1
#
#
# Sample Input:
#
# Sample Output:
# Notes:
#
# See Also:
#
# End of Header

proc ::ip::ipHostFromPrefix { prefix args } {
    set mask [mask $prefix]
    set ipaddr [prefix $prefix]
    if {[llength $args]} {
	array set opts $args
    } else {
	if {$mask==32} {
	    return $ipaddr
	} else {
	    return [intToString [expr {[toHex $ipaddr] + 1} ]]
	}
    }
    set format {-ipv4}
    # if we got here, then options were set
    if {[info exists opts(-exclude)]} {
	#basic algo is:
	# 1. throw away prefixes that are less specific that $prefix
	# 2. of remaining pfx, throw away prefixes that do not overlap
	# 3. run reducetoAggregates on specific nets
	# 4.

	# 1. convert to hex format
	set currHex [prefixToNative $prefix ]
	set exclHex [prefixToNative $opts(-exclude) ]
	# sort the prefixes by their mask, include the $prefix as a marker
	#  so we know from where to throw away prefixes
	set sortedPfx [lsort -integer -index 1 [concat [list $currHex]  $exclHex]]
	# throw away prefixes that are less specific than $prefix
	set specPfx [lrange $sortedPfx [expr {[lsearch -exact $sortedPfx $currHex] +1} ] end]

	#2. throw away non-overlapping prefixes
	set specPfx [isOverlapNative -all -inline \
			 [lindex $currHex 0 ] \
			 [lindex $currHex 1 ] \
			 $specPfx ]
	#3. run reduce aggregates
	set specPfx [reduceToAggregates $specPfx]

	#4 now have to pick an address that overlaps with $currHex but not with
	#   $specPfx
	# 4.1 find the largest prefix w/ most specific mask and go to the next net


	# current ats tcl does not allow this in one command, so
	#  for now just going to grab the last prefix (list is already sorted)
	set sPfx [lindex $specPfx end]
	set startPfx $sPfx
	# add currHex to specPfx
	set oChkPfx [concat $specPfx [list $currHex]]


	set notcomplete 1
	set overflow 0
	while {$notcomplete} {
	    #::ipMore::log::debug "doing nextnet on $sPfx"
	    set nextNet [nextNet [lindex $sPfx 0] [lindex $sPfx 1]]
	    #::ipMore::log::debug "trying $nextNet"
	    if {$overflow && ($nextNet > $startPfx)} {
		#we've gone thru the entire net and didn't find anything.
		return -code error [msgcat::mc "ip host could not be found in %s" $prefix]
		break
	    }
	    set oPfx [isOverlapNative -all -inline \
			  $nextNet -1 \
			  $oChkPfx
		     ]
	    switch -exact [llength $oPfx] {
		0 {
		    # no overlap at all. meaning we have gone beyond the bounds of
		    # $currHex. need to overlap and try again
		    #::ipMore::log::debug {ipHostFromPrefix: overlap done}
		    set overflow 1
		}
		1 {
		    #we've found what we're looking for. pick this address and exit
		    return [intToString $nextNet]
		}
		default {
		    # 2 or more overlaps, need to increment again
		    set sPfx [lindex $oPfx 0]
		}
	    }
	}
    }
}


##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::reduceToAggregates
#
# Purpose:
#        finds nets that overlap and filters out the more specifc nets
#
# Synopsis:
#       ::ip::reduceToAggregates <prefixList>
#
# Arguments:
#        <prefixList>
#            prefixList a list in the from of
#            is <ipaddr>/<masklen> or native format
#
# Return Values:
#        non-overlapping ip prefixes
#
# Description:
#
# Examples:
#
#  % ::ip::reduceToAggregates {1.1.1.0/24 1.1.0.0/8  2.1.1.0/24 1.1.1.1/32 }
#  1.0.0.0/8 2.1.1.0/24
#
# Sample Input:
#
# Sample Output:
# Notes:
#
# See Also:
#
# End of Header

proc ::ip::reduceToAggregates { prefixList } {
    #find out format of $prefixeList
    set dotConv 0
    if {[llength [lindex $prefixList 0]]==1} {
	#format is dotted form convert all prefixes to native form
	set prefixList [ip::prefixToNative $prefixList]
	set dotConv 1
    }

    set nonOverLapping $prefixList
    while {1==1} {
	set overlapFound 0
	set remaining $nonOverLapping
	set nonOverLapping {}
	while {[llength $remaining]} {
	    set current [lvarpop remaining]
	    set overLap [ip::isOverlapNative [lindex $current 0] [lindex $current 1] $remaining]
	    if {$overLap} {
		#there was a overlap find out which prefix has a the smaller mask, and keep that one
		if {[lindex $current 1] > [lindex [lindex $remaining [expr {$overLap -1}]] 1]} {
		    #current has more restrictive mask, throw that prefix away
		    # keep other prefix
		    lappend nonOverLapping [lindex $remaining [expr {$overLap -1}]]
		} else {
		    lappend nonOverLapping $current
		}
		lvarpop remaining [expr {$overLap -1}]
		set overlapFound 1
	    } else {
		#no overlap, keep all prefixes, don't touch the stuff in
		# remaining, it is needed for other overlap checking
		lappend nonOverLapping $current
	    }
	}
	if {$overlapFound==0} {break}
    }
    if {$dotConv} {return [nativeToPrefix $nonOverLapping]}
    return $nonOverLapping
}

##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::longestPrefixMatch
#
# Purpose:
#        given host IP finds longest prefix match from set of prefixes
#
# Synopsis:
#       ::ip::longestPrefixMatch <ipaddr> <prefixList> [-ipv4]
#
# Arguments:
#        <prefixList>
#            is list of <ipaddr> in native or dotted form
#        <ipaddr>
#            ip address in <ipprefix> format, dotted form, or integer form
#        -ipv4
#            the provided integer format addresses are in ipv4 format (default)
#
# Return Values:
#        <ipprefix> that is the most specific match to <ipaddr>
#
# Description:
#
# Examples:
#        % ::ip::longestPrefixMatch 1.1.1.1 {1.1.1.0/24 1.0.0.0/8  2.1.1.0/24 1.1.1.0/28 }
#        1.1.1.0/28
#
# Sample Input:
#
# Sample Output:
# Notes:
#
# See Also:
#
# End of Header

proc ::ip::longestPrefixMatch { ipaddr prefixList args} {
    set ipv4 1
    while {[llength $args]} {
	switch -- [lindex $args 0] {
	    -ipv4 {set args [lrange $args 1 end]}
	    default {
		return -code error [msgcat::mc "option %s not supported" [lindex $args 0]]
	    }
	}
    }
    #find out format of prefixes
    set dotConv 0
    if {[llength [lindex $prefixList 0]]==1} {
	#format is dotted form convert all prefixes to native form
	set prefixList [ip::prefixToNative $prefixList]
	set dotConv 1
    }
    #sort so that most specific prefix is in the front
    if {[llength [lindex [lindex $prefixList 0] 1]]} {
	set prefixList [lsort -decreasing -integer -index 1 $prefixList]
    } else {
	set prefixList [list $prefixList]
    }
    if {![string is integer -strict $ipaddr]} {
	set ipaddr [prefixToNative $ipaddr]
    }
    set best [ip::isOverlapNative -inline \
		  [lindex $ipaddr 0] [lindex $ipaddr 1] $prefixList]
    if {$dotConv && [llength $best]} {
	return [nativeToPrefix $best]
    }
    return $best
}

##Procedure Header
# Copyright (c) 2004 Cisco Systems, Inc.
#
# Name:
#       ::ip::cmpDotIP
#
# Purpose:
#        helper function for dotted ip address for use in lsort
#
# Synopsis:
#       ::ip::cmpDotIP <ipaddr1> <ipaddr2>
#
# Arguments:
#        <ipaddr1> <ipaddr2>
#            prefix is in dotted ip address format
#
# Return Values:
#        -1 if ipaddr1 is less that ipaddr2
#         1 if ipaddr1 is more that ipaddr2
#         0 if ipaddr1 and ipaddr2 are equal
#
# Description:
#
# Examples:
#        % lsort -command ip::cmpDotIP {1.0.0.0 2.2.0.0 128.0.0.0 3.3.3.3}
#        1.0.0.0 2.2.0.0 3.3.3.3 128.0.0.0
#
# Sample Input:
#
# Sample Output:
# Notes:
#
# See Also:
#
# End of Header
#            ip address in <ipprefix> format, dotted form, or integer form

if {![package vsatisfies [package provide Tcl] 8.4]} {
    # 8.3+
    proc ip::cmpDotIP {ipaddr1 ipaddr2} {
	# convert dotted to list of integers
	set ipaddr1 [split $ipaddr1 .]
	set ipaddr2 [split $ipaddr2 .]
	foreach a $ipaddr1 b $ipaddr2 {
	    #ipMore::log::debug "$ipInt1 $ipInt2"
	    if { $a < $b}  {
		return -1
	    } elseif {$a >$b} {
		return 1
	    }
	}
	return 0
    }
} else {
    # 8.4+
    proc ip::cmpDotIP {ipaddr1 ipaddr2} {
	# convert dotted to decimal
	set ipInt1 [::ip::toHex $ipaddr1]
	set ipInt2 [::ip::toHex $ipaddr2]
	#ipMore::log::debug "$ipInt1 $ipInt2"
	if { $ipInt1 < $ipInt2}  {
	    return -1
	} elseif {$ipInt1 >$ipInt2 } {
	    return 1
	} else {
	    return 0
	}
    }
}

# Populate the array "maskLenToDotted" for fast lookups of mask to
# dotted form.

namespace eval ::ip {
    variable maskLenToDotted
    variable x

    for {set x 0} {$x <33} {incr x} {
	set maskLenToDotted($x) [intToString [maskToInt $x]]
    }
    unset x
}

##Procedure Header
# Copyright (c) 2015 Martin Heinrich <martin.heinrich@frequentis.com>
#
# Name:
#       ::ip::distance
#
# Purpose:
#        Calculate integer distance between two IPv4 addresses (dotted form or int)
#
# Synopsis:
#       distance <ipaddr1> <ipaddr2>
#
# Arguments:
#        <ipaddr1>
#        <ipaddr2>
#            ip address
#
# Return Values:
#        integer distance (addr2 - addr1)
#
# Description:
#
# Examples:
#   % ::ip::distance 1.1.1.0 1.1.1.5
#   5
#
# Sample Input:
#
# Sample Output:

proc ::ip::distance {ip1 ip2} {
    # use package ip for normalization
    # XXX does not support ipv6
    expr {[toInteger $ip2]-[toInteger $ip1]}
}

##Procedure Header
# Copyright (c) 2015 Martin Heinrich <martin.heinrich@frequentis.com>
#
# Name:
#       ::ip::nextIp
#
# Purpose:
#        Increment the given IPv4 address by an offset.
#        Complement to 'distance'.
#
# Synopsis:
#       nextIp <ipaddr> ?<offset>?
#
# Arguments:
#        <ipaddr>
#            ip address
#
#        <offset>
#            The integer to increment the address by.
#            Default is 1.
#
# Return Values:
#        The increment ip address.
#
# Description:
#
# Examples:
#   % ::ip::nextIp 1.1.1.0 5
#   1.1.1.5
#
# Sample Input:
#
# Sample Output:

proc ::ip::nextIp {ip {offset 1}} {
    set int [toInteger $ip]
    incr int $offset
    set prot {}
    # TODO if ipv4 then set prot -ipv4, but
    # XXX intToString has -ipv4, but never returns ipv6
    intToString $int ;# 8.5-ism, avoid: {*}$prot
}
