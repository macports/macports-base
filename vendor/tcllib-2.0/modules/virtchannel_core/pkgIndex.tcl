if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}

package ifneeded tcl::chan::core 1.1   [list source [file join $dir core.tcl]]
package ifneeded tcl::chan::events 1.1 [list source [file join $dir events.tcl]]

if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}

package ifneeded tcl::transform::core 1.1 [list source [file join $dir transformcore.tcl]]
