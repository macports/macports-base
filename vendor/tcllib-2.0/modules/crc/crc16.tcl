# crc16.tcl -- Copyright (C) 2002, 2017 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# Cyclic Redundancy Check - this is a Tcl implementation of a general
# table-driven CRC implementation. This code should be able to generate
# the lookup table and implement the correct algorithm for most types
# of CRC. CRC-16, CRC-32 and the CCITT version of CRC-16. [1][2][3]
# Most transmission CRCs use the CCITT polynomial (including X.25, SDLC
# and Kermit).
#
# [1] http://www.microconsultants.com/tips/crc/crc.txt for the reference
#     implementation
# [2] http://www.embedded.com/internet/0001/0001connect.htm
#     for another good discussion of why things are the way they are.
# [3] "Numerical Recipes in C", Press WH et al. Chapter 20.
#
# Checks: a crc for the string "123456789" should give:
#   CRC16:     0xBB3D
#   CRC-CCITT: 0x29B1
#   XMODEM:    0x31C3
#   CRC-32:    0xCBF43926
#
# Additional CRCs from the bottom of
# http://reveng.sourceforge.net/crc-catalogue/all.htm
#
#   KERMIT:    0x2189
#   MODBUS:    0x4B37
#   MCRF4XX:   0x6F91
#   GENIBUS:   0xD64E
#   X.25:      0x906E
#   SDLC:      0x906E
#   USB:       0xB4C8
#   BUYPASS:   0xFEE8
#   UMTS:      0xFEE8		::crc::umts
#   GSM:       0xCE3C
#   UNKNOWN2:  0xDE76
#   MAXIM:     0x44C2
#   UNKNOWN3:  0x0117
#   UNKNOWN4:  0x5118
#   CMS:       0xAEE7
#
# eg: crc::crc16 "123456789"
#     crc::crc-ccitt "123456789"
# or  crc::crc16 -file tclsh.exe
#
# Note:
#  The CCITT CRC can very easily be checked for the accuracy of transmission
#  as the CRC of the message plus the CRC values will be 0. That is:
#   % set msg {123456789}
#   % set crc [crc::crc-ccitt $msg]
#   % crc::crc-ccitt $msg[binary format S $crc]
#   0
#
#  The same is true of other CRCs but some operate in reverse bit order:
#   % crc::crc16 $msg[binary format s [crc::crc16 $msg]]
#   0
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

# @mdgen EXCLUDE: crcc.tcl

package require Tcl 8.5 9;                # tcl minimum version

namespace eval ::crc {
    namespace export crc16 crc-ccitt crc-32

    # Standard CRC generator polynomials.
    variable polynomial
    set polynomial(crc16)     [expr {(1<<16) | (1<<15) | (1<<2) | 1}]
    set polynomial(ccitt)     [expr {(1<<16) | (1<<12) | (1<<5) | 1}]
    set polynomial(crc32)     [expr {(1<<32) | (1<<26) | (1<<23) | (1<<22)
                                     | (1<<16) | (1<<12) | (1<<11) | (1<<10)
                                     | (1<<8) | (1<<7) | (1<<5) | (1<<4)
                                     | (1<<2) | (1<<1) | 1}]
    set polynomial(kermit)    [expr {(1<<16) | (1<<12) | (1<<5) | 1}]
    set polynomial(modbus)    [expr {(1<<16) | (1<<15) | (1<<2) | 1}]
    set polynomial(mcrf4xx)   [expr {(1<<16) | (1<<12) | (1<<5) | 1}]
    set polynomial(genibus)   [expr {(1<<16) | (1<<12) | (1<<5) | 1}]
    set polynomial(x25)       [expr {(1<<16) | (1<<12) | (1<<5) | 1}]
    set polynomial(usb)       [expr {(1<<16) | (1<<15) | (1<<2) | 1}]
    set polynomial(buypass)   [expr {(1<<16) | (1<<15) | (1<<2) | 1}]
    set polynomial(gsm)       [expr {(1<<16) | (1<<12) | (1<<5) | 1}]
    set polynomial(unknown2)  [expr {(1<<16) | (1<<12) | (1<<5) | 1}]
    set polynomial(maxim)     [expr {(1<<16) | (1<<15) | (1<<2) | 1}]
    set polynomial(unknown3)  [expr {(1<<16) | (1<<15) | (1<<2) | 1}]
    set polynomial(unknown4)  [expr {(1<<16) | (1<<15) | (1<<2) | 1}]
    set polynomial(cms)       [expr {(1<<16) | (1<<15) | (1<<2) | 1}]

