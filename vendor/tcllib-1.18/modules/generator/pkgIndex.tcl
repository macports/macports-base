# Requires Tcl 8.6 and higher, to have the coroutines underlying generators.
if {![package vsatisfies [package provide Tcl] 8.6]} return
package ifneeded generator 0.1 [list source [file join $dir generator.tcl]]
