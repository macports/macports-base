::namespace eval ::tool::signal {}
::namespace eval ::tao {}

# Provide a backward compatible hook
proc ::tool::main {} {
  ::cron::main
}

proc ::tool::do_events {} {
  ::cron::do_events
}

proc ::tao::do_events {} {
  ::cron::do_events
}

proc ::tao::main {} {
  ::cron::main
}


package provide tool::pipeline 0.1

