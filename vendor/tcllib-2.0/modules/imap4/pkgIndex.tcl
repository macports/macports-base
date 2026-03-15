if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded imap4 0.5.5 [list source [file join $dir imap4.tcl]]
