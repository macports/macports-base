#-----------------------------------------------------------------------------
#   Copyright (C) 1999-2004 Jochen C. Loewer (loewerj@web.de)
#   Copyright (C) 2006      Michael Schlenker (mic42@users.sourceforge.net)
#-----------------------------------------------------------------------------
#
#   A (partial) LDAPv3 protocol implementation in plain Tcl.
#
#   See RFC 4510 and ASN.1 (X.680) and BER (X.690).
#
#
#   This software is copyrighted by Jochen C. Loewer (loewerj@web.de). The
#   following terms apply to all files associated with the software unless
#   explicitly disclaimed in individual files.
#
#   The authors hereby grant permission to use, copy, modify, distribute,
#   and license this software and its documentation for any purpose, provided
#   that existing copyright notices are retained in all copies and that this
#   notice is included verbatim in any distributions. No written agreement,
#   license, or royalty fee is required for any of the authorized uses.
#   Modifications to this software may be copyrighted by their authors
#   and need not follow the licensing terms described here, provided that
#   the new terms are clearly indicated on the first page of each file where
#   they apply.
#
#   IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY
#   FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
#   ARISING OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY
#   DERIVATIVES THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE
#   POSSIBILITY OF SUCH DAMAGE.
#
#   THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
#   INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE
#   IS PROVIDED ON AN "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE
#   NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
#   MODIFICATIONS.
#
#   written by Jochen Loewer
#   3 June, 1999
#
#-----------------------------------------------------------------------------

package require Tcl 8.5
package require asn 0.7
package provide ldap 1.10.1

namespace eval ldap {

    namespace export    connect secure_connect  \
			starttls                \
			tlsoptions              \
                        disconnect              \
                        bind unbind             \
                        bindSASL                \
                        search                  \
                        searchInit           	\
		        searchNext	        \
		        searchEnd		\
                        modify                  \
                        modifyMulti             \
                        add                     \
		        addMulti		\
                        delete                  \
                        modifyDN		\
		        info

    namespace import ::asn::*

    variable doDebug

    # Valid TLS procotol versions
    variable tlsProtocols [list -tls1 yes -tls1.1 yes -tls1.2 yes]

    set doDebug 0

    # LDAP result codes from the RFC
    variable resultCode2String
    array set resultCode2String {
         0  success
         1  operationsError
         2  protocolError
         3  timeLimitExceeded
         4  sizeLimitExceeded
         5  compareFalse
         6  compareTrue
         7  authMethodNotSupported
         8  strongAuthRequired
        10  referral
        11  adminLimitExceeded
        12  unavailableCriticalExtension
        13  confidentialityRequired
        14  saslBindInProgress
        16  noSuchAttribute
        17  undefinedAttributeType
        18  inappropriateMatching
        19  constraintViolation
        20  attributeOrValueExists
        21  invalidAttributeSyntax
        32  noSuchObject
        33  aliasProblem
        34  invalidDNSyntax
        35  isLeaf
        36  aliasDereferencingProblem
        48  inappropriateAuthentication
        49  invalidCredentials
        50  insufficientAccessRights
        51  busy
        52  unavailable
        53  unwillingToPerform
        54  loopDetect
        64  namingViolation
        65  objectClassViolation
        66  notAllowedOnNonLeaf
        67  notAllowedOnRDN
        68  entryAlreadyExists
        69  objectClassModsProhibited
        80  other
    }

    # TLS options for secure_connect and starttls
    # (see tcltls documentation, function tls::import)
    variable validTLSOptions
    set validTLSOptions {
	-cadir
	-cafile
	-certfile
	-cipher
	-command
	-dhparams
	-keyfile
	-model
	-password
	-request
	-require
	-server
	-servername
	-ssl2
	-ssl3
	-tls1
	-tls1.1
	-tls1.2
    }

    # Default TLS options for secure_connect and starttls
    variable defaultTLSOptions
    array set defaultTLSOptions {
	-request 1
	-require 1
	-ssl2    no
	-ssl3    no
	-tls1	 yes
	-tls1.1	 yes
	-tls1.2	 yes
    }

    variable curTLSOptions
    array set curTLSOptions [array get defaultTLSOptions]

    # are we using the old interface (TLSMode = "compatible") or the
    # new one (TLSMode = "integrated")
    variable TLSMode
    set TLSMode "compatible"
}


#-----------------------------------------------------------------------------
#    Lookup an numerical ldap result code and return a string version
#
#-----------------------------------------------------------------------------
proc ::ldap::resultCode2String {code} {
    variable resultCode2String
    if {[::info exists resultCode2String($code)]} {
	    return $resultCode2String($code)
    } else {
	    return "unknownError"
    }
}

#-----------------------------------------------------------------------------
#   Basic sanity check for connection handles
#   must be an array
#-----------------------------------------------------------------------------
proc ::ldap::CheckHandle {handle} {
    if {![array exists $handle]} {
        return -code error \
            [format "Not a valid LDAP connection handle: %s" $handle]
    }
}

#-----------------------------------------------------------------------------
#    info
#
#-----------------------------------------------------------------------------

proc ldap::info {args} {
   set cmd [lindex $args 0]
   set cmds {connections bound bounduser control extensions features ip saslmechanisms tls whoami}
   if {[llength $args] == 0} {
   	return -code error \
		"Usage: \"info subcommand ?handle?\""
   }
   if {[lsearch -exact $cmds $cmd] == -1} {
   	return -code error \
		"Invalid subcommand \"$cmd\", valid commands are\
		[join [lrange $cmds 0 end-1] ,] and [lindex $cmds end]"
   }
   eval [linsert [lrange $args 1 end] 0 ldap::info_$cmd]
}

#-----------------------------------------------------------------------------
#    get the ip address of the server we connected to
#
#-----------------------------------------------------------------------------
proc ldap::info_ip {args} {
   if {[llength $args] != 1} {
   	return -code error \
	       "Wrong # of arguments. Usage: ldap::info ip handle"
   }
   CheckHandle [lindex $args 0]
   upvar #0 [lindex $args 0] conn
   if {![::info exists conn(sock)]} {
   	return -code error \
		"\"[lindex $args 0]\" is not a ldap connection handle"
   }
   return [lindex [fconfigure $conn(sock) -peername] 0]
}

#-----------------------------------------------------------------------------
#   get the list of open ldap connections
#
#-----------------------------------------------------------------------------
proc ldap::info_connections {args} {
   if {[llength $args] != 0} {
   	return -code error \
	       "Wrong # of arguments. Usage: ldap::info connections"
   }
   return [::info vars ::ldap::ldap*]
}

#-----------------------------------------------------------------------------
#   check if the connection is bound
#
#-----------------------------------------------------------------------------
proc ldap::info_bound {args} {
   if {[llength $args] != 1} {
   	return -code error \
	       "Wrong # of arguments. Usage: ldap::info bound handle"
   }
   CheckHandle [lindex $args 0]
   upvar #0 [lindex $args 0] conn
   if {![::info exists conn(bound)]} {
   	return -code error \
		"\"[lindex $args 0]\" is not a ldap connection handle"
   }

   return $conn(bound)
}

#-----------------------------------------------------------------------------
#   check with which user the connection is bound
#
#-----------------------------------------------------------------------------
proc ldap::info_bounduser {args} {
   if {[llength $args] != 1} {
   	return -code error \
	       "Wrong # of arguments. Usage: ldap::info bounduser handle"
   }
   CheckHandle [lindex $args 0]
   upvar #0 [lindex $args 0] conn
   if {![::info exists conn(bound)]} {
   	return -code error \
		"\"[lindex $args 0]\" is not a ldap connection handle"
   }

   return $conn(bounduser)
}

#-----------------------------------------------------------------------------
#   check if the connection uses tls
#
#-----------------------------------------------------------------------------

proc ldap::info_tls {args} {
   if {[llength $args] != 1} {
   	return -code error \
	       "Wrong # of arguments. Usage: ldap::info tls handle"
   }
   CheckHandle [lindex $args 0]
   upvar #0 [lindex $args 0] conn
   if {![::info exists conn(tls)]} {
   	return -code error \
		"\"[lindex $args 0]\" is not a ldap connection handle"
   }
   return $conn(tls)
}

#-----------------------------------------------------------------------------
#   return the TLS connection status
#
#-----------------------------------------------------------------------------

proc ldap::info_tlsstatus {args} {
   if {[llength $args] != 1} {
   	return -code error \
	       "Wrong # of arguments. Usage: ldap::info tlsstatus handle"
   }
   CheckHandle [lindex $args 0]
   upvar #0 [lindex $args 0] conn
   if {![::info exists conn(tls)]} {
   	return -code error \
		"\"[lindex $args 0]\" is not a ldap connection handle"
   }
   if {$conn(tls)} then {
       set r [::tls::status $conn(sock)]
   } else {
       set r {}
   }
   return $r
}

