if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded counter 2.0.6 [list source [file join $dir counter.tcl]]
