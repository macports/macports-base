# comm.tcl --
#
#	socket-based 'send'ing of commands between interpreters.
#
# %%_OSF_FREE_COPYRIGHT_%%
# Copyright (C) 1995-1998 The Open Group.   All Rights Reserved.
# (Please see the file "comm.LICENSE" that accompanied this source,
#  or http://www.opengroup.org/www/dist_client/caubweb/COPYRIGHT.free.html)
# Copyright (c) 2003-2007 ActiveState Corporation
#
# This is the 'comm' package written by Jon Robert LoVerso, placed
# into its own namespace during integration into tcllib.
#
# Note that the actual code was changed in several places (Reordered,
# eval speedup)
# 
#	comm works just like Tk's send, except that it uses sockets.
#	These commands work just like "send" and "winfo interps":
#
#		comm send ?-async? <id> <cmd> ?<arg> ...?
#		comm interps
#
#	See the manual page comm.n for further details on this package.
#
# RCS: @(#) $Id: comm.tcl,v 1.34 2010/09/15 19:48:33 andreas_kupries Exp $

package require Tcl 8.3
package require snit ; # comm::future objects.

namespace eval ::comm {
    namespace export comm comm_send

    variable  comm
    array set comm {}

    if {![info exists comm(chans)]} {
	array set comm {
	    debug 0 chans {} localhost 127.0.0.1
	    connecting,hook	1
	    connected,hook	1
	    incoming,hook	1
	    eval,hook		1
	    callback,hook	1
	    reply,hook		1
	    lost,hook		1
	    offerVers		{3 2}
	    acceptVers		{3 2}
	    defVers		2
	    defaultEncoding	"utf-8"
	    defaultSilent   0
	}
	set comm(lastport) [expr {[pid] % 32768 + 9999}]
	# fast check for acceptable versions
	foreach comm(_x) $comm(acceptVers) {
	    set comm($comm(_x),vers) 1
	}
	catch {unset comm(_x)}
    }

    # Class variables:
    #	lastport		saves last default listening port allocated
    #	debug			enable debug output
    #	chans			list of allocated channels
    #   future,fid,$fid         List of futures a specific peer is waiting for.
    #
    # Channel instance variables:
    # comm()
    #	$ch,port		listening port (our id)
    #	$ch,socket		listening socket
    #	$ch,socketcmd		command to use to create sockets.
    #   $ch,silent      boolean to indicate whether to throw error on
    #                   protocol negotiation failure
    #	$ch,local		boolean to indicate if port is local
    #	$ch,interp		interpreter to run received scripts in.
    #				If not empty we own it! = We destroy it
    #				with the channel
    #	$ch,events		List of hoks to run in the 'interp', if defined
    #	$ch,serial		next serial number for commands
    #
    #	$ch,hook,$hook		script for hook $hook
    #
    #	$ch,peers,$id		open connections to peers; ch,id=>fid
    #	$ch,fids,$fid		reverse mapping for peers; ch,fid=>id
    #	$ch,vers,$id		negotiated protocol version for id
    #	$ch,pending,$id		list of outstanding send serial numbers for id
    #
    #	$ch,buf,$fid		buffer to collect incoming data
    #	$ch,result,$serial	result value set here to wake up sender
    #	$ch,return,$serial	return codes to go along with result

    if {0} {
	# Propagate result, code, and errorCode.  Can't just eval
	# otherwise TCL_BREAK gets turned into TCL_ERROR.
	global errorInfo errorCode
	set code [catch [concat commSend $args] res]
	return -code $code -errorinfo $errorInfo -errorcode $errorCode $res
    }
}

# ::comm::comm_send --
#
#	Convenience command. Replaces Tk 'send' and 'winfo' with
#	versions using the 'comm' variants. Multiple calls are
#	allowed, only the first one will have an effect.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc ::comm::comm_send {} {
    proc send {args} {
	# Use pure lists to speed this up.
	uplevel 1 [linsert $args 0 ::comm::comm send]
    }
    rename winfo tk_winfo
    proc winfo {cmd args} {
	if {![string match in* $cmd]} {
	    # Use pure lists to speed this up ...
	    return [uplevel 1 [linsert $args 0 tk_winfo $cmd]]
	}
	return [::comm::comm interps]
    }
    proc ::comm::comm_send {} {}
}

# ::comm::comm --
#
#	See documentation for public methods of "comm".
#	This procedure is followed by the definition of
#	the public methods themselves.
#
# Arguments:
#	cmd	Invoked method
#	args	Arguments to method.
#
# Results:
#	As of the invoked method.

proc ::comm::comm {cmd args} {
    set method [info commands ::comm::comm_cmd_$cmd*]

    if {[llength $method] == 1} {
	set chan ::comm::comm; # passed to methods
	return [uplevel 1 [linsert $args 0 $method $chan]]
    } else {
	foreach c [info commands ::comm::comm_cmd_*] {
	    # remove ::comm::comm_cmd_
	    lappend cmds [string range $c 17 end]
	}
        return -code error "unknown subcommand \"$cmd\":\
		must be one of [join [lsort $cmds] {, }]"
    }
}

proc ::comm::comm_cmd_connect {chan args} {
    uplevel 1 [linsert $args 0 [namespace current]::commConnect $chan]
}
proc ::comm::comm_cmd_self {chan args} {
    variable comm
    return $comm($chan,port)
}
proc ::comm::comm_cmd_channels {chan args} {
    variable comm
    return $comm(chans)
}
proc ::comm::comm_cmd_configure {chan args} {
    uplevel 1 [linsert $args 0 [namespace current]::commConfigure $chan 0]
}
proc ::comm::comm_cmd_ids {chan args} {
    variable comm
    set res $comm($chan,port)
    foreach {i id} [array get comm $chan,fids,*] {lappend res $id}
    return $res
}
interp alias {} ::comm::comm_cmd_interps {} ::comm::comm_cmd_ids
proc ::comm::comm_cmd_remoteid {chan args} {
    variable comm
    if {[info exists comm($chan,remoteid)]} {
	set comm($chan,remoteid)
    } else {
	return -code error "No remote commands processed yet"
    }
}
proc ::comm::comm_cmd_debug {chan bool} {
    variable comm
    return [set comm(debug) [string is true -strict $bool]]
}

# ### ### ### ######### ######### #########
## API: Setup async result generation for a remotely invoked command.

# (future,fid,<fid>) -> list (future)
# (current,async)    -> bool (default 0) 
# (current,state)    -> list (chan fid cmd ser)

