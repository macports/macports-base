# pop3.tcl --
#
#	POP3 mail client package, written in pure Tcl.
#	Some concepts borrowed from "frenchie", a POP3
#	mail client utility written by Scott Beasley.
#
# Copyright (c) 2000 by Ajuba Solutions.
# portions Copyright (c) 2000 by Scott Beasley
# portions Copyright (c) 2010-2012 Andreas Kupries
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.5
package require cmdline
package require log
package provide pop3 1.10

namespace eval ::pop3 {

    # The state variable remembers information about the open pop3
    # connection. It is indexed by channel id. The information is
    # a keyed list, with keys "msex" and "retr_mode". The value
    # associated with "msex" is boolean, a true value signals that the
    # server at the other end is MS Exchange. The value associated
    # with "retr_mode" is one of {retr, list, slow}.

    # The value of "msex" influences how the translation for the
    # channel is set and is determined by the contents of the received
    # greeting. The value of "retr_mode" is initially "retr" and
    # completely determined by the first call to [retrieve]. For "list"
    # the system will use LIST before RETR to retrieve the message size.

    # The state can be influenced by options given to "open".

    variable  state
    array set state {}

}

# ::pop3::config --
#
#	Retrieve configuration of pop3 connection
#
# Arguments:
#	chan      The channel, returned by ::pop3::open
#
# Results:
#	A serialized array.

proc ::pop3::config {chan} {
    variable state
    return  $state($chan)
}

# ::pop3::close --
#
#	Close the connection to the POP3 server.
#
# Arguments:
#	chan      The channel, returned by ::pop3::open
#
# Results:
#	None.

proc ::pop3::close {chan} {
    variable state
    catch {::pop3::send $chan "QUIT"}
    unset state($chan)
    ::close $chan
    return
}

# ::pop3::delete --
#
#	Delete messages on the POP3 server.
#
# Arguments:
#	chan      The channel, returned by ::pop3::open
#       start     The first message to delete in the range.
#                 May be "next" (the next message after the last
#                 one seen, see ::pop3::last), "start" (aka 1),
#                 "end" (the last message in the spool, for 
#                 deleting only the last message).
#       end       (optional, defaults to -1) The last message
#                 to delete in the range. May be "last"
#                 (the last message viewed), "end" (the last
#                 message in the spool), or "-1" (the default,
#                 any negative number means delete only
#                 one message).
#
# Results:
#	None.
#       May throw errors from the server.

proc ::pop3::delete {chan start {end -1}} {

    variable state
    array set  cstate $state($chan)
    set count $cstate(limit)
    set last 0
    catch {set last [::pop3::last $chan]}

    if {![string is integer $start]} {
	if {[string match $start "next"]} {
	    set start $last
	    incr start
	} elseif {$start == "start"} {
	    set start 1
	} elseif {$start == "end"} {
	    set start $count
	} else {
	    error "POP3 Deletion error: Bad start index $start"
	}
    } 
    if {$start == 0} {
	set start 1
    }
    
    if {![string is integer $end]} {
	if {$end == "end"} {
	    set end $count
	} elseif {$end == "last"} {
	    set end $last
	} else {
	    error "POP3 Deletion error: Bad end index $end"
	}
    } elseif {$end < 0} {
	set end $start
    }

    if {$end > $count} {
	set end $count
    }
    
    for {set index $start} {$index <= $end} {incr index} {
	if {[catch {::pop3::send $chan "DELE $index"} errorStr]} {
	    error "POP3 DELETE ERROR: $errorStr"
	}
    }
    return {}
}

# ::pop3::last --
#
#	Gets the index of the last email read from the server.
#       Note, some POP3 servers do not support this feature,
#       in which case the value returned may always be zero,
#       or an error may be thrown.
#
# Arguments:
#	chan      The channel, returned by ::pop3::open
#
# Results:
#	The index of the last email message read, which may
#       be zero if none have been read or if the server does
#       not support this feature.
#       Server errors may be thrown, including some cases
#       when the LAST command is not supported.

