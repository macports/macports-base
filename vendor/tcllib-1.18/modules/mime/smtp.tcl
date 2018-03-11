# smtp.tcl - SMTP client
#
# Copyright (c) 1999-2000 Marshall T. Rose
# Copyright (c) 2003-2006 Pat Thoyts
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#

package require Tcl 8.3
package require mime 1.4.1

catch {
    package require SASL 1.0;           # tcllib 1.8
    package require SASL::NTLM 1.0;     # tcllib 1.8
}

#
# state variables:
#
#    sd: socket to server
#    afterID: afterID associated with ::smtp::timer
#    options: array of user-supplied options
#    readable: semaphore for vwait
#    addrs: number of recipients negotiated
#    error: error during read
#    line: response read from server
#    crP: just put a \r in the data
#    nlP: just put a \n in the data
#    size: number of octets sent in DATA
#

namespace eval ::smtp {
    variable  trf 1
    variable  smtp
    array set smtp { uid 0 }

    namespace export sendmessage
}

if {[catch {package require Trf  2.0}]} {
    # Trf is not available, but we can live without it as long as the
    # transform and unstack procs are defined.

    # Warning!
    # This is a fragile emulation of the more general calling sequence
    # that appears to work with this code here.

    proc transform {args} {
	upvar state mystate
	set mystate(size) 1
    }
    proc unstack {channel} {
        # do nothing
        return
    }
    set ::smtp::trf 0
}


# ::smtp::sendmessage --
#
#	Sends a mime object (containing a message) to some recipients
#
# Arguments:
#	part  The MIME object containing the message to send
#       args  A list of arguments specifying various options for sending the
#             message:
#             -atleastone  A boolean specifying whether or not to send the
#                          message at all if any of the recipients are 
#                          invalid.  A value of false (as defined by 
#                          ::smtp::boolean) means that ALL recipients must be
#                          valid in order to send the message.  A value of
#                          true means that as long as at least one recipient
#                          is valid, the message will be sent.
#             -debug       A boolean specifying whether or not debugging is
#                          on.  If debugging is enabled, status messages are 
#                          printed to stderr while trying to send mail.
#             -queue       A boolean specifying whether or not the message
#                          being sent should be queued for later delivery.
#             -header      A single RFC 822 header key and value (as a list),
#                          used to specify to whom to send the message 
#                          (To, Cc, Bcc), the "From", etc.
#             -originator  The originator of the message (equivalent to
#                          specifying a From header).
#             -recipients  A string containing recipient e-mail addresses.
#                          NOTE: This option overrides any recipient addresses
#                          specified with -header.
#             -servers     A list of mail servers that could process the
#                          request.
#             -ports       A list of SMTP ports to use for each SMTP server
#                          specified
#             -client      The string to use as our host name for EHLO or HELO
#                          This defaults to 'localhost' or [info hostname]
#             -maxsecs     Maximum number of seconds to allow the SMTP server
#                          to accept the message. If not specified, the default
#                          is 120 seconds.
#             -usetls      A boolean flag. If the server supports it and we
#                          have the package, use TLS to secure the connection.
#             -tlspolicy   A command to call if the TLS negotiation fails for
#                          some reason. Return 'insecure' to continue with
#                          normal SMTP or 'secure' to close the connection and
#                          try another server.
#             -username    These are needed if your SMTP server requires
#             -password    authentication.
#
# Results:
#	Message is sent.  On success, return "".  On failure, throw an
#       exception with an error code and error message.

