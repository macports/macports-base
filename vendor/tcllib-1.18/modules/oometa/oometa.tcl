###
# Author: Sean Woods, yoda@etoyoc.com
##
# TclOO routines to implement property tracking by class and object
###
package require dicttool
namespace eval ::oo::meta {
  variable dirty_classes {}
  variable core_classes {::oo::class ::oo::object ::tao::moac}
}

proc ::oo::meta::args_to_dict args {
  if {[llength $args]==1} {
    return [lindex $args 0]
  }
  return $args
}

proc ::oo::meta::args_to_options args {
  set result {}
  foreach {var val} [args_to_dict {*}$args] {
    lappend result [string trimleft $var -] $val
  }
  return $result
}

proc ::oo::meta::ancestors class {
  set class [::oo::meta::normalize $class]
  set thisresult {}
  set result {}
  set queue $class
  variable core_classes
  
  while {[llength $queue]} {
    set tqueue $queue
    set queue {}
    foreach qclass $tqueue {
      if {$qclass in $core_classes} continue
      foreach aclass [::info class superclasses $qclass] {
        if { $aclass in $result } continue
        if { $aclass in $queue } continue
        lappend queue $aclass
      }
      foreach aclass [::info class mixins $qclass] {
        if { $aclass in $result } continue
        if { $aclass in $queue } continue
        lappend queue $aclass
      }
    }
    foreach qclass $tqueue {
      if {$qclass ni $core_classes} continue
      foreach aclass [::info class superclasses $qclass] {
        if { $aclass in $result } continue
        if { $aclass in $queue } continue
        lappend queue $aclass
      }
      foreach aclass [::info class mixins $qclass] {
        if { $aclass in $result } continue
        if { $aclass in $queue } continue
        lappend queue $aclass
      }
    }
    foreach item $tqueue {
      if { $item ni $result } {
        set result [linsert $result 0 $item]
      }
    }
  }
  return $result
}

proc ::oo::meta::info {class submethod args} {
  set class [::oo::meta::normalize $class]
  switch $submethod {
    rebuild {
      if {$class ni $::oo::meta::dirty_classes} {
        lappend ::oo::meta::dirty_classes $class
      }
    }
    is {
      set info [metadata $class]
      return [string is [lindex $args 0] -strict [dict getnull $info {*}[lrange $args 1 end]]]
    }
    for -
    map {
      set info [metadata $class]
      return [uplevel 1 [list ::dict $submethod [lindex $args 0] [dict get $info {*}[lrange $args 1 end-1]] [lindex $args end]]]
    }
    with {
      upvar 1 TEMPVAR info
      set info [metadata $class]
      return [uplevel 1 [list ::dict with TEMPVAR {*}$args]]
    }
    branchget {
      set info [metadata $class]
      set result {}
      foreach {field value} [dict getnull $info {*}$args] {
        dict set result [string trimright $field :] $value
      }
      return $result
    }
    branchset {
      if {$class ni $::oo::meta::dirty_classes} {
        lappend ::oo::meta::dirty_classes $class
      }
      foreach {field value} [lindex $args end] {
        ::dict set ::oo::meta::local_property($class) {*}[lrange $args 0 end-1] [string trimright $field :]: $value
      }
    }
    leaf_add {
      set result [dict getnull $::oo::meta::local_property($class) {*}[lindex $args 0]]
      ladd result {*}[lrange $args 1 end]
      dict set ::oo::meta::local_property($class) {*}[lindex $args 0] $result
    }
    leaf_remove {
      set result {}
      forearch element [dict getnull $::oo::meta::local_property($class) {*}[lindex $args 0]] {
        if { $element in [lrange $args 1 end]} continue
        lappend result $element
      }
      dict set ::oo::meta::local_property($class) {*}[lindex $args 0] $result
    }
    append -
    incr -
    lappend -
    set -
    unset -
    update {
      if {$class ni $::oo::meta::dirty_classes} {
        lappend ::oo::meta::dirty_classes $class
      }
      ::dict $submethod ::oo::meta::local_property($class) {*}$args
    }
    merge {
      if {$class ni $::oo::meta::dirty_classes} {
        lappend ::oo::meta::dirty_classes $class
      }
      set ::oo::meta::local_property($class) [dict rmerge $::oo::meta::local_property($class) {*}$args]
    }
    dump {
      set info [metadata $class]
      return $info
    }
    default {
      set info [metadata $class]
      return [::dict $submethod $info {*}$args] 
    }
  }
}

proc ::oo::meta::localdata {class args} {
  if {![::info exists ::oo::meta::local_property($class)]} {
    return {}
  }
  if {[::llength $args]==0} {
    return $::oo::meta::local_property($class)
  }
  return [::dict getnull $::oo::meta::local_property($class) {*}$args]
}

proc ::oo::meta::normalize class {
  set class ::[string trimleft $class :]
}