proc ::comm::comm_cmd_return_async {chan} {
    variable comm

    if {![info exists comm(current,async)]} {
	return -code error "No remote commands processed yet"
    }
    if {$comm(current,async)} {
	# Return the same future which were generated by the first
	# call.
	return $comm(current,state)
    }

    foreach {cmdchan cmdfid cmd ser} $comm(current,state) break

    # Assert that the channel performing the request and the channel
    # the current command came in are identical. Panic if not.

    if {![string equal $chan $cmdchan]} {
	return -code error "Internal error: Trying to activate\
		async return for a command on a different channel"
    }

    # Establish the future for the command and return a handle for
    # it. Remember the outstanding futures for a peer, so that we can
    # cancel them if the peer is lost before the promise implicit in
    # the future is redeemed.

    set future [::comm::future %AUTO% $chan $cmdfid $cmd $ser]

    lappend comm(future,fid,$cmdfid) $future
    set     comm(current,state)      $future

    # Mark the current command as using async result return. We do
    # this last to ensure that all errors in this method are reported
    # through the regular channels.

    set comm(current,async) 1

    return $future
}

# hook --
#
#	Internal command. Implements 'comm hook'.
#
# Arguments:
#	hook	hook to modify
#	script	Script to add/remove to/from the hook
#
# Results:
#	None.
#
proc ::comm::comm_cmd_hook {chan hook {script +}} {
    variable comm
    if {![info exists comm($hook,hook)]} {
	return -code error "Unknown hook invoked"
    }
    if {!$comm($hook,hook)} {
	return -code error "Unimplemented hook invoked"
    }
    if {[string equal + $script]} {
	if {[catch {set comm($chan,hook,$hook)} ret]} {
	    return
	}
	return $ret
    }
    if {[string match +* $script]} {
	append comm($chan,hook,$hook) \n [string range $script 1 end]
    } else {
	set comm($chan,hook,$hook) $script
    }
    return
}

# abort --
#
#	Close down all peer connections.
#	Implements the 'comm abort' method.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc ::comm::comm_cmd_abort {chan} {
    variable comm

    foreach pid [array names comm $chan,peers,*] {
	commLostConn $chan $comm($pid) "Connection aborted by request"
    }
}

# destroy --
#
#	Destroy the channel invoking it.
#	Implements the 'comm destroy' method.
#
# Arguments:
#	None.
#
# Results:
#	None.
#
proc ::comm::comm_cmd_destroy {chan} {
    variable comm
    catch {close $comm($chan,socket)}
    comm_cmd_abort $chan
    if {$comm($chan,interp) != {}} {
	interp delete $comm($chan,interp)
    }
    catch {unset comm($chan,port)}
    catch {unset comm($chan,local)}
    catch {unset comm($chan,silent)}
    catch {unset comm($chan,interp)}
    catch {unset comm($chan,events)}
    catch {unset comm($chan,socket)}
    catch {unset comm($chan,socketcmd)}
    catch {unset comm($chan,remoteid)}
    unset comm($chan,serial)
    unset comm($chan,chan)
    unset comm($chan,encoding)
    unset comm($chan,listen)
    # array unset would have been nicer, but is not available in
    # 8.2/8.3
    foreach pattern {hook,* interp,* vers,*} {
	foreach k [array names comm $chan,$pattern] {unset comm($k)}
    }
    set pos [lsearch -exact $comm(chans) $chan]
    set comm(chans) [lreplace $comm(chans) $pos $pos]
    if {
	![string equal ::comm::comm $chan] &&
	![string equal [info proc $chan] ""]
    } {
	rename $chan {}
    }
    return
}

# shutdown --
#
#	Close down a peer connection.
#	Implements the 'comm shutdown' method.
#
# Arguments:
#	id	Reference to the remote interp
#
# Results:
#	None.
#
proc ::comm::comm_cmd_shutdown {chan id} {
    variable comm

    if {[info exists comm($chan,peers,$id)]} {
	commLostConn $chan $comm($chan,peers,$id) \
	    "Connection shutdown by request"
    }
}

# new --
#
#	Create a new comm channel/instance.
#	Implements the 'comm new' method.
#
# Arguments:
#	ch	Name of the new channel
#	args	Configuration, in the form of -option value pairs.
#
# Results:
#	None.
#
proc ::comm::comm_cmd_new {chan ch args} {
    variable comm

    if {[lsearch -exact $comm(chans) $ch] >= 0} {
	return -code error "Already existing channel: $ch"
    }
    if {([llength $args] % 2) != 0} {
	return -code error "Must have an even number of config arguments"
    }
    # ensure that the new channel name is fully qualified
    set ch ::[string trimleft $ch :]
    if {[string equal ::comm::comm $ch]} {
	# allow comm to be recreated after destroy
    } elseif {[string equal $ch [info commands $ch]]} {
	return -code error "Already existing command: $ch"
    } else {
	# Create the new channel with fully qualified proc name
	proc $ch {cmd args} {
	    set method [info commands ::comm::comm_cmd_$cmd*]

	    if {[llength $method] == 1} {
		# this should work right even if aliased
		# it is passed to methods to identify itself
		set chan [namespace origin [lindex [info level 0] 0]]
		return [uplevel 1 [linsert $args 0 $method $chan]]
	    } else {
		foreach c [info commands ::comm::comm_cmd_*] {
		    # remove ::comm::comm_cmd_
		    lappend cmds [string range $c 17 end]
		}
		return -code error "unknown subcommand \"$cmd\":\
			must be one of [join [lsort $cmds] {, }]"
	    }
	}
    }
    lappend comm(chans) $ch
    set chan $ch
    set comm($chan,serial) 0
    set comm($chan,chan)   $chan
    set comm($chan,port)   0
    set comm($chan,listen) 0
    set comm($chan,socket) ""
    set comm($chan,local)  1
    set comm($chan,silent)   $comm(defaultSilent)
    set comm($chan,encoding) $comm(defaultEncoding)
    set comm($chan,interp)   {}
    set comm($chan,events)   {}
    set comm($chan,socketcmd) ::socket

    if {[llength $args] > 0} {
	if {[catch [linsert $args 0 commConfigure $chan 1] err]} {
	    comm_cmd_destroy $chan
	    return -code error $err
	}
    }
    return $chan
}

