if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded tepam          0.5.4 [list source [file join $dir tepam.tcl]]
package ifneeded tepam::doc_gen 0.1.3 [list source [file join $dir tepam_doc_gen.tcl]]
