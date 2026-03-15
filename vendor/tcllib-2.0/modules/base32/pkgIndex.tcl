if {![package vsatisfies [package provide Tcl] 8.5 9]} return
package ifneeded base32       0.2 [list source [file join $dir base32.tcl]]
package ifneeded base32::hex  0.2 [list source [file join $dir base32hex.tcl]]
package ifneeded base32::core 0.2 [list source [file join $dir base32core.tcl]]
