if {![package vsatisfies [package require Tcl] 8.5 9]} return
package ifneeded debug            1.0.7 [list source [file join $dir debug.tcl]]
package ifneeded debug::heartbeat 1.0.2 [list source [file join $dir heartbeat.tcl]]
package ifneeded debug::timestamp 1.1   [list source [file join $dir timestamp.tcl]]
package ifneeded debug::caller    1.2   [list source [file join $dir caller.tcl]]
