if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded ident 0.44 [list source [file join $dir ident.tcl]]

