# pkgIndex.tcl                                                    -*- tcl -*-
# $Id: pkgIndex.tcl,v 1.10 2008/08/05 20:40:04 andreas_kupries Exp $
if { ![package vsatisfies [package provide Tcl] 8.3] } {
    # PRAGMA: returnok
    return 
}
package ifneeded irc     0.6.1 [list source [file join $dir irc.tcl]]
package ifneeded picoirc 0.5.2 [list source [file join $dir picoirc.tcl]]
