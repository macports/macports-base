if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}

package ifneeded grammar::aycock 1.1 \
    [list source [file join $dir aycock-build.tcl]]
package ifneeded grammar::aycock::debug 1.1 \
    [list source [file join $dir aycock-debug.tcl]]
package ifneeded grammar::aycock::runtime 1.1 \
    [list source [file join $dir aycock-runtime.tcl]]
