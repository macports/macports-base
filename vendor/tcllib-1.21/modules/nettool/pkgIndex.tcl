
if {![package vsatisfies [package provide Tcl] 8.5]} {return}
# Backward compatible alias
package ifneeded nettool::available_ports 0.1 {package require nettool ; package provide nettool::available_ports 0.1}
package ifneeded nettool 0.5.2 [list source [file join $dir nettool.tcl]]

