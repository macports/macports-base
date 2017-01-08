if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded md5 2.0.7 [list source [file join $dir md5x.tcl]]
package ifneeded md5 1.4.4 [list source [file join $dir md5.tcl]]
