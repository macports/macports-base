# pop3d.tcl --
#
#	Implementation of a pop3 server for Tcl.
#
# Copyright (c) 2002-2009 by Andreas Kupries
# Copyright (c) 2005      by Reinhard Max (-socket option)
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require md5  ; # tcllib | APOP
package require mime ; # tcllib | storage callback
package require log  ; # tcllib | tracing

package provide pop3d 1.1.0

namespace eval ::pop3d {
    # Data storage in the pop3d module
    # -------------------------------
    #
    # There's a number of bits to keep track of for each server and
    # connection managed by it.
    #
    #   port
    #	callbacks
    #	connections
    #	connection state
    #   server state
    #
    # It would quickly become unwieldy to try to keep these in arrays or lists
    # within the pop3d namespace itself.  Instead, each pop3 server will
    # get its own namespace.  Each namespace contains:
    #
    # port    - port to listen on
    # sock    - listening socket
    # authCmd - authentication callback
    # storCmd - storage callback
    # sockCmd - command prefix for opening the server socket
    # state   - state of the server (up, down, exiting)
    # conn    - map : sock -> state array
    # counter - counter for state arrays
    #
    # Per connection in a server its own state array 'connXXX'.
    #
    # id         - unique id for the connection (APOP)
    # state      - state of connection       (auth, trans, update, fail)
    # name       - user for that connection
    # storage    - storage ref for that user
    # logon      - authentication method     (empty, apop, user)
    # deleted    - list of deleted messages
    # msg        - number of messages in storage
    # remotehost - name of remote host for connection
    # remoteport - remote port for connection

    # counter is used to give a unique name for unnamed server
    variable counter 0

    # commands is the list of subcommands recognized by the server
    variable commands [list	\
	    "cget"		\
	    "configure"		\
	    "destroy"		\
	    "down"		\
	    "up"		\
	    ]

    variable version [package present pop3d]
    variable server  "tcllib/pop3d-$version"

    variable cmdMap ; array set cmdMap {
	CAPA H_capa
	USER H_user
	PASS H_pass
	APOP H_apop
	STAT H_stat
	DELE H_dele
	RETR H_retr
	TOP  H_top
	QUIT H_quit
	NOOP H_noop
	RSET H_rset
	LIST H_list
    }

    # Capabilities to be reported by the CAPA command. The list
    # contains pairs of capability strings and the connection state in
    # which they are reported. The state can be "auth", "trans", or
    # "both".
    variable capabilities \
	[list \
	     USER			both \
	     PIPELINING			both \
	     "IMPLEMENTATION $server"	trans \
	    ]
    
    # -- UIDL -- not implemented --

    # Only export one command, the one used to instantiate a new server
    namespace export new
}

# ::pop3d::new --
#
#	Create a new pop3 server with a given name; if no name is given, use
#	pop3dX, where X is a number.
#
# Arguments:
#	name	name of the pop3 server; if null, generate one.
#
# Results:
#	name	name of the pop3 server created

proc ::pop3d::new {{name ""}} {
    variable counter
    
    if { [llength [info level 0]] == 1 } {
	incr counter
	set name "pop3d${counter}"
    }

    if { ![string equal [info commands ::$name] ""] } {
	return -code error "command \"$name\" already exists, unable to create pop3 server"
    }

    # Set up the namespace
    namespace eval ::pop3d::pop3d::$name {
	variable port     110
	variable trueport 110
	variable sock     {}
	variable sockCmd  ::socket
	variable authCmd  {}
	variable storCmd  {}
	variable state    down
	variable conn     ; array set conn {}
	variable counter  0
    }

    # Create the command to manipulate the pop3 server
    interp alias {} ::$name {} ::pop3d::Pop3dProc $name

    return $name
}

##########################
# Private functions follow

# ::pop3d::Pop3dProc --
#
#	Command that processes all pop3 server object commands.
#
# Arguments:
#	name	name of the pop3 server object to manipulate.
#	args	command name and args for the command
#
# Results:
#	Varies based on command to perform

