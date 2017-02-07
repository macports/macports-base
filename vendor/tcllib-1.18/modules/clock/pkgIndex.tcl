if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded clock::rfc2822 0.1 [list source [file join $dir rfc2822.tcl]]
package ifneeded clock::iso8601 0.1 [list source [file join $dir iso8601.tcl]]
