# ### ### ### ######### ######### #########
##
# (c) 2007 Andreas Kupries.

# Multi file operations. Singleton based on the multiop processor.

# ### ### ### ######### ######### #########
## Requisites

package require fileutil::multi::op

# ### ### ### ######### ######### #########
## API & Implementation

namespace eval ::fileutil {}

# Create the multiop processor object and make its do method the main
# command of this package.
::fileutil::multi::op ::fileutil::multi::obj

proc ::fileutil::multi {args} {
    return [uplevel 1 [linsert $args 0 ::fileutil::multi::obj do]]
}

# ### ### ### ######### ######### #########
## Ready

package provide fileutil::multi 0.1
