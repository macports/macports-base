if {![package vsatisfies [package provide Tcl] 8.2]} {
    return
}
package ifneeded bench            0.4 [list source [file join $dir bench.tcl]]
package ifneeded bench::out::text 0.1.2 [list source [file join $dir bench_wtext.tcl]]
package ifneeded bench::out::csv  0.1.2 [list source [file join $dir bench_wcsv.tcl]]
package ifneeded bench::in        0.1   [list source [file join $dir bench_read.tcl]]
