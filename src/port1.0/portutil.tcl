# et:ts=4
# portutil.tcl
#
# Copyright (c) 2002-2003 Kevin Van Vechten <kevin@opendarwin.org>
# Copyright (c) 2002-2003 Apple Computer, Inc.
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
package require darwinports_dlist 1.0
package require msgcat

global targets target_uniqid all_variants

set targets [list]
set target_uniqid 0

set all_variants [list]

########### External High Level Procedures ###########

namespace eval options {
}

# option
# This is an accessor for Portfile options.  Targets may use
# this in the same style as the standard Tcl "set" procedure.
#	name  - the name of the option to read or write
#	value - an optional value to assign to the option

proc option {_optionName_ args} {
	# XXX: right now we just transparently use globals
	# eventually this will need to bridge the options between
	# the Portfile's interpreter and the target's interpreters.
	global option_defaults option_workers
	global ${_optionName_}
	if {[llength $args] > 0} {
		ui_debug "setting option ${_optionName_} to $args"
		set ${_optionName_} [lindex $args 0]
	}
	global option_defaults
	if {[info exists option_defaults(${_optionName_})]} {
		#ui_debug "reading default value for ${_optionName_} \[option\]"
		set code [catch {$option_workers(${_optionName_}) eval "return $option_defaults(${_optionName_})"} result]
		if {$code != 0 && $code != 2} {
			ui_error "Error evaluation option ${_optionName_} \{$option_defaults(${_optionName_})\}: $result"
			return
		}
		#ui_debug "$option_defaults(${_optionName_}) -> $result"
		return $result
	} else {
		return [set ${_optionName_}]
	}
}

# exists
# This is an accessor for Portfile options.  Targets may use
# this procedure to test for the existence of a Portfile option.
#	name - the name of the option to test for existence

