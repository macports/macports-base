if {[package vsatisfies [package provide Tcl] 8.5 9]} {
    package ifneeded snit 2.3.4 \
        [list source [file join $dir snit2.tcl]]
}

package ifneeded snit 1.4.3 [list source [file join $dir snit.tcl]]
