if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}
package ifneeded critcl::emap 1.3.1 [list source [file join $dir emap.tcl]]
