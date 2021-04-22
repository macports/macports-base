###
# Amalgamated package for tool
# Do not edit directly, tweak the source in src/ and rerun
# build.tcl
###
package provide tool 0.7
namespace eval ::tool {}

###
# START: core.tcl
###
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

###
# END: core.tcl
###
###
# START: uuid.tcl
###
::namespace eval ::tool {}

proc ::tool::is_null value {
  return [expr {$value in {{} NULL}}]
}


proc ::tool::uuid_seed args {
  if {[llength $args]==0 || ([llength $args]==1 && [is_null [lindex $args 0]])} {
    if {[info exists ::env(USERNAME)]} {
      set user $::env(USERNAME)
    } elseif {[info exists ::env(USER)]} {
      set user $::env(USER)
    } else {
      set user $::env(user)
    }
    incr ::tool::nextuuid $::tool::globaluuid
    set ::tool::UUID_Seed [list user@[info hostname] [clock format [clock seconds]]]
  } else {
    incr ::tool::globaluuid $::tool::nextuuid
    set ::tool::nextuuid 0
    set ::tool::UUID_Seed $args
  }
}

###
# topic: 0a19b0bfb98162a8a37c1d3bbfb8bc3d
# description:
#    Because the tcllib version of uuid generate requires
#    network port access (which can be slow), here's a fast
#    and dirty rendition
###
proc ::tool::uuid_generate args {
  if {![llength $args]} {
    set block [list [incr ::tool::nextuuid] {*}$::tool::UUID_Seed]
  } else {
    set block $args
  }
  return [::sha1::sha1 -hex [join $block ""]]
}

###
# topic: ee3ec43cc2cc2c7d6cf9a4ef1c345c19
###
proc ::tool::uuid_short args {
  if {![llength $args]} {
    set block [list [incr ::tool::nextuuid] {*}$::tool::UUID_Seed]
  } else {
    set block $args
  }
  return [string range [::sha1::sha1 -hex [join $block ""]] 0 16]
}

###
# topic: b14c505537274904578340ec1bc12af1
# description:
#    Implementation the uses a compiled in ::md5 implementation
#    commonly used by embedded application developers
###
namespace eval ::tool {
  namespace export *
}
###
# Cache the bits of the UUID seed that aren't likely to change
# once the software is loaded, but which can be expensive to
# generate
###
set ::tool::nextuuid 0
set ::tool::globaluuid 0
::tool::uuid_seed

###
# END: uuid.tcl
###
###
# START: ensemble.tcl
###
::namespace eval ::tool::define {}

if {![info exists ::tool::dirty_classes]} {
  set ::tool::dirty_classes {}
}

###
# Monkey patch oometa's rebuild function to
# include a notifier to tool
###
proc ::oo::meta::rebuild args {
  foreach class $args {
    if {$class ni $::oo::meta::dirty_classes} {
      lappend ::oo::meta::dirty_classes $class
    }
    if {$class ni $::tool::dirty_classes} {
      lappend ::tool::dirty_classes $class
    }
  }
}

proc ::tool::ensemble_build_map args {
  set emap {}
  foreach thisclass $args {
    foreach {ensemble einfo} [::oo::meta::info $thisclass getnull method_ensemble] {
      foreach {submethod subinfo} $einfo {
        dict set emap $ensemble $submethod $subinfo
      }
    }
  }
  return $emap
}

proc ::tool::ensemble_methods emap {
  set result {}
  foreach {ensemble einfo} $emap {
    #set einfo [dict getnull $einfo method_ensemble $ensemble]
    set eswitch {}
    set default standard
    if {[dict exists $einfo default:]} {
      set emethodinfo [dict get $einfo default:]
      set arglist     [lindex $emethodinfo 0]
      set realbody    [lindex $emethodinfo 1]
      if {[llength $arglist]==1 && [lindex $arglist 0] in {{} args arglist}} {
        set body {}
      } else {
        set body "\n      ::tool::dynamic_arguments $ensemble \$method [list $arglist] {*}\$args"
      }
      append body "\n      " [string trim $realbody] "      \n"
      set default $body
      dict unset einfo default:
    }
    set methodlist {}
    foreach item [dict keys $einfo] {
      lappend methodlist [string trimright $item :]
    }
    set methodlist  [lsort -dictionary -unique $methodlist]
    foreach {submethod esubmethodinfo} [lsort -dictionary -stride 2 $einfo] {
      if {$submethod in {"_preamble:" "default:"}} continue
      set submethod [string trimright $submethod :]
      lassign $esubmethodinfo arglist realbody
      if {[string length [string trim $realbody]] eq {}} {
        dict set eswitch $submethod {}
      } else {
        if {[llength $arglist]==1 && [lindex $arglist 0] in {{} args arglist}} {
          set body {}
        } else {
          set body "\n      ::tool::dynamic_arguments $ensemble \$method [list $arglist] {*}\$args"
        }
        append body "\n      " [string trim $realbody] "      \n"
        dict set eswitch $submethod $body
      }
    }
    if {![dict exists $eswitch <list>]} {
      dict set eswitch <list> {return $methodlist}
    }
    if {$default=="standard"} {
      set default "error \"unknown method $ensemble \$method. Valid: \$methodlist\""
    }
    dict set eswitch default $default
    set mbody {}    
    if {[dict exists $einfo _preamble:]} {
      append mbody [lindex [dict get $einfo _preamble:] 1] \n
    }
    append mbody \n [list set methodlist $methodlist]
    append mbody \n "set code \[catch {switch -- \$method [list $eswitch]} result opts\]"
    append mbody \n {return -options $opts $result}
    append result \n [list method $ensemble {{method default} args} $mbody]    
  }
  return $result
}

