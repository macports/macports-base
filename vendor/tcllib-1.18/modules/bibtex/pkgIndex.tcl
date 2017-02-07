if {![package vsatisfies [package provide Tcl] 8.4]} {return}
package ifneeded bibtex 0.6 [list source [file join $dir bibtex.tcl]]
