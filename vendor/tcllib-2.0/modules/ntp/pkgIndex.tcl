if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded time 1.2.2 [list source [file join $dir time.tcl]]
