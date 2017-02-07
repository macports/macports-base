# -*- tcl -*-
# ### ### ### ######### ######### #########
##

# Class for the handling of stream sources.

# ### ### ### ######### ######### #########
## Requirements

package require transfer::copy ; # Data transmission core
package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type ::transfer::data::source {

    # ### ### ### ######### ######### #########
    ## API

    #                                                        Source is ...
    option -string   -default {} -configuremethod C-str  ; # a string.
    option -channel  -default {} -configuremethod C-chan ; # an open & readable channel.
    option -file     -default {} -configuremethod C-file ; # a file.
    option -variable -default {} -configuremethod C-var  ; # a string held by the named variable.

    option -size     -default -1 ; # number of characters to transfer.
    option -progress -default {}

    method type  {} {}
    method data  {} {}
    method size  {} {}
    method valid {mv} {}

    method transmit {sock blocksize done} {}

    # ### ### ### ######### ######### #########
    ## Implementation

    method type {} {
	return $myxtype
    }

    method data {} {
	switch -exact -- $myetype {
	    undefined {
		return -code error "Data source is undefined"
	    }
	    string - chan {
		return $mysrc
	    }
	    variable {
		upvar \#0 $mysrc thevalue
		return $thevalue
	    }
	    file {
		return [open $mysrc r]
	    }
	}
    }

    method size {} {
	if {$options(-size) < 0} {
	    switch -exact -- $myetype {
		undefined {
		    return -code error "Data source is undefined"
		}
		string {
		    return [string length $mysrc]
		}
		variable {
		    upvar \#0 $mysrc thevalue
		    return [string length $thevalue]
		}
		chan - file {
		    # Nothing, -1 passes through
		    # We do not use [file size] for a file, as a
		    # user-specified encoding may distort the
		    # counting.
		}
	    }
	}

	return $options(-size)
    }

    method valid {mv} {
	upvar 1 $mv message

	switch -exact -- $myetype {
	    undefined {
		set message "Data source is undefined"
		return 0
	    }
	    string - variable {
		if {[$self size] > [string length [$self data]]} {
		    set message "Not enough data to transmit"
		    return 0
		}
	    }
	    chan {
		# Additional check of option ?
	    }
	    file {
		# Additional check of option ?
	    }
	}
	return 1
    }

    method transmit {sock blocksize done} {
	::transfer::copy::do \
	    [$self type] [$self data] $sock \
	    -size      [$self size] \
	    -blocksize $blocksize \
	    -command   $done \
	    -progress  $options(-progress)
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal helper commands.

    method C-str {o newvalue} {
	set myetype string
	set myxtype string
	set mysrc   $newvalue
	return
    }

    method C-var {o newvalue} {
	set myetype variable
	set myxtype string

	if {![uplevel \#0 {info exists $newvalue}]} {
	    return -code error "Bad variable \"$newvalue\", does not exist"
	}

	set mysrc $newvalue
	return
    }

    method C-chan {o newvalue} {
	if {![llength [file channels $newvalue]]} {
	    return -code error "Bad channel handle \"$newvalue\", does not exist"
	}
	set myetype chan
	set myxtype chan
	set mysrc   $newvalue
	return
    }

    method C-file {o newvalue} {
	if {![file exists $newvalue]} {
	    return -code error "File \"$newvalue\" does not exist"
	}
	if {![file readable $newvalue]} {
	    return -code error "File \"$newvalue\" not readable"
	}
	if {![file isfile $newvalue]} {
	    return -code error "File \"$newvalue\" not a file"
	}
	set myetype file
	set myxtype chan
	set mysrc   $newvalue
	return
    }

    # ### ### ### ######### ######### #########
    ## Data structures

    variable myetype undefined
    variable myxtype undefined
    variable mysrc

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide transfer::data::source 0.2
