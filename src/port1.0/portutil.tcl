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

set target_uniqid 0

########### External High Level Procedures ###########

# options
# Exports options in an array as externally callable procedures
# Thus, "options name date" would create procedures named "name"
# and "date" that set global variables "array" and "date", respectively
# Arguments: <list of options>
proc options {args} {
    foreach option $args {
    	eval "proc $option {args} \{ \n\
	    global ${option} user_options \n\
		\if \{!\[info exists user_options(${option})\]\} \{ \n\
		     set ${option} \$args \n\
			 if \{\[info commands options::${option}\] != \"\"\} \{ \n\
			     options::${option} ${option} \n\
			 \} \n\
		\} \n\
	\}"

	eval "proc ${option}-delete {args} \{ \n\
	    global ${option} user_options \n\
		\if \{!\[info exists user_options(${option})\]\} \{ \n\
		    upvar #0 ${option} uplist \n\
		    foreach val \$args \{ \n\
				ldelete uplist \$val \n\
				if \{\[info commands options::${option}\] != \"\"\} \{ \n\
				    options::${option} ${option} \n\
				\} \n\
			\} \n\
		\} \n\
	\}"
	eval "proc ${option}-append {args} \{ \n\
	    global ${option} user_options \n\
		\if \{!\[info exists user_options(${option})\]\} \{ \n\
		    upvar #0 ${option} uplist \n\
		    set uplist \[concat \$uplist \$args\] \n\
			if \{\[info commands options::${option}\] != \"\"\} \{ \n\
			    options::${option} ${option} \n\
			\} \n\
		\} \n\
	\}"
    }
}

proc commands {args} {
    foreach option $args {
	options use_${option} ${option}.dir ${option}.pre_args ${option}.args ${option}.post_args ${option}.env ${option}.type ${option}.cmd
    }
}

proc command {command} {
    global ${command}.dir ${command}.pre_args ${command}.args ${command}.post_args ${command}.env ${command}.type ${command}.cmd

    set cmdstring ""
    if [info exists ${command}.dir] {
	upvar #0 ${command}.dir upstring
	set cmdstring "cd $upstring &&"
    }

    if [info exists ${command}.env] {
	upvar #0 ${command}.env upstring
	set cmdstring "$cmdstring $upstring"
    }

    if [info exists ${command}.cmd] {
	upvar #0 ${command}.cmd upstring
	set cmdstring "$cmdstring $upstring"
    } else {
	lappend cmdstring ${command}
	set cmdstring "$cmdstring $command"
    }
    foreach var "${command}.pre_args ${command}.args ${command}.post_args" {
	if [info exists $var] {
	    upvar #0 ${var} upstring
	    set cmdstring "$cmdstring $upstring"
	}
    }
    return $cmdstring
}

# default
proc default {option val} {
    global $option
	if {[trace vinfo $option)] != ""} {
		ui_debug "Re-registering default for $option"
	} else {
		# If option is already set and we did not set it
		# do not reset the value
		if {[info exists $option]} {
#			ui_debug "Default for $option ignored; option was already set external to default procedure"
			return
		}
	}
	set $option $val
	trace variable $option rwu default_check
}

proc default_check {optionName index op} {
	global $optionName
	switch $op {
		w {
			trace vdelete $optionName rwu default_check
			return
		}
		r {
			upvar $optionName option
			uplevel #0 "set $optionName $option" 
			return
		}
		u {
			trace vdelete $optionName rwu default_check
			return
		}
	}
}

# variant <provides> [<provides> ...] [requires <requires> [<requires>]]
proc variant {args} {
    global variants
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
    dlist_add_item variants $name
    dlist_append_key variants $name provides $provides
    dlist_append_key variants $name requires $requires
    dlist_set_key variants $name procedure $code
}

########### Misc Utility Functions ###########

proc tbool {key} {
    upvar $key upkey
    if {[info exists upkey]} {
	if {[string equal -nocase $upkey "yes"]} {
	    return 1
	}
    }
    return 0
}

