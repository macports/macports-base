if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}
package ifneeded critcl::literals 1.4.1 [list source [file join $dir literals.tcl]]
