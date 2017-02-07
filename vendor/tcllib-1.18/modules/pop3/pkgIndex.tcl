if {![package vsatisfies [package provide Tcl] 8.4]} {return}
package ifneeded pop3 1.9 [list source [file join $dir pop3.tcl]]
