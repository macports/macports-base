###
# Practcl
# An object oriented templating system for stamping out Tcl API calls to C
###

package require TclOO
###
# Seek out Tcllib if it's available
###
set tcllib_path {}
foreach path {.. ../.. ../../..} {
  foreach path [glob -nocomplain [file join [file normalize $path] tcllib* modules]] {
    set tclib_path $path
    lappend ::auto_path $path
    break
  }
  if {$tcllib_path ne {}} break
}
namespace eval ::practcl {}
namespace eval ::practcl::OBJECT {}