proc ldap::info_saslmechanisms {args} {
   if {[llength $args] != 1} {
   	return -code error \
	       "Wrong # of arguments. Usage: ldap::info saslmechanisms handle"
   }
   return [Saslmechanisms [lindex $args 0]]
}

proc ldap::info_extensions {args} {
   if {[llength $args] != 1} {
   	return -code error \
	       "Wrong # of arguments. Usage: ldap::info extensions handle"
   }
   return [Extensions [lindex $args 0]]
}

proc ldap::info_control {args} {
   if {[llength $args] != 1} {
   	return -code error \
	       "Wrong # of arguments. Usage: ldap::info control handle"
   }
   return [Control [lindex $args 0]]
}

proc ldap::info_features {args} {
   if {[llength $args] != 1} {
   	return -code error \
	       "Wrong # of arguments. Usage: ldap::info features handle"
   }
   return [Features [lindex $args 0]]
}

proc ldap::info_whoami {args} {
   if {[llength $args] != 1} {
   	return -code error \
	       "Wrong # of arguments. Usage: ldap::info whoami handle"
   }
   return [Whoami [lindex $args 0]]
}


#-----------------------------------------------------------------------------
# Basic server introspection support
#
#-----------------------------------------------------------------------------
proc ldap::Saslmechanisms {conn} {
    CheckHandle $conn
    lindex [ldap::search $conn {} {(objectClass=*)} \
                    {supportedSASLMechanisms} -scope base] 0 1 1
}

proc ldap::Extensions {conn} {
    CheckHandle $conn
    lindex [ldap::search $conn {} {(objectClass=*)} \
                    {supportedExtension} -scope base] 0 1 1
}

proc ldap::Control {conn} {
    CheckHandle $conn
    lindex [ldap::search $conn {} {(objectClass=*)} \
                    {supportedControl} -scope base] 0 1 1
}

proc ldap::Features {conn} {
    CheckHandle $conn
    lindex [ldap::search $conn {} {(objectClass=*)} \
                    {supportedFeatures} -scope base] 0 1 1
}

#-------------------------------------------------------------------------------
# Implements the RFC 4532 extension "Who am I?"
#
#-------------------------------------------------------------------------------
proc ldap::Whoami {handle} {
    CheckHandle $handle
    if {[lsearch [ldap::Extensions $handle] 1.3.6.1.4.1.4203.1.11.3] == -1} {
        return -code error \
            "Server does not support the \"Who am I?\" extension"
    }

    set request [asnApplicationConstr 23 [asnEncodeString 80 1.3.6.1.4.1.4203.1.11.3]]
    set mid [SendMessage $handle $request]
    set response [WaitForResponse $handle $mid]

    asnGetApplication response appNum
    if {$appNum != 24} {
        return -code error \
             "unexpected application number ($appNum != 24)"
    }

    asnGetEnumeration response resultCode
    asnGetOctetString response matchedDN
    asnGetOctetString response errorMessage
    if {$resultCode != 0} {
        return -code error \
		-errorcode [list LDAP [resultCode2String $resultCode] $matchedDN $errorMessage] \
		"LDAP error [resultCode2String $resultCode] '$matchedDN': $errorMessage"
    }
    set whoami ""
    if {[string length $response]} {
        asnRetag response 0x04
        asnGetOctetString response whoami
    }
    return $whoami
}

#-----------------------------------------------------------------------------
#    connect
#
#-----------------------------------------------------------------------------
proc ldap::connect { host {port 389} } {

    #--------------------------------------
    #   connect via TCP/IP
    #--------------------------------------
    set sock [socket $host $port]
    fconfigure $sock -blocking no -translation binary -buffering full

    #--------------------------------------
    #   initialize connection array
    #--------------------------------------
    upvar #0 ::ldap::ldap$sock conn
    catch { unset conn }

    set conn(host)      $host
    set conn(sock)      $sock
    set conn(messageId) 0
    set conn(tls)       0
    set conn(bound)     0
    set conn(bounduser) ""
    set conn(saslBindInProgress) 0
    set conn(tlsHandshakeInProgress) 0
    set conn(lastError) ""
    set conn(referenceVar) [namespace current]::searchReferences
    set conn(returnReferences) 0

    fileevent $sock readable [list ::ldap::MessageReceiver ::ldap::ldap$sock]
    return ::ldap::ldap$sock
}

#-----------------------------------------------------------------------------
#    tlsoptions
#
#-----------------------------------------------------------------------------
proc ldap::tlsoptions {args} {
    variable curTLSOptions
    variable validTLSOptions
    variable defaultTLSOptions
    variable TLSMode

    if {$args eq "reset"} then {
	array set curTLSOptions [array get defaultTLSOptions]
    } else {
	foreach {opt val} $args {
	    if {$opt in $validTLSOptions} then {
		set curTLSOptions($opt) $val
	    } else {
		return -code error "invalid TLS option '$opt'"
	    }
	}
    }
    set TLSMode "integrated"
    return [array get curTLSOptions]
}

#-----------------------------------------------------------------------------
#    secure_connect
#
#-----------------------------------------------------------------------------
proc ldap::secure_connect { host {port 636} {verify_cert ""} {sni_servername ""}} {

    variable tlsProtocols
    variable curTLSOptions
    variable TLSMode

    package require tls

    #------------------------------------------------------------------
    #   set options
    #------------------------------------------------------------------

    if {$TLSMode eq "compatible"} then {
	#
	# Compatible with old mode. Build a TLS socket with appropriate
	# parameters, without changing any other parameter which may
	# have been set by a previous call to tls::init (as specified
	# in the ldap.tcl manpage).
	#
	if {$verify_cert eq ""} then {
	    set verify_cert 1
	}
	set cmd [list tls::socket -request 1 -require $verify_cert \
				  -ssl2 no -ssl3 no]
	if {$sni_servername ne ""} {
	    lappend cmd -servername $sni_servername
	}

	# The valid ones depend on the server and openssl version,
	# tls::ciphers all tells it in the error message, but offers no
	# nice introspection.
	foreach {proto active} $tlsProtocols {
	    lappend cmd $proto $active
	}

	lappend cmd $host $port
    } else {
	#
	# New, integrated mode. Use only parameters set with
	# ldap::tlsoptions to build the socket.
	#

	if {$verify_cert ne "" || $sni_servername ne ""} then {
	    return -code error "verify_cert/sni_servername: incompatible with the use of tlsoptions"
	}

	set cmd [list tls::socket {*}[array get curTLSOptions] $host $port]
    }

    #------------------------------------------------------------------
    #   connect via TCP/IP
    #------------------------------------------------------------------

    set sock [eval $cmd]

    #------------------------------------------------------------------
    #   Run the TLS handshake
    #
    #------------------------------------------------------------------
    
    # run the handshake in synchronous I/O mode
    fconfigure $sock -blocking yes -translation binary -buffering full

    if {[catch { tls::handshake $sock } err]} {
	close $sock
	return -code error $err
    }

    # from now on, run in asynchronous I/O mode
    fconfigure $sock -blocking no -translation binary -buffering full

    #--------------------------------------
    #   initialize connection array
    #--------------------------------------
    upvar ::ldap::ldap$sock conn
    catch { unset conn }

    set conn(host)      $host
    set conn(sock)      $sock
    set conn(messageId) 0
    set conn(tls)       1
    set conn(bound)     0
    set conn(bounduser) ""
    set conn(saslBindInProgress) 0
    set conn(tlsHandshakeInProgress) 0
    set conn(lasterror) ""
    set conn(referenceVar) [namespace current]::searchReferences
    set conn(returnReferences) 0
    
    fileevent $sock readable [list ::ldap::MessageReceiver ::ldap::ldap$sock]
    return ::ldap::ldap$sock
}


