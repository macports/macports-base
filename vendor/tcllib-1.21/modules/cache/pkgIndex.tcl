if {![package vsatisfies [package provide Tcl] 8.4]} {return}
package ifneeded cache::async 0.3.1 [list source [file join $dir async.tcl]]

