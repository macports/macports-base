if {![package vsatisfies [package provide Tcl] 8.5 9]} {
    # PRAGMA: returnok
    return
}
package ifneeded dtplite 1.3.2 [list source [file join $dir dtplite.tcl]]
