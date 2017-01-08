if {![package vsatisfies [package provide Tcl] 8.6]} {return}
package ifneeded coroutine       1.1.3 [list source [file join $dir coroutine.tcl]]
package ifneeded coroutine::auto 1.1.3 [list source [file join $dir coro_auto.tcl]]
