# pkgIndex.tcl -*- tcl -*-
if { ![package vsatisfies [package provide Tcl] 8.6 9] } {
    # PRAGMA: returnok
    return
}
package ifneeded irc     0.8.0 [list source [file join $dir irc.tcl]]
package ifneeded picoirc 0.14.0 [list source [file join $dir picoirc.tcl]]