    # Array to hold the generated tables
    variable table
    if {![info exists table]} { array set table {}}

    # calculate the sign bit for the current platform.
    variable signbit
    if {![info exists signbit]} {
        if {[info exists ::tcl_platform(wordSize)]} {
            set signbit [expr {1 << (8*$::tcl_platform(wordSize)-1)}]
        } else {
            # Old Tcl. Find bit by shifting until wrap around to 0.
            # With int() result limited to system word size the loop will end.
            variable v
            for {set v 1} {int($v) != 0} {set signbit $v; set v [expr {$v<<1}]} {}
            unset v
        }
    }
}

# -------------------------------------------------------------------------
# Generate a CRC lookup table.
# This creates a CRC algorithm lookup table for a 'width' bits checksum
# using the 'poly' polynomial for all values of an input byte.
# Setting 'reflected' changes the bit order for input bytes.
# Returns a list or 255 elements.
#
# CRC-32:      Crc_table 32 $crc::polynomial(crc32)    1
# CRC-16:      Crc_table 16 $crc::polynomial(crc16)    1
# CRC16/CCITT: Crc_table 16 $crc::polynomial(ccitt)    0
# KERMIT:      Crc_table 16 $crc::polynomial(kermit)   1
# MODBUS:      Crc_table 16 $crc::polynomial(modbus)   1
# MCRF4XX:     Crc_table 16 $crc::polynomial(mcrf4xx)  1
# GENIBUS:     Crc_table 16 $crc::polynomial(genibus)  0
# X.25:        Crc_table 16 $crc::polynomial(x25)      1
# USB:         Crc_table 16 $crc::polynomial(usb)      1
# BUYPASS:     Crc_table 16 $crc::polynomial(buypass)  0
# GSM:         Crc_table 16 $crc::polynomial(gsm)      0
# UNKNOWN2:    Crc_table 16 $crc::polynomial(unknown2) 1
# MAXIM:       Crc_table 16 $crc::polynomial(maxim)    1
# UNKNOWN3:    Crc_table 16 $crc::polynomial(unknown3) 0
# UNKNOWN4:    Crc_table 16 $crc::polynomial(unknown4) 0
# CMS:         Crc_table 16 $crc::polynomial(cms)      0
#
proc ::crc::Crc_table {width poly reflected} {
    set tbl {}
    if {$width < 32} {
        set mask   [expr {(1 << $width) - 1}]
        set topbit [expr {1 << ($width - 1)}]
    } else {
        set mask   0xffffffff
        set topbit 0x80000000
    }

    for {set i 0} {$i < 256} {incr i} {
        if {$reflected} {
            set r [reflect $i 8]
        } else {
            set r $i
        }
        set r [expr {$r << ($width - 8)}]
        for {set k 0} {$k < 8} {incr k} {
            if {[expr {$r & $topbit}] != 0} {
                set r [expr {($r << 1) ^ $poly}]
            } else {
                set r [expr {$r << 1}]
            }
        }
        if {$reflected} {
            set r [reflect $r $width]
        }
        lappend tbl [expr {$r & $mask}]
    }
    return $tbl
}

# -------------------------------------------------------------------------
# Calculate the CRC checksum for the data in 's' using a precalculated
# table.
#  s the input data
#  width - the width in bits of the CRC algorithm
#  table - the name of the variable holding the calculated table
#  init  - the start value (or the last CRC for sequential blocks)
#  xorout - the final value may be XORd with this value
#  reflected - a boolean indicating that the bit order is reversed.
#              For hardware optimised CRC checks, the bits are handled
#              in transmission order (ie: bit0, bit1, ..., bit7)
proc ::crc::Crc {s width table {init 0} {xorout 0} {reflected 0}} {
    upvar $table tbl
    variable signbit
    set signmask [expr {~$signbit>>7}]

    if {$width < 32} {
        set mask   [expr {(1 << $width) - 1}]
        set rot    [expr {$width - 8}]
    } else {
        set mask   0xffffffff
        set rot    24
    }

    set crc $init
    binary scan $s c* data
    foreach {datum} $data {
        if {$reflected} {
            set ndx [expr {($crc ^ $datum) & 0xFF}]
            set lkp [lindex $tbl $ndx]
            set crc [expr {($lkp ^ ($crc >> 8 & $signmask)) & $mask}]
        } else {
            set ndx [expr {(($crc >> $rot) ^ $datum) & 0xFF}]
            set lkp [lindex $tbl $ndx]
            set crc [expr {($lkp ^ ($crc << 8 & $signmask)) & $mask}]
        }
    }

    return [expr {$crc ^ $xorout}]
}

