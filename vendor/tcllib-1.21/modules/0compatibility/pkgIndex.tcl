# Compatibility wrapper for deprecated packages.
##
# Stages
# [D1] Next Release   - Noted deprecated, with redirection wrappers
# [D2] Release After  - Wrappers become Blockers, throwing error noting redirection
# [D3] Release Beyond - All removed.
##
# Currently in deprecation
# - D1 doctools::path	(doctools2base)
# - D1 doctools::config	(doctools2base)
# - D1 configuration	(pt)
# - D1 paths		(pt)
#
# :Attention:
# - Original    `doctools::paths`     Tcl 8.4 required
#   Replacement `fileutilutil::paths` Tcl 8.5 required!

if {![package vsatisfies [package provide Tcl] 8.4]} {return}

package ifneeded configuration    1   [list source [file join $dir p_config.tcl]]
package ifneeded doctools::config 0.1 [list source [file join $dir d_config.tcl]]
package ifneeded doctools::paths  0.1 [list source [file join $dir d_paths.tcl]]
package ifneeded paths            1   [list source [file join $dir p_paths.tcl]]

if {![package vsatisfies [package provide Tcl] 8.5]} {return}


if {![package vsatisfies [package provide Tcl] 8.6]} {return}

