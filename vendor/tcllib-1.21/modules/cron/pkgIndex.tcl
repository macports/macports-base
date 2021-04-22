if {![package vsatisfies [package provide Tcl] 8.6]} {return}
package ifneeded cron 2.1 [list source [file join $dir cron.tcl]]
