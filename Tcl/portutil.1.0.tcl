# global port utility procedures
package provide portutil 1.0

namespace eval portutil {
	variable globals
	variable targets
}

########### External High Level Procedures ###########

# register_target
# Creates a target in the global target list using the internal dependancy
#     functions
# Arguments: <target name> <procedure to execute> <dependency list>
proc register_target {target procedure args} {
	if {[is_depend portutil::targets $target]} {
		puts "Warning: target '$target' re-registered (new procedure: '$procedure')"
	}
	if {[llength $args] == 0} {
		add_depend portutil::targets $target $procedure
	} else {
		eval "add_depend portutil::targets $target $procedure $args"
	}
}

proc deregister_target {target} {
		del_depend portutil::targets $target
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

# add dependancy
# Will overwrite entries for the same target
# Expects arguments: array, target, procedure, depends (optional)
proc add_depend {array target procedure args} {
	upvar $array uparray
	if {![isval uparray procedure,$target]} {
		lappend uparray(targets) $target
	}
	setval uparray procedure,$target $procedure
	if {[llength $args] > 0} {
		setval uparray depends,$target $args
	}
}

# del dependancy
proc del_depend {array target} {
	upvar $array uparray
	set uparray(targets) [ldelete uparray(targets) $target]
	delval uparray procedure,$target
	if {[isval uparray depends,$target]} {
		delval uparray depends,$target
	}
}

proc is_depend {array target} {
	upvar $array uparray
	return [isval uparray procedure,$target]
}


# XXX Well, it works. Could be faster.
proc eval_depend {array} {
	upvar $array uparray
	set list $uparray(targets)
	set slist $uparray(targets)
	set i 0
	set j [llength $list]
	while {$i < $j} {
		set target [lindex $slist $i]
		if {[isval uparray depends,$target]} {
			set depends [getval uparray depends,$target]
			set k [llength $depends]
			set l 0
			while {$l < $k} {
				set depend [lindex $depends $l]
				if {[lsearch -exact $list $depend] == -1} {
					puts "Missing dependancy '$depend'"
					return -1
				}
				set curloc [lsearch -exact $list $target]
				set newloc [lsearch -exact $list $depend]
				if {$curloc < $newloc} {
					set list [lreplace $list $curloc $curloc]
					set list [linsert $list $newloc $target]
				}
				incr l
			}
		} else {
			set curloc [lsearch -exact $list $target]
			set list [lreplace $list $curloc $curloc]
			set list [linsert $list 0 $target]
		}
		incr i
	}
	set uparray(targets) $list
	foreach target $uparray(targets) {
		if {[info exists uparray(depends,$target)]} {
			foreach depend $uparray(depends,$target) {
				if {[info exists finished]} {
					if {[lsearch $finished $depend] == -1} {
						puts "Cyclic dependencies between '$target' and dependancy '$depend'"
						return -1
					}
				}
			}
		}
		if {[$uparray(procedure,$target) $target] == 0} {
			lappend finished $target
		} else {
			puts "Error in target '$target'"
			return -1
		}
	}
	return 0
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
		setval $array $key [getval $array $key] $val
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
