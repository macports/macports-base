# ex:ts=4
# portutil.tcl
#
# Copyright (c) 2002 Apple Computer, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

package provide portutil 1.0
package require Pextlib 1.0

global targets target_uniqid variants

set targets [list]
set target_uniqid 0

set variants [list]

########### External High Level Procedures ###########

namespace eval options {
}

# options
# Exports options in an array as externally callable procedures
# Thus, "options name date" would create procedures named "name"
# and "date" that set global variables "name" and "date", respectively
# When an option is modified in any way, options::$option is called,
# if it exists
# Arguments: <list of options>
proc options {args} {
    foreach option $args {
    	eval "proc $option {args} \{ \n\
	    global ${option} user_options option_procs \n\
		\if \{!\[info exists user_options(${option})\]\} \{ \n\
		     set ${option} \$args \n\
			 if \{\[info exists option_procs($option)\]\} \{ \n\
				foreach p \$option_procs($option) \{ \n\
					eval \"\$p $option set \$args\" \n\
				\} \n\
			 \} \n\
		\} \n\
	\}"

	eval "proc ${option}-delete {args} \{ \n\
	    global ${option} user_options \n\
		\if \{!\[info exists user_options(${option})\]\} \{ \n\
		    foreach val \$args \{ \n\
			ldelete ${option} \$val \n\
		    \} \n\
			 if \{\[info exists option_procs($option)\]\} \{ \n\
				foreach p \$option_procs($option) \{ \n\
					eval \"\$p $option delete \$args\" \n\
				\} \n\
			 \} \n\
		\} \n\
	\}"
	eval "proc ${option}-append {args} \{ \n\
	    global ${option} user_options \n\
		\if \{!\[info exists user_options(${option})\]\} \{ \n\
		    set $option \[concat \$$option \$args\] \n\
			 if \{\[info exists option_procs($option)\]\} \{ \n\
				foreach p \$option_procs($option) \{ \n\
					eval \"\$p $option append \$args\" \n\
				\} \n\
			 \} \n\
		\} \n\
	\}"
    }
}

proc options_export {args} {
    foreach option $args {
        eval "proc options::${option} \{args\} \{ \n\
	    global ${option} PortInfo \n\
	    if \{\[info exists ${option}\]\} \{ \n\
		set PortInfo(${option}) \$${option} \n\
	    \} else \{ \n\
		unset PortInfo(${option}) \n\
	    \} \n\
        \}"
	option_proc ${option} options::${option}
    }
}

proc option_proc {option args} {
	global option_procs
	eval "lappend option_procs($option) $args"
}

# commands
# Accepts a list of arguments, of which several options are created
# and used to form a standard set of command options.
proc commands {args} {
    foreach option $args {
	options use_${option} ${option}.dir ${option}.pre_args ${option}.args ${option}.post_args ${option}.env ${option}.type ${option}.cmd
    }
}

# command
# Given a command name, command assembled a string
# composed of the command options.
proc command {command} {
    global ${command}.dir ${command}.pre_args ${command}.args ${command}.post_args ${command}.env ${command}.type ${command}.cmd

    set cmdstring ""
    if [info exists ${command}.dir] {
	set cmdstring "cd [set ${command}.dir] &&"
    }

    if [info exists ${command}.env] {
	foreach string [set ${command}.env] {
		set cmdstring "$cmdstring $string"
	}
    }

    if [info exists ${command}.cmd] {
	foreach string [set ${command}.cmd] {
		set cmdstring "$cmdstring $string"
	}
    } else {
	set cmdstring "$cmdstring ${command}"
    }
    foreach var "${command}.pre_args ${command}.args ${command}.post_args" {
	if [info exists $var] {
	foreach string [set ${var}] {
		set cmdstring "$cmdstring $string"
	}
	}
    }
    ui_debug "Assembled command: '$cmdstring'"
    return $cmdstring
}