proc ::pop3d::Pop3dProc {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	return -code error "wrong # args: should be \"$name option ?arg arg ...?\""
    }
    
    # Split the args into command and args components
    if { [llength [info commands ::pop3d::_$cmd]] == 0 } {
	variable commands
	set optlist [join $commands ", "]
	set optlist [linsert $optlist "end-1" "or"]
	return -code error "bad option \"$cmd\": must be $optlist"
    }
    eval [list ::pop3d::_$cmd $name] $args
}

# ::pop3d::_up --
#
#	Start listening on the configured port.
#
# Arguments:
#	name	name of the pop3 server.
#
# Results:
#	None.

proc ::pop3d::_up {name} {
    upvar ::pop3d::pop3d::${name}::port     port
    upvar ::pop3d::pop3d::${name}::trueport trueport
    upvar ::pop3d::pop3d::${name}::state    state
    upvar ::pop3d::pop3d::${name}::sockCmd  sockCmd
    upvar ::pop3d::pop3d::${name}::sock     sock

    log::log debug "pop3d $name up"
    if {[string equal $state up]} {return}

    log::log debug "pop3d $name listening, requested port $port"

    set cmd $sockCmd
    lappend cmd -server [list ::pop3d::HandleNewConnection $name] $port
    #puts $cmd
    set s [eval $cmd]
    set trueport [lindex [fconfigure $s -sockname] 2]

    ::log::log debug "pop3d $name listening on $trueport, socket $s ([fconfigure $s -sockname])"

    set state up
    set sock  $s
    return
}

# ::pop3d::_down --
#
#	Stop listening on the configured port.
#
# Arguments:
#	name	name of the pop3 server.
#
# Results:
#	None.

proc ::pop3d::_down {name} {
    upvar ::pop3d::pop3d::${name}::state    state
    upvar ::pop3d::pop3d::${name}::sock     sock
    upvar ::pop3d::pop3d::${name}::trueport trueport
    upvar ::pop3d::pop3d::${name}::port     port

    # Ignore if server is down or exiting
    if {![string equal $state up]} {return}

    close $sock
    set state down
    set sock  {}

    set trueport $port
    return
}

# ::pop3d::_destroy --
#
#	Destroy a pop3 server.
#
# Arguments:
#	name	name of the pop3 server.
#	mode	destruction mode
#
# Results:
#	None.

proc ::pop3d::_destroy {name {mode kill}} {
    upvar ::pop3d::pop3d::${name}::conn  conn

    switch -exact -- $mode {
	kill {
	    _down $name
	    foreach c [array names conn] {
		CloseConnection $name $c
	    }

	    namespace delete ::pop3d::pop3d::$name
	    interp alias {} ::$name {}
	}
	defer {
	    if {[array size conn] > 0} {
		upvar ::pop3d::pop3d::${name}::state state

		_down $name
		set state exiting
		return
	    }
	    _destroy $name kill
	    return
	}
	default {
	    return -code error \
		    "Illegal destruction mode \"$mode\":\
		    Expected \"kill\", or \"defer\""
	}
    }
    return
}

# ::pop3d::_cget --
#
#	Query option value
#
# Arguments:
#	name	name of the pop3 server.
#
# Results:
#	None.

proc ::pop3d::_cget {name anoption} {
    switch -exact -- $anoption {
	-state {
	    upvar ::pop3d::pop3d::${name}::state state
	    return $state
	}
	-port {
	    upvar ::pop3d::pop3d::${name}::trueport trueport
	    return $trueport
	}
	-auth {
	    upvar ::pop3d::pop3d::${name}::authCmd authCmd
	    return $authCmd
	}
	-storage {
	    upvar ::pop3d::pop3d::${name}::storCmd storCmd
	    return $storCmd
	}
	-socket {
	    upvar ::pop3d::pop3d::${name}::sockCmd sockCmd
	    return $sockCmd
	}
	default {
	    return -code error \
		    "Unknown option \"$anoption\":\
		    Expected \"-state\", \"-port\", \"-auth\", \"-socket\", or \"-storage\""
	}
    }
    # return - in all branches
}

