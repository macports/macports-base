# -*- tcl -*-
# Dialog - Dialog Demon (Server, or Client)
# Copyright (c) 2004, Andreas Kupries <andreas_kupries@users.sourceforge.net>

puts "- dialog (coserv-based)"

# ### ### ### ######### ######### #########
## Commands on top of a plain comm server.
## Assumes that the comm server environment
## is present. Provides set up and execution
## of a fixed linear dialog, done from the
# perspective of a server application.

# ### ### ### ######### ######### #########
## Load "comm" into the master.

namespace eval ::dialog {
    variable dtrace    {}
}

# ### ### ### ######### ######### #########
## Start a new dialog server.

proc ::dialog::setup {type cookie {ssl 0}} {
    variable id
    variable port

    switch -- $type {
	server  {set server 1}
	client  {set server 0}
	default {return -code error "Bad dialog type \"$type\", expected server, or client"}
    }

    set id [::coserv::start "$type: $cookie"]
    ::coserv::run $id {
	set responses {}
	set strace    {}
	set received  {}
	set conn      {}
	set ilog      {}

	proc Log {text} {
	    global ilog ; lappend ilog $text
	}
	proc Strace {text} {
	    global strace ; lappend strace $text
	}
	proc Exit {sock reason} {
	    Strace $reason
	    Log    [list $reason $sock]
	    close  $sock
	    Done
	}
	proc Done {} {
	    global main strace ilog
	    comm::comm send $main [list dialog::done [list $strace $ilog]]
	    return
	}
	proc ClearTraces {} {
	    global strace ; set strace {}
	    global ilog   ; set ilog   {}
	    return
	}
	proc Step {sock} {
	    global responses trace

	    if {![llength $responses]} {
		Exit $sock empty
		return
	    }

	    set now       [lindex $responses 0]
	    set responses [lrange $responses 1 end]

	    Log  [list ** $sock $now]
	    eval [linsert $now end $sock]
	    return
	}

	# Step commands ...

	proc .Crlf {sock} {
	    Strace crlf
	    Log crlf
	    fconfigure $sock -translation crlf
	    Step $sock
	    return
	}
	proc .Binary {sock} {
	    Strace bin
	    Log binary
	    fconfigure $sock -translation binary
	    Step $sock
	    return
	}
	proc .HaltKeep {sock} {
	    Log halt.keep
	    Done
	    global responses
	    set    responses {}
	    # No further stepping.
	    # This keeps the socket open.
	    # Needs external reset/cleanup
	    return
	}
	proc .Send {line sock} {
	    Strace [list >> $line]
	    Log    [list >> $line]

	    if {[catch {
		puts  $sock $line
		flush $sock
	    } msg]} {
		Exit $sock broken
		return
	    }
	    Step $sock
	    return
	}
	proc .Geval {script sock} {
	    Log geval
	    uplevel #0 $script
	    Step $sock
	    return
	}
	proc .Eval {script sock} {
	    Log eval
	    eval $script
	    Step $sock
	    return
	}
	proc .SendGvar {vname sock} {
	    upvar #0 $vname line
	    .Send $line $sock
	    return
	}
	proc .Receive {sock} {
	    set aid     [after 10000 [list Timeout    $sock]]
	    fileevent $sock readable [list Input $aid $sock]
	    # No "Step" here. Comes through input.
	    Log "   Waiting    \[$aid\]"
	    return
	}
	proc Input {aid sock} {
	    global received
	    if {[eof $sock]} {
		# Clean the timer up
		after cancel $aid
		Exit $sock close
		return
	    }
	    if {[gets $sock line] < 0} {
		Log "   **|////|**"
		return
	    }

	    Log "-- -v-"
	    Log "   Events off \[$aid, $sock\]"
	    fileevent    $sock readable {}
	    after cancel $aid

	    Strace [list << $line]
	    Log    [list << $line]
	    lappend received $line

	    # Now we can step further
	    Step $sock
	    return
	}
	proc Timeout {sock} {
	    Exit $sock timeout
	    return
	}
	proc Accept {sock host port} {
	    fconfigure $sock -blocking 0
	    ClearTraces
	    Step $sock
	    return
	}

	proc Server {} {
	    global port
	    # Start listener for dialog
	    set listener [socket -server Accept 0]
	    set port     [lindex [fconfigure $listener -sockname] 2]
	    # implied return of <port>
	}

	proc Client {port} {
	    global conn
	    catch {close $conn}

	    set conn [set sock [socket localhost $port]]
	    fconfigure $sock -blocking 0
	    ClearTraces
	    Log [list Client @ $port = $sock]
	    Log [list Channels $port = [lsort [file channels]]]
	    Step $sock
	    return
	}
    }

    if {$ssl} {
	# Replace various commands with tls aware variants
	coserv::run $id [list set devtools [tcllibPath devtools]]
	coserv::run $id {
	    package require tls

	    tls::init \
		-keyfile  $devtools/transmitter.key \
		-certfile $devtools/transmitter.crt \
		-cafile   $devtools/ca.crt \
		-ssl2 1    \
		-ssl3 1    \
		-tls1 0    \
		-require 1

	    proc Server {} {
		global port
		# Start listener for dialog
		set listener [tls::socket -server Accept 0]
		set port     [lindex [fconfigure $listener -sockname] 2]
		# implied return of <port>
	    }

	    proc Client {port} {
		global conn
		catch {close $conn}

		set conn [set sock [tls::socket localhost $port]]
		fconfigure $sock -blocking 0
		ClearTraces
		Log [list Client @ $port = $sock]
		Log [list Channels $port = [lsort [file channels]]]
		Step $sock
		return
	    }
	}
    }

    if {$server} {
	set port [coserv::run $id {Server}]
    }
}

