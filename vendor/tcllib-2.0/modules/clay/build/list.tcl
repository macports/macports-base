###
# Add elements to a list if that are not already present in the list.
# As a side effect, if variable [variable varname] does not exists,
# create it as an empty list.
# arglist:
# varname {positional 1 mandatory 1}
# element {positional 1 mandatory 0 repeating 1}
# example:
# ladd contents foo bar
# puts $contents
# > foo bar
# ladd contents foo bar baz bang
# puts $contents
# > foo bar baz bang
###
::clay::PROC ::clay::ladd {varname args} {
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

###
# Delete all instances of the elements given from a list contained in [variable varname].
# If the variable does exist this is a noop.
# arglist:
# varname {positional 1 mandatory 1}
# element {positional 1 mandatory 0 repeating 1}
# example:
# set contents {foo bar baz bang foo foo foo}
# ldelete contents foo
# puts $contents
# > bar baz bang
###
::clay::PROC ::clay::ldelete {varname args} {
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

###
# Return a random element from [variable list]
###
::clay::PROC ::clay::lrandom list {
  set len [llength $list]
  set idx [expr int(rand()*$len)]
  return [lindex $list $idx]
}
