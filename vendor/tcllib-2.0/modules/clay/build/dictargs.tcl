namespace eval ::dictargs {}
if {[info commands ::dictargs::parse] eq {}} {
  proc ::dictargs::parse {argdef argdict} {
    set result {}
    dict for {field info} $argdef {
      if {![string is alnum [string index $field 0]]} {
        error "$field is not a simple variable name"
      }
      upvar 1 $field _var
      set aliases {}
      if {[dict exists $argdict $field]} {
        set _var [dict get $argdict $field]
        continue
      }
      if {[dict exists $info aliases:]} {
        set found 0
        foreach {name} [dict get $info aliases:] {
          if {[dict exists $argdict $name]} {
            set _var [dict get $argdict $name]
            set found 1
            break
          }
        }
        if {$found} continue
      }
      if {[dict exists $info default:]} {
        set _var [dict get $info default:]
        continue
      }
      set mandatory 1
      if {[dict exists $info mandatory:]} {
        set mandatory [dict get $info mandatory:]
      }
      if {$mandatory} {
        error "$field is required"
      }
    }
  }
}

###
# Named Procedures as new command
###
proc ::dictargs::proc {name argspec body} {
  set result {}
  append result "::dictargs::parse \{$argspec\} \$args" \;
  append result $body
  uplevel 1 [list ::proc $name [list [list args [list dictargs $argspec]]] $result]
}

proc ::dictargs::method {name argspec body} {
  set class [lindex [::info level -1] 1]
  set result {}
  append result "::dictargs::parse \{$argspec\} \$args" \;
  append result $body
  oo::define $class method $name [list [list args [list dictargs $argspec]]] $result
}

