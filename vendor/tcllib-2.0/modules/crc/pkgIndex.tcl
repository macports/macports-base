if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded cksum 1.1.5 [list source [file join $dir cksum.tcl]]
package ifneeded crc16 1.1.5 [list source [file join $dir crc16.tcl]]
package ifneeded crc32 1.3.4 [list source [file join $dir crc32.tcl]]
package ifneeded sum   1.1.3 [list source [file join $dir sum.tcl]]