proc ::smtp::sendmessage {part args} {
    global errorCode errorInfo

    # Here are the meanings of the following boolean variables:
    # aloP -- value of -atleastone option above.
    # debugP -- value of -debug option above.
    # origP -- 1 if -originator option was specified, 0 otherwise.
    # queueP -- value of -queue option above.

    set aloP 0
    set debugP 0
    set origP 0
    set queueP 0
    set maxsecs 120
    set originator ""
    set recipients ""
    set servers [list localhost]
    set client "" ;# default is set after options processing
    set ports [list 25]
    set tlsP 1
    set tlspolicy {}
    set username {}
    set password {}

    array set header ""

    # lowerL will contain the list of header keys (converted to lower case) 
    # specified with various -header options.  mixedL is the mixed-case version
    # of the list.
    set lowerL ""
    set mixedL ""

    # Parse options (args).

    if {[expr {[llength $args]%2}]} {
        # Some option didn't get a value.
        error "Each option must have a value!  Invalid option list: $args"
    }
    
    foreach {option value} $args {
        switch -- $option {
            -atleastone {set aloP   [boolean $value]}
            -debug      {set debugP [boolean $value]}
            -queue      {set queueP [boolean $value]}
            -usetls     {set tlsP   [boolean $value]}
            -tlspolicy  {set tlspolicy $value}
	    -maxsecs    {set maxsecs [expr {$value < 0 ? 0 : $value}]}
            -header {
                if {[llength $value] != 2} {
                    error "-header expects a key and a value, not $value"
                }
                set mixed [lindex $value 0]
                set lower [string tolower $mixed]
                set disallowedHdrList \
                    [list content-type \
                          content-transfer-encoding \
                          content-md5 \
                          mime-version]
                if {[lsearch -exact $disallowedHdrList $lower] > -1} {
                    error "Content-Type, Content-Transfer-Encoding,\
                        Content-MD5, and MIME-Version cannot be user-specified."
                }
                if {[lsearch -exact $lowerL $lower] < 0} {
                    lappend lowerL $lower
                    lappend mixedL $mixed
                }               

                lappend header($lower) [lindex $value 1]
            }

            -originator {
                set originator $value
                if {$originator == ""} {
                    set origP 1
                }
            }

            -recipients {
                set recipients $value
            }

            -servers {
                set servers $value
            }

            -client {
                set client $value
            }

            -ports {
                set ports $value
            }

            -username { set username $value }
            -password { set password $value }

            default {
                error "unknown option $option"
            }
        }
    }

    if {[lsearch -glob $lowerL resent-*] >= 0} {
        set prefixL resent-
        set prefixM Resent-
    } else {
        set prefixL ""
        set prefixM ""
    }

    # Set a bunch of variables whose value will be the real header to be used
    # in the outbound message (with proper case and prefix).

    foreach mixed {From Sender To cc Dcc Bcc Date Message-ID} {
        set lower [string tolower $mixed]
	# FRINK: nocheck
        set ${lower}L $prefixL$lower
	# FRINK: nocheck
        set ${lower}M $prefixM$mixed
    }

    if {$origP} {
        # -originator was specified with "", so SMTP sender should be marked "".
        set sender ""
    } else {
        # -originator was specified with a value, OR -originator wasn't
        # specified at all.
        
        # If no -originator was provided, get the originator from the "From"
        # header.  If there was no "From" header get it from the username
        # executing the script.

        set who "-originator"
        if {$originator == ""} {
            if {![info exists header($fromL)]} {
                set originator $::tcl_platform(user)
            } else {
                set originator [join $header($fromL) ,]

                # Indicate that we're using the From header for the originator.

                set who $fromM
            }
        }
        
	# If there's no "From" header, create a From header with the value
	# of -originator as the value.

        if {[lsearch -exact $lowerL $fromL] < 0} {
            lappend lowerL $fromL
            lappend mixedL $fromM
            lappend header($fromL) $originator
        }

	# ::mime::parseaddress returns a list whose elements are huge key-value
	# lists with info about the addresses.  In this case, we only want one
	# originator, so we want the length of the main list to be 1.

        set addrs [::mime::parseaddress $originator]
        if {[llength $addrs] > 1} {
            error "too many mailboxes in $who: $originator"
        }
        array set aprops {error "invalid address \"$from\""}
        array set aprops [lindex $addrs 0]
        if {$aprops(error) != ""} {
            error "error in $who: $aprops(error)"
        }

	# sender = validated originator or the value of the From header.

        set sender $aprops(address)

	# If no Sender header has been specified and From is different from
	# originator, then set the sender header to the From.  Otherwise, don't
	# specify a Sender header.
        set from [join $header($fromL) ,]
        if {[lsearch -exact $lowerL $senderL] < 0 && \
                [string compare $originator $from]} {
            if {[info exists aprops]} {
                unset aprops
            }
            array set aprops {error "invalid address \"$from\""}
            array set aprops [lindex [::mime::parseaddress $from] 0]
            if {$aprops(error) != ""} {
                error "error in $fromM: $aprops(error)"
            }
            if {[string compare $aprops(address) $sender]} {
                lappend lowerL $senderL
                lappend mixedL $senderM
                lappend header($senderL) $aprops(address)
            }
        }
    }

    # We're done parsing the arguments.

    if {$recipients != ""} {
        set who -recipients
    } elseif {![info exists header($toL)]} {
        error "need -header \"$toM ...\""
    } else {
        set recipients [join $header($toL) ,]
	# Add Cc values to recipients list
	set who $toM
        if {[info exists header($ccL)]} {
            append recipients ,[join $header($ccL) ,]
            append who /$ccM
        }

        set dccInd [lsearch -exact $lowerL $dccL]
        if {$dccInd >= 0} {
	    # Add Dcc values to recipients list, and get rid of Dcc header
	    # since we don't want to output that.
            append recipients ,[join $header($dccL) ,]
            append who /$dccM

            unset header($dccL)
            set lowerL [lreplace $lowerL $dccInd $dccInd]
            set mixedL [lreplace $mixedL $dccInd $dccInd]
        }
    }

    set brecipients ""
    set bccInd [lsearch -exact $lowerL $bccL]
    if {$bccInd >= 0} {
        set bccP 1

	# Build valid bcc list and remove bcc element of header array (so that
	# bcc info won't be sent with mail).
        foreach addr [::mime::parseaddress [join $header($bccL) ,]] {
            if {[info exists aprops]} {
                unset aprops
            }
            array set aprops {error "invalid address \"$from\""}
            array set aprops $addr
            if {$aprops(error) != ""} {
                error "error in $bccM: $aprops(error)"
            }
            lappend brecipients $aprops(address)
        }

        unset header($bccL)
        set lowerL [lreplace $lowerL $bccInd $bccInd]
        set mixedL [lreplace $mixedL $bccInd $bccInd]
    } else {
        set bccP 0
    }

    # If there are no To headers, add "" to bcc list.  WHY??
    if {[lsearch -exact $lowerL $toL] < 0} {
        lappend lowerL $bccL
        lappend mixedL $bccM
        lappend header($bccL) ""
    }

    # Construct valid recipients list from recipients list.

    set vrecipients ""
    foreach addr [::mime::parseaddress $recipients] {
        if {[info exists aprops]} {
            unset aprops
        }
        array set aprops {error "invalid address \"$from\""}
        array set aprops $addr
        if {$aprops(error) != ""} {
            error "error in $who: $aprops(error)"
        }
        lappend vrecipients $aprops(address)
    }

    # If there's no date header, get the date from the mime message.  Same for
    # the message-id.

    if {([lsearch -exact $lowerL $dateL] < 0) \
            && ([catch { ::mime::getheader $part $dateL }])} {
        lappend lowerL $dateL
        lappend mixedL $dateM
        lappend header($dateL) [::mime::parsedatetime -now proper]
    }

    if {([lsearch -exact $lowerL ${message-idL}] < 0) \
            && ([catch { ::mime::getheader $part ${message-idL} }])} {
        lappend lowerL ${message-idL}
        lappend mixedL ${message-idM}
        lappend header(${message-idL}) [::mime::uniqueID]

    }

    # Get all the headers from the MIME object and save them so that they can
    # later be restored.
    set savedH [::mime::getheader $part]

    # Take all the headers defined earlier and add them to the MIME message.
    foreach lower $lowerL mixed $mixedL {
        foreach value $header($lower) {
            ::mime::setheader $part $mixed $value -mode append
        }
    }

    if {[string length $client] < 1} {
        if {![string compare $servers localhost]} {
            set client localhost
        } else {
            set client [info hostname]
        }
    }

    # Create smtp token, which essentially means begin talking to the SMTP
    # server.
    set token [initialize -debug $debugP -client $client \
		                -maxsecs $maxsecs -usetls $tlsP \
                                -multiple $bccP -queue $queueP \
                                -servers $servers -ports $ports \
                                -tlspolicy $tlspolicy \
                                -username $username -password $password]

    if {![string match "::smtp::*" $token]} {
	# An error occurred and $token contains the error info
	array set respArr $token
	return -code error $respArr(diagnostic)
    }

    set code [catch { sendmessageaux $token $part \
                                           $sender $vrecipients $aloP } \
                    result]
    set ecode $errorCode
    set einfo $errorInfo

    # Send the message to bcc recipients as a MIME attachment.

    if {($code == 0) && ($bccP)} {
        set inner [::mime::initialize -canonical message/rfc822 \
                                    -header [list Content-Description \
                                                  "Original Message"] \
                                    -parts [list $part]]

        set subject "\[$bccM\]"
        if {[info exists header(subject)]} {
            append subject " " [lindex $header(subject) 0] 
        }

        set outer [::mime::initialize \
                         -canonical multipart/digest \
                         -header [list From $originator] \
                         -header [list Bcc ""] \
                         -header [list Date \
                                       [::mime::parsedatetime -now proper]] \
                         -header [list Subject $subject] \
                         -header [list Message-ID [::mime::uniqueID]] \
                         -header [list Content-Description \
                                       "Blind Carbon Copy"] \
                         -parts [list $inner]]


        set code [catch { sendmessageaux $token $outer \
                                               $sender $brecipients \
                                               $aloP } result2]
        set ecode $errorCode
        set einfo $errorInfo

        if {$code == 0} {
            set result [concat $result $result2]
        } else {
            set result $result2
        }

        catch { ::mime::finalize $inner -subordinates none }
        catch { ::mime::finalize $outer -subordinates none }
    }

    # Determine if there was any error in prior operations and set errorcodes
    # and error messages appropriately.
    
    switch -- $code {
        0 {
            set status orderly
        }

        7 {
            set code 1
            array set response $result
            set result "$response(code): $response(diagnostic)"
            set status abort
        }

        default {
            set status abort
        }
    }

    # Destroy SMTP token 'cause we're done with it.
    
    catch { finalize $token -close $status }

    # Restore provided MIME object to original state (without the SMTP headers).
    
    foreach key [::mime::getheader $part -names] {
        mime::setheader $part $key "" -mode delete
    }
    foreach {key values} $savedH {
        foreach value $values {
            ::mime::setheader $part $key $value -mode append
        }
    }

    return -code $code -errorinfo $einfo -errorcode $ecode $result
}

