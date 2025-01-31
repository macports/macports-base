if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded Markdown 1.2.4 [list source [file join $dir markdown.tcl]]