#------------------------------------------------------------------------------
#    starttls -  negotiate tls on an open ldap connection
#
#------------------------------------------------------------------------------
proc ldap::starttls {handle {cafile ""} {certfile ""} {keyfile ""} \
                     {verify_cert ""} {sni_servername ""}} {
    variable tlsProtocols
    variable curTLSOptions
    variable TLSMode

    CheckHandle $handle

    upvar #0 $handle conn

    #------------------------------------------------------------------
    #   set options
    #------------------------------------------------------------------

    if {$TLSMode eq "compatible"} then {
	#
	# Compatible with old mode. Build a TLS socket with appropriate
	# parameters, without changing any other parameter which may
	# have been set by a previous call to tls::init (as specified
	# in the ldap.tcl manpage).
	#
	if {$verify_cert eq ""} then {
	    set verify_cert 1
	}
	set cmd [list tls::import $conn(sock) \
		     -cafile $cafile -certfile $certfile -keyfile $keyfile \
		     -request 1 -server 0 -require $verify_cert \
		     -ssl2 no -ssl3 no ]
	if {$sni_servername ne ""} {
	    lappend cmd -servername $sni_servername
	}

	# The valid ones depend on the server and openssl version,
	# tls::ciphers all tells it in the error message, but offers no
	# nice introspection.
	foreach {proto active} $tlsProtocols {
	    lappend cmd $proto $active
	}
    } else {
	#
	# New, integrated mode. Use only parameters set with
	# ldap::tlsoptions to build the socket.
	#

	if {$cafile ne "" || $certfile ne "" || $keyfile ne "" ||
		$verify_cert ne "" || $sni_servername ne ""} then {
	    return -code error "cafile/certfile/keyfile/verify_cert/sni_servername: incompatible with the use of tlsoptions"
	}

	set cmd [list tls::import $conn(sock) {*}[array get curTLSOptions]]
    }

    #------------------------------------------------------------------
    #   check handle
    #------------------------------------------------------------------

    if {$conn(tls)} {
        return -code error \
            "Cannot StartTLS on connection, TLS already running"
    }

    if {[ldap::waitingForMessages $handle]} {
        return -code error \
            "Cannot StartTLS while waiting for repsonses"
    }

    if {$conn(saslBindInProgress)} {
        return -code error \
            "Cannot StartTLS while SASL bind in progress"
    }

    if {[lsearch -exact [ldap::Extensions $handle] 1.3.6.1.4.1.1466.20037] == -1} {
        return -code error \
            "Server does not support the StartTLS extension"
    }
    package require tls


    set request [asnApplicationConstr 23 [asnEncodeString 80 1.3.6.1.4.1.1466.20037]]
    set mid [SendMessage $handle $request]
    set conn(tlsHandshakeInProgress) 1
    set response [WaitForResponse $handle $mid]

    asnGetApplication response appNum
    if {$appNum != 24} {
        set conn(tlsHandshakeInProgress) 0
        return -code error \
             "unexpected application number ($appNum != 24)"
    }

    asnGetEnumeration response resultCode
    asnGetOctetString response matchedDN
    asnGetOctetString response errorMessage
    if {$resultCode != 0} {
        set conn(tlsHandshakeInProgress) 0
        return -code error \
		-errorcode [list LDAP [resultCode2String $resultCode] $matchedDN $errorMessage] \
		"LDAP error [resultCode2String $resultCode] '$matchedDN': $errorMessage"
    }
    set oid "1.3.6.1.4.1.1466.20037"
    if {[string length $response]} {
        asnRetag response 0x04
        asnGetOctetString response oid
    }
    if {$oid ne "1.3.6.1.4.1.1466.20037"} {
        set conn(tlsHandshakeInProgress) 0
        return -code error \
            "Unexpected LDAP response"
    }

    # Initiate the TLS socket setup

    eval $cmd

    set retry 0
    while {1} {
        if {$retry > 20} {
            close $sock
            return -code error "too long retry to setup SSL connection"
        }
        if {[catch { tls::handshake $conn(sock) } err]} {
            if {[string match "*resource temporarily unavailable*" $err]} {
                after 50
                incr retry
            } else {
                close $conn(sock)
                return -code error $err
            }
        } else {
            break
        }
    }
    set conn(tls) 1
    set conn(tlsHandshakeInProgress) 0
    return 1
}



#------------------------------------------------------------------------------
#  Create a new unique message and send it over the socket.
#
#------------------------------------------------------------------------------

proc ldap::CreateAndSendMessage {handle payload} {
    upvar #0 $handle conn

    if {$conn(tlsHandshakeInProgress)} {
        return -code error \
            "Cannot send other LDAP PDU while TLS handshake in progress"
    }

    incr conn(messageId)
    set message [asnSequence [asnInteger $conn(messageId)] $payload]
    debugData "Message $conn(messageId) Sent" $message
    puts -nonewline $conn(sock) $message
    flush $conn(sock)
    return $conn(messageId)
}

#------------------------------------------------------------------------------
#  Send a message to the server which expects a response,
#  returns the messageId which is to be used with FinalizeMessage
#  and WaitForResponse
#
#------------------------------------------------------------------------------
proc ldap::SendMessage {handle pdu} {
    upvar #0 $handle conn
    set mid [CreateAndSendMessage $handle $pdu]

    # safe the state to match responses
    set conn(message,$mid) [list]
    return $mid
}

#------------------------------------------------------------------------------
#  Send a message to the server without expecting a response
#
#------------------------------------------------------------------------------
proc ldap::SendMessageNoReply {handle pdu} {
    upvar #0 $handle conn
    return [CreateAndSendMessage $handle $pdu]
}

#------------------------------------------------------------------------------
# Cleanup the storage associated with a messageId
#
#------------------------------------------------------------------------------
proc ldap::FinalizeMessage {handle messageId} {
    upvar #0 $handle conn
    trace "Message $messageId finalized"
    unset -nocomplain conn(message,$messageId)
}

#------------------------------------------------------------------------------
#  Wait for a response for the given messageId.
#
#  This waits in a vwait if no message has yet been received or returns
#  the oldest message at once, if it is queued.
#
#------------------------------------------------------------------------------
proc ldap::WaitForResponse {handle messageId} {
    upvar #0 $handle conn

    trace "Waiting for Message $messageId"
    # check if the message waits for a reply
    if {![::info exists conn(message,$messageId)]} {
        return -code error \
            [format "Cannot wait for message %d." $messageId]
    }

    # check if we have a received response in the buffer
    if {[llength $conn(message,$messageId)] > 0} {
        set response [lindex $conn(message,$messageId) 0]
        set conn(message,$messageId) [lrange $conn(message,$messageId) 1 end]
        return $response
    }

    # wait for an incoming response
    vwait [namespace which -variable $handle](message,$messageId)
    if {[llength $conn(message,$messageId)] == 0} {
        # We have waited and have been awakended but no message is there
        if {[string length $conn(lastError)]} {
            return -code error \
                [format "Protocol error: %s" $conn(lastError)]
        } else {
            return -code error \
                [format "Broken response for message %d" $messageId]
        }
    }
    set response [lindex $conn(message,$messageId) 0]
    set conn(message,$messageId) [lrange $conn(message,$messageId) 1 end]
    return $response
}

proc ldap::waitingForMessages {handle} {
    upvar #0 $handle conn
    return [llength [array names conn message,*]]
}

#------------------------------------------------------------------------------
# Process a single response PDU. Decodes the messageId and puts the
# message into the appropriate queue.
#
#------------------------------------------------------------------------------

proc ldap::ProcessMessage {handle response} {
    upvar #0 $handle conn

    # decode the messageId
    asnGetInteger  response messageId

    # check if we wait for a response
    if {[::info exists conn(message,$messageId)]} {
        # append the new message, which triggers
        # message handlers using vwait on the entry
        lappend conn(message,$messageId) $response
        return
    }

    # handle unsolicited server responses

    if {0} {
        asnGetApplication response appNum
        #if { $appNum != 24 } {
        #     error "unexpected application number ($appNum != 24)"
        #}
        asnGetEnumeration response resultCode
        asnGetOctetString response matchedDN
        asnGetOctetString response errorMessage
        if {[string length $response]} {
            asnGetOctetString response responseName
        }
        if {[string length $response]} {
            asnGetOctetString response responseValue
        }
        if {$resultCode != 0} {
            return -code error \
		    -errorcode [list LDAP [resultCode2String $resultCode] $matchedDN $errorMessage] \
		    "LDAP error [resultCode2String $resultCode] '$matchedDN': $errorMessage"
        }
    }
    #dumpASN1Parse $response
    #error "Unsolicited message from server"

}

#-------------------------------------------------------------------------------
# Get the code out of waitForResponse in case of errors
#
#-------------------------------------------------------------------------------
proc ldap::CleanupWaitingMessages {handle} {
    upvar #0 $handle conn
    foreach message [array names conn message,*] {
        set conn($message) [list]
    }
}

