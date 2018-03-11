# pkgIndex.tcl -*- tcl -*-
if {![package vsatisfies [package provide Tcl] 8.2]} { return }
package ifneeded otp 1.0.0 [list source [file join $dir otp.tcl]]