# ::smtp::sendmessageaux --
#
#	Sends a mime object (containing a message) to some recipients using an
#       existing SMTP token.
#
# Arguments:
#       token       SMTP token that has an open connection to the SMTP server.
#	part        The MIME object containing the message to send.
#       originator  The e-mail address of the entity sending the message,
#                   usually the From clause.
#       recipients  List of e-mail addresses to whom message will be sent.
#       aloP        Boolean "atleastone" setting; see the -atleastone option
#                   in ::smtp::sendmessage for details.
#
# Results:
#	Message is sent.  On success, return "".  On failure, throw an
#       exception with an error code and error message.

proc ::smtp::sendmessageaux {token part originator recipients aloP} {
    global errorCode errorInfo

    winit $token $part $originator

    set goodP 0
    set badP 0
    set oops ""
    foreach recipient $recipients {
        set code [catch { waddr $token $recipient } result]
        set ecode $errorCode
        set einfo $errorInfo

        switch -- $code {
            0 {
                incr goodP
            }

            7 {
                incr badP

                array set response $result
                lappend oops [list $recipient $response(code) \
                                   $response(diagnostic)]
            }

            default {
                return -code $code -errorinfo $einfo -errorcode $ecode $result
            }
        }
    }

    if {($goodP) && ((!$badP) || ($aloP))} {
        wtext $token $part
    } else {
        catch { talk $token 300 RSET }
    }

    return $oops
}

