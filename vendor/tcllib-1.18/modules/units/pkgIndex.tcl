# Tcl package index file, version 1.1

if {![package vsatisfies [package provide Tcl] 8.1]} {return}
package ifneeded units 2.1.1 [list source [file join $dir units.tcl]]
