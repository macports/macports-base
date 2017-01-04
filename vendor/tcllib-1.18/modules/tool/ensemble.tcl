::namespace eval ::tool::define {}

###
# topic: fb8d74e9c08db81ee6f1275dad4d7d6f
###
proc ::tool::dynamic_methods_ensembles {thisclass metadata} {
  variable trace
  set ensembledict {}
  if {$trace} { puts "dynamic_methods_ensembles $thisclass"}
  ###
  # Only go through the motions for classes that have a locally defined
  # ensemble method implementation
  ###
  set local_ensembles [dict keys [::oo::meta::localdata $thisclass method_ensemble]]
  foreach ensemble $local_ensembles {
    set einfo [dict getnull $metadata method_ensemble $ensemble]
    set eswitch {}
    set default standard
    if {[dict exists $einfo default:]} {
      set emethodinfo [dict get $einfo default:]
      set arglist     [lindex $emethodinfo 0]
      set realbody    [lindex $emethodinfo 1]
      if {$arglist in {args {}}} {
        set body {}
      } else {
        set body "\n      ::tool::dynamic_arguments [list $arglist] {*}\$args"
      }
      append body "\n      " [string trim $realbody] "      \n"
      set default $body
      dict unset einfo default:
    }
    set eswitch \n
    append eswitch "\n    [list <list> [list return [lsort -dictionary [dict keys $einfo]]]]" \n
    foreach {submethod esubmethodinfo} [lsort -dictionary -stride 2 $einfo] {
      if {$submethod eq "_preamble:"} continue
      set submethod [string trimright $submethod :]
      lassign $esubmethodinfo arglist realbody
      if {[string length [string trim $realbody]] eq {}} {
        append eswitch "    [list $submethod {}]" \n
      } else {
        if {$arglist in {args {}}} {
          set body {}
        } else {
          set body "\n      ::tool::dynamic_arguments [list $arglist] {*}\$args"
        }
        append body "\n      " [string trim $realbody] "      \n"
        append eswitch "    [list $submethod $body]" \n
      }
    }
    if {$default=="standard"} {
      set default "error \"unknown method $ensemble \$method. Valid: [lsort -dictionary [dict keys $eswitch]]\""
    }
    append eswitch [list default $default] \n
    if {[dict exists $einfo _preamble:]} {
      set body [lindex [dict get $einfo _preamble:] 1]
    } else {
      set body {}
    }
    append body \n "set code \[catch {switch -- \$method [list $eswitch]} result opts\]"

    #if { $ensemble == "action" } {
    #  append body \n {  if {$code == 0} { my event generate event $method {*}$dictargs}}
    #}
    append body \n {return -options $opts $result}
    oo::define $thisclass method $ensemble {{method default} args} $body
    # Define a property for this ensemble for introspection
    ::oo::meta::info $thisclass set ensemble_methods $ensemble: [lsort -dictionary [dict keys $einfo]]
  }
  if {$trace} { puts "/dynamic_methods_ensembles $thisclass"}
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

