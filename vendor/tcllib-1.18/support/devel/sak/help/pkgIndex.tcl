if {![package vsatisfies [package provide Tcl] 8.2]} return
package ifneeded sak::help 1.0 [list source [file join $dir help.tcl]]


