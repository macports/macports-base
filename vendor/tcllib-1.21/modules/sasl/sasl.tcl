# sasl.tcl - Copyright (C) 2005 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# This is an implementation of a general purpose SASL library for use in
# Tcl scripts. 
#
# References:
#    Myers, J., "Simple Authentication and Security Layer (SASL)", 
#      RFC 2222, October 1997.
#    Rose, M.T., "TclSASL", "http://beepcore-tcl.sourceforge.net/tclsasl.html"
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require Tcl 8.2

namespace eval ::SASL {
    variable uid
    if {![info exists uid]} { set uid 0 }

    variable mechanisms
    if {![info exists mechanisms]} {
        set mechanisms [list]
    }
}

# SASL::mechanisms --
#
#	Return a list of available SASL mechanisms. By default only the
#	client implementations are given but if type is set to server then
#	the list of available server mechanisms is returned.
#	No mechanism with a preference value less than 'minimum' will be
#	returned.
#	The list is sorted by the security preference with the most secure
#	mechanisms given first.
#
proc ::SASL::mechanisms {{type client} {minimum 0}} {
    variable mechanisms
    set r [list]
    foreach mech $mechanisms {
        if {[lindex $mech 0] < $minimum} { continue }
        switch -exact -- $type {
            client {
                if {[string length [lindex $mech 2]] > 0} {
                    lappend r [lindex $mech 1]
                }
            }
            server {
                if {[string length [lindex $mech 3]] > 0} {
                    lappend r [lindex $mech 1]
                }
            }
            default {
                return -code error "invalid type \"$type\":\
                    must be either client or server"
            }
        }
    }
    return $r
}

# SASL::register --
#
#	Register a new SASL mechanism with a security preference. Higher
#	preference values are chosen before lower valued mechanisms.
#	If no server implementation is available then an empty string 
#	should be provided for the serverproc parameter.
#
proc ::SASL::register {mechanism preference clientproc {serverproc {}}} {
    variable mechanisms
    set ndx [lsearch -regexp $mechanisms $mechanism]
    set mech [list $preference $mechanism $clientproc $serverproc]
    if {$ndx == -1} {
        lappend mechanisms $mech
    } else {
        set mechanisms [lreplace $mechanisms $ndx $ndx $mech]
    }
    set mechanisms [lsort -index 0 -decreasing -integer $mechanisms]
    return
}

# SASL::uid --
#
#	Return a unique integer.
#
proc ::SASL::uid {} {
    variable uid
    return [incr uid]
}

# SASL::response --
#
#	Get the reponse string from the SASL state.
#
proc ::SASL::response {context} {
    upvar #0 $context ctx
    return $ctx(response)
}

# SASL::reset --
#
#	Reset the SASL state. This permits the same instance to be reused
#	for a new round of authentication.
#
proc ::SASL::reset {context {step 0}} {
    upvar #0 $context ctx
    array set ctx [list step $step response "" valid false count 0]
    return $context
}

# SASL::cleanup --
#
#	Free any resources used with the SASL state.
#
proc ::SASL::cleanup {context} {
    if {[info exists $context]} {
        unset $context
    }
    return
}

# SASL::new --
#
#	Create a new SASL instance. 
#
proc ::SASL::new {args} {
    set context [namespace current]::[uid]
    upvar #0 $context ctx
    array set ctx [list mech {} callback {} proc {} service smtp server {} \
                       step 0 response "" valid false type client count 0]
    eval [linsert $args 0 [namespace origin configure] $context]
    return $context
}

