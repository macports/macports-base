# crcc.tcl - Copyright (C) 2002 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# Place holder for building a critcl C module for this tcllib module.
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------
# $Id: crcc.tcl,v 1.4 2008/03/25 07:15:35 andreas_kupries Exp $

package require critcl 

namespace eval ::crc {
    variable rcsid {$Id: crcc.tcl,v 1.4 2008/03/25 07:15:35 andreas_kupries Exp $}

    critcl::ccode {
        /* no code required in this file */
    }
}

# @sak notprovided crcc
package provide crcc 1.0.0