#checker -scope global exclude warnUndefinedVar
# var in question is 'dir'.
if {![package vsatisfies [package provide Tcl] 8.5]} {
    # PRAGMA: returnok
    return
}
# Utility wrapper around ::apply for easier writing.
package ifneeded lambda 1 [list source [file join $dir lambda.tcl]]
