# des.tcl - Copyright (C) 2005 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# Tcllib wrapper for the DES package. This wrapper provides the same 
# programming API that tcllib uses for AES and Blowfish. We require a
# DES implementation and use either TclDES or TclDESjr to get DES 
# and/or 3DES
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require Tcl 8.2

if {[catch {package require tclDES 1.0.0}]} {
    package require tclDESjr 1.0.0
}

namespace eval DES {
    variable uid
    if {![info exists uid]} { set uid 0 }
}

proc ::DES::Init {mode key iv {weak 0}} {
    variable uid
    set Key [namespace current]::[incr uid]
    upvar #0 $Key state
    if {[string length $key] % 8 != 0} {
        return -code error "invalid key length of\
             [expr {[string length $key] * 8}] bits:\
             DES requires 64 bit keys (56 bits plus parity bits)"
    }
    array set state [list M $mode I $iv K [des::keyset create $key $weak]]
    return $Key
}

proc ::DES::Encrypt {Key data} {
    upvar #0 $Key state
    set iv $state(I)
    set r [des::encrypt $state(K) $data $state(M) iv]
    set state(I) $iv
    return $r
}

proc ::DES::Decrypt {Key data} {
    upvar #0 $Key state
    set iv $state(I)
    set r [des::decrypt $state(K) $data $state(M) iv]
    set state(I) $iv
    return $r
}

proc ::DES::Reset {Key iv} {
    upvar #0 $Key state
    set state(I) $iv
    return
}

proc ::DES::Final {Key} {
    upvar #0 $Key state
    des::keyset destroy $state(K)
    # FRINK: nocheck
    unset $Key
}
# -------------------------------------------------------------------------

# Backwards compatability - here we re-implement the DES 0.8 procs using the
# current implementation.
#
# -- DO NOT USE THESE FUNCTIONS IN NEW CODE--
#
proc ::DES::GetKey {mode keydata keyvarname} {
    set weak 1
    switch -exact -- $mode {
        -encrypt    { set dir encrypt ; set vnc 0 }
        -encryptVNC { set dir encrypt ; set vnc 1 }
        -decrypt    { set dir decrypt ; set vnc 0 }
        -decryptVNC { set dir decrypt ; set vnc 1 }
        default {
            return -code error "invalid mode \"$mode\":\
                must be one of -encrypt, -decrypt, -encryptVNC or -decryptVNC"
        }
    }
    if {$vnc} { set keydata [ReverseBytes $keydata] }
    upvar $keyvarname Key
    set Key [Init ecb $keydata [string repeat \0 8] $weak]
    upvar $Key state
    array set state [list dir $dir]
    return
}

proc ::DES::DesBlock {data keyvarname} {
    upvar $keyvarname Key
    upvar #0 $Key state
    if {[string equal $state(dir) "encrypt"]} {
        set r [Encrypt $Key $data]
    } else {
        set r [Decrypt $Key $data]
    }
    return $r
}

proc ::DES::ReverseBytes {data} {
    binary scan $data b* bin
    return [binary format B* $bin]
}

# -------------------------------------------------------------------------

proc ::DES::SetOneOf {lst item} {
    set ndx [lsearch -glob $lst "${item}*"]
    if {$ndx == -1} {
        set err [join $lst ", "]
        return -code error "invalid mode \"$item\": must be one of $err"
    }
    return [lindex $lst $ndx]
}

proc ::DES::CheckSize {what size thing} {
    if {[string length $thing] != $size} {
        return -code error "invalid value for $what: must be $size bytes long"
    }
    return $thing
}

proc ::DES::Pad {data blocksize {fill \0}} {
    set len [string length $data]
    if {$len == 0} {
        set data [string repeat $fill $blocksize]
    } elseif {($len % $blocksize) != 0} {
        set pad [expr {$blocksize - ($len % $blocksize)}]
        append data [string repeat $fill $pad]
    }
    return $data
}

