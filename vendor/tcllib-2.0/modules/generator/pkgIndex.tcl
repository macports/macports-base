# Requires Tcl 8.6 and higher, to have the coroutines underlying generators.
if {![package vsatisfies [package provide Tcl] 8.6 9]} return
package ifneeded generator 0.3 [list source [file join $dir generator.tcl]]
