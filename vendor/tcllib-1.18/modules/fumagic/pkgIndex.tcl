if {![package vsatisfies [package provide Tcl] 8.4]} {return}

# Recognizers
package ifneeded fileutil::magic::filetype 1.0.2 [list source [file join $dir filetypes.tcl]]
package ifneeded fileutil::magic::mimetype 1.0.2 [list source [file join $dir mimetypes.tcl]]

# Runtime
package ifneeded fileutil::magic::rt 1.0 [list source [file join $dir rtcore.tcl]]

# Compiler packages
package ifneeded fileutil::magic::cgen   1.0 [list source [file join $dir cgen.tcl]]
package ifneeded fileutil::magic::cfront 1.0 [list source [file join $dir cfront.tcl]]



