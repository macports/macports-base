# clay::object
#
# This class is inherited by all classes that have options.
#
::oo::define ::clay::object {

  ###
  # description:
  # The [method clay] method allows an object access
  # to a combination of its own clay data as
  # well as to that of its class
  # ensemble:
  # ancestors {
  #   argspec {}
  #   description {Return the class this object belongs to, all classes mixed into this object, and all ancestors of those classes in search order.}
  # }
  # cache {
  #   argspec {path {mandatory 1 positional 1} value {mandatory 1 positional 1}}
  #   description {Store VALUE in such a way that request in SEARCH for PATH will always return it until the cache is flushed}
  # }
  # cget {
  #   argspec {field {mandatory 1 positional 1}}
  #   description {
  # Pull a value from either the object's clay structure or one of its constituent classes that matches the field name.
  # The order of search us:
  # [para] 1. The as a value in local dict variable config
  # [para] 2. The as a value in local dict variable clay
  # [para] 3. As a leaf in any ancestor as a root of the clay tree
  # [para] 4. As a leaf in any ancestor as [const const] [emph field]
  # [para] 5. As a leaf in any ancestor as [const option] [emph field] [const default]
  #   }
  # }
  # delegate {
  #   argspec {stub {mandatory 0 positional 1} object {mandatory 0 positional 1}}
  #   description {
  # Introspect or control method delegation. With no arguments, the method will return a
  # key/value list of stubs and objects. With just the [arg stub] argument, the method will
  # return the object (if any) attached to the stub. With a [arg stub] and an [arg object]
  # this command will forward all calls to the method [arg stub] to the [arg object].
  # }
  # }
  # dump { argspec {} description {Return a complete dump of this object's clay data, as well as the data from all constituent classes recursively blended in.}}
  # ensemble_map {argspec {} description {Return a dictionary describing the method ensembles to be assembled for this object}}
  # eval {argspec {script {mandatory 1 positional 1}} description {Evaluated a script in the namespace of this object}}
  # evolve {argspec {} description {Trigger the [method InitializePublic] private method}}
  # exists {argspec {path {mandatory 1 positional 1 repeating 1}} description {Returns 1 if [emph path] exists in either the object's clay data. Values greater than one indicate the element exists in one of the object's constituent classes. A value of zero indicates the path could not be found.}}
  # flush {argspec {} description {Wipe any caches built by the clay implementation}}
  # forward {argspec {method {positional 1 mandatory 1} object {positional 1 mandatory 1}} description {A convenience wrapper for
  # [example {oo::objdefine [self] forward {*}$args}]
  # }
  # }
  # get {argspec {path {mandatory 1 positional 1 repeating 1}}
  #   description {Pull a chunk of data from the clay system. If the last element of [emph path] is a branch (ends in a slash /),
  #   returns a recursive merge of all data from this object and it's constituent classes of the data in that branch.
  #   If the last element is a leaf, search this object for a matching leaf, or search all  constituent classes for a matching
  #   leaf and return the first value found.
  #   If no value is found, returns an empty string.
  # }
  # }
  # leaf {argspec {path {mandatory 1 positional 1 repeating 1}} description {A modified get which is tailored to pull only leaf elements}}
  # merge {argspec {dict {mandatory 1 positional 1 repeating 1}} description {Recursively merge the dictionaries given into the object's local clay storage.}}
  # mixin {argspec {class {mandatory 1 positional 1 repeating 1}} description {
  # Perform [lb]oo::objdefine [lb]self[rb] mixin[rb] on this object, with a few additional rules:
  #   Prior to the call, for any class was previously mixed in, but not in the new result, execute the script registered to mixin/ unmap-script (if given.)
  #   For all new classes, that were not present prior to this call, after the native TclOO mixin is invoked, execute the script registered to mixin/ map-script (if given.)
  #   Fall all classes that are now present and “mixed in”, execute the script registered to mixin/ react-script (if given.)
  # }}
  # mixinmap {
  #   argspec {stub {mandatory 0 positional 1} classes {mandatory 0 positional 1}}
  #   description {With no arguments returns the map of stubs and classes mixed into the current object. When only stub is given,
  #  returns the classes mixed in on that stub. When stub and classlist given, replace the classes currently on that stub with the given
  #  classes and invoke clay mixin on the new matrix of mixed in classes.
  # }
  # }
  # provenance {argspec {path {mandatory 1 positional 1 repeating 1}} description {Return either [const self] if that path exists in the current object, or return the first class (if any) along the clay search path which contains that element.}}
  # replace {argspec {dictionary {mandatory 1 positional 1}} description {Replace the contents of the internal clay storage with the dictionary given.}}
  # search {
  #   argspec {path {mandatory 1 positional 1} valuevar {mandatory 1 positional 1} isleafvar {mandatory 1 positional 1}}
  #   description {Return true, and set valuevar to the value and isleafar to true for false if PATH was found in the cache.}
  #}
  # source {argspec {filename {mandatory 1 positional 1}} description {Source the given filename within the object's namespace}}
  # set {argspec {path {mandatory 1 positional 1 repeating 1} value {mandatory 1 postional 1}} description {Merge the conents of [const value] with the object's clay storage at [const path].}}
  ###
  method clay {submethod args} {
    my variable clay claycache clayorder config option_canonical
    if {![info exists clay]} {set clay {}}
    if {![info exists claycache]} {set claycache {}}
    if {![info exists config]} {set config {}}
    if {![info exists clayorder] || [llength $clayorder]==0} {
      set clayorder {}
      if {[dict exists $clay cascade]} {
        dict for {f v} [dict get $clay cascade] {
          if {$f eq "."} continue
          if {[info commands $v] ne {}} {
            lappend clayorder $v
          }
        }
      }
      lappend clayorder {*}[::clay::ancestors [info object class [self]] {*}[lreverse [info object mixins [self]]]]
    }
    switch $submethod {
      ancestors {
        return $clayorder
      }
      branch {
        set path [::clay::tree::storage $args]
        if {![dict exists $clay {*}$path .]} {
          dict set clay {*}$path . {}
        }
      }
      busy {
        my variable clay_busy
        if {[llength $args]} {
          set clay_busy [string is true [lindex $args 0]]
          set claycache {}
        }
        if {![info exists clay_busy]} {
          set clay_busy 0
        }
        return $clay_busy
      }
      cache {
        set path [lindex $args 0]
        set value [lindex $args 1]
        dict set claycache $path $value
      }
      cget {
        # Leaf searches return one data field at a time
        # Search in our local dict
        if {[llength $args]==1} {
          set field [string trim [lindex $args 0] -:/]
          if {[info exists option_canonical($field)]} {
            set field $option_canonical($field)
          }
          if {[dict exists $config $field]} {
            return [dict get $config $field]
          }
        }
        set path [::clay::tree::storage $args]
        if {[dict exists $clay {*}$path]} {
          return [dict get $clay {*}$path]
        }
        # Search in our local cache
        if {[dict exists $claycache {*}$path]} {
          if {[dict exists $claycache {*}$path .]} {
            return [dict remove [dict get $claycache {*}$path] .]
          } else {
            return [dict get $claycache {*}$path]
          }
        }
        # Search in the in our list of classes for an answer
        foreach class $clayorder {
          if {[$class clay exists {*}$path]} {
            set value [$class clay get {*}$path]
            dict set claycache {*}$path $value
            return $value
          }
          if {[$class clay exists const {*}$path]} {
            set value [$class clay get const {*}$path]
            dict set claycache {*}$path $value
            return $value
          }
          if {[$class clay exists option {*}$path default]} {
            set value [$class clay get option {*}$path default]
            dict set claycache {*}$path $value
            return $value
          }
        }
        return {}
      }
      delegate {
        if {![dict exists $clay .delegate <class>]} {
          dict set clay .delegate <class> [info object class [self]]
        }
        if {[llength $args]==0} {
          return [dict get $clay .delegate]
        }
        if {[llength $args]==1} {
          set stub <[string trim [lindex $args 0] <>]>
          if {![dict exists $clay .delegate $stub]} {
            return {}
          }
          return [dict get $clay .delegate $stub]
        }
        if {([llength $args] % 2)} {
          error "Usage: delegate
    OR
    delegate stub
    OR
    delegate stub OBJECT ?stub OBJECT? ..."
        }
        foreach {stub object} $args {
          set stub <[string trim $stub <>]>
          dict set clay .delegate $stub $object
          oo::objdefine [self] forward ${stub} $object
          oo::objdefine [self] export ${stub}
        }
      }
      dump {
        # Do a full dump of clay data
        set result {}
        # Search in the in our list of classes for an answer
        foreach class $clayorder {
          ::clay::tree::dictmerge result [$class clay dump]
        }
        ::clay::tree::dictmerge result $clay
        return $result
      }
      ensemble_map {
        set path [::clay::tree::storage method_ensemble]
        if {[dict exists $claycache {*}$path]} {
          return [dict get $claycache {*}$path]
        }
        set emap {}
        foreach class $clayorder {
          if {![$class clay exists {*}$path .]} continue
          dict for {ensemble einfo} [$class clay dget {*}$path] {
            if {$ensemble eq "."} continue
            dict for {method body} $einfo {
              if {$method eq "."} continue
              dict set emap $ensemble $method class: $class
              dict set emap $ensemble $method body: $body
            }
          }
        }
        if {[dict exists $clay {*}$path]} {
          dict for {ensemble einfo} [dict get $clay {*}$path] {
            dict for {method body} $einfo {
              if {$method eq "."} continue
              dict set emap $ensemble $method class: $class
              dict set emap $ensemble $method body: $body
            }
          }
        }
        dict set claycache {*}$path $emap
        return $emap
      }
      eval {
        set script [lindex $args 0]
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
      evolve -
      initialize {
        my InitializePublic
      }
      exists {
        # Leaf searches return one data field at a time
        # Search in our local dict
        set path [::clay::tree::storage $args]
        if {[dict exists $clay {*}$path]} {
          return 1
        }
        # Search in our local cache
        if {[dict exists $claycache {*}$path]} {
          return 2
        }
        set count 2
        # Search in the in our list of classes for an answer
        foreach class $clayorder {
          incr count
          if {[$class clay exists {*}$path]} {
            return $count
          }
        }
        return 0
      }
      flush {
        set claycache {}
        set clayorder [::clay::ancestors [info object class [self]] {*}[lreverse [info object mixins [self]]]]
      }
      forward {
        oo::objdefine [self] forward {*}$args
      }
      dget {
        set path [::clay::tree::storage $args]
        if {[llength $path]==0} {
          # Do a full dump of clay data
          set result {}
          # Search in the in our list of classes for an answer
          foreach class $clayorder {
            ::clay::tree::dictmerge result [$class clay dump]
          }
          ::clay::tree::dictmerge result $clay
          return $result
        }
        if {[dict exists $clay {*}$path] && ![dict exists $clay {*}$path .]} {
          # Path is a leaf
          return [dict get $clay {*}$path]
        }
        # Search in our local cache
        if {[my clay search $path value isleaf]} {
          return $value
        }

        set found 0
        set branch [dict exists $clay {*}$path .]
        foreach class $clayorder {
          if {[$class clay exists {*}$path .]} {
            set found 1
            break
          }
          if {!$branch && [$class clay exists {*}$path]} {
            set result [$class clay dget {*}$path]
            my clay cache $path $result
            return $result
          }
        }
        # Path is a branch
        set result [dict getnull $clay {*}$path]
        foreach class $clayorder {
          if {![$class clay exists {*}$path .]} continue
          ::clay::tree::dictmerge result [$class clay dget {*}$path]
        }
        #if {[dict exists $clay {*}$path .]} {
        #  ::clay::tree::dictmerge result
        #}
        my clay cache $path $result
        return $result
      }
      getnull -
      get {
        set path [::clay::tree::storage $args]
        if {[llength $path]==0} {
          # Do a full dump of clay data
          set result {}
          # Search in the in our list of classes for an answer
          foreach class $clayorder {
            ::clay::tree::dictmerge result [$class clay dump]
          }
          ::clay::tree::dictmerge result $clay
          return [::clay::tree::sanitize $result]
        }
        if {[dict exists $clay {*}$path] && ![dict exists $clay {*}$path .]} {
          # Path is a leaf
          return [dict get $clay {*}$path]
        }
        # Search in our local cache
        if {[my clay search $path value isleaf]} {
          if {!$isleaf} {
            return [clay::tree::sanitize $value]
          } else {
            return $value
          }
        }
        set found 0
        set branch [dict exists $clay {*}$path .]
        foreach class $clayorder {
          if {[$class clay exists {*}$path .]} {
            set found 1
            break
          }
          if {!$branch && [$class clay exists {*}$path]} {
            set result [$class clay dget {*}$path]
            my clay cache $path $result
            return $result
          }
        }
        # Path is a branch
        set result [dict getnull $clay {*}$path]
        #foreach class [lreverse $clayorder] {
        #  if {![$class clay exists {*}$path .]} continue
        #  ::clay::tree::dictmerge result [$class clay dget {*}$path]
        #}
        foreach class $clayorder {
          if {![$class clay exists {*}$path .]} continue
          ::clay::tree::dictmerge result [$class clay dget {*}$path]
        }
        #if {[dict exists $clay {*}$path .]} {
        #  ::clay::tree::dictmerge result [dict get $clay {*}$path]
        #}
        my clay cache $path $result
        return [clay::tree::sanitize $result]
      }
      leaf {
        # Leaf searches return one data field at a time
        # Search in our local dict
        set path [::clay::tree::storage $args]
        if {[dict exists $clay {*}$path .]} {
          return [clay::tree::sanitize [dict get $clay {*}$path]]
        }
        if {[dict exists $clay {*}$path]} {
          return [dict get $clay {*}$path]
        }
        # Search in our local cache
        if {[my clay search $path value isleaf]} {
          if {!$isleaf} {
            return [clay::tree::sanitize $value]
          } else {
            return $value
          }
        }
        # Search in the in our list of classes for an answer
        foreach class $clayorder {
          if {[$class clay exists {*}$path]} {
            set value [$class clay get {*}$path]
            my clay cache $path $value
            return $value
          }
        }
      }
      merge {
        foreach arg $args {
          ::clay::tree::dictmerge clay {*}$arg
        }
      }
      mixin {
        ###
        # Mix in the class
        ###
        my clay flush
        set prior  [info object mixins [self]]
        set newmixin {}
        foreach item $args {
          lappend newmixin ::[string trimleft $item :]
        }
        set newmap $args
        foreach class $prior {
          if {$class ni $newmixin} {
            set script [$class clay search mixin/ unmap-script]
            if {[string length $script]} {
              if {[catch $script err errdat]} {
                puts stderr "[self] MIXIN ERROR POPPING $class:\n[dict get $errdat -errorinfo]"
              }
            }
          }
        }
        ::oo::objdefine [self] mixin {*}$args
        ###
        # Build a compsite map of all ensembles defined by the object's current
        # class as well as all of the classes being mixed in
        ###
        my InitializePublic
        foreach class $newmixin {
          if {$class ni $prior} {
            set script [$class clay search mixin/ map-script]
            if {[string length $script]} {
              if {[catch $script err errdat]} {
                puts stderr "[self] MIXIN ERROR PUSHING $class:\n[dict get $errdat -errorinfo]"
              }
            }
          }
        }
        foreach class $newmixin {
          set script [$class clay search mixin/ react-script]
          if {[string length $script]} {
            if {[catch $script err errdat]} {
              puts stderr "[self] MIXIN ERROR PEEKING $class:\n[dict get $errdat -errorinfo]"
            }
            break
          }
        }
      }
      mixinmap {
        if {![dict exists $clay .mixin]} {
          dict set clay .mixin {}
        }
        if {[llength $args]==0} {
          return [dict get $clay .mixin]
        } elseif {[llength $args]==1} {
          return [dict getnull $clay .mixin [lindex $args 0]]
        } else {
          dict for {slot classes} $args {
            dict set clay .mixin $slot $classes
          }
          set classlist {}
          dict for {item class} [dict get $clay .mixin] {
            if {$class ne {}} {
              lappend classlist $class
            }
          }
          my clay mixin {*}[lreverse $classlist]
        }
      }
      provenance {
        if {[dict exists $clay {*}$args]} {
          return self
        }
        foreach class $clayorder {
          if {[$class clay exists {*}$args]} {
            return $class
          }
        }
        return {}
      }
      refcount {
        my variable refcount
        if {![info exists refcount]} {
          return 0
        }
        return $refcount
      }
      refcount_incr {
        my variable refcount
        incr refcount
      }
      refcount_decr {
        my variable refcount
        incr refcount -1
        if {$refcount <= 0} {
          ::clay::object_destroy [self]
        }
      }
      replace {
        set clay [lindex $args 0]
      }
      search {
        set path [lindex $args 0]
        upvar 1 [lindex $args 1] value [lindex $args 2] isleaf
        set isleaf [expr {![dict exists $claycache $path .]}]
        if {[dict exists $claycache $path]} {
          set value [dict get $claycache $path]
          return 1
        }
        return 0
      }
      source {
        source [lindex $args 0]
      }
      set {
        #puts [list [self] clay SET {*}$args]
        ::clay::tree::dictset clay {*}$args
      }
      default {
        dict $submethod clay {*}$args
      }
    }
  }

  ###
  # Instantiate variables. Called on object creation and during clay mixin.
  ###
  method InitializePublic {} {
    my variable clayorder clay claycache config option_canonical clay_busy
    if {[info exists clay_busy] && $clay_busy} {
      # Avoid repeated calls to InitializePublic if we know that someone is
      # going to invoke it at the end of whatever process is going on
      return
    }
    set claycache {}
    set clayorder [::clay::ancestors [info object class [self]] {*}[lreverse [info object mixins [self]]]]
    if {![info exists clay]} {
      set clay {}
    }
    if {![info exists config]} {
      set config {}
    }
    dict for {var value} [my clay get variable] {
      if { $var in {. clay} } continue
      set var [string trim $var :/]
      my variable $var
      if {![info exists $var]} {
        if {$::clay::trace>2} {puts [list initialize variable $var $value]}
        set $var $value
      }
    }
    dict for {var value} [my clay get dict/] {
      if { $var in {. clay} } continue
      set var [string trim $var :/]
      my variable $var
      if {![info exists $var]} {
        set $var {}
      }
      foreach {f v} $value {
        if {$f eq "."} continue
        if {![dict exists ${var} $f]} {
          if {$::clay::trace>2} {puts [list initialize dict $var $f $v]}
          dict set ${var} $f $v
        }
      }
    }
    foreach {var value} [my clay get array/] {
      if { $var in {. clay} } continue
      set var [string trim $var :/]
      if { $var eq {clay} } continue
      my variable $var
      if {![info exists $var]} { array set $var {} }
      foreach {f v} $value {
        if {![array exists ${var}($f)]} {
          if {$f eq "."} continue
          if {$::clay::trace>2} {puts [list initialize array $var\($f\) $v]}
          set ${var}($f) $v
        }
      }
    }
    foreach {field info} [my clay get option/] {
      if { $field in {. clay} } continue
      set field [string trim $field -/:]
      foreach alias [dict getnull $info aliases] {
        set option_canonical($alias) $field
      }
      if {[dict exists $config $field]} continue
      set getcmd [dict getnull $info default-command]
      if {$getcmd ne {}} {
        set value [{*}[string map [list %field% $field %self% [namespace which my]] $getcmd]]
      } else {
        set value [dict getnull $info default]
      }
      dict set config $field $value
      set setcmd [dict getnull $info set-command]
      if {$setcmd ne {}} {
        {*}[string map [list %field% [list $field] %value% [list $value] %self% [namespace which my]] $setcmd]
      }
    }

    foreach {ensemble einfo} [my clay ensemble_map] {
      #if {[dict exists $einfo _body]} continue
      if {$ensemble eq "."} continue
      set body [::clay::ensemble_methodbody $ensemble $einfo]
      if {$::clay::trace>2} {
        set rawbody $body
        set body {puts [list [self] <object> [self method]]}
        append body \n $rawbody
      }
      oo::objdefine [self] method $ensemble {{method default} args} $body
    }
  }
}

::clay::object clay branch array
::clay::object clay branch mixin
::clay::object clay branch option
::clay::object clay branch dict clay
::clay::object clay set variable DestroyEvent 0


