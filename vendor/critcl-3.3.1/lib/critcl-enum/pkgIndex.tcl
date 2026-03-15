if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}
package ifneeded critcl::enum 1.2.1 [list source [file join $dir enum.tcl]]
