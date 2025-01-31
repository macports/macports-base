if {![package vsatisfies [package require Tcl] 8.6 9]} {return}
package ifneeded mkdoc 0.7.2 [list source [file join $dir mkdoc.tcl]]
