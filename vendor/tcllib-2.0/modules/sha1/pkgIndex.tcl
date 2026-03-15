if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded sha256  1.0.6 [list source [file join $dir sha256.tcl]]
package ifneeded sha256c 1.0.5 [list source [file join $dir sha256c.tcl]]
package ifneeded sha1    2.0.5 [list source [file join $dir sha1.tcl]]
package ifneeded sha1    1.1.2 [list source [file join $dir sha1v1.tcl]]
