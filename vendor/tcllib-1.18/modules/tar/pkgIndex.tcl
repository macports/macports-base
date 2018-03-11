if {![package vsatisfies [package provide Tcl] 8.4]} {
    # PRAGMA: returnok
    return
}
package ifneeded tar 0.10 [list source [file join $dir tar.tcl]]
