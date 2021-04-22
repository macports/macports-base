if {![package vsatisfies [package provide Tcl] 8.3]} {return}
package ifneeded profiler 0.6 [list source [file join $dir profiler.tcl]]
