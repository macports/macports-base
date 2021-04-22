if {![package vsatisfies [package provide Tcl] 8.2]} return
package ifneeded sak::test         1.0 [list source [file join $dir test.tcl]]
package ifneeded sak::test::run    1.0 [list source [file join $dir run.tcl]]
package ifneeded sak::test::shells 1.0 [list source [file join $dir shells.tcl]]
package ifneeded sak::test::shell  1.0 [list source [file join $dir shell.tcl]]
