#-------------------------------------------------------------------------
# TITLE: 
#    tool.tcl
#
# PROJECT:
#    tool: TclOO Helper Library
#
# DESCRIPTION:
#    tool(n): Implementation File
#
#-------------------------------------------------------------------------

namespace eval ::tool {}

###
# New OO Keywords for TOOL
###
namespace eval ::tool::define {}
proc ::tool::define::array {name {values {}}} {
  set class [current_class]
  set name [string trimright $name :]:
  if {![::oo::meta::info $class exists array $name]} {
    ::oo::meta::info $class set array $name {}
  }
  foreach {var val} $values {
    ::oo::meta::info $class set array $name: $var $val
  }
}

###
# topic: 710a93168e4ba7a971d3dbb8a3e7bcbc
###
proc ::tool::define::component {name info} {
  set class [current_class]
  ::oo::meta::info $class branchset component $name $info
}

###
# topic: 2cfc44a49f067124fda228458f77f177
# title: Specify the constructor for a class
###
proc ::tool::define::constructor {arglist rawbody} {
  set body {
::tool::object_create [self]
# Initialize public variables and options
my InitializePublic
  }
  append body $rawbody
  append body {
# Run "initialize"
my initialize
  }
  set class [current_class]
  ::oo::define $class constructor $arglist $body
}

###
# topic: 7a5c7e04989704eef117ff3c9dd88823
# title: Specify the a method for the class object itself, instead of for objects of the class
###
proc ::tool::define::class_method {name arglist body} {
  set class [current_class]
  ::oo::meta::info $class set class_typemethod $name: [list $arglist $body]
}

###
# topic: 4cb3696bf06d1e372107795de7fe1545
# title: Specify the destructor for a class
###
proc ::tool::define::destructor rawbody {
  set body {
::tool::object_destroy [self]
  }
  append body $rawbody
  ::oo::define [current_class] destructor $body
}

###
# topic: 8bcae430f1eda4ccdb96daedeeea3bd409c6bb7a
# description: Add properties and option handling
###
proc ::tool::define::property args {
  set class [current_class]
  switch [llength $args] {
    2 {
      set type const
      set property [string trimleft [lindex $args 0] :]
      set value [lindex $args 1]
      ::oo::meta::info $class set $type $property: $value
      return
    }
    3 {
      set type     [lindex $args 0]
      set property [string trimleft [lindex $args 1] :]
      set value    [lindex $args 2]
      ::oo::meta::info $class set $type $property: $value
      return
    }
    default {
      error "Usage:
property name type valuedict
OR property name value"
    }
  }
  ::oo::meta::info $class set {*}$args
}

###
# topic: 615b7c43b863b0d8d1f9107a8d126b21
# title: Specify a variable which should be initialized in the constructor
# description:
#    This keyword can also be expressed:
#    [example {property variable NAME {default DEFAULT}}]
#    [para]
#    Variables registered in the variable property are also initialized
#    (if missing) when the object changes class via the [emph morph] method.
###
proc ::tool::define::variable {name {default {}}} {
  set class [current_class]
  set name [string trimright $name :]
  ::oo::meta::info $class set variable $name: $default
  ::oo::define $class variable $name
}

###
# Utility Procedures
###

# topic: 643efabec4303b20b66b760a1ad279bf
###
proc ::tool::args_to_dict args {
  if {[llength $args]==1} {
    return [lindex $args 0]
  }
  return $args
}

###
# topic: b40970b0d9a2525990b9105ec8c96d3d
###
proc ::tool::args_to_options args {
  set result {}
  foreach {var val} [args_to_dict {*}$args] {
    lappend result [string trimleft $var -] $val
  }
  return $result
}

###
# topic: a92cd258900010f656f4c6e7dbffae57
###
proc ::tool::dynamic_methods class {
  set metadata [::oo::meta::metadata $class]
  foreach command [info commands ::tool::dynamic_methods_*] {
    $command $class $metadata
  }
}

