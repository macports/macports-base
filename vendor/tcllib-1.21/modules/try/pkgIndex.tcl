#checker -scope global exclude warnUndefinedVar
# var in question is 'dir'.
if {![package vsatisfies [package provide Tcl] 8.5]} {
    # PRAGMA: returnok
    return
}
# The package below is a backward compatible implementation of
# try/catch/finally, for use by Tcl 8.5 only. On 8.6 it does nothing.
package ifneeded try   1 [list source [file join $dir try.tcl]]

# The package below is a backward compatible implementation of
# "throw", for use by Tcl 8.5 only. On 8.6 it does nothing.
package ifneeded throw 1 [list source [file join $dir throw.tcl]]
