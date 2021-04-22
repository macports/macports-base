# -*- tcl -*-
# ### ### ### ######### ######### #########
##
# Basic byte transfer facilities. Essentially fcopy with a different
# API, hopefully better (progress and completion are separate). Also
# equivalent facilities to transfer an explicitly given string instead
# of reading the data to be transfered from a channel.

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.4

namespace eval ::transfer::copy {
    namespace export do chan string options
    namespace export doChan doString
}

# ### ### ### ######### ######### #########
## API commands

proc ::transfer::copy::do {type in out args} {
    switch -exact -- $type {
	chan - string {}
	default {
	    return -code error \
		    "Unknown type \"$type\",\
		    expected chan, or string"
	}
    }

    options $out $args settings

    switch -exact -- $type {
	chan   {doChan   $in $out settings}
	string {doString $in $out settings}
    }
    return
}

proc ::transfer::copy::chan {in out args} {
    # Options: -size n
    #          -blocksize n
    #          -progress cmd, (cmd n)       - feedback
    #          -command cmd,  (cmd n ?err?) - completion

    options     $out $args settings
    doChan  $in $out       settings
    return
}

proc ::transfer::copy::string {string out args} {
    # Options: -size n
    #          -blocksize n
    #          -progress cmd, (cmd n)       - feedback
    #          -command cmd,  (cmd n ?err?) - completion

    options          $out $args settings
    doString $string $out       settings
    return
}

proc ::transfer::copy::options {chan alist optv {defaults {}}} {
    upvar 1 $optv settings

    # Prepare defaults, hardwired, output channel, and caller

    array set settings {
	-size     -1
	-progress {}
	-command  {}
    }

    array set settings [CGet $chan]
    array set settings $defaults

    # Process the options

    set capture 0
    foreach o $alist {
	# Store argument to previous option
	if {$capture} {
	    set settings($key) $o
	    set capture 0
	    continue
	}
	# Dispatch & process the option
	switch -exact -- $o {
	    -blocksize -
	    -command -
	    -encoding -
	    -eofchar -
	    -progress -
	    -size -
	    -translation {
		set key $o
		set capture 1
	    }
	    default {
		return -code error \
			"Unknown option \"$o\",\
			expected one of -size,\
			-blocksize, -progress,\
			or -command"
	    }
	}
    }
    if {$capture} {
	return -code error \
		"wrong\#args, option \"$o\" \
		is without argument"
    }

    if {![llength $settings(-command)]} {
	return -code error \
		"Completion callback is missing"
    }

    return
}

# ### ### ### ######### ######### #########
## Implementation. Transfer from a channel.

proc ::transfer::copy::doChan {in out ov} {
    upvar 1 $ov settings

    upvar 0 settings(-size)    size
    upvar 0 settings(-command) command

    if {$size == 0} {
	# Nothing to transfer. Is that an error, or mildy ok ?
	# For now: Ok.

	Run command 0
	return
    }

    set state [CGet $out]
    Configure $out [array get settings]
    upvar 0 settings(-progress) progress
    upvar 0 settings(-blocksize) blocksize

    if {$size > 0} {
	if {$blocksize < $size} {
	    set n $blocksize
	} else {
	    set n $size
	}

	fcopy $in $out -size $n -command \
		[list \
		     ::transfer::copy::HandlerChan \
		     $n $size $size 0 \
		     $progress $command \
		     $in $out $state]
    } else {
	fcopy $in $out -size $blocksize -command \
	    [list \
		 ::transfer::copy::HandlerChan \
		 $blocksize $size $size 0 \
		 $progress $command \
		 $in $out $state]
    }
    return
}