###
# topic: fb8d74e9c08db81ee6f1275dad4d7d6f
###
proc ::tool::dynamic_object_ensembles {thisobject thisclass} {
  variable trace
  set ensembledict {}
  foreach dclass $::tool::dirty_classes {
    foreach {cclass cancestors} [array get ::oo::meta::cached_hierarchy] {
      if {$dclass in $cancestors} {
        unset -nocomplain ::tool::obj_ensemble_cache($cclass)
      }
    }
  }
  set ::tool::dirty_classes {}
  ###
  # Only go through the motions for classes that have a locally defined
  # ensemble method implementation
  ###
  foreach aclass [::oo::meta::ancestors $thisclass] {
    if {[info exists ::tool::obj_ensemble_cache($aclass)]} continue
    set emap [::tool::ensemble_build_map $aclass]
    set body [::tool::ensemble_methods $emap]
    oo::define $aclass $body
    # Define a property for this ensemble for introspection
    foreach {ensemble einfo} $emap {
      ::oo::meta::info $aclass set ensemble_methods $ensemble: [lsort -dictionary [dict keys $einfo]]
    }
    set ::tool::obj_ensemble_cache($aclass) 1
  }
}

###
# topic: ec9ca249b75e2667ad5bcb2f7cd8c568
# title: Define an ensemble method for this agent
###
::proc ::tool::define::method {rawmethod args} {
  set class [current_class]
  set mlist [split $rawmethod "::"]
  if {[llength $mlist]==1} {
    ###
    # Simple method, needs no parsing
    ###
    set method $rawmethod
    ::oo::define $class method $rawmethod {*}$args
    return
  }
  set ensemble [lindex $mlist 0]
  set method [join [lrange $mlist 2 end] "::"]
  switch [llength $args] {
    1 {
      ::oo::meta::info $class set method_ensemble $ensemble $method: [list dictargs [lindex $args 0]]
    }
    2 {
      ::oo::meta::info $class set method_ensemble $ensemble $method: $args
    }
    default {
      error "Usage: method NAME ARGLIST BODY"
    }
  }
}

###
# topic: 354490e9e9708425a6662239f2058401946e41a1
# description: Creates a method which exports access to an internal dict
###
proc ::tool::define::dictobj args {
  dict_ensemble {*}$args
}
proc ::tool::define::dict_ensemble {methodname varname {cases {}}} {
  set class [current_class]
  set CASES [string map [list %METHOD% $methodname %VARNAME% $varname] $cases]
  
  set methoddata [::oo::meta::info $class getnull method_ensemble $methodname]
  set initial [dict getnull $cases initialize]
  variable $varname $initial
  foreach {name body} $CASES {
    dict set methoddata $name: [list args $body]
  }
  set template [string map [list %CLASS% $class %INITIAL% $initial %METHOD% $methodname %VARNAME% $varname] {
    _preamble {} {
      my variable %VARNAME%
    }
    add args {
      set field [string trimright [lindex $args 0] :]
      set data [dict getnull $%VARNAME% $field]
      foreach item [lrange $args 1 end] {
        if {$item ni $data} {
          lappend data $item
        }
      }
      dict set %VARNAME% $field $data
    }
    remove args {
      set field [string trimright [lindex $args 0] :]
      set data [dict getnull $%VARNAME% $field]
      set result {}
      foreach item $data {
        if {$item in $args} continue
        lappend result $item
      }
      dict set %VARNAME% $field $result
    }
    initial {} {
      return [dict rmerge [my meta branchget %VARNAME%] {%INITIAL%}]
    }
    reset {} {
      set %VARNAME% [dict rmerge [my meta branchget %VARNAME%] {%INITIAL%}]
      return $%VARNAME%
    }
    dump {} {
      return $%VARNAME%
    }
    append args {
      return [dict $method %VARNAME% {*}$args]
    }
    incr args {
      return [dict $method %VARNAME% {*}$args]
    }
    lappend args {
      return [dict $method %VARNAME% {*}$args]
    }
    set args {
      return [dict $method %VARNAME% {*}$args]
    }
    unset args {
      return [dict $method %VARNAME% {*}$args]
    }
    update args {
      return [dict $method %VARNAME% {*}$args]
    }
    branchset args {
      foreach {field value} [lindex $args end] {
        dict set %VARNAME% {*}[lrange $args 0 end-1] [string trimright $field :]: $value
      }
    }
    rmerge args {
      set %VARNAME% [dict rmerge $%VARNAME% {*}$args]
      return $%VARNAME%  
    }
    merge args {
      set %VARNAME% [dict rmerge $%VARNAME% {*}$args]
      return $%VARNAME%
    }
    replace args {
      set %VARNAME% [dict rmerge $%VARNAME% {%INITIAL%} {*}$args]
    }
    default args {
      return [dict $method $%VARNAME% {*}$args]
    }
  }]
  foreach {name arglist body} $template {
    if {[dict exists $methoddata $name:]} continue
    dict set methoddata $name: [list $arglist $body]
  }
  ::oo::meta::info $class set method_ensemble $methodname $methoddata
}

