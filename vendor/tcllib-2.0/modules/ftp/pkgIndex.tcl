if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded ftp         2.4.14 [list source [file join $dir ftp.tcl]]
package ifneeded ftp::geturl 0.2.3  [list source [file join $dir ftp_geturl.tcl]]
