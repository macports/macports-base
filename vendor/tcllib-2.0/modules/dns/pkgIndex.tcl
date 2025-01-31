# pkgIndex.tcl -

if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded dns    1.6.1 [list source [file join $dir dns.tcl]]
package ifneeded resolv 1.0.4 [list source [file join $dir resolv.tcl]]
package ifneeded ip     1.5.1 [list source [file join $dir ip.tcl]]
package ifneeded spf    1.1.2 [list source [file join $dir spf.tcl]]
