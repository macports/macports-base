if {![package vsatisfies [package provide Tcl] 8.2]} return
package ifneeded sak::localdoc 1.0 [list source [file join $dir localdoc.tcl]]
