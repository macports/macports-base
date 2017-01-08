if {[package vsatisfies [package provide Tcl] 8.5]} {
    package ifneeded snit 2.3.2 \
        [list source [file join $dir snit2.tcl]]
}

package ifneeded snit 1.4.2 [list source [file join $dir snit.tcl]]
