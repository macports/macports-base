# Tcl package index file, version 1.1

if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded units 2.2.1 [list source [file join $dir units.tcl]]