# -------------------------------------------------------------------------
# Reverse the bit ordering for 'b' bits of the input value 'v'
proc ::crc::reflect {v b} {
    set t $v
    for {set i 0} {$i < $b} {incr i} {
        set v [expr {($t & 1) ? ($v | (1<<(($b-1)-$i))) : ($v & ~(1<<(($b-1)-$i))) }]
        set t [expr {$t >> 1}]
    }
    return $v
}

# -------------------------------------------------------------------------
# Description:
#  Pop the nth element off a list. Used in options processing.
#
proc ::crc::Pop {varname {nth 0}} {
    upvar $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the standard CRC16
# checksum
proc ::crc::CRC16 {s {seed 0}} {
    variable table
    if {![info exists table(crc16)]} {
        variable polynomial
        set table(crc16) [Crc_table 16 $polynomial(crc16) 1]
    }

    return [Crc $s 16 [namespace current]::table(crc16) $seed 0 1]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the CCITT telecoms
# flavour of the CRC16 checksum
proc ::crc::CRC-CCITT {s {seed 0} {xor 0}} {
    variable table
    if {![info exists table(ccitt)]} {
        variable polynomial
        set table(ccitt) [Crc_table 16 $polynomial(ccitt) 0]
    }

    return [Crc $s 16 [namespace current]::table(ccitt) $seed $xor 0]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the KERMIT
# flavour of the CRC16 checksum
proc ::crc::CRC-KERMIT {s {seed 0} {xor 0}} {
    variable table
    if {![info exists table(kermit)]} {
        variable polynomial
        # ::crc::Crc_table width poly reflected
        set table(kermit) [Crc_table 16 $polynomial(kermit) 1]
    }

    # ::crc::Crc s width table init xorout reflected
    return [Crc $s 16 [namespace current]::table(kermit) $seed $xor 1]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the MODBUS
# flavour of the CRC16 checksum
proc ::crc::CRC-MODBUS {s {seed 0xFFFF} {xor 0}} {
    variable table
    if {![info exists table(modbus)]} {
        variable polynomial
        # ::crc::Crc_table width poly reflected
        set table(modbus) [Crc_table 16 $polynomial(modbus) 1]
    }

    # ::crc::Crc s width table init xorout reflected
    return [Crc $s 16 [namespace current]::table(modbus) $seed $xor 1]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the MCRF4XX
# flavour of the CRC16 checksum
proc ::crc::CRC-MCRF4XX {s {seed 0xFFFF} {xor 0}} {
    variable table
    if {![info exists table(mcrf4xx)]} {
        variable polynomial
        # ::crc::Crc_table width poly reflected
        set table(mcrf4xx) [Crc_table 16 $polynomial(mcrf4xx) 1]
    }

    # ::crc::Crc s width table init xorout reflected
    return [Crc $s 16 [namespace current]::table(mcrf4xx) $seed $xor 1]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the GENIBUS
# flavour of the CRC16 checksum
proc ::crc::CRC-GENIBUS {s {seed 0xFFFF} {xor 0xFFFF}} {
    variable table
    if {![info exists table(genibus)]} {
        variable polynomial
        # ::crc::Crc_table width poly reflected
        set table(genibus) [Crc_table 16 $polynomial(genibus) 0]
    }

    # ::crc::Crc s width table init xorout reflected
    return [Crc $s 16 [namespace current]::table(genibus) $seed $xor 0]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the X25
# flavour of the CRC16 checksum
proc ::crc::CRC-X25 {s {seed 0xFFFF} {xor 0xFFFF}} {
    variable table
    if {![info exists table(x25)]} {
        variable polynomial
        # ::crc::Crc_table width poly reflected
        set table(x25) [Crc_table 16 $polynomial(x25) 1]
    }

    # ::crc::Crc s width table init xorout reflected
    return [Crc $s 16 [namespace current]::table(x25) $seed $xor 1]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the USB
# flavour of the CRC16 checksum
proc ::crc::CRC-USB {s {seed 0xFFFF} {xor 0xFFFF}} {
    variable table
    if {![info exists table(usb)]} {
        variable polynomial
        # ::crc::Crc_table width poly reflected
        set table(usb) [Crc_table 16 $polynomial(usb) 1]
    }

    # ::crc::Crc s width table init xorout reflected
    return [Crc $s 16 [namespace current]::table(usb) $seed $xor 1]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the BUYPASS
# flavour of the CRC16 checksum
proc ::crc::CRC-BUYPASS {s {seed 0} {xor 0}} {
    variable table
    if {![info exists table(buypass)]} {
        variable polynomial
        # ::crc::Crc_table width poly reflected
        set table(buypass) [Crc_table 16 $polynomial(buypass) 0]
    }

    # ::crc::Crc s width table init xorout reflected
    return [Crc $s 16 [namespace current]::table(buypass) $seed $xor 0]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the GSM
# flavour of the CRC16 checksum
proc ::crc::CRC-GSM {s {seed 0} {xor 0xFFFF}} {
    variable table
    if {![info exists table(gsm)]} {
        variable polynomial
        # ::crc::Crc_table width poly reflected
        set table(gsm) [Crc_table 16 $polynomial(gsm) 0]
    }

    # ::crc::Crc s width table init xorout reflected
    return [Crc $s 16 [namespace current]::table(gsm) $seed $xor 0]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the UNKNOWN-2
# flavour of the CRC16 checksum
proc ::crc::CRC-UNKNOWN2 {s {seed 0} {xor 0xFFFF}} {
    variable table
    if {![info exists table(unknown2)]} {
        variable polynomial
        # ::crc::Crc_table width poly reflected
        set table(unknown2) [Crc_table 16 $polynomial(unknown2) 1]
    }

    # ::crc::Crc s width table init xorout reflected
    return [Crc $s 16 [namespace current]::table(unknown2) $seed $xor 1]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the MAXIM
# flavour of the CRC16 checksum
proc ::crc::CRC-MAXIM {s {seed 0} {xor 0xFFFF}} {
    variable table
    if {![info exists table(maxim)]} {
        variable polynomial
        # ::crc::Crc_table width poly reflected
        set table(maxim) [Crc_table 16 $polynomial(maxim) 1]
    }

    # ::crc::Crc s width table init xorout reflected
    return [Crc $s 16 [namespace current]::table(maxim) $seed $xor 1]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the UNKNOWN-3
# flavour of the CRC16 checksum
proc ::crc::CRC-UNKNOWN3 {s {seed 0} {xor 0xFFFF}} {
    variable table
    if {![info exists table(unknown3)]} {
        variable polynomial
        # ::crc::Crc_table width poly reflected
        set table(unknown3) [Crc_table 16 $polynomial(unknown3) 0]
    }

    # ::crc::Crc s width table init xorout reflected
    return [Crc $s 16 [namespace current]::table(unknown3) $seed $xor 0]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the UNKNOWN-4
# flavour of the CRC16 checksum
proc ::crc::CRC-UNKNOWN4 {s {seed 0xFFFF} {xor 0xFFFF}} {
    variable table
    if {![info exists table(unknown4)]} {
        variable polynomial
        # ::crc::Crc_table width poly reflected
        set table(unknown4) [Crc_table 16 $polynomial(unknown4) 0]
    }

    # ::crc::Crc s width table init xorout reflected
    return [Crc $s 16 [namespace current]::table(unknown4) $seed $xor 0]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the CMS
# flavour of the CRC16 checksum
proc ::crc::CRC-CMS {s {seed 0xFFFF} {xor 0}} {
    variable table
    if {![info exists table(cms)]} {
        variable polynomial
        # ::crc::Crc_table width poly reflected
        set table(cms) [Crc_table 16 $polynomial(cms) 0]
    }

    # ::crc::Crc s width table init xorout reflected
    return [Crc $s 16 [namespace current]::table(cms) $seed $xor 0]
}

# -------------------------------------------------------------------------
# Demonstrates the parameters used for the 32 bit checksum CRC-32.
# This can be used to show the algorithm is working right by comparison with
# other crc32 implementations
proc ::crc::CRC-32 {s {seed 0xFFFFFFFF}} {
    variable table
    if {![info exists table(crc32)]} {
        variable polynomial
        set table(crc32) [Crc_table 32 $polynomial(crc32) 1]
    }

    return [Crc $s 32 [namespace current]::table(crc32) $seed 0xFFFFFFFF 1]
}

# -------------------------------------------------------------------------
# User level CRC command.
proc ::crc::crc {args} {
    array set opts [list filename {} channel {} chunksize 4096 \
                        format %u  seed 0 \
                        impl [namespace origin CRC16]]

    while {[string match -* [set option [lindex $args 0]]]} {
        switch -glob -- $option {
            -fi*  { set opts(filename) [Pop args 1] }
            -cha* { set opts(channel) [Pop args 1] }
            -chu* { set opts(chunksize) [Pop args 1] }
            -fo*  { set opts(format) [Pop args 1] }
            -i*   { set opts(impl) [uplevel 1 namespace origin [Pop args 1]] }
            -s*   { set opts(seed) [Pop args 1] }
            default {
                if {[llength $args] == 1} { break }
                if {[string compare $option "--"] == 0} { Pop args; break }
                set options [join [lsort [array names opts]] ", -"]
                return -code error "bad option $option:\
                       must be one of -$options or -- to indicate end of options"
            }
        }
        Pop args
    }

    if {$opts(filename) != {}} {
        set opts(channel) [open $opts(filename) r]
        fconfigure $opts(channel) -translation binary
    }

    if {$opts(channel) != {}} {
        set r $opts(seed)
        set trans [fconfigure $opts(channel) -translation]
        fconfigure $opts(channel) -translation binary
        while {![eof $opts(channel)]} {
            set chunk [read $opts(channel) $opts(chunksize)]
            set r [$opts(impl) $chunk $r]
        }
        fconfigure $opts(channel) -translation $trans
        if {$opts(filename) != {}} {
            close $opts(channel)
        }
    } else {
        if {[llength $args] != 1} {
            return -code error "wrong \# args: should be\
                   \"crc16 ?-format string? ?-seed value? ?-impl procname?\
                   -file name | -- data\""
        }
        set r [$opts(impl) [lindex $args 0] $opts(seed)]
    }
    return [format $opts(format) $r]
}

# -------------------------------------------------------------------------
# The user commands. See 'crc'
#
proc ::crc::crc16 {args} {
    return [eval [list crc -impl [namespace origin CRC16]] $args]
}

proc ::crc::crc-ccitt {args} {
    return [eval [list crc -impl [namespace origin CRC-CCITT] -seed 0xFFFF] $args]
}

proc ::crc::xmodem {args} {
    return [eval [list crc -impl [namespace origin CRC-CCITT] -seed 0] $args]
}

proc ::crc::crc-32 {args} {
    return [eval [list crc -impl [namespace origin CRC-32] -seed 0xFFFFFFFF] $args]
}

proc ::crc::kermit {args} {
    return [eval [list crc -impl [namespace origin CRC-KERMIT] -seed 0] $args]
}

proc ::crc::modbus {args} {
    return [eval [list crc -impl [namespace origin CRC-MODBUS] -seed 0xFFFF] $args]
}

proc ::crc::mcrf4xx {args} {
    return [eval [list crc -impl [namespace origin CRC-MCRF4XX] -seed 0xFFFF] $args]
}

proc ::crc::genibus {args} {
    return [eval [list crc -impl [namespace origin CRC-GENIBUS] -seed 0xFFFF] $args]
}

proc ::crc::crc-x25 {args} {
    return [eval [list crc -impl [namespace origin CRC-X25] -seed 0xFFFF] $args]
}

proc ::crc::crc-sdlc {args} {
    return [eval [list crc -impl [namespace origin CRC-X25] -seed 0xFFFF] $args]
}

proc ::crc::crc-usb {args} {
    return [eval [list crc -impl [namespace origin CRC-USB] -seed 0xFFFF] $args]
}

proc ::crc::buypass {args} {
    return [eval [list crc -impl [namespace origin CRC-BUYPASS] -seed 0] $args]
}

proc ::crc::umts {args} {
    return [eval [list crc -impl [namespace origin CRC-BUYPASS] -seed 0] $args]
}

proc ::crc::gsm {args} {
    return [eval [list crc -impl [namespace origin CRC-GSM] -seed 0] $args]
}

proc ::crc::unknown2 {args} {
    return [eval [list crc -impl [namespace origin CRC-UNKNOWN2] -seed 0] $args]
}

proc ::crc::maxim {args} {
    return [eval [list crc -impl [namespace origin CRC-MAXIM] -seed 0] $args]
}

proc ::crc::unknown3 {args} {
    return [eval [list crc -impl [namespace origin CRC-UNKNOWN3] -seed 0] $args]
}

proc ::crc::unknown4 {args} {
    return [eval [list crc -impl [namespace origin CRC-UNKNOWN4] -seed 0xFFFF] $args]
}

proc ::crc::cms {args} {
    return [eval [list crc -impl [namespace origin CRC-CMS] -seed 0xFFFF] $args]
}

# -------------------------------------------------------------------------

package provide crc16 1.1.5

# -------------------------------------------------------------------------
#
# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
