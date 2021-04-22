if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded lazyset 1 [list source [file join $dir lazyset.tcl]]
