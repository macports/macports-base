if {![package vsatisfies [package provide Tcl] 8.5]} {return}
# Backward compatible alias
package ifneeded nameserv::cluster 0.2.5  {package require udpcluster ; package provide nameserv::cluster 0.2.5}
package ifneeded udpcluster        0.3.3  [list source [file join $dir udpcluster.tcl]]