proc exists {name} {
	# XXX: right now we just transparently use globals
	# eventually this will need to bridge the options between
	# the Portfile's interpreter and the target's interpreters.
	global $name
	return [info exists $name]
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
	    global ${option} user_options option_procs \n\
		\if \{!\[info exists user_options(${option})\]\} \{ \n\
		    foreach val \$args \{ \n\
			ldelete ${option} \$val \n\
		    \} \n\
		    if \{\[string length \$${option}\] == 0\} \{ \n\
			unset ${option} \n\
		    \} \n\
			if \{\[info exists option_procs($option)\]\} \{ \n\
			    foreach p \$option_procs($option) \{ \n\
				eval \"\$p $option delete \$args\" \n\
			\} \n\
		    \} \n\
		\} \n\
	\}"
	eval "proc ${option}-append {args} \{ \n\
	    global ${option} user_options option_procs \n\
		\if \{!\[info exists user_options(${option})\]\} \{ \n\
		    if \{\[info exists ${option}\]\} \{ \n\
			set ${option} \[concat \$\{$option\} \$args\] \n\
		    \} else \{ \n\
			set ${option} \$args \n\
		    \} \n\
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

# option_deprecate
# Causes a warning to be printed when an option is set or accessed
proc option_deprecate {option {newoption ""} } {
    # If a new option is specified, default the option to {${newoption}}
    # Display a warning
    if {$newoption != ""} {
    	eval "proc warn_deprecated_$option \{option action args\} \{ \n\
	    global portname $option $newoption \n\
	    if \{\$action != \"read\"\} \{ \n\
	    	$newoption \$$option \n\
	    \} else \{ \n\
	        ui_warn \"Port \$portname using deprecated option \\\"$option\\\".\" \n\
		$option \[set $newoption\] \n\
	    \} \n\
	\}"
    } else {
    	eval "proc warn_deprecated_$option \{option action args\} \{ \n\
	    global portname $option $newoption \n\
	    ui_warn \"Port \$portname using deprecated option \\\"$option\\\".\" \n\
	\}"
    }
    option_proc $option warn_deprecated_$option
}

proc option_proc {option args} {
    global option_procs $option
    eval "lappend option_procs($option) $args"
    # Add a read trace to the variable, as the option procedures have no access to reads
    trace variable $option r option_proc_trace
}

# option_proc_trace
# trace handler for option reads. Calls option procedures with correct arguments.
proc option_proc_trace {optionName index op} {
    global option_procs
    foreach p $option_procs($optionName) {
	eval "$p $optionName read"
    }
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
    if [exists ${command}.dir] {
	set cmdstring "cd [option ${command}.dir] &&"
    }
    
    if [exists ${command}.env] {
	foreach string [option ${command}.env] {
	    set cmdstring "$cmdstring $string"
	}
    }
    
    if [exists ${command}.cmd] {
	foreach string [option ${command}.cmd] {
	    set cmdstring "$cmdstring $string"
	}
    } else {
	set cmdstring "$cmdstring ${command}"
    }
    foreach var "${command}.pre_args ${command}.args ${command}.post_args" {
	if [exists $var] {
	    foreach string [option ${var}] {
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
proc default {ditem option val} {
    global $option option_defaults option_workers
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
	set option_workers($option) [ditem_key $ditem worker]
    set $option $val
    trace variable $option rwu [list default_check $ditem]
}

# default_check
# trace handler to provide delayed variable & command expansion
# for default variable values
proc default_check {ditem optionName index op} {
    global option_defaults $optionName
    switch $op {
	w {
	    unset option_defaults($optionName)
	    trace vdelete $optionName rwu default_check
	    return
	}
	r {
		set $optionName [option $optionName]
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
    global all_variants PortInfo
    upvar $args upargs
    
    set len [llength $args]
    set code [lindex $args end]
    set args [lrange $args 0 [expr $len - 2]]
    
    set ditem [variant_new "temp-variant"]
    
    # mode indicates what the arg is interpreted as.
	# possible mode keywords are: requires, conflicts, provides
	# The default mode is provides.  Arguments are added to the
	# most recently specified mode (left to right).
    set mode "provides"
    foreach arg $args {
		switch -exact $arg {
			provides { set mode "provides" }
			requires { set mode "requires" }
			conflicts { set mode "conflicts" }
			default { ditem_append $ditem $mode $arg }		
        }
    }
    ditem_key $ditem name "[join [ditem_key $ditem provides] -]"

    # make a user procedure named variant-blah-blah
    # we will call this procedure during variant-run
    makeuserproc "variant-[ditem_key $ditem name]" \{$code\}
    lappend all_variants $ditem
    
    # Export provided variant to PortInfo
    lappend PortInfo(variants) [ditem_key $ditem provides]
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
    if {[exists $key]} {
	if {[string equal -nocase [option $key] "yes"]} {
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

    if {[catch {set tmpfile [mktemp "/tmp/[file tail $file].sed.XXXXXXXX"]} error]} {
	ui_error "reinplace: $error"
	return -code error "reinplace failed"
    }

    if {[catch {exec sed $pattern < $file > $tmpfile} error]} {
	ui_error "reinplace: $error"
	file delete "$tmpfile"
	return -code error "reinplace failed"
    }

    if {[catch {exec cp $tmpfile $file} error]} {
	ui_error "reinplace: $error"
	file delete "$tmpfile"
	return -code error "reinplace failed"
    }
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
    regsub -- "^\{(.*?)" $body "\{ \n foreach g \[info globals\] \{ \n global \$g \n \} \n \\1" body
    eval "proc $name {} $body"
}

########### Internal Dependancy Manipulation Procedures ###########

proc target_run {target_state_fd ditem} {
    global portname
    set result 0
    set procedure [ditem_key $ditem procedure]
    if {$procedure != ""} {
	set name [ditem_key $ditem name]
	set worker [ditem_key $ditem worker]
	
	# If the target has an init procedure, execute it.
	if {$worker != {} &&
		[interp eval $worker {return [info commands init]}] != {}} {
		#ui_debug "Initializing $name ($portname)"
	    set result [catch {interp eval $worker "init $name"} errstr]
	}
	
	if {$target_state_fd != "" &&
		[check_statefile target $name $target_state_fd] && $result == 0} {
	    set result 0
	    ui_debug "Skipping completed $name ($portname)"
	} elseif {$result == 0} {
	    # Execute pre-run procedure if it exists
	    if {$worker != {} &&
			[interp eval $worker {return [info commands start]}] != {}} {
			#ui_debug "Starting $name ($portname)"
			set result [catch {interp eval $worker "start $name"} errstr]
	    }

	    #if {$result == 0} {
		#foreach pre [ditem_key $ditem pre] {
		#    ui_debug "Executing $pre"
		#    set result [catch {interp eval $worker "$pre $name"} errstr]
		#    if {$result != 0} { break }
		#}
	    #}
	    
	    if {$result == 0} {
			ui_debug "Executing $name ($portname)"
			set procedure [ditem_key $ditem procedure]
			set result [catch {interp eval $worker "$procedure $name"} errstr]
			if {$result == 0 && $errstr != "0" && $errstr != ""} { set result $errstr }
	    }
	    
	    #if {$result == 0} {
		#foreach post [ditem_key $ditem post] {
		#    ui_debug "Executing $post"
		#    set result [catch {interp eval $worker $post $name} errstr]
		#    if {$result != 0} { break }
		#}
	    #}
	    
		# Execute post-run procedure
	    if {$worker != {} &&
			[interp eval $worker {return [info commands finish]}] != {} && $result == 0} {
		#ui_debug "Finishing $name ($portname)"
		set result [catch {interp eval $worker finish $name} errstr]
	    }
	}
	if {$result == 0} {
	    if {$target_state_fd != "" && [ditem_key $ditem runtype] != "always"} {
			write_statefile target $name $target_state_fd
	    }
	} else {
	    ui_error "Target $name returned: $errstr"
	    set result 1
	}
	
    } else {
	ui_info "Warning: $name does not have a registered procedure"
	set result 1
    }
    
    return $result
}

proc eval_targets {target {keepstate "1"}} {
    global targets portname
    set dlist $targets
	    
	# Select the subset of targets under $target
    if {$target != ""} {
        set matches [dlist_search $dlist provides $target]
		
        if {[llength $matches] > 0} {
			set origdlist $dlist
			set dlist {}
			foreach match $matches {
				eval "lappend dlist [dlist_append_dependents $origdlist $match [list]]"
			}
			set dlist [lsort -unique $dlist]
		} else {
			ui_error "unknown target: $target"
            return 1
        }
    }
	
	# XXX: this should not use a global, we need to be re-entrant.
	
    # Restore the state from a previous run.
    if {$keepstate} { 
		set target_state_fd [open_statefile]
	} else {
		set target_state_fd ""
	}

    array set statusdict [dlist_eval $dlist "" [list target_run $target_state_fd] canfail]

	# Make sure we got to the destination target
	if {![info exists statusdict($target)] || $statusdict($target) != 1} {
		# somebody broke!
		ui_info "Warning: the following items did not execute (for $portname): "
		foreach ditem $dlist {
			ui_info "[ditem_key $ditem name] " -nonewline
		}
		ui_info ""
		set result 1
	} else {
		set result 0
	}
	
    if {$keepstate} { close $target_state_fd }
    return $result
}

# open_statefile
# open file to store name of completed targets
proc open_statefile {args} {
    global workpath portname portpath ports_ignore_older

    if ![file isdirectory $workpath ] {
	file mkdir $workpath
    }
    # flock Portfile
    set statefile [file join $workpath .darwinports.${portname}.state]
    if {[file exists $statefile]} {
		if {![file writable $statefile]} {
			return -code error "$statefile is not writable - check permission on port directory"
		}
		if {!([info exists ports_ignore_older] && $ports_ignore_older == "yes") && [file mtime $statefile] < [file mtime ${portpath}/Portfile]} {
			ui_msg "Portfile changed since last build; discarding previous state."
			#file delete $statefile
			exec rm -rf [file join $workpath]
			exec mkdir [file join $workpath]
		}
	}
	
    set fd [open $statefile a+]
    if [catch {flock $fd -exclusive -noblock} result] {
        if {"$result" == "EAGAIN"} {
            ui_msg "Waiting for lock on $statefile"
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
# Check completed/selected state of target/variant $name
proc check_statefile {class name fd} {
    global portpath workdir
    	
    seek $fd 0
    while {[gets $fd line] >= 0} {
		if {$line == "$class: $name"} {
			return 1
		}
    }
    return 0
}

# write_statefile
# Set target $name completed in the state file
proc write_statefile {class name fd} {
    if {[check_statefile $class $name $fd]} {
		return 0
    }
    seek $fd 0 end
    puts $fd "$class: $name"
    flush $fd
}

# check_statefile_variants
# Check that recorded selection of variants match the current selection
proc check_statefile_variants {variations fd} {
	upvar $variations upvariations
	
    seek $fd 0
    while {[gets $fd line] >= 0} {
		if {[regexp "variant: (.*)" $line match name]} {
			set oldvariations([string range $name 1 end]) [string range $name 0 0]
		}
    }

	set mismatch 0
	if {[array size oldvariations] > 0} {
		if {[array size oldvariations] != [array size upvariations]} {
			set mismatch 1
		} else {
			foreach key [array names upvariations *] {
				if {$upvariations($key) != $oldvariations($key)} {
					set mismatch 1
					break
				}
			}
		}
	}

	return $mismatch
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
    
    foreach ditem $dlist {
	# Enumerate through the provides, tallying the pros and cons.
	set pros 0
	set cons 0
	set ignored 0
	foreach flavor [ditem_key $ditem provides] {
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
	    lappend selected $ditem
	}
    }
    return $selected
}

proc variant_run {ditem} {
    set name [ditem_key $ditem name]
    ui_debug "Executing $name provides [ditem_key $ditem provides]"

	# test for conflicting variants
	foreach v [ditem_key $ditem conflicts] {
		if {[variant_isset $v]} {
			ui_error "Variant $name conflicts with $v"
			return 1
		}
	}

    # execute proc with same name as variant.
    if {[catch "variant-${name}" result]} {
	ui_error "Error executing $name: $result"
	return 1
    }
    return 0
}

proc eval_variants {variations target} {
    global all_variants ports_force
    set dlist $all_variants
	set result 0
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
    
    dlist_eval $newlist "" variant_run
	
	# Make sure the variations match those stored in the statefile.
	# If they don't match, print an error indicating a 'port clean' 
	# should be performed.  
	# - Skip this test if the statefile is empty.
	# - Skip this test if performing a clean.
	# - Skip this test if ports_force was specified.

	if {$target != "clean" && 
		!([info exists ports_force] && $ports_force == "yes")} {
		set state_fd [open_statefile]
	
		if {[check_statefile_variants upvariations $state_fd]} {
			ui_error "Requested variants do not match original selection.\nPlease perform 'port clean' or specify the force option."
			set result 1
		} else {
			# Write variations out to the statefile
			foreach key [array names upvariations *] {
				write_statefile variant $upvariations($key)$key $state_fd
			}
		}
		
		close $state_fd
	}
	
	return $result
}

# Target class definition.

# constructor for target object
proc target_new {name procedure} {
    global targets
    set ditem [ditem_create]
	
	ditem_key $ditem name $name
	ditem_key $ditem procedure $procedure
    
    lappend targets $ditem
    
    return $ditem
}

proc make_custom_target {name requires uses runtype args} {
	set tname "custom-${name}" 
ui_debug "creating target $tname requires $requires"	
	set ditem [target_new $tname $tname]
	# custom targets simply run in the Portfile's interpreter
	ditem_key $ditem worker {}
	ditem_key $ditem procedure $tname
	# we provide our customized name, and the name of what we're replacing
	ditem_key $ditem provides [list $name $tname]
	ditem_key $ditem requires $requires
	ditem_key $ditem uses $uses
	if {$runtype != ""} { ditem_key $ditem runtype $runtype }

	if {[llength $args] == 0} { set args {{}} }
	eval "makeuserproc userproc-${tname} $args"
	eval "proc $tname \{args\} \{ \n\
		if \{\[catch userproc-${tname} result\]\} \{ \n\
			return -code error \$result \n\
		\} else \{ \n\
			return 0 \n\
		\} \n\
	\}"
	
	# Use this custom procedure, and none other
	use $tname
	return $ditem
}

proc target_provides {ditem args} {
    eval "ditem_append $ditem provides $args"
	# We run after each pre-hook
	foreach token $args {
		eval "ditem_append $ditem uses pre-${token}"
	}
}

proc target_requires {ditem args} {
    eval "ditem_append $ditem requires $args"
	# We run after each post-hook
	foreach token $args {
		eval "ditem_append $ditem uses post-${token}"
	}
}

proc target_uses {ditem args} {
    eval "ditem_append $ditem uses $args"
}

proc target_deplist {ditem args} {
    eval "ditem_append $ditem deplist $args"
}

proc target_prerun {ditem args} {
    eval "ditem_append $ditem prerun $args"
}

proc target_postrun {ditem args} {
    eval "ditem_append $ditem postrun $args"
}

proc target_runtype {ditem args} {
	eval "ditem_append $ditem runtype $args"
}

proc target_init {ditem args} {
    eval "ditem_append $ditem init $args"
}

# use
# Specifies that a specific target should be used instead of
# any alternative target with the same name.  The target with
# the given name is found, and all targets whose provides list
# intersect with it will be disabled.
#	name - the name of the target to use
proc use {name} {
    global targets
	ui_debug "use $name:"
	# Find the target which provides the name
	set target [dlist_search $targets provides $name]
	# Disable everything that provides the same services.
	foreach token [ditem_key $target provides] {
		if {$token == $name} { continue }
		set intersections [dlist_search $targets provides $token]
		foreach other $intersections {
			if {$other == $target} { continue }
			ui_debug "  suppressing [ditem_key $other name]"
			dlist_delete targets $other
		}
	}
	# Call to the target to set defaults
	set worker [ditem_key $target worker]
	if {$worker != {}} {
		catch {$worker eval "set_defaults"}
	}
}

##### variant class #####

# constructor for variant objects
proc variant_new {name} {
    set ditem [ditem_create]
    ditem_key $ditem name $name
    return $ditem
}

proc handle_default_variants {option action args} {
    global variations
    switch -regex $action {
	set|append {
	    foreach v $args {
		if {[regexp {([-+])([-A-Za-z0-9_]+)} $v whole val variant]} {
		    if {![info exists variations($variant)]} {
			set variations($variant) $val
		    }
		}
	    }
	}
	delete {
	    # xxx
	}
    }
}


# builds the specified port (looked up in the index) to the specified target
# doesn't yet support options or variants...
# newworkpath defines the port's workpath - useful for when one port relies
# on the source, etc, of another
proc portexec_int {portname target {newworkpath ""}} {
    ui_debug "Executing $target ($portname)"
    set variations [list]
    if {$newworkpath == ""} {
        array set options [list]
    } else {
        set options(workpath) ${newworkpath}
    }
	# Escape regex special characters
	regsub -all "(\\(){1}|(\\)){1}|(\\{1}){1}|(\\+){1}|(\\{1}){1}|(\\{){1}|(\\}){1}|(\\^){1}|(\\$){1}|(\\.){1}|(\\\\){1}" $portname "\\\\&" search_string 

    set res [dportsearch ^$search_string\$]
    if {[llength $res] < 2} {
        ui_error "Dependency $portname not found"
        return -1
    }

    array set portinfo [lindex $res 1]
    set porturl $portinfo(porturl)
    if {[catch {set worker [dportopen $porturl [array get options] $variations]} result]} {
        ui_error "Opening $portname $target failed: $result"
        return -1
    }
    if {[catch {dportexec $worker $target} result] || $result != 0} {
        ui_error "Execution $portname $target failed: $result"
        dportclose $worker
        return -1
    }
    dportclose $worker
    
    return 0
}


proc adduser {name args} {
    global os.platform
    set passwd {\*}
    set uid [nextuid]
    set gid [existsgroup nogroup]
    set realname ${name}
    set home /dev/null
    set shell /dev/null

    foreach arg $args {
	if {[regexp {([a-z]*)=(.*)} $arg match key val]} {
	    regsub -all " " ${val} "\\ " val
	    set $key $val
	}
    }

    if {[existsuser ${name}] != 0 || [existsuser ${uid}] != 0} {
	return
    }

    if {${os.platform} == "darwin"} {
	system "niutil -create . /users/${name}"
	system "niutil -createprop . /users/${name} name ${name}"
	system "niutil -createprop . /users/${name} passwd ${passwd}"
	system "niutil -createprop . /users/${name} uid ${uid}"
	system "niutil -createprop . /users/${name} gid ${gid}"
	system "niutil -createprop . /users/${name} realname ${realname}"
	system "niutil -createprop . /users/${name} home ${home}"
	system "niutil -createprop . /users/${name} shell ${shell}"
    } else {
	# XXX adduser is only available for darwin, add more support here
	ui_warn "WARNING: adduser is not implemented on ${os.platform}."
	ui_warn "The requested user was not created."
    }
}

proc addgroup {name args} {
    global os.platform
    set gid [nextgid]
    set passwd {\*}
    set users ""

    foreach arg $args {
	if {[regexp {([a-z]*)=(.*)} $arg match key val]} {
	    regsub -all " " ${val} "\\ " val
	    set $key $val
	}
    }

    if {[existsgroup ${name}] != 0 || [existsgroup ${gid}] != 0} {
	return
    }

    if {${os.platform} == "darwin"} {
	system "niutil -create . /groups/${name}"
	system "niutil -createprop . /groups/${name} name ${name}"
	system "niutil -createprop . /groups/${name} gid ${gid}"
	system "niutil -createprop . /groups/${name} passwd ${passwd}"
	system "niutil -createprop . /groups/${name} users ${users}"
    } else {
	# XXX addgroup is only available for darwin, add more support here
	ui_warn "WARNING: addgroup is not implemented on ${os.platform}."
	ui_warn "The requested group was not created."
    }
}
