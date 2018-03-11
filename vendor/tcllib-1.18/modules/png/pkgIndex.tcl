if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded png 0.2 [list source [file join $dir png.tcl]]
