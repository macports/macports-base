# rc4.tcl - Copyright (C) 2004 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# RC4 is a symmetric stream cipher developed by Ron Rivest of RSA Data
# Security Inc. The algorithm was a trade secret of RSA but was reverse
# engineered and published to the internet in 1994. This pure Tcl
# implementation is based on the description of the algorithm.
#
# The algorithm is a pseudo-random number generator with the output of
# the PRNG being xored with the plaintext stream. Decryption is done
# by feeding the ciphertext as input with the same key.

package require Tcl 8.2

# @mdgen EXCLUDE: rc4c.tcl

namespace eval ::rc4 {
    namespace export rc4

    variable uid
    if {![info exists uid]} {
        set uid 0
    }
}

# RC4Init - create and initialize the RC4 state as an array
#
proc ::rc4::RC4Init_Array {keystr} {
    variable uid

    binary scan $keystr c* key
    set keylen [llength $key]

    set Key [namespace current]::key[incr uid]
    # FRINK: nocheck
    variable $Key
    upvar #0 $Key state
    catch {unset state}

    set state(x) 0
    set state(y) 0
    for {set cn 0} {$cn < 256} {incr cn} {
        set state(s,$cn) $cn
    }
    set i 0
    set j 0
    for {set cn 0} {$cn < 256} {incr cn} {
        set j [expr {([lindex $key $i] + $state(s,$cn) + $j) % 256}]
        set t $state(s,$cn)
        set state(s,$cn) $state(s,$j)
        set state(s,$j) $t
        set i [expr {($i + 1) % $keylen}]
    }

    return $Key
}

# RC4 - process the data using the array based state
#
proc ::rc4::RC4_Array {Key datastr} {
    upvar #0 $Key state
    set res {}

    binary scan $datastr c* data
    set datalen [llength $data]
    
    set x $state(x)
    set y $state(y)

    for {set cn 0} {$cn < $datalen} {incr cn} {
        set x [expr {($x + 1) % 256}]
        set y [expr {($state(s,$x) + $y) % 256}]
        set t $state(s,$y)
        set state(s,$y) $state(s,$x)
        set state(s,$x) $t
        set i [expr {($state(s,$x) + $state(s,$y)) % 256}]
        lappend res [expr {([lindex $data $cn] ^ $state(s,$i)) & 0xFF}]
    }
    set state(x) $x
    set state(y) $y
    return [binary format c* $res]
}

# RC4Init - create and initialize the RC4 state as a list.
#
proc ::rc4::RC4Init_List {keystr} {
    variable uid

    binary scan $keystr c* key
    set keylen [llength $key]

    set Key [namespace current]::key[incr uid]
    # FRINK: nocheck
    variable $Key
    upvar #0 $Key State
    catch {unset State}

    set i 0
    set j 0
    set s {}; #[::struct::list::Liota 256]
    for {set n 0} {$n < 256} {incr n} {lappend s $n}
    
    for {set cn 0} {$cn < 256} {incr cn} {
        set j [expr {([lindex $key $i] + [lindex $s $cn] + $j) % 256}]
        set t [lindex $s $cn]
        lset s $cn [lindex $s $j]
        lset s $j $t
        set i [expr {($i + 1) % $keylen}]
    }
    
    set State(x) 0
    set State(y) 0
    set State(s) $s

    return $Key
}

# RC4 - process the data using the list-based state.
#
proc ::rc4::RC4_List {Key datastr} {
    upvar #0 $Key State
    set res {}

    binary scan $datastr c* data
    set datalen [llength $data]
    
    set x $State(x)
    set y $State(y)
    set s $State(s)

    for {set cn 0} {$cn < $datalen} {incr cn} {
        set x [expr {($x + 1) % 256}]
        set y [expr {([lindex $s $x] + $y) % 256}]
        set t [lindex $s $y]
        lset s $y [lindex $s $x]
        lset s $x $t
        set i [expr {([lindex $s $x] + [lindex $s $y]) % 256}]
        lappend res [expr {([lindex $data $cn] ^ [lindex $s $i]) & 0xFF}]
    }
    set State(x) $x
    set State(y) $y
    set State(s) $s
    return [binary format c* $res]
}

