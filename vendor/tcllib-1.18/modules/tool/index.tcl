package require Tcl 8.6 ;# try in pipeline.tcl. Possibly other things.
package require dicttool
package require TclOO
package require sha1
package require oo::meta 0.4.1
package require oo::dialect

::oo::dialect::create ::tool
::namespace eval ::tool {}
set ::tool::trace 0
###
# topic: 27196ce57a9fd09198a0b277aabdb0a96b432cb9
###
proc ::tool::pathload {path {order {}} {skip {}}} {
  ###
  # On windows while running under a VFS, the system sometimes
  # gets confused about the volume we are running under
  ###
  if {$::tcl_platform(platform) eq "windows"} {
    if {[string range $path 1 6] eq ":/zvfs"} {
      set path [string range $path 2 end]
    }
  }
  set loaded {pkgIndex.tcl index.tcl}
  foreach item $skip {
    lappend loaded [file tail $skip]
  }
  if {[file exists [file join $path metaclass.tcl]]} {
    lappend loaded metaclass.tcl
    uplevel #0 [list source [file join $path metaclass.tcl]]
  }
  if {[file exists [file join $path baseclass.tcl]]} {
    lappend loaded baseclass.tcl
    uplevel #0 [list source [file join $path baseclass.tcl]]
  }
  foreach file $order {
    set file [file tail $file]
    if {$file in $loaded} continue
    uplevel #0 [list source [file join $path $file]]
    lappend loaded $file
  }
  foreach file [lsort -dictionary [glob -nocomplain [file join $path *.tcl]]] {
    if {[file tail $file] in $loaded} continue
    uplevel #0 [list source $file]
    lappend loaded [file tail $file]
  }
}

set idxfile [file join [pwd] [info script]]
set cwd [file dirname $idxfile]
set ::tool::tool_root [file dirname $cwd]
::tool::pathload $cwd {
  uuid.tcl
  ensemble.tcl
  metaclass.tcl
  event.tcl
} $idxfile
package provide tool 0.5

