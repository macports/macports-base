if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded fileutil            1.16.3 [list source [file join $dir fileutil.tcl]]
package ifneeded fileutil::traverse  0.7    [list source [file join $dir traverse.tcl]]
package ifneeded fileutil::multi     0.2    [list source [file join $dir multi.tcl]]
package ifneeded fileutil::multi::op 0.5.4  [list source [file join $dir multiop.tcl]]
package ifneeded fileutil::decode    0.2.2  [list source [file join $dir decode.tcl]]
package ifneeded fileutil::paths     1.1    [list source [file join $dir paths.tcl]]
