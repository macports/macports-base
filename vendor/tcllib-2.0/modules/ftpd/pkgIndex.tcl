if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded ftpd 1.4.1 [list source [file join $dir ftpd.tcl]]
