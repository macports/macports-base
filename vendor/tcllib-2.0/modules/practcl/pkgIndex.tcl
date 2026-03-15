###
if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}
package ifneeded practcl 0.16.6 [list source [file join $dir practcl.tcl]]

