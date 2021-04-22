
if {![package vsatisfies [package provide Tcl] 8.5]} {return}

package ifneeded yaml         0.4.1 [list source [file join $dir yaml.tcl]]
package ifneeded huddle       0.4   [list source [file join $dir huddle.tcl]]
package ifneeded huddle::json 0.1   [list source [file join $dir json2huddle.tcl]]
