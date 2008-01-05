# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portutil.tcl
# $Id$
#
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2002 Apple Computer, Inc.
# Copyright (c) 2006, 2007 Markus W. Weissmann <mww@macports.org>
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
package require macports_dlist 1.0
package require macports_util 1.0
package require msgcat
package require porttrace 1.0

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
#   name  - the name of the option to read or write
#   value - an optional value to assign to the option

proc option {name args} {
    # XXX: right now we just transparently use globals
    # eventually this will need to bridge the options between
    # the Portfile's interpreter and the target's interpreters.
    global $name
    if {[llength $args] > 0} {
        ui_debug "setting option $name to $args"
        set $name [lindex $args 0]
    }
    return [set $name]
}

# exists
# This is an accessor for Portfile options.  Targets may use
# this procedure to test for the existence of a Portfile option.
#   name - the name of the option to test for existence

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
        proc $option {args} [subst -nocommands {
            global $option user_options option_procs
            if {![info exists user_options($option)]} {
                set $option \$args
            }
        }]
        proc ${option}-delete {args} [subst -nocommands {
            global $option user_options option_procs
            if {![info exists user_options($option)] && [info exists $option]} {
                set temp [set $option]
                foreach val \$args {
                   set temp [ldelete \$temp \$val]
                }
                if {\$temp eq ""} {
                    unset $option
                } else {
                    set $option \$temp
                }
            }
        }]
        proc ${option}-append {args} [subst -nocommands {
            global $option user_options option_procs
            if {![info exists user_options($option)]} {
                if {[info exists $option]} {
                    set $option [concat \${$option} \$args]
                } else {
                    set $option \$args
                }
            }
        }]
    }
}

proc options_export {args} {
    foreach option $args {
        proc options::export-${option} {option action {value ""}} [subst -nocommands {
            global $option PortInfo
            switch \$action {
                set {
                    set PortInfo($option) \$value
                }
                delete {
                    unset PortInfo($option)
                }
            }
        }]
        option_proc $option options::export-$option
    }
}

# option_deprecate
# Causes a warning to be printed when an option is set or accessed
proc option_deprecate {option {newoption ""} } {
    # If a new option is specified, default the option to {${newoption}}
    # Display a warning
    if {$newoption != ""} {
        proc warn_deprecated_${option} {option action args} [subst -nocommands {
            global portname $option $newoption
            if {\$action != "read"} {
                $newoption \$$option
            } else {
                ui_warn "Port \$portname using deprecated option \\\"$option\\\"."
                $option \[set $newoption\]
            }
        }]
    } else {
        proc warn_deprecated_$option {option action args} [subst -nocommands {
            global portname $option $newoption
            ui_warn "Port \$portname using deprecated option \\\"$option\\\"."
        }]
    }
    option_proc $option warn_deprecated_$option
}

proc option_proc {option args} {
    global option_procs $option
    if {[info exists option_procs($option)]} {
        set option_procs($option) [concat $option_procs($option) $args]
        # we're already tracing
    } else {
        set option_procs($option) $args
        trace add variable $option {read write unset} option_proc_trace
    }
}