# default
# Sets a variable to the supplied default if it does not exist,
# and adds a variable trace. The variable traces allows for delayed
# variable and command expansion in the variable's default value.
proc default {option val} {
    global $option option_defaults
	if {[info exists option_defaults($option)]} {
		ui_debug "Re-registering default for $option"
	} else {
		# If option is already set and we did not set it
		# do not reset the value
		if {[info exists $option]} {
			return
		}
	}
	set option_defaults($option) $val
	set $option $val
	trace variable $option rwu default_check
}

# default_check
# trace handler to provide delayed variable & command expansion
# for default variable values
proc default_check {optionName index op} {
	global option_defaults $optionName
	switch $op {
		w {
			unset option_defaults($optionName)
			trace vdelete $optionName rwu default_check
			return
		}
		r {
			upvar $optionName option
			uplevel #0 set $optionName $option_defaults($optionName)
			return
		}
		u {
			unset option_defaults($optionName)
			trace vdelete $optionName rwu default_check
			return
		}
	}
}

# variant <provides> [<provides> ...] [requires <requires> [<requires>]]
# Portfile level procedure to provide support for declaring variants
proc variant {args} {
    global variants PortInfo
    upvar $args upargs
    
    set len [llength $args]
    set code [lindex $args end]
    set args [lrange $args 0 [expr $len - 2]]
    
    set provides [list]
    set requires [list]
    
    # halfway through the list we'll hit 'requires' which tells us
    # to switch into processing required flavors/depspecs.
    set after_requires 0
    foreach arg $args {
        if ([string equal $arg requires]) { 
            set after_requires 1
            continue
        }
        if ($after_requires) {
            lappend requires $arg
        } else {
            lappend provides $arg
        }
    }
    set name "variant-[join $provides -]"
    set obj [variant_new $name]
    $obj append provides $provides
    $obj append requires $requires
    $obj set code $code
	lappend variants $obj

    # Export provided variant to PortInfo
    lappend PortInfo(variants) $provides
}

# variant_isset name
# Returns 1 if variant name selected, otherwise 0
proc variant_isset {name} {
    global variations

    if {[info exists variations($name)] && $variations($name) == "+"} {
	return 1
    }
    return 0
}

# variant_set name
# Sets variant to run for current portfile
proc variant_set {name} {
    global variations

    set variations($name) +
}

# variant_unset name
# Clear variant for current portfile
proc variant_unset {name} {
    global variations

    set variations($name) -
}

########### Misc Utility Functions ###########

# tbool (testbool)
# If the variable exists in the calling procedure's namespace
# and is set to "yes", return 1. Otherwise, return 0
proc tbool {key} {
    upvar $key $key
    if {[info exists $key]} {
	if {[string equal -nocase [set $key] "yes"]} {
	    return 1
	}
    }
    return 0
}

# ldelete
# Deletes a value from the supplied list
proc ldelete {list value} {
    upvar $list uplist
    set ix [lsearch -exact $uplist $value]
    if {$ix >= 0} {
	set uplist [lreplace $uplist $ix $ix]
    }
}

