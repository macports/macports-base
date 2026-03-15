if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}
package ifneeded critcl::cutil 0.5 [list source [file join $dir cutil.tcl]]
