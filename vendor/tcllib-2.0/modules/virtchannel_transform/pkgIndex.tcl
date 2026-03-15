if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}

package ifneeded tcl::transform::adler32 1.1     [list source [file join $dir adler32.tcl]]
package ifneeded tcl::transform::base64 1.1      [list source [file join $dir base64.tcl]]
package ifneeded tcl::transform::counter 1.1     [list source [file join $dir counter.tcl]]
package ifneeded tcl::transform::crc32 1.1       [list source [file join $dir crc32.tcl]]
package ifneeded tcl::transform::hex 1.1         [list source [file join $dir hex.tcl]]
package ifneeded tcl::transform::identity 1.1    [list source [file join $dir identity.tcl]]
package ifneeded tcl::transform::limitsize 1.1   [list source [file join $dir limitsize.tcl]]
package ifneeded tcl::transform::observe 1.1     [list source [file join $dir observe.tcl]]
package ifneeded tcl::transform::otp 1.1         [list source [file join $dir otp.tcl]]
package ifneeded tcl::transform::rot 1.1         [list source [file join $dir rot.tcl]]
package ifneeded tcl::transform::spacer 1.1      [list source [file join $dir spacer.tcl]]
package ifneeded tcl::transform::zlib 1.0.2      [list source [file join $dir zlib.tcl]]
