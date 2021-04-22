###
# Adapted from Tcllib's oo::dialect
#
# Copyright (c) 2015-2018 Sean Woods
# Copyright (c) 2015 Donald K Fellows
#
# BSD License
###
# @@ Meta Begin
# Package clay::dialect 0.4
# Meta platform     tcl
# Meta summary      A utility for defining a domain specific language for TclOO systems
# Meta description  This package allows developers to generate
# Meta description  domain specific languages to describe TclOO
# Meta description  classes and objects.
# Meta category     TclOO
# Meta subject      oodialect
# Meta require      {Tcl 8.6}
# Meta author       Sean Woods
# Meta author       Donald K. Fellows
# Meta license      BSD
# @@ Meta End
namespace eval ::clay::dialect {
  namespace export create
  # Allow test rigs to overwrite the flags before invoking this script
  foreach {flag test} {
    tip470 {package vsatisfies [package provide Tcl] 8.7}
  } {
    if {![info exists ::clay::dialect::has($flag)]} {
      set ::clay::dialect::has($flag) [eval $test]
    }
  }
}


proc ::clay::dialect::Push {class} {
  ::variable class_stack
  lappend class_stack $class
}
proc ::clay::dialect::Peek {} {
  ::variable class_stack
  return [lindex $class_stack end]
}
proc ::clay::dialect::Pop {} {
  ::variable class_stack
  set class_stack [lrange $class_stack 0 end-1]
}

if {$::clay::dialect::has(tip470)} {
proc ::clay::dialect::current_class {} {
  return [uplevel 1 self]
}
} else {
proc ::clay::dialect::current_class {} {
  tailcall Peek
}
}

###
# This proc will generate a namespace, a "mother of all classes", and a
# rudimentary set of policies for this dialect.
###
proc ::clay::dialect::create {name {parent ""}} {
  variable has
  set NSPACE [NSNormalize [uplevel 1 {namespace current}] $name]
  ::namespace eval $NSPACE {::namespace eval define {}}
  ###
  # Build the "define" namespace
  ###

  if {$parent eq ""} {
    ###
    # With no "parent" language, begin with all of the keywords in
    # oo::define
    ###
    foreach command [info commands ::oo::define::*] {
      set procname [namespace tail $command]
      interp alias {} ${NSPACE}::define::$procname {} \
        ::clay::dialect::DefineThunk $procname
    }
    # Create an empty dynamic_methods proc
    proc ${NSPACE}::dynamic_methods {class} {}
    namespace eval $NSPACE {
      ::namespace export dynamic_methods
      ::namespace eval define {::namespace export *}
    }
    set ANCESTORS {}
  } else {
    ###
    # If we have a parent language, that language already has the
    # [oo::define] keywords as well as additional keywords and behaviors.
    # We should begin with that
    ###
    set pnspace [NSNormalize [uplevel 1 {namespace current}] $parent]
    apply [list parent {
      ::namespace export dynamic_methods
      ::namespace import -force ${parent}::dynamic_methods
    } $NSPACE] $pnspace

    apply [list parent {
      ::namespace import -force ${parent}::define::*
      ::namespace export *
    } ${NSPACE}::define] $pnspace
      set ANCESTORS [list ${pnspace}::object]
  }
  ###
  # Build our dialect template functions
  ###
  proc ${NSPACE}::define {oclass args} [string map [list %NSPACE% $NSPACE] {
  ###
  # To facilitate library reloading, allow
  # a dialect to create a class from DEFINE
  ###
  set class [::clay::dialect::NSNormalize [uplevel 1 {namespace current}] $oclass]
    if {[info commands $class] eq {}} {
      %NSPACE%::class create $class {*}${args}
    } else {
      ::clay::dialect::Define %NSPACE% $class {*}${args}
    }
}]
  interp alias {} ${NSPACE}::define::current_class {} \
    ::clay::dialect::current_class
  interp alias {} ${NSPACE}::define::aliases {} \
    ::clay::dialect::Aliases $NSPACE
  interp alias {} ${NSPACE}::define::superclass {} \
    ::clay::dialect::SuperClass $NSPACE

  if {[info command ${NSPACE}::class] ne {}} {
    ::rename ${NSPACE}::class {}
  }
  ###
  # Build the metaclass for our language
  ###
  ::oo::class create ${NSPACE}::class {
    superclass ::clay::dialect::MotherOfAllMetaClasses
  }
  # Wire up the create method to add in the extra argument we need; the
  # MotherOfAllMetaClasses will know what to do with it.
  ::oo::objdefine ${NSPACE}::class \
    method create {name {definitionScript ""}} \
      "next \$name [list ${NSPACE}::define] \$definitionScript"

  ###
  # Build the mother of all classes. Note that $ANCESTORS is already
  # guaranteed to be a list in canonical form.
  ###
  uplevel #0 [string map [list %NSPACE% [list $NSPACE] %name% [list $name] %ANCESTORS% $ANCESTORS] {
    %NSPACE%::class create %NSPACE%::object {
     superclass %ANCESTORS%
      # Put MOACish stuff in here
    }
  }]
  if { "${NSPACE}::class" ni $::clay::dialect::core_classes } {
    lappend ::clay::dialect::core_classes "${NSPACE}::class"
  }
  if { "${NSPACE}::object" ni $::clay::dialect::core_classes } {
    lappend ::clay::dialect::core_classes "${NSPACE}::object"
  }
}

