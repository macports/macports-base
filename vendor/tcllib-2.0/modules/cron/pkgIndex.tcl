if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}
package ifneeded cron 2.2 [list source [file join $dir cron.tcl]]
