# Tcl package index file, version 1.1

if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded json        1.3.6 [list source [file join $dir json.tcl]]
package ifneeded json::write 1.0.5 [list source [file join $dir json_write.tcl]]
