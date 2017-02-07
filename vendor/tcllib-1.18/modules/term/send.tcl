# -*- tcl -*-
# ### ### ### ######### ######### #########
## Terminal packages - Generic sender operations

# ### ### ### ######### ######### #########
## Requirements

namespace eval ::term::send {}

# ### ### ### ######### ######### #########
## API. Write to channel, or default (stdout)

proc ::term::send::wr {str} {
    wrch stdout $str
    return
}

proc ::term::send::wrch {ch str} {
    puts -nonewline $ch $str
    flush           $ch
    return
}

namespace eval ::term::send {
    namespace export wr wrch
}

# ### ### ### ######### ######### #########
## Ready

package provide term::send 0.1

##
# ### ### ### ######### ######### #########
