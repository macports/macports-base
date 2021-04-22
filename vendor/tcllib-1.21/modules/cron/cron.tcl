###
# This file implements a process table
# Instead of having individual components try to maintain their own timers
# we centrally manage how often tasks should be kicked off here.
###
#
# Author: Sean Woods (for T&E Solutions)
package require Tcl 8.6 ;# See coroutine
package require coroutine
package require dicttool
::namespace eval ::cron {}

proc ::cron::task {command args} {
  if {$::cron::trace > 1} {
    puts [list ::cron::task $command $args]
  }
  variable processTable
  switch $command {
    TEMPLATE {
      return [list object {} lastevent 0 lastrun 0 err 0 result {} \
        running 0 coroutine {} scheduled 0 frequency 0 command {}]
    }
    delete {
      unset -nocomplain ::cron::processTable([lindex $args 0])
    }
    exists {
      return [::info exists ::cron::processTable([lindex $args 0])]
    }
    info {
      set process [lindex $args 0]
      if {![::info exists ::cron::processTable($process)]} {
        error "Process $process does not exist"
      }
      return $::cron::processTable($process)
    }
    frequency {
      set process [lindex $args 0]
      set time [lindex $args 1]
      if {![info exists ::cron::processTable($process)]} return
      dict with ::cron::processTable($process) {
        set now [clock_step [current_time]]
        set frequency [expr {0+$time}]
        if {$scheduled>($now+$time)} {
          dict set ::cron::processTable($process) scheduled [expr {$now+$time}]
        }
      }
    }
    sleep {
      set process [lindex $args 0]
      set time [lindex $args 1]
      if {![info exists ::cron::processTable($process)]} return
      dict with ::cron::processTable($process) {
        set now [clock_step [current_time]]
        set frequency 0
        set scheduled [expr {$now+$time}]
      }
    }
    create -
    set {
      set process [lindex $args 0]
      if {![::info exists ::cron::processTable($process)]} {
        set ::cron::processTable($process) [task TEMPLATE]
      }
      if {[llength $args]==2} {
        foreach {field value} [lindex $args 1] {
          dict set ::cron::processTable($process) $field $value
        }
      } else {
        foreach {field value} [lrange $args 1 end] {
          dict set ::cron::processTable($process) $field $value
        }
      }
    }
  }
}

proc ::cron::at args {
  if {$::cron::trace > 1} {
    puts [list ::cron::at $args]
  }
  switch [llength $args] {
    2 {
      variable processuid
      set process event#[incr processuid]
      lassign $args timecode command
    }
    3 {
      lassign $args process timecode command
    }
    default {
      error "Usage: ?process? timecode command"
    }
  }
  variable processTable
  if {[string is integer -strict $timecode]} {
    set scheduled [expr {$timecode*1000}]
  } else {
    set scheduled [expr {[clock scan $timecode]*1000}]
  }
  ::cron::task set $process \
    frequency -1 \
    command $command \
    scheduled $scheduled \
    coroutine {}

  if {$::cron::trace > 1} {
    puts [list ::cron::task info $process - > [::cron::task info $process]]
  }
  ::cron::wake NEW
  return $process
}

proc ::cron::idle args {
  if {$::cron::trace > 1} {
    puts [list ::cron::idle $args]
  }
  switch [llength $args] {
    2 {
      variable processuid
      set process event#[incr processuid]
      lassign $args command
    }
    3 {
      lassign $args process command
    }
    default {
      error "Usage: ?process? timecode command"
    }
  }
  ::cron::task set $process \
    scheduled 0 \
    frequency 0 \
    command $command
  ::cron::wake NEW
  return $process
}

proc ::cron::in args {
  if {$::cron::trace > 1} {
    puts [list ::cron::in $args]
  }
  switch [llength $args] {
    2 {
      variable processuid
      set process event#[incr processuid]
      lassign $args timecode command
    }
    3 {
      lassign $args process timecode command
    }
    default {
      error "Usage: ?process? timecode command"
    }
  }
  set now [clock_step [current_time]]
  set scheduled [expr {$timecode*1000+$now}]
  ::cron::task set $process \
    frequency -1 \
    command $command \
    scheduled $scheduled
  ::cron::wake NEW
  return $process
}

proc ::cron::cancel {process} {
  if {$::cron::trace > 1} {
    puts [list ::cron::cancel $process]
  }
  ::cron::task delete $process
}

