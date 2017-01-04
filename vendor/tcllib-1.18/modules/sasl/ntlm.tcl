# ntlm.tcl - Copyright (C) 2005 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# This is an implementation of Microsoft's NTLM authentication mechanism.
#
# References:
#    http://www.innovation.ch/java/ntlm.html
#    http://davenport.sourceforge.net/ntlm.html
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require Tcl 8.2;                # tcl minimum version
package require SASL 1.0;               # tcllib 1.7
package require des 1.0;                # tcllib 1.8
package require md4;                    # tcllib 1.4

namespace eval ::SASL {
    namespace eval NTLM {
        array set NTLMFlags {
            unicode        0x00000001
            oem            0x00000002
            req_target     0x00000004
            unknown        0x00000008
            sign           0x00000010
            seal           0x00000020
            datagram       0x00000040
            lmkey          0x00000080
            netware        0x00000100
            ntlm           0x00000200
            unknown        0x00000400
            unknown        0x00000800
            domain         0x00001000
            server         0x00002000
            share          0x00004000
            NTLM2          0x00008000
            targetinfo     0x00800000
            128bit         0x20000000
            keyexch        0x40000000
            56bit          0x80000000
        }
    }
}

# -------------------------------------------------------------------------

proc ::SASL::NTLM::NTLM {context challenge args} {
    upvar #0 $context ctx
    incr ctx(step)
    switch -exact -- $ctx(step) {
        
        1 {
            set ctx(realm) [eval [linsert $ctx(callback) end $context realm]]
            set ctx(hostname) [eval [linsert $ctx(callback) end $context hostname]]
            set ctx(response)   [CreateGreeting $ctx(realm) $ctx(hostname)]
            set result 1
        }

        2 {
            array set params [Decode $challenge]
            set user [eval [linsert $ctx(callback) end $context username]]
            set pass [eval [linsert $ctx(callback) end $context password]]
            if {[info exists params(domain)]} {
                set ctx(realm) $params(domain)
            }
            set ctx(response) [CreateResponse \
                                   $ctx(realm) $ctx(hostname) \
                                   $user $pass $params(nonce) $params(flags)]
            Decode $ctx(response)
            set result 0
        }
        default {
            return -code error "invalid state \"$ctx(step)"
        }
    }
    return $result
}

# -------------------------------------------------------------------------
# NTLM client implementation
# -------------------------------------------------------------------------

# The NMLM greeting. This is sent by the client to the server to initiate
# the challenge response handshake.
# This message contains the hostname (not domain qualified) and the 
# NT domain name for authentication.
#
proc ::SASL::NTLM::CreateGreeting {domainname hostname {flags {}}} {
    set domain [encoding convertto ascii $domainname]
    set host [encoding convertto ascii $hostname]
    set d_len [string length $domain]
    set h_len [string length $host]
    set d_off [expr {32 + $h_len}]
    if {![llength $flags]} {
        set flags {unicode oem ntlm server req_target}
    }
    set msg [binary format a8iississi \
                 "NTLMSSP\x00" 1 [Flags $flags] \
                 $d_len $d_len $d_off \
                 $h_len $h_len 32]
    append msg $host $domain
    return $msg
}

# Create a NTLM server challenge. This is sent by a server in response to
# a client type 1 message. The content of the type 2 message is variable
# and depends upon the flags set by the client and server choices.
#
proc ::SASL::NTLM::CreateChallenge {domainname} {
    SASL::md5_init
    set target  [encoding convertto ascii $domainname]
    set t_len   [string length $target]
    set nonce   [string range [binary format h* [SASL::CreateNonce]] 0 7]
    set pad     [string repeat \0 8]
    set context [string repeat \0 8]
    set msg [binary format a8issii \
                 "NTLMSSP\x00" 2 \
                 $t_len $t_len 48 \
                 [Flags {ntlm unicode}]]
    append msg $nonce $pad $context $pad $target
    return $msg
}

