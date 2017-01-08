if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded fileutil 1.15 [list source [file join $dir fileutil.tcl]]

if {![package vsatisfies [package provide Tcl] 8.3]} {return}
package ifneeded fileutil::traverse 0.6 [list source [file join $dir traverse.tcl]]

if {![package vsatisfies [package provide Tcl] 8.4]} {return}
package ifneeded fileutil::multi     0.1   [list source [file join $dir multi.tcl]]
package ifneeded fileutil::multi::op 0.5.3 [list source [file join $dir multiop.tcl]]
package ifneeded fileutil::decode    0.2   [list source [file join $dir decode.tcl]]
