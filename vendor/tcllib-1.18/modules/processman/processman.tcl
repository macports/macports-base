###
# IRM External Process Manager
###

package require cron 1.1

::namespace eval ::processman {}

if { $::tcl_platform(platform) eq "windows" } {
  package require twapi
} else {
  ###
  # Try to utilize C level utilities that are bundled
  # with either TclX or Odielib
  ###
  if [catch {package require odielib}] {
    catch {package require Tclx}
  }
  if {[info commands subprocess_exists] eq {}} {
    proc ::processman::subprocess_exists pid {
      set dat [exec ps]
      foreach line [split $dat \n] {
        if {![scan $line "%d %s" thispid rest]} continue
        if { $thispid eq $pid} {
          return $thispid
        }
      }
      return 0
    }
  }
  if {[info commands kill_subprocess] eq {}} {
    proc ::processman::kill_subprocess pid {
      catch {exec kill $pid}
    }
  }
}
if {[info commands harvest_zombies] eq {}} {
  proc ::processman::harvest_zombies args {
  }
}

###
# topic: a0cdb7503872cd302756c732956cd5c3
# title: Periodic scan of the state of processes
###
proc ::processman::events {} {
  variable process_binding
  foreach {id bind} $process_binding {
    if {![running $id]} {
      kill $id
      catch {eval $bind}
    }
  }
}

###
# topic: 95edbb845e0a8802b1cc3119516a6502
# title: Locate and executable of name
###
proc ::processman::find_exe name {
  global tcl_platform
  if {$tcl_platform(platform)=="windows"} {set suffix .exe} {set suffix {}}
  foreach f [list $name ~/irm/bin/$name ./$name/$name ./$name  ../$name/$name ../../$name/$name] {
    if {[file executable $f]} break
    append f $suffix
    if {[file executable $f]} break
  }
  if {![file executable $f]} {
     error "Cannot find the $name executable"
     return {}
  }
  return $f
}

###
# topic: ac021b1116f0c1d5e3319d9f333f0c89
# title: Kill a process
###
proc ::processman::kill id {
  variable process_list
  variable process_binding
  global tcl_platform

  if {![dict exists $process_list $id]} {
    return
  }
  foreach pid [dict get $process_list $id] {
    if { $tcl_platform(platform) eq "unix" } {
      catch {kill_subprocess $pid}
    } elseif { $tcl_platform(platform) eq "windows" } {
      catch {::twapi::end_process $pid}
    }
  }
  dict set process_list $id {}
  dict unset process_binding $id
  harvest_zombies
}

###
# topic: 8987329d60cd1adc766e09a0227f87b6
# title: Kill all processes spawned by this program
###
proc ::processman::kill_all {} {
  variable process_list
  if {![info exists process_list]} {
    return {}
  }
  foreach {name pidlist} $process_list {
    kill $name
  }
  harvest_zombies
}

###
# topic: 17a9014236425560140ba62bbb2745a8
# title: Kill a process
###
proc ::processman::killexe name {
  if {$::tcl_platform(platform) eq "windows" } {
    set pids [twapi::get_process_ids -name $name.exe]
    foreach pid $pids {
        # Catch the error in case process does not exist any more
        catch {twapi::end_process $pid}
    }
    #catch {exec taskkill /F /IM $name.exe} err
    puts $err
  } else {
    catch {exec killall -9 $name} err
    ##puts $err
  }
  harvest_zombies
}

###
# topic: 02406b2a7edd05c887554384ad2db41f
# title: Issue a command when process {$id} exits
###
proc ::processman::onexit {id cmd} {
  variable process_binding
  if {![running $id]} {
    catch {eval $cmd}
    return
  }
  dict set process_binding $id $cmd
}

###
# topic: ee784ae29e5b66867a30428b3095dc65
# title: Changes priority of task
###
proc ::processman::priority {id level} {
  variable process_list

  set pid [running $id]
  if {![string is integer $pid]} {
    set pid 0
  }
  if {!$pid} {
    return
  }
  if { $::tcl_platform(platform) eq "windows" } {
    package require twapi
    switch $level {
      low {
        twapi::set_priority_class $pid 0x4000
      }
      high {
        twapi::set_priority_class $pid 0x20
      }
      default {
        twapi::set_priority_class $pid 0x8000
      }
    }
  } else {
    switch $level {
      low {
        exec renice -n 10 -p $pid
      }
      high {
        exec renice -n -5 -p $pid
      }
      default {
        exec renice -n 0 -p $pid
      }
    }
  }
}

###
# topic: 8bccf62b4fa11949dba4c85e05d116e9
# title: Return a list of processes and their current state
###
proc ::processman::process_list {} {
  variable process_list
  if {![info exists process_list]} {
    return {}
  }
  set result {}
  foreach {name pidlist} $process_list {
    foreach pid $pidlist {
      lappend result $name $pid [subprocess_exists $pid]
    }
  }
  return $result
}

###
# topic: 96b4b2c53ea1554006417e507197488c
# title: Test if a process is running
###
proc ::processman::running id {
  variable process_list
  if {![dict exists $process_list $id]} {
    return 0
  }
  foreach pid [dict get $process_list $id] {
    if { $::tcl_platform(platform) eq "windows" } {
      if {[::twapi::process_exists $pid]} {
        return $pid
      }
    } else {
      if {[subprocess_exists $pid]} {
        return $pid
      }
    }
  }
  return 0
}

###
# topic: 61694ad97dbac52351431ad0d8c448e3
# title: Launch a task in the background
###
proc ::processman::spawn {id command args} {
  variable process_list
  if {[llength $command] == 1} {
    set command [lindex $command 0]
  }
  if {$::tcl_platform(platform) eq "windows"} {
    set pid [exec "$command" {*}$args &]
  } else {
    set pid [exec $command {*}$args &]
  }
  dict lappend process_list $id $pid
  return $pid
}

###
# topic: 56fbf345652c5ca18543a67a6bc95787
# title: Process Management Tools
###
namespace eval ::processman {
###
# initialize tables
###

variable process_list
variable process_binding
if { ![info exists process_list]} {
  set process_list {}
}
if {![info exists process_binding]} {
  set process_binding {}
}
}

::cron::every processman 60 ::processman::events

package provide odie::processman 0.3
package provide processman 0.3
