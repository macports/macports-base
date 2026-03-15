
if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}

package ifneeded yaml         0.4.2 [list source [file join $dir yaml.tcl]]
package ifneeded huddle       0.5   [list source [file join $dir huddle.tcl]]
package ifneeded huddle::json 0.2   [list source [file join $dir json2huddle.tcl]]
