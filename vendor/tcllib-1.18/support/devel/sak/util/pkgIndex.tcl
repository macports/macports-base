if {![package vsatisfies [package provide Tcl] 8.2]} return
package ifneeded sak::util     1.0 [list source [file join $dir util.tcl]]
package ifneeded sak::registry 1.0 [list source [file join $dir registry.tcl]]
package ifneeded sak::animate  1.0 [list source [file join $dir anim.tcl]]
package ifneeded sak::color    1.0 [list source [file join $dir color.tcl]]
package ifneeded sak::feedback 1.0 [list source [file join $dir feedback.tcl]]
