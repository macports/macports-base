if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded cache::async 0.3.2 [list source [file join $dir async.tcl]]

