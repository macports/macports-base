[example {
package require Tcl 8.5
package require fileutil
package require pt::pgen

lassign $argv name
set grammar [fileutil::cat $name.peg]
set pclass  [pt::pgen peg $gr snit -class $name -file  $name.peg -name  $name]
fileutil::writeFile $name.tcl $pclass
exit 0
}]
