###
# IRM External Process Manager
###

package require Tcl 8.5
package require cron 2.0

::namespace eval ::processman {}

###
# Attempt to locate some C - API helpers
###

set ::processman::api tcl

foreach {command package api} {
    {::twapi::process_exists} twapi    twapi
    umask                     tclx     tclx
    subprocess_exists         tclextra tclextra
    {}                        odielibc tclextra
} {
    if {[info commands $command] ne {}} {
	set ::processman::api $api
	break
    }
    if {![catch {package require $package}]} {
	set ::processman::api $api
	break
    }
}

switch $::processman::api {
    tclx {
	proc ::processman::kill_subprocess pid {
	    catch {::kill $pid}
	}
    }
    tclextra {
	proc ::processman::kill_subprocess pid {
	    catch {::kill_subprocess $pid}
	}
    }
    twapi {
	proc ::processman::priority {id level} {
	    foreach pid [PIDLIST $id] {
		switch $level {
		    background {
			if  {[catch {twapi::set_priority_class $pid 0x00104000} err]} {
			    puts "BG Mode failed - $err"
			    twapi::set_priority_class $pid 0x00004000
			}
		    }
		    low {
			twapi::set_priority_class $pid 0x00004000
		    }
		    high {
			twapi::set_priority_class $pid 0x00000020
		    }
		    default {
			twapi::set_priority_class $pid 0x00008000
		    }
		}
	    }
	}
	proc ::processman::killexe name {
	    set pids [twapi::get_process_ids -name $name.exe]
	    foreach pid $pids {
		# Catch the error in case process does not exist any more
		if {[catch {twapi::end_process $pid} err]} {
		    puts $err
		}
	    }
	    #catch {exec taskkill /F /IM $name.exe} err
	    #puts $err
	}
	proc ::processman::kill_subprocess pid {
	    if {[catch {::twapi::end_process $pid} err]} {
		puts $err
	    }
	}
	proc ::processman::subprocess_exists pid {
	    return [::twapi::process_exists $pid]
	}
	proc ::processman::keep_machine_awake {truefalse} {
	    if {[string is true -strict $truefalse]} {
		twapi::SetThreadExecutionState 0x80000040
	    } else {
		twapi::SetThreadExecutionState 0x00000000
	    }
	}
    }
    default {}
}

###
# Create fallback implementations for functions we don't have a
# C API call for
###

proc ::processman::fallback {name arglist body} {
    if {[info commands ::${name}] eq {} && [info commands ::processman::${name}] eq {} } {
	::proc ::processman::${name} $arglist $body
    }

}

# title: Keep the machine from going to sleep
::processman::fallback keep_machine_awake {truefalse} {
}

::processman::fallback killexe name {
    if {[catch {exec killall -9 $name} err]} {
	puts $err
    }
    harvest_zombies
}

###
# title: Detect a running process
# usage: subprocess_exists PID
# description:
#  Returns true if PID is running. If PID is an integer
#  it is interpreted as Process Id from the operating system.
#  Otherwise it is assumed to be a handle previously registered
#  with the processman package
###
::processman::fallback subprocess_exists pid {
    set dat [exec ps]
    foreach line [split $dat \n] {
	if {![scan $line "%d %s" thispid rest]} continue
	if { $thispid eq $pid} {
	    return $thispid
	}
    }
    return 0
}

# title: Changes priority of task
::processman::fallback priority {id level} {
    if {$::tcl_platform(platform) eq "windows"} {
	return
    }
    foreach pid [PIDLIST $id] {
	switch $level {
	    background {
		exec renice -n 20 -p $pid
	    }
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

::processman::fallback kill_subprocess pid {
    catch {exec kill $pid}
}

::processman::fallback harvest_zombies args {
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

proc ::processman::PIDLIST id {
    variable process_list
    if {[string is integer -strict $id]} {
	return $id
    }
    if {[dict exists $process_list $id]} {
	return [dict get $process_list $id]
    }
    return {}
}

###
# topic: ac021b1116f0c1d5e3319d9f333f0c89
# title: Kill a process
###
proc ::processman::kill id {
    variable process_list
    variable process_binding
    global tcl_platform
    foreach pid [PIDLIST $id] {
	kill_subprocess $pid
    }
    if {![string is integer $id]} {
	dict set process_list $id {}
	dict unset process_binding $id
    }
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
# topic: 8bccf62b4fa11949dba4c85e05d116e9
# title: Return a list of processes and their current state
###
proc ::processman::process_list {} {
    variable process_list
    set result {}
    dict set result self [pid]
    if {![info exists process_list]} {
	return $result
    }
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
    set pidlist {}
    if {![string is integer -strict $id]} {
	if {$id eq "self"} {
	    return [pid]
	}
	if {![dict exists $process_list $id]} {
	    return 0
	}
	set pidlist [dict get $process_list $id]
    } else {
	set pidlist $id
    }
    foreach pid $pidlist {
	if {[subprocess_exists $pid]} {
	    return $pid
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

package provide odie::processman 0.6
package provide processman 0.6
