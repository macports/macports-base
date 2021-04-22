# -*- tcl -*-
# ### ### ### ######### ######### #########
##
# Transfer class. Sending of data.
##
# Utilizes data source and connect components to handle the
# general/common parts.

# ### ### ### ######### ######### #########
## Requirements

package require snit
package require transfer::data::source ; # Data source
package require transfer::connect      ; # Connection startup

# ### ### ### ######### ######### #########
## Implementation

snit::type ::transfer::transmitter {

    # ### ### ### ######### ######### #########
    ## Convenient fire and forget file/channel transmission operations.

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

	set transmitter [eval $cmd]
	$transmitter configure \
	    -command [mytypemethod Done \
			  $chan [$transmitter cget -command]]

	# Begin transmission (or wait for other side to connect).
	return [$transmitter start]
    }

    typemethod {stream file} {file host port args} {
	set chan [open $file r]
	fconfigure $chan -translation binary

	return [eval [linsert $args 0 $type stream channel $chan $host $port]]
    }

    typemethod Done {chan command transmitter n {err {}}} {
	close $chan
	$transmitter destroy

	if {![llength $command]} return

	after 0 [linsert $command end $n $err]
	return
    }

    # ### ### ### ######### ######### #########
    ## API

    ## Data source sub component

    delegate option -string   to mysource
    delegate option -channel  to mysource
    delegate option -file     to mysource
    delegate option -variable to mysource
    delegate option -size     to mysource
    delegate option -progress to mysource

    ## Connection management sub component

    delegate option -host        to myconnect
    delegate option -port        to myconnect
    delegate option -mode        to myconnect
    delegate option -translation to myconnect
    delegate option -encoding    to myconnect
    delegate option -eofchar     to myconnect
    delegate option -socketcmd   to myconnect

    ## Transmitter configuration, and API

    option -command   -default {}
    option -blocksize -default 1024 -type {snit::integer -min 1}

    constructor {args} {}

    method start {} {}
    method busy  {} {}

    # ### ### ### ######### ######### #########
    ## Implementation

    constructor {args} {
	set mybusy 0
	install mysource  using ::transfer::data::source ${selfns}::source
	install myconnect using ::transfer::connect      ${selfns}::conn
	$self configurelist $args
	return
    }

    method start {} {
	if {$mybusy} {
	    return -code error "Object is busy"
	}

	if {![$mysource valid msg]} {
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
	# __ <=> myconnect
	$mysource transmit $sock \
		$options(-blocksize) \
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

    component mysource    ; # Data source providing the bytes to transfer
    component myconnect   ; # Connector controlling where to the data transfered to.
    variable  mybusy    0 ; # Transfer status.

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide transfer::transmitter 0.2