proc ::pop3::last {chan} {

    if {[catch {
	    set resultStr [::pop3::send $chan "LAST"]
        } errorStr]} {
	error "POP3 LAST ERROR: $errorStr"
    }
    
    return [string trim $resultStr]
}

# ::pop3::list --
#
#	Returns "scan listing" of the mailbox. If parameter msg
#       is defined, then the listing only for the given message 
#       is returned.
#
# Arguments:
#	chan        The channel open to the POP3 server.
#       msg         The message number (optional).
#
# Results:
#	If msg parameter is not given, Tcl list of scan listings in 
#       the maildrop is returned. In case msg parameter is given,
#       a list of length one containing the specified message listing
#       is returned.

proc ::pop3::list {chan {msg ""}} {
    global PopErrorNm PopErrorStr debug
 
    if {$msg == ""} {
	if {[catch {::pop3::send $chan "LIST"} errorStr]} {
	    error "POP3 LIST ERROR: $errorStr"
	}
	set msgBuffer [RetrSlow $chan]
    } else {
	# argument msg given, single-line response expected

	if {[catch {expr {0 + $msg}}]} {
	    error "POP3 LIST ERROR: malformed message number '$msg'"
	} else {
	    set msgBuffer [string trim [::pop3::send $chan "LIST $msg"]]
	}
    }
    return $msgBuffer
}

# pop3::open --
#
#	Opens a connection to a POP3 mail server.
#
# Arguments:
#       args     A list of options and values, possibly empty,
#		 followed by the regular arguments, i.e. host, user,
#		 passwd and port. The latter is optional.
#
#	host     The name or IP address of the POP3 server host.
#       user     The username to use when logging into the server.
#       passwd   The password to use when logging into the server.
#       port     (optional) The socket port to connect to, defaults
#                to port 110, the POP standard port address.
#
# Results:
#	The connection channel (a socket).
#       May throw errors from the server.

