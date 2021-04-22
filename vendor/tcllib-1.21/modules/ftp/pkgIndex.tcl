if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded ftp         2.4.13 [list source [file join $dir ftp.tcl]]
package ifneeded ftp::geturl 0.2.2  [list source [file join $dir ftp_geturl.tcl]]
