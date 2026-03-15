if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}

package ifneeded zipfile::decode 0.10.1 [list source [file join $dir decode.tcl]]
package ifneeded zipfile::encode 0.5.1 [list source [file join $dir encode.tcl]]

if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}

package ifneeded zipfile::mkzip 1.2.4 [list source [file join $dir mkzip.tcl]]
