# -*- tcl -*-
# ### ### ### ######### ######### #########
##
# Transfer class. Reception of data.
##
# Utilizes data destination and connect components to handle the
# general/common parts.

# ### ### ### ######### ######### #########
## Requirements

package require snit
package require transfer::data::destination ; # Data destination
package require transfer::connect           ; # Connection startup

# ### ### ### ######### ######### #########
## Implementation

snit::type ::transfer::receiver {

    # ### ### ### ######### ######### #########
    ## Convenient fire and forget file/channel reception operations.

    typemethod {stream channel} {chan host port args} {
	# Select stream configuration ( host => active, otherwise
	# passive)
	if {$host eq {}} {
	    set cmd [linsert $args 0 $type %AUTO% \
			 -channel $chan -port $port \
			 -mode passive -translation binary]
	} else {
	    set cmd [linsert $args 0 $type %AUTO% \
			 -channel $chan -host $host -port $port \
			 -mode active -translation binary]
	}

	# Create a transient transmitter controller, and wrap our own
	# internal completion handling around the user supplied
	# callback.

	set receiver [eval $cmd]
	$receiver configure \
	    -command [mytypemethod Done \
			  [$receiver cget -command]]

	# Begin transmission (or wait for other side to connect).
	return [$receiver start]
    }

    typemethod {stream file} {file host port args} {
	set chan [open $file w]
	fconfigure $chan -translation binary

	set receiver [eval [linsert $args 0 $type stream channel $chan $host $port]]

	# Redo completion command callback.
	$receiver configure \
	    -command [mytypemethod DoneFile $chan \
			  [lindex [$receiver cget -command] end]]
	return $receiver
    }

    typemethod Done {command receiver n {err {}}} {
	$receiver destroy

	if {![llength $command]} return

	after 0 [linsert $command end $n $err]
	return
    }

    typemethod DoneFile {chan command receiver n {err {}}} {
	close $chan
	$receiver destroy

	if {![llength $command]} return

	after 0 [linsert $command end $n $err]
	return
    }

    # ### ### ### ######### ######### #########
    ## API

    ## Data destination sub component

    delegate option -channel  to mydestination
    delegate option -file     to mydestination
    delegate option -variable to mydestination
    delegate option -progress to mydestination

    ## Connection management sub component

    delegate option -host        to myconnect
    delegate option -port        to myconnect
    delegate option -mode        to myconnect
    delegate option -translation to myconnect
    delegate option -encoding    to myconnect
    delegate option -eofchar     to myconnect
    delegate option -socketcmd   to myconnect

    ## Receiver configuration, and API

    option -command -default {}

    constructor {args} {}

    method start {} {}
    method busy  {} {}

    # ### ### ### ######### ######### #########
    ## Implementation

    constructor {args} {
	set mybusy 0
	install mydestination using ::transfer::data::destination ${selfns}::dest
	install myconnect     using ::transfer::connect           ${selfns}::conn

	$self configurelist $args
	return
    }

    method start {} {
	if {$mybusy} {
	    return -code error "Object is busy"
	}

	if {![$mydestination valid msg]} {
	    return -code error $msg
	}

	if {$options(-command) eq ""} {
	    return -code error "Completion callback is missing"
	}

	set mybusy 1
	return [$myconnect connect [mymethod Begin]]
    }

    method busy {} {
	return $mybusy
    }

    # ### ### ### ######### ######### #########
    ## Internal helper commands.

    method Begin {__ sock} {
	# __ == myconnect
	$mydestination receive $sock \
		[mymethod Done $sock]
	return
    }

    method Done {sock args} {
	# args is either (n),
	#             or (n errormessage)

	set mybusy 0
	close $sock
	$self Complete $args
	return
    }

    method Complete {arguments} {
	# 8.5: {*}$options(-command) $self {*}$arguments
	set     cmd $options(-command)
	lappend cmd $self
	foreach a $arguments {lappend cmd $a}

	uplevel #0 $cmd
	return
    }

    # ### ### ### ######### ######### #########
    ## Data structures

    component mydestination   ; # Data destination the transfered bytes are delivered to
    component myconnect	      ; # Connector controlling where to get the data from.
    variable  mybusy        0 ; # Transfer status.

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide transfer::receiver 0.2