# Support commands; not intended to be called directly.
proc ::clay::dialect::NSNormalize {namespace qualname} {
  if {![string match ::* $qualname]} {
    set qualname ${namespace}::$qualname
  }
  regsub -all {::+} $qualname "::"
}

proc ::clay::dialect::DefineThunk {target args} {
  tailcall ::oo::define [Peek] $target {*}$args
}

proc ::clay::dialect::Canonical {namespace NSpace class} {
  namespace upvar $namespace cname cname
  #if {[string match ::* $class]} {
  #  return $class
  #}
  if {[info exists cname($class)]} {
    return $cname($class)
  }
  if {[info exists ::clay::dialect::cname($class)]} {
    return $::clay::dialect::cname($class)
  }
  if {[info exists ::clay::dialect::cname(${NSpace}::${class})]} {
    return $::clay::dialect::cname(${NSpace}::${class})
  }
  foreach item [list "${NSpace}::$class" "::$class"] {
    if {[info commands $item] ne {}} {
      return $item
    }
  }
  return ${NSpace}::$class
}

###
# Implementation of the languages' define command
###
proc ::clay::dialect::Define {namespace class args} {
  Push $class
  try {
  	if {[llength $args]==1} {
      namespace eval ${namespace}::define [lindex $args 0]
    } else {
      ${namespace}::define::[lindex $args 0] {*}[lrange $args 1 end]
    }
  	${namespace}::dynamic_methods $class
  } finally {
    Pop
  }
}

###
# Implementation of how we specify the other names that this class will answer
# to
###

proc ::clay::dialect::Aliases {namespace args} {
  set class [Peek]
  namespace upvar $namespace cname cname
  set NSpace [join [lrange [split $class ::] 1 end-2] ::]
  set cname($class) $class
  foreach name $args {
    set cname($name) $class
    #set alias $name
    set alias [NSNormalize $NSpace $name]
    # Add a local metaclass reference
    if {![info exists ::clay::dialect::cname($alias)]} {
      lappend ::clay::dialect::aliases($class) $alias
      ##
      # Add a global reference, first come, first served
      ##
      set ::clay::dialect::cname($alias) $class
    }
  }
}

###
# Implementation of a superclass keyword which will enforce the inheritance of
# our language's mother of all classes
###

proc ::clay::dialect::SuperClass {namespace args} {
  set class [Peek]
  namespace upvar $namespace class_info class_info
  dict set class_info($class) superclass 1
  set ::clay::dialect::cname($class) $class
  set NSpace [join [lrange [split $class ::] 1 end-2] ::]
  set unique {}
  foreach item $args {
    set Item [Canonical $namespace $NSpace $item]
    dict set unique $Item $item
  }
  set root ${namespace}::object
  if {$class ne $root} {
    dict set unique $root $root
  }
  tailcall ::oo::define $class superclass {*}[dict keys $unique]
}

###
# Implementation of the common portions of the the metaclass for our
# languages.
###
if {[info command ::clay::dialect::MotherOfAllMetaClasses] eq {}} {
::oo::class create ::clay::dialect::MotherOfAllMetaClasses {
  superclass ::oo::class
  constructor {define definitionScript} {
    $define [self] {
      superclass
    }
    $define [self] $definitionScript
  }
  method aliases {} {
    if {[info exists ::clay::dialect::aliases([self])]} {
      return $::clay::dialect::aliases([self])
    }
  }
}
}

namespace eval ::clay::dialect {
  variable core_classes {::oo::class ::oo::object}
}
