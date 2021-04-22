if {![package vsatisfies [package provide Tcl] 8.3]} return
package ifneeded pregistry 0.1 [list source [file join $dir registry.tcl]]