proc ldelete {list value} {
    upvar $list uplist
    set ix [lsearch -exact $uplist $value]
    if {$ix >= 0} {
	set uplist [lreplace $uplist $ix $ix]
    }
}

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
#	<identifier> target <procedure to execute> <init procedure> [run type]
#	<identifier> provides <list of target names>
#	<identifier> requires <list of target names>
#	<identifier> uses <list of target names>
#	<identifier> preflight <target name>
#	<identifier> postflight <target name>
proc register {name mode args} {
    global targets target_uniqid
    dlist_add_item targets $name

    if {[string equal target $mode]} {
        set procedure [lindex $args 0]
        set init [lindex $args 1]
        if {[dlist_has_key targets $name procedure]} {
            ui_debug "Warning: target '$name' re-registered (new procedure: '$procedure')"
        }
        dlist_set_key targets $name procedure $procedure
        dlist_set_key targets $name init $init

	# Set runtype {always,once} if available
	if {[llength $args] == 3} {
	    dlist_set_key targets $name runtype [lindex $args 2]
	}
    } elseif {[string equal requires $mode] || [string equal uses $mode] || [string equal provides $mode]} {
        if {[dlist_has_item targets $name]} {
            dlist_append_key targets $name $mode $args
        } else {
            ui_info "Warning: target '$name' not-registered in register $mode"
        }
        
        if {[string equal provides $mode]} {
            # If it's a provides, register the pre-/post- hooks for use in Portfile.
            # Portfile syntax: pre-fetch { puts "hello world" }
            # User-code exceptions are caught and returned as a result of the target.
            # Thus if the user code breaks, dependent targets will not execute.
            foreach target $args {
		if {[info commands $target] != ""} {
		    ui_error "$name attempted to register provide \'$target\' which is a pre-existing procedure. Ignoring register."
		    continue;
		}
                set id [incr target_uniqid]
                set ident [lindex [dlist_get_matches targets provides $args] 0]
                set origproc [dlist_get_key targets $ident procedure]
                eval "proc $target {args} \{ \n\
                    register $ident target proc-$target$id \n\
                    proc proc-$target$id \{name\} \{ \n\
                        if \[catch userproc-$target$id result\] \{ \n\
							ui_info \$result \n\
							return 1 \n\
						\} else \{ \n\
							return 0 \n\
						\} \n\
                    \} \n\
                    eval \"proc do-$target \{\} \{ $origproc $target\}\" \n\
                    makeuserproc userproc-$target$id \$args \}"
                eval "proc pre-$target {args} \{ \n\
                    register pre-$target$id target proc-pre-$target$id \n\
                    register pre-$target$id preflight $target \n\
                    proc proc-pre-$target$id \{name\} \{ \n\
                        if \[catch userproc-pre-$target$id result\] \{ \n\
							ui_info \$result \n\
							return 1 \n\
						\} else \{ \n\
							return 0 \n\
						\} \n\
                    \} \n\
                    makeuserproc userproc-pre-$target$id \$args \}"
                eval "proc post-$target {args} \{ \n\
                    register post-$target$id target proc-post-$target$id \n\
                    register post-$target$id postflight $target \n\
                    proc proc-post-$target$id \{name\} \{ \n\
                        if \[catch userproc-post-$target$id result\] \{ \n\
							ui_info \$result \n\
							return 1 \n\
						\} else \{ \n\
							return 0 \n\
						\} \n\
                    \} \n\
                    makeuserproc userproc-post-$target$id \$args \}"
            }
        }
	
    } elseif {[string equal preflight $mode]} {
	# preflight vulcan mind meld:
	# "your requirements to my requirements; my provides to your requirements"
	
	dlist_append_key targets $name provides $name-pre-$args
	# XXX: this only returns the first match, is this what we want?
	set ident [lindex [dlist_get_matches targets provides $args] 0]
	
	dlist_append_key targets $name requires \
	    [dlist_get_key targets $ident requires]
	dlist_append_key targets $ident requires \
	    [dlist_get_key targets $name provides]
	
    } elseif {[string equal postflight $mode]} {
	# postflight procedure:
	
	dlist_append_key targets $name provides $name-post-$args
		
	set ident [lindex [dlist_get_matches targets provides $args] 0]

	# your provides to my requires
	dlist_append_key targets $name requires \
	    [dlist_get_key targets $ident provides]
	
	# my provides to the requires of your children
	foreach token [join [dlist_get_key targets $ident provides]] {
	    set matches [dlist_get_matches targets requires $token]
	    foreach match $matches {
		# don't want to require ourself
		if {![string equal $match $name]} {
		    dlist_append_key targets $match requires $name-post-$args
		}
	    }
	}
    }
}

# unregister
# Unregisters a target in the global target list
# Arguments: target <target name>
proc unregister {mode target} {
}

########### Internal Dependancy Manipulation Procedures ###########

