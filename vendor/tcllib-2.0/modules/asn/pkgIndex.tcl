# Tcl package index file, version 1.1

if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded asn 0.8.5 [list source [file join $dir asn.tcl]]
