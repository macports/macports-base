if { ![package vsatisfies [package provide Tcl] 8.2] } { return }
package ifneeded inifile 0.3 [list source [file join $dir ini.tcl]]
