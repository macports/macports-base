if {![package vsatisfies [package provide Tcl] 8.3]} {return}
package ifneeded tepam          0.5   [list source [file join $dir tepam.tcl]]
package ifneeded tepam::doc_gen 0.1.1 [list source [file join $dir tepam_doc_gen.tcl]]
