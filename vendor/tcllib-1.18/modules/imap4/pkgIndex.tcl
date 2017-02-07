if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded imap4 0.5.3 [list source [file join $dir imap4.tcl]]
