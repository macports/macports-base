if {![package vsatisfies [package provide Tcl] 8.4]} {return}

package ifneeded grammar::me::util      0.1 [list source [file join $dir me_util.tcl]]
package ifneeded grammar::me::tcl       0.1 [list source [file join $dir me_tcl.tcl]]
package ifneeded grammar::me::cpu       0.2 [list source [file join $dir me_cpu.tcl]]
package ifneeded grammar::me::cpu::core 0.2 [list source [file join $dir me_cpucore.tcl]]
package ifneeded grammar::me::cpu::gasm 0.1 [list source [file join $dir gasm.tcl]]
