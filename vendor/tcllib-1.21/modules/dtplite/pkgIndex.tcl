if {![package vsatisfies [package provide Tcl] 8.2]} {
    # PRAGMA: returnok
    return
}
package ifneeded dtplite 1.3.1 [list source [file join $dir dtplite.tcl]]
