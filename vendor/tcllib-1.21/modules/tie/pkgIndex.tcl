if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded tie                1.2 [list source [file join $dir tie.tcl]]
package ifneeded tie::std::file     1.1 [list source [file join $dir tie_file.tcl]]
package ifneeded tie::std::growfile 1.1 [list source [file join $dir tie_growfile.tcl]]
package ifneeded tie::std::log      1.1 [list source [file join $dir tie_log.tcl]]
package ifneeded tie::std::array    1.1 [list source [file join $dir tie_array.tcl]]
package ifneeded tie::std::rarray   1.1 [list source [file join $dir tie_rarray.tcl]]
package ifneeded tie::std::dsource  1.1 [list source [file join $dir tie_dsource.tcl]]