# ::pop3d::_configure --
#
#	Query and set option values
#
# Arguments:
#	name	name of the pop3 server.
#	args	options and option values
#
# Results:
#	None.

proc ::pop3d::_configure {name args} {
    set argc [llength $args]
    if {($argc > 1) && (($argc % 2) == 1)} {
	return -code error \
		"wrong # args, expected: -option | (-option value)..."
    }
    if {$argc == 1} {
	return [_cget $name [lindex $args 0]]
    }

    upvar ::pop3d::pop3d::${name}::trueport trueport
    upvar ::pop3d::pop3d::${name}::port     port
    upvar ::pop3d::pop3d::${name}::authCmd  authCmd
    upvar ::pop3d::pop3d::${name}::storCmd  storCmd
    upvar ::pop3d::pop3d::${name}::sockCmd  sockCmd
    upvar ::pop3d::pop3d::${name}::state    state

    if {$argc == 0} {
	# Return the full configuration.
	return [list \
		-port    $trueport \
		-auth    $authCmd  \
		-storage $storCmd  \
		-socket  $sockCmd \
		-state   $state \
		]
    }

    while {[llength $args] > 0} {
	set option [lindex $args 0]
	set value  [lindex $args 1]
	switch -exact -- $option {
	    -auth    {set authCmd $value}
	    -storage {set storCmd $value}
	    -socket  {set sockCmd $value}
	    -port    {
		set port $value

		# Propagate to the queried value if the server is down
		# and thus has no real true port.

		if {[string equal $state down]} {
		    set trueport $value
		}
	    }
	    -state {
		return -code error "Option -state is read-only"
	    }
	    default {
		return -code error \
			"Unknown option \"$option\":\
			Expected \"-port\", \"-auth\", \"-socket\", or \"-storage\""
	    }
	}
	set args [lrange $args 2 end]
    }
    return ""
}


# ::pop3d::_conn --
#
#	Query connection state.
#
# Arguments:
#	name	name of the pop3 server.
#	cmd	subcommand to perform
#	args	arguments for subcommand
#
# Results:
#	Specific to subcommand

proc ::pop3d::_conn {name cmd args} {
    upvar ::pop3d::pop3d::${name}::conn    conn
    switch -exact -- $cmd {
	list {
	    if {[llength $args] > 0} {
		return -code error "wrong # args: should be \"$name conn list\""
	    }
	    return [array names conn]
	}
	state {
	    if {[llength $args] != 1} {
		return -code error "wrong # args: should be \"$name conn state connId\""
	    }
	    set sock [lindex $args 0]
	    upvar $conn($sock) cstate
	    return [array get  cstate]
	}
	default {
	    return -code error "bad option \"$cmd\": must be list, or state"
	}
    }
}

##########################
##########################
# Server implementation.

proc ::pop3d::HandleNewConnection {name sock rHost rPort} {
    upvar ::pop3d::pop3d::${name}::conn    conn
    upvar ::pop3d::pop3d::${name}::counter counter

    set csa ::pop3d::pop3d::${name}::conn[incr counter]
    set conn($sock) $csa
    upvar $csa cstate

    set cstate(remotehost) $rHost
    set cstate(remoteport) $rPort
    set cstate(server)     $name
    set cstate(id)         "<[string map {- {}} [clock clicks]]_${name}_[pid]@[::info hostname]>"
    set cstate(state)      "auth"
    set cstate(name)       ""
    set cstate(logon)      ""
    set cstate(storage)    ""
    set cstate(deleted)    ""
    set cstate(msg)        0
    set cstate(size)       0

    ::log::log notice "pop3d $name $sock state auth, waiting for logon"

    fconfigure $sock -buffering line -translation crlf -blocking 0

    if {[catch {::pop3d::GreetPeer $name $sock} errmsg]} {
	close $sock
	log::log error "pop3d $name $sock greeting $errmsg"
	unset cstate
	unset conn($sock)
	return
    }

    fileevent $sock readable [list ::pop3d::HandleCommand $name $sock]
    return
}

