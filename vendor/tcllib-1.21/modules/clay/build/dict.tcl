###
# If the path (given by the list of elements) exists, return that value.
# Otherwise return an empty string. Designed to replace [example {
# if {[dict exists $dictionary {*}$args]} {
#   return [dict get $dictionary {*}$args]
# } else {
#   return {}
# }
# }]
# example:
# set value [dict getnull $arglist $option]
# arglist:
# dictionary {mandatory 1 positional 1}
# element {mandatory 0 positional 1 repeating 1}
###
::clay::PROC ::tcl::dict::getnull {dictionary args} {
  if {[exists $dictionary {*}$args]} {
    get $dictionary {*}$args
  }
} {
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] getnull ::tcl::dict::getnull]
}


###
# Test if value is a dict.
# [para]
# This command is added to the [fun dict] ensemble as [fun {dict is_dict}]
###
::clay::PROC ::tcl::dict::is_dict { d } {
  # is it a dict, or can it be treated like one?
  if {[catch {dict size $d} err]} {
    #::set ::errorInfo {}
    return 0
  }
  return 1
} {
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] is_dict ::tcl::dict::is_dict]
}

###
# A routine to recursively dig through dicts and merge
# adapted from http://stevehavelka.com/tcl-dict-operation-nested-merge/
###
::clay::PROC ::tcl::dict::rmerge {args} {
  ::set result [dict create . {}]
  # Merge b into a, and handle nested dicts appropriately
  ::foreach b $args {
    for { k v } $b {
      ::set field [string trim $k :/]
      if {![::clay::tree::is_branch $b $k]} {
        # Element names that end in ":" are assumed to be literals
        set result $k $v
      } elseif { [exists $result $k] } {
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
} {
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] rmerge ::tcl::dict::rmerge]
}

###
# Return true if the element [variable path] with the value [variable dict]
# is a dict. [variable path] is given as a list to descend into sub-dicts of
# the current dict.
# The rules are as follows:
# [list_begin enumerated]
# [enum]
# If the last character of the last element of [variable path] is a colon (:)
# return false
# [enum]
# If the last character of the last element of [variable path] is a slash (/)
# return true
# [enum]
# If a sub-element if [variable path] named [const .info] is present return true
# [list_end]
# [para]
# [para]
# This command is added to the [fun dict] ensemble as [fun {clay::tree::is_branch}]
# example:
# > set mydict {sub/ {sub/ {field {A block of text}}}
# > clay::tree::is_branch $mydict sub/
# 1
# > clay::tree::is_branch $mydict {sub/ sub/}
# 1
# > clay::tree::is_branch $mydict {sub/ sub/ field}
# 0
###
::clay::PROC ::clay::tree::is_branch { dict path } {
  set field [lindex $path end]
  if {[string index $field end] eq ":"} {
    return 0
  }
  if {[string index $field 0] eq "."} {
    return 0
  }
  if {[string index $field end] eq "/"} {
    return 1
  }
  return [dict exists $dict {*}$path .]
}

###
# Output a dictionary as an indented stream of
# data suitable for output to the screen. The system uses
# the rules for [fun {clay::tree::is_branch}] to determine if
# an value in a dictionary is a leaf or a branch.
# example:
# > set mydict {sub/ {sub/ {field {A block of text}}}
# > clay::tree::print $mydict
# sub/ {
#   sub/ {
#     field {A block of text}
#   }
# }
###
::clay::PROC ::clay::tree::print {dict} {
  ::set result {}
  ::set level -1
  ::clay::tree::_dictputb $level result $dict
  return $result
}

###
# Helper function for ::clay::tree::print
# Formats the string representation for a dictionary element within
# a human readable stream of lines, and determines if it needs to call itself
# with further indentation to express a sub-branch
###
::clay::PROC ::clay::tree::_dictputb {level varname dict} {
  upvar 1 $varname result
  incr level
  dict for {field value} $dict {
    if {$field eq "."} continue
    if {[clay::tree::is_branch $dict $field]} {
      putb result "[string repeat "  " $level]$field \{"
      _dictputb $level result $value
      putb result "[string repeat "  " $level]\}"
    } else {
      putb result "[string repeat "  " $level][list $field $value]"
    }
  }
}

###
# Output a dictionary removing any . entries added by [fun {clay::tree::merge}]
###
proc ::clay::tree::sanitize {dict} {
  ::set result {}
  ::set level -1
  ::clay::tree::_sanitizeb {} result $dict
  return $result
}

###
# Helper function for ::clay::tree::sanitize
# Formats the string representation for a dictionary element within
# a human readable stream of lines, and determines if it needs to call itself
# with further indentation to express a sub-branch
###
proc ::clay::tree::_sanitizeb {path varname dict} {
  upvar 1 $varname result
  dict for {field value} $dict {
    if {$field eq "."} continue
    if {[clay::tree::is_branch $dict $field]} {
      _sanitizeb [list {*}$path $field] result $value
    } else {
      dict set result {*}$path $field $value
    }
  }
}

###
# Return the path as a storage path for clay::tree
# with all branch terminators removed.
# This command will also break arguments up if they
# contain /.
# example:
# > clay::tree::storage {foo bar baz bang}
# foo bar baz bang
# > clay::tree::storage {foo bar baz bang/}
# foo bar baz bang
# > clay::tree::storage {foo bar baz bang:}
# foo bar baz bang:
# > clay::tree::storage {foo/bar/baz bang:}
# foo bar baz bang:
# > clay::tree::storage {foo/bar/baz/bang}
# foo bar baz bang
###
proc ::clay::tree::storage {rawpath} {
  set isleafvar 0
  set path {}
  set tail [string index $rawpath end]
  foreach element $rawpath {
    set items [split [string trim $element /] /]
    foreach item $items {
      if {$item eq {}} continue
      lappend path $item
    }
  }
  return $path
}

###
# Set an element with a recursive dictionary,
# marking all branches on the way down to the
# final element.
# If the value does not exists in the nested dictionary
# it is added as a leaf. If the value already exists as a branch
# the value given is merged if the value is a valid dict. If the
# incoming value is not a valid dict, the value overrides the value
# stored, and the value is treated as a leaf from then on.
# example:
# > set r {}
# > ::clay::tree::dictset r option color default Green
# . {} option {. {} color {. {} default Green}}
# > ::clay::tree::dictset r option {Something not dictlike}
# . {} option {Something not dictlike}
# # Note that if the value is not a dict, and you try to force it to be
# # an error with be thrown on the merge
# > ::clay::tree::dictset r option color default Blue
# missing value to go with key
###
proc ::clay::tree::dictset {varname args} {
  upvar 1 $varname result
  if {[llength $args] < 2} {
    error "Usage: ?path...? path value"
  } elseif {[llength $args]==2} {
    set rawpath [lindex $args 0]
  } else {
    set rawpath  [lrange $args 0 end-1]
  }
  set value [lindex $args end]
  set path [storage $rawpath]
  set dot .
  set one {}
  dict set result $dot $one
  set dpath {}
  foreach item [lrange $path 0 end-1] {
    set field $item
    lappend dpath [string trim $item /]
    dict set result {*}$dpath $dot $one
  }
  set field [lindex $rawpath end]
  set ext   [string index $field end]
  if {$ext eq {:} || ![dict is_dict $value]} {
    dict set result {*}$path $value
    return
  }
  if {$ext eq {/} && ![dict exists $result {*}$path $dot]} {
    dict set result {*}$path $dot $one
  }
  if {[dict exists $result {*}$path $dot]} {
    dict set result {*}$path [::clay::tree::merge [dict get $result {*}$path] $value]
    return
  }
  dict set result {*}$path $value
}

###
# A recursive form of dict merge, intended for modifying variables in place.
# example:
# > set mydict {sub/ {sub/ {description {a block of text}}}}
# > ::clay::tree::dictmerge mydict {sub/ {sub/ {field {another block of text}}}}]
# > clay::tree::print $mydict
# sub/ {
#   sub/ {
#     description {a block of text}
#     field {another block of text}
#   }
# }
###
proc ::clay::tree::dictmerge {varname args} {
  upvar 1 $varname result
  set dot .
  set one {}
  dict set result $dot $one
  foreach dict $args {
    dict for {f v} $dict {
      set field [string trim $f /]
      set bbranch [clay::tree::is_branch $dict $f]
      if {![dict exists $result $field]} {
        dict set result $field $v
        if {$bbranch} {
          dict set result $field [clay::tree::merge $v]
        } else {
          dict set result $field $v
        }
      } elseif {[dict exists $result $field $dot]} {
        if {$bbranch} {
          dict set result $field [clay::tree::merge [dict get $result $field] $v]
        } else {
          dict set result $field $v
        }
      }
    }
  }
  return $result
}



###
# A recursive form of dict merge
# [para]
# A routine to recursively dig through dicts and merge
# adapted from http://stevehavelka.com/tcl-dict-operation-nested-merge/
# example:
# > set mydict {sub/ {sub/ {description {a block of text}}}}
# > set odict [clay::tree::merge $mydict {sub/ {sub/ {field {another block of text}}}}]
# > clay::tree::print $odict
# sub/ {
#   sub/ {
#     description {a block of text}
#     field {another block of text}
#   }
# }
###
proc ::clay::tree::merge {args} {
  ###
  # The result of a merge is always a dict with branches
  ###
  set dot .
  set one {}
  dict set result $dot $one
  set argument 0
  foreach b $args {
    # Merge b into a, and handle nested dicts appropriately
    if {![dict is_dict $b]} {
      error "Element $b is not a dictionary"
    }
    dict for { k v } $b {
      if {$k eq $dot} {
        dict set result $dot $one
        continue
      }
      set bbranch [is_branch $b $k]
      set field [string trim $k /]
      if { ![dict exists $result $field] } {
        if {$bbranch} {
          dict set result $field [merge $v]
        } else {
          dict set result $field $v
        }
      } else {
        set abranch [dict exists $result $field $dot]
        if {$abranch && $bbranch} {
          dict set result $field [merge [dict get $result $field] $v]
        } else {
          dict set result $field $v
          if {$bbranch} {
            dict set result $field $dot $one
          }
        }
      }
    }
  }
  return $result
}
###
# Returns true if the path specified by args either does not exist,
# if exists and contains an empty string or the value of NULL or null.
# [para]
# This function is added to the global dict ensemble as [fun {dict isnull}]
###
::clay::PROC ::tcl::dict::isnull {dictionary args} {
  if {![exists $dictionary {*}$args]} {return 1}
  return [expr {[get $dictionary {*}$args] in {{} NULL null}}]
} {
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] isnull ::tcl::dict::isnull]
}
