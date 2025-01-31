if {![package vsatisfies [package provide Tcl] 8.6 9]} return
package ifneeded coroutine       1.4   [
    list source [file join $dir coroutine.tcl]]
package ifneeded coroutine::auto 1.3 [
    list source [file join $dir coro_auto.tcl]]
