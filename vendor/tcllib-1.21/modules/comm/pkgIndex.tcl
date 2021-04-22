if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded comm 4.7 [list source [file join $dir comm.tcl]]
