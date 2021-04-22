if {![package vsatisfies [package provide Tcl] 8.2]} return
package ifneeded sak::validate             1.0 [list source [file join $dir validate.tcl]]
package ifneeded sak::validate::manpages   1.0 [list source [file join $dir manpages.tcl]]
package ifneeded sak::validate::versions   1.0 [list source [file join $dir versions.tcl]]
package ifneeded sak::validate::testsuites 1.0 [list source [file join $dir testsuites.tcl]]
package ifneeded sak::validate::syntax     1.0 [list source [file join $dir syntax.tcl]]