# reinplace
# Provides "sed in place" functionality
proc reinplace {oddpattern file}  {
    set backpattern [strsed $oddpattern {g/\//\\\\\//}]
    set pattern [strsed $backpattern {g/\|/\//}]

    if {[catch {set input [open "$file" RDWR]} error]} {
	ui_error "reinplace: $error"
	return -code error "reinplace failed"
    }

    if {[catch {set result [mkstemp "/tmp/[file tail $file].sed.XXXXXXXX"]} error]} {
	ui_error "reinplace: $error"
	close $input
	return -code error "reinplace failed"
    }

    set output [lindex $result 0]
    set tmpfile [lindex $result 1]

    if {[catch {exec sed $pattern <@$input >@$output} error]} {
	ui_error "reinplace: $error"
	close $output
	close $input
	file delete "$tmpfile"
	return -code error "reinplace failed"
    }

    seek $output 0
    seek $input 0

    if {[catch {exec cat <@$output >@$input 2>/dev/null} error]} {
	ui_error "reinplace: $error"
	close $output
	close $input
	file delete "$tmpfile"
	return -code error "reinplace failed"
    }

    close $output
    close $input
    file delete "$tmpfile"
    return
}

# filefindbypath
# Provides searching of the standard path for included files
proc filefindbypath {fname} {
    global distpath filedir workdir worksrcdir portpath

    if [file readable $fname] {
	return $fname
    } elseif [file readable $portpath/$fname] {
	return $portpath/$fname
    } elseif [file readable $portpath/$filedir/$fname] {
	return $portpath/$filedir/$fname
    } elseif [file readable $distpath/$fname] {
	return $distpath/$fname
    } elseif [file readable $portpath/$workdir/$worksrcdir/$fname] {
	return $portpath/$workdir/$worksrcdir/$fname
    } elseif [file readable [file join /etc $fname]] {
	return [file join /etc $fname]
    }
    return ""
}

# include
# Source a file, looking for it along a standard search path.
proc include {fname} {
    set tgt [filefindbypath $fname]
    if [string length $tgt] {
	uplevel "source $tgt"
    } else {
	return -code error "Unable to find include file $fname"
    }
}

# makeuserproc
# This procedure re-writes the user-defined custom target to include
# all the globals in its scope.  This is undeniably ugly, but I haven't
# thought of any other way to do this.
proc makeuserproc {name body} {
    regsub -- "^\{(.*)" $body "\{ \n foreach g \[info globals\] \{ \n global \$g \n \} \n \\1 " body
    eval "proc $name {} $body"
}

########### External Dependancy Manipulation Procedures ###########
# register
# Creates a target in the global target list using the internal dependancy
#     functions
# Arguments: <identifier> <mode> <args ...>
# The following modes are supported:
#	<identifier> target <procedure to execute> [run type]
#	<identifier> init <procedure to execute>
#	<identifier> prerun <procedure to execute>
#	<identifier> postrun <procedure to execute>
#	<identifier> provides <list of target names>
#	<identifier> requires <list of target names>
#	<identifier> uses <list of target names>
#	<identifier> deplist <list of deplist names>
#	<provides> preflight <proc name>
#	<provides> postflight <proc name>
proc register {name mode args} {
    global targets target_uniqid
    
	set obj [dlist_get_by_name $targets $name]
	if {$obj == ""} {
		set obj [target_new $name]
		lappend targets $obj
	}

    if {$mode == "target"} {
        set procedure [lindex $args 0]
        if {[$obj has procedure]} {
            ui_debug "Warning: target '$name' re-registered (new procedure: '$procedure')"
        }
        $obj set procedure $procedure
		
		# Set runtype {always,once} if available
		if {[llength $args] >= 2} {
			$obj set runtype [lindex $args 1]
		}
    } elseif {$mode == "init"} {
		set init [lindex $args 0]
		if {[$obj has init]} {
			ui_debug "Warning: target '$name' re-registered init procedure (new procedure: '$init')"
		}
		$obj set init $init
    } elseif {$mode == "prerun"} {
		set prerun [lindex $args 0]
		if {[$obj has prerun]} {
			ui_debug "Warning: target '$name' re-registered pre-run procedure (new procedure: '$prerun')"
		}
		$obj prerun $prerun
    } elseif {$mode == "postrun"} {
		set postrun [lindex $args 0]
		if {[$obj has postrun]} {
			ui_debug "Warning: target '$name' re-registered post-run procedure (new procedure: '$postrun')"
		}
		$obj set postrun $postrun
    } elseif {$mode == "requires" || $mode == "uses" || $mode == "provides"} {
		$obj append $mode $args
        
        if {$mode == "provides"} {
            # If it's a provides, register the pre-/post- hooks for use in Portfile.
            # Portfile syntax: pre-fetch { puts "hello world" }
            # User-code exceptions are caught and returned as a result of the target.
            # Thus if the user code breaks, dependent targets will not execute.
            foreach target $args {
				if {[info commands $target] != ""} {
					ui_error "$name attempted to register provide \'$target\' which is a pre-existing procedure. Ignoring register."
					continue;
				}
                set ident [lindex [depspec_get_matches $targets provides $args] 0]
                set origproc [$ident get procedure]
				set ident [$ident get name]
                eval "proc $target {args} \{ \n\
					global target_uniqid \n\
					set id \[incr target_uniqid\] \n\
                    register $ident target proc-$target\$id \n\
                    eval \"proc proc-$target\$id \{name\} \{ \n\
                        if \\\[catch userproc-$target\$id result\\\] \{ \n\
							ui_info \\\$result \n\
							return 1 \n\
						\} else \{ \n\
							return 0 \n\
						\} \n\
                    \}\" \n\
                    eval \"proc do-$target \{\} \{ $origproc $target\}\" \n\
                    makeuserproc userproc-$target\$id \$args \}"
                eval "proc pre-$target {args} \{ \n\
					global target_uniqid \n\
					set id \[incr target_uniqid\] \n\
                    register $target preflight pre-$target\$id \n\
                    eval \"proc pre-$target\$id \{name\} \{ \n\
                        if \\\[catch userproc-pre-$target\$id result\\\] \{ \n\
							ui_info \\\$result \n\
							return 1 \n\
						\} else \{ \n\
							return 0 \n\
						\} \n\
                    \}\" \n\
                    makeuserproc userproc-pre-$target\$id \$args \}"
                eval "proc post-$target {args} \{ \n\
					global target_uniqid \n\
					set id \[incr target_uniqid\] \n\
                    register $target postflight post-$target\$id \n\
                    eval \"proc post-$target\$id \{name\} \{ \n\
                        if \\\[catch userproc-post-$target\$id result\\\] \{ \n\
							ui_info \\\$result \n\
							return 1 \n\
						\} else \{ \n\
							return 0 \n\
						\} \n\
                    \}\" \n\
                    makeuserproc userproc-post-$target\$id \$args \}"
            }
        }

	} elseif {$mode == "deplist"} {
		$obj append $mode $args
	
    } elseif {$mode == "preflight"} {
		# Find target which provides the specified name, and add a preflight.
		# XXX: this only returns the first match, is this what we want?
		set obj [lindex [depspec_get_matches $targets provides $name] 0]
		$obj append pre $args
		
    } elseif {$mode == "postflight"} {
		# Find target which provides the specified name, and add a preflight.
		# XXX: this only returns the first match, is this what we want?
		set obj [lindex [depspec_get_matches $targets provides $name] 0]
		$obj append post $args
	}
}


# unregister
# Unregisters a target in the global target list
# Arguments: target <target name>
proc unregister {mode target} {
}

########### Internal Dependancy Manipulation Procedures ###########

# returns a depspec by name
proc dlist_get_by_name {dlist name} {
	set result ""
	foreach d $dlist {
		if {[$d get name] == $name} {
			set result $d
			break
		}
	}
	return $result
}

# returns a list of depspecs that contain the given name in the given key
proc depspec_get_matches {dlist key value} {
    set result [list]
    foreach d $dlist {
		foreach val [$d get $key] {
			if {$val == $value} {
				lappend result $d
			}
		}
    }
    return $result
}

# Count the unmet dependencies in the dlist based on the statusdict
proc dlist_count_unmet {dlist statusdict names} {
    upvar $statusdict upstatusdict
    set unmet 0
    foreach name $names {
		# Service was provided, check next.
		if {[info exists upstatusdict($name)] && $upstatusdict($name) == 1} {
			continue
		} else {
			incr unmet
		}
    }
    return $unmet
}

# Returns true if any of the dependencies are pending in the dlist
proc dlist_has_pending {dlist uses} {
    foreach name $uses {
		if {[llength [depspec_get_matches $dlist provides $name]] > 0} {
			return 1
		}
    }
    return 0
}

# Get the name of the next eligible item from the dependency list
proc generic_get_next {dlist statusdict} {
    set nextitem ""
    # arbitrary large number ~ INT_MAX
    set minfailed 2000000000
    upvar $statusdict upstatusdict
    
    foreach obj $dlist {		
		# skip if unsatisfied hard dependencies
		if {[dlist_count_unmet $dlist upstatusdict [$obj get requires]]} { continue }
		
		# favor item with fewest unment soft dependencies
		set unmet [dlist_count_unmet $dlist upstatusdict [$obj get uses]]

		# delay items with unmet soft dependencies that can be filled
		if {$unmet > 0 && [dlist_has_pending $dlist [$obj get uses]]} { continue }
		
		if {$unmet >= $minfailed} {
			# not better than our last pick
			continue
		} else {
			# better than our last pick
			set minfailed $unmet
			set nextitem $obj
		}
    }
    return $nextitem
}


# Evaluate the list of depspecs, running each as it becomes eligible.
# dlist is a collection of depspec objects to be run
# get_next_proc is used to determine the best item to run
proc dlist_evaluate {dlist get_next_proc} {
	global portname
	
    # status - keys will be node names, values will be {-1, 0, 1}.
    array set statusdict [list]
	
	# XXX: Do we want to evaluate this dynamically instead of statically? 
	foreach obj $dlist {
		if {[$obj test] == 1} {
			foreach name [$obj get provides] {
				set statusdict($name) 1
			}
			ldelete dlist $obj
		}
	}
    
    # loop for as long as there are nodes in the dlist.
    while (1) {
		set obj [$get_next_proc $dlist statusdict]

		if {$obj == ""} { 
			break
		} else {
			set result [$obj run]
			# depspec->run returns an error code, so 0 == success.
			# translate this to the statusdict notation where 1 == success.
			foreach name [$obj get provides] {
				set statusdict($name) [expr $result == 0]
			}
			
			# Delete the item from the waiting list.
			ldelete dlist $obj
		}
    }
    
	if {[llength $dlist] > 0} {
		# somebody broke!
		ui_info "Warning: the following items did not execute (for $portname): "
		foreach obj $dlist {
			ui_info "[$obj get name] " -nonewline
		}
		ui_info ""
		return 1
    }
	return 0
}

proc target_run {this} {
	global target_state_fd portname
	set result 0
	set procedure [$this get procedure]
    if {$procedure != ""} {
		set name [$this get name]
	
		if {[$this has init]} {
			set result [catch {[$this get init] $name} errstr]
		}
				
		if {[check_statefile $name $target_state_fd]} {
			set result 0
			ui_debug "Skipping completed $name ($portname)"
		} else {
			# Execute pre-run procedure
			if {[$this has prerun]} {
				set result [catch {[$this get prerun] $name} errstr]
			}

			if {$result == 0} {
				foreach pre [$this get pre] {
					ui_debug "Executing $pre"
					set result [catch {$pre $name} errstr]
					if {$result != 0} { break }
				}
			}

			if {$result == 0} {
				ui_debug "Executing $name ($portname)"
				set result [catch {$procedure $name} errstr]
			}
			
			if {$result == 0} {
				foreach post [$this get post] {
					ui_debug "Executing $post"
					set result [catch {$post $name} errstr]
					if {$result != 0} { break }
				}
			}
			# Execute post-run procedure
			if {[$this has postrun] && $result == 0} {
				set postrun [$this get postrun]
				ui_debug "Executing $postrun"
				set result [catch {$postrun $name} errstr]
			}
		}
		if {$result == 0} {
			if {[$this get runtype] != "always"} {
				write_statefile $name $target_state_fd
			}
		} else {
			ui_error "Target error: $name returned $errstr"
			set result 1
		}
		
    } else {
		ui_info "Warning: $name does not have a registered procedure"
		set result 1
    }

    return $result
}

proc eval_targets {target} {
	global targets target_state_fd
	set dlist $targets

    # Select the subset of targets under $target
    if {$target != ""} {
		# XXX munge target. install really means registry, then install
		# If more than one target ever needs this, make this a generic interface
		if {$target == "install"} {
			set target registry
		}
        set matches [depspec_get_matches $dlist provides $target]
        if {[llength $matches] > 0} {
			set dlist [dlist_append_dependents $dlist [lindex $matches 0] [list]]
		# Special-case 'all'
        } elseif {$target != "all"} {
            ui_info "unknown target: $target"
            return 1
        }
    }
        
    # Restore the state from a previous run.
    set target_state_fd [open_statefile]
    
    set ret [dlist_evaluate $dlist generic_get_next]

    close $target_state_fd
	return $ret
}

# returns the names of dependents of <name> from the <itemlist>
proc dlist_append_dependents {dlist obj result} {

	# Append the item to the list, avoiding duplicates
	if {[lsearch $result $obj] == -1} {
		lappend result $obj
	}
    	
    # Recursively append any hard dependencies
	foreach dep [$obj get requires] {
		foreach provider [depspec_get_matches $dlist provides $dep] {
			set result [dlist_append_dependents $dlist $provider $result]
        }
    }
    # XXX: add soft-dependencies?
	return $result
}

# open_statefile
# open file to store name of completed targets
proc open_statefile {args} {
    global portpath workdir

    if ![file isdirectory $portpath/$workdir] {
	file mkdir $portpath/$workdir
    }
    # flock Portfile
    set statefile [file join $portpath $workdir .darwinports.state]
    if {[file exists $statefile] && ![file writable $statefile]} {
	return -code error "$statefile is not writable - check permission on port directory"
    }
    set fd [open $statefile a+]
    if [catch {flock $fd -exclusive -noblock} result] {
        if {"$result" == "EAGAIN"} {
            ui_puts "Waiting for lock on $statefile"
	} elseif {"$result" == "EOPNOTSUPP"} {
	    # Locking not supported, just return
	    return $fd
        } else {
            return -code error "$result obtaining lock on $statefile"
        }
    }
    flock $fd -exclusive
    return $fd
}

# check_statefile
# Check completed state of target $name
proc check_statefile {name fd} {
    global portpath workdir

    seek $fd 0
    while {[gets $fd line] >= 0} {
	if {[string equal $line $name]} {
	    return 1
	}
    }
    return 0
}

# write_statefile
# Set target $name completed in the state file
proc write_statefile {name fd} {
    if {[check_statefile $name $fd]} {
	return 0
    }
    seek $fd 0 end
    puts $fd $name
    flush $fd
}

# Traverse the ports collection hierarchy and call procedure func for
# each directory containing a Portfile
proc port_traverse {func {dir .}} {
    set pwd [pwd]
    if [catch {cd $dir} err] {
	ui_error $err
	return
    }
    foreach name [readdir .] {
	if {[string match $name .] || [string match $name ..]} {
	    continue
	}
	if [file isdirectory $name] {
	    port_traverse $func $name
	} else {
	    if [string match $name Portfile] {
		catch {eval $func {[file join $pwd $dir]}}
	    }
	}
    }
    cd $pwd
}


########### Port Variants ###########

# Each variant which provides a subset of the requested variations
# will be chosen.  Returns a list of the selected variants.
proc choose_variants {dlist variations} {
    upvar $variations upvariations

    set selected [list]
    
    foreach obj $dlist {
		# Enumerate through the provides, tallying the pros and cons.
		set pros 0
		set cons 0
		set ignored 0
		foreach flavor [$obj get provides] {
			if {[info exists upvariations($flavor)]} {
				if {$upvariations($flavor) == "+"} {
					incr pros
				} elseif {$upvariations($flavor) == "-"} {
					incr cons
				}
			} else {
				incr ignored
			}
		}
		
		if {$cons > 0} { continue }
		
		if {$pros > 0 && $ignored == 0} {
			lappend selected $obj
		}
	}
    return $selected
}

proc variant_run {this} {
	set name [$this get name]
    ui_debug "Executing $name provides [$this get provides]"
    makeuserproc $name-code "\{[$this get code]\}"
    if ([catch $name-code result]) {
		ui_error "Error executing $name: $result"
		return 1
	}
    return 0
}

proc eval_variants {variations} {
	global variants
	set dlist $variants
	upvar $variations upvariations
	set chosen [choose_variants $dlist upvariations]
    
	# now that we've selected variants, change all provides [a b c] to [a-b-c]
    # this will eliminate ambiguity between item a, b, and a-b while fulfilling requirments.
    #foreach obj $dlist {
    #    $obj set provides [list [join [$obj get provides] -]]
    #}
	
	set newlist [list]
    foreach variant $chosen {
        set newlist [dlist_append_dependents $dlist $variant $newlist]
    }

    dlist_evaluate $newlist generic_get_next
}

##### DEPSPEC #####

# Object-Oriented Depspecs
#
# Each depspec will have its data stored in an array
# (indexed by field name) and its procedures will be
# called via the dispatch procedure that is returned
# from depspec_new.
#
# sample usage:
# set obj [depspec_new]
# $obj set name "hello"
#

# Depspec
#	str name
#	str provides[]
#	str requires[]
#	str uses[]

global depspec_uniqid
set depspec_uniqid 0

# Depspec class definition.
global depspec_vtbl
set depspec_vtbl(test) depspec_test
set depspec_vtbl(run) depspec_run

# constructor for abstract depspec class
proc depspec_new {name} {
	global depspec_uniqid
	set id [incr depspec_uniqid]
	
	# declare the array of data
	set data dpspc_data_${id}
	set disp dpspc_disp_${id}
	
	global $data 
	set ${data}(name) $name
	set ${data}(_vtbl) depspec_vtbl
	
	eval "proc $disp {method args} { \n \
			global $data \n \
			eval return \\\[depspec_dispatch $disp $data \$method \$args\\\] \n \
		}"
	
	return $disp
}

# is the only proc to get access to the object's data
# so the get/set routines are defined here.  this lets
# the virtual members get a real "this" object.
proc depspec_dispatch {this data method args} {
	global $data
	switch $method {
		get {
			set prop [lindex $args 0]
			if {[eval info exists ${data}($prop)]} {
				eval return $${data}($prop)
			} else {
				return ""
			}
		}
		set {
			set prop [lindex $args 0]
			eval "set ${data}($prop) [lrange $args 1 end]"
		}
		has {
			set prop [lindex $args 0]
			return [info exists ${data}($prop)]
		}
		append {
			set prop [lindex $args 0]
			set vals [join [lrange $args 1 end] " "]
			eval "lappend ${data}($prop) $vals"
		}
		default {
			eval set vtbl $${data}(_vtbl)
			global $vtbl
			if {[info exists ${vtbl}($method)]} {
				eval set function $${vtbl}($method)
				eval "return \[$function $this $args\]"
			} else {
				ui_error "unknown method: $method"
			}
		}
	}
	return ""
}

proc depspec_test {this} {
	return 0
}

proc depspec_run {this} {
	return 0
}

##### target depspec subclass #####

# Target class definition.
global target_vtbl
array set target_vtbl [array get depspec_vtbl]
set target_vtbl(run) target_run

# constructor for target depspec class
proc target_new {name} {
	set obj [depspec_new $name]
	
	$obj set _vtbl target_vtbl

	return $obj
}

##### variant depspec subclass #####

# Variant class definition.
global variant_vtbl
array set variant_vtbl [array get depspec_vtbl]
set variant_vtbl(run) variant_run

# constructor for target depspec class
proc variant_new {name} {
	set obj [depspec_new $name]
	
	$obj set _vtbl variant_vtbl

	return $obj
}



##### portfile depspec subclass #####
global portfile_vtbl
array set portfile_vtbl [array get depspec_vtbl]
set portfile_vtbl(run) portfile_run
set portfile_vtbl(test) portfile_test

proc portfile_new {name} {
	set obj [depspec_new $name]
	
	$obj set _vtbl portfile_vtbl
	
	return $obj
}

# build the specified portfile
proc portfile_run {this} {
	set portname [$this get name]
	
    ui_debug "Building $portname"
    array set options [list]
    array set variations [list]
    array set portinfo [dportmatch ^$portname\$]
    if {[array size portinfo] == 0} {
        ui_error "Dependency $portname not found"
        return -1
    }
    set porturl $portinfo(porturl)

    set worker [dportopen $porturl options variations]
	if {[catch {dportexec $worker clean} result] || $result != 0} {
		ui_error "Clean of $portname before build failed: $result"
		dportclose $worker
		return -1
    }
	if {[catch {dportexec $worker install} result] || $result != 0} {
		ui_error "Build of $portname failed: $result"
		dportclose $worker
		return -1
	}
	if {[catch {dportexec $worker clean} result] || $result != 0} {
		ui_error "Clean of $portname after build failed: $result"
    }
    dportclose $worker
	
	return 0
}

proc portfile_test {this} {
	set receipt [registry_exists [$this get name]]
	if {$receipt != ""} {
		ui_debug "Found Dependency: receipt: $receipt"
		return 1
	} else {
		return 0
	}
}

proc portfile_search_path {depregex search_path} {
	set found 0
    foreach path $search_path {
		if {![file isdirectory $path]} {
			continue
		}
		foreach filename [readdir $path] {
			if {[regexp $depregex $filename] == 1} {
				ui_debug "Found Dependency: path: $path filename: $filename regex: $depregex"
				set found 1
				break
			}
		}
	}
	return $found
}



##### lib portfile depspec subclass #####
global libportfile_vtbl
array set libportfile_vtbl [array get portfile_vtbl]
set libportfile_vtbl(test) libportfile_test

proc libportfile_new {name match} {
	set obj [portfile_new $name]
	
	$obj set _vtbl libportfile_vtbl
	$obj set depregex $match
	
	return $obj
}

# XXX - Architecture specific
# XXX - Rely on information from internal defines in cctools/dyld:
# define DEFAULT_FALLBACK_FRAMEWORK_PATH
# /Library/Frameworks:/Library/Frameworks:/Network/Library/Frameworks:/System/Library/Frameworks
# define DEFAULT_FALLBACK_LIBRARY_PATH /lib:/usr/local/lib:/lib:/usr/lib
# Environment variables DYLD_FRAMEWORK_PATH, DYLD_LIBRARY_PATH,
# DYLD_FALLBACK_FRAMEWORK_PATH, and DYLD_FALLBACK_LIBRARY_PATH take precedence

proc libportfile_test {this} {
	global env prefix 

	# Check the registry first
	set result [portfile_test $this]
	if {$result == 1} {
		return $result
	} else {
		# Not in the registry, check the library path.
		set depregex [$this get depregex]
		
		if {[info exists env(DYLD_FRAMEWORK_PATH)]} {
		lappend search_path $env(DYLD_FRAMEWORK_PATH)
		} else {
		lappend search_path /Library/Frameworks /Network/Library/Frameworks /System/Library/Frameworks
		}
		if {[info exists env(DYLD_FALLBACK_FRAMEWORK_PATH)]} {
		lappend search_path $env(DYLD_FALLBACK_FRAMEWORK_PATH)
		}
		if {[info exists env(DYLD_LIBRARY_PATH)]} {
		lappend search_path $env(DYLD_LIBRARY_PATH)
		} else {
		lappend search_path /lib /usr/local/lib /lib /usr/lib /op/local/lib /usr/X11R6/lib ${prefix}/lib
		}
		if {[info exists env(DYLD_FALLBACK_LIBRARY_PATH)]} {
		lappend search_path $env(DYLD_LIBRARY_PATH)
		}
		regsub {\.} $depregex {\.} depregex
		set depregex \^$depregex.*\\.dylib\$

		return [portfile_search_path $depregex $search_path]
	}
}

##### bin portfile depspec subclass #####
global binportfile_vtbl
array set binportfile_vtbl [array get portfile_vtbl]
set binportfile_vtbl(test) binportfile_test

proc binportfile_new {name match} {
	set obj [portfile_new $name]
	
	$obj set _vtbl binportfile_vtbl
	$obj set depregex $match

	return $obj
}

proc binportfile_test {this} {
	global env prefix 

	# Check the registry first
	set result [portfile_test $this]
	if {$result == 1} {
		return $result
	} else {
		# Not in the registry, check the binary path.
		set depregex [$this get depregex]

		set search_path [split $env(PATH) :]
		
		set depregex \^$depregex\$

		return [portfile_search_path $depregex $search_path]
	}
}
