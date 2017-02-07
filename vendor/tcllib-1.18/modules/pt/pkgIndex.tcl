if {![package vsatisfies [package provide Tcl] 8.5]} return

# General utilities.
package ifneeded char          1.0.1 [list source [file join $dir char.tcl]]
package ifneeded configuration 1 [list source [file join $dir configuration.tcl]]
package ifneeded paths         1 [list source [file join $dir paths.tcl]]
package ifneeded text::write   1 [list source [file join $dir text_write.tcl]]

# AST support
package ifneeded pt::ast     1.1 [list source [file join $dir pt_astree.tcl]]

# General parser support. Currently only conversion of structured
# syntax errors (or parts thereof) into a human-readable form.
package ifneeded pt::util    1.1 [list source [file join $dir pt_util.tcl]]

# Parsing Expression support
package ifneeded pt::pe        1.0.2 [list source [file join $dir pt_pexpression.tcl]]
package ifneeded pt::pe::op    1.0.1 [list source [file join $dir pt_pexpr_op.tcl]]

# Parsing Expression Grammar support.
package ifneeded pt::peg                1 [list source [file join $dir pt_pegrammar.tcl]]
package ifneeded pt::peg::container     1 [list source [file join $dir pt_peg_container.tcl]]
package ifneeded pt::peg::interp    1.0.1 [list source [file join $dir pt_peg_interp.tcl]]
package ifneeded pt::peg::op        1.0.1 [list source [file join $dir pt_peg_op.tcl]]
package ifneeded pt::parse::peg     1.0.1 [list source [file join $dir pt_parse_peg.tcl]]


# Export/import managers. Assumes an untrusted environment.
package ifneeded pt::peg::export            1 [list source [file join $dir pt_peg_export.tcl]]
package ifneeded pt::peg::import            1 [list source [file join $dir pt_peg_import.tcl]]

# Export plugins, connecting manager to the core conversion packages.
package ifneeded pt::peg::export::container 1 [list source [file join $dir pt_peg_export_container.tcl]]
package ifneeded pt::peg::export::json      1 [list source [file join $dir pt_peg_export_json.tcl]]
package ifneeded pt::peg::export::peg       1 [list source [file join $dir pt_peg_export_peg.tcl]]

# Import plugins, connecting manager to the core conversion packages.
package ifneeded pt::peg::import::json      1 [list source [file join $dir pt_peg_import_json.tcl]]
package ifneeded pt::peg::import::peg       1 [list source [file join $dir pt_peg_import_peg.tcl]]

# Export core functionality: Conversion from PEG to a specific format.
package ifneeded pt::peg::to::container     1 [list source [file join $dir pt_peg_to_container.tcl]]
package ifneeded pt::peg::to::cparam    1.1.3 [list source [file join $dir pt_peg_to_cparam.tcl]]
package ifneeded pt::peg::to::json          1 [list source [file join $dir pt_peg_to_json.tcl]]
package ifneeded pt::peg::to::param     1.0.1 [list source [file join $dir pt_peg_to_param.tcl]]
package ifneeded pt::peg::to::peg       1.0.2 [list source [file join $dir pt_peg_to_peg.tcl]]
package ifneeded pt::peg::to::tclparam  1.0.3 [list source [file join $dir pt_peg_to_tclparam.tcl]]

# Import core functionality: Conversion from a specific format to PEG.
package ifneeded pt::peg::from::json      1 [list source [file join $dir pt_peg_from_json.tcl]]
package ifneeded pt::peg::from::peg   1.0.3 [list source [file join $dir pt_peg_from_peg.tcl]]

# PARAM runtime.
package ifneeded pt::rde      1.1 [list source [file join $dir pt_rdengine.tcl]]
package ifneeded pt::rde::oo  1.1 [list source [file join $dir pt_rdengine_oo.tcl]]

# PEG grammar specification, as CONTAINER
package ifneeded pt::peg::container::peg 1 [list source [file join $dir pt_peg_container_peg.tcl]]

# */PARAM support (canned configurations).
package ifneeded pt::cparam::configuration::critcl  1.0.2 [list source [file join $dir pt_cparam_config_critcl.tcl]]
package ifneeded pt::cparam::configuration::tea     0.1   [list source [file join $dir pt_cparam_config_tea.tcl]]
package ifneeded pt::tclparam::configuration::snit  1.0.2 [list source [file join $dir pt_tclparam_config_snit.tcl]]
package ifneeded pt::tclparam::configuration::tcloo 1.0.4 [list source [file join $dir pt_tclparam_config_tcloo.tcl]]

# Parser generator core.
package ifneeded pt::pgen 1.0.3 [list source [file join $dir pt_pgen.tcl]]
