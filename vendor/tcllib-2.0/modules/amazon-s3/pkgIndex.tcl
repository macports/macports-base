# pkgIndex.tcl --
# Copyright (c) 2006 Darren New
# This is for the Amazon S3 web service packages.

if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}

package ifneeded xsxp 1.1   [list source [file join $dir xsxp.tcl]]
package ifneeded S3   1.0.5 [list source [file join $dir S3.tcl]]

