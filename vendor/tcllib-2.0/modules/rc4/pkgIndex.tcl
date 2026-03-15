if {![package vsatisfies [package provide Tcl] 8.5 9]} {
    # PRAGMA: returnok
    return
}
package ifneeded rc4 1.2.0 [list source [file join $dir rc4.tcl]]