#-------------------------------------------------------------------------------
#  The basic fileevent based message receiver.
#  It reads PDU's from the network in a non-blocking fashion.
#
#-------------------------------------------------------------------------------
proc ldap::MessageReceiver {handle} {
    upvar #0 $handle conn

    # We have to account for partial PDUs received, so
    # we keep some state information.
    #
    #   conn(pdu,partial)  -- we are reading a partial pdu if non zero
    #   conn(pdu,length_bytes) -- the buffer for loading the length
    #   conn(pdu,length)   -- we have decoded the length if >= 0, if <0 it contains
    #                         the length of the length encoding in bytes
    #   conn(pdu,payload)  -- the payload buffer
    #   conn(pdu,received) -- the data received

    # fetch the sequence byte
    if {[::info exists conn(pdu,partial)] && $conn(pdu,partial) != 0} {
        # we have decoded at least the type byte
    } else {
        foreach {code type} [ReceiveBytes $conn(sock) 1] {break}
        switch -- $code {
            ok {
                binary scan $type c byte
                set type [expr {($byte + 0x100) % 0x100}]
                if {$type != 0x30} {
                    CleanupWaitingMessages $handle
                    set conn(lastError) [format "Expected SEQUENCE (0x30) but got %x" $type]
                    return
                } else {
                    set conn(pdu,partial) 1
                    append conn(pdu,received) $type
                }
	    }
	    partial {
		# See ticket https://core.tcl.tk/tcllib/tktview/c247ed5db42e373470bf8a6302717e76eb3c6106
		return
	    }
	    eof {
                CleanupWaitingMessages $handle
                set conn(lastError) "Server closed connection"
                catch {close $conn(sock)}
                return
            }
            default {
                CleanupWaitingMessages $handle
                set bytes $type[read $conn(sock)]
                binary scan $bytes h* values
                set conn(lastError) [format \
					 "Error reading SEQUENCE response for handle %s : %s : %s" $handle $code $values]
                return
	    }
        }
    }

    # fetch the length
    if {[::info exists conn(pdu,length)] && $conn(pdu,length) >= 0} {
        # we already have a decoded length
    } else {
        if {[::info exists conn(pdu,length)] && $conn(pdu,length) < 0} {
            # we already know the length, but have not received enough bytes to decode it
            set missing [expr {1+abs($conn(pdu,length))-[string length $conn(pdu,length_bytes)]}]
            if {$missing != 0} {
                foreach {code bytes} [ReceiveBytes $conn(sock) $missing] {break}
                switch -- $code {
                    "ok"  {
                        append conn(pdu,length_bytes) $bytes
                        append conn(pdu,received) $bytes
                        asnGetLength conn(pdu,length_bytes) conn(pdu,length)
                    }
                    "partial" {
                        append conn(pdu,length_bytes) $bytes
                        append conn(pdu,received) $bytes
                        return
                    }
                    "eof" {
                        CleanupWaitingMessages $handle
                        catch {close $conn(sock)}
                        set conn(lastError) "Server closed connection"
                        return
                    }
                    default {
                        CleanupWaitingMessages $handle
                        set conn(lastError) [format \
                            "Error reading LENGTH2 response for handle %s : %s" $handle $code]
                        return
                    }
                }
            }
        } else {
            # we know nothing, need to read the first length byte
            foreach {code bytes} [ReceiveBytes $conn(sock) 1] {break}
            switch -- $code {
                "ok"  {
                    set conn(pdu,length_bytes) $bytes
                    binary scan $bytes c byte
                    set size [expr {($byte + 0x100) % 0x100}]
                    if {$size > 0x080} {
                        set conn(pdu,length) [expr {-1* ($size & 0x7f)}]
                        # fetch the rest with the next fileevent
                        return
                    } else {
                        asnGetLength conn(pdu,length_bytes) conn(pdu,length)
                    }
                }
                "eof" {
                    CleanupWaitingMessages $handle
                    catch {close $conn(sock)}
                    set conn(lastError) "Server closed connection"
                }
                default {
                    CleanupWaitingMessages $handle
                    set conn(lastError) [format \
                        "Error reading LENGTH1 response for handle %s : %s" $handle $code]
                    return
                }
            }
        }
    }

    if {[::info exists conn(pdu,payload)]} {
        # length is decoded, we can read the rest
        set missing [expr {$conn(pdu,length) - [string length $conn(pdu,payload)]}]
    } else {
        set missing $conn(pdu,length)
    }
    if {$missing > 0} {
        foreach {code bytes} [ReceiveBytes $conn(sock) $missing] {break}
        switch -- $code {
            "ok" {
                append conn(pdu,payload) $bytes
            }
            "partial" {
                append conn(pdu,payload) $bytes
                return
            }
            "eof" {
                CleanupWaitingMessages $handle
                catch {close $conn(sock)}
                set conn(lastError) "Server closed connection"
            }
            default {
                CleanupWaitingMessages $handle
                set conn(lastError) [format \
                    "Error reading DATA response for handle %s : %s" $handle $code]
                return
            }
        }
    }

    # we have a complete PDU, push it for processing
    set pdu $conn(pdu,payload)
    set conn(pdu,payload) ""
    set conn(pdu,partial) 0
    unset -nocomplain set conn(pdu,length)
    set conn(pdu,length_bytes) ""

    # reschedule message Processing
    after 0 [list ::ldap::ProcessMessage $handle $pdu]
}

#-------------------------------------------------------------------------------
# Receive the number of bytes from the socket and signal error conditions.
#
#-------------------------------------------------------------------------------
proc ldap::ReceiveBytes {sock bytes} {
    set status [catch {read $sock $bytes} block]
    if { $status != 0 } {
        return [list error $block]
    } elseif { [string length $block] == $bytes } {
        # we have all bytes we wanted
        return [list ok $block]
    } elseif { [eof $sock] } {
        return [list eof $block]
    } elseif { [fblocked $sock] || ([string length $block] < $bytes)} {
        return [list partial $block]
    } else {
        error "Socket state for socket $sock undefined!"
    }
}

#-----------------------------------------------------------------------------
#    bindSASL  -  does a bind with SASL authentication
#-----------------------------------------------------------------------------

proc ldap::bindSASL {handle {name ""} {password ""} } {
    CheckHandle $handle

    package require SASL

    upvar #0 $handle conn

    set mechs [ldap::Saslmechanisms $handle]

    set conn(saslBindInProgress) 1
    set auth 0
    foreach mech [SASL::mechanisms] {
        if {[lsearch -exact $mechs $mech] == -1} { continue }
        trace "Using $mech for SASL Auth"
        if {[catch {
            SASLAuth $handle $mech $name $password
        } msg]} {
            trace [format "AUTH %s failed: %s" $mech $msg]
        } else {
	   # AUTH was successful
	   if {$msg == 1} {
	       set auth 1
	       break
	   }
	}
    }

    set conn(saslBindInProgress) 0
    return $auth
}

#-----------------------------------------------------------------------------
#    SASLCallback - Callback to use for SASL authentication
#
#    More or less cut and copied from the smtp module.
#    May need adjustments for ldap.
#
#-----------------------------------------------------------------------------
proc ::ldap::SASLCallback {handle context command args} {
    upvar #0 $handle conn
    upvar #0 $context ctx
    array set options $conn(options)
    trace "SASLCallback $command"
    switch -exact -- $command {
        login    { return $options(-username) }
        username { return $options(-username) }
        password { return $options(-password) }
        hostname { return [::info hostname] }
        realm    {
            if {[string equal $ctx(mech) "NTLM"] \
                    && [info exists ::env(USERDOMAIN)]} {
                return $::env(USERDOMAIN)
            } else {
                return ""
            }
        }
        default  {
            return -code error "error: unsupported SASL information requested"
        }
    }
}

#-----------------------------------------------------------------------------
#    SASLAuth - Handles the actual SASL message exchange
#
#-----------------------------------------------------------------------------

proc ldap::SASLAuth {handle mech name password} {
    upvar 1 $handle conn

    set conn(options) [list -password $password -username $name]

    # check for tcllib bug # 1545306 and reset the nonce-count if
    # found, so a second call to this code does not fail
    #
    if {[::info exists ::SASL::digest_md5_noncecount]} {
        set ::SASL::digest_md5_noncecount 0
    }

    set ctx [SASL::new -mechanism $mech \
                       -service ldap    \
                       -callback [list ::ldap::SASLCallback $handle]]

    set msg(serverSASLCreds) ""
    # Do the SASL Message exchanges
    while {[SASL::step $ctx $msg(serverSASLCreds)]} {
        # Create and send the BindRequest
        set request [buildSASLBindRequest "" $mech [SASL::response $ctx]]
        set messageId [SendMessage $handle $request]
        debugData bindRequest $request

        set response [WaitForResponse $handle $messageId]
        FinalizeMessage $handle $messageId
        debugData bindResponse $response

        array set msg [decodeSASLBindResponse $handle $response]

	# Check for Bind success
        if {$msg(resultCode) == 0} {
            set conn(bound) 1
            set conn(bounduser) $name
            SASL::cleanup $ctx
            break
        }

	# Check if next SASL step is requested
        if {$msg(resultCode) == 14} {
            continue
        }

        SASL::cleanup $ctx
        # Something went wrong
        return 	-code error \
		-errorcode [list LDAP [resultCode2String $msg(resultCode)] \
				 $msg(matchedDN) $msg(errorMessage)] \
		"LDAP error [resultCode2String $msg(resultCode)] '$msg(matchedDN)': $msg(errorMessage)"
    }

    return 1
}

