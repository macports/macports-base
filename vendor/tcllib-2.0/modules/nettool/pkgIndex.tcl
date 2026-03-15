
if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}
# Backward compatible alias
package ifneeded nettool::available_ports 0.2 {package require nettool ; package provide nettool::available_ports 0.2}
package ifneeded nettool 0.5.4 [list source [file join $dir nexttool.tcl]]

