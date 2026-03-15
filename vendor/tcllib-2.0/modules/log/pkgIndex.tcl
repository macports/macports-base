if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
package ifneeded log 1.5 [list source [file join $dir log.tcl]]
package ifneeded logger           0.9.5 [list source [file join $dir logger.tcl]]
package ifneeded logger::appender 1.4   [list source [file join $dir loggerAppender.tcl]]
package ifneeded logger::utils    1.3.2 [list source [file join $dir loggerUtils.tcl]]