#----------------------------------------------------------------------------
#
# Create a LDAP BindRequest using SASL
#
#----------------------------------------------------------------------------

proc ldap::buildSASLBindRequest {name mech {credentials {}}} {
    if {$credentials ne {}} {
       set request [  asnApplicationConstr 0            		\
            [asnInteger 3]                 		\
            [asnOctetString $name]         		\
            [asnChoiceConstr 3                   	\
                    [asnOctetString $mech]      	\
                    [asnOctetString $credentials] 	\
            ]  \
        ]
    } else {
    set request [   asnApplicationConstr 0            		\
        [asnInteger 3]                 		\
        [asnOctetString $name]         		\
        [asnChoiceConstr 3                   	\
                [asnOctetString $mech]      	\
        ] \
        ]
    }
    return $request
}

#-------------------------------------------------------------------------------
#
# Decode an LDAP BindResponse
#
#-------------------------------------------------------------------------------
proc ldap::decodeSASLBindResponse {handle response} {
    upvar #0 $handle conn

    asnGetApplication response appNum
    if { $appNum != 1 } {
        error "unexpected application number ($appNum != 1)"
    }
    asnGetEnumeration response resultCode
    asnGetOctetString response matchedDN
    asnGetOctetString response errorMessage

    # Check if we have a serverSASLCreds field left,
    # or if this is a simple response without it
    # probably an error message then.
    if {[string length $response]} {
        asnRetag response 0x04
        asnGetOctetString response serverSASLCreds
    } else {
        set serverSASLCreds ""
    }
    return [list appNum $appNum \
                 resultCode $resultCode matchedDN $matchedDN \
                 errorMessage $errorMessage serverSASLCreds $serverSASLCreds]
}


#-----------------------------------------------------------------------------
#    bind  -  does a bind with simple authentication
#
#-----------------------------------------------------------------------------
proc ldap::bind { handle {name ""} {password ""} } {
    CheckHandle $handle

    upvar #0 $handle conn

    #-----------------------------------------------------------------
    #   marshal bind request packet and send it
    #
    #-----------------------------------------------------------------
    set request [asnApplicationConstr 0                \
                        [asnInteger 3]                 \
                        [asnOctetString $name]         \
                        [asnChoice 0 $password]        \
                ]
    set messageId [SendMessage $handle $request]
    debugData bindRequest $request

    set response [WaitForResponse $handle $messageId]
    FinalizeMessage $handle $messageId
    debugData bindResponse $response

    asnGetApplication response appNum
    if { $appNum != 1 } {
        error "unexpected application number ($appNum != 1)"
    }
    asnGetEnumeration response resultCode
    asnGetOctetString response matchedDN
    asnGetOctetString response errorMessage
    if {$resultCode != 0} {
        return -code error \
		-errorcode [list LDAP [resultCode2String $resultCode] $matchedDN $errorMessage] \
		"LDAP error [resultCode2String $resultCode] '$matchedDN': $errorMessage"
    }
    set conn(bound) 1
    set conn(bounduser) $name
}


#-----------------------------------------------------------------------------
#    unbind
#
#-----------------------------------------------------------------------------
proc ldap::unbind { handle } {
    CheckHandle $handle

    upvar #0 $handle conn

    #------------------------------------------------
    #   marshal unbind request packet and send it
    #------------------------------------------------
    set request [asnApplication 2 ""]
    SendMessageNoReply $handle $request

    set conn(bounduser) ""
    set conn(bound) 0
    close $conn(sock)
    set conn(sock) ""
}


#-----------------------------------------------------------------------------
#    search  -  performs a LDAP search below the baseObject tree using a
#               complex LDAP search expression (like "|(cn=Linus*)(sn=Torvalds*)"
#               and returns all matching objects (DNs) with given attributes
#               (or all attributes if empty list is given) as list:
#
#  {dn1 { attr1 {val11 val12 ...} attr2 {val21 val22 ... } ... }} {dn2 { ... }} ...
#
#-----------------------------------------------------------------------------
proc ldap::search { handle baseObject filterString attributes args} {
    CheckHandle $handle

    upvar #0 $handle conn

    searchInit $handle $baseObject $filterString $attributes $args

    set results    {}
    set lastPacket 0
    while { !$lastPacket } {

	set r [searchNext $handle]
	if {[llength $r] > 0} then {
	    lappend results $r
	} else {
	    set lastPacket 1
	}
    }
    searchEnd $handle

    return $results
}
#-----------------------------------------------------------------------------
#    searchInProgress - checks if a search is in progress
#
#-----------------------------------------------------------------------------

proc ldap::searchInProgress {handle} {
   CheckHandle $handle
   upvar #0 $handle conn
   if {[::info exists conn(searchInProgress)]} {
   	return $conn(searchInProgress)
   } else {
       	return 0
   }
}

#-----------------------------------------------------------------------------
#    searchInit - initiates an LDAP search
#
#-----------------------------------------------------------------------------
proc ldap::searchInit { handle baseObject filterString attributes opt} {
    CheckHandle $handle

    upvar #0 $handle conn

    if {[searchInProgress $handle]} {
        return -code error \
            "Cannot start search. Already a search in progress for this handle."
    }

    set scope        2
    set derefAliases 0
    set sizeLimit    0
    set timeLimit    0
    set attrsOnly    0

    foreach {key value} $opt {
        switch -- [string tolower $key] {
            -scope {
                switch -- $value {
                   base 		{ set scope 0 }
                   one - onelevel 	{ set scope 1 }
                   sub - subtree 	{ set scope 2 }
                   default {  }
                }
            }
	    -derefaliases {
		switch -- $value {
		    never 	{ set derefAliases 0 }
		    search 	{ set derefAliases 1 }
		    find 	{ set derefAliases 2 }
		    always 	{ set derefAliases 3 }
		    default { }
		}
	    }
	    -sizelimit {
		set sizeLimit $value
	    }
	    -timelimit {
		set timeLimit $value
	    }
	    -attrsonly {
		set attrsOnly $value
	    }
	    -referencevar {
		set referenceVar $value
	    }
	    default {
		return -code error \
			"Invalid search option '$key'"
	    }
        }
    }

    set request [buildSearchRequest $baseObject $scope \
    			$derefAliases $sizeLimit $timeLimit $attrsOnly $filterString \
			$attributes]
    set messageId [SendMessage $handle $request]
    debugData searchRequest $request

    # Keep the message Id, so we know about the search
    set conn(searchInProgress) 	$messageId
    if {[::info exists referenceVar]} {
	set conn(referenceVar) $referenceVar
	set $referenceVar [list]
    }

    return $conn(searchInProgress)
}

