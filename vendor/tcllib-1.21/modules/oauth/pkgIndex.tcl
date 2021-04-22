if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded oauth 1.0.3 [list source [file join $dir oauth.tcl]]