# ::smtp::initialize --
#
#	Create an SMTP token and open a connection to the SMTP server.
#
# Arguments:
#       args  A list of arguments specifying various options for sending the
#             message:
#             -debug       A boolean specifying whether or not debugging is
#                          on.  If debugging is enabled, status messages are 
#                          printed to stderr while trying to send mail.
#             -client      Either localhost or the name of the local host.
#             -multiple    Multiple messages will be sent using this token.
#             -queue       A boolean specifying whether or not the message
#                          being sent should be queued for later delivery.
#             -servers     A list of mail servers that could process the
#                          request.
#             -ports       A list of ports on mail servers that could process
#                          the request (one port per server-- defaults to 25).
#             -usetls      A boolean to indicate we will use TLS if possible.
#             -tlspolicy   Command called if TLS setup fails.
#             -username    These provide the authentication information 
#             -password    to be used if needed by the SMTP server.
#
# Results:
#	On success, return an smtp token.  On failure, throw
#       an exception with an error code and error message.

proc ::smtp::initialize {args} {
    global errorCode errorInfo

    variable smtp

    set token [namespace current]::[incr smtp(uid)]
    # FRINK: nocheck
    variable $token
    upvar 0 $token state

    array set state [list afterID "" options "" readable 0]
    array set options [list -debug 0 -client localhost -multiple 1 \
                            -maxsecs 120 -queue 0 -servers localhost \
                            -ports 25 -usetls 1 -tlspolicy {} \
                            -username {} -password {}]
    array set options $args
    set state(options) [array get options]

    # Iterate through servers until one accepts a connection (and responds
    # nicely).
   
    set index 0 
    foreach server $options(-servers) {
	set state(readable) 0
        if {[llength $options(-ports)] >= $index} {
            set port [lindex $options(-ports) $index]
        } else {
            set port 25
        }
        if {$options(-debug)} {
            puts stderr "Trying $server..."
            flush stderr
        }

        if {[info exists state(sd)]} {
            unset state(sd)
        }

        if {[set code [catch {
            set state(sd) [socket -async $server $port]
            fconfigure $state(sd) -blocking off -translation binary
            fileevent $state(sd) readable [list ::smtp::readable $token]
        } result]]} {
            set ecode $errorCode
            set einfo $errorInfo

            catch { close $state(sd) }
            continue
        }

        if {[set code [catch { hear $token 600 } result]]} {
            array set response [list code 400 diagnostic $result]
        } else {
            array set response $result
        }
        set ecode $errorCode
        set einfo $errorInfo
        switch -- $response(code) {
            220 {
            }

            421 - default {
                # 421 - Temporary problem on server
                catch {close $state(sd)}
                continue
            }
        }

        set r [initialize_ehlo $token]
        if {$r != {}} {
            return $r
        }
        incr index
    }

    # None of the servers accepted our connection, so close everything up and
    # return an error.
    finalize $token -close drop

    return -code $code -errorinfo $einfo -errorcode $ecode $result
}

# If we cannot load the tls package, ignore the error
proc ::smtp::load_tls {} {
    set r [catch {package require tls}]
    if {$r} {set ::errorInfo ""}
    return $r
}

