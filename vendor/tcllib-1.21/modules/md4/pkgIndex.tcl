# This package has been tested with tcl 8.2.3 and above.
if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded md4 1.0.7 [list source [file join $dir md4.tcl]]
