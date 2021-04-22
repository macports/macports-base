# Tcl package index file, version 1.1

if {![package vsatisfies [package provide Tcl] 8.4]} {return}
package ifneeded bee 0.1 [list source [file join $dir bee.tcl]]