proc ldap::buildSearchRequest {baseObject scope derefAliases
    			       sizeLimit timeLimit attrsOnly filterString
			       attributes} {
    #----------------------------------------------------------
    #   marshal filter and attributes parameter
    #----------------------------------------------------------
    set berFilter [filter::encode $filterString]

    set berAttributes ""
    foreach attribute $attributes {
        append berAttributes [asnOctetString $attribute]
    }

    #----------------------------------------------------------
    #   marshal search request packet and send it
    #----------------------------------------------------------
    set request [asnApplicationConstr 3             \
                        [asnOctetString $baseObject]    \
                        [asnEnumeration $scope]         \
                        [asnEnumeration $derefAliases]  \
                        [asnInteger     $sizeLimit]     \
                        [asnInteger     $timeLimit]     \
                        [asnBoolean     $attrsOnly]     \
                        $berFilter                      \
                        [asnSequence    $berAttributes] \
                ]

}
#-----------------------------------------------------------------------------
#    searchNext - returns the next result of an LDAP search
#
#-----------------------------------------------------------------------------
proc ldap::searchNext { handle } {
    CheckHandle $handle

    upvar #0 $handle conn

    if {! [::info exists conn(searchInProgress)]} then {
	return -code error \
	    "No search in progress"
    }

    set result {}
    set lastPacket 0

    #----------------------------------------------------------
    #   Wait for a search response packet
    #----------------------------------------------------------

    set response [WaitForResponse $handle $conn(searchInProgress)]
    debugData searchResponse $response

    asnGetApplication response appNum

    if {$appNum == 4} {
        trace "Search Response Continue"
	#----------------------------------------------------------
	#   unmarshal search data packet
	#----------------------------------------------------------
	asnGetOctetString response objectName
	asnGetSequence    response attributes
	set result_attributes {}
	while { [string length $attributes] != 0 } {
	    asnGetSequence attributes attribute
	    asnGetOctetString attribute attrType
	    asnGetSet  attribute attrValues
	    set result_attrValues {}
	    while { [string length $attrValues] != 0 } {
		asnGetOctetString attrValues attrValue
		lappend result_attrValues $attrValue
	    }
	    lappend result_attributes $attrType $result_attrValues
	}
	set result [list $objectName $result_attributes]
    } elseif {$appNum == 5} {
        trace "Search Response Done"
	#----------------------------------------------------------
	#   unmarshal search final response packet
	#----------------------------------------------------------
	asnGetEnumeration response resultCode
	asnGetOctetString response matchedDN
	asnGetOctetString response errorMessage
	set result {}
	FinalizeMessage $handle $conn(searchInProgress)
        unset conn(searchInProgress)

	if {$resultCode != 0} {
        return -code error \
		-errorcode [list LDAP [resultCode2String $resultCode] $matchedDN $errorMessage] \
		"LDAP error [resultCode2String $resultCode] : $errorMessage"
	}
    } elseif {$appNum == 19} {
    	trace "Search Result Reference"
	#---------------------------------------------------------
	#   unmarshall search result reference packet
	#---------------------------------------------------------
	
	# This should be a sequence but Microsoft AD sends just 
	# a URI encoded as an OctetString, so have a peek at the tag
	# and go on.
	
	asnPeekTag response tag type constr
	if {$tag == 0x04} {
	    set references $response
	} elseif {$tag == 0x030} {
	    asnGetSequence response references
	} 

	set urls {}
	while {[string length $references]} {
	    asnGetOctetString references url
	    lappend urls $url	   
	}
	if {[::info exists conn(referenceVar)]} {	
	    upvar 0 conn(referenceVar) refs
	    if {[llength $refs]} {
		set refs [concat [set $refs $urls]]
	    } else {
		set refs $urls
	    }
	}

	# Get the next search result instead
	set result [searchNext $handle]
    }

    # Unknown application type of result set.
    # We should just ignore it since the only PDU the server
    # MUST return if it understood our request is the "search response
    # done" (apptype 5) which we know how to process.

    return $result
}

#-----------------------------------------------------------------------------
#    searchEnd - end an LDAP search
#
#-----------------------------------------------------------------------------
proc ldap::searchEnd { handle } {
    CheckHandle $handle

    upvar #0 $handle conn

    if {! [::info exists conn(searchInProgress)]} then {
        # no harm done, just do nothing
	return
    }
    abandon $handle $conn(searchInProgress)
    FinalizeMessage $handle $conn(searchInProgress)

    unset conn(searchInProgress)
    unset -nocomplain conn(referenceVar)
    return
}

#-----------------------------------------------------------------------------
#
#    Send an LDAP abandon message
#
#-----------------------------------------------------------------------------
proc ldap::abandon {handle messageId} {
    CheckHandle $handle

    upvar #0 $handle conn
    trace "MessagesPending: [string length $conn(messageId)]"
    set request [asnApplication 16      	\
                        [asnInteger $messageId]         \
                ]
    SendMessageNoReply $handle $request
}

#-----------------------------------------------------------------------------
#    modify  -  provides attribute modifications on one single object (DN):
#                 o replace attributes with new values
#                 o delete attributes (having certain values)
#                 o add attributes with new values
#
#-----------------------------------------------------------------------------
proc ldap::modify { handle dn
                    attrValToReplace { attrToDelete {} } { attrValToAdd {} } } {

    CheckHandle $handle

    upvar #0 $handle conn

    set lrep {}
    foreach {attr value} $attrValToReplace {
	lappend lrep $attr [list $value]
    }

    set ldel {}
    foreach {attr value} $attrToDelete {
	if {[string equal $value ""]} then {
	    lappend ldel $attr {}
	} else {
	    lappend ldel $attr [list $value]
	}
    }

    set ladd {}
    foreach {attr value} $attrValToAdd {
	lappend ladd $attr [list $value]
    }

    modifyMulti $handle $dn $lrep $ldel $ladd
}


#-----------------------------------------------------------------------------
#    modify  -  provides attribute modifications on one single object (DN):
#                 o replace attributes with new values
#                 o delete attributes (having certain values)
#                 o add attributes with new values
#
#-----------------------------------------------------------------------------
proc ldap::modifyMulti {handle dn
                    attrValToReplace {attrValToDelete {}} {attrValToAdd {}}} {

    CheckHandle $handle
    upvar #0 $handle conn

    set operationAdd     0
    set operationDelete  1
    set operationReplace 2

    set modifications ""

    #------------------------------------------------------------------
    #   marshal attribute modify operations
    #    - always mode 'replace' ! see rfc2251:
    #
    #        replace: replace all existing values of the given attribute
    #        with the new values listed, creating the attribute if it
    #        did not already exist.  A replace with no value will delete
    #        the entire attribute if it exists, and is ignored if the
    #        attribute does not exist.
    #
    #------------------------------------------------------------------
    append modifications [ldap::packOpAttrVal $operationReplace \
				$attrValToReplace]

    #------------------------------------------------------------------
    #   marshal attribute add operations
    #
    #------------------------------------------------------------------
    append modifications [ldap::packOpAttrVal $operationAdd \
				$attrValToAdd]

    #------------------------------------------------------------------
    #   marshal attribute delete operations
    #
    #     - a non-empty value will trigger to delete only those
    #       attributes which have the same value as the given one
    #
    #     - an empty value will trigger to delete the attribute
    #       in all cases
    #
    #------------------------------------------------------------------
    append modifications [ldap::packOpAttrVal $operationDelete \
				$attrValToDelete]

    #----------------------------------------------------------
    #   marshal 'modify' request packet and send it
    #----------------------------------------------------------
    set request [asnApplicationConstr 6              \
                        [asnOctetString $dn ]            \
                        [asnSequence    $modifications ] \
                ]
    set messageId [SendMessage $handle $request]
    debugData modifyRequest $request
    set response [WaitForResponse $handle $messageId]
    FinalizeMessage $handle $messageId
    debugData bindResponse $response

    asnGetApplication response appNum
    if { $appNum != 7 } {
         error "unexpected application number ($appNum != 7)"
    }
    asnGetEnumeration response resultCode
    asnGetOctetString response matchedDN
    asnGetOctetString response errorMessage
    if {$resultCode != 0} {
        return -code error \
		-errorcode [list LDAP [resultCode2String $resultCode] $matchedDN $errorMessage] \
		"LDAP error [resultCode2String $resultCode] '$matchedDN': $errorMessage"
    }
}

proc ldap::packOpAttrVal {op attrValueTuples} {
    set p ""
    foreach {attrName attrValues} $attrValueTuples {
	set l {}
	foreach v $attrValues {
	    lappend l [asnOctetString $v]
	}
        append p [asnSequence                        \
		    [asnEnumeration $op ]            \
		    [asnSequence                     \
			[asnOctetString $attrName  ] \
			[asnSetFromList $l]          \
		    ]                                \
		]
    }
    return $p
}


#-----------------------------------------------------------------------------
#    add  -  will create a new object using given DN and sets the given
#            attributes. Multiple value attributes may be used, provided
#            that each attr-val pair be listed.
#
#-----------------------------------------------------------------------------
proc ldap::add { handle dn attrValueTuples } {

    CheckHandle $handle

    #
    # In order to handle multi-valuated attributes (see bug 1191326 on
    # sourceforge), we walk through tuples to collect all values for
    # an attribute.
    # http://core.tcl.tk/tcllib/tktview?name=1191326fff
    #

    foreach { attrName attrValue } $attrValueTuples {
	lappend avpairs($attrName) $attrValue
    }

    return [addMulti $handle $dn [array get avpairs]]
}

