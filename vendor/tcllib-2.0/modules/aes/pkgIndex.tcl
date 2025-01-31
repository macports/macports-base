if {![package vsatisfies [package provide Tcl] 8.5 9]} {
    # PRAGMA: returnok
    return
}
package ifneeded aes 1.2.2 [list source [file join $dir aes.tcl]]
