if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded tiff 0.2.3 [list source [file join $dir tiff.tcl]]
