# -*- tcl -*-
# ### ### ### ######### ######### #########
## Terminal packages - Generic receiver operations

# ### ### ### ######### ######### #########
## Requirements

namespace eval ::term::receive {}

# ### ### ### ######### ######### #########
## API. Read character from specific channel,
##      or default (stdin). Processing of
##      character sequences.

proc ::term::receive::getch {{chan stdin}} {
    return [read $chan 1]
}

proc ::term::receive::listen {cmd {chan stdin}} {
    fconfigure $chan -blocking 0
    fileevent  $chan readable \
	    [list ::term::receive::Foreach $chan $cmd]
    return
}

proc ::term::receive::unlisten {{chan stdin}} {
    fileevent $chan readable {}
    return
}

# ### ### ### ######### ######### #########
## Internals

proc ::term::receive::Foreach {chan cmd} {
    set string [read $chan]
    if {[string length $string]} {
	#puts stderr "F($string)"
	uplevel #0 [linsert $cmd end process $string]
    }
    if {[eof $chan]} {
	close $chan
	uplevel #0 [linsert $cmd end eof]
    }
    return
}

# ### ### ### ######### ######### #########
## Initialization

namespace eval ::term::receive {
    namespace export getch listen
}

# ### ### ### ######### ######### #########
## Ready

package provide term::receive 0.1

##
# ### ### ### ######### ######### #########
