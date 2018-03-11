if {![package vsatisfies [package provide Tcl] 8.4]} {return}

package ifneeded zipfile::decode 0.7 [list source [file join $dir decode.tcl]]
package ifneeded zipfile::encode 0.4 [list source [file join $dir encode.tcl]]

if {![package vsatisfies [package provide Tcl] 8.6]} {return}

package ifneeded zipfile::mkzip 1.2 [list source [file join $dir mkzip.tcl]]
