if {![package vsatisfies [package provide Tcl] 8.2]} return
package ifneeded sak::doc       1.0 [list source [file join $dir doc.tcl]]
package ifneeded sak::doc::auto 1.0 [list source [file join $dir doc_auto.tcl]]