proc ::pop3::open {args} {
    variable state
    array set cstate {socketcmd ::socket msex 0 retr_mode retr limit {} stls 0 tls-callback {}}

    log::log debug "pop3::open | [join $args]"

    while {[set err [cmdline::getopt args {
	msex.arg
	retr-mode.arg
	socketcmd.arg
        stls.arg
        tls-callback.arg
    } opt arg]]} {
	if {$err < 0} {
	    return -code error "::pop3::open : $arg"
	}
	switch -exact -- $opt {
	    msex {
		if {![string is boolean $arg]} {
		    return -code error \
			    ":pop3::open : Argument to -msex has to be boolean"
		}
		set cstate(msex) $arg
	    }
	    retr-mode {
		switch -exact -- $arg {
		    retr - list - slow {
			set cstate(retr_mode) $arg
		    }
		    default {
			return -code error \
				":pop3::open : Argument to -retr-mode has to be one of retr, list or slow"
		    }
		}
	    }
	    socketcmd {
		set cstate(socketcmd) $arg
	    }
            stls {
		if {![string is boolean $arg]} {
		    return -code error \
			    ":pop3::open : Argument to -tls has to be boolean"
		}
		set cstate(stls) $arg                
            }
            tls-callback {
		set cstate(tls-callback) $arg                                
            }
	    default {
		# Can't happen
	    }
	}
    }

    if {[llength $args] > 4} {
	return -code error "To many arguments to ::pop3::open"
    }
    if {[llength $args] < 3} {
	return -code error "Not enough arguments to ::pop3::open"
    }
    foreach {host user password port} $args break
    if {$port == {}} {
	if {([lindex $cstate(socketcmd) 0] eq "tls::socket") ||
	    ([lindex $cstate(socketcmd) 0] eq "::tls::socket")} {
	    # Standard port for SSL-based pop3 connections.
	    set port 995
	} else {
	    # Standard port for any other type of connection.
	    set port 110
	}
    }

    log::log debug "pop3::open | protocol, connect to $host $port"

    # Argument processing is finally complete, now open the channel

    set chan [eval [linsert $cstate(socketcmd) end $host $port]]
    fconfigure $chan -buffering none

    log::log debug "pop3::open | connect on $chan"

    if {$cstate(msex)} {
	# We are talking to MS Exchange. Work around its quirks.
	fconfigure $chan -translation binary
    } else {
	fconfigure $chan -translation {binary crlf}
    }

    log::log debug "pop3::open | wait for greeting"

    if {[catch {::pop3::send $chan {}} errorStr]} {
	::close $chan
	return -code error "POP3 CONNECT ERROR: $errorStr"
    }

    if {0} {
	# -FUTURE- Identify MS Exchange servers
	set cstate(msex) 1

	# We are talking to MS Exchange. Work around its quirks.
	fconfigure $chan -translation binary
    }

    if {$cstate(stls)} {
        log::log debug "pop3::open | negotiating TLS on $chan"
        if {[catch {
            set capa [::pop3::capa $chan]
            log::log debug "pop3::open | Server $chan can $capa"
        } errorStr]} {
            close $chan
            return -code error "POP3 CONNECT/STLS ERROR: $errorStr"
        }

        if { [lsearch -exact $capa STLS] == -1} {
            log::log debug "pop3::open | Server $chan can't STLS"
            close $chan
            return -code error "POP CONNECT ERROR: STLS requested but not supported by server"
        }
        log::log debug "pop3::open | server can TLS on $chan"

        if {[catch {
            ::pop3::send $chan "STLS"
        } errorStr]} {
            close $chan
            return -code error "POP3 STLS ERROR: $errorStr"
        }        
        
        package require tls
        
        log::log debug "pop3::open | tls::import $chan"
        # Explicitly disable ssl2 and only allow ssl3 and tlsv1. Although the defaults
        # will work with most servers, ssl2 is really, really old and is deprecated.
        if {$cstate(tls-callback) ne ""} {
            set newchan [tls::import $chan -ssl2 0 -ssl3 1 -tls1 1 -cipher SSLv3,TLSv1 -command $cstate(tls-callback)]            
        } else {
            set newchan [tls::import $chan -ssl2 0 -ssl3 1 -tls1 1 -cipher SSLv3,TLSv1]            
        }
        
        if {[catch {
            log::log debug "pop3::open | tls::handshake $chan"
            tls::handshake $chan
        } errorStr]} {
            close $chan
            return -code error "POP3 CONNECT/TLS HANDSHAKE ERROR: $errorStr"
        }
        
        array set security [tls::status $chan]
        set sbits 0
        if { [info exists security(sbits)] } {
            set sbits $security(sbits)
        }
        if { $sbits == 0 } {
            close $chan
            return -code error "POP3 CONNECT/TLS: TLS Requested but not available"
        } elseif { $sbits < 128 } {            
            close $chan
            return -code error "POP3 CONNECT/TLS: TLS Requested but insufficient (<128bits): $sbits"
        }
        
        log::log debug "pop3::open | $chan now in $sbits bit TLS mode ($security(cipher))"
    }

    log::log debug "pop3::open | authenticate $user (*password not shown*)"

    if {[catch {
	::pop3::send $chan "USER $user"
	::pop3::send $chan "PASS $password"
    } errorStr]} {
	::close $chan
	return -code error "POP3 LOGIN ERROR: $errorStr"
    }

    # [ 833486 ] Can't delete messages one at a time ...
    # Remember the number of messages in the maildrop at the beginning
    # of the session. This gives us the highest possible number for
    # message ids later. Note that this number must not be affected
    # when deleting mails later. While the number of messages drops
    # down the limit for the message id's stays the same. The messages
    # are not renumbered before the session actually closed.

    set cstate(limit) [lindex [::pop3::status $chan] 0]

    # Remember the state.

    set state($chan) [array get cstate]

    log::log debug "pop3::open | ok ($chan)"
    return $chan
}

# ::pop3::retrieve --
#
#	Retrieve email message(s) from the server.
#
# Arguments:
#	chan      The channel, returned by ::pop3::open
#       start     The first message to retrieve in the range.
#                 May be "next" (the next message after the last
#                 one seen, see ::pop3::last), "start" (aka 1),
#                 "end" (the last message in the spool, for 
#                 retrieving only the last message).
#       end       (optional, defaults to -1) The last message
#                 to retrieve in the range. May be "last"
#                 (the last message viewed), "end" (the last
#                 message in the spool), or "-1" (the default,
#                 any negative number means retrieve only
#                 one message).
#
# Results:
#	A list containing all of the messages retrieved.
#       May throw errors from the server.

