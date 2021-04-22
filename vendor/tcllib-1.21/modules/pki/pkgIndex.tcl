if {![package vsatisfies [package provide Tcl] 8.6]} {return}

package ifneeded pki 0.20 [list source [file join $dir pki.tcl]]