###
# topic: 0776dccd7e84530fa6412e507c02487c
###
proc ::cron::every {process frequency command} {
  if {$::cron::trace > 1} {
    puts [list ::cron::every $process $frequency $command]
  }
  variable processTable
  set mnow [clock_step [current_time]]
  set frequency [expr {$frequency*1000}]
  ::cron::task set $process \
    frequency $frequency \
    command $command \
    scheduled [expr {$mnow + $frequency}]
  ::cron::wake NEW
}


proc ::cron::object_coroutine {objname coroutine {info {}}} {
  if {$::cron::trace > 1} {
    puts [list ::cron::object_coroutine $objname $coroutine $info]
  }
  task set $coroutine \
    {*}$info \
    object $objname \
    coroutine $coroutine

  return $coroutine
}

# Notification that an object has been destroyed, and that
# it should give up any toys associated with events
proc ::cron::object_destroy {objname} {
  if {$::cron::trace > 1} {
    puts [list ::cron::object_destroy $objname]
  }
  variable processTable
  set dat [array get processTable]
  foreach {process info} $dat {
    if {[dict exists $info object] && [dict get $info object] eq $objname} {
      unset -nocomplain processTable($process)
    }
  }
}

###
# topic: 97015814408714af539f35856f85bce6
###
proc ::cron::run process {
  variable processTable
  set mnow [clock_step [current_time]]
  if {[dict exists processTable($process) scheduled] && [dict exists processTable($process) scheduled]>0} {
    dict set processTable($process) scheduled [expr {$mnow-1000}]
  } else {
    dict set processTable($process) lastrun 0
  }
  ::cron::wake PROCESS
}

proc ::cron::clock_step timecode {
  return [expr {$timecode-($timecode%1000)}]
}

proc ::cron::clock_delay {delay} {
  set now [current_time]
  set then [clock_step [expr {$delay+$now}]]
  return [expr {$then-$now}]
}

# Sleep for X seconds, wake up at the top
proc ::cron::clock_sleep {{sec 1} {offset 0}} {
  set now [current_time]
  set delay [expr {[clock_delay [expr {$sec*1000}]]+$offset}]
  sleep $delay
}

proc ::cron::current_time {} {
  if {$::cron::time < 0} {
    return [clock milliseconds]
  }
  return $::cron::time
}

proc ::cron::clock_set newtime {
  variable time
  for {} {$time < $newtime} {incr time 100} {
    uplevel #0 {::cron::do_one_event CLOCK_ADVANCE}
  }
  set time $newtime
  uplevel #0 {::cron::do_one_event CLOCK_ADVANCE}
}

proc ::cron::once_in_a_while body {
  set script {set _eventid_ $::cron::current_event}
  append script $body
  # Add a safety to allow this while to only execute once per call
  append script {if {$_eventid_==$::cron::current_event} yield}
  uplevel 1 [list while 1 $body]
}

proc ::cron::sleep ms {
  if {$::cron::trace > 1} {
    puts [list ::cron::sleep $ms [info coroutine]]
  }

  set coro [info coroutine]
  # When the clock is being externally
  # controlled, advance the clock when
  # a sleep is called
  variable time
  if {$time >= 0 && $coro eq {}} {
    ::cron::clock_set [expr {$time+$ms}]
    return
  }
  if {$coro ne {}} {
    set mnow [current_time]
    set start $mnow
    set end [expr {$start+$ms}]
    set eventid $coro
    if {$::cron::trace} {
      puts "::cron::sleep $ms $coro"
    }
    # Mark as running
    task set $eventid scheduled $end coroutine $coro running 1
    ::cron::wake WAKE_IN_CORO
    yield 2
    while {$end >= $mnow} {
      if {$::cron::trace} {
        puts "::cron::sleep $ms $coro (loop)"
      }
      set mnow [current_time]
      yield 2
    }
    # Mark as not running to resume idle computation
    task set $eventid running 0
    if {$::cron::trace} {
      puts "/::cron::sleep $ms $coro"
    }
  } else {
    set eventid [incr ::cron::eventcount]
    set var ::cron::event_#$eventid
    set $var 0
    if {$::cron::trace} {
      puts "::cron::sleep $ms $eventid waiting for $var"
      ::after $ms "set $var 1 ; puts \"::cron::sleep - $eventid - FIRED\""
    } else {
      ::after $ms "set $var 1"
    }
    ::vwait $var
    if {$::cron::trace} {
      puts "/::cron::sleep $ms $eventid"
    }
    unset $var
  }
}

