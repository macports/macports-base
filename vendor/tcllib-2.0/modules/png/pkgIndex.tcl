if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded png 0.4.1 [list source [file join $dir png.tcl]]
