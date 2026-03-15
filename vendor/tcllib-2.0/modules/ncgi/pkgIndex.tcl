if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded ncgi 1.4.6 [list source [file join $dir ncgi.tcl]]
