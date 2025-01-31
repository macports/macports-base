if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded mapproj 1.1 [list source [file join $dir mapproj.tcl]]
