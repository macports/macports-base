###
# This package enhances the stock dict implementation with some
# creature comforts
###
if {[info commands ::ladd] eq {}} {
  proc ladd {varname args} {
    upvar 1 $varname var
    if ![info exists var] {
        set var {}
    }
    foreach item $args {
      if {$item in $var} continue
      lappend var $item
    }
    return $var
  }
}

if {[info command ::ldelete] eq {}} {
  proc ::ldelete {varname args} {
    upvar 1 $varname var
    if ![info exists var] {
        return
    }
    foreach item [lsort -unique $args] {
      while {[set i [lsearch $var $item]]>=0} {
        set var [lreplace $var $i $i]
      }
    }
    return $var
  }  
}

if {[::info commands ::tcl::dict::getnull] eq {}} {
  proc ::tcl::dict::getnull {dictionary args} {
    if {[exists $dictionary {*}$args]} {
      get $dictionary {*}$args
    }
  }
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] getnull ::tcl::dict::getnull]
}
if {[::info commands ::tcl::dict::print] eq {}} {
  ###
  # Test if element is a dict
  ###
  proc ::tcl::dict::_putb {buffervar indent field value} {
    ::upvar 1 $buffervar buffer
    ::append buffer \n [::string repeat " " $indent] [::list $field] " "
    if {[string index $field end] eq "/"} {
      ::incr indent 2
      ::append buffer "\{"
      foreach item $value {
        if [catch {
        if {![is_dict $item]} {
          ::append buffer \n [::string repeat " " $indent] [list $item]
        } else {
          ::append buffer \n "[::string repeat " " $indent]\{"
          ::incr indent 2
          foreach {sf sv} $item {
            _putb buffer $indent $sf $sv
          }
          ::incr indent -2
          ::append buffer \n "[::string repeat " " $indent]\}"          
        }
        } err] {
          puts [list FAILED $indent $field $item]
          puts $err
          puts "$::errorInfo"
        }
      }
      ::incr indent -2
      ::append buffer \n [::string repeat " " $indent] "\}"
    } elseif {[string index $field end] eq ":" || ![is_dict $value]} {
      ::append buffer [::list $value]
    } else {
      ::incr indent 2
      ::append buffer "\{"
      foreach {f v} $value {
        _putb buffer $indent $f $v
      }
      ::incr indent -2
      ::append buffer \n [::string repeat " " $indent] "\}"
    }
  }
  proc ::tcl::dict::print dict {
    ::set buffer {}
    ::foreach {field value} $dict {
      _putb buffer 0 $field $value
    }
    return $buffer
  }
  
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] print ::tcl::dict::print]
}
if {[::info commands ::tcl::dict::is_dict] eq {}} {
  ###
  # Test if element is a dict
  ###
  proc ::tcl::dict::is_dict { d } {
    # is it a dict, or can it be treated like one?
    if {[catch {dict size $d} err]} {
      #::set ::errorInfo {}
      return 0
    }
    return 1
  }
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] is_dict ::tcl::dict::is_dict]
}
if {[::info commands ::tcl::dict::rmerge] eq {}} {
  ###
  # title: A recursive form of dict merge
  # description:
  # A routine to recursively dig through dicts and merge
  # adapted from http://stevehavelka.com/tcl-dict-operation-nested-merge/
  ###
  proc ::tcl::dict::rmerge {a args} {
    ::set result $a
    # Merge b into a, and handle nested dicts appropriately
    ::foreach b $args {
      for { k v } $b {
        if {[string index $k end] eq ":"} {
          # Element names that end in ":" are assumed to be literals
          set result $k $v
        } elseif { [dict exists $result $k] } {
          # key exists in a and b?  let's see if both values are dicts
          # both are dicts, so merge the dicts
          if { [is_dict [get $result $k]] && [is_dict $v] } {
            set result $k [rmerge [get $result $k] $v]
          } else {  
            set result $k $v
          }
        } else {
          set result $k $v
        }
      }
    }
    return $result
  }
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] rmerge ::tcl::dict::rmerge]
}

if {[::info commands ::tcl::dict::isnull] eq {}} {
  proc ::tcl::dict::isnull {dictionary args} {
    if {![exists $dictionary {*}$args]} {return 1}
    return [expr {[get $dictionary {*}$args] in {{} NULL null}}]
  }
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] isnull ::tcl::dict::isnull]
}

package provide dicttool 1.1
