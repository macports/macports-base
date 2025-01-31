if {![package vsatisfies [package provide Tcl] 8.5 9]} {
    # PRAGMA: returnok
    return
}
package ifneeded blowfish 1.0.6 [list source [file join $dir blowfish.tcl]]