proc ::smtp::initialize_ehlo {token} {
    global errorCode errorInfo
    upvar einfo einfo
    upvar ecode ecode
    upvar code  code
    
    # FRINK: nocheck
    variable $token
    upvar 0 $token state
    array set options $state(options)

    # Try enhanced SMTP first.

    if {[set code [catch {smtp::talk $token 300 "EHLO $options(-client)"} \
                       result]]} {
        array set response [list code 400 diagnostic $result args ""]
    } else {
        array set response $result
    }
    set ecode $errorCode
    set einfo $errorInfo
    if {(500 <= $response(code)) && ($response(code) <= 599)} {
        if {[set code [catch { talk $token 300 \
                                   "HELO $options(-client)" } \
                           result]]} {
            array set response [list code 400 diagnostic $result args ""]
        } else {
            array set response $result
        }
        set ecode $errorCode
        set einfo $errorInfo
    }
    
    if {$response(code) == 250} {
        # Successful response to HELO or EHLO command, so set up queuing
        # and whatnot and return the token.
        
        set state(esmtp) $response(args)

        if {(!$options(-multiple)) \
                && ([lsearch $response(args) ONEX] >= 0)} {
            catch {smtp::talk $token 300 ONEX}
        }
        if {($options(-queue)) \
                && ([lsearch $response(args) XQUE] >= 0)} {
            catch {smtp::talk $token 300 QUED}
        }
        
        # Support STARTTLS extension.
        # The state(tls) item is used to see if we have already tried this.
        if {($options(-usetls)) && ![info exists state(tls)] \
                && (([lsearch $response(args) STARTTLS] >= 0)
                    || ([lsearch $response(args) TLS] >= 0))} {
            if {![load_tls]} {
                set state(tls) 0
                if {![catch {smtp::talk $token 300 STARTTLS} resp]} {
                    array set starttls $resp
                    if {$starttls(code) == 220} {
                        fileevent $state(sd) readable {}
                        catch {
                            ::tls::import $state(sd)
                            catch {::tls::handshake $state(sd)} msg
                            set state(tls) 1
                        } 
                        fileevent $state(sd) readable \
                            [list ::smtp::readable $token]
                        return [initialize_ehlo $token]
                    } else {
                        # Call a TLS client policy proc here
                        #  returns secure close and try another server.
                        #  returns insecure continue on current socket
                        set policy insecure
                        if {$options(-tlspolicy) != {}} {
                            catch {
                                eval $options(-tlspolicy) \
                                    [list $starttls(code)] \
                                    [list $starttls(diagnostic)]
                            } policy
                        }
                        if {$policy != "insecure"} {
                            set code error
                            set ecode $starttls(code)
                            set einfo $starttls(diagnostic)
                            catch {close $state(sd)}
                            return {}
                        }
                    }
                }
            }
        }

        # If we have not already tried and the server supports it and we 
        # have a username -- lets try to authenticate.
        #
        if {![info exists state(auth)]
            && [llength [package provide SASL]] != 0
            && [set andx [lsearch -glob $response(args) "AUTH*"]] >= 0 
            && [string length $options(-username)] > 0 } {
            
            # May be AUTH mech or AUTH=mech
            # We want to use the strongest mechanism that has been offered
            # and that we support. If we cannot find a mechanism that 
            # succeeds, we will go ahead and try to carry on unauthenticated.
            # This may still work else we'll get an unauthorised error later.

            set mechs [string range [lindex $response(args) $andx] 5 end]
            foreach mech [SASL::mechanisms] {
                if {[lsearch -exact $mechs $mech] == -1} { continue }
                if {[catch {
                    Authenticate $token $mech
                } msg]} {
                    if {$options(-debug)} {
                        puts stderr "AUTH $mech failed: $msg "
                        flush stderr
                    }
                }
                if {[info exists state(auth)] && $state(auth)} {
                    if {$state(auth) == 1} {
                        break
                    } else {
                        # After successful AUTH we are supposed to redo
                        # our connection for mechanisms that setup a new
                        # security layer -- these should set state(auth) 
                        # greater than 1
                        fileevent $state(sd) readable \
                            [list ::smtp::readable $token]
                        return [initialize_ehlo $token]
                    }
                }
            }
        }
        
        return $token
    } else {
        # Bad response; close the connection and hope the next server
        # is happier.
        catch {close $state(sd)}
    }
    return {}
}

