namespace eval ::clay {}
set ::clay::trace 0

if {[info commands ::cron::object_destroy] eq {}} {
  # Provide a noop if we aren't running with the cron scheduler
  namespace eval ::cron {}
  proc ::cron::object_destroy args {}
}

###
# Because many features in this package may be added as
# commands to future tcl cores, or be provided in binary
# form by packages, I need a declaritive way of saying
# [emph {Create this command if there isn't one already}].
# The [emph ninja] argument is a script to execute if the
# command is created by this mechanism.
###
proc ::clay::PROC {name arglist body {ninja {}}} {
  if {[info commands $name] ne {}} return
  proc $name $arglist $body
  eval $ninja
}
if {[info commands ::PROC] eq {}} {
  namespace eval ::clay { namespace export PROC }
  namespace eval :: { namespace import ::clay::PROC }
}

proc ::clay::_ancestors {resultvar class} {
  upvar 1 $resultvar result
  if {$class in $result} {
    return
  }
  lappend result $class
  foreach aclass [::info class superclasses $class] {
    _ancestors result $aclass
  }
}

proc ::clay::ancestors {args} {
  set result {}
  set queue  {}
  set metaclasses {}

  foreach class $args {
    set ancestors($class) {}
    _ancestors ancestors($class) $class
  }
  foreach class [lreverse $args] {
    foreach aclass $ancestors($class) {
      if {$aclass in $result} continue
      set skip 0
      foreach bclass $args {
        if {$class eq $bclass} continue
        if {$aclass in $ancestors($bclass)} {
          set skip 1
          break
        }
      }
      if {$skip} continue
      lappend result $aclass
    }
  }
  foreach class [lreverse $args] {
    foreach aclass $ancestors($class) {
      if {$aclass in $result} continue
      lappend result $aclass
    }
  }
  ###
  # Screen out classes that do not participate in clay
  # interactions
  ###
  set output {}
  foreach {item} $result {
    if {[catch {$item clay noop} err]} {
      continue
    }
    lappend output $item
  }
  return $output
}

proc ::clay::args_to_dict args {
  if {[llength $args]==1} {
    return [lindex $args 0]
  }
  return $args
}

proc ::clay::args_to_options args {
  set result {}
  foreach {var val} [args_to_dict {*}$args] {
    lappend result [string trim $var -:] $val
  }
  return $result
}

###
# topic: 4969d897a83d91a230a17f166dbcaede
###
proc ::clay::dynamic_arguments {ensemble method arglist args} {
  set idx 0
  set len [llength $args]
  if {$len > [llength $arglist]} {
    ###
    # Catch if the user supplies too many arguments
    ###
    set dargs 0
    if {[lindex $arglist end] ni {args dictargs}} {
      return -code error -level 2 "Usage: $ensemble $method [string trim [dynamic_wrongargs_message $arglist]]"
    }
  }
  foreach argdef $arglist {
    if {$argdef eq "args"} {
      ###
      # Perform args processing in the style of tcl
      ###
      uplevel 1 [list set args [lrange $args $idx end]]
      break
    }
    if {$argdef eq "dictargs"} {
      ###
      # Perform args processing in the style of tcl
      ###
      uplevel 1 [list set args [lrange $args $idx end]]
      ###
      # Perform args processing in the style of clay
      ###
      set dictargs [::clay::args_to_options {*}[lrange $args $idx end]]
      uplevel 1 [list set dictargs $dictargs]
      break
    }
    if {$idx > $len} {
      ###
      # Catch if the user supplies too few arguments
      ###
      if {[llength $argdef]==1} {
        return -code error -level 2 "Usage: $ensemble $method [string trim [dynamic_wrongargs_message $arglist]]"
      } else {
        uplevel 1 [list set [lindex $argdef 0] [lindex $argdef 1]]
      }
    } else {
      uplevel 1 [list set [lindex $argdef 0] [lindex $args $idx]]
    }
    incr idx
  }
}

