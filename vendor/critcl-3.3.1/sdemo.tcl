set dir [file dirname [file normalize [info script]]]
source pkgIndex.tcl

package require stubs::container
package require stubs::gen
package require stubs::gen::decl
package require stubs::gen::header
package require stubs::gen::init
package require stubs::gen::macro
package require stubs::gen::slot
package require stubs::gen::stubs
package require stubs::reader

stubs::container::new C
stubs::reader::file   C [lindex $argv 0]

interp alias {} CI {} stubs::container::interfaces C
#interp alias {} G {} stubs::gen::decl
#interp alias {} G {} stubs::gen::init
#interp alias {} G {} stubs::gen::macro
#interp alias {} G {} stubs::gen::slot
#interp alias {} G {} stubs::gen::header
interp alias {} G {} stubs::gen::stubs

puts [G::gen C]
foreach i [CI] { puts [G::gen C $i] }
exit
