package require Tcl 8.6 ;# try in pipeline.tcl. Possibly other things.
package require dicttool
package require TclOO
package require sha1
#package require cron 2.0
package require oo::meta 0.5.1
package require oo::dialect

::oo::dialect::create ::tool
::namespace eval ::tool {}
set ::tool::trace 0

proc ::tool::script_path {} {
  set path [file dirname [file join [pwd] [info script]]]
  return $path
}

proc ::tool::module {cmd args} {
  ::variable moduleStack
  ::variable module

  switch $cmd {
    push {
      set module [lindex $args 0]
      lappend moduleStack $module
      return $module
    }
    pop {
      set priormodule      [lindex $moduleStack end]
      set moduleStack [lrange $moduleStack 0 end-1]
      set module [lindex $moduleStack end]
      return $priormodule
    }
    peek {
      set module      [lindex $moduleStack end]
      return $module
    }
    default {
      error "Invalid command \"$cmd\". Valid: peek, pop, push"
    }
  }
}
::tool::module push core

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
    if {![file exists [file join $path $file]]} {
      puts "WARNING [file join $path $file] does not exist in [info script]"
    } else {
      uplevel #0 [list source [file join $path $file]]
    }
    lappend loaded $file
  }
  foreach file [lsort -dictionary [glob -nocomplain [file join $path *.tcl]]] {
    if {[file tail $file] in $loaded} continue
    uplevel #0 [list source $file]
    lappend loaded [file tail $file]
  }
}
