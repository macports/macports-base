###
# topic: 65dfea29d424543cdfc0e1cbf9f90295ef6214cb
# description:
#    This script digests the raw data from
#    http://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.csv
#    And produces a summary
###
proc ::record {service port type usage} {
  if { $port eq {} } return
  if {$service eq {} && $type in {tcp udp {}} && $usage != "Reserved"} {
    ladd ::available_port($port) {*}$type
    return
  }
  unset -nocomplain ::available_port($port)
  lappend ::busy_port($port) $type $usage
  #puts [list busy $service $port $type $usage]
}

for {set x 0} {$x < 65536} {incr x} {
  set ::available_port($x) {}
}
package require dicttool
package require csv
set fin [open [lindex $argv 0] r]
set headers [gets $fin]
set thisline {}
while {[gets $fin line]>=0} {
  append thisline \n$line
  if {![csv::iscomplete $line]} continue
  set lline [csv::split $line]
  if [catch {
  set service [lindex $lline 0]
  set port [lindex $lline 1]
  set type [lindex $lline 2]
  set usage [lindex $lline 3]

  }] continue
  if {![string is integer -strict $port]} {
    set startport [lindex [split $port -] 0]
    set endport [lindex [split $port -] 1]
    if {[string is integer -strict $startport] && [string is integer -strict $endport]} {
      for {set i $startport} {$i<=$endport}  {incr i}  {
        record $service $i $type $usage
      }
      continue
    }
    
  }
  
  record $service $port $type $usage
}
close $fin

set fout [open available_ports.tcl w]
puts $fout {
package provide nettool::available_ports 0.1
namespace eval ::nettool {
  set blocks {}
}
}
set startport 0
set endport 0
foreach {port avail} [lsort -integer -stride 2 [array get available_port]] {
  # Don't bother with ports below 1024
  # Most operating systems won't let us access them anyway
  if {$port < 1024 } continue
  if { $endport == ($port-1) } {
    set endport $port
    continue
  }
  if {$startport} {
    puts $fout [list lappend ::nettool::blocks $startport $endport]
  }
  set startport $port
  set endport $port
}
if { $startport } {
  puts $fout [list lappend ::nettool::blocks $startport $endport]
}
close $fout

exit

