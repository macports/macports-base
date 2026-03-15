###
# show_body: 1
# description:
# Trigger build targets, and recompute dependencies
###
proc ::practcl::trigger {args} {
  ::practcl::LOCAL make trigger {*}$args
  foreach {name obj} [::practcl::LOCAL make objects] {
    set ::make($name) [$obj do]
  }
}

###
# show_body: 1
# description:
# Calculate if a dependency for any of the arguments needs to
# be fulfilled or rebuilt.
proc ::practcl::depends {args} {
  ::practcl::LOCAL make depends {*}$args
}

###
# show_body: 1
# description:
# Declare a build product. This proc is just a shorthand for
# [emph {::practcl::LOCAL make task $name $info $action}]
# [para]
# Registering a build product with this command will create
# an entry in the global [variable make] array, and populate
# a value in the global [variable target] array.
###
proc ::practcl::target {name info {action {}}} {
  set obj [::practcl::LOCAL make task $name $info $action]
  set ::make($name) 0
  set filename [$obj define get filename]
  if {$filename ne {}} {
    set ::target($name) $filename
  }
}
