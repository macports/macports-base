###
# Tool Datatypes
###

::tool::define ::tool::datatype::string {
  method value::get value {
    return $value
  }

  method value::put value {
    return $value
  }
}

::tool::define ::tool::datatype::boolean {
  superclass ::tool::datatype::string

  ###
  # topic: efc05671edb5dba64be56c1c3d102e6f9cdf3287
  ###
  method value::get rawvalue {
    return [string is true -strict $rawvalue]
  }

  ###
  # topic: 1c75cc4d57d468fc594ecad49fc20a954158c18f
  ###
  method value::put rawvalue {
    return [string is true -strict $rawvalue]
  }
}

::tool::define ::tool::datatype::integer {
  superclass ::tool::datatype::string

  option format {default %d}
  
  ###
  # topic: efc05671edb5dba64be56c1c3d102e6f9cdf3287
  ###
  method value::get rawvalue {
    if { $rawvalue eq {} } {
      return {}
    }
    set format [my cget format]
    set c [scan $rawvalue $format newvalue]
    if {![info exists newvalue]} {
      error "Bad value $rawvalue"
    }
    return $newvalue
  }

  ###
  # topic: 1c75cc4d57d468fc594ecad49fc20a954158c18f
  ###
  method value::put rawvalue {
    if { $rawvalue eq {} } {
      return {}
    }
    set format [my cget format]
    set c [scan $rawvalue $format newvalue]
    if {![info exists newvalue]} {
      error "Bad value $rawvalue"
    }
    return $newvalue
  }
}

::tool::define ::tool::datatype::real {
  superclass ::tool::datatype::string

  option format {default %g}
  
  ###
  # topic: c32d30915be323dca1264c441d06a16ea6b62b68
  ###
  method value::get rawvalue {
    if { $rawvalue eq {} } {
      return {}
    }
    set format [my cget format]
    set c [scan $rawvalue $format newvalue]
    if {![info exists newvalue]} {
      error "Bad value $rawvalue"
    }
    return $newvalue
  }

  ###
  # topic: 27f11c0626223864f2602553471cc11d563b2eec
  ###
  method value::put rawvalue {
    if { $rawvalue eq {} } {
      return {}
    }
    set format [my cget format]
    set c [scan $rawvalue $format newvalue]
    if {![info exists newvalue]} {
      error "Bad value $rawvalue"
    }
    return $newvalue
  }
}

::tool::define ::tool::datatype::unixtime {
  superclass ::tool::datatype::string

  option gmt {widget boolean default 0}

  ###
  # topic: ba50b03e339a6f09b429871fc6a2ba3c54516aa2
  # title: Convert an internally encoded value to its externally encoded value
  # description:
  #    Used for widgets that display human-readable values. For example
  #    converting the human readable [emph {c131 - 01-141-L - Passage}]
  #    into an integer ([emph 131]) for encoding in a database field.
  ###
  method value::get value {
    if { $value eq {} } {
      return {}
    }
    set outtime [clock scan $value -gmt [my cget gmt]]
    return $outtime
  }

  ###
  # topic: ef8b8c1dbd3388c95a14de3e551e7c4a43ba7bbf
  # title: Convert an externally encoded value to its internally encoded value
  # description:
  #    Used for widgets that display human-readable values. For example
  #    converting an integer in the database ([emph 131]) to something
  #    mor intelligable to the user [emph {c131 - 01-141-L - Passage}]
  ###
  method value::put value {
    if { $value eq {} } {
      return {}
    }
    set realvalue $value
    return [clock format $realvalue -gmt [my cget gmt]]
  }
}

::tool::define ::tool::datatype::datetime {
  superclass ::tool::datatype::string

  option display_format {default {}}  
  option output_format  {default {}}
  option gmt {widget boolean default 0}

  ###
  # topic: 1e0804037f9558efac701766446ed26bb67b318f
  # title: Convert an internally encoded value to its externally encoded value
  # description:
  #    Used for widgets that display human-readable values. For example
  #    converting the human readable [emph {c131 - 01-141-L - Passage}]
  #    into an integer ([emph 131]) for encoding in a database field.
  ###
  method value::get value {
    if { $value eq {} } {
      return {}
    }
    set format [my cget display_format]
    if { $format ni { {} "unixtime" } } {
      set outtime [clock scan $value -format $format -gmt [my cget gmt]]
    } else {
      set outtime [clock scan $value]
    }
    set format [my cget output_format]
    if { $format ni { {} "unixtime" } } {
      return [clock format $outtime -format $format -gmt [my cget gmt]]
    } else {
      return $outtime
    }
  }

  ###
  # topic: fee644b1fa3dc4796d55a0429e0418171854b4d4
  # title: Convert an externally encoded value to its internally encoded value
  # description:
  #    Used for widgets that display human-readable values. For example
  #    converting an integer in the database ([emph 131]) to something
  #    mor intelligable to the user [emph {c131 - 01-141-L - Passage}]
  ###
  method value::put value {
    if { $value eq {} } {
      return {}
    }
    set format [my cget output_format]
    if { $format ni { {} "unixtime" } } {
      set realvalue [clock scan $value -format $format -gmt [my cget gmt]]
    } else {
      set realvalue $value
    }
    set format [my cget display_format]
    if { $format ni { {} "unixtime" } } {
      return [clock format $realvalue -format $format -gmt [my cget gmt]]
    } else {
      return [clock format $realvalue -gmt [my cget gmt]]
    }
  }
}

