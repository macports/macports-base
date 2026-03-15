if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded lazyset 1.1 [list source [file join $dir lazyset.tcl]]
