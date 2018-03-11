# package index for md5crypt
if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded md5crypt 1.1.0 [list source [file join $dir md5crypt.tcl]]
