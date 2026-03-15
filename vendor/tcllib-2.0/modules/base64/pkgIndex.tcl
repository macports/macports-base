if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded base64   2.6.1 [list source [file join $dir base64.tcl]]
package ifneeded uuencode 1.1.6 [list source [file join $dir uuencode.tcl]]
package ifneeded yencode  1.1.4 [list source [file join $dir yencode.tcl]]
package ifneeded ascii85  1.1.1 [list source [file join $dir ascii85.tcl]]
