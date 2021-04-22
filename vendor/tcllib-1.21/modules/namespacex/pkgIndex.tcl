if {![package vsatisfies [package provide Tcl] 8.5]} {
    # PRAGMA: returnok
    return
}
package ifneeded namespacex 0.3 [list source [file join $dir namespacex.tcl]]