# SASL::configure --
#
#	Configure the SASL state.
#
proc ::SASL::configure {context args} {
    variable mechanisms
    upvar #0 $context ctx
    while {[string match -* [set option [lindex $args 0]]]} {
        switch -exact -- $option {
            -service {
                set ctx(service) [Pop args 1]
            }
            -server - -serverFQDN {
                set ctx(server) [Pop args 1]
            }
            -mech - -mechanism {
                set mech [string toupper [Pop args 1]]
                set ctx(proc) {}
                foreach m $mechanisms {
                    if {[string equal [lindex $m 1] $mech]} {
                        set ctx(mech) $mech
                        if {[string equal $ctx(type) "server"]} {
                            set ctx(proc) [lindex $m 3]
                        } else {
                            set ctx(proc) [lindex $m 2]
                        }
                        break
                    }
                }
                if {[string equal $ctx(proc) {}]} {
                    return -code error "mechanism \"$mech\" not available:\
                        must be one of those given by \[sasl::mechanisms\]"
                }
            }
            -callback - -callbacks {
                set ctx(callback) [Pop args 1]
            }
            -type {
                set type [Pop args 1]
                if {[lsearch -exact {server client} $type] != -1} {
                    set ctx(type) $type
                    if {![string equal $ctx(mech) ""]} {
                        configure $context -mechanism $ctx(mech)
                    }
                } else {
                    return -code error "bad value \"$type\":\
                        must be either client or server"
                }
            }
            default {
                return -code error "bad option \"$option\":\
                    must be one of -mechanism, -service, -server -type\
                    or -callbacks"
            }
        }
        Pop args
    }
        
}

proc ::SASL::step {context challenge args} {
    upvar #0 $context ctx
    incr ctx(count)
    return [eval [linsert $args 0 $ctx(proc) $context $challenge]]
}


proc ::SASL::Pop {varname {nth 0}} {
    upvar $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

proc ::SASL::md5_init {} {
    variable md5_inited
    if {[info exists md5_inited]} {return} else {set md5_inited 1}
    # Deal with either version of md5. We'd like version 2 but someone
    # may have already loaded version 1.
    set md5major [lindex [split [package require md5] .] 0]
    if {$md5major < 2} {
        # md5 v1, no options, and returns a hex string ready for us.
        proc ::SASL::md5_hex {data} { return [::md5::md5 $data] }
        proc ::SASL::md5_bin {data} { return [binary format H* [::md5::md5 $data]] }
        proc ::SASL::hmac_hex {pass data} { return [::md5::hmac $pass $data] }
        proc ::SASL::hmac_bin {pass data} { return [binary format H* [::md5::hmac $pass $data]] }
    } else {
        # md5 v2 requires -hex to return hash as hex-encoded non-binary string.
        proc ::SASL::md5_hex {data} { return [string tolower [::md5::md5 -hex $data]] }
        proc ::SASL::md5_bin {data} { return [::md5::md5 $data] }
        proc ::SASL::hmac_hex {pass data} { return [::md5::hmac -hex -key $pass $data] }
        proc ::SASL::hmac_bin {pass data} { return [::md5::hmac -key $pass $data] }
    }
}

# -------------------------------------------------------------------------

# CRAM-MD5 SASL MECHANISM
#
# 	Implementation of the Challenge-Response Authentication Mechanism
#	(RFC2195).
#
# Comments:
#	This mechanism passes a server generated string containing
#	a timestamp and has the client generate an MD5 HMAC using the
#	shared secret as the key and the server string as the data.
#	The downside of this protocol is that the server must have access
#	to the plaintext password.
#
proc ::SASL::CRAM-MD5:client {context challenge args} {
    upvar #0 $context ctx
    md5_init
    if {$ctx(step) != 0} {
        return -code error "unexpected state: CRAM-MD5 has only 1 step"
    }
    if {[string length $challenge] == 0} {
        set ctx(response) ""
        return 1
    }
    set password [eval $ctx(callback) [list $context password]]
    set username [eval $ctx(callback) [list $context username]]
    set reply [hmac_hex $password $challenge]
    set reply "$username [string tolower $reply]"
    set ctx(response) $reply
    incr ctx(step)
    return 0
}

proc ::SASL::CRAM-MD5:server {context clientrsp args} {
    upvar #0 $context ctx
    md5_init
    incr ctx(step)
    switch -exact -- $ctx(step) {
        1 {
            set ctx(realm) [eval $ctx(callback) [list $context realm]]
            set ctx(response) "<[pid].[clock seconds]@$ctx(realm)>"
            return 1
        }
        2 {
            foreach {user hash} $clientrsp break
            set hash [string tolower $hash]
            set pass [eval $ctx(callback) [list $context password $user $ctx(realm)]]
            set check [hmac_bin $pass $ctx(response)]
            binary scan $check H* cx
            if {[string equal $cx $hash]} {
                return 0
            } else {
                return -code error "authentication failed"
            }
        }
        default {
            return -code error "invalid state"
        }
    }
}

::SASL::register CRAM-MD5 30 ::SASL::CRAM-MD5:client ::SASL::CRAM-MD5:server

# -------------------------------------------------------------------------
# PLAIN SASL MECHANISM
#
# 	Implementation of the single step login SASL mechanism (RFC2595).
#
# Comments:
#	A single step mechanism in which the authorization ID, the
#	authentication ID and password are all transmitted in plain
#	text. This should not be used unless the channel is secured by
#	some other means (such as SSL/TLS).
#
proc ::SASL::PLAIN:client {context challenge args} {
    upvar #0 $context ctx
    incr ctx(step)
    set authzid  [eval $ctx(callback) [list $context login]]
    set username [eval $ctx(callback) [list $context username]]
    set password [eval $ctx(callback) [list $context password]]
    set ctx(response) "$authzid\x00$username\x00$password"
    return 0
}

proc ::SASL::PLAIN:server {context clientrsp args} {
    upvar \#0 $context ctx
    if {[string length $clientrsp] < 1} {
        set ctx(response) ""
        return 1
    } else {
        foreach {authzid authid pass} [split $clientrsp \0] break
        set realm [eval $ctx(callback) [list $context realm]]
        set check [eval $ctx(callback) [list $context password $authid $realm]]
        if {[string equal $pass $check]} {
            return 0
        } else {
            return -code error "authentication failed"
        }
    }
}

::SASL::register PLAIN 10 ::SASL::PLAIN:client ::SASL::PLAIN:server

# -------------------------------------------------------------------------
# LOGIN SASL MECHANISM
#
# 	Implementation of the two step login SASL mechanism.
#
# Comments:
#	This is an unofficial but widely deployed SASL mechanism somewhat
#	akin to the PLAIN mechanism. Both the authentication ID and password
#	are transmitted in plain text in response to server prompts.
#
#	NOT RECOMMENDED for use in new protocol implementations.
#
proc ::SASL::LOGIN:client {context challenge args} {
    upvar #0 $context ctx
    if {$ctx(step) == 0 && [string length $challenge] == 0} {
        set ctx(response) ""
        return 1
    }
    incr ctx(step)
    switch -exact -- $ctx(step) {
        1 {
            set ctx(response) [eval $ctx(callback) [list $context username]]
            set r 1
        }
        2 {
            set ctx(response) [eval $ctx(callback) [list $context password]]
            set r 0
        }
        default {
            return -code error "unexpected state \"$ctx(step)\":\
                LOGIN has only 2 steps"
        }
    }
    return $r
}

proc ::SASL::LOGIN:server {context clientrsp args} {
    upvar #0 $context ctx
    incr ctx(step)
    switch -exact -- $ctx(step) {
        1 {
            set ctx(response) "Username:"
            return 1
        }
        2 {
            set ctx(username) $clientrsp
            set ctx(response) "Password:"
            return 1
        }
        3 {
            set user $ctx(username)
            set realm [eval $ctx(callback) [list $context realm]]
            set pass [eval $ctx(callback) [list $context password $user $realm]]
            if {[string equal $clientrsp $pass]} {
                return 0
            } else {
                return -code error "authentication failed"
            }
        }
        default {
            return -code error "invalid state"
        }
    }
}

::SASL::register LOGIN 20 ::SASL::LOGIN:client ::SASL::LOGIN:server

# -------------------------------------------------------------------------
# ANONYMOUS SASL MECHANISM
#
# 	Implementation of the ANONYMOUS SASL mechanism (RFC2245).
#
# Comments:
#
# 
proc ::SASL::ANONYMOUS:client {context challenge args} {
    upvar #0 $context ctx
    set user  [eval $ctx(callback) [list $context username]]
    set realm [eval $ctx(callback) [list $context realm]]
    set ctx(response) $user@$realm
    return 0
}

proc ::SASL::ANONYMOUS:server {context clientrsp args} {
    upvar #0 $context ctx
    set ctx(response) ""
    if {[string length $clientrsp] < 1} {
        if {$ctx(count) > 2} {
            return -code error "authentication failed"
        }
        return 1
    } else {
        set ctx(trace) $clientrsp
        return 0
    }
}

::SASL::register ANONYMOUS 5 ::SASL::ANONYMOUS:client ::SASL::ANONYMOUS:server

# -------------------------------------------------------------------------

# DIGEST-MD5 SASL MECHANISM
#
# 	Implementation of the DIGEST-MD5 SASL mechanism (RFC2831).
#
# Comments:
#
proc ::SASL::DIGEST-MD5:client {context challenge args} {
    upvar #0 $context ctx
    md5_init
    if {$ctx(step) == 0 && [string length $challenge] == 0} {
        if {[info exists ctx(challenge)]} {
            set challenge $ctx(challenge)
        } else {
            set ctx(response) ""
            return 1
        }
    }
    incr ctx(step)
    set result 0
    switch -exact -- $ctx(step) {
        1 {
            set ctx(challenge) $challenge
            array set params [DigestParameters $challenge]
            
            if {![info exists ctx(noncecount)]} {
                set ctx(noncecount) 0
            }
            set nonce $params(nonce)
            set cnonce [CreateNonce]
            set noncecount [format %08u [incr ctx(noncecount)]]
            set qop auth
            
            # support the 'charset' parameter.
            set username [eval $ctx(callback) [list $context username]]
            set password [eval $ctx(callback) [list $context password]]
            set encoding iso8859-1
            if {[info exists params(charset)]} {
                set encoding $params(charset)
            }
            set username [encoding convertto $encoding $username]
            set password [encoding convertto $encoding $password]

            if {[info exists params(realm)]} {
                set realm $params(realm)
            } else {
                set realm [eval $ctx(callback) [list $context realm]]
            }
            
            set uri "$ctx(service)/$realm"
            set R [DigestResponse $username $realm $password $uri \
                       $qop $nonce $noncecount $cnonce]
            
            set ctx(response) "username=\"$username\",realm=\"$realm\",nonce=\"$nonce\",nc=\"$noncecount\",cnonce=\"$cnonce\",digest-uri=\"$uri\",response=\"$R\",qop=$qop"
            if {[info exists params(charset)]} {
                append ctx(response) ",charset=$params(charset)"
            }
            set result 1
        }
        
        2 {
            set ctx(response) ""
            set result 0
        }
        default {
            return -code error "invalid state"
        }
    }
    return $result
}

proc ::SASL::DIGEST-MD5:server {context challenge args} {
    upvar #0 $context ctx
    md5_init
    incr ctx(step)
    set result 0
    switch -exact -- $ctx(step) {
        1 {
            set realm [eval $ctx(callback) [list $context realm]]
            set ctx(nonce) [CreateNonce]
            set ctx(nc) 0
            set ctx(response) "realm=\"$realm\",nonce=\"$ctx(nonce)\",qop=\"auth\",charset=utf-8,algorithm=md5-sess"
            set result 1
        }
        2 {
            array set params [DigestParameters $challenge]
            set realm [eval $ctx(callback) [list $context realm]]
            set password [eval $ctx(callback)\
                              [list $context password $params(username) $realm]]
            set uri "$ctx(service)/$realm"
            set nc [format %08u [expr {$ctx(nc) + 1}]]
            set R [DigestResponse $params(username) $realm $password \
                       $uri auth $ctx(nonce) $nc $params(cnonce)]
            if {[string equal $R $params(response)]} {
                set R2 [DigestResponse $params(username) $realm $password \
                        $uri auth $ctx(nonce) $nc $params(cnonce)]
                set ctx(response) "rspauth=$R2"
                incr ctx(nc)
                set result 1
            } else {
                return -code error "authentication failed"
            }
        }
        3 {
            set ctx(response) ""
            set result 0
        }
        default {
            return -code error "invalid state"
        }
    }
    return $result
}

# RFC 2831 2.1
# Char categories as per spec...
# Build up a regexp for splitting the challenge into key value pairs.
proc ::SASL::DigestParameters {challenge} {
    set sep "\\\]\\\[\\\\()<>@,;:\\\"\\\?=\\\{\\\} \t"
    set tok {0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\-\|\~\!\#\$\%\&\*\+\.\^\_\`}
    set sqot {(?:\'(?:\\.|[^\'\\])*\')}
    set dqot {(?:\"(?:\\.|[^\"\\])*\")}
    set parameters {}
    regsub -all "(\[${tok}\]+)=(${dqot}|(?:\[${tok}\]+))(?:\[${sep}\]+|$)" $challenge {\1 \2 } parameters
    return $parameters
}

# RFC 2831 2.1.2.1
#
proc ::SASL::DigestResponse {user realm pass uri qop nonce noncecount cnonce} {
    set A1 [md5_bin "$user:$realm:$pass"]
    set A2 "AUTHENTICATE:$uri"
    if {![string equal $qop "auth"]} {
        append A2 :[string repeat 0 32]
    }
    set A1h [md5_hex "${A1}:$nonce:$cnonce"]
    set A2h [md5_hex $A2]
    set R   [md5_hex $A1h:$nonce:$noncecount:$cnonce:$qop:$A2h]
    return $R
}

# RFC 2831 2.1.2.2
#
proc ::SASL::DigestResponse2 {user realm pass uri qop nonce noncecount cnonce} {
    set A1 [md5_bin "$user:$realm:$pass"]
    set A2 ":$uri"
    if {![string equal $qop "auth"]} {
        append A2 :[string repeat 0 32]
    }
    set A1h [md5_hex "${A1}:$nonce:$cnonce"]
    set A2h [md5_hex $A2]
    set R   [md5_hex $A1h:$nonce:$noncecount:$cnonce:$qop:$A2h]
    return $R
}

# Get 16 random bytes for a nonce value. If we can use /dev/random, do so
# otherwise we hash some values.
#
proc ::SASL::CreateNonce {} {
    set bytes {}
    if {[file readable /dev/urandom]} {
        catch {
            set f [open /dev/urandom r]
            fconfigure $f -translation binary -buffering none
            set bytes [read $f 16]
            close $f
        }
    }
    if {[string length $bytes] < 1} {
        md5_init
        set bytes [md5_bin [clock seconds]:[pid]:[expr {rand()}]]
    }
    return [binary scan $bytes h* r; set r]
}

::SASL::register DIGEST-MD5 40 \
    ::SASL::DIGEST-MD5:client ::SASL::DIGEST-MD5:server

# -------------------------------------------------------------------------

# OTP SASL MECHANISM
#
# 	Implementation of the OTP SASL mechanism (RFC2444).
#
# Comments:
#
#	RFC 2289: A One-Time Password System
#	RFC 2444: OTP SASL Mechanism
#	RFC 2243: OTP Extended Responses
#	Client initializes with authid\0authzid
#	Server responds with extended OTP responses 
# 	eg: otp-md5 498 bi32123 ext
#	Client responds with otp result as:
#	 hex:xxxxxxxxxxxxxxxx
# 	or
#	 word:WWWW WWW WWWW WWWW WWWW
#
#	To support changing the otp sequence the extended commands have:
#	  init-hex:<current>:<new params>:<new>
#	eg: init-hex:xxxxxxxxxxxx:md5 499 seed987:xxxxxxxxxxxxxx
#	or init-word

proc ::SASL::OTP:client {context challenge args} {
    upvar #0 $context ctx
    package require otp
    incr ctx(step)
    switch -exact -- $ctx(step) {
        1 {
            set authzid  [eval $ctx(callback) [list $context login]]
            set username [eval $ctx(callback) [list $context username]]
            set ctx(response) "$authzid\x00$username"
            set cont 1
        }
        2 {
            foreach {type count seed ext} $challenge break
            set type [lindex [split $type -] 1]
            if {[lsearch -exact {md4 md5 sha1 rmd160} $type] == -1} {
                return -code error "unsupported digest algorithm \"$type\":\
                    must be one of md4, md5, sha1 or rmd160"
            }
            set challenge [lrange $challenge 3 end]
            set password [eval $ctx(callback) [list $context password]]
            set otp [::otp::otp-$type -word -seed $seed \
                         -count $count $password]
            if {[string match "ext*" $ext]} {
                set otp word:$otp
            }
            set ctx(response) $otp
            set cont 0
        }
        default {
            return -code error "unexpected state \"$ctx(step)\":\
               the SASL OTP mechanism only has 2 steps"
        }
    }
    return $cont
}

::SASL::register OTP 45 ::SASL::OTP:client

# -------------------------------------------------------------------------

package provide SASL 1.3.3

# -------------------------------------------------------------------------
#
# Local variables:
#   indent-tabs-mode: nil
# End:
