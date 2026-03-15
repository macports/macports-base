if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded control 0.1.4 [list source [file join $dir control.tcl]]