# Dependency List (dlist)
# The dependency list is really just one big array.  (I would have
# liked to make this nested arrays, but that's not feasible in Tcl,
# thus we'll use the $fieldname,$groupname syntax to mimic structures.
#
# Dependency lists may contain private data, via the 
# dlist_*_key APIs.  However, it must be recognized that the
# following keys are reserved for use by the evaluation engine.
# (Don't fret, you want these keys anyway, honest.)  These keys also
# have predefined accessor APIs to remind you of their significance.
#
# Reserved keys: 
# name		- The unique identifier of the item.  No Commas!
# provides	- The list of tokens this item provides
# requires	- The list of hard-dependency tokens
# uses		- The list of soft-dependency tokens
# runtype	- The runtype of the item {always,once}

# Sets the key/value to an item in the dependency list
proc dlist_set_key {dlist name key args} {
    upvar $dlist uplist
    # might be keen to validate $name here.
    eval "set uplist($key,$name) $args"
}

# Appends the value to the list stored at the key of the item
proc dlist_append_key {dlist name key args} {
    upvar $dlist uplist
    if {![dlist_has_key uplist $name $key]} { set uplist($key,$name) [list] }
    eval "lappend uplist($key,$name) [join $args]"
}

# Return true if the key exists for the item, false otherwise
proc dlist_has_key {dlist name key} {
    upvar $dlist uplist
    return [info exists uplist($key,$name)]
}

# Retrieves the value of the key of an item in the dependency list
proc dlist_get_key {dlist name key} {
    upvar $dlist uplist
    if {[info exists uplist($key,$name)]} {
	return $uplist($key,$name)
    } else {
	return ""
    }
}

# Adds a colorless odorless item to the dependency list
proc dlist_add_item {dlist name} {
    upvar $dlist uplist
    set uplist(name,$name) $name
}

# Deletes all keys of the specified item
proc dlist_remove_item {dlist name} {
    upvar $dlist uplist
    array unset uplist *,$name
}

# Tests if the item is present in the dependency list
proc dlist_has_item {dlist name} {
    upvar $dlist uplist
    return [info exists uplist(name,$name)]
}

# Return a list of names of items that provide the given name
proc dlist_get_matches {dlist key value} {
    upvar $dlist uplist
    set result [list]
    foreach ident [array names uplist name,*] {
	set name $uplist($ident)
	foreach val [dlist_get_key uplist $name $key] {
	    if {[string equal $val $value] && 
		![info exists ${result}($name)]} {
		lappend result $name
	    }
	}
    }
    return $result
}

# Count the unmet dependencies in the dlist based on the statusdict
proc dlist_count_unmet {names statusdict} {
    upvar $statusdict upstatusdict
    set unmet 0
    foreach name $names {
	if {![info exists upstatusdict($name)] ||
	    ![string equal $upstatusdict($name) success]} {
	    incr unmet
	}
    }
    return $unmet
}

# Returns true if any of the dependencies are pending in the dlist
proc dlist_has_pending {dlist uses} {
    foreach name $uses {
	if {[info exists ${dlist}(name,$name)]} { 
	    return 1
	}
    }
    return 0
}

