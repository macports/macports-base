set srcdir [file dirname [file normalize [file join [pwd] [info script]]]]
set moddir [file dirname $srcdir]

set version 0.5.2
set tclversion 8.5
set module [file tail $moddir]

proc ::ladd {varname args} {
  upvar 1 $varname var
  if ![info exists var] {
      set var {}
  }
  foreach item $args {
    if {$item in $var} continue
    lappend var $item
  }
  return $var
}

dict set map %module% $module
dict set map %version% $version
dict set map %tclversion% $tclversion
dict set map {    } {}
dict set map "\t" {    }

###
# Rebuild the available ports file
###
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
set fin [open [file join $srcdir service-names-port-numbers.csv] r]
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

set fout [open [file join $moddir available_ports.tcl] w]
puts $fout {
namespace eval ::nettool {
  set blocks {}
}
}
set startport 0
set endport 0

foreach port [lsort -integer [array names  available_port]] {
  set avail $available_port($port)
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

set fout [open [file join $moddir [file tail $module].tcl] w]
puts $fout [string map $map {###
    # Amalgamated package for %module%
    # Do not edit directly, tweak the source in src/ and rerun
    # build.tcl
    ###
    package require Tcl %tclversion%
    package provide %module% %version%
    namespace eval ::%module% {}
    set ::%module%::version %version%
}]

# Track what files we have included so far
set loaded {}
lappend loaded build.tcl
# These files must be loaded in a particular order
foreach file {
  core.tcl
  generic.tcl
  available_ports.tcl
  locateport.tcl
  platform_unix.tcl
  platform_unix_linux.tcl
  platform_unix_macosx.tcl
  platform_windows.tcl
  platform_windows_twapi.tcl
} {
  lappend loaded $file
  set fin [open [file join $srcdir $file] r]
  puts $fout "###\n# START: [file tail $file]\n###"
  puts $fout [read $fin]
  close $fin
  puts $fout "###\n# END: [file tail $file]\n###"
}

# These files can be loaded in any order
foreach file [glob [file join $srcdir *.tcl]] {
  if {[file tail $file] in $loaded} continue
  lappend loaded $file
  set fin [open [file join $srcdir $file] r]
  puts $fout "###\n# START: [file tail $file]\n###"
  puts $fout [read $fin]
  close $fin
  puts $fout "###\n# END: [file tail $file]\n###"
}

# Provide some cleanup and our final package provide
puts $fout [string map $map {
    namespace eval ::%module% {
	namespace export *
    }
    ###
    # Perform any one-time discovery we might need
    ###
    ::nettool::discover
    ::nettool::init
}]
close $fout

###
# Build our pkgIndex.tcl file
###
set fout [open [file join $moddir pkgIndex.tcl] w]
puts $fout [string map $map {
    if {![package vsatisfies [package provide Tcl] %tclversion%]} {return}
    # Backward compatible alias
    package ifneeded nettool::available_ports 0.1 {package require %module% ; package provide nettool::available_ports 0.1}
    package ifneeded %module% %version% [list source [file join $dir %module%.tcl]]
}]
close $fout
