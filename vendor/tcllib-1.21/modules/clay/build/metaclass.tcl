#-------------------------------------------------------------------------
# TITLE:
#    clay.tcl
#
# PROJECT:
#    clay: TclOO Helper Library
#
# DESCRIPTION:
#    clay(n): Implementation File
#
#-------------------------------------------------------------------------
::clay::dialect::create ::clay


proc ::clay::dynamic_methods class {
  foreach command [info commands [namespace current]::dynamic_methods_*] {
    $command $class
  }
}

proc ::clay::dynamic_methods_class {thisclass} {
  set methods {}
  set mdata [$thisclass clay find class_typemethod]
  foreach {method info} $mdata {
    if {$method eq {.}} continue
    set method [string trimright $method :/-]
    if {$method in $methods} continue
    lappend methods $method
    set arglist [dict getnull $info arglist]
    set body    [dict getnull $info body]
    ::oo::objdefine $thisclass method $method $arglist $body
  }
}

###
# New OO Keywords for clay
###
proc ::clay::define::Array {name {values {}}} {
  set class [current_class]
  set name [string trim $name :/]
  $class clay branch array $name
  dict for {var val} $values {
    $class clay set array/ $name $var $val
  }
}

###
# An annotation that objects of this class interact with delegated
# methods. The annotation is intended to be a dictionary, and the
# only reserved key is [emph {description}], a human readable description.
###
proc ::clay::define::Delegate {name info} {
  set class [current_class]
  foreach {field value} $info {
    $class clay set component/ [string trim $name :/]/ $field $value
  }
}

###
# topic: 2cfc44a49f067124fda228458f77f177
# title: Specify the constructor for a class
###
proc ::clay::define::constructor {arglist rawbody} {
  set body {
my variable DestroyEvent
set DestroyEvent 0
::clay::object_create [self] [info object class [self]]
# Initialize public variables and options
my InitializePublic
  }
  append body $rawbody
  set class [current_class]
  ::oo::define $class constructor $arglist $body
}

###
# Specify the a method for the class object itself, instead of for objects of the class
###
proc ::clay::define::Class_Method {name arglist body} {
  set class [current_class]
  $class clay set class_typemethod/ [string trim $name :/] [dict create arglist $arglist body $body]
}

###
# And alias to the new Class_Method keyword
###
proc ::clay::define::class_method {name arglist body} {
  set class [current_class]
  $class clay set class_typemethod/ [string trim $name :/] [dict create arglist $arglist body $body]
}

proc ::clay::define::clay {args} {
  set class [current_class]
  if {[lindex $args 0] in "cget set branch"} {
    $class clay {*}$args
  } else {
    $class clay set {*}$args
  }
}

###
# topic: 4cb3696bf06d1e372107795de7fe1545
# title: Specify the destructor for a class
###
proc ::clay::define::destructor rawbody {
  set body {
# Run the destructor once and only once
set self [self]
my variable DestroyEvent
if {$DestroyEvent} return
set DestroyEvent 1
}
  append body $rawbody
  ::oo::define [current_class] destructor $body
}

proc ::clay::define::Dict {name {values {}}} {
  set class [current_class]
  set name [string trim $name :/]
  $class clay branch dict $name
  foreach {var val} $values {
    $class clay set dict/ $name/ $var $val
  }
}

###
# Define an option for the class
###
proc ::clay::define::Option {name args} {
  set class [current_class]
  set dictargs {default {}}
  foreach {var val} [::clay::args_to_dict {*}$args] {
    dict set dictargs [string trim $var -:/] $val
  }
  set name [string trimleft $name -]

  ###
  # Option Class handling
  ###
  set optclass [dict getnull $dictargs class]
  if {$optclass ne {}} {
    foreach {f v} [$class clay find option_class $optclass] {
      if {![dict exists $dictargs $f]} {
        dict set dictargs $f $v
      }
    }
    if {$optclass eq "variable"} {
      variable $name [dict getnull $dictargs default]
    }
  }
  foreach {f v} $dictargs {
    $class clay set option $name $f $v
  }
}

proc ::clay::define::Method {name argstyle argspec body} {
  set class [current_class]
  set result {}
  switch $argstyle {
    dictargs {
      append result "::dictargs::parse \{$argspec\} \$args" \;
    }
  }
  append result $body
  oo::define $class method $name [list [list args [list dictargs $argspec]]] $result
}

###
# Define a class of options
# All field / value pairs will be be inherited by an option that
# specify [emph name] as it class field.
###
proc ::clay::define::Option_Class {name args} {
  set class [current_class]
  set dictargs {default {}}
  set name [string trimleft $name -:]
  foreach {f v} [::clay::args_to_dict {*}$args] {
    $class clay set option_class $name [string trim $f -/:] $v
  }
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
proc ::clay::define::Variable {name {default {}}} {
  set class [current_class]
  set name [string trimright $name :/]
  $class clay set variable/ $name $default
}