###
# topic: 21de7bb8db019f3a2fd5a6ae9b38fd55
# description:
#    Called once per second, and timed to ensure
#    we run in roughly realtime
###
proc ::cron::runTasksCoro {} {
  ###
  # Do this forever
  ###
  variable processTable
  variable processing
  variable all_coroutines
  variable coroutine_object
  variable coroutine_busy
  variable nextevent
  variable current_event

  while 1 {
    incr current_event
    set lastevent 0
    set now [current_time]
    # Wake me up in 5 minute intervals, just out of principle
    set nextevent [expr {$now-($now % 300000) + 300000}]
    set next_idle_event [expr {$now+250}]
    if {$::cron::trace > 1} {
      puts [list CRON TASK RUNNER nextevent $nextevent]
    }
    ###
    # Determine what tasks to run this timestep
    ###
    set tasks {}
    set cancellist {}
    set nexttask {}

    foreach {process} [lsort -dictionary [array names processTable]] {
      dict with processTable($process) {
        if {$::cron::trace > 1} {
          puts [list CRON TASK RUNNER process $process frequency: $frequency scheduled: $scheduled]
        }
        if {$scheduled==0 && $frequency==0} {
          set lastrun $now
          set lastevent $now
          lappend tasks $process
        } else {
          if { $scheduled <= $now } {
            lappend tasks $process
            if { $frequency < 0 } {
              lappend cancellist $process
            } elseif {$frequency==0} {
              set scheduled 0
              if {$::cron::trace > 1} {
                puts [list CRON TASK RUNNER process $process demoted to idle]
              }
            } else {
              set scheduled [clock_step [expr {$frequency+$lastrun}]]
              if { $scheduled <= $now } {
                set scheduled [clock_step [expr {$frequency+$now}]]
              }
              if {$::cron::trace > 1} {
                puts [list CRON TASK RUNNER process $process rescheduled to $scheduled]
              }
            }
            set lastrun $now
          }
          set lastevent $now
        }
      }
    }
    foreach task $tasks {
      dict set processTable($task) lastrun $now
      if {[dict exists processTable($task) foreground] && [dict set processTable($task) foreground]} continue
      if {[dict exists processTable($task) running] && [dict set processTable($task) running]} continue
      if {$::cron::trace > 2} {
        puts [list RUNNING $task [task info $task]]
      }
      set coro [dict getnull $processTable($task) coroutine]
      dict set processTable($task) running 1
      set command [dict getnull $processTable($task) command]
      if {$command eq {} && $coro eq {}} {
        # Task has nothing to do. Slot it for destruction
        lappend cancellist $task
      } elseif {$coro ne {}} {
        if {[info command $coro] eq {}} {
          set object [dict get $processTable($task) object]
          # Trigger coroutine again if a command was given
          # If this coroutine is associated with an object, ensure
          # the object still exists before invoking its method
          if {$command eq {} || ($object ne {} && [info command $object] eq {})} {
            lappend cancellist $task
            dict set processTable($task) running 0
            continue
          }
          if {$::cron::trace} {
            puts [list RESTARTING $task - coroutine $coro - with $command]
          }
          ::coroutine $coro {*}$command
        }
        try $coro on return {} {
          # Terminate the coroutine
          lappend cancellist $task
        } on break {} {
          # Terminate the coroutine
          lappend cancellist $task
        } on error {errtxt errdat} {
          # Coroutine encountered an error
          lappend cancellist $task
          puts "ERROR $coro"
          set errorinfo [dict get $errdat -errorinfo]
          if {[info exists coroutine_object($coro)] && $coroutine_object($coro) ne {}} {
            catch {
            puts "OBJECT: $coroutine_object($coro)"
            puts "CLASS: [info object class $coroutine_object($coro)]"
            }
          }
          puts "$errtxt"
          puts ***
          puts $errorinfo
        } on continue {result opts} {
          # Ignore continue
          if { $result eq "done" } {
            lappend cancellist $task
          }
        } on ok {result opts} {
          if { $result eq "done" } {
            lappend cancellist $task
          }
        }
      } else {
        dict with processTable($task) {
          set err [catch {uplevel #0 $command} result errdat]
          if $err {
            puts "CRON TASK FAILURE:"
            puts "PROCESS: $task"
            puts $result
            puts ***
            puts [dict get $errdat -errorinfo]
          }
        }
        yield 0
      }
      dict set processTable($task) running 0
    }
    foreach {task} $cancellist {
      unset -nocomplain processTable($task)
    }
    foreach {process} [lsort -dictionary [array names processTable]] {
      set scheduled 0
      set frequency 0
      dict with processTable($process) {
        if {$scheduled==0 && $frequency==0} {
          if {$next_idle_event < $nextevent} {
            set nexttask $task
            set nextevent $next_idle_event
          }
        } elseif {$scheduled < $nextevent} {
          set nexttask $process
          set nextevent $scheduled
        }
        set lastevent $now
      }
    }
    foreach {eventid msec} [array get ::cron::coro_sleep] {
      if {$msec < 0} continue
      if {$msec<$nextevent} {
        set nexttask "CORO $eventid"
        set nextevent $scheduled
      }
    }
    set delay [expr {$nextevent-$now}]
    if {$delay <= 0} {
      yield 0
    } else {
      if {$::cron::trace > 1} {
        puts "NEXT EVENT $delay - NEXT TASK $nexttask"
      }
      yield $delay
    }
  }
}

proc ::cron::wake {{who ???}} {
  ##
  # Only triggered by cron jobs kicking off other cron jobs within
  # the script body
  ##
  if {$::cron::trace} {
    puts "::cron::wake $who"
  }
  if {$::cron::busy} {
    return
  }
  after cancel $::cron::next_event
  set ::cron::next_event [after idle [list ::cron::do_one_event $who]]
}

proc ::cron::do_one_event {{who ???}} {
  if {$::cron::trace} {
    puts "::cron::do_one_event $who"
  }
  after cancel $::cron::next_event
  set now [current_time]
  set ::cron::busy 1
  while {$::cron::busy} {
    if {[info command ::cron::COROUTINE] eq {}} {
      ::coroutine ::cron::COROUTINE ::cron::runTasksCoro
    }
    set cron_delay [::cron::COROUTINE]
    if {$cron_delay==0} {
      if {[incr loops]>10} {
        if {$::cron::trace} {
          puts "Breaking out of 10 recursive loops"
        }
        set ::cron::wake_time 1000
        break
      }
      set ::cron::wake_time 0
      incr ::cron::loops(active)
    } else {
      set ::cron::busy 0
      incr ::cron::loops(idle)
    }
  }
  ###
  # Try to get the event to fire off on the border of the
  # nearest second
  ###
  if {$cron_delay < 10} {
    set cron_delay 250
  }
  set ctime [current_time]
  set next [expr {$ctime+$cron_delay}]
  set ::cron::wake_time [expr {$next/1000}]
  if {$::cron::trace} {
    puts [list EVENT LOOP WILL WAKE IN $cron_delay ms next: [clock format $::cron::wake_time -format "%H:%M:%S"] active: $::cron::loops(active) idle: $::cron::loops(idle) woken_by: $who]
  }
  set ::cron::next_event [after $cron_delay {::cron::do_one_event TIMER}]
}


proc ::cron::main {} {
  # Never launch from a coroutine
  if {[info coroutine] ne {}} {
    return
  }
  set ::cron::forever 1
  while {$::cron::forever} {
    ::after 120000 {set ::cron::forever 1}
    # Call an update just to give the rest of the event loop a chance
    incr ::cron::loops(main)
    ::after cancel $::cron::next_event
    set ::cron::next_event [::after idle {::cron::wake MAIN}]
    set ::cron::forever 1
    set ::cron::busy 0
    ::vwait ::cron::forever
    if {$::cron::trace} {
      puts "MAIN LOOP CYCLE $::cron::loops(main)"
    }
  }
}

###
# topic: 4a891d0caabc6e25fbec9514ea8104dd
# description:
#    This file implements a process table
#    Instead of having individual components try to maintain their own timers
#    we centrally manage how often tasks should be kicked off here.
###
namespace eval ::cron {
  variable lastcall 0
  variable processTable
  variable busy 0
  variable next_event {}
  variable trace 0
  variable current_event
  variable time -1
  if {![info exists current_event]} {
    set current_event 0
  }
  if {![info exists ::cron::loops]} {
    array set ::cron::loops {
      active 0
      main 0
      idle 0
      wake 0
    }
  }
}

::cron::wake STARTUP
package provide cron 2.1

