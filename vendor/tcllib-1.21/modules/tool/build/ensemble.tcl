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

