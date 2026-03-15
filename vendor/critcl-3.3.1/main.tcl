if {![catch {
  # Kit related main:
  package require starkit
}]} {
  if {[starkit::startup] == "sourced"} return
} else {
  # Direct invoke without kit (sourced/debug/dev-edition), assume
  # relative location of the required packages:
  lappend ::auto_path [file join [file dirname [info script]] lib]
}
package require critcl::app 3
#puts [package ifneeded critcl [package require critcl::app 3]]
critcl::app::main $argv