#-----------------------------------------------------------------------------
#    addMulti -  will create a new object using given DN and sets the given
#                attributes. Argument is a list of attr-listOfVals pair.
#
#-----------------------------------------------------------------------------
proc ldap::addMulti { handle dn attrValueTuples } {

    CheckHandle $handle

    upvar #0 $handle conn

    #------------------------------------------------------------------
    #   marshal attribute list
    #
    #------------------------------------------------------------------
    set attrList ""

    foreach { attrName attrValues } $attrValueTuples {
	set valList {}
	foreach val $attrValues {
	    lappend valList [asnOctetString $val]
	}
	append attrList [asnSequence                         \
			    [asnOctetString $attrName ]      \
			    [asnSetFromList $valList]        \
			]
    }

    #----------------------------------------------------------
    #   marshal search 'add' request packet and send it
    #----------------------------------------------------------
    set request [asnApplicationConstr 8             \
                        [asnOctetString $dn       ] \
                        [asnSequence    $attrList ] \
                ]

    set messageId [SendMessage $handle $request]
    debugData addRequest $request
    set response [WaitForResponse $handle $messageId]
    FinalizeMessage $handle $messageId
    debugData bindResponse $response

    asnGetApplication response appNum
    if { $appNum != 9 } {
         error "unexpected application number ($appNum != 9)"
    }
    asnGetEnumeration response resultCode
    asnGetOctetString response matchedDN
    asnGetOctetString response errorMessage
    if {$resultCode != 0} {
        return -code error \
		-errorcode [list LDAP [resultCode2String $resultCode] $matchedDN $errorMessage] \
		"LDAP error [resultCode2String $resultCode] '$matchedDN': $errorMessage"
    }
}

#-----------------------------------------------------------------------------
#    delete  -  removes the whole object (DN) inclusive all attributes
#
#-----------------------------------------------------------------------------
proc ldap::delete { handle dn } {

    CheckHandle $handle

    upvar #0 $handle conn

    #----------------------------------------------------------
    #   marshal 'delete' request packet and send it
    #----------------------------------------------------------
    set request [asnApplication 10 $dn ]
    set messageId [SendMessage $handle $request]
    debugData deleteRequest $request
    set response [WaitForResponse $handle $messageId]
    FinalizeMessage $handle $messageId

    debugData deleteResponse $response

    asnGetApplication response appNum
    if { $appNum != 11 } {
         error "unexpected application number ($appNum != 11)"
    }
    asnGetEnumeration response resultCode
    asnGetOctetString response matchedDN
    asnGetOctetString response errorMessage
    if {$resultCode != 0} {
        return -code error \
		-errorcode [list LDAP [resultCode2String $resultCode] $matchedDN $errorMessage] \
		"LDAP error [resultCode2String $resultCode] '$matchedDN': $errorMessage"
    }
}


#-----------------------------------------------------------------------------
#    modifyDN  -  moves an object (DN) to another (relative) place
#
#-----------------------------------------------------------------------------
proc ldap::modifyDN { handle dn newrdn { deleteOld 1 } {newSuperior ! } } {

    CheckHandle $handle

    upvar #0 $handle conn

    #----------------------------------------------------------
    #   marshal 'modifyDN' request packet and send it
    #----------------------------------------------------------

    if {[string equal $newSuperior "!"]} then {
        set request [asnApplicationConstr 12                 \
			    [asnOctetString $dn ]            \
			    [asnOctetString $newrdn ]        \
			    [asnBoolean     $deleteOld ]     \
		    ]

    } else {
	set request [asnApplicationConstr 12                 \
			    [asnOctetString $dn ]            \
			    [asnOctetString $newrdn ]        \
			    [asnBoolean     $deleteOld ]     \
			    [asnContext     0 $newSuperior]  \
		    ]
    }
    set messageId [SendMessage $handle $request]
    debugData modifyRequest $request
    set response [WaitForResponse $handle $messageId]

    asnGetApplication response appNum
    if { $appNum != 13 } {
         error "unexpected application number ($appNum != 13)"
    }
    asnGetEnumeration response resultCode
    asnGetOctetString response matchedDN
    asnGetOctetString response errorMessage
    if {$resultCode != 0} {
        return -code error \
		-errorcode [list LDAP [resultCode2String $resultCode] $matchedDN $errorMessage] \
		"LDAP error [resultCode2String $resultCode] '$matchedDN': $errorMessage"

    }
}

#-----------------------------------------------------------------------------
#    disconnect
#
#-----------------------------------------------------------------------------
proc ldap::disconnect { handle } {

    CheckHandle $handle

    upvar #0 $handle conn

    # should we sent an 'unbind' ?
    catch {close $conn(sock)}
    unset conn

    return
}



#-----------------------------------------------------------------------------
#    trace
#
#-----------------------------------------------------------------------------
proc ldap::trace { message } {

    variable doDebug

    if {!$doDebug} return

    puts stderr $message
}


#-----------------------------------------------------------------------------
#    debugData
#
#-----------------------------------------------------------------------------
proc ldap::debugData { info data } {

    variable doDebug

    if {!$doDebug} return

    set len [string length $data]
    trace "$info ($len bytes):"
    set address ""
    set hexnums ""
    set ascii   ""
    for {set i 0} {$i < $len} {incr i} {
        set v [string index $data $i]
        binary scan $v H2 hex
        binary scan $v c  num
        set num [expr {( $num + 0x100 ) % 0x100}]
        set text .
        if {$num > 31} {
            set text $v
        }
        if { ($i % 16) == 0 } {
            if {$address != ""} {
                trace [format "%4s  %-48s  |%s|" $address $hexnums $ascii ]
                set address ""
                set hexnums ""
                set ascii   ""
            }
            append address [format "%04d" $i]
        }
        append hexnums "$hex "
        append ascii   $text
        #trace [format "%3d %2s %s" $i $hex $text]
    }
    if {$address != ""} {
        trace [format "%4s  %-48s  |%s|" $address $hexnums $ascii ]
    }
    trace ""
}

#-----------------------------------------------------------------------------
# ldap::filter -- set of procedures for construction of BER-encoded
#                 data defined by ASN.1 type Filter described in RFC 4511
#                 from string representations of search filters
#                 defined in RFC 4515.
#-----------------------------------------------------------------------------
namespace eval ldap::filter {
    # Regexp which matches strings of type AttribyteType:
    variable reatype {[A-Za-z][A-Za-z0-9-]*|\d+(?:\.\d+)+}

    # Regexp which matches attribute options in strings
    # of type AttributeDescription:
    variable reaopts {(?:;[A-Za-z0-9-]+)*}

    # Regexp which matches strings of type AttributeDescription.
    # Note that this regexp captures attribute options,
    # with leading ";", if any.
    variable readesc (?:$reatype)($reaopts)

    # Two regexps to match strings representing "left hand side" (LHS)
    # in extensible match assertion.
    # In fact there could be one regexp with two alterations,
    # but this would complicate capturing of regexp parts.
    # The first regexp captures, in this order:
    # 1. Attribute description.
    # 2. Attribute options.
    # 3. ":dn" string, indicating "Use DN attribute types" flag.
    # 4. Matching rule ID.
    # The second regexp captures, in this order:
    # 1. ":dn" string.
    # 2. Matching rule ID.
    variable reaextmatch1 ^($readesc)(:dn)?(?::($reatype))?\$
    variable reaextmatch2 ^(:dn)?:($reatype)\$

    # The only validation proc using this regexp requires it to be
    # anchored to the boundaries of a string being validated,
    # so we change it here to allow this regexp to be compiled:
    set readesc ^$readesc\$

    unset reatype reaopts

    namespace import ::asn::*
}

# "Public API" function.
# Parses the string represntation of an LDAP search filter expression
# and returns its BER-encoded form.
# NOTE While RFC 4515 strictly defines that any filter expression must
# be surrounded by parentheses it is customary for LDAP client software
# to allow specification of simple (i.e. non-compound) filter expressions
# without enclosing parentheses, so we also do this (in fact, we allow
# omission of outermost parentheses in any filter expression).
proc ldap::filter::encode s {
    if {[string match (*) $s]} {
	ProcessFilter $s
    } else {
	ProcessFilterComp $s
    }
}

# Parses the string represntation of an LDAP search filter expression
# and returns its BER-encoded form.
proc ldap::filter::ProcessFilter s {
    if {![string match (*) $s]} {
	return -code error "Invalid filter: filter expression must be\
	    surrounded by parentheses"
    }
    ProcessFilterComp [string range $s 1 end-1]
}

# Parses "internals" of a filter expression, i.e. what's contained
# between its enclosing parentheses.
# It classifies the type of filter expression (compound, negated or
# simple) and invokes its corresponding handler.
# Returns a BER-encoded form of the filter expression.
proc ldap::filter::ProcessFilterComp s {
    switch -- [string index $s 0] {
	& {
	    ProcessFilterList 0 [string range $s 1 end]
	}
	| {
	    ProcessFilterList 1 [string range $s 1 end]
	}
	! {
	    ProcessNegatedFilter [string range $s 1 end]
	}
	default {
	    ProcessMatch $s
	}
    }
}