proc ::smtp::SASLCallback {token context command args} {
    upvar #0 $token state
    upvar #0 $context ctx
    array set options $state(options)
    switch -exact -- $command {
        login    { return "" }
        username { return $options(-username) }
        password { return $options(-password) }
        hostname { return [info host] }
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

proc ::smtp::Authenticate {token mechanism} {
    upvar 0 $token state
    package require base64
    set ctx [SASL::new -mechanism $mechanism \
                 -callback [list [namespace origin SASLCallback] $token]]

    set state(auth) 0
    set result [smtp::talk $token 300 "AUTH $mechanism"]
    array set response $result

    while {$response(code) == 334} {
        # The NTLM initial response is not base64 encoded so handle it.
        if {[catch {base64::decode $response(diagnostic)} challenge]} {
            set challenge $response(diagnostic)
        }
        SASL::step $ctx $challenge
        set result [smtp::talk $token 300 \
                        [base64::encode -maxlen 0 [SASL::response $ctx]]]
        array set response $result
    }
    
    if {$response(code) == 235} {
        set state(auth) 1
        return $result
    } else {
        return -code 7 $result
    }
}

# ::smtp::finalize --
#
#	Deletes an SMTP token by closing the connection to the SMTP server,
#       cleanup up various state.
#
# Arguments:
#       token   SMTP token that has an open connection to the SMTP server.
#       args    Optional arguments, where the only useful option is -close,
#               whose valid values are the following:
#               orderly     Normal successful completion.  Close connection and
#                           clear state variables.
#               abort       A connection exists to the SMTP server, but it's in
#                           a weird state and needs to be reset before being
#                           closed.  Then clear state variables.
#               drop        No connection exists, so we just need to clean up
#                           state variables.
#
# Results:
#	SMTP connection is closed and state variables are cleared.  If there's
#       an error while attempting to close the connection to the SMTP server,
#       throw an exception with the error code and error message.

proc ::smtp::finalize {token args} {
    global errorCode errorInfo
    # FRINK: nocheck
    variable $token
    upvar 0 $token state

    array set options [list -close orderly]
    array set options $args

    switch -- $options(-close) {
        orderly {
            set code [catch { talk $token 120 QUIT } result]
        }

        abort {
            set code [catch {
                talk $token 0 RSET
                talk $token 0 QUIT
            } result]
        }

        drop {
            set code 0
            set result ""
        }

        default {
            error "unknown value for -close $options(-close)"
        }
    }
    set ecode $errorCode
    set einfo $errorInfo

    catch { close $state(sd) }

    if {$state(afterID) != ""} {
        catch { after cancel $state(afterID) }
    }

    foreach name [array names state] {
        unset state($name)
    }
    # FRINK: nocheck
    unset $token

    return -code $code -errorinfo $einfo -errorcode $ecode $result
}

# ::smtp::winit --
#
#	Send originator info to SMTP server.  This occurs after HELO/EHLO
#       command has completed successfully (in ::smtp::initialize).  This function
#       is called by ::smtp::sendmessageaux.
#
# Arguments:
#       token       SMTP token that has an open connection to the SMTP server.
#       part        MIME token for the message to be sent. May be used for
#                   handling some SMTP extensions.
#       originator  The e-mail address of the entity sending the message,
#                   usually the From clause.
#       mode        SMTP command specifying the mode of communication.  Default
#                   value is MAIL.
#
# Results:
#	Originator info is sent and SMTP server's response is returned.  If an
#       error occurs, throw an exception.

proc ::smtp::winit {token part originator {mode MAIL}} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state

    if {[lsearch -exact [list MAIL SEND SOML SAML] $mode] < 0} {
        error "unknown origination mode $mode"
    }

    set from "$mode FROM:<$originator>"

    # RFC 1870 -  SMTP Service Extension for Message Size Declaration
    if {[info exists state(esmtp)] 
        && [lsearch -glob $state(esmtp) "SIZE*"] != -1} {
        catch {
            set size [string length [mime::buildmessage $part]]
            append from " SIZE=$size"
        }
    }

    array set response [set result [talk $token 600 $from]]

    if {$response(code) == 250} {
        set state(addrs) 0
        return $result
    } else {
        return -code 7 $result
    }
}

# ::smtp::waddr --
#
#	Send recipient info to SMTP server.  This occurs after originator info
#       is sent (in ::smtp::winit).  This function is called by
#       ::smtp::sendmessageaux. 
#
# Arguments:
#       token       SMTP token that has an open connection to the SMTP server.
#       recipient   One of the recipients to whom the message should be
#                   delivered.  
#
# Results:
#	Recipient info is sent and SMTP server's response is returned.  If an
#       error occurs, throw an exception.

proc ::smtp::waddr {token recipient} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state

    set result [talk $token 3600 "RCPT TO:<$recipient>"]
    array set response $result

    switch -- $response(code) {
        250 - 251 {
            incr state(addrs)
            return $result
        }

        default {
            return -code 7 $result
        }
    }
}

# ::smtp::wtext --
#
#	Send message to SMTP server.  This occurs after recipient info
#       is sent (in ::smtp::winit).  This function is called by
#       ::smtp::sendmessageaux. 
#
# Arguments:
#       token       SMTP token that has an open connection to the SMTP server.
#	part        The MIME object containing the message to send.
#
# Results:
#	MIME message is sent and SMTP server's response is returned.  If an
#       error occurs, throw an exception.

proc ::smtp::wtext {token part} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state
    array set options $state(options)

    set result [talk $token 300 DATA]
    array set response $result
    if {$response(code) != 354} {
        return -code 7 $result
    }

    if {[catch { wtextaux $token $part } result]} {
        catch { puts -nonewline $state(sd) "\r\n.\r\n" ; flush $state(sd) }
        return -code 7 [list code 400 diagnostic $result]
    }

    set secs $options(-maxsecs)

    set result [talk $token $secs .]
    array set response $result
    switch -- $response(code) {
        250 - 251 {
            return $result
        }

        default {
            return -code 7 $result
        }
    }
}

