if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded md5 2.0.9 [list source [file join $dir md5x.tcl]]
package ifneeded md5 1.4.6 [list source [file join $dir md5.tcl]]
