if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded websocket 1.4.2 [list source [file join $dir websocket.tcl]]