# Compose the final client response. This contains the encoded username
# and password, along with the server nonce value.
#
proc ::SASL::NTLM::CreateResponse {domainname hostname username passwd nonce flags} {
    set lm_resp [LMhash $passwd $nonce]
    set nt_resp [NThash $passwd $nonce]

    set domain  [string toupper $domainname]
    set host    [string toupper $hostname]
    set user    $username
    set unicode [expr {$flags & 0x00000001}]

    if {$unicode} {
      set domain [to_unicode_le $domain]
      set host   [to_unicode_le $host]
      set user   [to_unicode_le $user]
    }

    set l_len [string length $lm_resp]; # LM response length
    set n_len [string length $nt_resp]; # NT response length
    set d_len [string length $domain];  # Domain name length
    set h_len [string length $host];    # Host name length
    set u_len [string length $user];    # User name length
    set s_len 0 ;                       # Session key length

    # The offsets to strings appended to the structure
    set d_off [expr {0x40}];            # Fixed offset to Domain buffer
    set u_off [expr {$d_off + $d_len}]; # Offset to user buffer 
    set h_off [expr {$u_off + $u_len}]; # Offset to host buffer
    set l_off [expr {$h_off + $h_len}]; # Offset to LM hash
    set n_off [expr {$l_off + $l_len}]; # Offset to NT hash
    set s_off [expr {$n_off + $n_len}]; # Offset to Session key

    set msg [binary format a8is4s4s4s4s4s4i \
                 "NTLMSSP\x00" 3 \
                 [list $l_len $l_len $l_off 0] \
                 [list $n_len $n_len $n_off 0] \
                 [list $d_len $d_len $d_off 0] \
                 [list $u_len $u_len $u_off 0] \
                 [list $h_len $h_len $h_off 0] \
                 [list $s_len $s_len $s_off 0] \
                 $flags]
    append msg $domain $user $host $lm_resp $nt_resp
    return $msg
}

proc ::SASL::NTLM::Debug {msg} {
    array set d [Decode $msg]
    if {[info exists d(flags)]}  { 
        set d(flags) [list [format 0x%08x $d(flags)] [decodeflags $d(flags)]] 
    }
    if {[info exists d(nonce)]}  { set d(nonce) [base64::encode $d(nonce)] }
    if {[info exists d(lmhash)]} { set d(lmhash) [base64::encode $d(lmhash)] }
    if {[info exists d(nthash)]} { set d(nthash) [base64::encode $d(nthash)] }
    return [array get d]
}

proc ::SASL::NTLM::Decode {msg} {
    #puts [Debug $msg]
    binary scan $msg a7ci protocol zero type
    
    switch -exact -- $type {
        1 {
            binary scan $msg @12ississi flags dlen dlen2 doff hlen hlen2 hoff
            binary scan $msg @${hoff}a${hlen} host
            binary scan $msg @${doff}a${dlen} domain
            return [list type $type flags [format 0x%08x $flags] \
                        domain $domain host $host]
        }
        2 {
            binary scan $msg @12ssiia8a8 dlen dlen2 doff flags nonce pad
            set domain {}; binary scan $msg @${doff}a${dlen} domain
            set unicode [expr {$flags & 0x00000001}]
            if {$unicode} {
                set domain [from_unicode_le $domain]
            }

            binary scan $nonce H* nonce_h
            binary scan $pad   H* pad_h
            return [list type $type flags [format 0x%08x $flags] \
                        domain $domain nonce $nonce]
        }
        3 {
            binary scan $msg @12ssissississississii \
                lmlen lmlen2 lmoff \
                ntlen ntlen2 ntoff \
                dlen  dlen2  doff  \
                ulen  ulen2  uoff \
                hlen  hlen2  hoff \
                slen  slen2  soff \
                flags
            set domain {}; binary scan $msg @${doff}a${dlen} domain
            set user {};   binary scan $msg @${uoff}a${ulen} user
            set host {};   binary scan $msg @${hoff}a${hlen} host
            set unicode [expr {$flags & 0x00000001}]
            if {$unicode} {
                set domain [from_unicode_le $domain]
                set user   [from_unicode_le $user]
                set host   [from_unicode_le $host]
            }
            binary scan $msg @${ntoff}a${ntlen} ntdata
            binary scan $msg @${lmoff}a${lmlen} lmdata
            binary scan $ntdata H* ntdata_h
            binary scan $lmdata H* lmdata_h
            return [list type $type flags [format 0x%08x $flags]\
                        domain $domain host $host user $user \
                        lmhash $lmdata nthash $ntdata]
        }
        default {
            return -code error "invalid NTLM data: type not recognised"
        }
    }
}

proc ::SASL::NTLM::decodeflags {value} {
    variable NTLMFlags
    set result {}
    foreach {flag mask} [array get NTLMFlags] {
        if {$value & ($mask & 0xffffffff)} {
            lappend result $flag
        }
    }
    return $result
}

proc ::SASL::NTLM::Flags {flags} {
    variable NTLMFlags
    set result 0
    foreach flag $flags {
        if {![info exists NTLMFlags($flag)]} {
            return -code error "invalid ntlm flag \"$flag\""
        }
        set result [expr {$result | $NTLMFlags($flag)}]
    }
    return $result
}

