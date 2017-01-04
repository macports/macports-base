##################
## Module Name     --  websocket
## Original Author --  Emmanuel Frecon - emmanuel@sics.se
## Patches         --  Adrián Medraño Calvo - amcalvo@prs.de
## Description:
##
##    This library implements a WebSocket client library on top of the
##    existing http package.  The library implements the HTTP-like
##    handshake and the necessary framing of messages on sending and
##    reception.  The library is also server-aware, i.e. implementing
##    the slightly different framing when communicating from a server
##    to a client.  Part of the code comes (with modifications) from
##    the following Wiki page: http://wiki.tcl.tk/26556

##
##################

package require Tcl 8.5

package require http 2.7;  # Need keepalive!
package require logger
package require sha1
package require base64


# IMPLEMENTATION NOTES:
#
# The rough idea behind this library is to misuse the standard HTTP
# package so as to benefit from all its handshaking and the solid
# implementation of the HTTP protocol that it provides.  "Misusing"
# means requiring the HTTP package to keep the socket alive, which
# giving away the opened socket to the library once all initial HTTP
# handshaking has been performed.  From that point and onwards, the
# library is responsible for the framing of fragments of messages on
# the socket according to the RFC.
#
# The library almost solely uses the standard API of the HTTP package,
# thus being future-proof as much as possible as long as the HTTP
# package is kept backwards compatible. HOWEVER, it requires to
# extract the identifier of the socket towards the server from the
# state array. This extraction is not officially specified in the man
# page of the library and could therefor be subject to change in the
# future.

