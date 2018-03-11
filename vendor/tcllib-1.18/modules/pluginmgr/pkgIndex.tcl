if {![package vsatisfies [package provide Tcl] 8.4]} {return}
package ifneeded pluginmgr 0.3 [list source [file join $dir pluginmgr.tcl]]
