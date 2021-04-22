if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded html 1.5 [list source [file join $dir html.tcl]]