# ::smtp::wtextaux --
#
#	Helper function that coordinates writing the MIME message to the socket.
#       In particular, it stacks the channel leading to the SMTP server, sets up
#       some file events, sends the message, unstacks the channel, resets the
#       file events to their original state, and returns.
#
# Arguments:
#       token       SMTP token that has an open connection to the SMTP server.
#	part        The MIME object containing the message to send.
#
# Results:
#	Message is sent.  If anything goes wrong, throw an exception.

proc ::smtp::wtextaux {token part} {
    global errorCode errorInfo

    # FRINK: nocheck
    variable $token
    upvar 0 $token state

    # Workaround a bug with stacking channels on top of TLS.
    # FRINK: nocheck
    set trf [set [namespace current]::trf]
    if {[info exists state(tls)] && $state(tls)} {
        set trf 0
    }

    flush $state(sd)
    fileevent $state(sd) readable ""
    if {$trf} {
        transform -attach $state(sd) -command [list ::smtp::wdata $token]
    } else {
        set state(size) 1
    }
    fileevent $state(sd) readable [list ::smtp::readable $token]

    # If trf is not available, get the contents of the message,
    # replace all '.'s that start their own line with '..'s, and
    # then write the mime body out to the filehandle. Do not forget to
    # deal with bare LF's here too (SF bug #499242).

    if {$trf} {
        set code [catch { ::mime::copymessage $part $state(sd) } result]
    } else {
        set code [catch { ::mime::buildmessage $part } result]
        if {$code == 0} {
	    # Detect and transform bare LF's into proper CR/LF
	    # sequences.

	    while {[regsub -all -- {([^\r])\n} $result "\\1\r\n" result]} {}
            regsub -all -- {\n\.}      $result "\n.."   result

            # Fix for bug #827436 - mail data must end with CRLF.CRLF
            if {[string compare [string index $result end] "\n"] != 0} {
                append result "\r\n"
            }
            set state(size) [string length $result]
            puts -nonewline $state(sd) $result
            set result ""
	}
    }
    set ecode $errorCode
    set einfo $errorInfo

    flush $state(sd)
    fileevent $state(sd) readable ""
    if {$trf} {
        unstack $state(sd)
    }
    fileevent $state(sd) readable [list ::smtp::readable $token]

    return -code $code -errorinfo $einfo -errorcode $ecode $result
}

# ::smtp::wdata --
#
#	This is the custom transform using Trf to do CR/LF translation.  If Trf
#       is not installed on the system, then this function never gets called and
#       no translation occurs.
#
# Arguments:
#       token       SMTP token that has an open connection to the SMTP server.
#       command     Trf provided command for manipulating socket data.
#	buffer      Data to be converted.
#
# Results:
#	buffer is translated, and state(size) is set.  If Trf is not installed
#       on the system, the transform proc defined at the top of this file sets
#       state(size) to 1.  state(size) is used later to determine a timeout
#       value.

proc ::smtp::wdata {token command buffer} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state

    switch -- $command {
        create/write -
        clear/write  -
        delete/write {
            set state(crP) 0
            set state(nlP) 1
            set state(size) 0
        }

        write {
            set result ""

            foreach c [split $buffer ""] {
                switch -- $c {
                    "." {
                        if {$state(nlP)} {
                            append result .
                        }
                        set state(crP) 0
                        set state(nlP) 0
                    }

                    "\r" {
                        set state(crP) 1
                        set state(nlP) 0
                    }

                    "\n" {
                        if {!$state(crP)} {
                            append result "\r"
                        }
                        set state(crP) 0
                        set state(nlP) 1
                    }

                    default {
                        set state(crP) 0
                        set state(nlP) 0
                    }
                }

                append result $c
            }

            incr state(size) [string length $result]
            return $result
        }

        flush/write {
            set result ""

            if {!$state(nlP)} {
                if {!$state(crP)} {
                    append result "\r"
                }
                append result "\n"
            }

            incr state(size) [string length $result]
            return $result
        }

	create/read -
        delete/read {
	    # Bugfix for [#539952]
        }

	query/ratio {
	    # Indicator for unseekable channel,
	    # for versions of Trf which ask for
	    # this.
	    return {0 0}
	}
	query/maxRead {
	    # No limits on reading bytes from the channel below, for
	    # versions of Trf which ask for this information
	    return -1
	}

	default {
	    # Silently pass all unknown commands.
	    #error "Unknown command \"$command\""
	}
    }

    return ""
}

# ::smtp::talk --
#
#	Sends an SMTP command to a server
#
# Arguments:
#       token       SMTP token that has an open connection to the SMTP server.
#	secs        Timeout after which command should be aborted.
#       command     Command to send to SMTP server.
#
# Results:
#	command is sent and response is returned.  If anything goes wrong, throw
#       an exception.