proc ::DES::Pop {varname {nth 0}} {
    upvar $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

proc ::DES::Hex {data} {
    binary scan $data H* r
    return $r 
}

proc ::DES::des {args} {
    array set opts {
        -dir encrypt -mode cbc -key {} -in {} -out {} -chunksize 4096 -hex 0 -weak 0 old 0
    }
    set blocksize 8
    set opts(-iv) [string repeat \0 $blocksize]
    set modes {ecb cbc cfb ofb}
    set dirs {encrypt decrypt}
    while {[string match -* [set option [lindex $args 0]]]} {
        switch -exact -- $option {
            -mode      { 
                set M [Pop args 1]
                if {[catch {set mode [SetOneOf $modes $M]} err]} {
                    if {[catch {SetOneOf {encode decode} $M}]} {
                        return -code error $err
                    } else {
                        # someone is using the old interface, therefore ecb
                        set mode ecb
                        set opts(-weak) 1
                        set opts(old) 1
                        set opts(-dir) [expr {[string match en* $M] ? "encrypt" : "decrypt"}]
                    }
                }
                set opts(-mode) $mode
            }
            -dir       { set opts(-dir) [SetOneOf $dirs [Pop args 1]] }
            -iv        { set opts(-iv) [Pop args 1] }
            -key       { set opts(-key) [Pop args 1] }
            -in        { set opts(-in) [Pop args 1] }
            -out       { set opts(-out) [Pop args 1] }
            -chunksize { set opts(-chunksize) [Pop args 1] }
            -hex       { set opts(-hex) 1 }
            -weak      { set opts(-weak) 1 }
            --         { Pop args ; break }
            default {
                set err [join [lsort [array names opts -*]] ", "]
                return -code error "bad option \"$option\":\
                    must be one of $err"
            }
        }
        Pop args
    }

    if {$opts(-key) == {}} {
        return -code error "no key provided: the -key option is required"
    }

    # pad the key if backwards compat required
    if {$opts(old)} {
        set pad [expr {8 - ([string length $opts(-key)] % 8)}]
        if {$pad != 8} {
            append opts(-key) [string repeat \0 $pad]
        }
    }

    set r {}
    if {$opts(-in) == {}} {

        if {[llength $args] != 1} {
            return -code error "wrong \# args:\
                should be \"des ?options...? -key keydata plaintext\""
        }

        set data [Pad [lindex $args 0] $blocksize]
        set Key [Init $opts(-mode) $opts(-key) $opts(-iv) $opts(-weak)]
        if {[string equal $opts(-dir) "encrypt"]} {
            set r [Encrypt $Key $data]
        } else {
            set r [Decrypt $Key $data]
        }

        if {$opts(-out) != {}} {
            puts -nonewline $opts(-out) $r
            set r {}
        }
        Final $Key

    } else {

        if {[llength $args] != 0} {
            return -code error "wrong \# args:\
                should be \"des ?options...? -key keydata -in channel\""
        }

        set Key [Init $opts(-mode) $opts(-key) $opts(-iv) $opts(-weak)]
        upvar $Key state
        set state(reading) 1
        if {[string equal $opts(-dir) "encrypt"]} {
            set state(cmd) Encrypt
        } else {
            set state(cmd) Decrypt
        }
        set state(output) ""
        fileevent $opts(-in) readable \
            [list [namespace origin Chunk] \
                 $Key $opts(-in) $opts(-out) $opts(-chunksize)]
        if {[info commands ::tkwait] != {}} {
            tkwait variable [subst $Key](reading)
        } else {
            vwait [subst $Key](reading)
        }
        if {$opts(-out) == {}} {
            set r $state(output)
        }
        Final $Key

    }

    if {$opts(-hex)} {
        set r [Hex $r]
    }
    return $r
}

# -------------------------------------------------------------------------

package provide des 1.1.0

# -------------------------------------------------------------------------
#
# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
