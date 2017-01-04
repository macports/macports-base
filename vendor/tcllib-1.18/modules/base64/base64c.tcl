# base64c - Copyright (C) 2003 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# This package is a place-holder for the critcl enhanced code present in
# the tcllib base64 module.
#
# Normally this code will become part of the tcllibc library.
#

# @sak notprovided base64c
package require critcl
package provide base64c 0.1.0

namespace eval ::base64c {
    variable base64c_rcsid {$Id: base64c.tcl,v 1.5 2008/03/25 07:15:35 andreas_kupries Exp $}

    critcl::ccode {
        /* no code required in this file */
    }
}
