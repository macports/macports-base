if {[info commands ::cron::object_destroy] eq {}} {
  # Provide a noop if we aren't running with the cron scheduler
  namespace eval ::cron {}
  proc ::cron::object_destroy args {}
}
::namespace eval ::clay::event {}

###
# Process the queue of objects to be destroyed
###
proc ::clay::cleanup {} {
  if {![info exists ::clay::idle_destroy]} return
  foreach obj $::clay::idle_destroy {
    if {[info commands $obj] ne {}} {
      catch {$obj destroy}
    }
  }
  set ::clay::idle_destroy {}
}

proc ::clay::object_create {objname {class {}}} {
  #if {$::clay::trace>0} {
  #  puts [list $objname CREATE]
  #}
}

proc ::clay::object_rename {object newname} {
  if {$::clay::trace>0} {
    puts [list $object RENAME -> $newname]
  }
}

###
# Mark an objects for destruction on the next cleanup
###
proc ::clay::object_destroy args {
  if {![info exists ::clay::idle_destroy]} {
    set ::clay::idle_destroy {}
  }
  foreach objname $args {
    if {$::clay::trace>0} {
      puts [list $objname DESTROY]
    }
    ::cron::object_destroy $objname
    if {$objname in $::clay::idle_destroy} continue
    lappend ::clay::idle_destroy $objname
  }
}

###
# description: Cancel a scheduled event
###
proc ::clay::event::cancel {self {task *}} {
  variable timer_event
  variable timer_script

  foreach {id event} [array get timer_event $self:$task] {
    ::after cancel $event
    set timer_event($id) {}
    set timer_script($id) {}
  }
}

###
# description:
#    Generate an event
#    Adds a subscription mechanism for objects
#    to see who has recieved this event and prevent
#    spamming or infinite recursion
###
proc ::clay::event::generate {self event args} {
  set wholist [Notification_list $self $event]
  if {$wholist eq {}} return
  set dictargs [::oo::meta::args_to_options {*}$args]
  set info $dictargs
  set strict 0
  set debug 0
  set sender $self
  dict with dictargs {}
  dict set info id     [::clay::event::nextid]
  dict set info origin $self
  dict set info sender $sender
  dict set info rcpt   {}
  foreach who $wholist {
    catch {::clay::event::notify $who $self $event $info}
  }
}

###
# title: Return a unique event handle
###
proc ::clay::event::nextid {} {
  return "event#[format %0.8x [incr ::clay::event_count]]"
}

###
# description:
#    Called recursively to produce a list of
#    who recieves notifications
###
proc ::clay::event::Notification_list {self event {stackvar {}}} {
  set notify_list {}
  foreach {obj patternlist} [array get ::clay::object_subscribe] {
    if {$obj eq $self} continue
    if {$obj in $notify_list} continue
    set match 0
    foreach {objpat eventlist} $patternlist {
      if {![string match $objpat $self]} continue
      foreach eventpat $eventlist {
        if {![string match $eventpat $event]} continue
        set match 1
        break
      }
      if {$match} {
        break
      }
    }
    if {$match} {
      lappend notify_list $obj
    }
  }
  return $notify_list
}

###
# Final delivery to intended recipient object
###
proc ::clay::event::notify {rcpt sender event eventinfo} {
  if {[info commands $rcpt] eq {}} return
  if {$::clay::trace} {
    puts [list event notify rcpt $rcpt sender $sender event $event info $eventinfo]
  }
  $rcpt notify $event $sender $eventinfo
}

###
# Evaluate an event script in the global namespace
###
proc ::clay::event::process {self handle script} {
  variable timer_event
  variable timer_script

  array unset timer_event $self:$handle
  array unset timer_script $self:$handle

  set err [catch {uplevel #0 $script} result errdat]
  if $err {
    puts "BGError: $self $handle $script
ERR: $result
[dict get $errdat -errorinfo]
***"
  }
}

###
# description: Schedule an event to occur later
###
proc ::clay::event::schedule {self handle interval script} {
  variable timer_event
  variable timer_script
  if {$::clay::trace} {
    puts [list $self schedule $handle $interval]
  }
  if {[info exists timer_event($self:$handle)]} {
    if {$script eq $timer_script($self:$handle)} {
      return
    }
    ::after cancel $timer_event($self:$handle)
  }
  set timer_script($self:$handle) $script
  set timer_event($self:$handle) [::after $interval [list ::clay::event::process $self $handle $script]]
}

###
# Subscribe an object to an event pattern
###
proc ::clay::event::subscribe {self who event} {
  upvar #0 ::clay::object_subscribe($self) subscriptions
  if {![info exists subscriptions]} {
    set subscriptions {}
  }
  set match 0
  foreach {objpat eventlist} $subscriptions {
    if {![string match $objpat $who]} continue
    foreach eventpat $eventlist {
      if {[string match $eventpat $event]} {
        # This rule already exists
        return
      }
    }
  }
  dict lappend subscriptions $who $event
}

###
# Unsubscribe an object from an event pattern
###
proc ::clay::event::unsubscribe {self args} {
  upvar #0 ::clay::object_subscribe($self) subscriptions
  if {![info exists subscriptions]} {
    return
  }
  switch [llength $args] {
    1 {
      set event [lindex $args 0]
      if {$event eq "*"} {
        # Shortcut, if the
        set subscriptions {}
      } else {
        set newlist {}
        foreach {objpat eventlist} $subscriptions {
          foreach eventpat $eventlist {
            if {[string match $event $eventpat]} continue
            dict lappend newlist $objpat $eventpat
          }
        }
        set subscriptions $newlist
      }
    }
    2 {
      set who [lindex $args 0]
      set event [lindex $args 1]
      if {$who eq "*" && $event eq "*"} {
        set subscriptions {}
      } else {
        set newlist {}
        foreach {objpat eventlist} $subscriptions {
          if {[string match $who $objpat]} {
            foreach eventpat $eventlist {
              if {[string match $event $eventpat]} continue
              dict lappend newlist $objpat $eventpat
            }
          }
        }
        set subscriptions $newlist
      }
    }
  }
}
