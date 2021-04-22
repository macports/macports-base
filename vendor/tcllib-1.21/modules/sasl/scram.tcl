# scram.tcl - Copyright (c) 2013 Sergei Golovan <sgolovan@nes.ru>
#
# This is an implementation of SCRAM-* SASL authentication
# mechanism (RFC-5802).
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require Tcl 8.2
package require SASL
package require sha1
package require base64

namespace eval ::SASL::SCRAM {}

# ::SASL::SCRAM::Map --
#
#       Map comma and equal sign to their codes in authzid and username
#       (section 5.1, a and n attributes)
#
# Arguments:
#       string      string subject to mapping
#
# Result:
#       The given string with , replaced by =2C and = replaced by =3D
#
# Side effects:
#       None
#
# Comment:
#       Since comma, equal sign, 2, C, 3, D are all in ASCII,
#       [encoding convertto utf-8 [Map]] gives the same result as
#       [Map [encoding convertto utf-8]], so the latter is used here
#       despite the former is correct formally

proc ::SASL::SCRAM::Map {string} {
    string map {, =2C = =3D} $string
}

# ::SASL::SCRAM::Unmap --
#
#       Replace codes =2C by , and =3D by = in authzid and username
#       (section 5.1, a and n attributes)
#
# Arguments:
#       string      authzid or username extracted from a challenge
#
# Result:
#       Mapped argument
#
# Side effects:
#       None
#
# Comment:
#       Since comma, equal sign, 2, C, 3, D are all in ASCII,
#       [encoding convertfrom utf-8 [Unmap]] gives the same result as
#       [Unmap [encoding convertfrom utf-8]], and the former is used here
#       despite the latter is correct formally

proc ::SASL::SCRAM::Unmap {string} {
    string map {=2C , =3D =} $string
}

# ::SASL::SCRAM::GS2Header --
#
#       Return GS2 header for SCRAM (section 7, gs2-header)
#
# Arguments:
#       authzid     authorization identity (empty if it's the same as username
#                   to authenticate)
#
# Result:
#       GS2 header for inclusion into a client messages
#
# Side effects:
#       None

proc ::SASL::SCRAM::GS2Header {authzid} {
    # n means that client doesn't support channel binding
    if {[string equal $authzid ""]} {
	return "n,,"
    } else {
	return "n,a=[Map $authzid],"
    }
}

# ::SASL::SCRAM::ClientFirstMessageBare --
#
#       Return the first client message without the GS2 header (section 7,
#       client-first-message-bare, without extensions)
#
# Arguments:
#       username    Username to authenticate
#       nonce       Random string of printable chars
#
# Result:
#       SCRAM client first message without GS2 header
#
# Side effects:
#       None

proc ::SASL::SCRAM::ClientFirstMessageBare {username nonce} {
    return "n=[Map $username],r=$nonce"
}

# ::SASL::SCRAM::ClientFirstMessage --
#
#       Return the first client message to be sent to a server (section 7,
#       client-first-message, without extensions)
#
# Arguments:
#       authzid     authorization identity (empty if it's the same as username
#                   to authenticate)
#       username    Username to authenticate
#       nonce       Random string of printable chars
#
# Result:
#       SCRAM client first message without GS2 header
#
# Side effects:
#       None

proc ::SASL::SCRAM::ClientFirstMessage {authzid username nonce} {
    return "[GS2Header $authzid][ClientFirstMessageBare $username $nonce]"
}

# ::SASL::SCRAM::ClientFinalMessageWithoutProof --
#
#       Return the final client message not including the client proof
#       (section 7, client-final-message-without-proof, without extensions).
#       Note that we don't support channel binding, so the GS2 header used
#       here is the same as in the first message. This message is used twice:
#       1) as part of auth-message which hash authenticates user, 2) as part
#       of the final message client sends to the server
#
# Arguments:
#       authzid     authorization identity (empty if it's the same as username
#                   to authenticate), must be the same as in the first message
#       nonce       Random string of printable chars, must be the one received
#                   from the server on step 1
#
# Result:
#       The final client message without proof
#
# Side effects:
#       None

proc ::SASL::SCRAM::ClientFinalMessageWithoutProof {authzid nonce} {
    # We still don't support channel binding, so just use [GS2Header]
    return "c=[base64::encode [GS2Header $authzid]],r=$nonce"
}

# ::SASL::SCRAM::ServerFirstMessage --
#
#       Return the server first message (section 7, server-first-message)
#
# Arguments:
#       nonce       Random string of printable chars, it must start with the
#                   random string received from the client at step 0
#       salt        Random binary string
#       iter        Number of iterations for salting password (required to be
#                   not less then 4096)
#
# Result:
#       The first server message
#
# Side effects:
#       None

proc ::SASL::SCRAM::ServerFirstMessage {nonce salt iter} {
    return "r=$nonce,s=[base64::encode $salt],i=$iter"
}

# ::SASL::SCRAM::ParseChallenge --
#
#       Parse client or server output string and return a list of attr-value,
#       suitable for [array set].  Channel binding part of GS2 header returns
#       as "cbind n", "cbind y" or "cbind p p <value>", other attributes
#       return simply as "<attr> <value>"
#
# Arguments:
#       challenge   Input string to parse
#
# Result:
#       List with even number of members
#
# Side effects:
#       None

proc ::SASL::SCRAM::ParseChallenge {challenge} {
    set attrval [split $challenge ,]
    set params {}
    set n 0
    foreach av $attrval {
        incr n
        if {$av == ""} continue

        if {[regexp {^([a-z])(?:=(.+))?$} $av -> attr val]} {
            if {$n == 1 && ($attr == "n" || $attr == "y")} {
                # Header (channel binding)
                lappend params cbind $attr
            } elseif {$n == 1 && $attr == "p"} {
                # Header (channel binding)
                lappend params cbind $attr $attr $val
            } else {
                lappend params $attr $val
            }
        } else {
            return -code error "invalid challenge"
        }
    }
    return $params
}

# ::SASL::SCRAM::Xor --
#
#       Return bitwize XOR between two strings of equal length
#
# Arguments:
#       str1        String to XOR
#       str2        String to XOR
#
# Result:
#       Bitwise XOR of the supplied strings or error if their lengths differ
#
# Side effects:
#       None

proc ::SASL::SCRAM::Xor {str1 str2} {
    set result ""
    foreach s1 [split $str1 ""] s2 [split $str2 ""] {
	append result [binary format c [expr {[scan $s1 %c] ^ [scan $s2 %c]}]]
    }
    return $result
}

# ::SASL::SCRAM::Hi --
#
#       Salt the given password using algorithm from section 2.2
#
# Arguments:
#       hmac        Function which calculates a Hashed Message Authentication
#                   digest (HMAC) described in RFC 2104 in binary form
#       password    Password to salt
#       salt        Random string used as a salt
#       i           Number of iterations (assumed i>=1)
#
# Result:
#       Salted password
#
# Side effects:
#       None

proc ::SASL::SCRAM::Hi {hmac password salt i} {
    set res [set ui [$hmac $password "$salt\x0\x0\x0\x1"]]
    for {set n 1} {$n < $i} {incr n} {
        set ui [$hmac $password $ui]
        set res [Xor $res $ui]
    }
    return $res
}

# ::SASL::SCRAM::Algo --
#
#       Return client proof and server signature according to SCRAM
#       algorithm from section 3.
#
# Arguments:
#       hash        Function which returns a cryptographic dugest in binary form
#       hmac        Function which calculates a Hashed Message Authentication
#                   digest (HMAC) described in RFC 2104 in binary form
#       password    User password
#       salt        Random string used as a salt
#       i           Number of iterations for password salting (assumed i>=1)
#       auth_message Message which is to be hashed to get client and server
#                    signatures
#
# Result:
#       List of two binaries with client proof and server signature
#
# Side effects:
#       None

proc ::SASL::SCRAM::Algo {hash hmac password salt i auth_message} {
    set salted_password [Hi $hmac $password $salt $i]
    set client_key [$hmac $salted_password "Client Key"]
    set stored_key [$hash $client_key]
    set client_signature [$hmac $stored_key $auth_message]
    set client_proof [Xor $client_key $client_signature]
    set server_key [$hmac $salted_password "Server Key"]
    set server_signature [$hmac $server_key $auth_message]
    return [list $client_proof $server_signature]
}

# ::SASL::SCRAM::client --
#
#       Perform authentication step of the client part of SCRAM SASL
#       procedure. It's an auxiliary procedure called from the callback
#       registered with the SASL package
#
# Arguments:
#       hash        Function which returns a cryptographic dugest in binary form
#       hmac        Function which calculates a Hashed Message Authentication
#                   digest (HMAC) described in RFC 2104 in binary form
#       context     Array name which contains authentication state (in particular
#                   step and response values)
#       challenge   Input from the server
#       args        Ignored rest of the arguments
#
# Result:
#       1 if authentication is to be continued, 0 if it is finished with
#       success, error if it is failed for some reason. ${context}(response)
#       contains data to be sent to the server
#
# Side effects:
#       The authzid, username, password are obtained using SASL callback.
#       Step 1 uses data from step 0, and step 2 uses data from step 1
#       (stored in the context array)
#
# Known bugs and limitations:
#       1) The authzid, username and password aren't saslprepped
#       2) There's no check for 'm' attribute (authentication must fail if it's
#          present)
#       3) There's no check if the server's nonce has the client's nonce as
#          a prefix

proc ::SASL::SCRAM::client {hash hmac context challenge args} {
    upvar #0 $context ctx

    switch -exact -- $ctx(step) {
	0 {
            # Initial message with username and random string

            # authzid and username will be used also at step 1, so store them
            set ctx(authzid) [encoding convertto utf-8 [eval $ctx(callback) [list $context login]]]
            set ctx(username) [encoding convertto utf-8 [eval $ctx(callback) [list $context username]]]
	    set ctx(nonce) [::SASL::CreateNonce]
	    set ctx(response) [ClientFirstMessage $ctx(authzid) $ctx(username) $ctx(nonce)]
	    incr ctx(step)
	    return 1
	}
	1 {
            # Final message with client proof calculated using the user's password

            array set params [ParseChallenge $challenge]
	    set password [encoding convertto utf-8 [eval $ctx(callback) [list $context password]]]
            set final_message [ClientFinalMessageWithoutProof $ctx(authzid) $params(r)]
            set auth_message "[ClientFirstMessageBare $ctx(username) $ctx(nonce)],$challenge,$final_message"
	    foreach {proof signature} [Algo $hash $hmac $password [base64::decode $params(s)] $params(i) $auth_message] break
            set ctx(signature) $signature
	    set ctx(response) "$final_message,p=[base64::encode $proof]"
	    incr ctx(step)
	    return 1
	}
	2 {
            # Check of the server's signature

            array set params [ParseChallenge $challenge]
            if {[info exists params(e)]} {
                return -code error $params(e)
            }
            if {![string equal $ctx(signature) [base64::decode $params(v)]]} {
                return -code error "invalid server signature"
            }
	    incr ctx(step)
            return 0

	}
	default {
	    return -code error "invalid state"
	}
    }
}

# ::SASL::SCRAM::server --
#
#       Perform authentication step of the server part of SCRAM SASL
#       procedure. It's an auxiliary procedure called from the callback
#       registered with the SASL package
#
# Arguments:
#       hash        Function which returns a cryptographic dugest in binary form
#       hmac        Function which calculates a Hashed Message Authentication
#                   digest (HMAC) described in RFC 2104 in binary form
#       context     Array name which contains authentication state (in particular
#                   step and response values)
#       clientrsp   Input from the client
#       args        Ignored rest of the arguments
#
# Result:
#       1 if authentication is to be continued, 0 if it is finished with
#       success, error if it is failed for some reason. ${context}(response)
#       contains data to be sent to the server
#
# Side effects:
#       The authentication realm and password are obtained using SASL callback.
#       Step 1 uses data from step 0 (stored in the context array)
#
# Known bugs and limitations:
#       1) The server part needs to know the user's password (which violates the
#          idea that server cannot impersonate client)
#       2) The username and password aren't saslprepped
#       3) There's no check for 'm' attribute (authentication must fail if it's
#          present)
#       4) There's no check if the encoded username contains unprotected =
#       5) The authzid support is not implemented
#       6) The channel binding option at step 1 is ignored

proc ::SASL::SCRAM::server {hash hmac context clientrsp args} {
    upvar #0 $context ctx

    switch -exact -- $ctx(step) {
	0 {
            if {[string length $clientrsp] == 0} {
                # Do not increase the step counter here and send an empty
                # challenge because SCRAM is a client-first mechanism (section
                # 5 of RFC-4422)
                set ctx(response) ""
                return 1
            }

            # Initial response with random string, salt and number of iterations

            array set params [ParseChallenge $clientrsp]
            if {![info exists params(cbind)]} {
                return -code error "invalid header"
            }
            if {$params(cbind) == "p"} {
                return -code error "channel binding is not supported"
            }

            set ctx(username) [encoding convertfrom utf-8 [Unmap $params(n)]]
            set ctx(salt)     [::SASL::CreateNonce]
            set ctx(nonce)    $params(r)[::SASL::CreateNonce]
            set ctx(iter)     4096

            # Store the bare client message for AuthMessage at step 1
            regexp {^[^,]*,[^,]*,(.*)} $clientrsp -> ctx(message)

	    set ctx(response) [ServerFirstMessage $ctx(nonce) $ctx(salt) $ctx(iter)]
	    incr ctx(step)
	    return 1
	}
	1 {
            # Verification of the client's proof and response with the
            # server's signature

            array set params [ParseChallenge $clientrsp]
            set realm [eval $ctx(callback) [list $context realm]]
            set password [encoding convertto utf-8 [eval $ctx(callback) [list $context password $ctx(username) $realm]]]

            # Remove proof to create AuthMessage
            regexp {(.*),p=[^,]*$} $clientrsp -> final_message
            set auth_message "$ctx(message),[ServerFirstMessage $ctx(nonce) $ctx(salt) $ctx(iter)],$final_message"
	    foreach {proof signature} [Algo $hash $hmac $password $ctx(salt) $ctx(iter) $auth_message] break
            if {![string equal $proof [base64::decode $params(p)]]} {
                return -code error "authentication failed"
            }
	    set ctx(response) "v=[base64::encode $signature]"
	    incr ctx(step)
	    return 0
	}
	default {
	    return -code error "invalid state"
	}
    }
}

# -------------------------------------------------------------------------
# Provide the mandatory SCRAM-SHA-1 mechanism

proc ::SASL::SCRAM::SHA-1:hash {str} {
    sha1::sha1 -bin $str
}

proc ::SASL::SCRAM::SHA-1:hmac {key str} {
    sha1::hmac -bin -key $key $str
}

proc ::SASL::SCRAM::SHA-1:client {context challenge args} {
    client ::SASL::SCRAM::SHA-1:hash ::SASL::SCRAM::SHA-1:hmac $context $challenge
}

proc ::SASL::SCRAM::SHA-1:server {context clientrsp args} {
    server ::SASL::SCRAM::SHA-1:hash ::SASL::SCRAM::SHA-1:hmac $context $clientrsp
}

# Register the SCRAM-SHA-1 SASL mechanism with the Tcllib SASL package

::SASL::register SCRAM-SHA-1 50 ::SASL::SCRAM::SHA-1:client ::SASL::SCRAM::SHA-1:server

# -------------------------------------------------------------------------

package provide SASL::SCRAM 0.1

# -------------------------------------------------------------------------
#
# Local variables:
# indent-tabs-mode: nil
# End:
# vim:ts=8:sw=4:sts=4:et
