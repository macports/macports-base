# ident.tcl --
#
#	Implemetation of the client side of the ident protocol.
#	See RFC 1413 for details on the protocol.
#
# Copyright (c) 2004 Reinhard Max <max@tclers.tk>
#
# -------------------------------------------------------------------------
# This software is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the file 'license.terms' for
# more details.
# -------------------------------------------------------------------------
# RCS: @(#) $Id: ident.tcl,v 1.2 2004/07/12 14:01:04 patthoyts Exp $

package provide ident 0.42

namespace eval ident {
    namespace export query configure
}

proc ident::parse {string} {

    # remove all white space for easier parsing
    regsub -all {\s} $string "" s
    if {[regexp {^\d+,\d+:(\w+):(.*)} $s -> resptype addinfo]} {
	switch -exact -- $resptype {
	    USERID {
		if { [regexp {^([^,]+)(,([^:]+))?:} \
			  $addinfo -> opsys . charset]
		 } then {
		    # get the user-if from the original string, because it
		    # is allowed to contain white space.
		    set index [string last : $string]
		    incr index
		    set userid [string range $string $index end]
		    if {$charset != ""} {
			set (user-id) \
			    [encoding convertfrom $charset $userid]
		    }
		    set answer [list resp-type USERID opsys $opsys \
				    user-id $userid]
		}
	    }
	    ERROR {
		set answer [list resp-type ERROR error $addinfo]
	    }
	}
    }
    if {![info exists answer]} {
	set answer [list resp-type FATAL \
			error "Unexpected response:\"$string\""]
    }
    return $answer
}

proc ident::Callback {sock command} {
    gets $sock answer
    close $sock
    lappend command [parse $answer]
    eval $command
}

proc ident::query {socket {command {}}} {

    foreach {sock_ip sock_host sock_port} [fconfigure $socket -sockname] break
    foreach {peer_ip peer_host peer_port} [fconfigure $socket -peername] break
    
    set blocking [string equal $command ""]
    set failed [catch {socket $peer_ip ident} sock]
    if {$failed} {
	set result [list resp-type FATAL error $sock]
	if {$blocking} {
	    return $result
	} else {
	    after idle [list $command $result]
	    return
	}
    }
    fconfigure $sock -encoding binary -buffering line -blocking $blocking
    puts $sock "$peer_port,$sock_port"
    if {$blocking} {
	gets $sock answer
	close $sock
	return [parse $answer]
    } else {
	fileevent $sock readable \
	    [namespace code [list Callback $sock $command]]
    }    
}
