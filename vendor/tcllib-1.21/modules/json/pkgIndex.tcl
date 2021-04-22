# Tcl package index file, version 1.1

if {![package vsatisfies [package provide Tcl] 8.4]} {return}
package ifneeded json 1.3.4 [list source [file join $dir json.tcl]]

if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded json::write 1.0.4 [list source [file join $dir json_write.tcl]]
