if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded report 0.5 [list source [file join $dir report.tcl]]