proc ::tool::define::arrayobj args {
  array_ensemble {*}$args
}

###
# topic: 354490e9e9708425a6662239f2058401946e41a1
# description: Creates a method which exports access to an internal array
###
proc ::tool::define::array_ensemble {methodname varname {cases {}}} {
  set class [current_class]
  set CASES [string map [list %METHOD% $methodname %VARNAME% $varname] $cases]
  set initial [dict getnull $cases initialize]
  array $varname $initial

  set map [list %CLASS% $class %METHOD% $methodname %VARNAME% $varname %CASES% $CASES %INITIAL% $initial]

  ::oo::define $class method _${methodname}Get {field} [string map $map {
    my variable %VARNAME%
    if {[info exists %VARNAME%($field)]} {
      return $%VARNAME%($field)
    }
    return [my meta getnull %VARNAME% $field:]
  }]
  ::oo::define $class method _${methodname}Exists {field} [string map $map {
    my variable %VARNAME%
    if {[info exists %VARNAME%($field)]} {
      return 1
    }
    return [my meta exists %VARNAME% $field:]
  }]
  set methoddata [::oo::meta::info $class set array_ensemble $methodname: $varname]
  
  set methoddata [::oo::meta::info $class getnull method_ensemble $methodname]
  foreach {name body} $CASES {
    dict set methoddata $name: [list args $body]
  } 
  set template  [string map [list %CLASS% $class %INITIAL% $initial %METHOD% $methodname %VARNAME% $varname] {
    _preamble {} {
      my variable %VARNAME%
    }
    reset {} {
      ::array unset %VARNAME% *
      foreach {field value} [my meta getnull %VARNAME%] {
        set %VARNAME%([string trimright $field :]) $value
      }
      ::array set %VARNAME% {%INITIAL%}
      return [array get %VARNAME%]
    }
    ni value {
      set field [string trimright [lindex $args 0] :]
      set data [my _%METHOD%Get $field]
      return [expr {$value ni $data}]
    }
    in value {
      set field [string trimright [lindex $args 0] :]
      set data [my _%METHOD%Get $field]
      return [expr {$value in $data}]
    }
    add args {
      set field [string trimright [lindex $args 0] :]
      set data [my _%METHOD%Get $field]
      foreach item [lrange $args 1 end] {
        if {$item ni $data} {
          lappend data $item
        }
      }
      set %VARNAME%($field) $data
    }
    remove args {
      set field [string trimright [lindex $args 0] :]
      set data [my _%METHOD%Get $field]
      set result {}
      foreach item $data {
        if {$item in $args} continue
        lappend result $item
      }
      set %VARNAME%($field) $result
    }
    dump {} {
      set result {}
      foreach {var val} [my meta getnull %VARNAME%] {
        dict set result [string trimright $var :] $val
      }
      foreach {var val} [lsort -dictionary -stride 2 [array get %VARNAME%]] {
        dict set result [string trimright $var :] $val
      }
      return $result
    }
    exists args {
      set field [string trimright [lindex $args 0] :]
      set data [my _%METHOD%Exists $field]
    }
    getnull args {
      set field [string trimright [lindex $args 0] :]
      set data [my _%METHOD%Get $field]      
    }
    get field {
      set field [string trimright $field :]
      set data [my _%METHOD%Get $field]
    }
    set args {
      set field [string trimright [lindex $args 0] :]
      ::set %VARNAME%($field) {*}[lrange $args 1 end]        
    }
    append args {
      set field [string trimright [lindex $args 0] :]
      set data [my _%METHOD%Get $field]
      ::append data {*}[lrange $args 1 end]
      set %VARNAME%($field) $data
    }
    incr args {
      set field [string trimright [lindex $args 0] :]
      ::incr %VARNAME%($field) {*}[lrange $args 1 end]
    }
    lappend args {
      set field [string trimright [lindex $args 0] :]
      set data [my _%METHOD%Get $field]
      $method data {*}[lrange $args 1 end]
      set %VARNAME%($field) $data
    }
    branchset args {
      foreach {field value} [lindex $args end] {
        set %VARNAME%([string trimright $field :]) $value
      }
    }
    rmerge args {
      foreach arg $args {
        my %VARNAME% branchset $arg
      }
    }
    merge args {
      foreach arg $args {
        my %VARNAME% branchset $arg
      }
    }
    default args {
      return [array $method %VARNAME% {*}$args]
    }
  }]
  foreach {name arglist body} $template {
    if {[dict exists $methoddata $name:]} continue
    dict set methoddata $name: [list $arglist $body]
  }
  ::oo::meta::info $class set method_ensemble $methodname $methoddata
}


