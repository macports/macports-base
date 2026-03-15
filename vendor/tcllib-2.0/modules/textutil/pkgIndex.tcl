if {![package vsatisfies [package provide Tcl] 8.5 9]} {
    # FRINK: nocheck
    return
}
package ifneeded textutil           0.10  [list source [file join $dir textutil.tcl]]
package ifneeded textutil::adjust   0.7.4 [list source [file join $dir adjust.tcl]]
package ifneeded textutil::split    0.9   [list source [file join $dir split.tcl]]
package ifneeded textutil::trim     0.8   [list source [file join $dir trim.tcl]]
package ifneeded textutil::tabify   0.8   [list source [file join $dir tabify.tcl]]
package ifneeded textutil::repeat   0.8   [list source [file join $dir repeat.tcl]]
package ifneeded textutil::string   0.9   [list source [file join $dir string.tcl]]
package ifneeded textutil::expander 1.3.2 [list source [file join $dir expander.tcl]]
package ifneeded textutil::patch    0.2   [list source [file join $dir patch.tcl]]
package ifneeded textutil::wcswidth 35.3  [list source [file join $dir wcswidth.tcl]]
