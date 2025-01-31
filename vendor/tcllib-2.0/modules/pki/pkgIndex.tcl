if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}

package ifneeded pki 0.22 [list source [file join $dir pki.tcl]]
