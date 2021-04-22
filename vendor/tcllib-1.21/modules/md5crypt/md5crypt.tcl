# md5crypt.tcl - Copyright (C) 2003 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# This file provides a pure tcl implementation of the BSD MD5 crypt algorithm.
# The implementation is based upon the OpenBSD code which is in turn based upon
# the original code by Poul-Henning Kamp. 
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------
# @mdgen EXCLUDE: md5cryptc.tcl

package require Tcl 8.2;                # tcl minimum version
package require md5 2;                  # tcllib 1.5

# Try and load a compiled extension to help.
if {[catch {package require tcllibc}]} {
    catch {package require md5cryptc}
}

namespace eval md5crypt {
    variable itoa64 \
        {./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz}

    namespace import -force ::md5::MD5Init ::md5::MD5Update ::md5::MD5Final
    namespace export md5crypt
}

proc ::md5crypt::to64_tcl {v n} {
    variable itoa64
    for {} {$n > 0} {incr n -1} {
        set i [expr {$v & 0x3f}]
        append s [string index $itoa64 $i]
        set v [expr {($v >> 6) & 0x3FFFFFFF}]
    }
    return $s
}

# ::md5crypt::salt --
#	Generate a salt string suitable for use with the md5crypt command.
proc ::md5crypt::salt {{len 8}} {
    variable itoa64
    set salt ""
    for {set n 0} {$n < $len} {incr n} {
        append salt [string index $itoa64 [expr {int(rand() * 64)}]]
    }
    return $salt
}

proc ::md5crypt::md5crypt_tcl {magic pw salt} {
    set sp 0

    set start 0
    if {[string match "${magic}*" $salt]} {
        set start [string length $magic]
    }
    set end [string first $ $salt $start]
    if {$end < 0} {set end [string length $salt]} else {incr end -1}
    if {$end - $start > 7} {set end [expr {$start + 7}]}
    set salt [string range $salt $start $end]

    set ctx [MD5Init]
    MD5Update $ctx $pw
    MD5Update $ctx $magic
    MD5Update $ctx $salt

    set ctx2 [MD5Init]
    MD5Update $ctx2 $pw
    MD5Update $ctx2 $salt
    MD5Update $ctx2 $pw
    set H2 [MD5Final $ctx2]

    for {set pl [string length $pw]} {$pl > 0} {incr pl -16} {
        set tl [expr {($pl > 16 ? 16 : $pl) - 1}]
        MD5Update $ctx [string range $H2 0 $tl]
    }
    
    for {set i [string length $pw]} {$i != 0} {set i [expr {$i >> 1}]} {
        if {$i & 1} {
            set c \0
        } else {
            set c [string index $pw 0]
        }
        MD5Update $ctx $c
    }
    
    set result "${magic}${salt}\$"
    
    set H [MD5Final $ctx]

    for {set i 0} {$i < 1000} {incr i} {
        set ctx [MD5Init]
        if {$i & 1} {
            MD5Update $ctx $pw
        } else {
            MD5Update $ctx $H
        }
        if {$i % 3} {
            MD5Update $ctx $salt
        }
        if {$i % 7} {
            MD5Update $ctx $pw
        }
        if {$i & 1} {
            MD5Update $ctx $H
        } else {
            MD5Update $ctx $pw
        }
        set H [MD5Final $ctx]
    }

    binary scan $H c* Vs
    foreach v $Vs {lappend V [expr {$v & 0xFF}]}
    set l [expr {([lindex $V 0] << 16) | ([lindex $V  6] << 8) | [lindex $V 12]}]
    append result [to64 $l 4]
    set l [expr {([lindex $V 1] << 16) | ([lindex $V  7] << 8) | [lindex $V 13]}]
    append result [to64 $l 4]
    set l [expr {([lindex $V 2] << 16) | ([lindex $V  8] << 8) | [lindex $V 14]}]
    append result [to64 $l 4]
    set l [expr {([lindex $V 3] << 16) | ([lindex $V  9] << 8) | [lindex $V 15]}]
    append result [to64 $l 4]
    set l [expr {([lindex $V 4] << 16) | ([lindex $V 10] << 8) | [lindex $V  5]}]
    append result [to64 $l 4]
    set l [expr {[lindex $V 11]}]
    append result [to64 $l 2]
    
    return $result
}

if {[info commands ::md5crypt::to64_c] == {}} {
    interp alias {} ::md5crypt::to64 {} ::md5crypt::to64_tcl
} else {
    interp alias {} ::md5crypt::to64 {} ::md5crypt::to64_c
}

if {[info commands ::md5crypt::md5crypt_c] == {}} {
    interp alias {} ::md5crypt::md5crypt {} ::md5crypt::md5crypt_tcl {$1$}
    interp alias {} ::md5crypt::aprcrypt {} ::md5crypt::md5crypt_tcl {$apr1$}
} else {
    interp alias {} ::md5crypt::md5crypt {} ::md5crypt::md5crypt_c {$1$}
    interp alias {} ::md5crypt::aprcrypt {} ::md5crypt::md5crypt_c {$apr1$}
}

# -------------------------------------------------------------------------

package provide md5crypt 1.1.0

# -------------------------------------------------------------------------
# Local Variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
