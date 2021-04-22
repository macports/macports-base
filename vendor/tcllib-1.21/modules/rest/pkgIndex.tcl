if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded rest 1.5 [list source [file join $dir rest.tcl]]