# Get the name of the next eligible item from the dependency list
proc dlist_get_next {dlist statusdict} {
    set nextitem ""
    # arbitrary large number ~ INT_MAX
    set minfailed 2000000000
    upvar $dlist uplist
    upvar $statusdict upstatusdict
    
    foreach n [array names uplist name,*] {
	set name $uplist($n)
	
	# skip if unsatisfied hard dependencies
	if {[dlist_count_unmet [dlist_get_key uplist $name requires] upstatusdict]} { continue }
	
	# favor item with fewest unment soft dependencies
	set unmet [dlist_count_unmet [dlist_get_key uplist $name uses] upstatusdict]
	
	# delay items with unmet soft dependencies that can be filled
	if {$unmet > 0 && [dlist_has_pending dlist [dlist_get_key uplist $name uses]]} { continue }
	
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


# Evaluate the dlist, invoking action on each name in the dlist as it
# becomes eligible.
proc dlist_evaluate {dlist downstatusdict action} {
    # dlist - nodes waiting to be executed
    upvar $dlist uplist
    upvar $downstatusdict statusdict
    
    # status - keys will be node names, values will be success or failure.
    array set statusdict [list]
    
    # loop for as long as there are nodes in the dlist.
    while (1) {
	set name [dlist_get_next uplist statusdict]
	if {[string length $name] == 0} { 
	    break
	} else {
	    set result [eval $action uplist $name]
	    foreach token $uplist(provides,$name) {
		array set statusdict [list $token $result]
	    }
	    dlist_remove_item uplist $name
	}
    }
    
    set names [array names uplist name,*]
	if { [llength $names] > 0} {
		# somebody broke!
		ui_info "Warning: the following items did not execute: "
		foreach name $names {
			ui_info "$uplist($name) " -nonewline
		}
		ui_info ""
		return 1
    }
	return 0
}

proc exec_target {fd dlist name} {
# XXX: Don't depend on entire dlist, this should really receive just one node.
    upvar $dlist uplist
    if {[dlist_has_key uplist $name procedure] && [dlist_has_key uplist $name init]} {
	set procedure [dlist_get_key uplist $name procedure]
	set init [dlist_get_key uplist $name init]
	if {"$init" != ""} {
	    $init $name
	}
	if {[check_statefile $name $fd]} {
	    set result 0
	    ui_debug "Skipping completed $name"
	} else {
	    ui_debug "Executing $name"
	    set result [$procedure $name]
	}
	if {$result == 0} {
	    set result success
	    if {[dlist_get_key uplist $name runtype] != "always"} {
		write_statefile $name $fd
	    }
	} else {
	    ui_error "Target error: $name returned $result"
	    set result failure
	}
    } else {
	ui_info "Warning: $name does not have a registered procedure"
	set result failure
    }
    return $result
}

proc eval_targets {dlist target} {
    upvar $dlist uplist
	
    # Select the subset of targets under $target
    if {[string length $target] > 0} {
		# XXX munge target. install really means registry, then install
		# If more than one target ever needs this, make this a generic interface
		if {[string equal $target "install"]} {
			set target registry
		}
        set matches [dlist_get_matches uplist provides $target]
        if {[llength $matches] > 0} {
            array set dependents [list]
            dlist_append_dependents dependents uplist [lindex $matches 0]
            array unset uplist
            array set uplist [array get dependents]
            # Special-case 'all'
        } elseif {![string equal $target all]} {
            ui_info "Warning: unknown target: $target"
            return
        }
    }
    
    array set statusdict [list]
    
    # Restore the state from a previous run.
    set fd [open_statefile]
    
    set ret [dlist_evaluate uplist statusdict [list exec_target $fd]]

    close $fd
	return $ret
}

# select dependents of <name> from the <itemlist>
# adding them to <dependents>
proc dlist_append_dependents {dependents dlist name} {
    upvar $dependents updependents
    upvar $dlist uplist

    # Append item to the list, avoiding duplicates
    if {![info exists updependents(name,$name)]} {
	set names [array names uplist *,$name]
        foreach n $names {
            set updependents($n) $uplist($n)
        }
    }
    
    # Recursively append any hard dependencies
    if {[info exists uplist(requires,$name)]} {
        foreach dep $uplist(requires,$name) {
            foreach provide [dlist_get_matches uplist provides $dep] {
                dlist_append_dependents updependents uplist $provide
            }
        }
    }
    
    # XXX: add soft-dependencies?
}

# open_statefile
# open file to store name of completed targets
proc open_statefile {args} {
    global portpath workdir

    if ![file isdirectory $portpath/$workdir] {
	file mkdir $portpath/$workdir
    }
    set fd [open "$portpath/$workdir/.darwinports.state" a+]
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
proc choose_variants {variants variations} {
    upvar $variants upvariants 
    upvar $variations upvariations

    set selected [list]
    
    foreach n [array names upvariants name,*] {
		set name $upvariants($n)
		
		# Enumerate through the provides, tallying the pros and cons.
		set pros 0
		set cons 0
		set ignored 0
		foreach flavor [dlist_get_key upvariants $name provides] {
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
			lappend selected $name
		}
	}
    return $selected
}

proc exec_variant {dlist name} {
# XXX: Don't depend on entire dlist, this should really receive just one node.
    upvar $dlist uplist
    ui_debug "Executing $name"
    makeuserproc $name-code "\{[dlist_get_key uplist $name procedure]\}"
    $name-code
    return success
}

proc eval_variants {dlist variations} {
    upvar $dlist uplist
	upvar $variations upvariations

	set chosen [choose_variants uplist upvariations]

    # now that we've selected variants, change all provides [a b c] to [a-b-c]
    # this will eliminate ambiguity between item a, b, and a-b while fulfilling requirments.
    foreach n [array names uplist provides,*] {
        array set uplist [list $n [join $uplist($n) -]]
    }
	
	array set dependents [list]
    foreach variant $chosen {
        dlist_append_dependents dependents uplist $variant
    }
	array unset uplist
	array set uplist [array get dependents]
    
    array set statusdict [list]
        
    dlist_evaluate uplist statusdict [list exec_variant]
}