###
# topic: 53ab28ac5c6ee601fe1fe07b073be88e
###
proc ::clay::dynamic_wrongargs_message {arglist} {
  set result ""
  set dargs 0
  foreach argdef $arglist {
    if {$argdef in {args dictargs}} {
      set dargs 1
      break
    }
    if {[llength $argdef]==1} {
      append result " $argdef"
    } else {
      append result " ?[lindex $argdef 0]?"
    }
  }
  if { $dargs } {
    append result " ?option value?..."
  }
  return $result
}

proc ::clay::is_dict { d } {
  # is it a dict, or can it be treated like one?
  if {[catch {::dict size $d} err]} {
    #::set ::errorInfo {}
    return 0
  }
  return 1
}

proc ::clay::is_null value {
  return [expr {$value in {{} NULL}}]
}

proc ::clay::leaf args {
  set marker [string index [lindex $args end] end]
  set result [path {*}${args}]
  if {$marker eq "/"} {
    return $result
  }
  return [list {*}[lrange $result 0 end-1] [string trim [string trim [lindex $result end]] /]]
}

proc ::clay::K {a b} {set a}
if {[info commands ::K] eq {}} {
  namespace eval ::clay { namespace export K }
  namespace eval :: { namespace import ::clay::K }
}

###
# Perform a noop. Useful in prototyping for commenting out blocks
# of code without actually having to comment them out. It also makes
# a handy default for method delegation if a delegate has not been
# assigned yet.
proc ::clay::noop args {}
if {[info commands ::noop] eq {}} {
  namespace eval ::clay { namespace export noop }
  namespace eval :: { namespace import ::clay::noop }
}


###
# Process the queue of objects to be destroyed
###
proc ::clay::cleanup {} {
  set count 0
  if {![info exists ::clay::idle_destroy]} return
  set objlist $::clay::idle_destroy
  set ::clay::idle_destroy {}
  foreach obj $objlist {
    if {![catch {$obj destroy}]} {
      incr count
    }
  }
  return $count
}

proc ::clay::object_create {objname {class {}}} {
  #if {$::clay::trace>0} {
  #  puts [list $objname CREATE]
  #}
}

proc ::clay::object_rename {object newname} {
  if {$::clay::trace>0} {
    puts [list $object RENAME -> $newname]
  }
}

###
# Mark an objects for destruction on the next cleanup
###
proc ::clay::object_destroy args {
  if {![info exists ::clay::idle_destroy]} {
    set ::clay::idle_destroy {}
  }
  foreach objname $args {
    if {$::clay::trace>0} {
      puts [list $objname DESTROY]
    }
    ::cron::object_destroy $objname
    if {$objname in $::clay::idle_destroy} continue
    lappend ::clay::idle_destroy $objname
  }
}


proc ::clay::path args {
  set result {}
  foreach item $args {
    set item [string trim $item :./]
    foreach subitem [split $item /] {
      lappend result [string trim ${subitem}]/
    }
  }
  return $result
}

###
# Append a line of text to a variable. Optionally apply a string mapping.
# arglist:
#   map {mandatory 0 positional 1}
#   text {mandatory 1 positional 1}
###
proc ::clay::putb {buffername args} {
  upvar 1 $buffername buffer
  switch [llength $args] {
    1 {
      append buffer [lindex $args 0] \n
    }
    2 {
      append buffer [string map {*}$args] \n
    }
    default {
      error "usage: putb buffername ?map? string"
    }
  }
}
if {[info command ::putb] eq {}} {
  namespace eval ::clay { namespace export putb }
  namespace eval :: { namespace import ::clay::putb }
}

proc ::clay::script_path {} {
  set path [file dirname [file join [pwd] [info script]]]
  return $path
}

proc ::clay::NSNormalize qualname {
  if {![string match ::* $qualname]} {
    set qualname ::clay::classes::$qualname
  }
  regsub -all {::+} $qualname "::"
}

proc ::clay::uuid_generate args {
  return [uuid generate]
}

namespace eval ::clay {
  variable option_class {}
  variable core_classes {::oo::class ::oo::object}
}
