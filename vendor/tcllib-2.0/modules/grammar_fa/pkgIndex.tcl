if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}

package ifneeded grammar::fa            0.6   [list source [file join $dir fa.tcl]]
package ifneeded grammar::fa::op        0.4.2 [list source [file join $dir faop.tcl]]
package ifneeded grammar::fa::dacceptor 0.1.2 [list source [file join $dir dacceptor.tcl]]
package ifneeded grammar::fa::dexec     0.3   [list source [file join $dir dexec.tcl]]
