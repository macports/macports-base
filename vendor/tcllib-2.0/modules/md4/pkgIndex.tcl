# This package has been tested with tcl 8.2.3 and above.
if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded md4 1.0.8 [list source [file join $dir md4.tcl]]
