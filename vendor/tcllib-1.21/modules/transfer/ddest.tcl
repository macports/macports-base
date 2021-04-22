# -*- tcl -*-
# ### ### ### ######### ######### #########
##

# Class for the handling of stream destinations.

# ### ### ### ######### ######### #########
## Requirements

package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type ::transfer::data::destination {

    # ### ### ### ######### ######### #########
    ## API

    #                                                        Destination is ...
    option -channel  -default {} -configuremethod C-chan ; # an open & writable channel.
    option -file     -default {} -configuremethod C-file ; # a writable file.
    option -variable -default {} -configuremethod C-var  ; # the named variable.
    option -progress -default {}

    method put   {chunk} {}
    method done  {}      {}
    method valid {mv}    {}

    method receive {sock done} {}

    # ### ### ### ######### ######### #########
    ## Implementation

    method put {chunk} {
	if {$myxtype eq "file"} {
	    set mydest  [open $mydest w]
	    set myxtype channel
	    set myclose 1
	}

	switch -exact -- $myxtype {
	    variable {
		upvar \#0 $mydest var
		append var $chunk
	    }
	    channel {
		puts -nonewline $mydest $chunk
	    }
	}
	return
    }

    method done {} {
	switch -exact -- $myxtype {
	    file - variable {}
	    channel {
		if {$myclose} {
		    close $mydest
		}
	    }
	}
    }

    method valid {mv} {
	upvar 1 $mv message
	switch -exact -- $myxtype {
	    undefined {
		set message "Data destination is undefined"
		return 0
	    }
	    default {}
	}
	return 1
    }

    method receive {sock done} {
	set myntransfered 0
	set old [fconfigure $sock -blocking]
	fconfigure $sock -blocking 0
	fileevent $sock readable \
		[mymethod Read $sock $old $done]
	return
    }

    method Read {sock oldblock done} {
	set chunk [read $sock]
	if {[set l [string length $chunk]]} {
	    $self put $chunk
	    incr myntransfered $l
	    if {[llength $options(-progress)]} {
		uplevel #0 [linsert $options(-progress) end $myntransfered]
	    }
	}
	if {[eof $sock]} {
	    $self done
	    fileevent  $sock readable {}
	    fconfigure $sock -blocking $oldblock

	    uplevel #0 [linsert $done end $myntransfered]
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal helper commands.

    method C-var {o newvalue} {
	set myetype variable
	set myxtype string

	if {![uplevel \#0 {info exists $newvalue}]} {
	    return -code error "Bad variable \"$newvalue\", does not exist"
	}

	set mydest $newvalue
	return
    }

    method C-chan {o newvalue} {
	if {![llength [file channels $newvalue]]} {
	    return -code error "Bad channel handle \"$newvalue\", does not exist"
	}
	set myetype channel
	set myxtype channel
	set mydest  $newvalue
	return
    }

    method C-file {o newvalue} {
	if {![file exists $newvalue]} {
	    set d [file dirname $newvalue]
	    if {![file writable $d]} {
		return -code error "File \"$newvalue\" not creatable"
	    }
	    if {![file isdirectory $d]} {
		return -code error "File \"$newvalue\" not creatable"
	    }
	} else {
	    if {![file writable $newvalue]} {
		return -code error "File \"$newvalue\" not writable"
	    }
	    if {![file isfile $newvalue]} {
		return -code error "File \"$newvalue\" not a file"
	    }
	}
	set myetype channel
	set myxtype file
	set mydest  $newvalue
	return
    }

    # ### ### ### ######### ######### #########
    ## Data structures

    variable myetype  undefined
    variable myxtype  undefined
    variable mydest   {}
    variable myclose  0
    variable myntransfered

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide transfer::data::destination 0.2
