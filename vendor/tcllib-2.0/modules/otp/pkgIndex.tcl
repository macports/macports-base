# pkgIndex.tcl -*- tcl -*-
if {![package vsatisfies [package provide Tcl] 8.5 9]} { return }
package ifneeded otp 1.1.0 [list source [file join $dir otp.tcl]]