proc ::pop3::retrieve {chan start {end -1}} {
    variable state
    array set cstate $state($chan)
    
    set count $cstate(limit)
    set last 0
    catch {set last [::pop3::last $chan]}

    if {![string is integer $start]} {
	if {[string match $start "next"]} {
	    set start $last
	    incr start
	} elseif {$start == "start"} {
	    set start 1
	} elseif {$start == "end"} {
	    set start $count
	} else {
	    error "POP3 Retrieval error: Bad start index $start"
	}
    } 
    if {$start == 0} {
	set start 1
    }
    
    if {![string is integer $end]} {
	if {$end == "end"} {
	    set end $count
	} elseif {$end == "last"} {
	    set end $last
	} else {
	    error "POP3 Retrieval error: Bad end index $end"
	}
    } elseif {$end < 0} {
	set end $start
    }

    if {$end > $count} {
	set end $count
    }
    
    set result {}

    ::log::log debug "pop3 $chan retrieve $start -- $end"

    for {set index $start} {$index <= $end} {incr index} {
	switch -exact -- $cstate(retr_mode) {
	    retr {
		set sizeStr [::pop3::send $chan "RETR $index"]

		::log::log debug "pop3 $chan retrieve ($sizeStr)"

		if {[scan $sizeStr {%d %s} size dummy] < 1} {
		    # The server did not deliver the size information.
		    # Switch our mode to "list" and use the slow
		    # method this time. The next call will use LIST before
		    # RETR to get the size information. If even that fails
		    # the system will fall back to slow mode all the time.

		    ::log::log debug "pop3 $chan retrieve - no size information, go slow"

		    set cstate(retr_mode) list
		    set state($chan) [array get cstate]

		    # Retrieve in slow motion.
		    set msgBuffer [RetrSlow $chan]
		} else {
		    ::log::log debug "pop3 $chan retrieve - size information present, use fast mode"

		    set msgBuffer [RetrFast $chan $size]
		}
	    }
	    list {
		set sizeStr [::pop3::send $chan "LIST $index"]

		if {[scan $sizeStr {%d %d %s} dummy size dummy] < 2} {
		    # Not even LIST generates the necessary size information.
		    # Switch to full slow mode and don't bother anymore.

		    set cstate(retr_mode) slow
		    set state($chan) [array get cstate]

		    ::pop3::send $chan "RETR $index"

		    # Retrieve in slow motion.
		    set msgBuffer [RetrSlow $chan]
		} else {
		    # Ignore response of RETR, already know the size
		    # through LIST

		    ::pop3::send $chan "RETR $index"
		    set msgBuffer [RetrFast $chan $size]
		}
	    }
	    slow {
		# Retrieve in slow motion.

		::pop3::send $chan "RETR $index"
		set msgBuffer [RetrSlow $chan]
	    }
	}
	lappend result $msgBuffer
    }
    return $result
}

# ::pop3::RetrFast --
#
#	Fast retrieval of a message from the pop3 server.
#	Internal helper to prevent code bloat in "pop3::retrieve"
#
# Arguments:
#	chan	The channel to read the message from.
#
# Results:
#	The text of the retrieved message.

