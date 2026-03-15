if {![package vsatisfies [package provide Tcl] 8.5 9]} {
    return
}
package ifneeded bench            0.6   [list source [file join $dir bench.tcl]]
package ifneeded bench::out::text 0.1.3 [list source [file join $dir bench_wtext.tcl]]
package ifneeded bench::out::csv  0.1.3 [list source [file join $dir bench_wcsv.tcl]]
package ifneeded bench::in        0.2   [list source [file join $dir bench_read.tcl]]
