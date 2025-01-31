#checker -scope global exclude warnUndefinedVar
# var in question is 'dir'.
if {![package vsatisfies [package provide Tcl] 8.6 9]} {
    # PRAGMA: returnok
    return
}
package ifneeded oo::meta   0.7.2 [list source [file join $dir oometa.tcl]]
package ifneeded oo::option 0.3.2 [list source [file join $dir oooption.tcl]]
