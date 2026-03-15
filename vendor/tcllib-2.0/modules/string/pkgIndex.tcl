if {![package vsatisfies [package provide Tcl] 8.5 9]} {
    # FRINK: nocheck
    return
}
package ifneeded string::token        1.1   [list source [file join $dir token.tcl]]
package ifneeded string::token::shell 1.3 [list source [file join $dir token_shell.tcl]]
