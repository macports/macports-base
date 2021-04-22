if {![package vsatisfies [package provide Tcl] 8.3]} {return}
package ifneeded smtp 1.5.1 [list source [file join $dir smtp.tcl]]

if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded mime 1.7.0 [list source [file join $dir mime.tcl]]
