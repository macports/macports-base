# Package index file for PKGNAME
#
if { [package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded PKGNAME 1.0 [list load [file join $dir PKGNAME.dll]]

# Note: add support for other platforms!