# send --
#
#	Send command to a specified channel.
#	Implements the 'comm send' method.
#
# Arguments:
#	args	see inside
#
# Results:
#	varies.
#
proc ::comm::comm_cmd_send {chan args} {
    variable comm

    set cmd send

    # args = ?-async | -command command? id cmd ?arg arg ...?
    set i 0
    set opt [lindex $args $i]
    if {[string equal -async $opt]} {
	set cmd async
	incr i
    } elseif {[string equal -command $opt]} {
	set cmd command
	set callback [lindex $args [incr i]]
	incr i
    }
    # args = id cmd ?arg arg ...?

    set id [lindex $args $i]
    incr i
    set args [lrange $args $i end]

    if {![info complete $args]} {
	return -code error "Incomplete command"
    }
    if {![llength $args]} {
	return -code error \
		"wrong # args: should be \"send ?-async? id arg ?arg ...?\""
    }
    if {[catch {commConnect $chan $id} fid]} {
	return -code error "Connect to remote failed: $fid"
    }

    set ser [incr comm($chan,serial)]
    # This is unneeded - wraps from 2147483647 to -2147483648
    ### if {$comm($chan,serial) == 0x7fffffff} {set comm($chan,serial) 0}

    commDebug {puts stderr "<$chan> send <[list [list $cmd $ser $args]]>"}

    # The double list assures that the command is a single list when read.
    puts  $fid [list [list $cmd $ser $args]]
    flush $fid

    commDebug {puts stderr "<$chan> sent"}

    # wait for reply if so requested

    if {[string equal command $cmd]} {
	# In this case, don't wait on the command result.  Set the callback
	# in the return and that will be invoked by the result.
	lappend comm($chan,pending,$id) [list $ser callback]
	set comm($chan,return,$ser) $callback
	return $ser
    } elseif {[string equal send $cmd]} {
	upvar 0 comm($chan,pending,$id) pending	;# shorter variable name

	lappend pending $ser
	set comm($chan,return,$ser) ""		;# we're waiting

	commDebug {puts stderr "<$chan> --<<waiting $ser>>--"}
	vwait ::comm::comm($chan,result,$ser)

	# if connection was lost, pending is gone
	if {[info exists pending]} {
	    set pos [lsearch -exact $pending $ser]
	    set pending [lreplace $pending $pos $pos]
	}

	commDebug {
	    puts stderr "<$chan> result\
		    <$comm($chan,return,$ser);$comm($chan,result,$ser)>"
	}

	array set return $comm($chan,return,$ser)
	unset comm($chan,return,$ser)
	set thisres $comm($chan,result,$ser)
	unset comm($chan,result,$ser)
	switch -- $return(-code) {
	    "" - 0 {return $thisres}
	    1 {
		return  -code $return(-code) \
			-errorinfo $return(-errorinfo) \
			-errorcode $return(-errorcode) \
			$thisres
	    }
	    default {return -code $return(-code) $thisres}
	}
    }
}

###############################################################################

# ::comm::commDebug --
#
#	Internal command. Conditionally executes debugging
#	statements. Currently this are only puts commands logging the
#	various interactions. These could be replaced with calls into
#	the 'log' module.
#
# Arguments:
#	arg	Tcl script to execute.
#
# Results:
#	None.

proc ::comm::commDebug {cmd} {
    variable comm
    if {$comm(debug)} {
	uplevel 1 $cmd
    }
}

# ::comm::commConfVars --
#
#	Internal command. Used to declare configuration options.
#
# Arguments:
#	v	Name of configuration option.
#	t	Default value.
#
# Results:
#	None.

proc ::comm::commConfVars {v t} {
    variable comm
    set comm($v,var) $t
    set comm(vars) {}
    foreach c [array names comm *,var] {
	lappend comm(vars) [lindex [split $c ,] 0]
    }
    return
}
::comm::commConfVars port     p
::comm::commConfVars local    b
::comm::commConfVars listen   b
::comm::commConfVars socket   ro
::comm::commConfVars socketcmd socketcmd
::comm::commConfVars chan     ro
::comm::commConfVars serial   ro
::comm::commConfVars encoding enc
::comm::commConfVars silent   b
::comm::commConfVars interp   interp
::comm::commConfVars events   ev

# ::comm::commConfigure --
#
#	Internal command. Implements 'comm configure'.
#
# Arguments:
#	force	Boolean flag. If set the socket is reinitialized.
#	args	New configuration, as -option value pairs.
#
# Results:
#	None.

proc ::comm::commConfigure {chan {force 0} args} {
    variable comm

    # query
    if {[llength $args] == 0} {
	foreach v $comm(vars) {lappend res -$v $comm($chan,$v)}
	return $res
    } elseif {[llength $args] == 1} {
	set arg [lindex $args 0]
	set var [string range $arg 1 end]
	if {![string match -* $arg] || ![info exists comm($var,var)]} {
	    return -code error "Unknown configuration option: $arg"
	}
	return $comm($chan,$var)
    }

    # set
    set opt 0
    foreach arg $args {
	incr opt
	if {[info exists skip]} {unset skip; continue}
	set var [string range $arg 1 end]
	if {![string match -* $arg] || ![info exists comm($var,var)]} {
	    return -code error "Unknown configuration option: $arg"
	}
	set optval [lindex $args $opt]
	switch $comm($var,var) {
	    ev {
		if {![string equal  $optval ""]} {
		    set err 0
		    if {[catch {
			foreach ev $optval {
			    if {[lsearch -exact {connecting connected incoming eval callback reply lost} $ev] < 0} {
				set err 1
				break
			    }
			}
		    }]} {
			set err 1
		    }
		    if {$err} {
			return -code error \
				"Non-event to configuration option: -$var"
		    }
		}
		# FRINK: nocheck
		set $var $optval
		set skip 1
	    }
	    interp {
		if {
		    ![string equal  $optval ""] &&
		    ![interp exists $optval]
		} {
		    return -code error \
			    "Non-interpreter to configuration option: -$var"
		}
		# FRINK: nocheck
		set $var $optval
		set skip 1
	    }
	    b {
		# FRINK: nocheck
		set $var [string is true -strict $optval]
		set skip 1
	    }
	    v {
		# FRINK: nocheck
		set $var $optval
		set skip 1
	    }
	    p {
		if {
		    ![string equal $optval ""] &&
		    ![string is integer $optval]
		} {
		    return -code error \
			"Non-port to configuration option: -$var"
		}
		# FRINK: nocheck
		set $var $optval
		set skip 1
	    }
	    i {
		if {![string is integer $optval]} {
		    return -code error \
			"Non-integer to configuration option: -$var"
		}
		# FRINK: nocheck
		set $var $optval
		set skip 1
	    }
	    enc {
		# to configure encodings, we will need to extend the
		# protocol to allow for handshaked encoding changes
		return -code error "encoding not configurable"
		if {[lsearch -exact [encoding names] $optval] == -1} {
		    return -code error \
			"Unknown encoding to configuration option: -$var"
		}
		set $var $optval
		set skip 1
	    }
	    ro {
		return -code error "Readonly configuration option: -$var"
	    }
	    socketcmd {
		if {$optval eq {}} {
		    return -code error \
			"Non-command to configuration option: -$var"
		}

		set $var $optval
		set skip 1
	    }
	}
    }
    if {[info exists skip]} {
	return -code error "Missing value for option: $arg"
    }

    foreach var {port listen local socketcmd} {
	# FRINK: nocheck
	if {[info exists $var] && [set $var] != $comm($chan,$var)} {
	    incr force
	    # FRINK: nocheck
	    set comm($chan,$var) [set $var]
	}
    }

    foreach var {silent interp events} {
	# FRINK: nocheck
	if {[info exists $var] && ([set $var] != $comm($chan,$var))} {
	    # FRINK: nocheck
	    set comm($chan,$var) [set ip [set $var]]
	    if {[string equal $var "interp"] && ($ip != "")} {
		# Interrogate the interp about its capabilities.
		#
		# Like: set, array set, uplevel present ?
		# Or:   The above, hidden ?
		#
		# This is needed to decide how to execute hook scripts
		# and regular scripts in this interpreter.
		set comm($chan,interp,set)  [Capability $ip set]
		set comm($chan,interp,aset) [Capability $ip array]
		set comm($chan,interp,upl)  [Capability $ip uplevel]
	    }
	}
    }

    if {[info exists encoding] &&
	![string equal $encoding $comm($chan,encoding)]} {
	# This should not be entered yet
	set comm($chan,encoding) $encoding
	fconfigure $comm($chan,socket) -encoding $encoding
	foreach {i sock} [array get comm $chan,peers,*] {
	    fconfigure $sock -encoding $encoding
	}
    }

    # do not re-init socket
    if {!$force} {return ""}

    # User is recycling object, possibly to change from local to !local
    if {[info exists comm($chan,socket)]} {
	comm_cmd_abort $chan
	catch {close $comm($chan,socket)}
	unset comm($chan,socket)
    }

    set comm($chan,socket) ""
    if {!$comm($chan,listen)} {
	set comm($chan,port) 0
	return ""
    }

    if {[info exists port] && [string equal "" $comm($chan,port)]} {
	set nport [incr comm(lastport)]
    } else {
	set userport 1
	set nport $comm($chan,port)
    }
    while {1} {
	set cmd [list $comm($chan,socketcmd) -server [list ::comm::commIncoming $chan]]
	if {$comm($chan,local)} {
	    lappend cmd -myaddr $comm(localhost)
	}
	lappend cmd $nport
	if {![catch $cmd ret]} {
	    break
	}
	if {[info exists userport] || ![string match "*already in use" $ret]} {
	    # don't eradicate the class
	    if {
		![string equal ::comm::comm $chan] &&
		![string equal [info proc $chan] ""]
	    } {
		rename $chan {}
	    }
	    return -code error $ret
	}
	set nport [incr comm(lastport)]
    }
    set comm($chan,socket) $ret
    fconfigure $ret -translation lf -encoding $comm($chan,encoding)

    # If port was 0, system allocated it for us
    set comm($chan,port) [lindex [fconfigure $ret -sockname] 2]
    return ""
}

# ::comm::Capability --
#
#	Internal command. Interogate an interp for
#	the commands needed to execute regular and
#	hook scripts.

proc ::comm::Capability {interp cmd} {
    if {[lsearch -exact [interp hidden $interp] $cmd] >= 0} {
	# The command is present, although hidden.
	return hidden
    }

    # The command is not a hidden command. Use info to determine if it
    # is present as regular command. Note that the 'info' command
    # itself might be hidden.

    if {[catch {
	set has [llength [interp eval $interp [list info commands $cmd]]]
    }] && [catch {
	set has [llength [interp invokehidden $interp info commands $cmd]]
    }]} {
	# Unable to interogate the interpreter in any way. Assume that
	# the command is not present.
	set has 0
    }
    return [expr {$has ? "ok" : "no"}]
}

# ::comm::commConnect --
#
#	Internal command. Called to connect to a remote interp
#
# Arguments:
#	id	Specification of the location of the remote interp.
#		A list containing either one or two elements.
#		One element = port, host is localhost.
#		Two elements = port and host, in this order.
#
# Results:
#	fid	channel handle of the socket the connection goes through.

proc ::comm::commConnect {chan id} {
    variable comm

    commDebug {puts stderr "<$chan> commConnect $id"}

    # process connecting hook now
    CommRunHook $chan connecting

    if {[info exists comm($chan,peers,$id)]} {
	return $comm($chan,peers,$id)
    }
    if {[lindex $id 0] == 0} {
	return -code error "Remote comm is anonymous; cannot connect"
    }

    if {[llength $id] > 1} {
	set host [lindex $id 1]
    } else {
	set host $comm(localhost)
    }
    set port [lindex $id 0]
    set fid [$comm($chan,socketcmd) $host $port]

    # process connected hook now
    if {[catch {
	CommRunHook $chan connected
    } err]} {
	global  errorInfo
	set ei $errorInfo
	close $fid
	error $err $ei
    }

    # commit new connection
    commNewConn $chan $id $fid

    # send offered protocols versions and id to identify ourselves to remote
    puts $fid [list $comm(offerVers) $comm($chan,port)]
    set comm($chan,vers,$id) $comm(defVers)		;# default proto vers
    flush  $fid
    return $fid
}

# ::comm::commIncoming --
#
#	Internal command. Called for an incoming new connection.
#	Handles connection setup and initialization.
#
# Arguments:
#	chan	logical channel handling the connection.
#	fid	channel handle of the socket running the connection.
#	addr	ip address of the socket channel 'fid'
#	remport	remote port for the socket channel 'fid'
#
# Results:
#	None.

proc ::comm::commIncoming {chan fid addr remport} {
    variable comm

    commDebug {puts stderr "<$chan> commIncoming $fid $addr $remport"}

    # process incoming hook now
    if {[catch {
	CommRunHook $chan incoming
    } err]} {
	global errorInfo
	set ei $errorInfo
	close $fid
	error $err $ei
    }

    # Wait for offered version, without blocking the entire system.
    # Bug 3066872. For a Tcl 8.6 implementation consider use of
    # coroutines to hide the CSP and properly handle everything
    # event based.

    fconfigure $fid -blocking 0
    fileevent  $fid readable [list ::comm::commIncomingOffered $chan $fid $addr $remport]
    return
}

proc ::comm::commIncomingOffered {chan fid addr remport} {
    variable comm

    # Check if we have a complete line.
    if {[gets $fid protoline] < 0} {
	#commDebug {puts stderr "commIncomingOffered: no data"}
	if {[eof $fid]} {
	    commDebug {puts stderr "commIncomingOffered: eof on fid=$fid"}
	    catch {
		close $fid
	    }
	}
	return
    }

    # Protocol version line has been received, disable event handling
    # again.
    fileevent $fid readable {}
    fconfigure $fid -blocking 1

    # a list of offered proto versions is the first word of first line
    # remote id is the second word of first line
    # rest of first line is ignored

    set offeredvers [lindex $protoline 0]
    set remid       [lindex $protoline 1]

    commDebug {puts stderr "<$chan> offered <$protoline>"}

    # use the first supported version in the offered list
    foreach v $offeredvers {
	if {[info exists comm($v,vers)]} {
	    set vers $v
	    break
	}
    }
    if {![info exists vers]} {
	close $fid
	if {[info exists comm($chan,silent)] && 
	    [string is true -strict $comm($chan,silent)]} then return
	error "Unknown offered protocols \"$protoline\" from $addr/$remport"
    }

    # If the remote host addr isn't our local host addr,
    # then add it to the remote id.
    if {[string equal [lindex [fconfigure $fid -sockname] 0] $addr]} {
	set id $remid
    } else {
	set id [list $remid $addr]
    }

    # Detect race condition of two comms connecting to each other
    # simultaneously.  It is OK when we are talking to ourselves.

    if {[info exists comm($chan,peers,$id)] && $id != $comm($chan,port)} {

	puts stderr "commIncoming race condition: $id"
	puts stderr "peers=$comm($chan,peers,$id) port=$comm($chan,port)"

	# To avoid the race, we really want to terminate one connection.
	# However, both sides are committed to using it.
	# commConnect needs to be synchronous and detect the close.
	# close $fid
	# return $comm($chan,peers,$id)
    }

    # Make a protocol response.  Avoid any temptation to use {$vers > 2}
    # - this forces forwards compatibility issues on protocol versions
    # that haven't been invented yet.  DON'T DO IT!  Instead, test for
    # each supported version explicitly.  I.e., {$vers >2 && $vers < 5} is OK.

    switch $vers {
	3 {
	    # Respond with the selected version number
	    puts  $fid [list [list vers $vers]]
	    flush $fid
	}
    }

    # commit new connection
    commNewConn $chan $id $fid
    set comm($chan,vers,$id) $vers
}

# ::comm::commNewConn --
#
#	Internal command. Common new connection processing
#
# Arguments:
#	id	Reference to the remote interp
#	fid	channel handle of the socket running the connection.
#
# Results:
#	None.

proc ::comm::commNewConn {chan id fid} {
    variable comm

    commDebug {puts stderr "<$chan> commNewConn $id $fid"}

    # There can be a race condition two where comms connect to each other
    # simultaneously.  This code favors our outgoing connection.

    if {[info exists comm($chan,peers,$id)]} {
	# abort this connection, use the existing one
	# close $fid
	# return -code return $comm($chan,peers,$id)
    } else {
	set comm($chan,pending,$id) {}
    	set comm($chan,peers,$id) $fid
    }
    set comm($chan,fids,$fid) $id
    fconfigure $fid -translation lf -encoding $comm($chan,encoding) -blocking 0
    fileevent $fid readable [list ::comm::commCollect $chan $fid]
}

# ::comm::commLostConn --
#
#	Internal command. Called to tidy up a lost connection,
#	including aborting ongoing sends. Each send should clean
#	themselves up in pending/result.
#
# Arguments:
#	fid	Channel handle of the socket which got lost.
#	reason	Message describing the reason of the loss.
#
# Results:
#	reason

proc ::comm::commLostConn {chan fid reason} {
    variable comm

    commDebug {puts stderr "<$chan> commLostConn $fid $reason"}

    catch {close $fid}

    set id $comm($chan,fids,$fid)

    # Invoke the callbacks of all commands which have such and are
    # still waiting for a response from the lost peer. Use an
    # appropriate error.

    foreach s $comm($chan,pending,$id) {
	if {[string equal "callback" [lindex $s end]]} {
	    set ser [lindex $s 0]
	    if {[info exists comm($chan,return,$ser)]} {
		set args [list -id       $id \
			      -serial    $ser \
			      -chan      $chan \
			      -code      -1 \
			      -errorcode NONE \
			      -errorinfo "" \
			      -result    $reason \
			     ]
		if {[catch {uplevel \#0 $comm($chan,return,$ser) $args} err]} {
		    commBgerror $err
		}
	    }
	} else {
	    set comm($chan,return,$s) {-code error}
	    set comm($chan,result,$s) $reason
	}
    }
    unset comm($chan,pending,$id)
    unset comm($chan,fids,$fid)
    catch {unset comm($chan,peers,$id)}		;# race condition
    catch {unset comm($chan,buf,$fid)}

    # Cancel all outstanding futures for requests which were made by
    # the lost peer, if there are any. This does not destroy
    # them. They will stay around until the long-running operations
    # they belong too kill them.

    CancelFutures $fid

    # process lost hook now
    catch {CommRunHook $chan lost}

    return $reason
}

proc ::comm::commBgerror {err} {
    # SF Tcllib Patch #526499
    # (See http://sourceforge.net/tracker/?func=detail&aid=526499&group_id=12883&atid=312883
    #  for initial request and comments)
    #
    # Error in async call. Look for [bgerror] to report it. Same
    # logic as in Tcl itself. Errors thrown by bgerror itself get
    # reported to stderr.
    if {[catch {bgerror $err} msg]} {
	puts stderr "bgerror failed to handle background error."
	puts stderr "    Original error: $err"
	puts stderr "    Error in bgerror: $msg"
	flush stderr
    }
}

# CancelFutures: Mark futures associated with a comm channel as
# expired, done when the connection to the peer has been lost. The
# marked futures will not generate result anymore. They will also stay
# around until destroyed by the script they belong to.

proc ::comm::CancelFutures {fid} {
    variable comm
    if {![info exists comm(future,fid,$fid)]} return

    commDebug {puts stderr "\tCanceling futures: [join $comm(future,fid,$fid) \
                         "\n\t                 : "]"}

    foreach future $comm(future,fid,$fid) {
	$future Cancel
    }

    unset comm(future,fid,$fid)
    return
}

###############################################################################

# ::comm::commCollect --
#
#	Internal command. Called from the fileevent to read from fid
#	and append to the buffer. This continues until we get a whole
#	command, which we then invoke.
#
# Arguments:
#	chan	logical channel collecting the data
#	fid	channel handle of the socket we collect.
#
# Results:
#	None.

proc ::comm::commCollect {chan fid} {
    variable comm
    upvar #0 comm($chan,buf,$fid) data

    # Tcl8 may return an error on read after a close
    if {[catch {read $fid} nbuf] || [eof $fid]} {
	commDebug {puts stderr "<$chan> collect/lost eof $fid = [eof $fid]"}
	commDebug {puts stderr "<$chan> collect/lost nbuf = <$nbuf>"}
	commDebug {puts stderr "<$chan> collect/lost [fconfigure $fid]"}

	fileevent $fid readable {}		;# be safe
	commLostConn $chan $fid "target application died or connection lost"
	return
    }
    append data $nbuf

    commDebug {puts stderr "<$chan> collect <$data>"}

    # If data contains at least one complete command, we will
    # be able to take off the first element, which is a list holding
    # the command.  This is true even if data isn't a well-formed
    # list overall, with unmatched open braces.  This works because
    # each command in the protocol ends with a newline, thus allowing
    # lindex and lreplace to work.
    #
    # This isn't true with Tcl8.0, which will return an error until
    # the whole buffer is a valid list.  This is probably OK, although
    # it could potentially cause a deadlock.

    # [AK] Actually no. This breaks down if the sender shoves so much
    # data at us so fast that the receiver runs into out of memory
    # before the list is fully well-formed and thus able to be
    # processed.

    while {![catch {
	set cmdrange [Word0 data]
	# word0 is essentially the pre-8.0 'lindex <list> 0', getting
	# the first word of a list, even if the remainder is not fully
	# well-formed. Slight API change, we get the char indices the
	# word is between, and a relative index to the remainder of
	# the list.
    }]} {
	# Unpack the indices, then extract the word.
	foreach {s e step} $cmdrange break
	set cmd [string range $data $s $e]
	commDebug {puts stderr "<$chan> cmd <$data>"}
	if {[string equal "" $cmd]} break
	if {[info complete $cmd]} {
	    # The word is a command, step to the remainder of the
	    # list, and delete the word we have processed.
	    incr e $step
	    set data [string range $data $e end]
	    after idle \
		    [list ::comm::commExec $chan $fid $comm($chan,fids,$fid) $cmd]
	}
    }
}

proc ::comm::Word0 {dv} {
    upvar 1 $dv data

    # data
    #
    # The string we expect to be either a full well-formed list, or a
    # well-formed list until the end of the first word in the list,
    # with non-wellformed data following after, i.e. an incomplete
    # list with a complete first word.

    if {[regexp -indices "^\\s*(\{)" $data -> bracerange]} {
	# The word is brace-quoted, starting at index 'lindex
	# bracerange 0'. We now have to find the closing brace,
	# counting inner braces, ignoring quoted braces. We fail if
	# there is no proper closing brace.

	foreach {s e} $bracerange break
	incr s ; # index of the first char after the brace.
	incr e ; # same. but this is our running index.

	set level 1
	set max [string length $data]

	while {$level} {
	    # We are looking for the first regular or backslash-quoted
	    # opening or closing brace in the string. If none is found
	    # then the word is not complete, and we abort our search.

	    # Bug 2972571: To avoid the bogus detection of
	    # backslash-quoted braces we look for double-backslashes
	    # as well and skip them. Without this a string like '{puts
	    # \\}' will incorrectly find a \} at the end, missing the
	    # end of the word.

	    if {![regexp -indices -start $e {((\\\\)|([{}])|(\\[{}]))} $data -> any dbs regular quoted]} {
		#                            ^^      ^      ^
		#                            |\\     regular \quoted
		#                            any
		return -code error "no complete word found/1"
	    }

	    foreach {ds de} $dbs     break
	    foreach {qs qe} $quoted  break
	    foreach {rs re} $regular break

	    if {$ds >= 0} {
		# Skip double-backslashes ...
		set  e $de
		incr e
		continue
	    } elseif {$qs >= 0} {
		# Skip quoted braces ...
		set  e $qe
		incr e
		continue
	    } elseif {$rs >= 0} {
		# Step one nesting level in or out.
		if {[string index $data $rs] eq "\{"} {
		    incr level
		} else {
		    incr level -1
		}
		set  e $re
		incr e
		#puts @$e
		continue
	    } else {
		return -code error "internal error"
	    }
	}

	incr e -2 ; # index of character just before the brace.
	return [list $s $e 2]

    } elseif {[regexp -indices {^\s*(\S+)\s} $data -> wordrange]} {
	# The word is a simple literal which ends at the next
	# whitespace character. Note that there has to be a whitespace
	# for us to recognize a word, for while there is no whitespace
	# behind it in the buffer the word itself may be incomplete.

	return [linsert $wordrange end 1]
    }

    return -code error "no complete word found/2"
}

# ::comm::commExec --
#
#	Internal command. Receives and executes a remote command,
#	returning the result and/or error. Unknown protocol commands
#	are silently discarded
#
# Arguments:
#	chan		logical channel collecting the data
#	fid		channel handle of the socket we collect.
#	remoteid	id of the other side.
#	buf		buffer containing the command to execute.
#
# Results:
#	None.

proc ::comm::commExec {chan fid remoteid buf} {
    variable comm

    # buffer should contain:
    #	send  # {cmd}		execute cmd and send reply with serial #
    #	async # {cmd}		execute cmd but send no reply
    #	reply # {cmd}		execute cmd as reply to serial #

    # these variables are documented in the hook interface
    set cmd [lindex $buf 0]
    set ser [lindex $buf 1]
    set buf [lrange $buf 2 end]
    set buffer [lindex $buf 0]

    # Save remoteid for "comm remoteid".  This will only be valid
    # if retrieved before any additional events occur on this channel.
    # N.B. we could have already lost the connection to remote, making
    # this id be purely informational!
    set comm($chan,remoteid) [set id $remoteid]

    # Save state for possible async result generation
    AsyncPrepare $chan $fid $cmd $ser

    commDebug {puts stderr "<$chan> exec <$cmd,$ser,$buf>"}

    switch -- $cmd {
	send - async - command {}
	callback {
	    if {![info exists comm($chan,return,$ser)]} {
	        commDebug {puts stderr "<$chan> No one waiting for serial \"$ser\""}
		return
	    }

	    # Decompose reply command to assure it only uses "return"
	    # with no side effects.

	    array set return {-code "" -errorinfo "" -errorcode ""}
	    set ret [lindex $buffer end]
	    set len [llength $buffer]
	    incr len -2
	    foreach {sw val} [lrange $buffer 1 $len] {
		if {![info exists return($sw)]} continue
		set return($sw) $val
	    }

	    catch {CommRunHook $chan callback}

	    # this wakes up the sender
	    commDebug {puts stderr "<$chan> --<<wakeup $ser>>--"}

	    # the return holds the callback command
	    # string map the optional %-subs
	    set args [list -id       $id \
			  -serial    $ser \
			  -chan      $chan \
			  -code      $return(-code) \
			  -errorcode $return(-errorcode) \
			  -errorinfo $return(-errorinfo) \
			  -result    $ret \
			 ]
	    set code [catch {uplevel \#0 $comm($chan,return,$ser) $args} err]
	    catch {unset comm($chan,return,$ser)}

	    # remove pending serial
	    upvar 0 comm($chan,pending,$id) pending
	    if {[info exists pending]} {
		set pos [lsearch -exact $pending [list $ser callback]]
		if {$pos != -1} {
		    set pending [lreplace $pending $pos $pos]
		}
	    }
	    if {$code} {
		commBgerror $err
	    }
	    return
	}
	reply {
	    if {![info exists comm($chan,return,$ser)]} {
	        commDebug {puts stderr "<$chan> No one waiting for serial \"$ser\""}
		return
	    }

	    # Decompose reply command to assure it only uses "return"
	    # with no side effects.

	    array set return {-code "" -errorinfo "" -errorcode ""}
	    set ret [lindex $buffer end]
	    set len [llength $buffer]
	    incr len -2
	    foreach {sw val} [lrange $buffer 1 $len] {
		if {![info exists return($sw)]} continue
		set return($sw) $val
	    }

	    catch {CommRunHook $chan reply}

	    # this wakes up the sender
	    commDebug {puts stderr "<$chan> --<<wakeup $ser>>--"}
	    set comm($chan,result,$ser) $ret
	    set comm($chan,return,$ser) [array get return]
	    return
	}
	vers {
	    set ::comm::comm($chan,vers,$id) $ser
	    return
	}
	default {
	    commDebug {puts stderr "<$chan> unknown command; discard \"$cmd\""}
	    return
	}
    }

    # process eval hook now
    set done 0
    set err  0
    if {[info exists comm($chan,hook,eval)]} {
	set err [catch {CommRunHook $chan eval} ret]
	commDebug {puts stderr "<$chan> eval hook res <$err,$ret>"}
	switch $err {
	    1 {
		# error
		set done 1
	    }
	    2 - 3 {
		# return / break
		set err 0
		set done 1
	    }
	}
    }

    commDebug {puts stderr "<$chan> hook(eval) done=$done, err=$err"}

    # exec command
    if {!$done} {
	commDebug {puts stderr "<$chan> exec ($buffer)"}

	# Sadly, the uplevel needs to be in the catch to access the local
	# variables buffer and ret.  These cannot simply be global because
	# commExec is reentrant (i.e., they could be linked to an allocated
	# serial number).

	if {$comm($chan,interp) == {}} {
	    # Main interpreter
	    set thecmd [concat [list uplevel \#0] $buffer]
	    set err    [catch $thecmd ret]
	} else {
	    # Redirect execution into the configured slave
	    # interpreter. The exact command used depends on the
	    # capabilities of the interpreter. A best effort is made
	    # to execute the script in the global namespace.
	    set interp $comm($chan,interp)

	    if {$comm($chan,interp,upl) == "ok"} {
		set thecmd [concat [list uplevel \#0] $buffer]
		set err [catch {interp eval $interp $thecmd} ret]
	    } elseif {$comm($chan,interp,aset) == "hidden"} {
		set thecmd [linsert $buffer 0 interp invokehidden $interp uplevel \#0]
		set err [catch $thecmd ret]
	    } else {
		set thecmd [concat [list interp eval $interp] $buffer]
		set err [catch $thecmd ret]
	    }
	}
    }

    # Check and handle possible async result generation.
    if {[AsyncCheck]} return

    commSendReply $chan $fid $cmd $ser $err $ret
    return
}

# ::comm::commSendReply --
#
#	Internal command. Executed to construct and send the reply
#	for a command.
#
# Arguments:
#	fid		channel handle of the socket we are replying to.
#	cmd		The type of request (send, command) we are replying to.
#	ser		Serial number of the request the reply is for.
#	err		result code to place into the reply.
#	ret		result value to place into the reply.
#
# Results:
#	None.

proc ::comm::commSendReply {chan fid cmd ser err ret} {
    variable comm

    commDebug {puts stderr "<$chan> res <$err,$ret> /$cmd"}

    # The double list assures that the command is a single list when read.
    if {[string equal send $cmd] || [string equal command $cmd]} {
	# The catch here is just in case we lose the target.  Consider:
	#	comm send $other comm send [comm self] exit
	catch {
	    set return [list return -code $err]
	    # send error or result
	    if {$err == 1} {
		global errorInfo errorCode
		lappend return -errorinfo $errorInfo -errorcode $errorCode
	    }
	    lappend return $ret
	    if {[string equal send $cmd]} {
		set reply reply
	    } else {
		set reply callback
	    }
	    puts  $fid [list [list $reply $ser $return]]
	    flush $fid
	}
	commDebug {puts stderr "<$chan> reply sent"}
    }

    if {$err == 1} {
	commBgerror $ret
    }
    commDebug {puts stderr "<$chan> exec complete"}
    return
}

proc ::comm::CommRunHook {chan event} {
    variable comm

    # The documentation promises the hook scripts to have access to a
    # number of internal variables. For a regular hook we simply
    # execute it in the calling level to fulfill this. When the hook
    # is redirected into an interpreter however we do a best-effort
    # copying of the variable values into the interpreter. Best-effort
    # because the 'set' command may not be available in the
    # interpreter, not even hidden.

    if {![info exists comm($chan,hook,$event)]} return
    set cmd    $comm($chan,hook,$event)
    set interp $comm($chan,interp)
    commDebug {puts stderr "<$chan> hook($event) run <$cmd>"}

    if {
	($interp != {}) &&
	([lsearch -exact $comm($chan,events) $event] >= 0)
    } {
	# Best-effort to copy the context into the interpreter for
	# access by the hook script.
	set vars   {
	    addr buffer chan cmd fid host
	    id port reason remport ret var
	}

	if {$comm($chan,interp,set) == "ok"} {
	    foreach v $vars {
		upvar 1 $v V
		if {![info exists V]} continue
		interp eval $interp [list set $v $V]
	    }
	} elseif {$comm($chan,interp,set) == "hidden"} {
	    foreach v $vars {
		upvar 1 $v V
		if {![info exists V]} continue
		interp invokehidden $interp set $v $V
	    }
	}
	upvar 1 return AV
	if {[info exists AV]} {
	    if {$comm($chan,interp,aset) == "ok"} {
		interp eval $interp [list array set return [array get AV]]
	    } elseif {$comm($chan,interp,aset) == "hidden"} {
		interp invokehidden $interp array set return [array get AV]
	    }
	}

	commDebug {puts stderr "<$chan> /interp $interp"}
	set code [catch {interp eval $interp $cmd} res]
    } else {
	commDebug {puts stderr "<$chan> /main"}
	set code [catch {uplevel 1 $cmd} res]
    }

    # Perform the return code propagation promised
    # to the hook scripts.
    switch -exact -- $code {
	0 {}
	1 {
	    return -errorinfo $::errorInfo -errorcode $::errorCode -code error $res
	}
	3 {return}
	4 {}
	default {return -code $code $res}
    }
    return
}

# ### ### ### ######### ######### #########
## Hooks to link async return and future processing into the regular
## system.

# AsyncPrepare, AsyncCheck: Initialize state information for async
# return upon start of a remote invokation, and checking the state for
# async return.

proc ::comm::AsyncPrepare {chan fid cmd ser} {
    variable comm
    set comm(current,async) 0
    set comm(current,state) [list $chan $fid $cmd $ser]
    return
}

proc ::comm::AsyncCheck {} {
    # Check if the executed command notified us of an async return. If
    # not we let the regular return processing handle the end of the
    # script. Otherwise we stop the caller from proceeding, preventing
    # a regular return.

    variable comm
    if {!$comm(current,async)} {return 0}
    return 1
}

# FutureDone: Action taken by an uncanceled future to deliver the
# generated result to the proper invoker. This also removes the future
# from the list of pending futures for the comm channel.

proc comm::FutureDone {future chan fid cmd sid rcode rvalue} {
    variable comm
    commSendReply $chan $fid $cmd $sid $rcode $rvalue

    set pos [lsearch -exact $comm(future,fid,$fid) $future]
    set comm(future,fid,$fid) [lreplace $comm(future,fid,$fid) $pos $pos]
    return
}

# ### ### ### ######### ######### #########
## Hooks to save command state across nested eventloops a remotely
## invoked command may run before finally activating async result
## generation.

# DANGER !! We have to refer to comm internals using fully-qualified
# names because the wrappers will execute in the global namespace
# after their installation.

proc ::comm::Vwait {varname} {
    variable ::comm::comm

    set hasstate [info exists comm(current,async)]
    set hasremote 0
    if {$hasstate} {
	set chan     [lindex $comm(current,state) 0]
	set async    $comm(current,async)
	set state    $comm(current,state)
	set hasremote [info exists comm($chan,remoteid)]
	if {$hasremote} {
	    set remoteid $comm($chan,remoteid)
	}
    }

    set code [catch {uplevel 1 [list ::comm::VwaitOrig $varname]} res]

    if {$hasstate} {
	set comm(current,async)  $async
	set comm(current,state)	 $state
    }
    if {$hasremote} {
	set comm($chan,remoteid) $remoteid
    }

    return -code $code $res
}

proc ::comm::Update {args} {
    variable ::comm::comm

    set hasstate [info exists comm(current,async)]
    set hasremote 0
    if {$hasstate} {
	set chan     [lindex $comm(current,state) 0]
	set async    $comm(current,async)
	set state    $comm(current,state)

	set hasremote [info exists comm($chan,remoteid)]
	if {$hasremote} {
	    set remoteid $comm($chan,remoteid)
	}
    }

    set code [catch {uplevel 1 [linsert $args 0 ::comm::UpdateOrig]} res]

    if {$hasstate} {
	set comm(current,async)  $async
	set comm(current,state)	 $state
    }
    if {$hasremote} {
	set comm($chan,remoteid) $remoteid
    }

    return -code $code $res
}

# Install the wrappers.

proc ::comm::InitWrappers {} {
    rename ::vwait       ::comm::VwaitOrig
    rename ::comm::Vwait ::vwait

    rename ::update       ::comm::UpdateOrig
    rename ::comm::Update ::update

    proc ::comm::InitWrappers {} {}
    return
}

# ### ### ### ######### ######### #########
## API: Future objects.

snit::type comm::future {
    option -command -default {}

    constructor {chan fid cmd ser} {
	set xfid  $fid
	set xcmd  $cmd
	set xser  $ser
	set xchan $chan
	return
    }

    destructor {
	if {!$canceled} {
	    return -code error \
		    "Illegal attempt to destroy unresolved future \"$self\""
	}
    }

    method return {args} {
	# Syntax:             | 0
	#       : -code x     | 2
	#       : -code x val | 3
	#       :         val | 4
	# Allowing multiple -code settings, last one is taken.

	set rcode  0
	set rvalue {}

	while {[lindex $args 0] == "-code"} {
	    set rcode [lindex $args 1]
	    set args  [lrange $args 2 end]
	}
	if {[llength $args] > 1} {
	    return -code error "wrong\#args, expected \"?-code errcode? ?result?\""
	}
	if {[llength $args] == 1} {
	    set rvalue [lindex $args 0]
	}

	if {!$canceled} {
	    comm::FutureDone $self $xchan $xfid $xcmd $xser $rcode $rvalue
	    set canceled 1
	}
	# assert: canceled == 1
	$self destroy
	return
    }

    variable xfid  {}
    variable xcmd  {}
    variable xser  {}
    variable xchan {}
    variable canceled 0

    # Internal method for use by comm channels. Marks the future as
    # expired, no peer to return a result back to.

    method Cancel {} {
	set canceled 1
	if {![llength $options(-command)]} {return}
	uplevel #0 [linsert $options(-command) end $self]
	return
    }
}

# ### ### ### ######### ######### #########
## Setup
::comm::InitWrappers

###############################################################################
#
# Finish creating "comm" using the default port for this interp.
#

if {![info exists ::comm::comm(comm,port)]} {
    if {[string equal macintosh $tcl_platform(platform)]} {
	::comm::comm new ::comm::comm -port 0 -local 0 -listen 1
	set ::comm::comm(localhost) \
	    [lindex [fconfigure $::comm::comm(::comm::comm,socket) -sockname] 0]
	::comm::comm config -local 1
    } else {
	::comm::comm new ::comm::comm -port 0 -local 1 -listen 1
    }
}

#eof
package provide comm 4.6.3.1