proc ::pop3d::CloseConnection {name sock} {
    upvar ::pop3d::pop3d::${name}::storCmd storCmd
    upvar ::pop3d::pop3d::${name}::state   state
    upvar ::pop3d::pop3d::${name}::conn    conn

    upvar $conn($sock) cstate

    # Kill a pending idle event for CloseConnection, we are closing now.
    catch {after cancel $cstate(idlepending)}

    ::log::log debug "pop3d $name $sock closing connection"

    if {[catch {close $sock} msg]} {
	::log::log error "pop3d $name $sock close: $msg"
    }
    if {$storCmd != {}} {
	# remove possible lock set in storage facility.
	if {[catch {
	    uplevel #0 [linsert $storCmd end unlock $cstate(storage)]
	} msg]} {
	    ::log::log error "pop3d $name $sock storage unlock: $msg"
	    # -W- future ? kill all connections, execute clean up of storage
	    # -W-          facility.
	}
    }

    unset cstate
    unset conn($sock)

    ::log::log notice "pop3d $name $sock closed"

    if {[string equal $state existing] && ([array size conn] == 0)} {
	_destroy $name
    }
    return
}

proc ::pop3d::HandleCommand {name sock} {
    # @c Called by the event system after arrival of a new command for
    # @c connection.

    # @a sock:   Direct access to the channel representing the connection.
    
    # Client closed connection, bye bye
    if {[eof $sock]} {
	CloseConnection $name $sock
	return
    }

    # line was incomplete, wait for more
    if {[gets $sock line] < 0} {
	return
    }

    upvar ::pop3d::pop3d::${name}::conn    conn
    upvar $conn($sock)                   cstate
    variable                             cmdMap

    ::log::log info "pop3d $name $sock < $line"

    set fail [catch {
	set cmd [string toupper [lindex $line 0]]

	if {![::info exists cmdMap($cmd)]} {
	    # unknown command, use unknown handler

	    HandleUnknownCmd $name $sock $cmd $line
	} else {
	    $cmdMap($cmd) $name $sock $cmd $line
	}
    } errmsg] ;#{}

    if {$fail} {
	# Had an error during handling of 'cmd'.
	# Handled by closing the connection.
	# (We do not know how to relay the internal error to the client)

	::log::log error "pop3d $name $sock $cmd: $errmsg"
	CloseConnection $name $sock
    }
    return
}

proc ::pop3d::GreetPeer {name sock} {
    # @c Called after the initialization of a new connection. Writes the
    # @c greeting to the new client. Overides the baseclass definition
    # @c (<m server:GreetPeer>).
    #
    # @a conn: Descriptor of connection to write to.

    upvar cstate cstate
    variable server

    log::log debug "pop3d $name $sock _ Greeting"

    Respond2Client $name $sock +OK \
	    "[::info hostname] $server ready $cstate(id)"
    return
}

proc ::pop3d::HandleUnknownCmd {name sock cmd line} {
    Respond2Client $name $sock -ERR "unknown command '$cmd'"
    return
}

proc ::pop3d::Respond2Client {name sock ok wtext} {
    ::log::log info "pop3d $name $sock > $ok $wtext"
    puts $sock                          "$ok $wtext"
    return
}

##########################
##########################
# Command implementations.

proc ::pop3d::H_capa {name sock cmd line} {
    # @c Handle CAPA command.

    # Capabilities should better be configurable and handled per
    # server object, so that e.g. USER/PASS authentication can be
    # turned off.

    upvar cstate cstate
    variable capabilities

    Respond2Client $name $sock +OK "Capability list follows"
    foreach {capability state} $capabilities {
	if {
	    [string equal $state "both"] ||
	    [string equal $state $cstate(state)]
	} {
	    puts $sock $capability
	}
    }
    puts $sock .
    return
}

