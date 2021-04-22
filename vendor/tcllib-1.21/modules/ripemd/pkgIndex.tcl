# pkgIndex.tcl - 
#
# RIPEMD package index file
#
# This package has been tested with tcl 8.2.3 and above.
#
# $Id: pkgIndex.tcl,v 1.6 2009/05/07 01:12:59 patthoyts Exp $

if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded ripemd128 1.0.5 [list source [file join $dir ripemd128.tcl]]
package ifneeded ripemd160 1.0.5 [list source [file join $dir ripemd160.tcl]]