proc ::smtp::talk {token secs command} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state

    array set options $state(options)

    if {$options(-debug)} {
        puts stderr "--> $command (wait upto $secs seconds)"
        flush stderr
    }

    if {[catch { puts -nonewline $state(sd) "$command\r\n"
                 flush $state(sd) } result]} {
        return [list code 400 diagnostic $result]
    }

    if {$secs == 0} {
        return ""
    }

    return [hear $token $secs]
}

# ::smtp::hear --
#
#	Listens for SMTP server's response to some prior command.
#
# Arguments:
#       token       SMTP token that has an open connection to the SMTP server.
#	secs        Timeout after which we should stop waiting for a response.
#
# Results:
#	Response is returned.

proc ::smtp::hear {token secs} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state

    array set options $state(options)

    array set response [list args ""]

    set firstP 1
    while {1} {
        if {$secs >= 0} {
	    ## SF [ 836442 ] timeout with large data
	    ## correction, aotto 031105 -
	    if {$secs > 600} {set secs 600}
            set state(afterID) [after [expr {$secs*1000}] \
                                      [list ::smtp::timer $token]]
        }

        if {!$state(readable)} {
            vwait ${token}(readable)
        }

        # Wait until socket is readable.
        if {$state(readable) !=  -1} {
            catch { after cancel $state(afterID) }
            set state(afterID) ""
        }

        if {$state(readable) < 0} {
            array set response [list code 400 diagnostic $state(error)]
            break
        }
        set state(readable) 0

        if {$options(-debug)} {
            puts stderr "<-- $state(line)"
            flush stderr
        }

        if {[string length $state(line)] < 3} {
            array set response \
                  [list code 500 \
                        diagnostic "response too short: $state(line)"]
            break
        }

        if {$firstP} {
            set firstP 0

            if {[scan [string range $state(line) 0 2] %d response(code)] \
                    != 1} {
                array set response \
                      [list code 500 \
                            diagnostic "unrecognizable code: $state(line)"]
                break
            }

            set response(diagnostic) \
                [string trim [string range $state(line) 4 end]]
        } else {
            lappend response(args) \
                    [string trim [string range $state(line) 4 end]]
        }

        # When status message line ends in -, it means the message is complete.
        
        if {[string compare [string index $state(line) 3] -]} {
            break
        }
    }

    return [array get response]
}

# ::smtp::readable --
#
#	Reads a line of data from SMTP server when the socket is readable.  This
#       is the callback of "fileevent readable".
#
# Arguments:
#       token       SMTP token that has an open connection to the SMTP server.
#
# Results:
#	state(line) contains the line of data and state(readable) is reset.
#       state(readable) gets the following values:
#       -3  if there's a premature eof,
#       -2  if reading from socket fails.
#       1   if reading from socket was successful

proc ::smtp::readable {token} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state

    if {[catch { array set options $state(options) }]} {
        return
    }

    set state(line) ""
    if {[catch { gets $state(sd) state(line) } result]} {
        set state(readable) -2
        set state(error) $result
    } elseif {$result == -1} {
        if {[eof $state(sd)]} {
            set state(readable) -3
            set state(error) "premature end-of-file from server"
        }
    } else {
        # If the line ends in \r, remove the \r.
        if {![string compare [string index $state(line) end] "\r"]} {
            set state(line) [string range $state(line) 0 end-1]
        }
        set state(readable) 1
    }

    if {$state(readable) < 0} {
        if {$options(-debug)} {
            puts stderr "    ... $state(error) ..."
            flush stderr
        }

        catch { fileevent $state(sd) readable "" }
    }
}

# ::smtp::timer --
#
#	Handles timeout condition on any communication with the SMTP server.
#
# Arguments:
#       token       SMTP token that has an open connection to the SMTP server.
#
# Results:
#	Sets state(readable) to -1 and state(error) to an error message.

proc ::smtp::timer {token} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state

    array set options $state(options)

    set state(afterID) ""
    set state(readable) -1
    set state(error) "read from server timed out"

    if {$options(-debug)} {
        puts stderr "    ... $state(error) ..."
        flush stderr
    }
}

# ::smtp::boolean --
#
#	Helper function for unifying boolean values to 1 and 0.
#
# Arguments:
#       value   Some kind of value that represents true or false (i.e. 0, 1,
#               false, true, no, yes, off, on).
#
# Results:
#	Return 1 if the value is true, 0 if false.  If the input value is not
#       one of the above, throw an exception.

proc ::smtp::boolean {value} {
    switch -- [string tolower $value] {
        0 - false - no - off {
            return 0
        }

        1 - true - yes - on {
            return 1
        }

        default {
            error "unknown boolean value: $value"
        }
    }
}

# -------------------------------------------------------------------------

package provide smtp 1.4.5

# -------------------------------------------------------------------------
# Local variables:
# indent-tabs-mode: nil
# End:
