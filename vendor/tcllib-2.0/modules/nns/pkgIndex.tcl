if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded nameserv::common 0.2 [list source [file join $dir common.tcl]]
package ifneeded nameserv         0.4.3 [list source [file join $dir nns.tcl]]
package ifneeded nameserv::server 0.3.3 [list source [file join $dir server.tcl]]
package ifneeded nameserv::auto   0.4   [list source [file join $dir nns_auto.tcl]]
