# -*- tcl -*-
# ### ### ### ######### ######### #########
##

# Class for handling of active/passive connectivity.

# ### ### ### ######### ######### #########
## Requirements

package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type ::transfer::connect {

    # ### ### ### ######### ######### #########
    ## API

    option -host        -default localhost
    option -port        -default 0
    option -mode        -default active    -type {snit::enum -values {active passive}}
    option -socketcmd   -default ::socket

    option -translation -default {}
    option -encoding    -default {}
    option -eofchar     -default {}

    method connect {command} {}

    # active:
    # - connect to host/port
    #
    # passive:
    # - listen on port for connection

    # ### ### ### ######### ######### #########
    ## Implementation

    method connect {command} {
	if {$options(-mode) eq "active"} {
	    set sock [Socket $options(-host) $options(-port)]

	    $self ConfigureTheOpenedSocket $sock $command
	    return
	} else {
	    set mysock [Socket -server [mymethod IsConnected $command] \
			    $options(-port)]

	    # Return port the server socket is listening on for the
	    # connection.
	    return [lindex [fconfigure $mysock -sockname] 2]
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal helper commands.

    method IsConnected {command sock peerhost peerport} {
	# Accept only a one connection.
	close $mysock
	$self ConfigureTheOpenedSocket $sock $command
	return
    }

    method ConfigureTheOpenedSocket {sock command} {
	foreach o {-translation -encoding -eofchar} {
	    if {$options($o) eq ""} continue
	    fconfigure $sock $o $options($o)
	}

	after 0 [linsert $command end $self $sock]
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal helper commands.

    proc Socket {args} {
	upvar 1 options(-socketcmd) socketcmd
	return [eval [linsert $args 0 $socketcmd]]
    }

    # ### ### ### ######### ######### #########
    ## Data structures

    variable mysock {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide transfer::connect 0.2
