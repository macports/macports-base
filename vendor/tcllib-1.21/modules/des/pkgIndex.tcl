if {![package vsatisfies [package provide Tcl] 8.2]} {
    # PRAGMA: returnok
    return
}
package ifneeded des 1.1.0 [list source [file join $dir des.tcl]]
package ifneeded tclDES 1.0.0 [list source [file join $dir tcldes.tcl]]
package ifneeded tclDESjr 1.0.0 [list source [file join $dir tcldesjr.tcl]]
