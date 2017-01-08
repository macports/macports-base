# pkgIndex.tcl -
#
# $Id: pkgIndex.tcl,v 1.21 2010/08/16 17:35:18 andreas_kupries Exp $

if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded dns    1.3.5 [list source [file join $dir dns.tcl]]
package ifneeded resolv 1.0.3 [list source [file join $dir resolv.tcl]]
package ifneeded ip     1.3   [list source [file join $dir ip.tcl]]
package ifneeded spf    1.1.1 [list source [file join $dir spf.tcl]]
