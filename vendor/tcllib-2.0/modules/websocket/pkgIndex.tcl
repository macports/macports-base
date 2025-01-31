if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}
package ifneeded websocket 1.6 [list source [file join $dir websocket.tcl]]
