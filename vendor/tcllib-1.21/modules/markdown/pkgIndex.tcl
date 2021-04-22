if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded Markdown 1.2.2 [list source [file join $dir markdown.tcl]]
