if {![package vsatisfies [package provide Tcl] 8.3]} {return}
package ifneeded smtp 1.4.5 [list source [file join $dir smtp.tcl]]
if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded mime 1.6 [list source [file join $dir mime.tcl]]
