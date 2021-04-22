if {![package vsatisfies [package provide Tcl] 8.4]} {return}
package ifneeded uevent         0.3.1 [list source [file join $dir uevent.tcl]]
package ifneeded uevent::onidle 0.1   [list source [file join $dir uevent_onidle.tcl]]