# PRAGMA: nocheck
proc ::rc4::K {x y} {set x}

# Using this compat function for < 8.4 is 2x slower than using arrays.
if {[package vcompare [package provide Tcl] 8.4] < 0} {
    proc ::rc4::lset {var index arg} {
        upvar 1 $var list
        set list [::lreplace [K $list [set list {}]] $index $index $arg]
    }
}

proc ::rc4::RC4Final {Key} {
    upvar #0 $Key state
    catch {unset state}
    return {}
}

# -------------------------------------------------------------------------
# Helper to turn binary data into hex format.
#
proc ::rc4::Hex {data} {
    binary scan $data H* result
    return $result
}

# Demo function for use with Trf transform command to add automatic
# RC4 encryption to a channel. Illustrates use of [transform]
#
# For instance, to create a file with all ondisk data encrypted:
#   set f [open secretfile r+]
#   transform -attach $f -command [list rc4::Transform $f Secret]
#   puts -nonewline $f yourdata   ;# write to encrypt
#   read $f                       ;# read to decrypt
#   close $f
#
proc ::rc4::Transform {channel keystr operation data} {
    set readkey [namespace current]::R$channel
    # FRINK: nocheck
    variable $readkey
    upvar #0 $readkey rk
    set writekey [namespace current]::W$channel
    # FRINK: nocheck
    variable $writekey
    upvar #0 $writekey wk
    set result {}

    #puts stderr "$operation {$data}"
    switch -- $operation {
        create/write {
            if {[info exists wk]} {
                RCFinal $wk
            }
            set wk [RC4Init $keystr] 
        }
        clear/write {}
        delete/write {
            if {[info exists wk]} {
                RC4Final $wk
                unset wk
            }
        }
        write - flush/write {
            if {![info exists wk]} {
                set wk [RC4Init $keystr]
            }
            set result [RC4 $wk $data] 
        }

        create/read {
            if {[info exists rk]} {
                RCFinal $rk
            }
            set rk [RC4Init $keystr] 
        }
        clear/read {}
        delete/read {
            if {[info exists rk]} {
                RC4Final $rk
                unset rk
            }
        }
        read - flush/read {
            if {![info exists rk]} {
                set rk [RC4Init $keystr]
            }
            set result [RC4 $rk $data] 
        }
        
        query/ratio {
            set result {1 1};           # RC4 is a 1:1 stream cipher.
        }
        query/maxRead {
            set result -1;              # Permit read of any amount
        }
        default {
            # ignore unknown operations.
        }
    }
    return $result
}