proc ::transfer::copy::HandlerChan {
    blocksize remainder size total
    progress command
    in out state
    transfered args
} {
    incr total $transfered

    # Progress
    if {[llength $progress]} {
	Run progress $total
    }

    # Error signaled ?
    if {[llength $args]} {
	# Restore channel state and then propagate the problem
	# forward.
	Configure $out $state
	Run command $total [lindex $args 0]
	return
    }

    # How much transfered, have we transfered everything ?

    if {($remainder >= 0) && ($size <= $total)} {
	# Everything has been transfered, trigger completion
	# callback. The caller has to close the output channel!

	Configure $out $state
	Run command $total
	return
    }

    if {[eof $in]} {
	# Input has closed, action depends on the specified size. -1
	# signals transfer to eof, so we are now done. Otherwise we
	# have transfered less than we wanted, and that is an error.

	Configure $out $state
	if {$size < 0} {
	    Run command $total
	} else {
	    Run command $total \
		"Transfer aborted, not enough input"
	}
	return
    }

    # Restart, for next chunk.
    if {$size > 0} {
	incr remainder -$blocksize
	if {$blocksize < $remainder} {
	    set n $blocksize
	} else {
	    set n $remainder
	}
	puts \tnext=$n

	fcopy $in $out -size $n -command \
	    [list \
		 ::transfer::copy::HandlerChan \
		 $blocksize $remainder $size $total \
		 $progress $command \
		 $in $out $state]
    } else {
	fcopy $in $out -size $blocksize -command \
	    [list \
		 ::transfer::copy::HandlerChan \
		 $blocksize $remainder $size $total \
		 $progress $command \
		 $in $out $state]
    }
    return
}

# ### ### ### ######### ######### #########
## Implementation. Transfer from a string.

proc ::transfer::copy::doString {str out ov} {
    upvar 1 $ov settings

    upvar 0 settings(-size)    size
    upvar 0 settings(-command) command

    if {$size == 0} {
	# Nothing to transfer. Is that an error, or mildy ok ?
	# For now: Ok

	Run command 0
	return
    }

    set length [::string length $str]
    if {$size > 0} {
	if {$length < $size} {
	    Run command 0 \
		    "Transfer impossible,\
		    not enough data for size"
	    return
	}
	set last $size
    } else {
	# size < 0 (Note size == 0 already captured)
	set last $length
	set size $last
    }

    # We transfer the string in chunks of -blocksize. We cannot use
    # fcopy for this, so do our own event processing.

    set state [CGet $out]
    Configure $out [array get settings]

    upvar 0 settings(-blocksize) blocksize
    upvar 0 settings(-progress)  progress

    fileevent $out writable [list \
	    ::transfer::copy::HandlerString \
	    $size 0 $last \
	    $blocksize 0 [expr {$blocksize - 1}] \
	    $progress $command \
	    $str $out $state]
    return
}

proc ::transfer::copy::HandlerString {
    pending transfered last
    block from to
    progress command
    str out state
} {
    # pending + transfered = last. from/to is chunk to transfer.

    if {$to > $last} {
	set  to         end
	incr transfered $pending
	set  pending    0
    }

    set code [catch {
	puts -nonewline $out \
		[::string range $str $from $to]
    } res]
    if {$code} {
	Configure $out $state
	fileevent $out writable {}
	Run command $transfered $res
	return
    }

    if {[llength $progress]} {
	Run progress $transfered
    }

    if {$pending == 0} {
	# Done
	Configure $out $state
	fileevent $out writable {}
	Run command $transfered
    }

    # Prepare for next chunk

    incr transfered $block
    incr pending   -$block
    incr from       $block
    incr to         $block

    fileevent $out writable [list \
		  ::transfer::copy::HandlerString \
		  $pending $transfered $last \
		  $block $from $to \
		  $progress $command \
		  $str $out $state]
    return
}

# ### ### ### ######### ######### #########
## Implementation. Support commands.

proc ::transfer::copy::Run {cmdv args} {
    upvar 1 $cmdv c
    set command $c
    foreach a $args {lappend command $a}
    return [uplevel #0 $command]

    # 8.5: {*}$c {*}$args
}

proc ::transfer::copy::CGet {chan} {
    array set settings {}

    foreach o {
	-buffersize -encoding -translation -eofchar -blocking
    } {
	set settings($o) [fconfigure $chan $o]
    }

    set   settings(-blocksize) $settings(-buffersize)
    unset settings(-buffersize)
    return [array get settings]
}

proc ::transfer::copy::Configure {chan settings} {
    array set tmp $settings

    set   tmp(-buffersize) $tmp(-blocksize)
    unset tmp(-blocksize)
    unset -nocomplain tmp(-progress)
    unset -nocomplain tmp(-command)
    unset -nocomplain tmp(-size)

    foreach o [array names tmp] {
	fconfigure $chan $o $tmp($o)
    }
    return
}

# ### ### ### ######### ######### #########
## Ready

package provide transfer::copy 0.3
