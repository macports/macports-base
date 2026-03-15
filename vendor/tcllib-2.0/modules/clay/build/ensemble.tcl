::namespace eval ::clay::define {}

###
# Produce the body of an ensemble's public dispatch method
# ensemble is the name of the the ensemble.
# einfo is a dictionary of methods for the ensemble, and each value is a script
# to execute on dispatch
# example:
# ::clay::ensemble_methodbody foo {
#   bar {tailcall my Foo_bar {*}$args}
#   baz {tailcall my Foo_baz {*}$args}
#   clock {return [clock seconds]}
#   default {puts "You gave me $method"}
# }
###
proc ::clay::ensemble_methodbody {ensemble einfo} {
  set default standard
  set preamble {}
  set eswitch {}
  set Ensemble [string totitle $ensemble]
  if {$Ensemble eq "."} continue
  foreach {msubmethod minfo} [lsort -dictionary -stride 2 $einfo] {
    if {$msubmethod eq "."} continue
    if {![dict exists $minfo body:]} {
      continue
    }
    set submethod [string trim $msubmethod :/-]
    if {$submethod eq "default"} {
      set default [dict get $minfo body:]
    } else {
      dict set eswitch $submethod [dict get $minfo body:]
    }
    if {[dict exists $submethod aliases:]} {
      foreach alias [dict get $minfo aliases:] {
        if {![dict exists $eswitch $alias]} {
          dict set eswitch $alias [dict get $minfo body:]
        }
      }
    }
  }
  set methodlist [lsort -dictionary [dict keys $eswitch]]
  if {![dict exists $eswitch <list>]} {
    dict set eswitch <list> {return $methodlist}
  }
  if {$default eq "standard"} {
    set default "error \"unknown method $ensemble \$method. Valid: \$methodlist\""
  }
  dict set eswitch default $default
  set mbody {}
  append mbody \n [list set methodlist $methodlist]
  append mbody \n "switch -- \$method \{$eswitch\}" \n
  return $mbody
}

::proc ::clay::define::Ensemble {rawmethod args} {
  if {[llength $args]==2} {
    lassign $args argspec body
    set argstyle tcl
  } elseif {[llength $args]==3} {
    lassign $args argstyle argspec body
  } else {
    error "Usage: Ensemble name ?argstyle? argspec body"
  }
  set class [current_class]
  #if {$::clay::trace>2} {
  #  puts [list $class Ensemble $rawmethod $argspec $body]
  #}
  set mlist [split $rawmethod "::"]
  set ensemble [string trim [lindex $mlist 0] :/]
  set method   [string trim [lindex $mlist 2] :/]
  if {[string index $method 0] eq "_"} {
    $class clay set method_ensemble $ensemble $method $body
    return
  }
  set realmethod  [string totitle $ensemble]_${method}
  set realbody {}
  if {$argstyle eq "dictargs"} {
    append realbody "::dictargs::parse \{$argspec\} \$args" \n
  }
  if {[$class clay exists method_ensemble $ensemble _preamble]} {
    append realbody [$class clay get method_ensemble $ensemble _preamble] \n
  }
  append realbody $body
  if {$method eq "default"} {
    $class clay set method_ensemble $ensemble $method: "tailcall my $realmethod \$method {*}\$args"
    if {$argstyle eq "dictargs"} {
      oo::define $class method $realmethod [list method [list args $argspec]] $realbody
    } else {
      oo::define $class method $realmethod [list method {*}$argspec] $realbody
    }
  } else {
    $class clay set method_ensemble $ensemble $method: "tailcall my $realmethod {*}\$args"
    if {$argstyle eq "dictargs"} {
      oo::define $class method $realmethod [list [list args $argspec]] $realbody
    } else {
      oo::define $class method $realmethod $argspec $realbody
    }
  }
  if {$::clay::trace>2} {
    puts [list $class clay set method_ensemble/ $ensemble [string trim $method :/]  ...]
  }
}


