if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded htmlparse 1.2.2 [list source [file join $dir htmlparse.tcl]]
