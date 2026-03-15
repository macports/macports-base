if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded ripemd128 1.0.6 [list source [file join $dir ripemd128.tcl]]
package ifneeded ripemd160 1.0.7 [list source [file join $dir ripemd160.tcl]]
