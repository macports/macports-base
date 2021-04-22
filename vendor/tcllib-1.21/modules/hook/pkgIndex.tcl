if {![package vsatisfies [package provide Tcl] 8.5]} {
    # PRAGMA: returnok
    return
}
package ifneeded hook 0.2 [list source [file join $dir hook.tcl]]