###
# END: ensemble.tcl
###
###
# START: metaclass.tcl
###
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
::tool::object_create [self] [info object class [self]]
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
# Run the destructor once and only once
set self [self]
my variable DestroyEvent
if {$DestroyEvent} return
set DestroyEvent 1
::tool::object_destroy $self
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
    lappend result [string trimright [string trimleft $var -] :] $val
  }
  return $result
}

###
# topic: a92cd258900010f656f4c6e7dbffae57
###
proc ::tool::dynamic_methods class {
  ::oo::meta::rebuild $class
  set metadata [::oo::meta::metadata $class]
  foreach command [info commands [namespace current]::dynamic_methods_*] {
    $command $class $metadata
  }
}

###
# topic: 4969d897a83d91a230a17f166dbcaede
###
proc ::tool::dynamic_arguments {ensemble method arglist args} {
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
proc ::tool::dynamic_wrongargs_message {arglist} {
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

proc ::tool::object_create {objname {class {}}} {
  foreach varname {
    object_info
    object_signal
    object_subscribe
  } {
    variable $varname
    set ${varname}($objname) {}
  }
  if {$class eq {}} {
    set class [info object class $objname]
  }
   set object_info($objname) [list class $class]
  if {$class ne {}} {
    $objname graft class $class
    foreach command [info commands [namespace current]::dynamic_object_*] {
      $command $objname $class
    }
  }
}


proc ::tool::object_rename {object newname} {
  foreach varname {
    object_info
    object_signal
    object_subscribe
  } {
    variable $varname
    if {[info exists ${varname}($object)]} {
      set ${varname}($newname) [set ${varname}($object)]
      unset ${varname}($object)
    }
  }
  variable coroutine_object
  foreach {coro coro_objname} [array get coroutine_object] {
    if { $object eq $coro_objname } {
      set coroutine_object($coro) $newname
    }
  }
  rename $object ::[string trimleft $newname]
  ::tool::event::generate $object object_rename [list newname $newname]
}

proc ::tool::object_destroy objname {
  ::tool::event::generate $objname object_destroy [list objname $objname]
  ::tool::event::cancel $objname *
  ::cron::object_destroy $objname
  variable coroutine_object
  foreach varname {
    object_info
    object_signal
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
  variable mixins {}
  variable mixinmap {}
  variable DestroyEvent 0

  constructor args {
    my Config_merge [::tool::args_to_options {*}$args]
  }
  
  destructor {}
    
  method ancestors {{reverse 0}} {
    set result [::oo::meta::ancestors [info object class [self]]]
    if {$reverse} {
      return [lreverse $result]
    }
    return $result
  }
  
  method DestroyEvent {} {
    my variable DestroyEvent
    return $DestroyEvent
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
      if {$stub eq "class"} {
        # Force class to always track the object's current class
        set obj [info object class [self]]
      }
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
    my variable option_canonical
    array set option_canonical [dict getnull $public option_canonical]
    set dictargs {}
    foreach {var getcmd} [dict getnull $public option_default_command] {
      if {[dict getnull $dat $var class:] eq "organ"} {
        if {[my organ $var] ne {}} continue
      }
      if {[dict exists $config $var]} continue
      dict set dictargs $var [{*}[string map [list %field% $var %self% [namespace which my]] $getcmd]]
    }
    foreach {var value} [dict getnull $public option_default_value] {
      if {[dict getnull $dat $var class:] eq "organ"} {
        if {[my organ $var] ne {}} continue
      }
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
  method mixin args {
    ###
    # Mix in the class
    ###
    my variable mixins
    set prior $mixins

    set mixins $args
    ::oo::objdefine [self] mixin {*}$args
    ###
    # Build a compsite map of all ensembles defined by the object's current
    # class as well as all of the classes being mixed in
    ###
    set emap [::tool::ensemble_build_map [::info object class [self]] {*}[lreverse $args]]
    set body [::tool::ensemble_methods $emap]
    oo::objdefine [self] $body
    foreach class $args {
      if {$class ni $prior} {
        my meta mixin $class
      }
      my ClassPublicApply $class
    }
    foreach class $prior {
      if {$class ni $mixins } { 
        my meta mixout $class
      }
    }
  }

  method mixinmap args { 
    my variable mixinmap
    set priorlist {}
    foreach {slot classes} $args {
      if {[dict exists $mixinmap $slot]} {
        lappend priorlist {*}[dict get $mixinmap $slot]  
        foreach class [dict get $mixinmap $slot] {
          if {$class ni $classes && [$class meta exists mixin unmap-script:]} {
            if {[catch [$class meta get mixin unmap-script:] err errdat]} {
              puts stderr "[self] MIXIN ERROR POPPING $class:\n[dict get $errdat -errorinfo]"
            }
          }
        }
      }
      dict set mixinmap $slot $classes
    }
    my Recompute_Mixins
    foreach {slot classes} $args {
      foreach class $classes {
        if {$class ni $priorlist && [$class meta exists mixin map-script:]} {
          if {[catch [$class meta get mixin map-script:] err errdat]} {
            puts stderr "[self] MIXIN ERROR PUSHING $class:\n[dict get $errdat -errorinfo]"
          }
        }
      }
    }
    foreach {slot classes} $mixinmap {
      foreach class $classes {
        if {[$class meta exists mixin react-script:]} {
          if {[catch [$class meta get mixin react-script:] err errdat]} {
            puts stderr "[self] MIXIN ERROR REACTING $class:\n[dict get $errdat -errorinfo]"
          }
        }
      }
    }
  }

  method debug_mixinmap {} {
    my variable mixinmap
    return $mixinmap
  }

  method Recompute_Mixins {} {
    my variable mixinmap
    set classlist {}
    foreach {item class} $mixinmap {
      if {$class ne {}} {
        lappend classlist $class
      }
    }
    my mixin {*}$classlist
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
      my variable mixins
      oo::objdefine [self] class ::${newclass}
      my graft class ::${newclass}
      # Reapply mixins
      my mixin {*}$mixins
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
}



###
# END: metaclass.tcl
###
###
# START: option.tcl
###
###
# topic: 68aa446005235a0632a10e2a441c0777
# title: Define an option for the class
###
proc ::tool::define::option {name args} {
  set class [current_class]
  set dictargs {default: {}}
  foreach {var val} [::oo::meta::args_to_dict {*}$args] {
    dict set dictargs [string trimright [string trimleft $var -] :]: $val
  }
  set name [string trimleft $name -]

  ###
  # Option Class handling
  ###
  set optclass [dict getnull $dictargs class:]
  if {$optclass ne {}} {
    foreach {f v} [::oo::meta::info $class getnull option_class $optclass] {
      if {![dict exists $dictargs $f]} {
        dict set dictargs $f $v
      }
    }
    if {$optclass eq "variable"} {
      variable $name [dict getnull $dictargs default:]
    }
  }
  ::oo::meta::info $class branchset option $name $dictargs
}

###
# topic: 827a3a331a2e212a6e301f59c1eead59
# title: Define a class of options
# description:
#    Option classes are a template of properties that other
#    options can inherit.
###
proc ::tool::define::option_class {name args} {
  set class [current_class]
  set dictargs {default {}}
  foreach {var val} [::oo::meta::args_to_dict {*}$args] {
    dict set dictargs [string trimleft $var -] $val
  }
  set name [string trimleft $name -]
  ::oo::meta::info $class branchset option_class $name $dictargs
}

::tool::define ::tool::object {
  property options_strict 0
  variable organs {}

  option_class organ {
    widget label
    set-command {my graft %field% %value%}
    get-command {my organ %field%}
  }

  option_class variable {
    widget entry
    set-command {my variable %field% ; set %field% %value%}
    get-command {my variable %field% ; set %field%}
  }
  
  dict_ensemble config config {
    get {
      return [my Config_get {*}$args]
    }
    merge {
      return [my Config_merge {*}$args]
    }
    set {
      my Config_set {*}$args
    }
  }

  ###
  # topic: 86a1b968cea8d439df87585afdbdaadb
  ###
  method cget args {
    return [my Config_get {*}$args]
  }

  ###
  # topic: 73e2566466b836cc4535f1a437c391b0
  ###
  method configure args {
    # Will be removed at the end of "configurelist_triggers"
    set dictargs [::oo::meta::args_to_options {*}$args]
    if {[llength $dictargs] == 1} {
      return [my cget [lindex $dictargs 0]]
    }
    set dat [my Config_merge $dictargs]
    my Config_triggers $dat
  }

  method Config_get {field args} {
    my variable config option_canonical option_getcmd
    set field [string trimleft $field -]
    if {[info exists option_canonical($field)]} {
      set field $option_canonical($field)
    }
    if {[info exists option_getcmd($field)]} {
      return [eval $option_getcmd($field)]
    }
    if {[dict exists $config $field]} {
      return [dict get $config $field]
    }
    if {[llength $args]} {
      return [lindex $args 0]
    }
    return [my meta cget $field] 
  }
  
  ###
  # topic: dc9fba12ec23a3ad000c66aea17135a5
  ###
  method Config_merge dictargs {
    my variable config option_canonical
    set rawlist $dictargs
    set dictargs {}
    set dat [my meta getnull option]
    foreach {field val} $rawlist {
      set field [string trimleft $field -]
      set field [string trimright $field :]
      if {[info exists option_canonical($field)]} {
        set field $option_canonical($field)
      }
      dict set dictargs $field $val
    }
    ###
    # Validate all inputs
    ###
    foreach {field val} $dictargs {
      set script [dict getnull $dat $field validate-command:]
      if {$script ne {}} {
        dict set dictargs $field [eval [string map [list %field% [list $field] %value% [list $val] %self% [namespace which my]] $script]]
      }
    }
    ###
    # Apply all inputs with special rules
    ###
    foreach {field val} $dictargs {
      set script [dict getnull $dat $field set-command:]
      dict set config $field $val
      if {$script ne {}} {
        {*}[string map [list %field% [list $field] %value% [list $val] %self% [namespace which my]] $script]
      }
    }
    return $dictargs
  }
  
  method Config_set args {
    set dictargs [::tool::args_to_options {*}$args]
    set dat [my Config_merge $dictargs]
    my Config_triggers $dat
  }
  
  ###
  # topic: 543c936485189593f0b9ed79b5d5f2c0
  ###
  method Config_triggers dictargs {
    set dat [my meta getnull option]
    foreach {field val} $dictargs {
      set script [dict getnull $dat $field post-command:]
      if {$script ne {}} {
        {*}[string map [list %field% [list $field] %value% [list $val] %self% [namespace which my]] $script]
      }
    }
  }

  method Option_Default field {
    set info [my meta getnull option $field]
    set getcmd [dict getnull $info default-command:]
    if {$getcmd ne {}} {
      return [{*}[string map [list %field% $field %self% [namespace which my]] $getcmd]]
    } else {
      return [dict getnull $info default:]
    }
  }
}

package provide tool::option 0.1

###
# END: option.tcl
###
###
# START: event.tcl
###
###
# This file implements the Tool event manager
###

::namespace eval ::tool {}

::namespace eval ::tool::event {}

###
# topic: f2853d380a732845610e40375bcdbe0f
# description: Cancel a scheduled event
###
proc ::tool::event::cancel {self {task *}} {
  variable timer_event
  variable timer_script

  foreach {id event} [array get timer_event $self:$task] {
    ::after cancel $event
    set timer_event($id) {}
    set timer_script($id) {}
  }
}

###
# topic: 8ec32f6b6ba78eaf980524f8dec55b49
# description:
#    Generate an event
#    Adds a subscription mechanism for objects
#    to see who has recieved this event and prevent
#    spamming or infinite recursion
###
proc ::tool::event::generate {self event args} {
  set wholist [Notification_list $self $event]
  if {$wholist eq {}} return
  set dictargs [::oo::meta::args_to_options {*}$args]
  set info $dictargs
  set strict 0
  set debug 0
  set sender $self
  dict with dictargs {}
  dict set info id     [::tool::event::nextid]
  dict set info origin $self
  dict set info sender $sender
  dict set info rcpt   {}
  foreach who $wholist {
    catch {::tool::event::notify $who $self $event $info}
  }
}

###
# topic: 891289a24b8cc52b6c228f6edb169959
# title: Return a unique event handle
###
proc ::tool::event::nextid {} {
  return "event#[format %0.8x [incr ::tool::event_count]]"
}

###
# topic: 1e53e8405b4631aec17f98b3e8a5d6a4
# description:
#    Called recursively to produce a list of
#    who recieves notifications
###
proc ::tool::event::Notification_list {self event {stackvar {}}} {
  set notify_list {}
  foreach {obj patternlist} [array get ::tool::object_subscribe] {
    if {$obj eq $self} continue
    if {$obj in $notify_list} continue
    set match 0
    foreach {objpat eventlist} $patternlist {
      if {![string match $objpat $self]} continue
      foreach eventpat $eventlist {
        if {![string match $eventpat $event]} continue
        set match 1
        break
      }
      if {$match} {
        break
      }
    }
    if {$match} {
      lappend notify_list $obj
    }
  }
  return $notify_list
}

###
# topic: b4b12f6aed69f74529be10966afd81da
###
proc ::tool::event::notify {rcpt sender event eventinfo} {
  if {[info commands $rcpt] eq {}} return 
  if {$::tool::trace} {
    puts [list event notify rcpt $rcpt sender $sender event $event info $eventinfo]
  }
  $rcpt notify $event $sender $eventinfo
}

###
# topic: 829c89bda736aed1c16bb0c570037088
###
proc ::tool::event::process {self handle script} {
  variable timer_event
  variable timer_script

  array unset timer_event $self:$handle
  array unset timer_script $self:$handle

  set err [catch {uplevel #0 $script} result errdat]
  if $err {
    puts "BGError: $self $handle $script
ERR: $result
[dict get $errdat -errorinfo]
***"
  }
}

###
# topic: eba686cffe18cd141ac9b4accfc634bb
# description: Schedule an event to occur later
###
proc ::tool::event::schedule {self handle interval script} {
  variable timer_event
  variable timer_script
  if {$::tool::trace} {
    puts [list $self schedule $handle $interval]
  }
  if {[info exists timer_event($self:$handle)]} {
    if {$script eq $timer_script($self:$handle)} {
      return
    }
    ::after cancel $timer_event($self:$handle)
  }
  set timer_script($self:$handle) $script
  set timer_event($self:$handle) [::after $interval [list ::tool::event::process $self $handle $script]]
}

proc ::tool::event::sleep msec {
  ::cron::sleep $msec
}

###
# topic: e64cff024027ee93403edddd5dd9fdde
###
proc ::tool::event::subscribe {self who event} {
  upvar #0 ::tool::object_subscribe($self) subscriptions
  if {![info exists subscriptions]} {
    set subscriptions {}
  }
  set match 0
  foreach {objpat eventlist} $subscriptions {
    if {![string match $objpat $who]} continue      
    foreach eventpat $eventlist {
      if {[string match $eventpat $event]} {
        # This rule already exists
        return
      }
    }
  }
  dict lappend subscriptions $who $event
}

###
# topic: 5f74cfd01735fb1a90705a5f74f6cd8f
###
proc ::tool::event::unsubscribe {self args} {
  upvar #0 ::tool::object_subscribe($self) subscriptions
  if {![info exists subscriptions]} {
    return
  }  
  switch [llength $args] {
    1 {
      set event [lindex $args 0]
      if {$event eq "*"} {
        # Shortcut, if the 
        set subscriptions {}
      } else {
        set newlist {}
        foreach {objpat eventlist} $subscriptions {
          foreach eventpat $eventlist {
            if {[string match $event $eventpat]} continue
            dict lappend newlist $objpat $eventpat
          }
        }
        set subscriptions $newlist
      }
    }
    2 {
      set who [lindex $args 0]
      set event [lindex $args 1]
      if {$who eq "*" && $event eq "*"} {
        set subscriptions {}
      } else {
        set newlist {}
        foreach {objpat eventlist} $subscriptions {
          if {[string match $who $objpat]} {
            foreach eventpat $eventlist {
              if {[string match $event $eventpat]} continue
              dict lappend newlist $objpat $eventpat
            }
          }
        }
        set subscriptions $newlist
      }
    }
  }
}

::tool::define ::tool::object {
  ###
  # topic: 20b4a97617b2b969b96997e7b241a98a
  ###
  method event {submethod args} {
    ::tool::event::$submethod [self] {*}$args
  }
}

###
# topic: 37e7bd0be3ca7297996da2abdf5a85c7
# description: The event manager for Tool
###
namespace eval ::tool::event {
  variable nextevent {}
  variable nexteventtime 0
}


###
# END: event.tcl
###
###
# START: pipeline.tcl
###
::namespace eval ::tool::signal {}
::namespace eval ::tao {}

# Provide a backward compatible hook
proc ::tool::main {} {
  ::cron::main
}

proc ::tool::do_events {} {
  ::cron::do_events
}

proc ::tao::do_events {} {
  ::cron::do_events
}

proc ::tao::main {} {
  ::cron::main
}


package provide tool::pipeline 0.1


###
# END: pipeline.tcl
###
###
# START: coroutine.tcl
###
proc ::tool::define::coroutine {name corobody} {
  set class [current_class]
  ::oo::meta::info $class set method_ensemble ${name} _preamble: [list {} [string map [list %coroname% $name] {
    my variable coro_queue coro_lock
    set coro %coroname%
    set coroname [info object namespace [self]]::%coroname%
  }]]
  ::oo::meta::info $class set method_ensemble ${name} coroutine: {{} {
    return $coroutine
  }}
  ::oo::meta::info $class set method_ensemble ${name} restart: {{} {
    # Don't allow a coroutine to kill itself
    if {[info coroutine] eq $coroname} return
    if {[info commands $coroname] ne {}} {
      rename $coroname {}
    }
    set coro_lock($coroname) 0
    ::coroutine $coroname {*}[namespace code [list my $coro main]]
    ::cron::object_coroutine [self] $coroname
  }}
  ::oo::meta::info $class set method_ensemble ${name} kill: {{} {
    # Don't allow a coroutine to kill itself
    if {[info coroutine] eq $coroname} return
    if {[info commands $coroname] ne {}} {
      rename $coroname {}
    }
  }}

  ::oo::meta::info $class set method_ensemble ${name} main: [list {} $corobody]

  ::oo::meta::info $class set method_ensemble ${name} clear: {{} {
    set coro_queue($coroname) {}
  }}
  ::oo::meta::info $class set method_ensemble ${name} next: {{eventvar} {
    upvar 1 [lindex $args 0] event
    if {![info exists coro_queue($coroname)]} {
      return 1
    }
    if {[llength $coro_queue($coroname)] == 0} {
      return 1
    }
    set event [lindex $coro_queue($coroname) 0]
    set coro_queue($coroname) [lrange $coro_queue($coroname) 1 end]
    return 0
  }}
  
  ::oo::meta::info $class set method_ensemble ${name} peek: {{eventvar} {
    upvar 1 [lindex $args 0] event
    if {![info exists coro_queue($coroname)]} {
      return 1
    }
    if {[llength $coro_queue($coroname)] == 0} {
      return 1
    }
    set event [lindex $coro_queue($coroname) 0]
    return 0
  }}

  ::oo::meta::info $class set method_ensemble ${name} running: {{} {
    if {[info commands $coroname] eq {}} {
      return 0
    }
    if {[::cron::task exists $coroname]} {
      set info [::cron::task info $coroname]
      if {[dict exists $info running]} {
        return [dict get $info running]
      }
    }
    return 0
  }}
  
  ::oo::meta::info $class set method_ensemble ${name} send: {args {
    lappend coro_queue($coroname) $args
    if {[info coroutine] eq $coroname} {
      return
    }
    if {[info commands $coroname] eq {}} {
      ::coroutine $coroname {*}[namespace code [list my $coro main]]
      ::cron::object_coroutine [self] $coroname
    }
    if {[info coroutine] eq {}} {
      ::cron::do_one_event $coroname
    } else {
      yield
    }
  }}
  ::oo::meta::info $class set method_ensemble ${name} default: {args {my [self method] send $method {*}$args}}

}

###
# END: coroutine.tcl
###
###
# START: organ.tcl
###
###
# A special class of objects that
# stores no meta data of its own
# Instead it vampires off of the master object
###
tool::class create ::tool::organelle {
  
  constructor {master} {
    my entangle $master
    set final_class [my select]
    if {[info commands $final_class] ne {}} {
      # Safe to switch class here, we haven't initialized anything
      oo::objdefine [self] class $final_class
    }
    my initialize
  }

  method entangle {master} {
    my graft master $master
    my forward meta $master meta
    foreach {stub organ} [$master organ] {
      my graft $stub $organ
    }
    foreach {methodname variable} [my meta branchget array_ensemble] {
      my forward $methodname $master $methodname
    }
  }
  
  method select {} {
    return {}
  }
}

###
# END: organ.tcl
###
###
# START: script.tcl
###
###
# Add configure by script facilities to TOOL
###
::tool::define ::tool::object {

  ###
  # Allows for a constructor to accept a psuedo-code
  # initialization script which exercise the object's methods
  # sans "my" in front of every command
  ###
  method Eval_Script script {
    set buffer {}
    set thisline {}
    foreach line [split $script \n] {
      append thisline $line
      if {![info complete $thisline]} {
        append thisline \n
        continue
      }
      set thisline [string trim $thisline]
      if {[string index $thisline 0] eq "#"} continue
      if {[string length $thisline]==0} continue
      if {[lindex $thisline 0] eq "my"} {
        # Line already calls out "my", accept verbatim
        append buffer $thisline \n
      } elseif {[string range $thisline 0 2] eq "::"} {
        # Fully qualified commands accepted verbatim
        append buffer $thisline \n
      } elseif {
        append buffer "my $thisline" \n
      }
      set thisline {}
    }
    eval $buffer
  }
}
###
# END: script.tcl
###

namespace eval ::tool {
  namespace export *
}