# Parses string $s containing a chain of one or more filter
# expressions (as found in compound filter expressions),
# processes each filter in such chain and returns
# a BER-encoded form of this chain tagged with specified
# application type given as $apptype.
proc ldap::filter::ProcessFilterList {apptype s} {
    set data ""
    set rest $s
    while 1 {
	foreach {filter rest} [ExtractFilter $rest] break
	append data [ProcessFilter $filter]
	if {$rest == ""} break
    }
    # TODO looks like it's impossible to hit this condition
    if {[string length $data] == 0} {
	return -code error "Invalid filter: filter composition must\
	    consist of at least one element"
    }
    asnChoiceConstr $apptype $data
}

# Parses a string $s representing a filter expression
# and returns a BER construction representing negation
# of that filter expression.
proc ldap::filter::ProcessNegatedFilter s {
    asnChoiceConstr 2 [ProcessFilter $s]
}

# Parses a string $s representing an "attribute matching rule"
# (i.e. the contents of a non-compound filter expression)
# and returns its BER-encoded form.
proc ldap::filter::ProcessMatch s {
    if {![regexp -indices {(=|~=|>=|<=|:=)} $s range]} {
	return -code error "Invalid filter: no match operator in item"
    }
    foreach {a z} $range break
    set lhs   [string range $s 0 [expr {$a - 1}]]
    set match [string range $s $a $z]
    set val   [string range $s [expr {$z + 1}] end]

    switch -- $match {
	= {
	    if {$val eq "*"} {
		ProcessPresenceMatch $lhs
	    } else {
		if {[regexp {^([^*]*)(\*(?:[^*]*\*)*)([^*]*)$} $val \
			-> initial any final]} {
		    ProcessSubstringMatch $lhs $initial $any $final
		} else {
		    ProcessSimpleMatch 3 $lhs $val
		}
	    }
	}
	>= {
	    ProcessSimpleMatch 5 $lhs $val
	}
	<= {
	    ProcessSimpleMatch 6 $lhs $val
	}
	~= {
	    ProcessSimpleMatch 8 $lhs $val
	}
	:= {
	    ProcessExtensibleMatch $lhs $val
	}
    }
}

# From a string $s, containing a chain of filter
# expressions (as found in compound filter expressions)
# extracts the first filter expression and returns
# a two element list composed of the extracted filter
# expression and the remainder of the source string.
proc ldap::filter::ExtractFilter s {
    if {[string index $s 0] ne "("} {
	return -code error "Invalid filter: malformed compound filter expression"
    }
    set pos   1
    set nopen 1
    while 1 {
	if {![regexp -indices -start $pos {\)|\(} $s match]} {
	    return -code error "Invalid filter: unbalanced parenthesis"
	}
	set pos [lindex $match 0]
	if {[string index $s $pos] eq "("} {
	    incr nopen
	} else {
	    incr nopen -1
	}
	if {$nopen == 0} {
	    return [list [string range $s 0 $pos] \
		[string range $s [incr pos] end]]
	}
	incr pos
    }
}

# Constructs a BER-encoded form of a "presence" match
# involving an attribute description string passed in $attrdesc.
proc ldap::filter::ProcessPresenceMatch attrdesc {
    ValidateAttributeDescription $attrdesc options
    asnChoice 7 [LDAPString $attrdesc]
}

# Constructs a BER-encoded form of a simple match designated
# by application type $apptype and involving an attribute
# description $attrdesc and attribute value $val.
# "Simple" match is one of: equal, less or equal, greater
# or equal, approximate.
proc ldap::filter::ProcessSimpleMatch {apptype attrdesc val} {
    ValidateAttributeDescription $attrdesc options
    append data [asnOctetString [LDAPString $attrdesc]] \
	[asnOctetString [AssertionValue $val]]
    asnChoiceConstr $apptype $data
}

# Constructs a BER-encoded form of a substrings match
# involving an attribute description $attrdesc and parts of attribute
# value -- $initial, $any and $final.
# A string contained in any may be compound -- several strings
# concatenated by asterisks ("*"), they are extracted and used as
# multiple attribute value parts of type "any".
proc ldap::filter::ProcessSubstringMatch {attrdesc initial any final} {
    ValidateAttributeDescription $attrdesc options

    set data [asnOctetString [LDAPString $attrdesc]]

    set seq [list]
    set parts 0
    if {$initial != ""} {
	lappend seq [asnChoice 0 [AssertionValue $initial]]
	incr parts
    }

    foreach v [split [string trim $any *] *] {
	if {$v != ""} {
	    lappend seq [asnChoice 1 [AssertionValue $v]]
	    incr parts
	}
    }

    if {$final != ""} {
	lappend seq [asnChoice 2 [AssertionValue $final]]
	incr parts
    }

    if {$parts == 0} {
	return -code error "Invalid filter: substrings match parses to zero parts"
    }

    append data [asnSequenceFromList $seq]

    asnChoiceConstr 4 $data
}

# Constructs a BER-encoded form of an extensible match
# involving an attribute value given in $value and a string
# containing the matching rule OID, if present a "Use DN attribute
# types" flag, if present, and an atttibute description, if present,
# given in $lhs (stands for "Left Hand Side").
proc ldap::filter::ProcessExtensibleMatch {lhs value} {
    ParseExtMatchLHS $lhs attrdesc options dn ruleid
    set data ""
    foreach {apptype val} [list 1 $ruleid 2 $attrdesc] {
	if {$val != ""} {
	    append data [asnChoice $apptype [LDAPString $val]]
	}
    }
    append data [asnChoice 3 [AssertionValue $value]]
    if {$dn} {
	# [asnRetag] is broken in asn, so we use the trick
	# to simulate "boolean true" BER-encoding which
	# is octet 1 of length 1:
	append data [asnChoice 4 [binary format cc 1 1]]
    }
    asnChoiceConstr 9 $data
}

# Parses a string $s, representing a "left hand side" of an extensible match
# expression, into several parts: attribute desctiption, options,
# "Use DN attribute types" flag and rule OID. These parts are
# assigned to corresponding variables in the caller's scope.
proc ldap::filter::ParseExtMatchLHS {s attrdescVar optionsVar dnVar ruleidVar} {
    upvar 1 $attrdescVar attrdesc $optionsVar options $dnVar dn $ruleidVar ruleid
    variable reaextmatch1
    variable reaextmatch2
    if {[regexp $reaextmatch1 $s -> attrdesc opts dnstr ruleid]} {
	set options [ProcessAttrTypeOptions $opts]
	set dn [expr {$dnstr != ""}]
    } elseif {[regexp $reaextmatch2 $s -> dnstr ruleid]} {
	set attrdesc ""
	set options [list]
	set dn [expr {$dnstr != ""}]
    } else {
	return -code error "Invalid filter: malformed attribute description"
    }
}

# Validates an attribute description passed as $attrdesc.
# Raises an error if it's ill-formed.
# Variable in the caller's scope whose name is passed in optionsVar
# is set to a list of attribute options (which may be empty if
# there's no options in the attribute type).
proc ldap::filter::ValidateAttributeDescription {attrdesc optionsVar} {
    variable readesc
    if {![regexp $readesc $attrdesc -> opts]} {
	return -code error "Invalid filter: malformed attribute description"
    }
    upvar 1 $optionsVar options
    set options [ProcessAttrTypeOptions $opts]
    return
}

# Parses a string $s containing one or more attribute
# options, delimited by seimcolons, with the leading semicolon,
# if non-empty.
# Returns a list of distinct options, lowercased for normalization
# purposes.
proc ldap::filter::ProcessAttrTypeOptions s {
    set opts [list]
    foreach opt [split [string trimleft $s \;] \;] {
	lappend opts [string tolower $opt]
    }
    set opts
}

# Checks an assertion value $s for validity and substitutes
# any backslash escapes in it with their respective values.
# Returns canonical form of the attribute value
# ready to be packed into a BER-encoded stream.
proc ldap::filter::AssertionValue s {
    set v [encoding convertto utf-8 $s]
    if {[regexp {\\(?:[[:xdigit:]])?(?![[:xdigit:]])|[()*\0]} $v]} {
	return -code error "Invalid filter: malformed assertion value"
    }

    variable escmap
    if {![info exists escmap]} {
	for {set i 0} {$i <= 0xff} {incr i} {
	    lappend escmap [format {\%02x} $i] [format %c $i]
	}
    }
    string map -nocase $escmap $v
}

# Turns a given Tcl string $s into a binary blob ready to be packed
# into a BER-encoded stream.
proc ldap::filter::LDAPString s {
    encoding convertto utf-8 $s
}

# vim:ts=8:sw=4:sts=4:noet
