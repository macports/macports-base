if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded html 1.6 [list source [file join $dir html.tcl]]
