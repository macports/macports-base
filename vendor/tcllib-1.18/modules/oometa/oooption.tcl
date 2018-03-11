###
# Option handling for TclOO
###
package require oo::meta 0.4

proc ::oo::define::option {field argdict} {
  set class [lindex [::info level -1] 1]
  foreach {prop value} $argdict {
    ::oo::meta::info $class set option $field [string trim $prop :]: $value
  }
}

oo::define oo::object {
  
  ###
  # topic: 3c4893b65a1c79b2549b9ee88f23c9e3
  # description:
  #    Provide a default value for all options and
  #    publically declared variables, and locks the
  #    pipeline mutex to prevent signal processing
  #    while the contructor is still running.
  #    Note, by default an odie object will ignore
  #    signals until a later call to <i>my lock remove pipeline</i>
  ###
  method _staticInit {} {
    my variable meta
    if {![info exists meta]} {
      set meta {}
    }
    set dat [my meta getnull option]
    foreach {var info} $dat {
      if {[dict exists $info set-command:]} {
        if {[catch {my cget $var} value]} {
          dict set meta $var [my cget $var default:]
        } else {
          if { $value eq {} } {
            dict set meta $var [my cget $var default:]
          }
        }
      }
      if {![dict exists $meta $var]} {
        dict set meta $var [my cget $var default:]
      }
    }
    foreach {var info} [my meta getnull variable] {
      if { $var eq "meta" } continue
      my variable $var
      if {![info exists $var]} {
        if {[dict exists $info default:]} {
          set $var [dict get $info default:]
        } else {
          set $var {}
        }
      }
    }
    foreach {var info} [my meta getnull array] {
      if { $var eq "meta" } continue
      my variable $var
      if {![info exists $var]} {
        if {[dict exists $info default:]} {
          array set $var [dict get $info default:]
        } else {
          array set $var {}
        }
      }
    }
  }

  ###
  # topic: 86a1b968cea8d439df87585afdbdaadb
  ###
  method cget {field {default {}}} {
    my variable _config
    set field [string trimleft $field -]
    set dat [my meta getnull option]
  
    if {[my meta is true const options_strict:] && ![dict exists $dat $field]} {
      error "Invalid option -$field. Valid: [dict keys $dat]"
    }
    set info [dict getnull $dat $field]    
    if {$default eq "default"} {
      set getcmd [dict getnull $info default-command:]
      if {$getcmd ne {}} {
        return [{*}[string map [list %field% $field %self% [namespace which my]] $getcmd]]
      } else {
        return [dict getnull $info default:]
      }
    }
    if {[dict exists $dat $field]} {
      set getcmd [dict getnull $info get-command:]
      if {$getcmd ne {}} {
        return [{*}[string map [list %field% $field %self% [namespace which my]] $getcmd]]
      }
      if {![info exists _config($field)]} {
        set getcmd [dict getnull $info default-command:]
        if {$getcmd ne {}} {
          set _config($field) [{*}[string map [list %field% $field %self% [namespace which my]] $getcmd]]
        } else {
          set _config($field) [dict getnull $info default:]
        }
      }
      if {$default eq "varname"} {
        set varname [my varname _config]
        return "${varname}($field)"
      }
      return $_config($field)
    }
    return [my meta cget $field]
  }
  
  ###
  # topic: 73e2566466b836cc4535f1a437c391b0
  ###
  method configure args {
    # Will be removed at the end of "configurelist_triggers"
    set dictargs [::oo::meta::args_to_options {*}$args]
    if {[llength $dictargs] == 1} {
      return [my cget [lindex $dictargs 0]]
    }
    my configurelist $dictargs
    my configurelist_triggers $dictargs
  }

  ###
  # topic: dc9fba12ec23a3ad000c66aea17135a5
  ###
  method configurelist dictargs {
    my variable _config
    set dat [my meta getnull option]
    if {[my meta is true const options_strict:]} {
      foreach {field val} $dictargs {
        if {![dict exists $dat $field]} {
          error "Invalid option $field. Valid: [dict keys $dat]"
        }
      }
    }
    ###
    # Validate all inputs
    ###
    foreach {field val} $dictargs {
      set script [dict getnull $dat $field validate-command:]
      if {$script ne {}} {
        {*}[string map [list %field% [list $field] %value% [list $val] %self% [namespace which my]] $script]
      }
    }
    ###
    # Apply all inputs with special rules
    ###
    array set _config $dictargs
  }

  ###
  # topic: 543c936485189593f0b9ed79b5d5f2c0
  ###
  method configurelist_triggers dictargs {
    set dat [my meta getnull option]
    ###
    # Apply all inputs with special rules
    ###
    foreach {field val} $dictargs {
      set script [dict getnull $dat $field set-command:]
      if {$script ne {}} {
        {*}[string map [list %field% [list $field] %value% [list $val] %self% [namespace which my]] $script]
      }
    }
  }
}
package provide oo::option 0.3