::tool::define ::tool::datatype::select {
  superclass ::tool::datatype::string

  option values {}
  
  option state {
    widget select
    values {normal readonly disabled}
    default readonly
  }

  ###
  # topic: 3339ac6fe57b0b23add1e8fb64336c567a7e3694
  ###
  method CalculateValues {} {
    return [my GetConfigValueList]
  }

  ###
  # topic: 6ee18ff095fc0ff746b0dcf0876daa6150adf42c
  ###
  method CalculateValueWidth values {
    set w 0
    set n 0
    foreach v $values {
      incr n
      set l [string length $v]
      incr bins($l)
      if {$l > $w} {
        set w $l
      }
    }
    if { $w > 30} {
      set w 30
    }
    return $w
  }

  ###
  # topic: 14e9b60d5636bca086ca44a90cf15dbefeaa1340
  ###
  method GetConfigValueList {} {
    my variable config
    set values {}
    if {[dict exists $config options_command]} {
      return [eval [dict get $config options_command]]
    }
    if {[dict exists $config values]} {
      return [dict get $config values]
    }
    if {[dict exists $config options]} {
      return [dict get $config options]
    }
    return {}
  }
}

::tool::define ::tool::datatype::select_keyvalue {
  superclass ::tool::datatype::select

  option state {
    widget select
    values {normal readonly disabled}
    default readonly
  }
  option accept_number {
    widget boolean
    default 1
  }

  ###
  # topic: 77bd2ab8551c40ecee13ffc38d6f9af819680de9
  ###
  method CalculateValues {} {
    set values [my GetConfigValueList]
    foreach {key value} $values {
      lappend result $key
    }
    return $result
  }

  ###
  # topic: 3e8bc6c0b4bdafca5b43b927e2c874432239fc4f
  ###
  method value::get rawvalue {
    set values [my GetConfigValueList]
    foreach {var val} $values {
      if {$rawvalue eq $val} {
        return $val
      }
      if {$rawvalue eq $var} {
        return $val
      }
    }
    return $rawvalue
  }

  ###
  # topic: 6a6e2567e1fa5cb769dc67cc402ff2a08cb55ecd
  ###
  method value::put rawvalue {
    set values [my GetConfigValueList]
    foreach {var val} $values {
      if {$rawvalue eq $val} {
        return $var
      }
      if {$rawvalue eq $var} {
        return $var
      }
    }
    if {[my cget accept_number]} {
      if {[string is double $rawvalue]} {
        return $rawvalue
      }
    }
    error "Invalid Value \"$rawvalue\". Valid: [join [dict keys $values] ,]"
  }
}

::tool::define ::tool::datatype::enumerated {
  superclass ::tool::datatype::select

  option state {
    widget select
    values {normal readonly disabled}
    default readonly
  }
  option enum {
    default {}
  }

  ###
  # topic: 5fa7461dcfec89fd52456af62f04aa28696d5974
  ###
  method CalculateValues {} {
    set values {}
    foreach {id code comment} [my GetConfigValueList] {
      lappend values "$id - $code"
    }
    return $values
  }

  ###
  # topic: b47b26deb7db53bbce74a78401302d103d805748
  ###
  method value::get value {
    set value [lindex $value 0]
    foreach {id code comment} [my GetConfigValueList] {
      if {$value == $id } {
        return $id
      }
    }
    return {}
  }

  ###
  # topic: 90776f5900f1bc28fbdf47c895e2d052e3fbaafd
  ###
  method value::put value {
    foreach {id code comment} [my GetConfigValueList] {
      if { [lindex $value 0] == $id } {
        return "$id - $code - $comment"
      }
    }
    return {}
  }
}

::tool::define ::tool::datatype::vector {
  superclass ::tool::datatype::string
  
  property vector_fields {
    x {format {%0.6g} widget entry width 10}
    y {format {%0.6g} widget entry width 10}
    z {format {%0.6g} widget entry width 10}
  }

  method Vector_Fields {} {
    return [my property vector_fields]
  }
  
  ###
  # topic: 6d9aec52f3c16e5248eee30bfacb9045917273aa
  ###
  method value::get newvalue {
    set result {}
    array set content $newvalue
    foreach {vfield info} [my Vector_Fields]  {
      set format [if_null [dict getnull $info format] %s]
      set newvalue [format $format $content($vfield)]
      lappend result $newvalue
    }
    return $result
  }

  ###
  # topic: 96480da6e97f6cfe3574475a7c3b132b39a9003c
  ###
  method value::put inputvalue {
    set idx -1
    foreach {vfield info} [my Vector_Fields] {
      incr idx
      set format [if_null [dict getnull $info format] %s]
      set value [lindex $inputvalue $idx]
      if {[dict exists $info default]} {
        if {$value eq {}} {
          set value [dict get $info default]
        }
      }
      if {$value eq {}} {
        set local_array($vfield) $value
      } elseif { $format in {"%d" int integer} } {
        if [catch {expr {int($value)}} nvalue] {
          puts "Err: $format $vfield. Raw: $value. Err: $nvalue"
          dict set result $vfield $value
        } else {
          dict set result $vfield $nvalue
        }
      } else {
        if [catch {format $format $value} nvalue] {
          puts "Err: $vfield. Raw: $value. Err: $nvalue"
          dict set result $vfield $value
        } else {
          dict set result $vfield $nvalue
        }
      }
    }
    return $result
  }
}

package provide tool::datatype 0.1