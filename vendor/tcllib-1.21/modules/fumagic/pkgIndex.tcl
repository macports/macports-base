if {![package vsatisfies [package provide Tcl] 8.6]} {return}

# Recognizers
package ifneeded fileutil::magic::filetype 2.0.1 [list source [file join $dir filetypes.tcl]]

# Runtime
package ifneeded fileutil::magic::rt 3.0 [list source [file join $dir rtcore.tcl]]

# Compiler packages
package ifneeded fileutil::magic::cgen   1.3.0 [list source [file join $dir cgen.tcl]]
package ifneeded fileutil::magic::cfront 1.3.0 [list source [file join $dir cfront.tcl]]



