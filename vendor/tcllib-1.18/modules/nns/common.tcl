# -*- tcl -*-
# ### ### ### ######### ######### #########
## Name service - Common/shared information.

# ### ### ### ######### ######### #########
## Requirements

namespace eval ::nameserv::common {}

# ### ### ### ######### ######### #########
## API

proc ::nameserv::common::port {} {
    variable port
    return  $port
}

namespace eval ::nameserv::common {
    # Derivation of the standard port number for this service.

    # nameserv::server
    # -> nameservserver  / remove ':'
    # -> 62637378737837  / phonecode
    # -> 38573           / mod 65536

    variable port 38573

    # The modulo operation is required because IP port numbers are
    # restricted to unsigned short (16 bit), i.e. 1 ... 65535.
}

# ### ### ### ######### ######### #########
## Ready

package provide nameserv::common 0.1

##
# ### ### ### ######### ######### #########
