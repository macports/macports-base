# global port utility procedures
package provide portutil 1.0
package require Pextlib 1.0

namespace eval portutil {
	variable globals
	variable targets
}

########### External High Level Procedures ###########

# register
# Creates a target in the global target list using the internal dependancy
#     functions
# Arguments: target <target name> <procedure to execute>
# Arguments: requires <list of target names>
# Arguments: uses <list of target names>
proc register {mode target args} {	
	if {[string equal target $mode]} {
		if {[isval portutil::targets $target]} {
			# XXX: remove puts
			puts "Warning: target '$target' re-registered (new procedure: '$procedure')"
		}
		depend_list_add_item portutil::targets $target $args [list] [list]
	} else {
		# requires or uses or whatever ;-)
		if {[isval portutil::targets name,$target]} {
			# XXX: violates data abstraction
			eval "lappend portutil::targets($mode,$target) $args"
		} else {
			# XXX: remove puts
			puts "Warning: target '$target' not-registered in register $mode"
		}
	}
}

proc deregister_target {target} {
	depend_list_del_item portutil::targets portutil::targets $target
}

# options
# Exports options in an array as externally callable procedures
# Thus, "options myarray name date" would create procedures named "name"
# and "date" that set the array items keyed by "name" and "date"
# Arguments: <array for export> <options (keys in array) to export>
proc options {array args} {
	foreach option $args {
		eval proc $option {args} \{ setval $array $option {$args} \}
	}
}

# default
# Checks if variable is set, if not, sets to supplied value
proc default {array key val} {
	upvar $array uparray
	if {![isval $array $key]} {
		setval $array $key $val
	}
}

# globals
# Specifies which keys from an array should be exported as global variables.
# Often used directly with options procedure
proc globals {array args} {
	foreach key $args {
		if {[info exists portutil::globals($key)]} {
			error "Re-exporting global $key"
		}
		set portutil::globals($key) $array
	}
}

########### Dependancy Manipulation Procedures ###########

# depend_list_add
# Creates a new node in the dependency list with the given name.
# Optionally sets the list of hard and soft dependencies.
# Caution: this will over-write an existing node of the same name.
proc depend_list_add_item {nodes name procedure requires uses} {
	upvar $nodes upnodes
	set upnodes(name,$name) $name
	set upnodes(procedure,$name) $procedure
	set upnodes(requires,$name) $requires
	set upnodes(uses,$name) $uses
}

proc depend_list_del_item {nodes name} {
	upvar $nodes upnodes
	unset upnodes(name,$name)
	unset upnodes(procedure,$name)
	unset upnodes(requires,$name)
	unset upnodes(uses,$name)
}

# Count the unmet dependencies in the sublist
# (private)
proc depend_list_count_unmet {names statusdict} {
	upvar $statusdict upstatusdict
	set unmet 0
	foreach name $names {
		if {![isval upstatusdict $name] ||
		    ![string equal $upstatusdict($name) success]} {
			incr unmet
		}
	}
	return $unmet
}

# Returns true of any of the dependencies are pending in the waitlist
# (private)
proc depend_list_has_pending {waitlist uses} {
	foreach name $uses {
		if {[isval $waitlist name,$name]} { 
			return 1
		}
	}
	return 0
}

# Get the next item from the depend list
# (private)
proc depend_list_get_next {waitlist statusdict} {
	set nextitem ""
	# arbitrary large number ~ INT_MAX
	set minfailed 2000000000
	upvar $waitlist upwaitlist
	upvar $statusdict upstatusdict

	foreach n [array names upwaitlist name,*] {
		set name $upwaitlist($n)

		# skip if unsatisfied hard dependencies
		if {[depend_list_count_unmet $upwaitlist(requires,$name) upstatusdict]} { continue }

		# favor item with fewest unment soft dependencies
		set unmet [depend_list_count_unmet $upwaitlist(uses,$name) upstatusdict]

		# delay items with unmet soft dependencies that can be filled
		if {$unmet > 0 && [depend_list_has_pending waitlist $upwaitlist(uses,$name)]} { continue }

		if {$unmet >= $minfailed} {
			# not better than our last pick
			continue
		} else {
			# better than our last pick
			set minfailed $unmet
			set nextitem $name
		}
	}
	return $nextitem
}


# Evaluate the dependency list, returning an ordered list suitable
# for execution.
proc eval_depend {nodes} {
	# waitlist - nodes waiting to be executed
	upvar $nodes waitlist

	# status - keys will be node names, values will be success or failure.
	array set statusdict [list]
		
	# loop for as long as there are nodes in the waitlist.
	while (1) {
		set name [depend_list_get_next waitlist statusdict]
		if {[isval waitlist procedure,$name]} {
			# XXX: remove puts
			puts "DEBUG: Executing $name"
			if {[$waitlist(procedure,$name) $waitlist(name,$name)] == 0} {
				array set statusdict [list $name success]
			} else {
				# XXX: remove puts
				puts "Error in $name"
				array set statusdict [list $name failure]
			}
			array unset waitlist name,$name
			array unset waitlist procedure,$name
			array unset waitlist requires,$name
			array unset waitlist uses,$name
		} else {
			# somebody broke!
			# XXX: remove puts
			puts "Warning: the following targets did not execute: "
			foreach name [array names waitlist name,*] {
				puts -nonewline "$waitlist($name) "
			}
			puts ""
			break
		}
	}
	
}

########### Global Variable Manipulation Procedures ###########

proc globalval {array key} {
	upvar $array uparray
	global $key
	set $key $uparray($key)
	set portutil::globals($key) $array
}

proc unglobalval {key} {
	global $key
	if {[info exists $key]} {
		unset $key
	}
	if {[info exists portutil::globals($key)]} {
		unset portutil::globals($key)
	}
}

########### Stack/List Manipulation Procedures ###########

proc push {list value} {
	upvar $list stack
	lappend list $value
}

proc pop {list} {
	upvar $list stack
	set value [lindex $list end]
	set list [lrange $list 0 [expr [llength $list]-2]]
	return $value
}

proc ldelete {list value} {
	set ix [lsearch -exact $list $value]
	if {$ix >= 0} {
		return [lreplace $list $ix $ix]
	} else {
		return $list
	}
}

########### Base Data Accessor Procedures ###########

proc setval {array key val} {
	upvar $array uparray
	set uparray($key) $val
	if {[info exists portutil::globals($key)]} {
		if {$portutil::globals($key) == $array} {
			globalval uparray $key
		}
	}
}

proc appendval {array key val} {
	upvar $array uparray
	if {[isval $array $key]} {
		setval $array $key "[getval $array $key] $val"
	} else {
		setval $array $key $val
	}
}

proc isval {array key} {
	upvar $array uparray
	return [info exists uparray($key)]
}

proc getval {array key} {
	upvar $array uparray
	if {![info exists uparray($key)]} {
		error "Undefined option $key in $array"
	} else {
		if {[info exists portutil::globals($key)]} {
			upvar #0 $key upkey
			setval $array $key $upkey
		}
		return $uparray($key)
	}
}

proc delval {array key} {
	upvar $array uparray
	unset uparray($key)
	if {[info exists portutil::globals($key)]} {
		unglobalval $key
	}
}