proc ::pop3::RetrFast {chan size} {
    set msgBuffer [read $chan $size]

    foreach line [split $msgBuffer \n] {
	::log::log debug "pop3 $chan fast <$line>"
    }

    # There is a small discrepance in counting octets we have to be
    # aware of. 'size' is #octets before transmission, i.e. can be
    # with one eol character, CR or LF. The channel system in binary
    # mode counts every character, and the protocol specified CRLF as
    # eol, so for every line in the message we read that many
    # characters _less_. Another factor which can cause a miscount is
    # the ".-stuffing performed by the sender. I.e. what we got now is
    # not necessarily the complete message. We have to perform slow
    # reads to get the remainder of the message. This has another
    # complication. We cannot simply check for a line containing the
    # terminating signature, simply because the point where the
    # message was broken in two might just be in between the dots of a
    # "\r\n..\r\n" sequence. We have to make sure that we do not
    # misinterpret the second part of this sequence as terminator.
    # Another possibility: "\r\n.\r\n" is broken just after the dot.
    # Then we have to ensure to not to miss the terminator entirely.

    # Sometimes the gets returns nothing, need to get the real
    # terminating "."                                    / "

    if {[string equal [string range $msgBuffer end-3 end] "\n.\r\n"]} {
	# Complete terminator found. Remove it from the message buffer.

	::log::log debug "pop3 $chan /5__"
	set msgBuffer [string range $msgBuffer 0 end-3]

    } elseif {[string equal [string range $msgBuffer end-2 end] "\n.\r"]} {
	# Complete terminator found. Remove it from the message buffer.
	# Also perform an empty read to remove the missing '\n' from
	# the channel. If we don't do this all following commands will
	# run into off-by-one (character) problems.

	::log::log debug "pop3 $chan /4__"
	set msgBuffer [string range $msgBuffer 0 end-2]
	while {[read $chan 1] != "\n"} {}

    } elseif {[string equal [string range $msgBuffer end-1 end] "\n."]} {
	# \n. at the end of the fast buffer.
	# Can be	\n.\r\n	 = Terminator
	# or		\n..\r\n = dot-stuffed single .

	log::log debug "pop3 $chan /check for cut .. or terminator sequence"

	# Idle until non-empty line encountered.
	while {[set line [gets $chan]] == ""} {}
	if {"$line" == "\r"} {
	    # Terminator already found. Note that we have to
	    # remove the partial terminator sequence from the
	    # message buffer.
	    ::log::log debug "pop3 $chan /3__ <$line>"
	    set msgBuffer [string range $msgBuffer 0 end-1]
	} else {
	    # Append line and look for the real terminator
	    append msgBuffer $line
	    ::log::log debug "pop3 $chan ____ <$line>"
	    while {[set line [gets $chan]] != ".\r"} {
		::log::log debug "pop3 $chan ____ <$line>"
		append msgBuffer $line
	    }
	    ::log::log debug "pop3 $chan /2__ <$line>"
	}
    } elseif {[string equal [string index $msgBuffer end] \n]} {
	# Line terminator (\n) found. The remainder of the mail has to
	# consist of true lines we can read directly.

	while {![string equal [set line [gets $chan]] ".\r"]} {
	    ::log::log debug "pop3 $chan ____ <$line>"
	    append msgBuffer $line
	}
	::log::log debug "pop3 $chan /1__ <$line>"
    } else {
	# Incomplete line at the end of the buffer. We complete it in
	# a single read, and then handle the remainder like the case
	# before, where we had a complete line at the end of the
	# buffer.

	set line [gets $chan]
	::log::log debug "pop3 $chan /1a_ <$line>"
	append msgBuffer $line

	::log::log debug "pop3 $chan /1b_"

	while {![string equal [set line [gets $chan]] ".\r"]} {
	    ::log::log debug "pop3 $chan ____ <$line>"
	    append msgBuffer $line
	}
	::log::log debug "pop3 $chan /1c_ <$line>"
    }

    ::log::log debug "pop3 $chan done"

    # Map both cr+lf and cr to lf to simulate auto EOL translation, then
    # unstuff .-stuffed lines.

    return [string map [::list \n.. \n.] [string map [::list \r \n] [string map [::list \r\n \n] $msgBuffer]]]
}

# ::pop3::RetrSlow --
#
#	Slow retrieval of a message from the pop3 server.
#	Internal helper to prevent code bloat in "pop3::retrieve"
#
# Arguments:
#	chan	The channel to read the message from.
#
# Results:
#	The text of the retrieved message.

proc ::pop3::RetrSlow {chan} {

    set msgBuffer ""
	
    while {1} {
	set line [string trimright [gets $chan] \r]
	::log::log debug "pop3 $chan slow $line"

	# End of the message is a line with just "."
	if {$line == "."} {
	    break
	} elseif {[string index $line 0] == "."} {
	    set line [string range $line 1 end]
	}
		
	append msgBuffer $line "\n"
    }

    return $msgBuffer
}