# -------------------------------------------------------------------------
# Description:
#  Pop the nth element off a list. Used in options processing.
#
proc ::rc4::Pop {varname {nth 0}} {
    upvar $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

# -------------------------------------------------------------------------
# Fileevent handler for chunked file hashing.
#
proc ::rc4::Chunk {State} {
    upvar #0 $State state
    
    if {[eof $state(-in)]} {
        fileevent $state(-in) readable {}
        set state(reading) 0
    }
    set data [read $state(-in) $state(-chunksize)]
    if {[llength $state(-out)] == 0} {
        append state(output) [RC4 $state(Key) $data]
    } else {
        puts -nonewline $state(-out) [RC4 $state(Key) $data]
    }
    if {!$state(reading) && [llength $state(-command)] != 0} {
        Cleanup $State; # cleanup and call users command 
    }
}


proc ::rc4::Cleanup {State} {
    upvar #0 $State state
    set cmd $state(-command)
    set res $state(output)
    # If we opened the channel then we should close it too.
    if {[string length $state(-infile)] > 0} {
        close $state(-in)
    }
    RC4Final $state(Key)
    unset state
    if {[llength $cmd] != 0} {
        eval $cmd [list $res]
    }
    return $res
}

# -------------------------------------------------------------------------

proc ::rc4::rc4 {args} {
    array set opts {-hex 0 -infile {} -in {} -out {} -chunksize 4096
        -key {} -command {}}
    while {[string match -* [set option [lindex $args 0]]]} {
        switch -exact -- $option {
            -key        { set opts(-key) [Pop args 1] }
            -hex        { set opts(-hex) 1}
            -infile     { set opts(-infile) [Pop args 1] }
            -in         { set opts(-in) [Pop args 1] }
            -out        { set opts(-out) [Pop args 1] }
            -chunksize  { set opts(-chunksize) [Pop args 1] }
            -command    { set opts(-command) [Pop args 1] }
            default {
                if {[llength $args] == 1} { break }
                if {[string compare $option "--"] == 0} { Pop args; break }
                set err [join [lsort [array names opts]] ", "]
                return -code error "bad option $option:\
                    must be one of $err"
            }
        }
        Pop args
    }

    if {[string length $opts(-key)] < 1} {
        return -code error "wrong # args:\
            should be \"rc4 ?-hex? -key key -in channel | string\""
    }

    if {$opts(-infile) != {}} {
        set opts(-in) [open $opts(-infile) r]
        fconfigure $opts(-in) -translation binary
    }

    set r {}
    if {$opts(-in) == {}} {
        if {[llength $args] != 1} {
            return -code error "wrong # args:\
                should be \"rc4 ?-hex? -key key -in channel | string\""
        }

        set Key [RC4Init $opts(-key)]
        set r [RC4 $Key [lindex $args 0]]
        if {[llength $opts(-command)] != 0} {
            eval $opts(-command) [list $r]
            set r {}
        } elseif {$opts(-out) != {}} {
            puts -nonewline $opts(-out) $r
            set r {}
        }
        RC4Final $Key

    } else {

        variable uid
        set State [namespace current]::state[incr uid]
        upvar #0 $State state
        array set state [array get opts]
        set state(Key) [RC4Init $opts(-key)]
        set state(reading) 1
        set state(output) ""
        fileevent $opts(-in) readable [list [namespace origin Chunk] $State]
        if {[llength $opts(-command)] != 0} {
            return {}
        } else {
            vwait [set State](reading)
            set r [Cleanup $State]
        }
    }

    if {$opts(-hex)} {
        set r [Hex $r]
    }
    return $r
}

# -------------------------------------------------------------------------

proc ::rc4::SelectImplementation {impl} {
    switch -exact -- $impl {
        critcl {
            interp alias {} ::rc4::RC4Init {} ::rc4::rc4c_init
            interp alias {} ::rc4::RC4     {} ::rc4::rc4c
        }
        array {
            interp alias {} ::rc4::RC4Init {} ::rc4::RC4Init_Array
            interp alias {} ::rc4::RC4     {} ::rc4::RC4_Array
        }
        list {
            interp alias {} ::rc4::RC4Init {} ::rc4::RC4Init_List
            interp alias {} ::rc4::RC4     {} ::rc4::RC4_List
        }
        default {
            return -code error "invalid implementation \"$impl\":\
                must be one of \"critcl\", \"array\" or \"list\""
        }
    }
}

# -------------------------------------------------------------------------

# Using a list to hold the keystream state is a lot faster than using
# an array. However, for Tcl < 8.4 we don't have the lset command.
# Using a compatability lset is slower than using arrays.
# Obviously, a compiled C version is fastest of all.
# So lets pick the fastest method we can find...
#
namespace eval ::rc4 {
    if {[catch {package require tcllibc}]} {
        catch {package require rc4c}
    }
    if {[info commands ::rc4::rc4c] != {}} {
        SelectImplementation critcl
    } elseif {[package vcompare [package provide Tcl] 8.4] < 0} {
        SelectImplementation array
    } else {
        SelectImplementation list
    }
}

package provide rc4 1.1.0

# -------------------------------------------------------------------------
# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