###
# topic: 4969d897a83d91a230a17f166dbcaede
###
proc ::tool::dynamic_arguments {arglist args} {
  set idx 0
  set len [llength $args]
  if {$len > [llength $arglist]} {
    ###
    # Catch if the user supplies too many arguments
    ###
    set dargs 0
    if {[lindex $arglist end] ni {args dictargs}} {
      set string [dynamic_wrongargs_message $arglist]
      error $string
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
      # Perform args processing in the style of tool
      ###
      set dictargs [::tool::args_to_options {*}[lrange $args $idx end]]
      uplevel 1 [list set dictargs $dictargs]
      break
    }
    if {$idx > $len} {
      ###
      # Catch if the user supplies too few arguments
      ###
      if {[llength $argdef]==1} {
        set string [dynamic_wrongargs_message $arglist]
        error $string
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
# topic: b88add196bb63abccc44639db5e5eae1
###
proc ::tool::dynamic_methods_class {thisclass metadata} {
  foreach {method info} [dict getnull $metadata class_typemethod] {
    lassign $info arglist body
    set method [string trimright $method :]
    ::oo::objdefine $thisclass method $method $arglist $body
  }
}

###
# topic: 53ab28ac5c6ee601fe1fe07b073be88e
###
proc ::tool::dynamic_wrongargs_message arglist {
  set result "Wrong # args: should be:"
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

proc ::tool::object_create objname {
  foreach varname {
    object_info
    object_subscribe
  } {
    variable $varname
    set ${varname}($objname) {}
  }
  set object_info($objname) [list class [info object class $objname]]
}

proc ::tool::object_destroy objname {
  ::tool::event::generate $objname object_destroy [list objname $objname]
  foreach varname {
    object_info
    object_subscribe
  } {
    variable $varname
    unset -nocomplain ${varname}($objname)
  }
}

#-------------------------------------------------------------------------
# Option Handling Mother of all Classes

# tool::object
#
# This class is inherited by all classes that have options.
#

::tool::define ::tool::object {
  # Put MOACish stuff in here
  variable signals_pending create
  variable organs {}
  
  constructor args {
    my config merge [::tool::args_to_options {*}$args]
  }
  
  destructor {}
    
  method ancestors {{reverse 0}} {
    set result [::oo::meta::ancestors [info object class [self]]]
    if {$reverse} {
      return [lreverse $result]
    }
    return $result
  }
  
  ###
  # title: Forward a method
  ###
  method forward {method args} {
    oo::objdefine [self] forward $method {*}$args
  }
  
  ###
  # title: Direct a series of sub-functions to a seperate object
  ###
  method graft args {
    my variable organs
    if {[llength $args] == 1} {
      error "Need two arguments"
    }
    set object {}
    foreach {stub object} $args {
      dict set organs $stub $object
      oo::objdefine [self] forward <${stub}> $object
      oo::objdefine [self] export <${stub}>
    }
    return $object
  }
  
  # Called after all options and public variables are initialized
  method initialize {} {}
  
  ###
  # topic: 3c4893b65a1c79b2549b9ee88f23c9e3
  # description:
  #    Provide a default value for all options and
  #    publically declared variables, and locks the
  #    pipeline mutex to prevent signal processing
  #    while the contructor is still running.
  #    Note, by default an odie object will ignore
  #    signals until a later call to <i>my lock remove pipeline</i>
  ###
  ###
  # topic: 3c4893b65a1c79b2549b9ee88f23c9e3
  # description:
  #    Provide a default value for all options and
  #    publically declared variables, and locks the
  #    pipeline mutex to prevent signal processing
  #    while the contructor is still running.
  #    Note, by default an odie object will ignore
  #    signals until a later call to <i>my lock remove pipeline</i>
  ###
  method InitializePublic {} {
    my variable config meta
    if {![info exists meta]} {
      set meta {}
    }
    if {![info exists config]} {
      set config {}
    }
    my ClassPublicApply {}
  }
  
  class_method info {which} {
    my variable cache
    if {![info exists cache($which)]} {
      set cache($which) {}
      switch $which {
        public {
          dict set cache(public) variable [my meta branchget variable]
          dict set cache(public) array [my meta branchget array]
          set optinfo [my meta getnull option]
          dict set cache(public) option_info $optinfo
          foreach {var info} [dict getnull $cache(public) option_info] {
            if {[dict exists $info aliases:]} {
              foreach alias [dict exists $info aliases:] {
                dict set cache(public) option_canonical $alias $var
              }
            }
            set getcmd [dict getnull $info default-command:]
            if {$getcmd ne {}} {
              dict set cache(public) option_default_command $var $getcmd
            } else {
              dict set cache(public) option_default_value $var [dict getnull $info default:]
            }
            dict set cache(public) option_canonical $var $var
          }
        }
      }
    }
    return $cache($which)
  }
  
  ###
  # Incorporate the class's variables, arrays, and options
  ###
  method ClassPublicApply class {
    my variable config
    set integrate 0
    if {$class eq {}} {
      set class [info object class [self]]      
    } else {
      set integrate 1
    }
    set public [$class info public]
    foreach {var value} [dict getnull $public variable] {
      if { $var in {meta config} } continue
      my variable $var
      if {![info exists $var]} {
        set $var $value
      }
    }
    foreach {var value} [dict getnull $public array] {
      if { $var eq {meta config} } continue
      my variable $var
      foreach {f v} $value {
        if {![array exists ${var}($f)]} {
          set ${var}($f) $v
        }
      }
    }
    set dat [dict getnull $public option_info]
    if {$integrate} {
      my meta rmerge [list option $dat]
    }
    #set field [my cget field]
    my variable option_canonical
    array set option_canonical [dict getnull $public option_canonical]
    set dictargs {}
    foreach {var getcmd} [dict getnull $public option_default_command] {
      if {[dict exists $config $var]} continue
      dict set dictargs $var [{*}[string map [list %field% $var %self% [namespace which my]] $getcmd]]
    }
    foreach {var value} [dict getnull $public option_default_value] {
      if {[dict exists $config $var]} continue
      dict set dictargs $var $value
    }
    ###
    # Apply all inputs with special rules
    ###
    foreach {field val} $dictargs {
      if {[dict exists $config $field]} continue
      set script [dict getnull $dat $field set-command:]
      dict set config $field $val
      if {$script ne {}} {
        {*}[string map [list %field% [list $field] %value% [list $val] %self% [namespace which my]] $script]
      }
    }
  }
  
  ###
  # topic: 3c4893b65a1c79b2549b9ee88f23c9e3
  # description:
  #    Provide a default value for all options and
  #    publically declared variables, and locks the
  #    pipeline mutex to prevent signal processing
  #    while the contructor is still running.
  #    Note, by default an odie object will ignore
  #    signals until a later call to <i>my lock remove pipeline</i>
  ###
  method mixin class {
    ###
    # Mix in the class
    ###
    ::oo::objdefine [self] mixin $class
    my ClassPublicApply $class
  }
  
  method morph newclass {
    if {$newclass eq {}} return
    set class [string trimleft [info object class [self]]]
    set newclass [string trimleft $newclass :]
    if {[info command ::$newclass] eq {}} {
      error "Class $newclass does not exist"
    }
    if { $class ne $newclass } {
      my Morph_leave
      oo::objdefine [self] class ::${newclass}
      my InitializePublic
      my Morph_enter
    }
  }

  ###
  # Commands to perform as this object transitions out of the present class
  ###
  method Morph_leave {} {}
  ###
  # Commands to perform as this object transitions into this class as a new class
  ###
  method Morph_enter {} {}
  
  ###
  # title: List which objects are forwarded as organs
  ###
  method organ {{stub all}} {
    my variable organs
    if {![info exists organs]} {
      return {}
    }
    if { $stub eq "all" } {
      return $organs
    }
    return [dict getnull $organs $stub]
  }

  class_method property args {
    if {[my meta exists {*}$args]} {
      return [my meta get {*}$args]
    }
    set field [string trimright [lindex $args end] :]:
    if {[my meta exists {*}[lrange $args 0 end-1] $field]} {
      return [my meta get {*}[lrange $args 0 end-1] $field]
    }
    if {[my meta exists const {*}[lrange $args 0 end-1] $field]} {
      return [my meta get const {*}[lrange $args 0 end-1] $field]
    }
    return {}
  }
  
  method property args {
    if {[my meta exists {*}$args]} {
      return [my meta get {*}$args]
    }
    set field [string trimright [lindex $args end] :]:
    if {[my meta exists {*}[lrange $args 0 end-1] $field]} {
      return [my meta get {*}[lrange $args 0 end-1] $field]
    }
    if {[my meta exists const {*}[lrange $args 0 end-1] $field]} {
      return [my meta get const {*}[lrange $args 0 end-1] $field]
    }
    return {}
  }
}


