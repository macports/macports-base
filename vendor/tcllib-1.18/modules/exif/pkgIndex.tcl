if {![package vsatisfies [package provide Tcl] 8.3]} {return}
package ifneeded exif 1.1.2 [list source [file join $dir exif.tcl]]
