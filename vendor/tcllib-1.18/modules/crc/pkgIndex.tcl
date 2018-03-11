if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded cksum 1.1.4 [list source [file join $dir cksum.tcl]]
package ifneeded crc16 1.1.2 [list source [file join $dir crc16.tcl]]
package ifneeded crc32 1.3.2 [list source [file join $dir crc32.tcl]]
package ifneeded sum   1.1.2 [list source [file join $dir sum.tcl]]