proc ::dialog::runclient {port} {
    variable id
    variable dtrace {}
    coserv::task $id [list Client $port]
    return
}

proc ::dialog::dialog_set {response_script} {
    begin
    uplevel 1 $response_script
    end
    return
}

proc ::dialog::begin {{cookie {}}} {
    variable id
    ::coserv::task $id [list set responses {}]
    log::log debug "+============================================ $cookie \\\\"
    return
}

proc ::dialog::cmd {command} {
    variable id
    ::coserv::task $id [list lappend responses $command]
    return
}

proc ::dialog::end {} {
    # This implicitly waits for all preceding commands (which are async) to complete.
    variable id
    set responses [::coserv::run $id [list set responses]]
    ::coserv::run $id {set received {}}
    log::log debug |\t[join $responses \n|\t]
    log::log debug +---------------------------------------------
    return
}

proc ::dialog::crlf.      {}       {cmd .Crlf}
proc ::dialog::binary.    {}       {cmd .Binary}
proc ::dialog::send.      {line}   {cmd [list .Send $line]}
proc ::dialog::receive.   {}       {cmd .Receive}
proc ::dialog::respond.   {line}   {receive. ; send. $line}
proc ::dialog::request.   {line}   {send. $line ; receive.}
proc ::dialog::halt.keep. {}       {cmd .HaltKeep}
proc ::dialog::sendgvar.  {vname}  {cmd [list .SendGvar $vname]}
proc ::dialog::reqgvar.   {vname}  {sendgvar. $vname ; receive.}
proc ::dialog::geval.     {script} {cmd [list .Geval $script]}
proc ::dialog::eval.      {script} {cmd [list .Eval  $script]}

proc ::dialog::done {traces} {
    variable dtrace $traces
    return
}

proc ::dialog::waitdone {} {
    variable dtrace

    # Loop until we have data from the dialog subprocess.
    # IOW writes which do not create data are ignored.
    while {![llength $dtrace]} {
	vwait ::dialog::dtrace
    }

    foreach {strace ilog} $dtrace break
    set dtrace {}

    log::log debug  +---------------------------------------------
    log::log debug  |\t[join $strace \n|\t]
    log::log debug  +---------------------------------------------
    log::log debug  /\t[join $ilog \n/\t]
    log::log debug "+============================================ //"
    return $strace
}

proc ::dialog::received {} {
    # Wait for all preceding commands to complete.
    variable id
    set received [::coserv::run $id [list set received]]
    ::coserv::run $id [list set received {}]
    return $received
}

proc ::dialog::listener {} {
    variable port
    return $port
}

proc ::dialog::shutdown {} {
    variable id
    variable port
    variable dtrace

    ::coserv::shutdown $id

    set id     {}
    set port   {}
    set dtrace {}
    return
}

# ### ### ### ######### ######### #########