namespace eval ::websocket {
    variable WS
    if { ! [info exists WS] } {
	array set WS {
	    loglevel       "error"
	    maxlength      16777216
	    ws_magic       "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
	    ws_version     13
	    id_gene        0
	    whitespace     " \t"
	    tchar          {!#$%&'*+-.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ^_`abcdefghijklmnopqrstuvwxyz|~}
	    -keepalive     30
	    -ping          ""
	}
	# Build ASCII case-insensitive mapping table. See
	# <http://tools.ietf.org/html/rfc6455#section-2.1>.
	for {set i 0x41} {$i <= 0x5A} {incr i} {
	    lappend WS(lowercase) [format %c $i] [format %c [expr {$i + 0x20}]]
	}; unset i;
	variable log [::logger::init [string trimleft [namespace current] ::]]
	variable libdir [file dirname [file normalize [info script]]]
	${log}::setlevel $WS(loglevel)
    }
}

# ::websocket::loglevel -- Set or query loglevel
#
#       Set or query the log level of the library, which defaults to
#       warn.  The library provides much more debugging help when set
#       to debug.
#
# Arguments:
#	loglvl	New loglevel, empty for no change
#
# Results:
#       Return the (changed?) log level of the library
#
# Side Effects:
#       Increasing the loglevel of the library will output an
#       increased number of messages via the logger package.
proc ::websocket::loglevel { { loglvl "" } } {
    variable WS
    variable log

    if { $loglvl != "" } {
	if { [catch "${log}::setlevel $loglvl"] == 0 } {
	    set WS(loglevel) $loglvl
	}
    }

    return $WS(loglevel)
}


# ::websocket::Disconnect -- Disconnect from remote end
#
#       Disconnects entirely from remote end, providing an event in
#       the handler associated to the socket.  This event is of type
#       "disconnect".  Upon disconnection, the socket is closed and
#       all state concerning that WebSocket is forgotten.
#
# Arguments:
#	sock	WebSocket that was taken over or created by this library
#
# Results:
#       None.
#
# Side Effects:
#       None.
proc ::websocket::Disconnect { sock } {
    variable WS

    set varname [namespace current]::Connection_$sock
    upvar \#0 $varname Connection

    if { $Connection(liveness) ne "" } {
	after cancel $Connection(liveness)
    }
    Push $sock disconnect "Disconnected from remote end"
    catch {::close $sock}
    unset $varname
}


# ::websocket::close -- Close a WebSocket
#
#       Close a WebSocket, while sending the remote end a close frame
#       to describe the reason for the closure.
#
# Arguments:
#	sock	WebSocket that was taken over or created by this library
#	code	Reason code, as suggested by the RFC
#	reason	Descriptive message, empty to rely on builtin messages.
#
# Results:
#       None.
#
# Side Effects:
#       Will eventually disconnect the socket and loose connection to
#       the remote end.
proc ::websocket::close { sock { code 1000 } { reason "" } } {
    variable WS
    variable log

    set varname [namespace current]::Connection_$sock
    if { ! [info exists $varname] } {
	${log}::warn "$sock is not a WebSocket connection anymore"
	ThrowError "$sock is not a WebSocket"
    }
    upvar \#0 $varname Connection

    if { $Connection(state) eq "CLOSED" } {
	${log}::notice "Connection already closed"
	return
    }
    set Connection(state) CLOSED

    if { $code == "" || ![string is integer $code] } {
	send $sock 8
	${log}::info "Closing web socket"
	Push $sock close {}
    } else {
	if { $reason eq "" } {
	    set reason [string map \
			    { 1000 "Normal closure" \
			      1001 "Endpoint going away" \
			      1002 "Protocol error" \
			      1003 "Received incompatible data type" \
			      1006 "Abnormal closure" \
			      1007 "Received data not consistent with type" \
			      1008 "Policy violation" \
			      1009 "Received message too big" \
			      1010 "Missing extension" \
			      1011 "Unexpected condition" \
			      1015 "TLS handshake error" } $code]
	}
	set msg [binary format Su $code]
	append msg [encoding convertto utf-8 $reason]
	set msg [string range $msg 0 124];  # Cut answer to make sure it fits!
	send $sock 8 $msg
	${log}::info "Closing web socket: $code ($reason)"
	Push $sock close [list $code $reason]
    }
    
    Disconnect $sock
}


# ::websocket::Push -- Push event or data to handler
#
#       Every WebSocket is associated to a handler that will be
#       notified upon reception of data, but also upon important
#       events within the library or events resulting from control
#       messages sent by the remote end.  This procedure calls this
#       handler, catching all errors that might occur within the
#       handler.  The types that the library pushes out via this
#       callback are:
#
#       text       Text complete message.
#       binary     Binary complete message.
#       ping       Ping complete message.
#       pong       Pong complete message.
#       connect    Notification of successful connection.
#       disconnect Disconnection from remote end.
#       close      Pending closure of connection
#       timeout    Notification of connection timeout.
#       error      Notification of error conditions.
#
#       The handler is expected to be a command prefix, and the values
#       of parameters sock, type and msg are appended as arguments
#       when evaluating it.
#
# Arguments:
#	sock	WebSocket that was taken over or created by this library
#	type	Type of the event
#	msg	Data of the event.
#       handler Use this command to push back instead of handler at WebSocket
#
# Results:
#       None.
#
# Side Effects:
#       None.
proc ::websocket::Push { sock type msg { handler "" } } {
    variable WS
    variable log

    # If we have not specified a handler, which is in most cases, pick
    # up the handler from the array that contains all WS-relevant
    # information.
    if { $handler eq "" } {
	set varname [namespace current]::Connection_$sock
	if { ! [info exists $varname] } {
	    ${log}::warn "$sock is not a WebSocket connection anymore"
	    ThrowError "$sock is not a WebSocket"
	}
	upvar \#0 $varname Connection
	set handler $Connection(handler)
    }

    if { [catch [list {*}$handler $sock $type $msg] res] } {
	${log}::error "Error when executing WebSocket reception handler: $res"
    }
}


# ::websocket::Ping -- Send a ping
#
#       Sends a ping at regular intervals to keep the connection alive
#       and prevent equipment to close it due to inactivity.
#
# Arguments:
#	sock	WebSocket that was taken over or created by this library
#
# Results:
#       None.
#
# Side Effects:
#       None.
proc ::websocket::Ping { sock } {
    variable WS
    variable log

    set varname [namespace current]::Connection_$sock
    if { ! [info exists $varname] } {
	${log}::warn "$sock is not a WebSocket connection anymore"
	ThrowError "$sock is not a WebSocket"
    }
    upvar \#0 $varname Connection

    # Reschedule at once to get around any possible problem with ping
    # sending.
    Liveness $sock

    # Now send a ping, which will trigger a pong from the
    # (well-behaved) client.
    ${log}::debug "Sending ping to keep connection alive"
    send $sock ping $Connection(-ping)
}


# ::websocket::Liveness -- Keep connections alive
#
#       Keep connections alive (from the server side by construction),
#       as suggested by the specification.  This procedure arranges to
#       send pings after a given period of inactivity within the
#       socket.  This ties to ensure that all equipment keep the
#       connection open.
#
# Arguments:
#	sock	Existing Web socket
#
# Results:
#       Return the time to next ping, negative or zero if not relevant.
#
# Side Effects:
#       None.
proc ::websocket::Liveness { sock } {
    variable WS
    variable log

    set varname [namespace current]::Connection_$sock
    upvar \#0 $varname Connection

    # Keep connection alive by issuing pings.
    if { $Connection(liveness) ne "" } {
	after cancel $Connection(liveness)
    }
    set when [expr {$Connection(-keepalive)*1000}]
    if { $when > 0 } {
	set Connection(liveness) [after $when [namespace current]::Ping $sock]
    } else {
	set Connection(liveness) ""
    }
    return $when
}


proc ::websocket::Type { opcode } {
    variable WS
    variable log

    array set TYPES {1 text 2 binary 8 close 9 ping 10 pong}
    if { [info exists TYPES($opcode)] } {
	set type $TYPES($opcode)
    } else {
	set type <opcode-$opcode>
    }

    return $type
}


# ::websocket::validate -- Validate incoming client connections for WebSocket
#
#       This procedure checks whether a set of headers form a valid
#       WebSocket opening handshake. If so, it returns values
#       important for constructing the closing handshake.
#
#       The following aspects are checked:
#         - A valid Connection header
#         - A valid Upgrade header
#         - A valid Sec-Websocket-Version header
#         - A valid Sec-Websocket-Key header
#
#       These other are left to the invoker to check:
#         - Host contains server's authority.
#         - Origin is allowed.
#         - Sec-Websocket-Protocols contains a supported protocol.
#
# Arguments:
#	hdrs	Dictionary with HTTP header field names and their values.
#
# Results:
#       An empty list if the headers do not constitute a valid WebSocket opening
#       handshake. Otherwise, a dictionary with keys 'key', 'version'
#       and, optionally, 'protocols'.
#
# Side Effects:
#       None.
proc ::websocket::validate {hdrs} {
    variable WS
    set res [dict create]

    set upgrading 0;
    set websocket 0;
    foreach {k v} $hdrs {
	switch -exact -- [ASCIILowercase $k] {
	    connection {
		foreach v [SplitCommaSeparated $v] {
		    if {"upgrade" eq [ASCIILowercase $v]} {
			set upgrading 1
			break
		    }
		}
		if {!$upgrading} {
		    ThrowError "No 'Connect' header with 'upgrade' token found" HANDSHAKE CONNECTION
		}
	    }
	    upgrade {
		# May be a list, see
		# <http://tools.ietf.org/html/rfc7230#section-6.7> and
		# <http://tools.ietf.org/html/rfc6455#section-4.1>.
		foreach v [SplitCommaSeparated $v] {
		    # The protocol-name may be followed by a slash and a
		    # protocol-version. Ignore the version, look only at the
		    # protocol-name. See
		    # <http://tools.ietf.org/html/rfc7230#section-6.7>.
		    regexp {^[^/]+$} $v v
		    if { "websocket" eq [ASCIILowercase $v] } {
			set websocket 1
			break
		    }
		}
		if {!$websocket} {
		    ThrowError "No 'Upgrade' header with 'websocket' token found" HANDSHAKE UPGRADE
		}
	    }
	    sec-websocket-version {
		set version [string trim $v $WS(whitespace)]
		if {$version ne $WS(ws_version)} {
		    ThrowError "Invalid WebSocket version '${version}'" HANDSHAKE VERSION
		} else {
		    dict set res version $version
		}
	    }
	    sec-websocket-key {
		set key [string trim $v $WS(whitespace)]
		if {24 != [string length $key]} {
		    ThrowError "Invalid WebSocket key length" HANDSHAKE KEY
		} elseif {![regexp {^[a-zA-Z0-9+/]*={0,2}$} $key]} {
		    ThrowError "Invalid WebSocket key: not base64" HANDSHAKE KEY
		}
		dict set res key $key
	    }
	    sec-websocket-protocol {
		# There might be multiple "sec-websocket-protocol" headers.
		# See <http://tools.ietf.org/html/rfc6455#section-11.3.4>.
		set protocols [SplitCommaSeparated $v]
		# Must be valid tokens.
		foreach protocol $protocols {
		    foreach c [split $protocol ""] {
			if {$c in $WS(tchar)} {
			    ThrowError "Invalid protocol name '${protocol}'" HANDSHAKE PROTOCOL;
			}
		    }
		}
		dict lappend res protocols {*}$protocols;
	    }
	}
    }
    if {![dict exists $res version]} {
	ThrowError "No WebSocket version specified" HANDSHAKE VERSION
    }
    if {![dict exists $res key]} {
	ThrowError "No WebSocket key specified" HANDSHAKE KEY
    }

    return $res
}

# ::websocket::test -- Test incoming client connections for WebSocket
#
#       This procedure will test if the connection from an incoming
#       client is the opening of a WebSocket stream.  The socket is
#       not upgraded at once, instead a (temporary) context for the
#       incoming connection is created.  This allows server code to
#       perform a number of actions, if necessary before the WebSocket
#       stream connection goes live.  The test is made by analysing
#       the content of the headers.  Additionally, the procedure
#       checks that there exist a valid handler for the path
#       requested.
#
# Arguments:
#	srvSock	Socket to WebSocket compliant HTTP server
#	cliSock	Socket to incoming connected client.
#	path	Path requested by client at server
#	hdrs	Dictionary list of the HTTP headers.
#	qry	Dictionary list of the HTTP query (if applicable).
#
# Results:
#       1 if this is an incoming WebSocket upgrade request for a
#       recognised path, 0 otherwise.
#
# Side Effects:
#       None.
proc ::websocket::test { srvSock cliSock path { hdrs {} } { qry {} } } {
    variable WS
    variable log

    if { [llength $hdrs] <= 0 } {
	return 0
    }

    set varname [namespace current]::Server_$srvSock
    if { ! [info exists $varname] } {
	${log}::warn "$srvSock is not a WebSocket server anymore"
	ThrowError "$srvSock is not a WebSocket"
    }
    upvar \#0 $varname Server

    if {[catch {validate $hdrs} res]} {
	return 0
    }
    set protos [dict get $res protocols];
    set key [dict get $res key];

    # Search amongst existing WS handlers for one that responds to
    # that URL and implement one of the protocols.
    foreach { ptn cb proto } $Server(live) {
	set idx [lsearch -glob $protos $proto]
	# URL paths comparison should be case-sensitive. See
	# <http://tools.ietf.org/html/rfc2616#section-3.2.3>.
 	if { [string match $ptn $path] \
		 && ( ![llength $protos] || $idx >= 0 ) } {
	    set found(protocol) [expr {$idx >= 0? [lindex $protos $idx] : ""}]
	    set found(live) $cb
	    break
	}
    }

    # Stop if cannot agree on subprotocol.
    if {![info exists found]} {
	${log}::warn "Cannot find any handler for $path"
	return 0
    }

    # Create a context for the incoming client
    set varname [namespace current]::Client_${srvSock}_${cliSock}
    upvar \#0 $varname Client
    
    set Client(server) $srvSock
    set Client(sock) $cliSock
    set Client(key) $key
    set Client(accept) ""
    set Client(path) $path
    set Client(query) $qry
    set Client(accept) [sec-websocket-accept $key]
    set Client(protos) $protos
    set Client(live) $found(live)
    set Client(protocol) $found(protocol)
    
    # Return the context for the incoming client.
    return 1
}


# ::websocket::upgrade -- Upgrade socket to WebSocket in servers
#
#       Upgrade a socket that had been deemed to be an incoming
#       WebSocket connection request (see ::websocket::test) to a true
#       WebSocket.  This procedure will send the necessary connection
#       handshake to the client, arrange for the relevant callbacks to
#       be made during the life of the WebSocket and mediate of the
#       incoming request via a special "request" message.
#
# Arguments:
#	sock	Socket to client.
#
# Results:
#       None.
#
# Side Effects:
#       The socket is kept open and becomes a WebSocket, pushing out
#       callbacks as explained in ::websocket::takeover and accepting
#       messages as explained in ::websocket::send.
proc ::websocket::upgrade { sock } {
    variable WS
    variable log

    set clients [info vars [namespace current]::Client_*_${sock}]
    if { [llength $clients] == 0 } {
	${log}::warn "$sock does not point to a client WebSocket"
	ThrowError "$sock is not a WebSocket client"
    }

    set c [lindex $clients 0];   # Should only be one really...
    upvar \#0 $c Client

    # Write client response header, this is the last time we speak
    # "http"...
    puts $sock "HTTP/1.1 101 Switching Protocols"
    puts $sock "Upgrade: websocket"
    puts $sock "Connection: Upgrade"
    puts $sock "Sec-WebSocket-Accept: $Client(accept)"
    if { $Client(protocol) != "" } {
	puts $sock "Sec-WebSocket-Protocol: $Client(protocol)"
    }
    puts $sock ""
    flush $sock

    # Make the socket a server websocket
    #
    # Tell the websocket handler that we have a new incoming
    # request. We mediate this through the "message" part, which in
    # this case is composed of a list containing the URL and the query
    # (itself as a list).
    takeover $sock $Client(live) 1 [list $Client(path) $Client(query)]

    # Get rid of the temporary client state
    unset $c
}


# ::websocket::live -- Register WebSocket callbacks for servers
#
#       This procedure registers callbacks that will be performed on a
#       WebSocket compliant server whenever a client connects to a
#       matching path and protocol.
#
# Arguments:
#	sock	Socket to known WebSocket compliant HTTP server.
#	path	glob-style path to match in client.
#	cb	command to callback (same args as ::websocket::takeover)
#	proto	Application protocol
#
# Results:
#       None.
#
# Side Effects:
#       None.
proc ::websocket::live { sock path cb { proto "*" } } {
    variable WS
    variable log

    set varname [namespace current]::Server_$sock
    if { ! [info exists $varname] } {
	${log}::warn "$sock is not a WebSocket server anymore"
	ThrowError "$sock is not a WebSocket"
    }
    upvar \#0 $varname Server

    lappend Server(live) $path $cb $proto
}


# ::webserver::server -- Declare WebSocket server
#
#       This procedure registers the (accept) socket passed as an
#       argument as the identifier for an HTTP server that is capable
#       of doing WebSocket.
#
# Arguments:
#	sock	Socket on which the server accepts incoming connections.
#
# Results:
#       Return the socket.
#
# Side Effects:
#       None.
proc ::websocket::server { sock } {
    variable WS
    variable log

    set varname [namespace current]::Server_$sock
    upvar \#0 $varname Server
    set Server(sock) $sock
    set Server(live) {}

    return $sock
}


# ::websocket::send -- Send message or fragment to remote end.
#
#       Sends a fragment or a control message to the remote end of the
#       WebSocket. The type of the message is passed as a parameter
#       and can either be an integer according to the specification or
#       one of the following strings: text, binary, ping.  When
#       fragmenting, it is not allowed to change the type of the
#       message between fragments.
#
# Arguments:
#	sock	WebSocket that was taken over or created by this library
#	type	Type of the message (see above)
#	msg	Data of the fragment.
#	final	True if final fragment
#
# Results:
#       Returns the number of bytes sent, or -1 on error.  Serious
#       errors will trigger errors that must be catched.
#
# Side Effects:
#       None.
proc ::websocket::send { sock type {msg ""} {final 1}} {
    variable WS
    variable log

    set varname [namespace current]::Connection_$sock
    if { ! [info exists $varname] } {
	${log}::warn "$sock is not a WebSocket connection anymore"
	ThrowError "$sock is not a WebSocket"
    }
    upvar \#0 $varname Connection

    # Refuse to send if not connected
    if { $Connection(state) ne "CONNECTED" } {
	${log}::warn "Cannot send along WS $sock, not connected"
	return -1
    }

    # Determine opcode from type, i.e. text, binary or ping. Accept
    # integer opcodes for internal use or for future extensions of the
    # protocol.
    set opcode -1;
    if { [string is integer $type] } {
	set opcode $type
    } else {
	switch -glob -nocase -- $type {
	    t* {
		# text
		set opcode 1
	    }
	    b* {
		# binary
		set opcode 2
	    }
	    p* {
		# ping
		set opcode 9
	    }
	}
    }

    if { $opcode < 0 } {
	ThrowError \
	    "Unrecognised type, should be one of text, binary, ping or\
             a protocol valid integer"
    }

    # Refuse to continue if different from last type of message.
    if { $Connection(write:opcode) > 0 } {
	if { $opcode != $Connection(write:opcode) } {
	    ThrowError \
		"Cannot change type of message under continuation!"
	}
	set opcode 0;    # Continuation
    } else {
	set Connection(write:opcode) $opcode
    }

    # Encode text
    set type [Type $Connection(write:opcode)]
    if { $Connection(write:opcode) == 1 } {
	set msg [encoding convertto utf-8 $msg]
    }

    # Reset continuation state once sending last fragment of message.
    if { $final } {
	set Connection(write:opcode) -1
    }

    # Start assembling the header.
    set header [binary format c [expr {!!$final << 7 | $opcode}]]

    # Append the length of the message to the header. Small lengths
    # fit directly, larger ones use the markers 126 or 127.  We need
    # also to take into account the direction of the socket, since
    # clients shall randomly mask data.
    set mlen [string length $msg]
    if { $mlen < 126 } {
	set plen [string length $msg]
    } elseif { $mlen < 65536 } {
	set plen 126
    } else {
	set plen 127
    }

    # Set mask bit and push regular length into header.
    if { [string is true $Connection(server)] } {
	append header [binary format c $plen]
	set dst "client"
    } else {
	append header [binary format c [expr {1 << 7 | $plen}]]
	set dst "server"
    }

    # Appends "longer" length when the message is longer than 125 bytes
    if { $mlen > 125 } {
	if { $mlen < 65536 } {
	    append header [binary format Su $mlen]
	} else {
	    append header [binary format Wu $mlen]
	}
    }

    # Add the masking key and perform client masking whenever relevant
    if { [string is false $Connection(server)] } {
	set mask [expr {int(rand()*(1<<32))}]
	append header [binary format Iu $mask]
	set msg [Mask $mask $msg]
    }
    
    # Send the (masked) frame
    if { [catch {
	puts -nonewline $sock $header$msg;
	flush $sock;} err]} {
	${log}::error "Could not send to remote end, closed socket? ($err)"
	close $sock 1001
	return -1
    }

    # Keep socket alive at all times.
    Liveness $sock

    if { [string is true $final] } {
	${log}::debug "Sent $mlen bytes long $type final fragment to $dst"
    } else {
	${log}::debug "Sent $mlen bytes long $type fragment to $dst"
    }
    return [string length $header$msg]
}


# ::websocket::Mask -- Mask data according to RFC
#
#       XOR mask data with the provided mask as described in the RFC.
#
# Arguments:
#	mask	Mask to use to mask the data
#	dta	Bytes to mask
#
# Results:
#       Return the mask bytes, i.e. as many bytes as the data that was
#       given to this procedure, though XOR masked.
#
# Side Effects:
#       None.
proc ::websocket::Mask { mask dta } {
    variable WS
    variable log

    # Format data as a list of 32-bit integer
    # words and list of 8-bit integer byte leftovers.  Then unmask
    # data, recombine the words and bytes, and return
    binary scan $dta I*c* words bytes

    set masked_words {}
    set masked_bytes {}
    for {set i 0} {$i < [llength $words]} {incr i} {
	lappend masked_words [expr {[lindex $words $i] ^ $mask}]
    }
    for {set i 0} {$i < [llength $bytes]} {incr i} {
	lappend masked_bytes [expr {[lindex $bytes $i] ^
				    ($mask >> (24 - 8 * $i))}]
    }

    return [binary format I*c* $masked_words $masked_bytes]
}


# ::websocket::Receiver -- Receive (framed) data from WebSocket
#
#       Received framed data from a WebSocket, recontruct all
#       fragments to a complete message whenever the final fragment is
#       received and calls the handler associated to the WebSocket
#       with the content of the message once it has been
#       reconstructed.  Interleaved control frames are also passed
#       further to the handler.  This procedure also automatically
#       responds to ping by pongs.
#
# Arguments:
#	sock	WebSocket that was taken over or created by this library
#
# Results:
#       None.
#
# Side Effects:
#       Read a frame from the socket, possibly blocking while reading.
proc ::websocket::Receiver { sock } {
    variable WS
    variable log

    set varname [namespace current]::Connection_$sock
    if { ! [info exists $varname] } {
	${log}::warn "$sock is not a WebSocket connection anymore"
	ThrowError "$sock is not a WebSocket"
    }
    upvar \#0 $varname Connection

    # Keep connection alive by issuing pings.
    Liveness $sock

    # Get basic header.  Abort if reserved bits are set, unexpected
    # continuation frame, fragmented or oversized control frame, or
    # the opcode is unrecognised.
    if { [catch {read $sock 2} dta] || [string length $dta] != 2 } {
	if {[chan eof $sock]} {
	    set dta "Socket closed."
	}
	${log}::error "Cannot read header from socket: $dta"
	close $sock 1001
	return
    }
    binary scan $dta Su header
    set opcode [expr {$header >> 8 & 0xf}]
    set mask [expr {$header >> 7 & 0x1}]
    set len [expr {$header & 0x7f}]
    set reserved [expr {$header >> 12 & 0x7}]
    if { $reserved \
	     || ($opcode == 0 && $Connection(read:mode) eq "") \
	     || ($opcode > 7 && (!($header & 0x8000) || $len > 125)) \
	     || [lsearch {0 1 2 8 9 10} $opcode] < 0 } {
	# Send close frame, reason 1002: protocol error
	close $sock 1002
	return
    }
    # Determine the opcode for this frame, i.e. handle continuation of
    # frames. Control frames must not be split/continued (RFC6455 5.5).
    # No multiplexing here!
    if { $Connection(read:mode) eq "" } {
	set Connection(read:mode) $opcode
    } elseif { $opcode == 0 } {
	set opcode $Connection(read:mode)
    }


    # Get the extended length, if present
    if { $len == 126 } {
	if { [catch {read $sock 2} dta] || [string length $dta] != 2 } {
	    ${log}::error "Cannot read length from socket: $dta"
	    close $sock 1001
	    return
	}
	binary scan $dta Su len
    } elseif { $len == 127 } {
	if { [catch {read $sock 8} dta] || [string length $dta] != 8 } {
	    ${log}::error "Cannot read length from socket: $dta"
	    close $sock 1001
	    return
	}
	binary scan $dta Wu len
    }


    # Control frames use a separate buffer, since they can be
    # interleaved in fragmented messages.
    if { $opcode > 7 } {
	# Control frames should be shorter than 125 bytes
	if { $len > 125 } {
	    close $sock 1009
	    return
	}
	set oldmsg $Connection(read:msg)
	set Connection(read:msg) ""
    } else {
	# Limit the maximum message length
	if { [string length $Connection(read:msg)] + $len > $WS(maxlength) } {
	    # Send close frame, reason 1009: frame too big
	    close $sock 1009 "Limit $WS(maxlength) exceeded"
	    return
	}
    }

    if { $mask } {
	# Get mask and data.  Format data as a list of 32-bit integer
        # words and list of 8-bit integer byte leftovers.  Then unmask
	# data, recombine the words and bytes, and append to the buffer.
	if { [catch {read $sock 4} dta] || [string length $dta] != 4 } {
	    ${log}::error "Cannot read mask from socket: $dta"
	    close $sock 1001
	    return
	}
	binary scan $dta Iu mask
	if { [catch {read $sock $len} bytes] } {
	    ${log}::error "Cannot read fragment content from socket: $bytes"
	    close $sock 1001
	    return
	}
	append Connection(read:msg) [Mask $mask $bytes]
    } else {
	if { [catch {read $sock $len} bytes] \
		 || [string length $bytes] != $len } {
	    ${log}::error "Cannot read fragment content from socket: $bytes"
	    close $sock 1001
	    return
	}
	append Connection(read:msg) $bytes
    }

    if { [string is true $Connection(server)] } {
	set dst "client"
    } else {
	set dst "server"
    }
    set type [Type $Connection(read:mode)]

    # If the FIN bit is set, process the frame.
    if { $header & 0x8000 } {
	${log}::debug "Received $len bytes long $type final fragment from $dst"
	switch $opcode {
	    1 {
		# Text: decode and notify handler
		Push $sock text \
		    [encoding convertfrom utf-8 $Connection(read:msg)]
	    }
	    2 {
		# Binary: notify handler, no decoding
		Push $sock binary $Connection(read:msg)
	    }
	    8 {
		# Close: decode, notify handler and close frame.
		if { [string length $Connection(read:msg)] >= 2 } {
		    binary scan [string range $Connection(read:msg) 0 1] Su \
			reason
		    set msg [encoding convertfrom utf-8 \
				 [string range $Connection(read:msg) 2 end]]
		    close $sock $reason $msg
		} else {
		    close $sock 
		}
		return
	    }
	    9 {
		# Ping: send pong back and notify handler since this
		# might contain some data.
		send $sock 10 $Connection(read:msg)
		Push $sock ping $Connection(read:msg)
	    }
	    10 {
		Push $sock pong $Connection(read:msg)
	    }
	}

	# Prepare for next frame.
	if { $opcode < 8 } {
	    # Reinitialise
	    set Connection(read:msg) ""
	    set Connection(read:mode) ""
	} else {
	    set Connection(read:msg) $oldmsg
	    if {$Connection(read:mode) eq $opcode} {
		# non-interjected control frame, clear mode
		set Connection(read:mode) ""
	    }
	}
    } else {
	${log}::debug "Received $len long $type fragment from $dst"
    }
}


# ::websocket::New -- Create new websocket connection context
#
#       Create a blank new websocket connection context array, the
#       connection is placed in the state "CONNECTING" meaning that it
#       is not ready for action yet.
#
# Arguments:
#	sock	Socket to remote end
#	handler	Handler callback
#	server	Is this a server or a client socket
#
# Results:
#       Return the internal name of the array storing connection
#       details.
#
# Side Effects:
#       This procedure will reinitialise the connection information
#       for the socket if it was already known.  This is on purpose
#       and by design, but worth noting.
proc ::websocket::New { sock handler { server 0 } } {
    variable WS
    variable log

    set varname [namespace current]::Connection_$sock
    upvar \#0 $varname Connection
    
    set Connection(sock) $sock
    set Connection(handler) $handler
    set Connection(server) $server

    set Connection(peername) 0.0.0.0
    set Connection(sockname) 127.0.0.1
    
    set Connection(read:mode) ""
    set Connection(read:msg) ""
    set Connection(write:opcode) -1
    set Connection(state) CONNECTING
    set Connection(liveness) ""
    
    # Arrange for keepalive to be zero, i.e. no pings, when we are
    # within a client.  When in servers, take the default from the
    # library.  In any case, this can be configured, which means that
    # even clients can start sending pings when nothing has happened
    # on the line if necessary.
    if { [string is true $server] } {
	set Connection(-keepalive) $WS(-keepalive)
    } else {
	set Connection(-keepalive) 0
    }
    set Connection(-ping) $WS(-ping)

    return $varname
}


# ::websocket::takeover -- Take over an existing socket.
#
#       Take over an existing opened socket to implement sending and
#       receiving WebSocket framing on top of the socket.  The
#       procedure takes a handler, i.e. a command that will be called
#       whenever messages, control messages or other important
#       internal events are received or occur.
#
#       The handler should be a command prefix, to be evaluated with
#       socket handle, the message type and the message appended.
#
# Arguments:
#	sock	Existing opened socket.
#	handler	Command to call on events and incoming messages.
#	server	Is this a socket within a server, i.e. towards a client.
#	info	Additional information to pass to the handler upon successful
#		connection.
#
# Results:
#       None.
#
# Side Effects:
#       The handler is invoked with type 'connect' on successful connection.
proc ::websocket::takeover { sock handler { server 0 } { info {} }} {
    variable WS
    variable log

    # Create (or update) connection
    set varname [New $sock $handler $server]
    upvar \#0 $varname Connection
    set Connection(state) CONNECTED

    # Gather information about local and remote peer.
    if { [catch {fconfigure $sock -peername} sockinfo] == 0 } {
	set Connection(peername) [lindex $sockinfo 1]
	if { $Connection(peername) eq "" } {
	    set Connection(peername) [lindex $sockinfo 0]
	}
    } else {
	${log}::warn "Cannot get remote information from socket: $sockinfo"
    }
    if { [catch {fconfigure $sock -sockname} sockinfo] == 0 } {
	set Connection(sockname) [lindex $sockinfo 1]
	if { $Connection(sockname) eq "" } {
	    set Connection(sockname) [lindex $sockinfo 0]
	}
    } else {
	${log}::warn "Cannot get local information from socket: $sockinfo"
    }

    # Listen to incoming traffic on socket and make sure we ping if
    # necessary.
    fconfigure $sock -translation binary -blocking on
    fileevent $sock readable [list [namespace current]::Receiver $sock]
    Liveness $sock

    # Tell the WebSocket handler that the connection is now open.
    Push $sock connect $info;
    
    ${log}::debug "$sock has been registered as a\
                   [expr $server?\"server\":\"client\"] WebSocket"
}


# ::websocket::Connected -- Handshake and framing initialisation
#
#       Performs the security handshake once connection to a remote
#       WebSocket server has been established and handshake properly.
#       On success, start listening to framed data on the socket, and
#       mediate the callers about the connection and the application
#       protocol that was chosen by the server.
#
# Arguments:
#	opener	Temporary HTTP connection opening object.
#	sock	Socket connection to server, empty to pick from HTTP state array
#	token	HTTP state array.
#
# Results:
#       None.
#
# Side Effects:
#       None.
proc ::websocket::Connected { opener sock token } {
    variable WS
    variable log

    upvar \#0 $opener OPEN

    # Dig into the internals of the HTTP library for the socket if
    # none present as part of the arguments (ugly...)
    if { $sock eq "" } {
	set sock [HTTPSocket $token]
	if { $sock eq "" } {
	    ${log}::warn "Cannot extract sock from HTTP token $token, aborting"
	    return 0
	}
    }

    set ncode [::http::ncode $token]
    if { $ncode == 101 } {
	array set HDR [::http::meta $token]

	# Extact security handshake, check against what was expected
	# and abort in case of mismatch.
	if { [info exists HDR(Sec-WebSocket-Accept)] } {
	    # Compute security handshake
	    set accept [sec-websocket-accept $OPEN(nonce)]
	    if { $accept ne $HDR(Sec-WebSocket-Accept) } {
		${log}::error "Security handshake failed"
		::http::reset $token error
		unset $opener
		Disconnect $sock
		return 0
	    }
	}

	# Extract application protocol information to pass further to
	# handler.
	set proto ""
	if { [info exists HDR(Sec-WebSocket-Protocol)] } {
	    set proto $HDR(Sec-WebSocket-Protocol)
	}

	# Remove the socket from the socketmap inside the http
	# library.  THIS IS UGLY, but the only way to make sure we
	# really can take over the socket and make sure the library
	# will open A NEW socket, even towards the same host, at a
	# later time.
	if { [info vars ::http::socketmap] ne "" } {
	    foreach k [array names ::http::socketmap] {
		if { $::http::socketmap($k) eq $sock } {
		    ${log}::debug "Removed socket $sock from internal state\
                                   of http library"
		    unset ::http::socketmap($k)
		}
	    }
	} else {
	    ${log}::warn "Could not remove socket $sock from socket map, future\
                          connections to same host and port are likely not to\
                          work"
	}

	# Takeover the socket to create a connection and mediate about
	# connection via the handler. Tell the handler which protocol was
	# chosen.
	takeover $sock $OPEN(handler) 0 $proto
    } else {
	Push \
	    $sock \
	    error \
	    "HTTP error code $ncode when establishing WebSocket connection with $OPEN(url)" \
	    $OPEN(handler)
    }

    ::http::cleanup $token
    unset $opener;   # Always unset the temporary connection opening
		     # array
    return 0
}


# ::websocket::Finished -- Pass further on HTTP connection finalisation
#
#       Pass further to Connected whenever the HTTP operation has
#       been finished as implemented by the HTTP package.
#
# Arguments:
#	opener	Temporary HTTP connection opening object.
#	token	HTTP state array.
#
# Results:
#       None.
#
# Side Effects:
#       None.
proc ::websocket::Finished { opener token } {
    if {[::http::status $token] ne "timeout"} {
	upvar \#0 $opener OPEN
	if { [info exists OPEN(timeout)] } {
	    ::after cancel $OPEN(timeout);
	    unset OPEN(timeout);
	}
    }

    Connected $opener "" $token
}


# ::websocket::Timeout -- Timeout an HTTP connection
#
#       Reimplementation of the timeout facility from the HTTP package
#       to be able to cleanup internal state properly and mediate to
#       the handler.
#
# Arguments:
#	opener	Temporary HTTP connection opening object.
#	token	HTTP state array.
#
# Results:
#       None.
#
# Side Effects:
#       Reset the HTTP connection, which will (probably) close the
#       socket.
proc ::websocket::Timeout { opener token } {
    variable WS
    variable log

    if { [info exists $opener] } {
	upvar \#0 $opener OPEN
	
	set sock [HTTPSocket $token]
	Push $sock timeout \
	    "Timeout when connecting to $OPEN(url)" $OPEN(handler)
	::http::reset $token "timeout";
	::http::cleanup $token
	
	# Destroy connection state, which will also attempt to close
	# the socket.
	if { $sock ne "" } {
	    Disconnect $sock
	}
    }
}


# ::websocket::HTTPSocket -- Get socket from HTTP token
#
#       Extract the socket used for a given (existing) HTTP
#       connection.  This uses the undocumented index called "sock" in
#       the HTTP state array.
#
# Arguments:
#	token	HTTP token, as returned by http::geturl
#
# Results:
#       The socket to the remote server, or an empty string on errors.
#
# Side Effects:
#       None.
proc ::websocket::HTTPSocket { token } {
    variable log

    upvar \#0 $token htstate
    if { [info exists htstate(sock)] } {
	return $htstate(sock)
    } else {
	${log}::error "No socket associated to HTTP token $token!"
	return ""
    }
}


# ::websocket::open -- Open connection to remote WebSocket server
#
#       Open a WebSocket connection to a remote server.  This
#       procedure takes a number of options, which mostly are the
#       options that are supported by the http::geturl procedure.
#       However, there are a few differences described below:
#       -headers  Is supported, but additional headers will be added internally
#       -validate Is not supported, it has no point.
#       -handler  Is used internally, so cannot be specified.
#       -command  Is used internally, so cannot be specified.
#       -protocol Contains a list of app. protocols to handshake with server
#
# Arguments:
#	url	WebSocket URL, i.e. led by ws: or wss:
#	handler	Command prefix to invoke on data reception or event occurrence
#	args	List of dashled options with their values, as explained above.
#
# Results:
#       Return the socket for use with the rest of the WebSocket
#       library, or an empty string on errors.
#
# Side Effects:
#       None.
proc ::websocket::open { url handler args } {
    variable WS
    variable log

    # Fool the http library by replacing the ws: (websocket) scheme
    # with the http, so we can use the http library to handle all the
    # initial handshake.
    set hturl [regsub -nocase {^ws} $url "http"]

    # Start creating a command to call the http library.
    set cmd [list ::http::geturl $hturl]

    # Control the geturl options that we can blindly pass to the
    # http::geturl call. We basically remove -validate, which has no
    # point and stop -handler which we will be using internally.  We
    # restrain the use of -timeout, implementing the timeout ourselves
    # to avoid the library to close the socket to the server.  We also
    # intercept the headers since we will be adding WebSocket protocol
    # information as part of the headers.
    set protos {}
    set timeout -1
    array set HDR {}
    foreach { k v } $args {
	set allowed 0
	foreach opt {bi* bl* ch* he* k* m* prog* prot* qu* s* ti* ty*} {
	    if { [string match -nocase $opt [string trimleft $k -]] } {
		set allowed 1
	    }
	}
	if { ! $allowed } {
	    ThrowError "$k is not a recognised option"
	}
	switch -nocase -glob -- [string trimleft $k -] {
	    he* {
		# Catch the headers, since we will be adding a few
		# ones by hand.
		array set HDR $v
	    }
	    prot* {
		# New option -protocol to support the list of
		# application protocols that the client accepts.
		# -protocol should be a list.
		set protos $v
	    }
	    ti* {
		# We implement the timeout ourselves to be able to
		# properly cleanup.
		if { [string is integer $v] && $v > 0 } {
		    set timeout $v
		}
	    }
	    default {
		# Any other allowed option will simply be passed
		# further to the http::geturl call, to benefit from
		# all its facilities.
		lappend cmd $k $v
	    }
	}
    }

    # Create an HTTP connection object that will contain all necessary
    # internal data until the connection has been a success or until
    # it failed.
    set varname [namespace current]::opener_[incr WS(id_gene)]
    upvar \#0 $varname OPEN
    set OPEN(url) $url
    set OPEN(handler) $handler
    set OPEN(nonce) ""

    # Construct the WebSocket part of the header according to RFC6455.
    # The NONCE should be randomly chosen for each new connection
    # established
    AddToken HDR Connection "Upgrade"
    AddToken HDR Upgrade "websocket"
    for { set i 0 } { $i < 4 } { incr i } {
        append OPEN(nonce) [binary format Iu [expr {int(rand()*4294967296)}]]
    }
    set OPEN(nonce) [::base64::encode $OPEN(nonce)]
    set HDR(Sec-WebSocket-Key) $OPEN(nonce)
    set HDR(Sec-WebSocket-Protocol) [join $protos ", "]
    set HDR(Sec-WebSocket-Version) $WS(ws_version)
    lappend cmd -headers [array get HDR]

    # Adding our own handler to intercept the socket once connection
    # has been opened and established properly would be logical, but
    # does not work in practice since this forces the HTTP library to
    # perform a HTTP 1.0 request. Instead, we arrange to be called
    # back via -command. We force -keepalive to make sure the HTTP
    # library does not insert a "Connection: close" directive in the
    # headers, and really make sure to do whatever we can to have a
    # HTTP 1.1 connection.
    lappend cmd \
	-command [list [namespace current]::Finished $varname] \
	-keepalive 1 \
	-protocol 1.1

    # Now open the connection to the remote server using the HTTP
    # package...
    set sock ""
    if { [catch $cmd token] } {
	unset $varname;    # Free opening context, we won't need it!
	ThrowError "Error while opening WebSocket connection to $url: $token"
    } else {
	set sock [HTTPSocket $token]
	if { $sock ne "" } {
	    # Create connection context.
	    New $sock $handler
	    if { $timeout > 0 } {
		set OPEN(timeout) \
		    [after $timeout [list [namespace current]::Timeout $varname $token]]
	    }
	} else {
	    ${log}::warn "Cannot extract socket from HTTP token, failure"
	    # Call the timeout to get rid of internal states
	    Timeout $varname $token
	}
    }

    return $sock
}


# ::websocket::conninfo -- Connection information
#
#       Provide callers with some introspection facilities in order to
#       get some semi-internal data about an existing websocket.  It
#       returns the following pieces of information:
#       peername   - name or IP of remote end
#       (sock)name - name or IP of local end
#       closed     - 1 if closed, 0 otherwise
#       client     - 1 if client websocket
#       server     - 1 if server websocket
#       type       - the string "server" or "client", depending on the type.
#       handler    - callback registered from websocket.
#       state      - current state of websocket, one of CONNECTING, CONNECTED or
#                    CLOSED.
#
# Arguments:
#	sock	WebSocket that was taken over or created by this library
#	what	What piece of information to get, see above for details.
#
# Results:
#       Return the value of the information or an empty string.
#
# Side Effects:
#       None.
proc ::websocket::conninfo { sock what } {
    variable WS
    variable log

    set varname [namespace current]::Connection_$sock
    if { ! [::info exists $varname] } {
        ${log}::warn "$sock is not a WebSocket connection anymore"
        ThrowError "$sock is not a WebSocket"
    }
    upvar \#0 $varname Connection
    
    switch -glob -nocase -- $what {
        "peer*" {
            return $Connection(peername)
        }
        "sockname" -
        "name" {
            return $Connection(sockname)
        }
        "close*" {
            return [expr {$Connection(state) eq "CLOSED"}]
        }
        "client" {
            return [string is false $Connection(server)]
        }
        "server" {
            return [string is true $Connection(server)]
        }
        "type" {
            return [expr {[string is true $Connection(server)]?\
			      "server":"client"}]
        }
        "handler" {
            return $Connection(handler)
        }
	"state" {
	    return $Connection(state)
	}
        default {
            ThrowError "$what is not a known information piece for a websocket"
        }
    }
    return "";  # Never reached
}


# ::websocket::find -- Find an existing websocket
#
#       Look among existing websockets for the ones that match the
#       hostname and port number filters passed as parameters.  This
#       lookup takes the remote end into account.
#
# Arguments:
#	host	hostname filter, will also be tried against IP.
#	port	port filter
#
# Results:
#       List of matching existing websockets.
#
# Side Effects:
#       None.
proc ::websocket::find { { host * } { port * } } {
    variable WS
    variable log

    set socks [list]
    foreach varname [::info vars [namespace current]::Connection_*] {
        upvar \#0 $varname Connection
        foreach {ip hst prt} $Connection(peername) break
        if { ([string match $host $ip] || [string match $host $hst]) \
                 && [string match $port $prt] } {
            lappend socks $Connection(sock)
        }
    }

    return $socks
}


# ::websocket::configure -- Configure an existing websocket.
#
#       Takes a number of dash-led options to configure the behaviour
#       of an existing websocket.  The recognised options are:
#       -keepalive  The frequency of the keepalive pings.
#       -ping       The text sent during pings.
#
# Arguments:
#	sock	WebSocket that was taken over or created by this library
#	args	Dash-led options and their (new) value.
#
# Results:
#       None.
#
# Side Effects:
#       None.
proc ::websocket::configure { sock args } {
    variable WS
    variable log

    set varname [namespace current]::Connection_$sock
    if { ! [info exists $varname] } {
	${log}::warn "$sock is not a WebSocket connection anymore"
	ThrowError "$sock is not a WebSocket"
    }
    upvar \#0 $varname Connection

    foreach { k v } $args {
	set allowed 0
	foreach opt {k* p*} {
	    if { [string match -nocase $opt [string trimleft $k -]] } {
		set allowed 1
	    }
	}
	if { ! $allowed } {
	    ThrowError "$k is not a recognised option"
	}
	switch -nocase -glob -- [string trimleft $k -] {
	    k* {
		# Change keepalive
		set Connection(-keepalive) $v
		Liveness $sock;  # Change at once.
	    }
	    p* {
		# Change ping, i.e. text used during the automated pings.
		set Connection(-ping) $v
	    }
	}
    }
}

# ::websocket::sec-websocket-accept -- Construct Sec-Websocket-Accept field value.
#
#       Construct the value for the Sec-Websocket-Accept header field, as
#       defined by (RFC6455 4.2.2.5.4).
#
#       See <http://tools.ietf.org/html/rfc6455#section-4.2.2>.
#
# Arguments:
#       key     The value of the Sec-Websocket-Key header field in the client's
#               handshake.
#
# Results:
#       The value for the Sec-Websocket-Accept header field.
#
# Side Effects:
#       None.
proc ::websocket::sec-websocket-accept { key } {
    variable WS
    set sec ${key}$WS(ws_magic)
    return [::base64::encode [sha1::sha1 -bin $sec]]
}

# ::websocket::SplitCommaSeparated -- Extract elements from comma-separated headers
#
#       Extract elements from a comma separated header's value, ignoring empty
#       elements and linear whitespace.
#
#       See <http://tools.ietf.org/html/rfc7230#section-7>.
#
# Arguments:
#       value   A header's value, consisting of a comma separated list of
#               elements.
#
# Results:
#       A list of values.
#
# Side Effects:
#       None.
proc ::websocket::SplitCommaSeparated { csl } {
    variable WS
    set r [list]
    foreach e [split $csl ,] {
	# Trim OWS.
	set v [string trim $e $WS(whitespace)]
	# There might be empty elements.
	if {"" ne $v} {
	    lappend r $v
	}
    }
    return $r
}

# ::websocket::ASCIILowercase
#
#       Convert a string to ASCII lowercase.
#
#       See <http://tools.ietf.org/html/rfc6455#section-2.1>.
#
# Arguments:
#       str   The string to convert
#
# Results:
#       The string converted to ASCII lowercase.
#
# Side Effects:
#       None.
proc ::websocket::ASCIILowercase { str } {
    variable WS
    return [string map $WS(lowercase) $str]
}


# ::websocket::AddToken
#
#       Ensures a token is included in hdr's header field value.
#
# Arguments:
#       hdrsName Name of an array variable on caller's scope whose
#                keys are header names and values are header values.
#       hdr      Header name, matched case-insensitively.
#       token    Token to include.
#
# Results:
#       Nothing.
#
# Side Effects:
#       Modifies variable named hdrsName in caller's scope.
proc ::websocket::AddToken { hdrsName hdr token } {
    ::upvar 1 $hdrsName hdrs;
    set hdrname [lsearch -exact -nocase -inline [array names hdrs] $hdr]
    if {"" ne $hdrname} {
	append hdrs($hdrname) ", $token"
    } else {
	set hdrs($hdr) $token
    }
}

# ::websocket::ThrowError
#
#       Consistent error reporting. All errors from the WebSocket
#       library have the word WEBSOCKET as the first element in the
#       -errorcode list.
#
# Arguments:
#       msg             Error message.
#       ?errorcodes...? Optional. Additional error codes.
#
# Results:
#       An error return value to the caller of the caller.
#
# Side Effects:
#       None.
proc ::websocket::ThrowError {msg args} {
    return \
	-level 2 \
	-code error \
	-errorcode [list WEBSOCKET {*}$args] \
	$msg;
}

package provide websocket 1.4
