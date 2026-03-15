if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded exif 1.1.4 [list source [file join $dir exif.tcl]]
