if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded htmlparse 1.2.3 [list source [file join $dir htmlparse.tcl]]
