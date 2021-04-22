###
# Author: Sean Woods, yoda@etoyoc.com
##
# TclOO routines to implement property tracking by class and object
###
package require Tcl 8.6 ;# tailcall
package require dicttool
package provide oo::meta 0.7.1

namespace eval ::oo::meta {
  variable dirty_classes {}
  variable core_classes {::oo::class ::oo::object}
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
  variable core_classes
  set class [::oo::meta::normalize $class]
  set core_result {}
  set queue $class
  set result {}
  # Rig things such that that the top superclasses
  # are evaluated first
  while {[llength $queue]} {
    set tqueue $queue
    set queue {}
    foreach qclass $tqueue {
      if {$qclass in $core_classes} {
        if {$qclass ni $core_result} {
          lappend core_result $qclass
        }
        continue
      }
      foreach aclass [::info class superclasses $qclass] {
        if { $aclass in $result } continue
        if { $aclass in $core_result } continue
        if { $aclass in $queue } continue
        lappend queue $aclass
      }
    }
    foreach item $tqueue {
      if {$item in $core_result} continue
      if { $item ni $result } {
        set result [linsert $result 0 $item]
      }
    }
  }
  # Handle core classes last
  set queue $core_result
  while {[llength $queue]} {
    set tqueue $queue
    set queue {}
    foreach qclass $tqueue {
      foreach aclass [::info class superclasses $qclass] {
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

proc oo::meta::info {class submethod args} {
  set class [::oo::meta::normalize $class]
  switch $submethod {
    cget {
      ###
      # submethod: cget
      # arguments: ?*path* ...? *field*
      # format: markdown
      # description:
      # Retrieve a value from the class' meta data. Values are searched in the
      # following order:
      # 1. From class meta data as const **path** **field:**
      # 2. From class meta data as const **path** **field**
      # 3. From class meta data as **path** **field:**
      # 4. From class meta data as **path** **field**
      ###
      set path [lrange $args 0 end-1]
      set field [string trimright [lindex $args end] :]
      foreach mclass [lreverse [::oo::meta::ancestors $class]] {
        if {![::info exists ::oo::meta::local_property($mclass)]} continue
        set class_metadata $::oo::meta::local_property($mclass)
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
      }
      return {}
    }
    rebuild {
      ::oo::meta::rebuild $class
    }
    is {
      set info [metadata $class]
      return [string is [lindex $args 0] -strict [dict getnull $info {*}[lrange $args 1 end]]]
    }
    for -
    map {
      set info [metadata $class]
      uplevel 1 [list ::dict $submethod [lindex $args 0] [dict get $info {*}[lrange $args 1 end-1]] [lindex $args end]]
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
      ::oo::meta::rebuild $class
      foreach {field value} [lindex $args end] {
        ::dict set ::oo::meta::local_property($class) {*}[lrange $args 0 end-1] [string trimright $field :]: $value
      }
    }
    leaf_add {
      if {[::info exists ::oo::meta::local_property($class)]} {
        set result [dict getnull $::oo::meta::local_property($class) {*}[lindex $args 0]]
      }
      ladd result {*}[lrange $args 1 end]
      dict set ::oo::meta::local_property($class) {*}[lindex $args 0] $result
    }
    leaf_remove {
      if {![::info exists ::oo::meta::local_property($class)]} return
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
      ::oo::meta::rebuild $class
      ::dict $submethod ::oo::meta::local_property($class) {*}$args
    }
    merge {
      ::oo::meta::rebuild $class
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
      if {![::info exists ::oo::meta::local_property($dclass)]} continue
      if {[dict getnull $::oo::meta::local_property($dclass) classinfo type:] eq "core"} {
        if {$dclass ni $::oo::meta::core_classes} {
          lappend ::oo::meta::core_classes $dclass
        }
      }
    }
    set dirty_classes {}
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
  foreach class $cached_hierarchy($class) {
    if {[::info exists local_property($class)]} {
      lappend metadata $local_property($class)
    }
  }
  #foreach aclass [lreverse [::info class superclasses $class]] {
  #  lappend metadata [::oo::meta::metadata $aclass]
  #}

  lappend metadata {classinfo {type: {}}}
  if {[::info exists local_property($class)]} {
    lappend metadata $local_property($class)
  }
  set metadata [dict rmerge {*}$metadata]
  set cached_property($class) $metadata
  return $metadata
}

proc ::oo::meta::rebuild args {
  foreach class $args {
    if {$class ni $::oo::meta::dirty_classes} {
      lappend ::oo::meta::dirty_classes $class
    }
  }
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
  if {[lindex $args 0] in "cget set branchset"} {
    ::oo::meta::info $class {*}$args
  } else {
    ::oo::meta::info $class set {*}$args
  }
}

oo::define oo::class {
  method meta {submethod args} {
    tailcall ::oo::meta::info [self] $submethod {*}$args
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
    my variable meta MetaMixin
    if {![info exists MetaMixin]} {
      set MetaMixin {}
    }
    set class [::info object class [self object]]
    set classlist [list $class {*}$MetaMixin]
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
        # 0. (If path length==1) From the _config array
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
        foreach mclass [lreverse $classlist] {
          set class_metadata [::oo::meta::metadata $mclass]
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
        }
        return {}
      }
      is {
        set value [my meta cget {*}[lrange $args 1 end]]
        return [string is [lindex $args 0] -strict $value]
      }
      for -
      map {
        foreach mclass $classlist {
          lappend mdata [::oo::meta::metadata $mclass]
        }
        set info [dict rmerge {*}$mdata $meta]
        uplevel 1 [list ::dict $submethod [lindex $args 0] [dict get $info {*}[lrange $args 1 end-1]] [lindex $args end]]
      }
      with {
        upvar 1 TEMPVAR info
        foreach mclass $classlist {
          lappend mdata [::oo::meta::metadata $mclass]
        }
        set info [dict rmerge {*}$mdata $meta]
        return [uplevel 1 [list dict with TEMPVAR {*}$args]]
      }
      dump {
        foreach mclass $classlist {
          lappend mdata [::oo::meta::metadata $mclass]
        }
        return [dict rmerge {*}$mdata $meta]
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
      exists {
        foreach mclass $classlist {
          if {[dict exists [::oo::meta::metadata $mclass] {*}$args]} {
            return 1
          }
        }
        if {[dict exists $meta {*}$args]} {
          return 1
        }
        return 0
      }
      get -
      getnull {
        if {[string index [lindex $args end] end]==":"} {
          # Looking for a leaf node
          if {[dict exists $meta {*}$args]} {
            return [dict get $meta {*}$args]
          }
          foreach mclass [lreverse $classlist] {
            set mdata [::oo::meta::metadata $mclass]
            if {[dict exists $mdata {*}$args]} {
              return [dict get $mdata {*}$args]
            }
          }
          if {$submethod == "get"} {
            error "key \"$args\" not known in metadata"
          }
          return {}
        }
        # Looking for a branch node
        # So we need to composite the result
        set found 0
        foreach mclass $classlist {
          set mdata [::oo::meta::metadata $mclass]
          if {[dict exists $mdata {*}$args]} {
            set found 1
            lappend result [dict get $mdata {*}$args]
          }
        }
        if {[dict exists $meta {*}$args]} {
          set found 1
          lappend result [dict get $meta {*}$args]
        }
        if {!$found} {
          if {$submethod == "get"} {
            error "key \"$args\" not known in metadata"
          }
          return {}
        }
        return [dict rmerge {*}$result]
      }
      branchget {
        set result {}
        foreach mclass [lreverse $classlist] {
          foreach {field value} [dict getnull [::oo::meta::metadata $mclass] {*}$args] {
            dict set result [string trimright $field :] $value
          }
        }
        foreach {field value} [dict getnull $meta {*}$args] {
          dict set result [string trimright $field :] $value
        }
        return $result
      }
      mixin {
        foreach mclass $args {
          set mclass [::oo::meta::normalize $mclass]
          if {$mclass ni $MetaMixin} {
            lappend MetaMixin $mclass
          }
        }
      }
      mixout {
        foreach mclass $args {
          set mclass [::oo::meta::normalize $mclass]
          while {[set i [lsearch $MetaMixin $mclass]]>=0} {
            set MetaMixin [lreplace $MetaMixin $i $i]
          }
        }
      }
      default {
        foreach mclass $classlist {
          lappend mdata [::oo::meta::metadata $mclass]
        }
        set info [dict rmerge {*}$mdata $meta]
        return [dict $submethod $info {*}$args] 
      }
    }
  }
}
