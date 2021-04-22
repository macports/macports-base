if {![package vsatisfies [package provide Tcl] 8.3]} return
package ifneeded interp                   0.1.2 [list source [file join $dir interp.tcl]]
package ifneeded interp::delegate::proc   0.2   [list source [file join $dir deleg_proc.tcl]]
package ifneeded interp::delegate::method 0.2   [list source [file join $dir deleg_method.tcl]]