proc ::pop3d::H_user {name sock cmd line} {
    # @c Handle USER command.
    #
    # @a conn: Descriptor of connection to write to.
    # @a cmd:  The sent command
    # @a line: The sent line, with <a cmd> as first word.

    # Called only in places where cstate is known!
    upvar cstate cstate

    if {[string equal $cstate(logon) apop]} {
	Respond2Client $name $sock -ERR "login mechanism APOP was chosen"
    } elseif {[string equal $cstate(state) trans]} {
	Respond2Client $name $sock -ERR "client already authenticated"
    } else {
	# The user name is the first argument to the command

	set cstate(name)  [lindex [split $line] 1]
	set cstate(logon) user

	Respond2Client $name $sock +OK "please send PASS command"
    }
    return
}


proc ::pop3d::H_pass {name sock cmd line} {
    # @c Handle PASS command.
    #
    # @a conn: Descriptor of connection to write to.
    # @a cmd:  The sent command
    # @a line: The sent line, with <a cmd> as first word.

    # Called only in places where cstate is known!
    upvar cstate cstate

    if {[string equal $cstate(logon) apop]} {
	Respond2Client $name $sock -ERR "login mechanism APOP was chosen"
    } elseif {[string equal $cstate(state) trans]} {
	Respond2Client $name $sock -ERR "client already authenticated"
    } else {
	upvar ::pop3d::pop3d::${name}::authCmd authCmd

	if {$authCmd == {}} {
	    # No authentication is possible. Reject all users.
	    CheckLogin $name $sock "" "" ""
	    return
	}

	# The password is given as the first argument of the command

	set pwd [lindex [split $line] 1]

	if {![uplevel #0 [linsert $authCmd end exists $cstate(name)]]} {
	    ::log::log warning "pop3d $name $sock $authCmd lookup $cstate(name) : user does not exist"
	    CheckLogin $name $sock "" "" ""
	    return
	}
	if {[catch {
	    set info [uplevel #0 [linsert $authCmd end lookup $cstate(name)]]
	} msg]} {
	    ::log::log error "pop3d $name $sock $authCmd lookup $cstate(name) : $msg"
	    CheckLogin $name $sock "" "" ""
	    return
	}
	CheckLogin $name $sock $pwd [lindex $info 0] [lindex $info 1]
    }
    return
}


proc ::pop3d::H_apop {name sock cmd line} {
    # @c Handle APOP command.
    #
    # @a conn: Descriptor of connection to write to.
    # @a cmd:  The sent command
    # @a line: The sent line, with <a cmd> as first word.

    # Called only in places where cstate is known!
    upvar cstate cstate

    if {[string equal $cstate(logon) user]} {
	Respond2Client $name $sock -ERR "login mechanism USER/PASS was chosen"
	return
    } elseif {[string equal $cstate(state) trans]} {
	Respond2Client $name $sock -ERR "client already authenticated"
	return
    }

    # The first two arguments to the command are user name and its
    # response to the challenge set by the server.

    set cstate(name)  [lindex $line 1]
    set cstate(logon) apop

    upvar ::pop3d::pop3d::${name}::authCmd authCmd

    #log::log debug "authCmd|$authCmd|"

    if {$authCmd == {}} {
	# No authentication is possible. Reject all users.
	CheckLogin $name $sock "" "" ""
	return
    }

    set digest  [lindex $line 2]

    if {![uplevel #0 [linsert $authCmd end exists $cstate(name)]]} {
	::log::log warning "pop3d $name $sock $authCmd lookup $cstate(name) : user does not exist"
	CheckLogin $name $sock "" "" ""
	return
    }
    if {[catch {
	set info [uplevel #0 [linsert $authCmd end lookup $cstate(name)]]
    } msg]} {
	::log::log error "pop3d $name $sock $authCmd lookup $cstate(name) : $msg"
	CheckLogin $name $sock "" "" ""
	return
    }

    set pwd     [lindex $info 0]
    set storage [lindex $info 1]

    ::log::log debug "pop3d $name $sock info = <$info>"

    if {$storage == {}} {
	# user does not exist, skip over digest computation
	CheckLogin $name $sock "" "" $storage
	return
    }

    # Do the same algorithm as the client to generate a digest, then
    # compare our data with information sent by the client. As we are
    # using tcl 8.x there is need to use channels, an immediate
    # computation is possible.

    set ourDigest [Md5 "$cstate(id)$pwd"]

    ::log::log debug "pop3d $name $sock digest input <$cstate(id)$pwd>"
    ::log::log debug "pop3d $name $sock digest outpt <$ourDigest>"
    ::log::log debug "pop3d $name $sock digest given <$digest>"

    CheckLogin $name $sock $digest $ourDigest $storage
    return
}


proc ::pop3d::H_stat {name sock cmd line} {
    # @c Handle STAT command.
    #
    # @a conn: Descriptor of connection to write to.
    # @a cmd:  The sent command
    # @a line: The sent line, with <a cmd> as first word.

    # Called only in places where cstate is known!
    upvar cstate cstate

    if {[string equal $cstate(state) auth]} {
	Respond2Client $name $sock -ERR "client not authenticated"
    } else {
	# Return number of messages waiting and size of the contents
	# of the chosen maildrop in octects.
	Respond2Client $name $sock +OK  "$cstate(msg) $cstate(size)"
    }

    return
}


proc ::pop3d::H_dele {name sock cmd line} {
    # @c Handle DELE command.
    #
    # @a conn: Descriptor of connection to write to.
    # @a cmd:  The sent command
    # @a line: The sent line, with <a cmd> as first word.

    # Called only in places where cstate is known!
    upvar cstate cstate

    if {[string equal $cstate(state) auth]} {
	Respond2Client $name $sock -ERR "client not authenticated"
	return
    }

    set msgid [lindex $line 1]

    if {
	($msgid < 1) ||
	($msgid > $cstate(msg)) ||
	([lsearch $msgid $cstate(deleted)] >= 0)
    } {
	Respond2Client $name $sock -ERR "no such message"
    } else {
	lappend cstate(deleted) $msgid
	Respond2Client $name $sock +OK "message $msgid deleted"
    }
    return
}


proc ::pop3d::H_retr {name sock cmd line} {
    # @c Handle RETR command.
    #
    # @a conn: Descriptor of connection to write to.
    # @a cmd:  The sent command
    # @a line: The sent line, with <a cmd> as first word.

    # Called only in places where cstate is known!
    upvar cstate cstate

    if {[string equal $cstate(state) auth]} {
	Respond2Client $name $sock -ERR "client not authenticated"
	return
    }

    set msgid [lindex $line 1]

    if {
	($msgid > $cstate(msg)) ||
	([lsearch $msgid $cstate(deleted)] >= 0)
    } {
	Respond2Client $name $sock -ERR "no such message"
    } else {
	Transfer $name $sock $msgid
    }
    return
}


proc ::pop3d::H_top  {name sock cmd line} {
    # @c Handle RETR command.
    #
    # @a conn: Descriptor of connection to write to.
    # @a cmd:  The sent command
    # @a line: The sent line, with <a cmd> as first word.

    # Called only in places where cstate is known!
    upvar cstate cstate

    if {[string equal $cstate(state) auth]} {
	Respond2Client $name $sock -ERR "client not authenticated"
	return
    }

    set msgid  [lindex $line 1]
    set nlines [lindex $line 2]

    if {
	($msgid > $cstate(msg)) ||
	([lsearch $msgid $cstate(deleted)] >= 0)
    } {
	Respond2Client $name $sock -ERR "no such message"
    } elseif {$nlines == {}} {
	Respond2Client $name $sock -ERR "missing argument: #lines to read"
    } elseif {$nlines < 0} {
	Respond2Client $name $sock -ERR \
		"number of lines has to be greater than or equal to zero."
    } elseif {$nlines == 0} {
	# nlines == 0, no limit, same as H_retr
	Transfer $name $sock $msgid
    } else {
	# nlines > 0
	Transfer $name $sock $msgid $nlines
    }
    return
}


proc ::pop3d::H_quit {name sock cmd line} {
    # @c Handle QUIT command.
    #
    # @a conn: Descriptor of connection to write to.
    # @a cmd:  The sent command
    # @a line: The sent line, with <a cmd> as first word.

    # Called only in places where cstate is known!
    upvar cstate cstate
    variable server

    set cstate(state) update

    if {$cstate(deleted) != {}} {
	upvar ::pop3d::pop3d::${name}::storCmd storCmd
	if {$storCmd != {}} {
	    uplevel #0 [linsert $storCmd end \
		    dele $cstate(storage) $cstate(deleted)]
	}
    }

    set cstate(idlepending) [after idle [list ::pop3d::CloseConnection $name $sock]]

    Respond2Client $name $sock +OK \
	    "[::info hostname] $server shutting down"
    return
}


proc ::pop3d::H_noop {name sock cmd line} {
    # @c Handle NOOP command.
    #
    # @a conn: Descriptor of connection to write to.
    # @a cmd:  The sent command
    # @a line: The sent line, with <a cmd> as first word.

    # Called only in places where cstate is known!
    upvar cstate cstate

    if {[string equal $cstate(state) fail]} {
	Respond2Client $name $sock -ERR "login failed, no actions possible"
    } elseif {[string equal $cstate(state) auth]} {
	Respond2Client $name $sock -ERR "client not authenticated"
    } else {
	Respond2Client $name $sock +OK ""
    }
    return
}


proc ::pop3d::H_rset {name sock cmd line} {
    # @c Handle RSET command.
    #
    # @a conn: Descriptor of connection to write to.
    # @a cmd:  The sent command
    # @a line: The sent line, with <a cmd> as first word.

    # Called only in places where cstate is known!
    upvar cstate cstate

    if {[string equal $cstate(state) fail]} {
	Respond2Client $name $sock -ERR "login failed, no actions possible"
    } elseif {[string equal $cstate(state) auth]} {
	Respond2Client $name $sock -ERR "client not authenticated"
    } else {
	set cstate(deleted) ""

	Respond2Client $name $sock +OK "$cstate(msg) messages waiting"
    }
    return
}


proc ::pop3d::H_list {name sock cmd line} {
    # @c Handle LIST command. Generates scan listing
    #
    # @a conn: Descriptor of connection to write to.
    # @a cmd:  The sent command
    # @a line: The sent line, with <a cmd> as first word.

    # Called only in places where cstate is known!
    upvar cstate cstate

    if {[string equal $cstate(state) fail]} {
	Respond2Client $name $sock -ERR "login failed, no actions possible"
	return
    } elseif {[string equal $cstate(state) auth]} {
	Respond2Client $name $sock -ERR "client not authenticated"
	return
    }

    set msgid [lindex $line 1]

    upvar ::pop3d::pop3d::${name}::storCmd storCmd

    if {$msgid == {}} {
	# full listing
	Respond2Client $name $sock +OK "$cstate(msg) messages"

	set n $cstate(msg)

	for {set i 1} {$i <= $n} {incr i} {
	    Respond2Client $name $sock $i \
		    [uplevel #0 [linsert $storCmd end \
		    size $cstate(storage) $i]]
	}
	puts $sock "."

    } else {
	# listing for specified message

	if {
	    ($msgid < 1) ||
	    ($msgid > $cstate(msg)) ||
	    ([lsearch $msgid $cstate(deleted)] >= 0)
	}  {
	    Respond2Client $name $sock -ERR "no such message"
	    return
	}

	Respond2Client $name $sock +OK \
		"$msgid [uplevel #0 [linsert $storCmd end \
		size $cstate(storage) $msgid]]"
	return
    }
}

##########################
##########################
# Command helper commands.

proc ::pop3d::CheckLogin {name sock clientid serverid storage} {
    # @c Internal procedure. General code used by USER/PASS and
    # @c APOP login mechanisms to verify the given user-id.
    # @c Locks the mailbox in case of a match.
    #
    # @a conn:     Descriptor of connection to write to.
    # @a clientid: Authentication code transmitted by client
    # @a serverid: Authentication code calculated here.
    # @a storage:  Handle of mailbox requested by client.

    #log::log debug "CheckLogin|$name|$sock|$clientid|$serverid|$storage|"

    upvar cstate cstate
    upvar ::pop3d::pop3d::${name}::storCmd storCmd

    set noStorage [expr {$storCmd == {}}]

    if {$storage == {}} {
	# The user given by the client has no storage, therefore it does
	# not exist. React as if wrong password was given.

	set cstate(state) auth
	set cstate(logon) ""

	::log::log notice "pop3d $name $sock state auth, no maildrop"
	Respond2Client $name $sock -ERR "authentication failed, sorry"

    } elseif {[string compare $clientid $serverid] != 0} {
	# password/digest given by client dos not match

	set cstate(state) auth
	set cstate(logon) ""

	::log::log notice "pop3d $name $sock state auth, secret does not match"
	Respond2Client $name $sock -ERR "authentication failed, sorry"

    } elseif {
	!$noStorage &&
	! [uplevel #0 [linsert $storCmd end lock $storage]]
    } {
	# maildrop is locked already (by someone else).

	set cstate(state) auth
	set cstate(logon) ""

	::log::log notice "pop3d $name $sock state auth, maildrop already locked"
	Respond2Client $name $sock -ERR \
		"could not aquire lock for maildrop $cstate(name)"
    } else {
	# everything went fine. allow to proceed in session.

	set cstate(storage) $storage
	set cstate(state)   trans
	set cstate(logon)   ""

	set cstate(msg) 0
	if {!$noStorage} {
	    set cstate(msg) [uplevel #0 [linsert $storCmd end \
		    stat $cstate(storage)]]
	    set cstate(size) [uplevel #0 [linsert $storCmd end \
		    size $cstate(storage)]]
	}
	
	::log::log notice \
		"pop3d $name $sock login $cstate(name) $storage $cstate(msg)"
	::log::log notice "pop3d $name $sock state trans"

	Respond2Client $name $sock +OK "congratulations"
    }
    return
}

proc ::pop3d::Transfer {name sock msgid {limit -1}} {
    # We ask the storage for the mime token of the mail and use
    # that to generate and copy the mail to the requestor.

    upvar cstate cstate
    upvar ::pop3d::pop3d::${name}::storCmd storCmd

    if {$limit < 0} {
	Respond2Client $name $sock +OK \
		"[uplevel #0 [linsert $storCmd end \
		size $cstate(storage) $msgid]] octets"
    } else {
	Respond2Client $name $sock +OK ""
    }

    set token [uplevel #0 [linsert $storCmd end get $cstate(storage) $msgid]]
    
    ::log::log debug "pop3d $name $sock transfering data ($token)"

    if {$limit < 0} {
	# Full transfer, we can use "copymessage" and avoid
	# construction in memory (depending on source of token).

	log::log debug "pop3d $name Transfer $msgid /full"

	# We do "."-stuffing here. This is not in the scope of the
	# MIME library we use, but a transport dependent thing.

	set msg [string trimright [string map [list "\n." "\n.."] \
				       [mime::buildmessage $token]] \n]
	log::log debug "($msg)"
	puts $sock $msg
	puts $sock .

    } else {
	# As long as FR #531541 is not implemented we have to build
	# the entire message in memory and then cut it down to the
	# requested size. If limit was greater than the number of
	# lines in the message we will get the terminating "."
	# too. Using regsub we make sure that it is not present and
	# reattach during the transfer. Otherwise we would have to use
	# a regexp/if combo to decide wether to attach the terminator
	# not.

	set msg [split [mime::buildmessage $token] \n]
	set i 0
	incr limit -1
	while {[lindex $msg $i] != {}} {
	    incr i
	    incr limit
	}
	# i now refers to the line separating header and body

	regsub -- "\n\\.\n$" [string map [list "\n." "\n.."] [join [lrange $msg 0 $limit] \n]] {} data
	puts $sock ${data}\n.
    }
    ::log::log debug "pop3d $name $sock transfer complete"
    # response already sent.
    return
}

set major [lindex [split [package require md5] .] 0]
if {$::major < 2} {
    proc ::pop3d::Md5 {text} {md5::md5 $text}
} else {
    proc ::pop3d::Md5 {text} {string tolower [md5::md5 -hex $text]}
}
unset major

##########################
# Module initialization
return
