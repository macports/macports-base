if {![package vsatisfies [package provide Tcl] 8.5 9]} return
package ifneeded interp                   0.1.3 [list source [file join $dir interp.tcl]]
package ifneeded interp::delegate::proc   0.3   [list source [file join $dir deleg_proc.tcl]]
package ifneeded interp::delegate::method 0.3   [list source [file join $dir deleg_method.tcl]]
