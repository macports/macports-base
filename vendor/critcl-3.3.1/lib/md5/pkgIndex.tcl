if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}
package ifneeded md5 1.5 [list source [file join $dir md5.tcl]]
