if {![package vsatisfies [package provide Tcl] 8.5 9]} {
    # PRAGMA: returnok
    return
}
package ifneeded des 1.2 [list source [file join $dir des.tcl]]
package ifneeded tclDES 1.1 [list source [file join $dir tcldes.tcl]]
package ifneeded tclDESjr 1.1 [list source [file join $dir tcldesjr.tcl]]
