if {![package vsatisfies [package provide Tcl] 8.5 9]} {
    # FRINK: nocheck
    return
}
package ifneeded uri      1.2.8 [list source [file join $dir uri.tcl]]
package ifneeded uri::urn 1.0.4 [list source [file join $dir urn-scheme.tcl]]
