###
# A build deliverable object. Normally an object file, header, or tcl script
# which must be compiled or generated in some way
###
::clay::define ::practcl::make_obj {
  superclass ::practcl::metaclass

  constructor {module_object name info {action_body {}}} {
    my variable define triggered domake
    set triggered 0
    set domake 0
    set define(name) $name
    set define(action) {}
    array set define $info
    my select
    my initialize
    foreach {stub obj} [$module_object child organs] {
      my graft $stub $obj
    }
    if {$action_body ne {}} {
      set define(action) $action_body
    }
  }

  method do {} {
    my variable domake
    return $domake
  }

  method check {} {
    my variable needs_make domake
    if {$domake} {
      return 1
    }
    if {[info exists needs_make]} {
      return $needs_make
    }
    set make_objects [my <module> make objects]
    set needs_make 0
    foreach item [my define get depends] {
      if {![dict exists $make_objects $item]} continue
      set depobj [dict get $make_objects $item]
      if {$depobj eq [self]} {
        puts "WARNING [self] depends on itself"
        continue
      }
      if {[$depobj check]} {
        set needs_make 1
      }
    }
    if {!$needs_make} {
      foreach filename [my output] {
        if {$filename ne {} && ![file exists $filename]} {
          set needs_make 1
        }
      }
    }
    return $needs_make
  }

  method output {} {
    set result {}
    set filename [my define get filename]
    if {$filename ne {}} {
      lappend result $filename
    }
    foreach filename [my define get files] {
      if {$filename ne {}} {
        lappend result $filename
      }
    }
    return $result
  }

  method reset {} {
    my variable triggered domake needs_make
    set triggerd 0
    set domake 0
    set needs_make 0
  }

  method triggers {} {
    my variable triggered domake define
    if {$triggered} {
      return $domake
    }
    set triggered 1
    set make_objects [my <module> make objects]

    foreach item [my define get depends] {
      if {![dict exists $make_objects $item]} continue
      set depobj [dict get $make_objects $item]
      if {$depobj eq [self]} {
        puts "WARNING [self] triggers itself"
        continue
      } else {
        set r [$depobj check]
        if {$r} {
          $depobj triggers
        }
      }
    }
    set domake 1
    my <module> make trigger {*}[my define get triggers]
  }
}