# Convert a string to unicode in little endian byte order.
proc ::SASL::NTLM::to_unicode_le {str} {
    set result [encoding convertto unicode $str]
    if {[string equal $::tcl_platform(byteOrder) "bigEndian"]} {
        set r {} ; set n 0
        while {[binary scan $result @${n}cc a b] == 2} {
            append r [binary format cc $b $a]
            incr n 2
        }
        set result $r
    }
    return $result
}

# Convert a little-endian unicode string to utf-8.
proc ::SASL::NTLM::from_unicode_le {str} {
    if {[string equal $::tcl_platform(byteOrder) "bigEndian"]} {
        set r {} ; set n 0
        while {[binary scan $str @${n}cc a b] == 2} {
            append r [binary format cc $b $a]
            incr n 2
        }
        set str $r
    }
    return [encoding convertfrom unicode $str]
}

proc ::SASL::NTLM::LMhash {password nonce} {
    set magic "\x4b\x47\x53\x21\x40\x23\x24\x25"
    set hash ""
    set password [string range [string toupper $password][string repeat \0 14] 0 13]
    foreach key [CreateDesKeys $password] {
        append hash [DES::des -dir encrypt -weak -mode ecb -key $key $magic]
    }

    append hash [string repeat \0 5]
    set res ""
    foreach key [CreateDesKeys $hash] {
        append res [DES::des -dir encrypt -weak -mode ecb -key $key $nonce]
    }

    return $res
}

proc ::SASL::NTLM::NThash {password nonce} {
    set pass [to_unicode_le $password]
    set hash [md4::md4 $pass]
    append hash [string repeat \x00 5]

    set res ""
    foreach key [CreateDesKeys $hash] {
        append res [DES::des -dir encrypt -weak -mode ecb -key $key $nonce]
    }

    return $res
}

# Convert a password into a 56 bit DES key according to the NTLM specs.
# We do NOT fix the parity of each byte. If we did, then bit 0 of each
# byte should be adjusted to give the byte odd parity.
#
proc ::SASL::NTLM::CreateDesKeys {key} {
    # pad to 7 byte boundary with nuls.
    set mod [expr {[string length $key] % 7}]
    if {$mod != 0} {
        append key [string repeat "\0" [expr {7 - $mod}]]
    }
    set len [string length $key]
    set r ""
    for {set n 0} {$n < $len} {incr n 7} {
        binary scan $key @${n}c7 bytes
        set b {}
        lappend b [expr {  [lindex $bytes 0] & 0xFF}]
        lappend b [expr {(([lindex $bytes 0] & 0x01) << 7) | (([lindex $bytes 1] >> 1) & 0x7F)}]
        lappend b [expr {(([lindex $bytes 1] & 0x03) << 6) | (([lindex $bytes 2] >> 2) & 0x3F)}]
        lappend b [expr {(([lindex $bytes 2] & 0x07) << 5) | (([lindex $bytes 3] >> 3) & 0x1F)}]
        lappend b [expr {(([lindex $bytes 3] & 0x0F) << 4) | (([lindex $bytes 4] >> 4) & 0x0F)}]
        lappend b [expr {(([lindex $bytes 4] & 0x1F) << 3) | (([lindex $bytes 5] >> 5) & 0x07)}]
        lappend b [expr {(([lindex $bytes 5] & 0x3F) << 2) | (([lindex $bytes 6] >> 6) & 0x03)}]
        lappend b [expr {(([lindex $bytes 6] & 0x7F) << 1)}]
        lappend r [binary format c* $b]
    }
    return $r;
}

# This is slower than the above in Tcl 8.4.9
proc ::SASL::NTLM::CreateDesKeys2 {key} {
    # pad to 7 byte boundary with nuls.
    append key [string repeat "\0" [expr {7 - ([string length $key] % 7)}]]
    binary scan $key B* bin
    set len [string length $bin]
    set r ""
    for {set n 0} {$n < $len} {incr n} {
        append r [string range $bin $n [incr n  6]] 0
    }
    # needs spliting into 8 byte keys.
    return [binary format B* $r]
}

# -------------------------------------------------------------------------

# Register this SASL mechanism with the Tcllib SASL package.
#
if {[llength [package provide SASL]] != 0} {
    ::SASL::register NTLM 50 ::SASL::NTLM::NTLM
}

package provide SASL::NTLM 1.1.2

# -------------------------------------------------------------------------
#
# Local variables:
# indent-tabs-mode: nil
# End:
