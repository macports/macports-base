if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded wip 1.3 [list source [file join $dir wip.tcl]]
package ifneeded wip 2.3 [list source [file join $dir wip2.tcl]]