proc ::oo::meta::metadata {class {force 0}} {
  set class [::oo::meta::normalize $class]
  ###
  # Destroy the cache of all derivitive classes
  ###
  if {$force} {
    unset -nocomplain ::oo::meta::cached_property
    unset -nocomplain ::oo::meta::cached_hierarchy
  } else {
    variable dirty_classes
    foreach dclass $dirty_classes {
      foreach {cclass cancestors} [array get ::oo::meta::cached_hierarchy] {
        if {$dclass in $cancestors} {
          unset -nocomplain ::oo::meta::cached_property($cclass)
          unset -nocomplain ::oo::meta::cached_hierarchy($cclass)
        }
      }
      if {[dict getnull $::oo::meta::local_property($dclass) classinfo type:] eq "core"} {
        if {$dclass ni $::oo::meta::core_classes} {
          lappend ::oo::meta::core_classes $dclass
        }
      }
    }
  }

  ###
  # If the cache is available, use it
  ###
  variable cached_property
  if {[::info exists cached_property($class)]} {
    return $cached_property($class)
  }
  ###
  # Build a cache of the hierarchy and the
  # aggregate metadata for this class and store
  # them for future use
  ###
  variable cached_hierarchy
  set metadata {}
  set stack {}
  variable local_property
  set cached_hierarchy($class) [::oo::meta::ancestors $class]
  foreach aclass [lrange $cached_hierarchy($class) 0 end-1] {
    if {[::info exists local_property($aclass)]} {
      lappend metadata $local_property($aclass)
    }
  }
  lappend metadata {classinfo {type {}}}
  if {[::info exists local_property($class)]} {
    set metadata [dict rmerge {*}$metadata $local_property($class)]
  } else {
    set metadata [dict rmerge {*}$metadata]
  }
  set cached_property($class) $metadata
  return $metadata
}

proc ::oo::meta::search args {
  variable local_property

  set path [lrange $args 0 end-1]
  set value [lindex $args end]

  set result {}
  foreach {class info} [array get local_property] {
    if {[dict exists $info {*}$path:]} {
      if {[string match [dict get $info {*}$path:] $value]} {
        lappend result $class
      }
      continue
    }
    if {[dict exists $info {*}$path]} {
      if {[string match [dict get $info {*}$path] $value]} {
        lappend result $class
      }
    }
  }
  return $result
}

proc ::oo::define::meta {args} {
  set class [lindex [::info level -1] 1]
  if {[lindex $args 0] in "set branchset"} {
    ::oo::meta::info $class {*}$args
  } else {
    ::oo::meta::info $class set {*}$args
  }
}

oo::define oo::class {
  method meta {submethod args} {
    return [::oo::meta::info [self] $submethod {*}$args]
  }
}

oo::define oo::object {
  ###
  # title: Provide access to meta data
  # format: markdown
  # description:
  # The *meta* method allows an object access
  # to a combination of its own meta data as
  # well as to that of its class
  ###
  method meta {submethod args} {
    set class [::info object class [self object]]
    my variable meta
    switch $submethod {
      cget {
        ###
        # submethod: cget
        # arguments: ?*path* ...? *field*
        # format: markdown
        # description:
        # Retrieve a value from the local objects **meta** dict
        # or from the class' meta data. Values are searched in the
        # following order:
        # 1. From the local dict as **path** **field:**
        # 2. From the local dict as **path** **field**
        # 3. From class meta data as const **path** **field:**
        # 4. From class meta data as const **path** **field**
        # 5. From class meta data as **path** **field:**
        # 6. From class meta data as **path** **field**
        ###
        set path [lrange $args 0 end-1]
        set field [string trim [lindex $args end] :]
        if {[dict exists $meta {*}$path $field:]} {
          return [dict get $meta {*}$path $field:]
        }
        if {[dict exists $meta {*}$path $field]} {
          return [dict get $meta {*}$path $field]
        }
        set class_metadata [::oo::meta::metadata $class]
        if {[dict exists $class_metadata const {*}$path $field:]} {
          return [dict get $class_metadata const {*}$path $field:]
        }
        if {[dict exists $class_metadata const {*}$path $field]} {
          return [dict get $class_metadata const {*}$path $field]
        }
        if {[dict exists $class_metadata {*}$path $field:]} {
          return [dict get $class_metadata {*}$path $field:]
        }
        if {[dict exists $class_metadata {*}$path $field]} {
          return [dict get $class_metadata {*}$path $field]
        }
        return {}
      }
      is {
        set value [my meta cget {*}[lrange $args 1 end]]
        return [string is [lindex $args 0] -strict $value]
      }
      for -
      map {
        set class_metadata [::oo::meta::metadata $class]
        set info [dict rmerge $class_metadata $meta]
        return [uplevel 1 [list dict $submethod [lindex $args 0] [dict get $info {*}[lrange $args 1 end-1]] [lindex $args end]]]
      }
      with {
        set class_metadata [::oo::meta::metadata $class]
        upvar 1 TEMPVAR info
        set info [dict rmerge $class_metadata $meta]
        return [uplevel 1 [list dict with TEMPVAR {*}$args]]
      }
      dump {
        set class_metadata [::oo::meta::metadata $class]
        return [dict rmerge $class_metadata $meta]
      }
      append -
      incr -
      lappend -
      set -
      unset -
      update {
        return [dict $submethod meta {*}$args]
      }
      branchset {
        foreach {field value} [lindex $args end] {
          dict set meta {*}[lrange $args 0 end-1] [string trimright $field :]: $value
        }
      }
      rmerge -
      merge {
        set meta [dict rmerge $meta {*}$args]
        return $meta
      }
      getnull {
        return [dict rmerge [dict getnull [::oo::meta::metadata $class] {*}$args] [dict getnull $meta {*}$args]]
      }
      branchget {
        set result {}
        foreach {field value} [dict getnull [::oo::meta::metadata $class] {*}$args] {
          dict set result [string trimright $field :] $value
        }
        foreach {field value} [dict getnull $meta {*}$args] {
          dict set result [string trimright $field :] $value
        }
        return $result
      }
      get {
        if {![dict exists $meta {*}$args]} {
          return [dict get [::oo::meta::metadata $class] {*}$args]
        }
        return [dict rmerge [dict getnull [::oo::meta::metadata $class] {*}$args] [dict getnull $meta {*}$args]]
      }
      default {
        set class_metadata [::oo::meta::metadata $class]
        set info [dict rmerge $class_metadata $meta]
        return [dict $submethod $info {*}$args] 
      }
    }
  }
}
package provide oo::meta 0.4.1