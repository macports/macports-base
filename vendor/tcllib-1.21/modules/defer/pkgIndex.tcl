if {![package vsatisfies [package provide Tcl] 8.6]} {
    # PRAGMA: returnok
    return
}
package ifneeded defer 1 [list source [file join $dir defer.tcl]]
