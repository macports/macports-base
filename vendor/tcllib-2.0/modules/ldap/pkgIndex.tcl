# Tcl package index file, version 1.1

if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded ldap 1.10.2 [list source [file join $dir ldap.tcl]]

# the OO level wrapper for ldap
package ifneeded ldapx 1.3 [list source [file join $dir ldapx.tcl]]
