# probopt.tcl --
#     Define the right workspace and load the three source files
#     comprising the package for probabilistic optimisation:
#
#     1. Minimisation via Particle Swarm Optimisation
#     2. Minimisation via Shuffled Complex Evolution
#     3. Maximisation via Lipschitz Optimisation
#
package require Tcl 8.5
package provide math::probopt 1.0

namespace eval ::math::probopt {}

set dir [file dirname [info script]]

source [file join [file dirname [info script]] probopt_pso.tcl]
source [file join [file dirname [info script]] probopt_sce.tcl]
source [file join [file dirname [info script]] probopt_lipo.tcl]
source [file join [file dirname [info script]] probopt_diffev.tcl]
