###
# A generic Practcl object
###
::clay::define ::practcl::object {
  superclass ::practcl::metaclass

  constructor {parent args} {
    my variable links define
    set organs [$parent child organs]
    my clay delegate {*}$organs
    array set define $organs
    array set define [$parent child define]
    array set links {}
    if {[llength $args]==1 && [file exists [lindex $args 0]]} {
      my define set filename [lindex $args 0]
      ::practcl::product select [self]
    } elseif {[llength $args] == 1} {
      set data  [uplevel 1 [list subst [lindex $args 0]]]
      array set define $data
      my select
    } else {
      array set define [uplevel 1 [list subst $args]]
      my select
    }
    my initialize

  }

  method child {method} {
    return {}
  }

  method go {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable links
    foreach {linktype objs} [array get links] {
      foreach obj $objs {
        $obj go
      }
    }
    ::practcl::debug [list /[self] [self method] [self class]]
  }
}
