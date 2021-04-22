if {![package vsatisfies [package provide Tcl] 8.5]} {
    # FRINK: nocheck
    return
}
package ifneeded string::token        1   [list source [file join $dir token.tcl]]
package ifneeded string::token::shell 1.2 [list source [file join $dir token_shell.tcl]]
