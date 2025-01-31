if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded autoproxy 1.8.1 [list source [file join $dir autoproxy.tcl]]
