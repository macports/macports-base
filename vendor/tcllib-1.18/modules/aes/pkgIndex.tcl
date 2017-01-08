if {![package vsatisfies [package provide Tcl] 8.5]} {
    # PRAGMA: returnok
    return
}
package ifneeded aes 1.2.1 [list source [file join $dir aes.tcl]]
