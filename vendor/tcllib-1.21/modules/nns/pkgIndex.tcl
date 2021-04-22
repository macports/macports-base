if {![package vsatisfies [package provide Tcl] 8]} {return}
package ifneeded nameserv::common 0.1 [list source [file join $dir common.tcl]]

if {![package vsatisfies [package provide Tcl] 8.4]} {return}
package ifneeded nameserv         0.4.2 [list source [file join $dir nns.tcl]]
package ifneeded nameserv::server 0.3.2 [list source [file join $dir server.tcl]]
package ifneeded nameserv::auto   0.3   [list source [file join $dir nns_auto.tcl]]
