if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded uevent         0.3.2 [list source [file join $dir uevent.tcl]]
package ifneeded uevent::onidle 0.2   [list source [file join $dir uevent_onidle.tcl]]
