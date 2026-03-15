if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}
package ifneeded clay 0.8.8 [list source [file join $dir clay.tcl]]