# ::pop3::send --
#
#	Send a command string to the POP3 server.  This is an
#       internal function, but may be used in rare cases.
#
# Arguments:
#	chan        The channel open to the POP3 server.
#       cmdstring   POP3 command string
#
# Results:
#	Result string from the POP3 server, except for the +OK tag.
#       Errors from the POP3 server are thrown.

proc ::pop3::send {chan cmdstring} {
   global PopErrorNm PopErrorStr debug

   if {$cmdstring != {}} {
       ::log::log debug "pop3 $chan >>> $cmdstring"       
       puts $chan $cmdstring
   }
   
   set popRet [string trim [gets $chan]]
   ::log::log debug "pop3 $chan <<< $popRet"

   if {[string first "+OK" $popRet] == -1} {
       error [string range $popRet 4 end]
   }

   return [string range $popRet 3 end]
}

# ::pop3::status --
#
#	Get the status of the mail spool on the POP3 server.
#
# Arguments:
#	chan      The channel, returned by ::pop3::open
#
# Results:
#	A list containing two elements, {msgCount octetSize},
#       where msgCount is the number of messages in the spool
#       and octetSize is the size (in octets, or 8 bytes) of
#       the entire spool.

proc ::pop3::status {chan} {

    if {[catch {set statusStr [::pop3::send $chan "STAT"]} errorStr]} {
	error "POP3 STAT ERROR: $errorStr"
    }

    # Dig the sent size and count info out.
    set rawStatus [split [string trim $statusStr]]
    
    return [::list [lindex $rawStatus 0] [lindex $rawStatus 1]]
}

# ::pop3::top --
#
#       Optional POP3 command (see RFC1939). Retrieves message header
#       and given number of lines from the message body.
#
# Arguments:
#	chan        The channel open to the POP3 server.
#       msg         The message number to be retrieved.
#       n           Number of lines returned from the message body.
#
# Results:
#	Text (with newlines) from the server.
#       Errors from the POP3 server are thrown.

proc ::pop3::top {chan msg n} {
    global PopErrorNm PopErrorStr debug
    
    if {[catch {::pop3::send $chan "TOP $msg $n"} errorStr]} {
	error "POP3 TOP ERROR: $errorStr"
    }

    return [RetrSlow $chan]
}

# ::pop3::uidl --
#
#	Returns "uid listing" of the mailbox. If parameter msg
#	is defined, then the listing only for the given message
#	is returned.
#
# Arguments:
#	chan        The channel open to the POP3 server.
#	msg         The message number (optional).
#
# Results:
#	If msg parameter is not given, Tcl list of uid listings in
#	the maildrop is returned. In case msg parameter is given,
#	a list of length one containing the uid of the specified
#	message listing is returned.

proc ::pop3::uidl {chan {msg ""}} {
    if {$msg == ""} {
	if {[catch {::pop3::send $chan "UIDL"} errorStr]} {
	    error "POP3 UIDL ERROR: $errorStr"
	}
	set msgBuffer [RetrSlow $chan]
    } else {
	# argument msg given, single-line response expected
	
	if {[catch {expr {0 + $msg}}]} {
	    error "POP3 UIDL ERROR: malformed message number '$msg'"
	} else {
	    set msgBuffer [string trim [::pop3::send $chan "UIDL $msg"]]
	}
    }

    return $msgBuffer
}

# ::pop3::capa --
#
#	Returns "capabilities" of the server. 
#
# Arguments:
#	chan        The channel open to the POP3 server.
#
# Results:
#	A Tcl list with the capabilities of the server.
#       UIDL, TOP, STLS are typical capabilities.


proc ::pop3::capa {chan} {
    global PopErrorNm PopErrorStr debug
 
    if {[catch {::pop3::send $chan "CAPA"} errorStr]} {
        error "POP3 CAPA ERROR: $errorStr"
    }
    set msgBuffer [string map {\r {}} [RetrSlow $chan]]
    
    return [split $msgBuffer \n]
}

