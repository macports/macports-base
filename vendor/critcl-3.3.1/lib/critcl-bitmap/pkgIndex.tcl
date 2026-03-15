if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}
package ifneeded critcl::bitmap 1.1.1 [list source [file join $dir bitmap.tcl]]