# option_proc_trace
# trace handler for option reads. Calls option procedures with correct arguments.
proc option_proc_trace {optionName index op} {
    global option_procs
    upvar $optionName $optionName
    switch $op {
        write {
            foreach p $option_procs($optionName) {
                $p $optionName set [set $optionName]
            }
        }
        read {
            foreach p $option_procs($optionName) {
                $p $optionName read
            }
        }
        unset {
            foreach p $option_procs($optionName) {
                if {[catch {$p $optionName delete} result]} {
                    ui_debug "error during unset trace ($p): $result\n$::errorInfo"
                }
            }
            trace add variable $optionName {read write unset} option_proc_trace
        }
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

# Given a command name, assemble a command string
# composed of the command options.
proc command_string {command} {
    global ${command}.dir ${command}.pre_args ${command}.args ${command}.post_args ${command}.cmd
    
    if {[info exists ${command}.dir]} {
        append cmdstring "cd \"[set ${command}.dir]\" &&"
    }
    
    if {[info exists ${command}.cmd]} {
        foreach string [set ${command}.cmd] {
            append cmdstring " $string"
        }
    } else {
        append cmdstring " ${command}"
    }

    foreach var "${command}.pre_args ${command}.args ${command}.post_args" {
        if {[info exists $var]} {
            foreach string [set ${var}] {
                append cmdstring " ${string}"
            }
        }
    }

    ui_debug "Assembled command: '$cmdstring'"
    return $cmdstring
}

# Given a command name, execute it with the options.
# command_exec command [-notty] [command_prefix [command_suffix]]
# command           name of the command
# command_prefix    additional command prefix (typically pipe command)
# command_suffix    additional command suffix (typically redirection)
proc command_exec {command args} {
    global ${command}.env ${command}.env_array env
    set notty 0
    set command_prefix ""
    set command_suffix ""

    if {[llength $args] > 0} {
        if {[lindex $args 0] == "-notty"} {
            set notty 1
            set args [lrange $args 1 end]
        }

        if {[llength $args] > 0} {
            set command_prefix [lindex $args 0]
            if {[llength $args] > 1} {
                set command_suffix [lindex $args 1]
            }
        }
    }
    
    # Set the environment.
    # If the array doesn't exist, we create it with the value
    # coming from ${command}.env
    # Otherwise, it means the caller actually played with the environment
    # array already (e.g. configure flags).
    if {![array exists ${command}.env_array]} {
        parse_environment ${command}
    }
    if {[option macosx_deployment_target] ne ""} {
        append_list_to_environment_value ${command} "MACOSX_DEPLOYMENT_TARGET" [option macosx_deployment_target]
    }
    
    # Debug that.
    ui_debug "Environment: [environment_array_to_string ${command}.env_array]"

    # Get the command string.
    set cmdstring [command_string ${command}]
    
    # Call this command.
    # TODO: move that to the system native call?
    # Save the environment.
    array set saved_env [array get env]
    # Set the overriden variables from the portfile.
    array set env [array get ${command}.env_array]
    # Call the command.
    set fullcmdstring "$command_prefix $cmdstring $command_suffix"
    if {$notty} {
        set code [catch {system -notty $fullcmdstring} result]
    } else {
        set code [catch {system $fullcmdstring} result]
    }
    # Unset the command array until next time.
    array unset ${command}.env_array
    
    # Restore the environment.
    array unset env *
    array set env [array get saved_env]

    # Return as if system had been called directly. 
    return -code $code $result
}

# default
# Sets a variable to the supplied default if it does not exist,
# and adds a variable trace. The variable traces allows for delayed
# variable and command expansion in the variable's default value.
proc default {option val} {
    global $option option_defaults
    if {[info exists option_defaults($option)]} {
        ui_debug "Re-registering default for $option"
        # remove the old trace
        trace vdelete $option rwu default_check
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
    global all_variants PortInfo
    
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
            description -
            provides -
            requires -
            conflicts { set mode $arg }
            default { ditem_append $ditem $mode $arg }      
        }
    }
    ditem_key $ditem name "[join [ditem_key $ditem provides] -]"

    # make a user procedure named variant-blah-blah
    # we will call this procedure during variant-run
    makeuserproc "variant-[ditem_key $ditem name]" \{$code\}
    
    # Export provided variant to PortInfo
    # (don't list it twice if the variant was already defined, which can happen
    # with universal or group code).
    set variant_provides [ditem_key $ditem provides]
    if {[variant_exists $variant_provides]} {
        # This variant was already defined. Remove it from the dlist.
        variant_remove_ditem $variant_provides
    } else {
        lappend PortInfo(variants) $variant_provides
        set vdesc [join [ditem_key $ditem description]]
        if {$vdesc != ""} {
            lappend PortInfo(variant_desc) $variant_provides $vdesc
        }
    }

    # Finally append the ditem to the dlist.
    lappend all_variants $ditem
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

# variant_undef name
# Undefine a variant for the current portfile.
proc variant_undef {name} {
    global variations PortInfo
    
    # Remove it from the list of selected variations.
    array unset variations $name

    # Remove the variant from the portinfo.
    if {[info exists PortInfo(variants)]} {
        set variant_index [lsearch -exact $PortInfo(variants) $name]
        if {$variant_index >= 0} {
            set new_list [lreplace $PortInfo(variants) $variant_index $variant_index]
            if {"$new_list" == {}} {
                unset PortInfo(variants) 
            } else {
                set PortInfo(variants) $new_list
            }
        }
    }
    
    # And from the dlist.
    variant_remove_ditem $name
}

# variant_remove_ditem name
# Remove variant name's ditem from the all_variants dlist
proc variant_remove_ditem {name} {
    global all_variants
    set item_index 0
    foreach variant_item $all_variants {
        set item_provides [ditem_key $variant_item provides]
        if {$item_provides == $name} {
            set all_variants [lreplace $all_variants $item_index $item_index]
            break
        }
        
        incr item_index
    }
}

# variant_exists name
# determine if a variant exists.
proc variant_exists {name} {
    global PortInfo
    if {[info exists PortInfo(variants)] &&
      [lsearch -exact $PortInfo(variants) $name] >= 0} {
        return 1
    }

    return 0
}

# platform <os> [<release>] [<arch>] 
# Portfile level procedure to provide support for declaring platform-specifics
# Basically, just wrap 'variant', so that Portfiles' platform declarations can
# be more readable, and support arch and version specifics
proc platform {args} {
    global all_variants PortInfo os.platform os.arch os.version os.major
    
    set len [llength $args]
    set code [lindex $args end]
    set os [lindex $args 0]
    set args [lrange $args 1 [expr $len - 2]]
    
    set ditem [variant_new "temp-variant"]
    
    foreach arg $args {
        if {[regexp {(^[0-9]$)} $arg match result]} {
            set release $result
        } elseif {[regexp {([a-zA-Z0-9]*)} $arg match result]} {
            set arch $result
        }
    }
    
    # Add the variant for this platform
    set platform $os
    if {[info exists release]} { set platform ${platform}_${release} }
    if {[info exists arch]} { set platform ${platform}_${arch} }
    
    # Pick up a unique name.
    if {[variant_exists $platform]} {
        set suffix 1
        while {[variant_exists "$platform-$suffix"]} {
            incr suffix
        }
        
        set platform "$platform-$suffix"
    }
    variant $platform $code
    
    # Set the variant if this platform matches the platform we're on
    set matches 1
    if {[info exists os.platform] && ${os.platform} == $os} { 
    set sel_platform $os
        if {[info exists os.major] && [info exists release]} {
            if {${os.major} == $release } { 
                set sel_platform ${sel_platform}_${release} 
            } else {
                set matches 0
            }
        }
        if {$matches == 1 && [info exists arch] && [info exists os.arch]} {
            if {${os.arch} == $arch} {
                set sel_platform ${sel_platform}_${arch}
            } else {
                set matches 0
            }
        }
        if {$matches == 1} {
            variant_set $sel_platform
        }
    }
}

########### Environment utility functions ###########

# Parse the environment string of a command, storing the values into the
# associated environment array.
proc parse_environment {command} {
    global ${command}.env ${command}.env_array

    if {[info exists ${command}.env]} {
        # Flatten the environment string.
        set the_environment [join [set ${command}.env]]
    
        while {[regexp "^(?: *)(\[^= \]+)=(\"|'|)(\[^\"'\]*?)\\2(?: +|$)(.*)$" ${the_environment} matchVar key delimiter value remaining]} {
            set the_environment ${remaining}
            set ${command}.env_array(${key}) ${value}
        }
    } else {
        array set ${command}.env_array {}
    }
}

# Append to the value in the parsed environment.
# Leave the environment untouched if the value is empty.
proc append_to_environment_value {command key value} {
    global ${command}.env_array

    if {[string length $value] == 0} {
        return
    }

    # Parse out any delimiter.
    set append_value $value
    if {[regexp {^("|')(.*)\1$} $append_value matchVar append_delim matchedValue]} {
        set append_value $matchedValue
    }

    if {[info exists ${command}.env_array($key)]} {
        set original_value [set ${command}.env_array($key)]
        set ${command}.env_array($key) "${original_value} ${append_value}"
    } else {
        set ${command}.env_array($key) $append_value
    }
}

# Append several items to a value in the parsed environment.
proc append_list_to_environment_value {command key vallist} {
    foreach {value} $vallist {
        append_to_environment_value ${command} $key $value
    }
}

# Build the environment as a string.
# Remark: this method is only used for debugging purposes.
proc environment_array_to_string {environment_array} {
    upvar 1 ${environment_array} env_array
    
    set theString ""
    foreach {key value} [array get env_array] {
        if {$theString == ""} {
            set theString "$key='$value'"
        } else {
            set theString "${theString} $key='$value'"
        }
    }
    
    return $theString
}

########### Distname utility functions ###########

# Given a distribution file name, return the appended tag
# Example: getdisttag distfile.tar.gz:tag1 returns "tag1"
# / isn't included in the regexp, thus allowing port specification in URLs.
proc getdisttag {name} {
    if {[regexp {.+:([0-9A-Za-z_-]+)$} $name match tag]} {
        return $tag
    } else {
        return ""
    }
}

# Given a distribution file name, return the name without an attached tag
# Example : getdistname distfile.tar.gz:tag1 returns "distfile.tar.gz"
# / isn't included in the regexp, thus allowing port specification in URLs.
proc getdistname {name} {
    regexp {(.+):[0-9A-Za-z_-]+$} $name match name
    return $name
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
    set ix [lsearch -exact $list $value]
    if {$ix >= 0} {
        return [lreplace $list $ix $ix]
    }
    return $list
}

# reinplace
# Provides "sed in place" functionality
proc reinplace {args}  {
    set extended 0
    while 1 {
        set arg [lindex $args 0]
        if {[string index $arg 0] eq "-"} {
            set args [lrange $args 1 end]
            switch [string range $arg 1 end] {
                E {
                    set extended 1
                }
                - {
                    break
                }
                default {
                    error "reinplace: unknown flag '$arg'"
                }
            }
        } else {
            break
        }
    }
    if {[llength $args] < 2} {
        error "reinplace ?-E? pattern file ..."
    }
    set pattern [lindex $args 0]
    set files [lrange $args 1 end]
    
    foreach file $files {
        if {[catch {set tmpfile [mkstemp "/tmp/[file tail $file].sed.XXXXXXXX"]} error]} {
            global errorInfo
            ui_debug "$errorInfo"
            ui_error "reinplace: $error"
            return -code error "reinplace failed"
        } else {
            # Extract the Tcl Channel number
            set tmpfd [lindex $tmpfile 0]
            # Set tmpfile to only the file name
            set tmpfile [lindex $tmpfile 1]
        }
    
        set cmdline $portutil::autoconf::sed_command
        if {$extended} {
            lappend cmdline $portutil::autoconf::sed_ext_flag
        }
        set cmdline [concat $cmdline [list $pattern < $file >@ $tmpfd]]
        if {[catch {eval exec $cmdline} error]} {
            global errorInfo
            ui_debug "$errorInfo"
            ui_error "reinplace: $error"
            file delete "$tmpfile"
            close $tmpfd
            return -code error "reinplace sed(1) failed"
        }
    
        close $tmpfd
    
        set attributes [file attributes $file]
        # We need to overwrite this file
        if {[catch {file attributes $file -permissions u+w} error]} {
            global errorInfo
            ui_debug "$errorInfo"
            ui_error "reinplace: $error"
            file delete "$tmpfile"
            return -code error "reinplace permissions failed"
        }
    
        if {[catch {exec cp $tmpfile $file} error]} {
            global errorInfo
            ui_debug "$errorInfo"
            ui_error "reinplace: $error"
            file delete "$tmpfile"
            return -code error "reinplace copy failed"
        }
    
        for {set i 0} {$i < [llength attributes]} {incr i} {
            set opt [lindex $attributes $i]
            incr i
            set arg [lindex $attributes $i]
            file attributes $file $opt $arg
        }
        
        file delete "$tmpfile"
    }
    return
}

# delete
# file delete -force by itself doesn't handle directories properly
# on systems older than Tiger. Lets recurse using fs-traverse instead
proc delete {args} {
    ui_debug "delete: $args"
    fs-traverse -depth file $args {
        file delete -force -- $file
        continue
    }
}

# touch
# mimics the BSD touch command
proc touch {args} {
    while {[string match -* [lindex $args 0]]} {
        set arg [string range [lindex $args 0] 1 end]
        set args [lrange $args 1 end]
        switch -- $arg {
            a -
            c -
            m {set options($arg) yes}
            r -
            t {
                set narg [lindex $args 0]
                set args [lrange $args 1 end]
                if {[string length $narg] == 0} {
                    return -code error "touch: option requires an argument -- $arg"
                }
                set options($arg) $narg
                set options(rt) $arg ;# later option overrides earlier
            }
            - break
            default {return -code error "touch: illegal option -- $arg"}
        }
    }
    
    # parse the r/t options
    if {[info exists options(rt)]} {
        if {[string equal $options(rt) r]} {
            # -r
            # get atime/mtime from the file
            if {[file exists $options(r)]} {
                set atime [file atime $options(r)]
                set mtime [file mtime $options(r)]
            } else {
                return -code error "touch: $options(r): No such file or directory"
            }
        } else {
            # -t
            # parse the time specification
            # turn it into a CCyymmdd hhmmss
            set timespec {^(?:(\d\d)?(\d\d))?(\d\d)(\d\d)(\d\d)(\d\d)(?:\.(\d\d))?$}
            if {[regexp $timespec $options(t) {} CC YY MM DD hh mm SS]} {
                if {[string length $YY] == 0} {
                    set year [clock format [clock seconds] -format %Y]
                } elseif {[string length $CC] == 0} {
                    if {$YY >= 69 && $YY <= 99} {
                        set year 19$YY
                    } else {
                        set year 20$YY
                    }
                } else {
                    set year $CC$YY
                }
                if {[string length $SS] == 0} {
                    set SS 00
                }
                set atime [clock scan "$year$MM$DD $hh$mm$SS"]
                set mtime $atime
            } else {
                return -code error \
                    {touch: out of range or illegal time specification: [[CC]YY]MMDDhhmm[.SS]}
            }
        }
    } else {
        set atime [clock seconds]
        set mtime [clock seconds]
    }
    
    # do we have any files to process?
    if {[llength $args] == 0} {
        # print usage
        ui_msg {usage: touch [-a] [-c] [-m] [-r file] [-t [[CC]YY]MMDDhhmm[.SS]] file ...}
        return
    }
    
    foreach file $args {
        if {![file exists $file]} {
            if {[info exists options(c)]} {
                continue
            } else {
                close [open $file w]
            }
        }
        
        if {[info exists options(a)] || ![info exists options(m)]} {
            file atime $file $atime
        }
        if {[info exists options(m)] || ![info exists options(a)]} {
            file mtime $file $mtime
        }
    }
    return
}

# copy
proc copy {args} {
    eval file copy $args
}

# move
proc move {args} {
    eval file rename $args
}

# ln
# Mimics the BSD ln implementation
# ln [-f] [-h] [-s] [-v] source_file [target_file]
# ln [-f] [-h] [-s] [-v] source_file ... target_dir
proc ln {args} {
    while {[string match -* [lindex $args 0]]} {
        set arg [string range [lindex $args 0] 1 end]
        if {[string length $arg] > 1} {
            set remainder -[string range $arg 1 end]
            set arg [string range $arg 0 0]
            set args [lreplace $args 0 0 $remainder]
        } else {
            set args [lreplace $args 0 0]
        }
        switch -- $arg {
            f -
            h -
            s -
            v {set options($arg) yes}
            - break
            default {return -code error "ln: illegal option -- $arg"}
        }
    }
    
    if {[llength $args] == 0} {
        ui_msg {usage: ln [-f] [-h] [-s] [-v] source_file [target_file]}
        ui_msg {       ln [-f] [-h] [-s] [-v] file ... directory}
        return
    } elseif {[llength $args] == 1} {
        set files $args
        set target ./
    } else {
        set files [lrange $args 0 [expr [llength $args] - 2]]
        set target [lindex $args end]
    }
    
    foreach file $files {
        if {[file isdirectory $file] && ![info exists options(s)]} {
            return -code error "ln: $file: Is a directory"
        }
        
        if {[file isdirectory $target] && ([file type $target] ne "link" || ![info exists options(h)])} {
            set linktarget [file join $target [file tail $file]]
        } else {
            set linktarget $target
        }
        
        if {![catch {file type $linktarget}]} {
            if {[info exists options(f)]} {
                file delete $linktarget
            } else {
                return -code error "ln: $linktarget: File exists"
            }
        }
        
        if {[llength $files] > 2} {
            if {![file exists $linktarget]} {
                return -code error "ln: $linktarget: No such file or directory"
            } elseif {![file isdirectory $target]} {
                # this error isn't striclty what BSD ln gives, but I think it's more useful
                return -code error "ln: $target: Not a directory"
            }
        }
        
        if {[info exists options(v)]} {
            ui_msg "ln: $linktarget -> $file"
        }
        if {[info exists options(s)]} {
            symlink $file $linktarget
        } else {
            file link -hard $linktarget $file
        }
    }
    return
}

# filefindbypath
# Provides searching of the standard path for included files
proc filefindbypath {fname} {
    global distpath filesdir worksrcdir portpath
    
    if {[file readable $portpath/$fname]} {
        return $portpath/$fname
    } elseif {[file readable $portpath/$filesdir/$fname]} {
        return $portpath/$filesdir/$fname
    } elseif {[file readable $distpath/$fname]} {
        return $distpath/$fname
    }
    return ""
}

# include
# Source a file, looking for it along a standard search path.
proc include {fname} {
    set tgt [filefindbypath $fname]
    if {[string length $tgt]} {
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

# backup
# Operates on universal_filelist, creates universal_archlist
# Save single-architecture files, a temporary location, preserving the original
# directory structure.

proc backup {arch} {
    global universal_archlist universal_filelist workpath
    lappend universal_archlist ${arch}
    foreach file ${universal_filelist} {
        set filedir [file dirname $file]
        xinstall -d ${workpath}/${arch}/${filedir}
        xinstall ${file} ${workpath}/${arch}/${filedir}
    }
}

# lipo
# Operates on universal_filelist, universal_archlist.
# Run lipo(1) on a list of single-arch files.

proc lipo {} {
    global universal_archlist universal_filelist workpath
    foreach file ${universal_filelist} {
        xinstall -d [file dirname $file]
        file delete ${file}
        set lipoSources ""
        foreach arch $universal_archlist {
            append lipoSources "-arch ${arch} ${workpath}/${arch}/${file} "
        }
        system "lipo ${lipoSources}-create -output ${file}"
    }
}


# unobscure maintainer addresses as used in Portfiles
# We allow two obscured forms:
#   (1) User name only with no domain:
#           foo implies foo@macports.org
#   (2) Mangled name:
#           subdomain.tld:username implies username@subdomain.tld
#
proc unobscure_maintainers { list } {
    set result {}
    foreach m $list {
        if {[string first "@" $m] < 0} {
            if {[string first ":" $m] >= 0} {
                set m [regsub -- "(.*):(.*)" $m "\\2@\\1"] 
            } else {
                set m "$m@macports.org"
            }
        }
        lappend result $m
    }
    return $result
}




########### Internal Dependency Manipulation Procedures ###########

proc target_run {ditem} {
    global target_state_fd portpath portname portversion portrevision portvariants ports_force variations workpath ports_trace PortInfo
    set result 0
    set skipped 0
    set procedure [ditem_key $ditem procedure]
    if {$procedure != ""} {
        set name [ditem_key $ditem name]
    
        if {[ditem_contains $ditem init]} {
            set result [catch {[ditem_key $ditem init] $name} errstr]
        }
    
        if {$result == 0} {
            # Skip the step if required and explain why through ui_debug.
            # 1st case: the step was already done (as mentioned in the state file)
            if {[check_statefile target $name $target_state_fd]} {
                ui_debug "Skipping completed $name ($portname)"
                set skipped 1
            # 2nd case: the step is not to always be performed
            # and this exact port/version/revision/variants is already installed
            # and user didn't mention -f
            # and portfile didn't change since installation.
            } elseif {[ditem_key $ditem runtype] != "always"
              && [registry_exists $portname $portversion $portrevision $portvariants]
              && !([info exists ports_force] && $ports_force == "yes")} {
                        
                # Did the Portfile change since installation?
                set regref [registry_open $portname $portversion $portrevision $portvariants]
            
                set installdate [registry_prop_retr $regref date]
                if { $installdate != 0
                  && $installdate < [file mtime ${portpath}/Portfile]} {
                    ui_debug "Portfile changed since installation"
                } else {
                    # Say we're skipping.
                    set skipped 1
                
                    ui_debug "Skipping $name ($portname) since this port is already installed"
                }
            
                # Something to close the registry entry may be called here, if it existed.
                # 3rd case: the same port/version/revision/Variants is already active
                # and user didn't mention -f
            } elseif {$name == "org.macports.activate"
              && [registry_exists $portname $portversion $portrevision $portvariants]
              && !([info exists ports_force] && $ports_force == "yes")} {
            
                # Is port active?
                set regref [registry_open $portname $portversion $portrevision $portvariants]
            
                if { [registry_prop_retr $regref active] != 0 } {
                    # Say we're skipping.
                    set skipped 1
                
                    ui_msg "Skipping $name ($portname $portvariants) since this port is already active"
                }
                
            }
            
            # otherwise execute the task.
            if {$skipped == 0} {
                set target [ditem_key $ditem provides]
            
                # Execute pre-run procedure
                if {[ditem_contains $ditem prerun]} {
                    set result [catch {[ditem_key $ditem prerun] $name} errstr]
                }
            
                #start tracelib
                if {($result ==0 
                  && [info exists ports_trace]
                  && $ports_trace == "yes"
                  && $target != "clean")} {
                    trace_start $workpath

                    # Enable the fence to prevent any creation/modification
                    # outside the sandbox.
                    if {$target != "activate"
                      && $target != "archive"
                      && $target != "fetch"
                      && $target != "install"} {
                        trace_enable_fence
                    }
            
                    # collect deps
                    
                    # Don't check dependencies for extract (they're not honored
                    # anyway). This avoids warnings about bzip2.
                    if {$target != "extract"} {
                        set depends {}
                        set deptypes {}
                    
                        # Determine deptypes to look for based on target
                        switch $target {
                            configure   { set deptypes "depends_lib depends_build" }
                            
                            build       { set deptypes "depends_lib depends_build" }
                        
                            test        -
                            destroot    -
                            install     -
                            archive     -
                            pkg         -
                            mpkg        -
                            rpm         -
                            srpm        -
                            dpkg        -
                            activate    -
                            ""          { set deptypes "depends_lib depends_build depends_run" }
                        }
                    
                        # Gather the dependencies for deptypes
                        foreach deptype $deptypes {
                            # Add to the list of dependencies if the option exists and isn't empty.
                            if {[info exists PortInfo($deptype)] && $PortInfo($deptype) != ""} {
                                set depends [concat $depends $PortInfo($deptype)]
                            }
                        }
    
                        # Dependencies are in the form verb:[param:]port
                        set depsPorts {}
                        foreach depspec $depends {
                            # grab the portname portion of the depspec
                            set dep_portname [lindex [split $depspec :] end]
                            lappend depsPorts $dep_portname
                        }
                    
                        set portlist $depsPorts
                        foreach depName $depsPorts {
                            set portlist [concat $portlist [recursive_collect_deps $depName $deptypes]]
                        }
                        #uniquer from http://aspn.activestate.com/ASPN/Cookbook/Tcl/Recipe/147663
                        array set a [split "[join $portlist {::}]:" {:}]
                        set depsPorts [array names a]
                    
                        if {[llength $deptypes] > 0} {tracelib setdeps $depsPorts}
                    }
                }
            
                if {$result == 0} {
                    foreach pre [ditem_key $ditem pre] {
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
                    foreach post [ditem_key $ditem post] {
                        ui_debug "Executing $post"
                        set result [catch {$post $name} errstr]
                        if {$result != 0} { break }
                    }
                }
                # Execute post-run procedure
                if {[ditem_contains $ditem postrun] && $result == 0} {
                    set postrun [ditem_key $ditem postrun]
                    ui_debug "Executing $postrun"
                    set result [catch {$postrun $name} errstr]
                }

                # Check dependencies & file creations outside workpath.
                if {[info exists ports_trace]
                  && $ports_trace == "yes"
                  && $target!="clean"} {
                
                    tracelib closesocket
                
                    trace_check_violations
                
                    # End of trace.
                    trace_stop
                }
            }
        }
        if {$result == 0} {
            # Only write to state file if:
            # - we indeed performed this step.
            # - this step is not to always be performed
            # - this step must be written to file
            if {$skipped == 0
          && [ditem_key $ditem runtype] != "always"
          && [ditem_key $ditem state] != "no"} {
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

# recursive found depends for portname
# It isn't ideal, because it scan many ports multiple time
proc recursive_collect_deps {portname deptypes} \
{
    set res [mport_search ^$portname\$]
    if {[llength $res] < 2} \
    {
        return {}
    }

    set depends {}

    array set portinfo [lindex $res 1]
    foreach deptype $deptypes \
    {
        if {[info exists portinfo($deptype)] && $portinfo($deptype) != ""} \
        {
            set depends [concat $depends $portinfo($deptype)]
        }
    }
    
    set portdeps {}
    foreach depspec $depends \
    {
        set portname [lindex [split $depspec :] end]
        lappend portdeps $portname
        set portdeps [concat $portdeps [recursive_collect_deps $portname $deptypes]]
    }
    return $portdeps
}


proc eval_targets {target} {
    global targets target_state_fd portname
    set dlist $targets
    
    # Select the subset of targets under $target
    if {$target != ""} {
        set matches [dlist_search $dlist provides $target]
    
        if {[llength $matches] > 0} {
            set dlist [dlist_append_dependents $dlist [lindex $matches 0] [list]]
            # Special-case 'all'
        } elseif {$target != "all"} {
            ui_error "unknown target: $target"
            return 1
        }
    }
    
    # Restore the state from a previous run.
    set target_state_fd [open_statefile]
    
    set dlist [dlist_eval $dlist "" target_run]
    
    if {[llength $dlist] > 0} {
        # somebody broke!
        set errstring "Warning: the following items did not execute (for $portname):"
        foreach ditem $dlist {
            append errstring " [ditem_key $ditem name]"
        }
        ui_info $errstring
        set result 1
    } else {
        set result 0
    }
    
    close $target_state_fd
    return $result
}

# open_statefile
# open file to store name of completed targets
proc open_statefile {args} {
    global workpath worksymlink place_worksymlink portname portpath ports_ignore_older
    
    if {![file isdirectory $workpath]} {
        file mkdir $workpath
    }
    # flock Portfile
    set statefile [file join $workpath .macports.${portname}.state]
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

    # Create a symlink to the workpath for port authors 
    if {[tbool place_worksymlink] && ![file isdirectory $worksymlink]} {
        exec ln -sf $workpath $worksymlink
    }
    
    set fd [open $statefile a+]
    if {[catch {flock $fd -exclusive -noblock} result]} {
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
                if {![info exists oldvariations($key)] || $upvariations($key) != $oldvariations($key)} {
                set mismatch 1
                break
                }
            }
        }
    }
    
    return $mismatch
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
    ui_debug "Executing variant $name provides [ditem_key $ditem provides]"
    
    # test for conflicting variants
    foreach v [ditem_key $ditem conflicts] {
        if {[variant_isset $v]} {
            ui_error "Variant $name conflicts with $v"
            return 1
        }
    }
    
    # execute proc with same name as variant.
    if {[catch "variant-${name}" result]} {
        global errorInfo
        ui_debug "$errorInfo"
        ui_error "Error executing $name: $result"
        return 1
    }
    return 0
}

# Given a list of variant specifications, return a canonical string form
# for the registry. 
    # The strategy is as follows: regardless of how some collection of variants
    # was turned on or off, a particular instance of the port is uniquely
    # characterized by the set of variants that are *on*. Thus, record those
    # variants in a string in a standard order as +var1+var2 etc.
    # We can skip the platform and architecture since those are always
    # requested.  XXX: Is that really true? What if the user explicitly
    # overrides the platform and architecture variants? Will the registry get
    # bollixed? It would seem safer to me to just leave in all the variants that
    # are on, but for now I'm just leaving the skipping code as it was in the
    # previous version.
proc canonicalize_variants {variants} {
    array set vara $variants
    set result ""
    set vlist [lsort -ascii [array names vara]]
    foreach v $vlist {
        if {$vara($v) == "+" && $v ne [option os.platform] && $v ne [option os.arch]} {
            append result +$v
        }
    }
    return $result
}

proc eval_variants {variations} {
    global all_variants ports_force PortInfo portvariants
    set dlist $all_variants
    upvar $variations upvariations
    set chosen [choose_variants $dlist upvariations]
    set portname $PortInfo(name)

    # Check to make sure the requested variations are available with this 
    # port, if one is not, warn the user and remove the variant from the 
    # array.
    foreach key [array names upvariations *] {
        if {![info exists PortInfo(variants)] || 
            [lsearch $PortInfo(variants) $key] == -1} {
            ui_debug "Requested variant $key is not provided by port $portname."
            array unset upvariations $key
        }
    }

    # now that we've selected variants, change all provides [a b c] to [a-b-c]
    # this will eliminate ambiguity between item a, b, and a-b while fulfilling requirments.
    #foreach obj $dlist {
    #    $obj set provides [list [join [$obj get provides] -]]
    #}
    
    set newlist [list]
    foreach variant $chosen {
        set newlist [dlist_append_dependents $dlist $variant $newlist]
    }
    
    set dlist [dlist_eval $newlist "" variant_run]
    if {[llength $dlist] > 0} {
        return 1
    }

    # Now compute the true active array of variants. Note we do not
    # change upvariations any further, since that represents the
    # requested list of variations; but the registry for consistency
    # must encode the actual list of variants evaluated, however that
    # came to pass (dependencies, defaults, etc.) While we're at it,
    # it's convenient to check for inconsistent requests for
    # variations, namely foo +requirer -required where the 'requirer'
    # variant requires the 'required' one.
    array set activevariants [list]
    foreach dvar $newlist {
        set thevar [ditem_key $dvar provides]
        if {[info exists upvariations($thevar)] && $upvariations($thevar) eq "-"} {
            set chosenlist ""
            foreach choice $chosen {
                lappend chosenlist +[ditem_key $choice provides]
            }
            ui_error "Inconsistent variant specification: $portname variant +$thevar is required by at least one of $chosenlist, but specified -$thevar"
            return 1
        }
        set activevariants($thevar) "+"
    }

    # Record a canonical variant string, used e.g. in accessing the registry
    set portvariants [canonicalize_variants [array get activevariants]]

    # XXX: I suspect it would actually work better in the following
    # block to record the activevariants in the statefile rather than
    # the upvariations, since as far as I can see different sets of
    # upvariations which amount to the same activevariants in the end
    # can share all aspects of the build. But I'm leaving this alone
    # for the time being, so that someone with more extensive
    # experience can examine the idea before putting it into
    # action. -- GlenWhitney

    return 0
}

proc check_variants {variations target} {
    global ports_force PortInfo
    upvar $variations upvariations
    set result 0
    set portname $PortInfo(name)
    
    # Make sure the variations match those stored in the statefile.
    # If they don't match, print an error indicating a 'port clean' 
    # should be performed.  
    # - Skip this test if the statefile is empty.
    # - Skip this test if performing a clean or submit.
    # - Skip this test if ports_force was specified.
    
    if { [lsearch "clean submit" $target] < 0 && 
        !([info exists ports_force] && $ports_force == "yes")} {
        
        set state_fd [open_statefile]
    
        if {[check_statefile_variants upvariations $state_fd]} {
            ui_error "Requested variants do not match original selection.\nPlease perform 'port clean $portname' or specify the force option."
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

proc target_provides {ditem args} {
    global targets
    # Register the pre-/post- hooks for use in Portfile.
    # Portfile syntax: pre-fetch { puts "hello world" }
    # User-code exceptions are caught and returned as a result of the target.
    # Thus if the user code breaks, dependent targets will not execute.
    foreach target $args {
        set origproc [ditem_key $ditem procedure]
        set ident [ditem_key $ditem name]
        if {[info commands $target] != ""} {
            ui_debug "$ident registered provides '$target', a pre-existing procedure. Target override will not be provided"
        } else {
            proc $target {args} "
                variable proc_index
                set proc_index \[llength \[ditem_key $ditem proc\]\]
                ditem_key $ditem procedure proc-${ident}-${target}-\${proc_index}
                proc proc-${ident}-${target}-\${proc_index} {name} \"
                    if {\\\[catch userproc-${ident}-${target}-\${proc_index} result\\\]} {
                        return -code error \\\$result
                    } else {
                        return 0
                    }
                \"
                proc do-$target {} { $origproc $target }
                makeuserproc userproc-${ident}-${target}-\${proc_index} \$args
            "
        }
        proc pre-$target {args} "
            variable proc_index
            set proc_index \[llength \[ditem_key $ditem pre\]\]
            ditem_append $ditem pre proc-pre-${ident}-${target}-\${proc_index}
            proc proc-pre-${ident}-${target}-\${proc_index} {name} \"
                if {\\\[catch userproc-pre-${ident}-${target}-\${proc_index} result\\\]} {
                    return -code error \\\$result
                } else {
                    return 0
                }
            \"
            makeuserproc userproc-pre-${ident}-${target}-\${proc_index} \$args
        "
        proc post-$target {args} "
            variable proc_index
            set proc_index \[llength \[ditem_key $ditem post\]\]
            ditem_append $ditem post proc-post-${ident}-${target}-\${proc_index}
            proc proc-post-${ident}-${target}-\${proc_index} {name} \"
                if {\\\[catch userproc-post-${ident}-${target}-\${proc_index} result\\\]} {
                    return -code error \\\$result
                } else {
                    return 0
                }
            \"
            makeuserproc userproc-post-${ident}-${target}-\${proc_index} \$args
        "
    }
    eval ditem_append $ditem provides $args
}

proc target_requires {ditem args} {
    eval ditem_append $ditem requires $args
}

proc target_uses {ditem args} {
    eval ditem_append $ditem uses $args
}

proc target_deplist {ditem args} {
    eval ditem_append $ditem deplist $args
}

proc target_prerun {ditem args} {
    eval ditem_append $ditem prerun $args
}

proc target_postrun {ditem args} {
    eval ditem_append $ditem postrun $args
}

proc target_runtype {ditem args} {
    eval ditem_append $ditem runtype $args
}

proc target_state {ditem args} {
    eval ditem_append $ditem state $args
}

proc target_init {ditem args} {
    eval ditem_append $ditem init $args
}

##### variant class #####

# constructor for variant objects
proc variant_new {name} {
    set ditem [ditem_create]
    ditem_key $ditem name $name
    return $ditem
}

proc handle_default_variants {option action {value ""}} {
    global variations
    switch -regex $action {
        set|append {
            foreach v $value {
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
    
    set res [mport_search ^$search_string\$]
    if {[llength $res] < 2} {
        ui_error "Dependency $portname not found"
        return -1
    }
    
    array set portinfo [lindex $res 1]
    set porturl $portinfo(porturl)
    if {[catch {set worker [mport_open $porturl [array get options] $variations]} result]} {
        global errorInfo
        ui_debug "$errorInfo"
        ui_error "Opening $portname $target failed: $result"
        return -1
    }
    if {[catch {mport_exec $worker $target} result] || $result != 0} {
        global errorInfo
        ui_debug "$errorInfo"
        ui_error "Execution $portname $target failed: $result"
        mport_close $worker
        return -1
    }
    mport_close $worker
    
    return 0
}

# portfile primitive that calls portexec_int with newworkpath == ${workpath}
proc portexec {portname target} {
    global workpath
    return [portexec_int $portname $target $workpath]
}

proc adduser {name args} {
    global os.platform
    set passwd {*}
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
    
    if {${os.platform} eq "darwin"} {
        exec dscl . -create /Users/${name} Password ${passwd}
        exec dscl . -create /Users/${name} UniqueID ${uid}
        exec dscl . -create /Users/${name} PrimaryGroupID ${gid}
        exec dscl . -create /Users/${name} RealName ${realname}
        exec dscl . -create /Users/${name} NFSHomeDirectory ${home}
        exec dscl . -create /Users/${name} UserShell ${shell}
    } else {
        # XXX adduser is only available for darwin, add more support here
        ui_warn "WARNING: adduser is not implemented on ${os.platform}."
        ui_warn "The requested user was not created."
    }
}

proc addgroup {name args} {
    global os.platform
    set gid [nextgid]
    set realname ${name}
    set passwd {*}
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
    
    if {${os.platform} eq "darwin"} {
        exec dscl . -create /Groups/${name} Password ${passwd}
        exec dscl . -create /Groups/${name} RealName ${realname}
        exec dscl . -create /Groups/${name} PrimaryGroupID ${gid}
        if {${users} ne ""} {
            exec dscl . -create /Groups/${name} GroupMembership ${users}
        }
    } else {
        # XXX addgroup is only available for darwin, add more support here
        ui_warn "WARNING: addgroup is not implemented on ${os.platform}."
        ui_warn "The requested group was not created."
    }
}

# proc to calculate size of a directory
# moved here from portpkg.tcl
proc dirSize {dir} {
    set size    0;
    foreach file [readdir $dir] {
        if {[file type [file join $dir $file]] == "link" } {
            continue
        }
        if {[file isdirectory [file join $dir $file]]} {
            incr size [dirSize [file join $dir $file]]
        } else {
            incr size [file size [file join $dir $file]];
        }
    }
    return $size;
}

# check for a binary in the path
# returns an error code if it can not be found
proc binaryInPath {binary} {
    global env
    foreach dir [split $env(PATH) :] { 
        if {[file executable [file join $dir $binary]]} {
            return [file join $dir $binary]
        }
    }
    
    return -code error [format [msgcat::mc "Failed to locate '%s' in path: '%s'"] $binary $env(PATH)];
}

# Set the UI prefix to something standard (so it can be grepped for in output)
proc set_ui_prefix {} {
    global UI_PREFIX env
    if {[info exists env(UI_PREFIX)]} {
        set UI_PREFIX $env(UI_PREFIX)
    } else {
        set UI_PREFIX "---> "
    }
}

# Use a specified group/version.
proc PortGroup {group version} {
    global portresourcepath

    set groupFile ${portresourcepath}/group/${group}-${version}.tcl

    if {[file exists $groupFile]} {
        uplevel "source $groupFile"
    } else {
        ui_warn "Group file could not be located."
    }
}

# check if archive type is supported by current system
# returns an error code if it is not
proc archiveTypeIsSupported {type} {
    global os.platform os.version
    set errmsg ""
    switch -regex $type {
        cp(io|gz) {
            set pax "pax"
            if {[catch {set pax [binaryInPath $pax]} errmsg] == 0} {
                if {[regexp {z$} $type]} {
                    set gzip "gzip"
                    if {[catch {set gzip [binaryInPath $gzip]} errmsg] == 0} {
                        return 0
                    }
                } else {
                    return 0
                }
            }
        }
        t(ar|bz|lz|gz) {
            set tar "tar"
            if {[catch {set tar [binaryInPath $tar]} errmsg] == 0} {
                if {[regexp {z2?$} $type]} {
                    if {[regexp {bz2?$} $type]} {
                        set gzip "bzip2"
                    } elseif {[regexp {lz$} $type]} {
                        set gzip "lzma"
                    } else {
                        set gzip "gzip"
                    }
                    if {[catch {set gzip [binaryInPath $gzip]} errmsg] == 0} {
                        return 0
                    }
                } else {
                    return 0
                }
            }
        }
        xar {
            set xar "xar"
            if {[catch {set xar [binaryInPath $xar]} errmsg] == 0} {
                return 0
            }
        }
        zip {
            set zip "zip"
            if {[catch {set zip [binaryInPath $zip]} errmsg] == 0} {
                set unzip "unzip"
                if {[catch {set unzip [binaryInPath $unzip]} errmsg] == 0} {
                    return 0
                }
            }
        }
        default {
            return -code error [format [msgcat::mc "Invalid port archive type '%s' specified!"] $type]
        }
    }
    return -code error [format [msgcat::mc "Unsupported port archive type '%s': %s"] $type $errmsg]
}

#
# merge function for universal builds
#

# private function
# merge_lipo base-path target-path relative-path architectures
# e.g. 'merge_lipo ${workpath}/pre-dest ${destroot} ${prefix}/bin/pstree i386 ppc
# will merge binary files with lipo which have to be in the same (relative) path
proc merge_lipo {base target file archs} {
    set exec-lipo ""
    foreach arch ${archs} {
        set exec-lipo [concat ${exec-lipo} [list "-arch" "${arch}" "${base}/${arch}${file}"]]
    }
    set exec-lipo [concat ${exec-lipo}]
    system "/usr/bin/lipo ${exec-lipo} -create -output ${target}${file}"
}

# private function
# merge C/C++/.. files
# either just copy (if equivalent) or add CPP directive for differences
# should work for C++, C, Obj-C, Obj-C++ files and headers
proc merge_cpp {base target file archs} {
    merge_file $base $target $file $archs
    # TODO -- instead of just calling merge_file:
    # check if different
    #   no: copy
    #   yes: merge with #elif defined(__i386__) (__x86_64__, __ppc__, __ppc64__)
}

# private function
# merge_file base-path target-path relative-path architectures
# e.g. 'merge_file ${workpath}/pre-dest ${destroot} ${prefix}/share/man/man1/port.1 i386 ppc
# will test equivalence of files and copy them if they are the same (for the different architectures) 
proc merge_file {base target file archs} {
    set basearch [lindex ${archs} 0]
    ui_debug "ba: '${basearch}' ('${archs}')"
    foreach arch [lrange ${archs} 1 end] {
        # checking for differences; TODO: error more gracefully on non-equal files
        exec "/usr/bin/diff" "-q" "${base}/${basearch}${file}" "${base}/${arch}${file}"
    }
    ui_debug "ba: '${basearch}'"
    file copy "${base}/${basearch}${file}" "${target}${file}"
}

# merges multiple "single-arch" destroots into the final destroot
# 'base' is the path where the different directories (one for each arch) are
# e.g. call 'merge ${workpath}/pre-dest' with having a destroot in ${workpath}/pre-dest/i386 and ${workpath}/pre-dest/ppc64 -- single arch -- each
proc merge {base} {
    global destroot

    # test which architectures are available, set one as base-architecture
    set archs ""
    set base_arch ""
    foreach arch {"i386" "x86_64" "ppc" "ppc64"} {
        if [file exists "${base}/${arch}"] {
            set archs [concat ${archs} ${arch}]
            set base_arch ${arch}
        }
    }
    ui_debug "merging architectures ${archs}, base_arch is ${base_arch}"

    # traverse the base-architecture directory
    set basepath "${base}/${base_arch}"
    fs-traverse file "${basepath}" {
        set fpath [string range "${file}" [string length "${basepath}"] [string length "${file}"]]
        if {${fpath} != ""} {
            # determine the type (dir/file/link)
            set filetype [exec "/usr/bin/file" "-b" "${basepath}${fpath}"]
            switch -regexp ${filetype} {
                directory {
                    # just create directories
                    ui_debug "mrg: directory ${fpath}"
                    file mkdir "${destroot}${fpath}"
                }
                symbolic\ link.* {
                    # copy symlinks, TODO: check if targets match!
                    ui_debug "mrg: symlink ${fpath}"
                    file copy "${basepath}${fpath}" "${destroot}${fpath}"
                }
                Mach-O.* {
                    merge_lipo "${base}" "${destroot}" "${fpath}" "${archs}"
                }
                current\ ar\ archive {
                    merge_lipo "${base}" "${destroot}" "${fpath}" "${archs}"
                }
                ASCII\ C\ program\ text {
                    merge_cpp "${base}" "${destroot}" "${fpath}" "${archs}"
                }
                default {
                    ui_debug "unknown file type: ${filetype}"
                    merge_file "${base}" "${destroot}" "${fpath}" "${archs}"
                }
            }
        }
    }
}

