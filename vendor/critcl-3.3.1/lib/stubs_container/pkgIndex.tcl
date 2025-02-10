if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}
#checker -scope global exclude warnUndefinedVar
package ifneeded stubs::container 1.1.1 [list source [file join $dir container.tcl]]
