###
# An object which is intended to be it's own class.
# arglist:
#   name    {mandatory 1 positional 1 description {the fully qualified name of the object}}
#   script  {mandatory 1 positional 1 description {
# A script that will be executed in the object's namespace.
# The command [bold clay] is provided, and will allow the script to exercise the object's own
# clay method. The command [bold method] is provided, and will define or modify a per-instance
# version of the object's method. The command [bold Ensemble] is provided, and will define or
# modify an ensemble method (though customized for this object)
# }}
###
proc ::clay::singleton {name script} {
  if {[info commands $name] eq {}} {
    ::clay::object create $name
  }
  oo::objdefine $name {
method SingletonProcs {} {
proc class class {
  uplevel 1 "oo::objdefine \[self\] class $class"
  my clay delegate class $class
}
proc clay args {
  my clay {*}$args
}
proc Ensemble {rawmethod args} {
  if {[llength $args]==2} {
    lassign $args argspec body
    set argstyle tcl
  } elseif {[llength $args]==3} {
    lassign $args argstyle argspec body
  } else {
    error "Usage: Ensemble name ?argstyle? argspec body"
  }
  set class [uplevel 1 self]
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
      oo::objdefine $class method $realmethod [list method [list args $argspec]] $realbody
    } else {
      oo::objdefine $class method $realmethod [list method {*}$argspec] $realbody
    }
  } else {
    $class clay set method_ensemble $ensemble $method: "tailcall my $realmethod {*}\$args"
    if {$argstyle eq "dictargs"} {
      oo::objdefine $class method $realmethod [list [list args $argspec]] $realbody
    } else {
      oo::objdefine $class method $realmethod $argspec $realbody
    }
  }
  if {$::clay::trace>2} {
    puts [list $class clay set method_ensemble/ $ensemble [string trim $method :/]  ...]
  }
}
proc method args {
  uplevel 1 "oo::objdefine \[self\] method {*}$args"
}
}
method script script {
  my clay busy 1
  my SingletonProcs
  eval $script
  my clay busy 0
  my InitializePublic
}
}
  $name script $script
  return $name
}
