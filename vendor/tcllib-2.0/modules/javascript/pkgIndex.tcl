# Tcl package index file, version 1.1

if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded javascript 1.0.3 [list source [file join $dir javascript.tcl]]
