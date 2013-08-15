# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# $Id$
#
# Copyright (c) 2002-2003 Apple Inc.
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2006-2007 Markus W. Weissmann <mww@macports.org>
# Copyright (c) 2004-2013 The MacPorts Project
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
# 3. Neither the name of Apple Inc. nor the names of its contributors
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
#   option  - the name of the option to read or write
#       not called 'name' because this would fail if its value was 'name'...
#   value - an optional value to assign to the option

proc option {option args} {
    # XXX: right now we just transparently use globals
    # eventually this will need to bridge the options between
    # the Portfile's interpreter and the target's interpreters.
    global $option
    if {[llength $args] > 0} {
        ui_debug "setting option $option to $args"
        set $option [lindex $args 0]
    }
    return [set $option]
}

# exists
# This is an accessor for Portfile options.  Targets may use
# this procedure to test for the existence of a Portfile option.
#   option - the name of the option to test for existence

proc exists {option} {
    # XXX: right now we just transparently use globals
    # eventually this will need to bridge the options between
    # the Portfile's interpreter and the target's interpreters.
    global $option
    return [info exists $option]
}

##
# Handle an option
#
# @param option name of the option
# @param args arguments
proc handle_option {option args} {
    global $option user_options option_procs

    if {![info exists user_options($option)]} {
        set $option $args
    }
}

##
# Handle option-append
#
# @param option name of the option
# @param args arguments
proc handle_option-append {option args} {
    global $option user_options option_procs

    if {![info exists user_options($option)]} {
        if {[info exists $option]} {
            set $option [concat [set $option] $args]
        } else {
            set $option $args
        }
    }
}

##
# Handle option-delete
#
# @param option name of the option
# @param args arguments
proc handle_option-delete {option args} {
    global $option user_options option_procs

    if {![info exists user_options($option)] && [info exists $option]} {
        set temp [set $option]
        foreach val $args {
            set temp [ldelete $temp $val]
        }
        set $option $temp
    }
}

##
# Handle option-strsed
#
# @param option name of the option
# @param args arguments
proc handle_option-strsed {option args} {
    global $option user_options option_procs

    if {![info exists user_options($option)] && [info exists $option]} {
        set temp [set $option]
        foreach val $args {
            set temp [strsed $temp $val]
        }
        set $option $temp
    }
}

##
# Handle option-replace
#
# @param option name of the option
# @param args arguments
proc handle_option-replace {option args} {
    global $option user_options option_procs deprecated_options

    # Deprecate -replace with only one argument, for backwards compatibility call -strsed
    # XXX: Remove this in 2.2.0
    if {[llength $args] == 1} {
        if {![info exists deprecated_options(${option}-replace)]} {
            set deprecated_options(${option}-replace) [list ${option}-strsed 0]
        }
        set refcount [lindex $deprecated_options(${option}-replace) 1]
        lset deprecated_options(${option}-replace) 1 [expr $refcount + 1]
        return [eval handle_option-strsed $option $args]
    }

    if {![info exists user_options($option)] && [info exists $option]} {
        foreach {old new} $args {
            set index [lsearch -exact [set $option] $old]
            if {$index == -1} {
                continue
            }
            set $option [lreplace [set $option] $index $index $new]
        }
    }
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
        interp alias {} $option {} handle_option $option
        interp alias {} $option-append {} handle_option-append $option
        interp alias {} $option-delete {} handle_option-delete $option
        interp alias {} $option-strsed {} handle_option-strsed $option
        interp alias {} $option-replace {} handle_option-replace $option
    }
}

##
# Export options into PortInfo
#
# @param option the name of the option
# @param action set or delete
# @param value the value to be set, defaults to an empty string
proc options::export {option action {value ""}} {
    global $option PortInfo
    switch $action {
        set {
            set PortInfo($option) $value
        }
        delete {
            unset -nocomplain PortInfo($option)
        }
    }
}

##
# Export multiple options
#
# @param args list of ports to be exported
proc options_export {args} {
    foreach option $args {
        option_proc $option options::export
    }
}

##
# Print a warning for deprecated options
#
# @param option deprecated option
# @param action read/set
# @param value ignored
proc handle_deprecated_option {option action {value ""}} {
    global subport $option deprecated_options
    set newoption [lindex $deprecated_options($option) 0]
    set refcount  [lindex $deprecated_options($option) 1]
    global $newoption

    if {$newoption == ""} {
        ui_warn "Port $subport using deprecated option \"$option\"."
        return
    }

    # Increment reference counter
    lset deprecated_options($option) 1 [expr $refcount + 1]

    if {$action != "read"} {
        $newoption [set $option]
    } else {
        $option [set $newoption]
    }
}

##
# Get the name of the array containing the deprecated options
# Thin layer avoiding to share global variables without notice
proc get_deprecated_options {} {
    return "deprecated_options"
}

##
# Mark an option as deprecated
# If it is set or accessed, it will be mapped to the new option
#
# @param option name of the option
# @param newoption name of a superseding option
proc option_deprecate {option {newoption ""} } {
    global deprecated_options
    # If a new option is specified, default the option to $newoption
    set deprecated_options($option) [list $newoption 0]
    # Create a normal option for compatibility
    options $option
    # Register a proc for handling the deprecation
    option_proc $option handle_deprecated_option
}

##
# Registers a proc to be called when an option is changed
#
# @param option the name of the option
# @param args name of procs
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
        options use_${option} ${option}.dir ${option}.pre_args ${option}.args ${option}.post_args ${option}.env ${option}.nice ${option}.type ${option}.cmd
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
# command_exec command [-notty] [-varprefix variable_prefix] [command_prefix [command_suffix]]
# command           name of the command
# variable_prefix   name of the variable prefix to use (defaults to command)
# command_prefix    additional command prefix (typically pipe command)
# command_suffix    additional command suffix (typically redirection)
proc command_exec {command args} {
    set varprefix "${command}"
    set notty ""
    set command_prefix ""
    set command_suffix ""

    if {[llength $args] > 0} {
        if {[lindex $args 0] == "-notty"} {
            set notty "-notty"
            set args [lrange $args 1 end]
        }

        if {[lindex $args 0] == "-varprefix"} {
            set varprefix [lindex $args 1]
            set args [lrange $args 2 end]
        }

        if {[llength $args] > 0} {
            set command_prefix [lindex $args 0]
            if {[llength $args] > 1} {
                set command_suffix [lindex $args 1]
            }
        }
    }

    global ${varprefix}.env ${varprefix}.env_array ${varprefix}.nice env macosx_version

    # Set the environment.
    # If the array doesn't exist, we create it with the value
    # coming from ${varprefix}.env
    # Otherwise, it means the caller actually played with the environment
    # array already (e.g. configure flags).
    if {![array exists ${varprefix}.env_array]} {
        parse_environment ${varprefix}
    }
    if {[option macosx_deployment_target] ne ""} {
        set ${varprefix}.env_array(MACOSX_DEPLOYMENT_TARGET) [option macosx_deployment_target]
    }
    set ${varprefix}.env_array(CC_PRINT_OPTIONS) "YES"
    set ${varprefix}.env_array(CC_PRINT_OPTIONS_FILE) [file join [option workpath] ".CC_PRINT_OPTIONS"]
    if {[option compiler.cpath] ne ""} {
        set ${varprefix}.env_array(CPATH) [join [option compiler.cpath] :]
    }
    if {[option compiler.library_path] ne ""} {
        set ${varprefix}.env_array(LIBRARY_PATH) [join [option compiler.library_path] :]
    }

    # Debug that.
    ui_debug "Environment: [environment_array_to_string ${varprefix}.env_array]"

    # Prepare nice value change
    set nice ""
    if {[info exists ${varprefix}.nice] && [set ${varprefix}.nice] != ""} {
        set nice "-nice [set ${varprefix}.nice]"
    }

    # Get the command string.
    set cmdstring [command_string ${command}]

    # Call this command.
    # TODO: move that to the system native call?
    # Save the environment.
    array set saved_env [array get env]
    # Set the overriden variables from the portfile.
    array set env [array get ${varprefix}.env_array]
    # Call the command.
    set fullcmdstring "$command_prefix $cmdstring $command_suffix"
    ui_debug "Executing command line: $fullcmdstring"
    set code [catch {eval system $notty $nice \$fullcmdstring} result]
    # Save variables in order to re-throw the same error code.
    set errcode $::errorCode
    set errinfo $::errorInfo

    # Unset the command array until next time.
    array unset ${varprefix}.env_array

    # Restore the environment.
    array unset env *
    if {$macosx_version == "10.5"} {
        unsetenv *
    }
    array set env [array get saved_env]

    # Return as if system had been called directly.
    return -code $code -errorcode $errcode -errorinfo $errinfo $result
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

##
# Filter options which take strings removing indent to ease Portfile writing
proc handle_option_string {option action args} {
    global $option

    switch $action {
        set {
            set args [join $args]

            set fulllist {}
            # args is a list of strings/list
            foreach arg $args {
                # Strip trailing empty lines
                if {[string index $arg 0] == "\n"} {
                    set arg [string range $arg 1 end]
                }
                if {[string index $arg end] == "\n"} {
                    set arg [string range $arg 0 end-1]
                }

                # Determine indent level
                set indent ""
                for {set i 0} {$i < [string length $arg]} {incr i} {
                    set c [string index $arg $i]
                    if {$c != " " && $c != "\t"} {
                        break
                    }
                    append indent $c
                }
                # Remove indent on first line
                set arg [string replace $arg 0 [expr $i - 1]]
                # Remove indent on each other line
                set arg [string map "\"\n$indent\" \"\n\"" $arg]

                lappend fulllist $arg
            }

            set $option $fulllist
        }
    }
}

# variant <provides> [<provides> ...] [requires <requires> [<requires>]]
# Portfile level procedure to provide support for declaring variants
proc variant {args} {
    global all_variants PortInfo porturl

    # Each key in PortInfo(vinfo) maps to an array which contains the
    # following keys:
    #   * conflicts
    #   * description: This key's mapping is duplicated in
    #                  PortInfo(variant_desc) for backward compatibility
    #                  reasons (specifically 1.7.0's format of PortIndex).
    #   * is_default: This key exists iff the variant is a default variant.
    #   * requires
    if {![info exists PortInfo(vinfo)]} {
        set PortInfo(vinfo) {}
    }
    array set vinfo $PortInfo(vinfo)

    set len [llength $args]
    if {$len < 2} {
        return -code error "Malformed variant specification"
    }
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
        # Create an array to contain the variant's information.
        if {![info exists vinfo($variant_provides)]} {
            set vinfo($variant_provides) {}
        }
        array set variant $vinfo($variant_provides)

        # Set conflicts.
        set vconflicts [join [lsort [ditem_key $ditem conflicts]]]
        if {$vconflicts ne ""} {
            array set variant [list conflicts $vconflicts]
        }

        lappend PortInfo(variants) $variant_provides
        set vdesc [join [ditem_key $ditem description]]

        # read global variant description, if none given
        if {$vdesc == ""} {
            set vdesc [variant_desc $porturl $variant_provides]
        }

        # Set description.
        if {$vdesc ne ""} {
            array set variant [list description $vdesc]
            # XXX: The following line should be removed after 1.8.0 is
            #      released.
            lappend PortInfo(variant_desc) $variant_provides $vdesc
        }

        # Set requires.
        set vrequires [join [lsort [ditem_key $ditem requires]]]
        if {$vrequires ne ""} {
            array set variant [list requires $vrequires]
        }
    }

    # Add the variant (back) to PortInfo(vinfo).
    array set vinfo [list $variant_provides [array get variant]]
    set PortInfo(vinfo) [array get vinfo]

    if {[variant_isset $variant_provides]} {
        # set variants that this one requires
        foreach req [ditem_key $ditem requires] {
            variant_set $req
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

##
# Load the global description file for a port tree
#
# @param descfile path to the descriptions file
proc load_variant_desc_file {descfile} {
    global variant_descs_global

    if {![info exists variant_descs_global($descfile)]} {
        set variant_descs_global($descfile) yes

        if {[file exists $descfile]} {
            ui_debug "Reading variant descriptions from $descfile"

            if {[catch {set fd [open $descfile r]} err]} {
                ui_warn "Could not open global variant description file: $err"
                return ""
            }
            set lineno 0
            while {[gets $fd line] >= 0} {
                incr lineno
                set name [lindex $line 0]
                set desc [lindex $line 1]
                if {$name != "" && $desc != ""} {
                    set variant_descs_global(${descfile}_$name) $desc
                } else {
                    ui_warn "Invalid variant description in $descfile at line $lineno"
                }
            }
            close $fd
        }
    }
}

##
# Get description for a variant from global descriptions file
#
# @param porturl url to a port
# @param variant name
# @return description from descriptions file or an empty string
proc variant_desc {porturl variant} {
    global variant_descs_global

    set descfile [getportresourcepath $porturl "port1.0/variant_descriptions.conf" no]
    load_variant_desc_file $descfile

    if {[info exists variant_descs_global(${descfile}_${variant})]} {
        return $variant_descs_global(${descfile}_${variant})
    } else {
        set descfile [getdefaultportresourcepath "port1.0/variant_descriptions.conf"]
        load_variant_desc_file $descfile

        if {[info exists variant_descs_global(${descfile}_${variant})]} {
            return $variant_descs_global(${descfile}_${variant})
        }

        return ""
    }
}

# platform [<os> [<release>]] [<arch>]
# Portfile level procedure to provide support for declaring platform-specifics
# Basically, just a fancy 'if', so that Portfiles' platform declarations can
# be more readable, and support arch and version specifics
proc platform {args} {
    global os.platform os.subplatform os.arch os.major

    set len [llength $args]
    if {$len < 2} {
        return -code error "Malformed platform specification"
    }
    set code [lindex $args end]
    set os [lindex $args 0]
    set args [lrange $args 1 [expr $len - 2]]

    foreach arg $args {
        if {[regexp {(^[0-9]+$)} $arg match result]} {
            set release $result
        } elseif {[regexp {([a-zA-Z0-9]*)} $arg match result]} {
            set arch $result
        }
    }

    set match 0
    # 'os' could be a platform or an arch when it's alone
    if {$len == 2 && ($os == ${os.platform} || $os == ${os.subplatform} || $os == ${os.arch})} {
        set match 1
    } elseif {($os == ${os.platform} || $os == ${os.subplatform})
              && (![info exists release] || ${os.major} == $release)
              && (![info exists arch] || ${os.arch} == $arch)} {
        set match 1
    }

    # Execute the code if this platform matches the platform we're on
    if {$match} {
        uplevel 1 $code
    }
}

# Portfiles may define more than one port.
# This executes the given code in 'body' if we were opened as the specified
# subport, and also adds it to the list of subports that are defined.
proc subport {subname body} {
    global subport name PortInfo
    if {$subport == $name && $subname != $name && 
        (![info exists PortInfo(subports)] || [lsearch -exact $PortInfo(subports) $subname] == -1)} {
        lappend PortInfo(subports) $subname
    }
    if {[string equal -nocase $subname $subport]} {
        set PortInfo(name) $subname
        uplevel 1 $body
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

# Append one or more items to the key in the parsed environment.
proc append_to_environment_value {command key args} {
    upvar #0 ${command}.env_array($key) env_key
    foreach value $args {
        if {$value eq {}} {
            continue
        }
        # Parse out any delimiters. Is this even necessary anymore?
        regexp {^(['"])(.*)\1$} $value -> delim value

        append env_key " $value"
    }
    catch {set env_key [string trimleft $env_key]}
}

# Return a string representation of the specified environment, for
# debugging purposes.
proc environment_array_to_string {environment_array} {
    upvar 1 ${environment_array} env_array
    foreach {key value} [array get env_array] {
        lappend env_list $key='$value'
    }
    return [join $env_list]
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
    global env workpath worksrcpath macosx_version
    set extended 0
    set suppress 0
    set oldlocale_exists 0
    set oldlocale "" 
    set locale ""
    set dir ${worksrcpath}
    while 1 {
        set arg [lindex $args 0]
        if {[string index $arg 0] eq "-"} {
            set args [lrange $args 1 end]
            switch -- [string range $arg 1 end] {
                locale {
                    set oldlocale_exists [info exists env(LC_CTYPE)]
                    if {$oldlocale_exists} {
                        set oldlocale $env(LC_CTYPE)
                    }
                    set locale [lindex $args 0]
                    set args [lrange $args 1 end]
                }
                E {
                    set extended 1
                }
                n {
                    set suppress 1
                }
                W {
                    set dir [lindex $args 0]
                    set args [lrange $args 1 end]
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
        error "reinplace ?-E? ?-n? ?-W dir? pattern file ..."
    }
    set pattern [lindex $args 0]
    set files [lrange $args 1 end]

    if {[file isdirectory ${workpath}/.tmp]} {
        set tempdir ${workpath}/.tmp
    } else {
        set tempdir /tmp
    }

    foreach file $files {
        # if $file is an absolute path already, file join will just return the
        # absolute path, otherwise it is $dir/$file
        set file [file join $dir $file]

        if {[catch {set tmpfile [mkstemp "${tempdir}/[file tail $file].sed.XXXXXXXX"]} error]} {
            global errorInfo
            ui_debug "$errorInfo"
            ui_error "reinplace: $error"
            return -code error "reinplace failed"
        } else {
            # Extract the Tcl Channel number
            set tmpfd [lindex $tmpfile 0]
            # Set tmpfile to only the file name
            set tmpfile [join [lrange $tmpfile 1 end]]
        }

        set cmdline $portutil::autoconf::sed_command
        if {$extended} {
            if {$portutil::autoconf::sed_ext_flag == "N/A"} {
                ui_debug "sed extended regexp not available"
                return -code error "reinplace sed(1) too old"
            }
            lappend cmdline $portutil::autoconf::sed_ext_flag
        }
        if {$suppress} {
            lappend cmdline -n
        }
        set cmdline [concat $cmdline [list $pattern < $file >@ $tmpfd]]
        if {$locale != ""} {
            set env(LC_CTYPE) $locale
        }
        ui_debug "Executing reinplace: $cmdline"
        if {[catch {eval exec $cmdline} error]} {
            global errorInfo
            ui_debug "$errorInfo"
            ui_error "reinplace: $error"
            file delete "$tmpfile"
            if {$locale != ""} {
                if {$oldlocale_exists} {
                    set env(LC_CTYPE) $oldlocale
                } else {
                    unset env(LC_CTYPE)
                    if {$macosx_version == "10.5"} {
                        unsetenv LC_CTYPE
                    }
                }
            }
            close $tmpfd
            return -code error "reinplace sed(1) failed"
        }

        if {$locale != ""} {
            if {$oldlocale_exists} {
                set env(LC_CTYPE) $oldlocale
            } else {
                unset env(LC_CTYPE)
                if {$macosx_version == "10.5"} {
                    unsetenv LC_CTYPE
                }
            }
        }
        close $tmpfd

        set attributes [file attributes $file]
        # start gsoc08-privileges
        chownAsRoot $file
        # end gsoc08-privileges

        # We need to overwrite this file
        if {[catch {file attributes $file -permissions u+w} error]} {
            global errorInfo
            ui_debug "$errorInfo"
            ui_error "reinplace: $error"
            file delete "$tmpfile"
            return -code error "reinplace permissions failed"
        }

        if {[catch {file copy -force $tmpfile $file} error]} {
            global errorInfo
            ui_debug "$errorInfo"
            ui_error "reinplace: $error"
            file delete "$tmpfile"
            return -code error "reinplace copy failed"
        }

        fileAttrsAsRoot $file $attributes

        file delete "$tmpfile"
    }
    return
}

# delete
# file delete -force by itself doesn't handle directories properly
# on systems older than Tiger. Let's recurse using fs-traverse instead.
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
        return -code error {usage: touch [-a] [-c] [-m] [-r file] [-t [[CC]YY]MMDDhhmm[.SS]] file ...}
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
        return -code error [join {{usage: ln [-f] [-h] [-s] [-v] source_file [target_file]}
                                  {       ln [-f] [-h] [-s] [-v] file ... directory}} "\n"]
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
                # this error isn't strictly what BSD ln gives, but I think it's more useful
                return -code error "ln: $target: Not a directory"
            }
        }

        if {[info exists options(v)]} {
            ui_notice "ln: $linktarget -> $file"
        }
        if {[info exists options(s)]} {
            symlink $file $linktarget
        } else {
            file link -hard $linktarget $file
        }
    }
    return
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
        system "[findBinary lipo $portutil::autoconf::lipo_path] ${lipoSources}-create -output ${file}"
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
global ports_dry_last_skipped
set ports_dry_last_skipped ""

proc target_run {ditem} {
    global target_state_fd workpath portpath ports_trace PortInfo ports_dryrun \
           ports_dry_last_skipped worksrcpath prefix subport env portdbpath \
           macosx_version
    set portname $subport
    set result 0
    set skipped 0
    set procedure [ditem_key $ditem procedure]
    set savedhome [file join $portdbpath home]
    set env(HOME) "${workpath}/.home"
    set env(TMPDIR) "${workpath}/.tmp"

    if {[ditem_key $ditem state] != "no"} {
        set target_state_fd [open_statefile]
    }

    if {$procedure != ""} {
        set targetname [ditem_key $ditem name]
        set target [ditem_key $ditem provides]
        portsandbox::set_profile $target
        global ${target}.asroot
        if { [tbool ${target}.asroot] } {
            elevateToRoot $targetname
        }

        if {[ditem_contains $ditem init]} {
            set result [catch {[ditem_key $ditem init] $targetname} errstr]
            # Save variables in order to re-throw the same error code.
            set errcode $::errorCode
            set errinfo $::errorInfo
        }

        if {$result == 0} {
            # Skip the step if required and explain why through ui_debug.
            # check if the step was already done (as mentioned in the state file)
            if {[ditem_key $ditem state] != "no"
                    && [check_statefile target $targetname $target_state_fd]} {
                ui_debug "Skipping completed $targetname ($portname)"
                set skipped 1
            }

            # Of course, if this is a dry run, don't do the task:
            if {[info exists ports_dryrun] && $ports_dryrun == "yes"} {
                # only one message per portname
                if {$portname != $ports_dry_last_skipped} {
                    ui_notice "For $portname: skipping $targetname (dry run)"
                    set ports_dry_last_skipped $portname
                } else {
                    ui_info "    .. and skipping $targetname"
                }
                set skipped 1
            }

            # otherwise execute the task.
            if {$skipped == 0} {
                # change current phase shown in log
                set_phase $target

                # Execute pre-run procedure
                if {[ditem_contains $ditem prerun]} {
                    set result [catch {[ditem_key $ditem prerun] $targetname} errstr]
                    # Save variables in order to re-throw the same error code.
                    set errcode $::errorCode
                    set errinfo $::errorInfo
                }

                #start tracelib
                if {($result ==0
                  && [info exists ports_trace]
                  && $ports_trace == "yes"
                  && $target != "clean")} {
                    porttrace::trace_start $workpath

                    # Enable the fence to prevent any creation/modification
                    # outside the sandbox.
                    if {$target != "activate"
                      && $target != "archive"
                      && $target != "install"} {
                        porttrace::trace_enable_fence
                    }

                    # collect deps
                    set depends {}
                    set deptypes {}

                    # Determine deptypes to look for based on target
                    switch $target {
                        fetch       -
                        checksum    { set deptypes "depends_fetch" }
                        extract     -
                        patch       { set deptypes "depends_fetch depends_extract" }
                        configure   -
                        build       { set deptypes "depends_fetch depends_extract depends_lib depends_build" }

                        test        -
                        destroot    -
                        dmg         -
                        pkg         -
                        portpkg     -
                        mpkg        -
                        rpm         -
                        srpm        -
                        dpkg        -
                        mdmg        -
                        ""          { set deptypes "depends_fetch depends_extract depends_lib depends_build depends_run" }

                        # install may be run given an archive, which means
                        # depends_fetch, _extract, _build dependencies have
                        # never been installed
                        activate    -
                        install     { set deptypes "depends_lib depends_run" }
                    }

                    # Gather the dependencies for deptypes
                    foreach deptype $deptypes {
                        # Add to the list of dependencies if the option exists and isn't empty.
                        if {[info exists PortInfo($deptype)] && $PortInfo($deptype) != ""} {
                            set depends [concat $depends $PortInfo($deptype)]
                        }
                    }

                    # Recursively collect all dependencies from registry for tracing
                    set deplist {}
                    foreach depspec $depends {
                        # Resolve dependencies to actual ports
                        set name [_get_dep_port $depspec]

                        # If portname is empty, the dependency is already satisfied by other means,
                        # for example a bin: dependency on a file not installed by MacPorts
                        if {$name != ""} {
                            if {[lsearch -exact $deplist $name] == -1} {
                                lappend deplist $name
                                set deplist [recursive_collect_deps $name $deplist]
                            }
                        }
                    }

                    # Add ccache port for access to ${prefix}/bin/ccache binary
                    if [option configure.ccache] {
                        lappend deplist ccache
                    }

                    ui_debug "Tracemode will respect recursively collected port dependencies: [lsort $deplist]"

                    if {[llength $deptypes] > 0} {tracelib setdeps $deplist}
                }

                if {$result == 0} {
                    foreach pre [ditem_key $ditem pre] {
                        ui_debug "Executing $pre"
                        set result [catch {eval $pre $targetname} errstr]
                        # Save variables in order to re-throw the same error code.
                        set errcode $::errorCode
                        set errinfo $::errorInfo
                        if {$result != 0} { break }
                    }
                }

                if {$result == 0} {
                    ui_debug "Executing $targetname ($portname)"
                    set result [catch {eval $procedure $targetname} errstr]
                    # Save variables in order to re-throw the same error code.
                    set errcode $::errorCode
                    set errinfo $::errorInfo
                }

                if {$result == 0} {
                    foreach post [ditem_key $ditem post] {
                        ui_debug "Executing $post"
                        set result [catch {eval $post $targetname} errstr]
                        # Save variables in order to re-throw the same error code.
                        set errcode $::errorCode
                        set errinfo $::errorInfo
                        if {$result != 0} { break }
                    }
                }
                # Execute post-run procedure
                if {[ditem_contains $ditem postrun] && $result == 0} {
                    set postrun [ditem_key $ditem postrun]
                    ui_debug "Executing $postrun"
                    set result [catch {eval $postrun $targetname} errstr]
                    # Save variables in order to re-throw the same error code.
                    set errcode $::errorCode
                    set errinfo $::errorInfo
                }

                # Check dependencies & file creations outside workpath.
                if {[info exists ports_trace]
                  && $ports_trace == "yes"
                  && $target!="clean"} {

                    tracelib closesocket

                    porttrace::trace_check_violations

                    # End of trace.
                    porttrace::trace_stop
                }
            }
        }
        if {[exists copy_log_files]} {
            set log_files [option copy_log_files]
            set log_dir [getportlogpath $portpath $subport]
            file mkdir $log_dir
 
            foreach log_file $log_files {
                set from "$worksrcpath/$log_file"
                if {[file exists $from]} {
                    file copy -force $from $log_dir
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
            write_statefile target $targetname $target_state_fd
            }
        } else {
            ui_error "$targetname for port $portname returned: $errstr"
            ui_debug "Error code: $errcode"
            ui_debug "Backtrace: $errinfo"
            set result 1
        }

    } else {
        ui_info "Warning: $targetname does not have a registered procedure"
        set result 1
    }

    if {[ditem_key $ditem state] != "no"} {
        close $target_state_fd
    }

    set env(HOME) $savedhome
    if {[info exists env(TMPDIR)]} {
        unset env(TMPDIR)
        if {$macosx_version == "10.5"} {
            unsetenv TMPDIR
        }
    }

    return $result
}

# recursive dependency search for portname
proc recursive_collect_deps {portname {depsfound {}}} \
{
    # Get the active port from the registry
    # There can be only one port active at a time, so take the first result only
    set regentry [lindex [registry_active $portname] 0]
    # Get port dependencies from the registry
    set deplist [registry_list_depends [lindex $regentry 0] [lindex $regentry 1] [lindex $regentry 2] [lindex $regentry 3]]

    foreach item $deplist {
        set name [lindex $item 0]
        if {[lsearch -exact $depsfound $name] == -1} {
            lappend depsfound $name
            set depsfound [recursive_collect_deps $name $depsfound]
        }
    }

    return $depsfound
}


proc eval_targets {target} {
    global targets target_state_fd subport version revision portvariants epoch ports_dryrun user_options
    set dlist $targets

    # the statefile will likely be autocleaned away after install,
    # so special-case already-completed install and activate
    if {[registry_exists $subport $version $revision $portvariants]} {
        if {$target == "install"} {
            ui_debug "Skipping $target ($subport) since this port is already installed"
            return 0
        } elseif {$target == "activate"} {
            set regref [registry_open $subport $version $revision $portvariants ""]
            if {[registry_prop_retr $regref active] != 0} {
                # Something to close the registry entry may be called here, if it existed.
                ui_debug "Skipping $target ($subport @${version}_${revision}${portvariants}) since this port is already active"
                return 0
            } else {
                # run the activate target but ignore its (completed) dependencies
                set result [target_run [lindex [dlist_search $dlist provides $target] 0]]
                if {[getuid] == 0 && [geteuid] != 0} {
                    seteuid 0; setegid 0
                }
                return $result
            }
        }
    }

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

    set dlist [dlist_eval $dlist "" target_run]

    if {[getuid] == 0 && [geteuid] != 0} {
        seteuid 0; setegid 0
    }

    if {[llength $dlist] > 0} {
        # somebody broke!
        set errstring "Warning: targets not executed for $subport:"
        foreach ditem $dlist {
            append errstring " [ditem_key $ditem name]"
        }
        ui_info $errstring
        set result 1
    } else {
        set result 0
    }

    return $result
}

# open_statefile
# open file to store name of completed targets
proc open_statefile {args} {
    global workpath worksymlink place_worksymlink subport portpath ports_ignore_different ports_dryrun \
           usealtworkpath altprefix env applications_dir subbuildpath

    if {$usealtworkpath} {
         ui_warn_once "privileges" "MacPorts running without privileges.\
                You may be unable to complete certain actions (e.g. install)."

        set newsourcepath "${altprefix}${portpath}"
    
        # copy Portfile (and patch files) if not there already
        # note to maintainers/devs: the original portfile in /opt/local is ALWAYS the one that will be
        #    read by macports. The copying of the portfile is done to preserve the symlink provided
        #    historically by macports from the portfile directory to the work directory.
        #    It is NOT read by MacPorts.
        if {![file exists ${newsourcepath}/Portfile] && ![tbool ports_dryrun]} {
            file mkdir $newsourcepath
            ui_debug "$newsourcepath created"
            ui_debug "Going to copy: ${portpath}/Portfile"
            file copy ${portpath}/Portfile $newsourcepath
            if {[file exists ${portpath}/files] } {
                ui_debug "Going to copy: ${portpath}/files"
                file copy ${portpath}/files $newsourcepath
            }
        }
    }

    if {![tbool ports_dryrun]} {
        set need_chown 0
        if {![file isdirectory $workpath/.home]} {
            file mkdir $workpath/.home
            set need_chown 1
        }
        if {![file isdirectory $workpath/.tmp]} {
            file mkdir $workpath/.tmp
            set need_chown 1
        }
        if {$need_chown} {
            chownAsRoot $subbuildpath
        }
        # Create a symlink to the workpath for port authors
        if {[tbool place_worksymlink] && ![file isdirectory $worksymlink]} {
            ui_debug "Attempting ln -sf $workpath $worksymlink"
            ln -sf $workpath $worksymlink
        }
    }

    # de-escalate privileges if MacPorts was started with sudo
    dropPrivileges

    # flock Portfile
    set statefile [file join $workpath .macports.${subport}.state]
    set fresh_build yes
    set checksum_portfile [sha256 file ${portpath}/Portfile]
    if {[file exists $statefile]} {
        set fresh_build no
        if {![file writable $statefile] && ![tbool ports_dryrun]} {
            return -code error "$statefile is not writable - check permission on port directory"
        }
        if {[file mtime ${portpath}/Portfile] > [clock seconds]} {
            return -code error "Portfile is from the future - check date and time of your system"
        }
        if {![tbool ports_ignore_different]} {
            # start by assuming the statefile is current
            set portfile_changed no

            # open the statefile, determine the statefile version
            set readfd [open $statefile r]
            set statefile_version 1
            if {[get_statefile_value "version" $readfd result] != 0} {
                set statefile_version $result
            }

            # check for outdated statefiles depending on what version the
            # statefile is; we explicitly support older statefiles here, because
            # all previously built archives would be invalidated (e.g., when
            # using mpkg) if we didn't
            switch $statefile_version {
                1 {
                    # statefile version 1
                    # this statefile doesn't have a checksum, fall back to
                    # comparing the Portfile modification date with the
                    # statefile modification date
                    if {[file mtime $statefile] < [file mtime ${portpath}/Portfile]} {
                        ui_debug "Statefile has version 1 and is older than Portfile"
                        set portfile_changed yes
                    }
                }
                2 {
                    # statefile version 2
                    # this statefile has a sha256 checksum of the Portfile in
                    # the "checksum" key
                    set checksum_statefile ""
                    if {[get_statefile_value "checksum" $readfd checksum_statefile] == 0} {
                        ui_warn "Statefile has version 2 but didn't contain a checksum"
                        set portfile_changed yes
                    } else {
                        if {$checksum_portfile != $checksum_statefile} {
                            ui_debug "Checksum recorded in statefile '$checksum_statefile' differs from Portfile checksum '$checksum_portfile'"
                            set portfile_changed yes
                        }
                    }
                }
                default {
                    ui_warn "Unsupported statefile version '$statefile_version'"
                    ui_warn "Please run 'port selfupdate' to update to the latest version of MacPorts"
                }
            }
            if {[tbool portfile_changed]} {
                if {![tbool ports_dryrun]} {
                    ui_notice "Portfile changed since last build; discarding previous state."
                    chownAsRoot $subbuildpath
                    delete $workpath
                    file mkdir $workpath
                    set fresh_build yes
                } else {
                    ui_notice "Portfile changed since last build but not discarding previous state (dry run)"
                }
            }
            close $readfd
        }
    } elseif {[tbool ports_dryrun]} {
        set statefile /dev/null
    }

    set fd [open $statefile a+]
    if {![tbool ports_dryrun]} {
        if {[catch {flock $fd -exclusive -noblock} result]} {
            if {"$result" == "EAGAIN"} {
                ui_notice "Waiting for lock on $statefile"
                flock $fd -exclusive
            } elseif {"$result" == "EOPNOTSUPP"} {
                # Locking not supported, just return
                return $fd
            } else {
                return -code error "$result obtaining lock on $statefile"
            }
        }
    }
    if {[tbool fresh_build]} {
        write_statefile "version" 2 $fd
        write_statefile "checksum" $checksum_portfile $fd
    }
    return $fd
}

# get_statefile_value
# Check for a given $class in the statefile $fd and write the first match to
# $result, if any. Returns 1 if a line matched, 0 otherwise
proc get_statefile_value {class fd result} {
    upvar $result upresult
    seek $fd 0
    while {[gets $fd line] >= 0} {
        if {[regexp "$class: (.*)" $line match value]} {
            set upresult $value
            return 1
        }
    }
    return 0
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

# Change the value of an existing statefile key
# caller must call open_statefile after this
proc update_statefile {class name path} {
    set fd [open $path r]
    while {[gets $fd line] >= 0} {
        if {[lindex $line 0] != "${class}:"} {
            lappend lines $line
        }
    }
    close $fd
    # truncate
    set fd [open $path w]
    puts $fd "$class: $name"
    foreach line $lines {
        puts $fd $line
    }
    close $fd
}

##
# Check that recorded selection of variants match the current selection
#
# @param variations input array name of new variants
# @param oldvariations output array name of old variants
# @param fd file descriptor of the state file
# @return 0 if variants match, 1 otherwise
proc check_statefile_variants {variations oldvariations fd} {
    upvar $variations upvariations
    upvar $oldvariations upoldvariations

    array set upoldvariations {}

    set variants_found no
    set targets_found no
    seek $fd 0
    while {[gets $fd line] >= 0} {
        if {[regexp "variant: (.*)" $line match name]} {
            set upoldvariations([string range $name 1 end]) [string range $name 0 0]
            set variants_found yes
        }
        if {[regexp "target: .*" $line]} {
            set targets_found yes
        }
    }

    if {![tbool variants_found] && ![tbool targets_found]} {
        # Statefile is "empty", skipping further tests
        return 0
    }

    set mismatch 0
    if {[array size upoldvariations] != [array size upvariations]} {
        set mismatch 1
    } else {
        foreach key [array names upvariations *] {
            if {![info exists upoldvariations($key)] || $upvariations($key) != $upoldvariations($key)} {
                set mismatch 1
                break
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
    set negated [list]

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

        if {$cons > 0} {
            lappend negated $ditem
        }
        if {$pros > 0 && $ignored == 0} {
            lappend selected $ditem
        }
    }
    return [list $selected $negated]
}

proc variant_run {ditem} {
    set name [ditem_key $ditem name]
    ui_debug "Executing variant $name provides [ditem_key $ditem provides]"

    # test for conflicting variants
    foreach v [ditem_key $ditem conflicts] {
        if {[variant_isset $v]} {
            ui_error "[option name]: Variant $name conflicts with $v"
            return 1
        }
    }

    # execute proc with same name as variant.
    if {[catch "variant-${name}" result]} {
        global errorInfo
        ui_debug "$errorInfo"
        ui_error "[option name]: Error executing $name: $result"
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
    # Can also do the same for -variants, for recording the negated list.
proc canonicalize_variants {variants {sign "+"}} {
    array set vara $variants
    set result ""
    set vlist [lsort -ascii [array names vara]]
    foreach v $vlist {
        if {$vara($v) == $sign} {
            append result "${sign}${v}"
        }
    }
    return $result
}

proc eval_variants {variations} {
    global all_variants ports_force PortInfo requested_variations portvariants negated_variants
    set dlist $all_variants
    upvar $variations upvariations
    set chosen [choose_variants $dlist upvariations]
    set negated [lindex $chosen 1]
    set chosen [lindex $chosen 0]
    set portname [option subport]

    # Check to make sure the requested variations are available with this
    # port, if one is not, warn the user and remove the variant from the
    # array.
    # Save the originally requested set in requested_variations.
    array set requested_variations [array get upvariations]
    foreach key [array names upvariations *] {
        if {![info exists PortInfo(variants)] ||
            [lsearch $PortInfo(variants) $key] == -1} {
            ui_debug "Requested variant $upvariations($key)$key is not provided by port $portname."
            array unset upvariations $key
        }
    }

    # now that we've selected variants, change all provides [a b c] to [a-b-c]
    # this will eliminate ambiguity between item a, b, and a-b while fulfilling requirements.
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
    set activevariants [list]
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
        lappend activevariants $thevar "+"
    }

    # Record a canonical variant string, used e.g. in accessing the registry
    set portvariants [canonicalize_variants $activevariants]

    # Make this important information visible in PortInfo
    set PortInfo(active_variants) $activevariants
    set PortInfo(canonical_active_variants) $portvariants

    # now set the negated variants
    set negated_list [list]
    foreach dvar $negated {
        set thevar [ditem_key $dvar provides]
        lappend negated_list $thevar "-"
    }
    set negated_variants [canonicalize_variants $negated_list "-"]

    return 0
}

proc check_variants {target} {
    global targets ports_force ports_dryrun PortInfo
    set result 0
    array set variations $PortInfo(active_variants)

    # Make sure the variations match those stored in the statefile.
    # If they don't match, print an error indicating a 'port clean'
    # should be performed.
    # - Skip this test if the target indicated target_state no
    # - Skip this test if the statefile is empty.
    # - Skip this test if ports_force was specified.

    # Assume we do not need the statefile
    set statereq 0
    set ditems [dlist_search $targets provides $target]
    if {[llength $ditems] > 0} {
        set ditems [dlist_append_dependents $targets [lindex $ditems 0] [list]]
    }
    foreach d $ditems {
        if {[ditem_key $d state] != "no"} {
            # At least one matching target requires the state file
            set statereq 1
            break
        }
    }
    if { $statereq &&
        !([info exists ports_force] && $ports_force == "yes")} {

        set state_fd [open_statefile]

        array set oldvariations {}
        if {[check_statefile_variants variations oldvariations $state_fd]} {
            ui_error "Requested variants \"[canonicalize_variants [array get variations]]\" do not match original selection \"[canonicalize_variants [array get oldvariations]]\".\nPlease use the same variants again, perform 'port clean [option subport]' or specify the force option (-f)."
            set result 1
        } elseif {!([info exists ports_dryrun] && $ports_dryrun == "yes")} {
            # Write variations out to the statefile
            foreach key [array names variations *] {
                write_statefile variant $variations($key)$key $state_fd
            }
        }

        close $state_fd
    }

    return $result
}

# add the default universal variant if appropriate
proc universal_setup {args} {
    if {[variant_exists universal]} {
        ui_debug "universal variant already exists, so not adding the default one"
    } elseif {[exists universal_variant] && ![option universal_variant]} {
        ui_debug "universal_variant is false, so not adding the default universal variant"
    } elseif {[exists use_xmkmf] && [option use_xmkmf]} {
        ui_debug "using xmkmf, so not adding the default universal variant"
    } elseif {![exists os.universal_supported] || ![option os.universal_supported]} {
        ui_debug "OS doesn't support universal builds, so not adding the default universal variant"
    } elseif {[llength [option supported_archs]] == 1} {
        ui_debug "only one arch supported, so not adding the default universal variant"
    } else {
        ui_debug "adding the default universal variant"
        variant universal {}
    }
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
        if {[info commands $target] == ""} {
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
    global PortInfo variations
    switch -regex $action {
        set|append {
            # Retrieve the information associated with each variant.
            if {![info exists PortInfo(vinfo)]} {
                set PortInfo(vinfo) {}
            }
            array set vinfo $PortInfo(vinfo)

            foreach v $value {
                if {[regexp {([-+])([-A-Za-z0-9_]+)} $v whole val variant] && ![info exists variations($variant)]} {
                    # Retrieve the information associated with this variant.
                    if {![info exists vinfo($variant)]} {
                        set vinfo($variant) {}
                    }
                    array unset info
                    array set info $vinfo($variant)
                    # Set is_default and update vinfo.
                    set info(is_default) $val
                    array set vinfo [list $variant [array get info]]

                    set variations($variant) $val
                }
            }
            # Update PortInfo(vinfo).
            set PortInfo(vinfo) [array get vinfo]
        }
        delete {
            # xxx
        }
    }
}

# create all users/groups listed in the add_users option
# format: [username [option=value ...] ...]
proc handle_add_users {} {
    set cur ""
    foreach val [option add_users] {
        if {[string match *=* $val] && $cur != ""} {
            set split_arg [split $val =]
            if {[lindex $split_arg 0] == "group"} {
                set groupname [lindex $split_arg 1]
                addgroup $groupname
                lappend args($cur) gid=[existsgroup $groupname]
            } else {
                lappend args($cur) $val
            }
        } else {
            set cur $val
        }
    }
    foreach username [array names args] {
        eval adduser $username $args($username)
    }
}

proc adduser {name args} {
    global os.platform

    if {[getuid] != 0} {
        ui_warn "adduser only works when running as root."
        ui_warn "The requested user '$name' was not created."
        return
    } elseif {[geteuid] != 0} {
        seteuid 0; setegid 0
        set escalated 1
    }

    set passwd {*}
    set uid [nextuid]
    set gid [existsgroup nogroup]
    set realname ${name}
    set home /var/empty
    set shell /usr/bin/false

    foreach arg $args {
        if {[regexp {([a-z]*)=(.*)} $arg match key val]} {
            set $key $val
        }
    }

    if {[existsuser ${name}] != 0 || [existsuser ${uid}] != 0} {
        return
    }

    if {${os.platform} eq "darwin"} {
        set dscl [findBinary dscl $portutil::autoconf::dscl_path]
        exec $dscl . -create /Users/${name} UniqueID ${uid}

        # These are implicitly added on Mac OSX Lion.  AuthenticationAuthority
        # causes the user to be visible in the Users & Groups Preference Pane,
        # and the others are just noise, so delete them.
        # https://trac.macports.org/ticket/30168
        exec $dscl . -delete /Users/${name} AuthenticationAuthority
        exec $dscl . -delete /Users/${name} PasswordPolicyOptions
        exec $dscl . -delete /Users/${name} dsAttrTypeNative:KerberosKeys
        exec $dscl . -delete /Users/${name} dsAttrTypeNative:ShadowHashData

        exec $dscl . -create /Users/${name} RealName ${realname}
        exec $dscl . -create /Users/${name} Password ${passwd}
        exec $dscl . -create /Users/${name} PrimaryGroupID ${gid}
        exec $dscl . -create /Users/${name} NFSHomeDirectory ${home}
        exec $dscl . -create /Users/${name} UserShell ${shell}
    } else {
        # XXX adduser is only available for darwin, add more support here
        ui_warn "adduser is not implemented on ${os.platform}."
        ui_warn "The requested user '$name' was not created."
    }

    if {[info exists escalated]} {
        dropPrivileges
    }
}

proc addgroup {name args} {
    global os.platform

    if {[getuid] != 0} {
        ui_warn "addgroup only works when running as root."
        ui_warn "The requested group '$name' was not created."
        return
    } elseif {[geteuid] != 0} {
        seteuid 0; setegid 0
        set escalated 1
    }

    set gid [nextgid]
    set realname ${name}
    set passwd {*}
    set users ""

    foreach arg $args {
        if {[regexp {([a-z]*)=(.*)} $arg match key val]} {
            set $key $val
        }
    }

    if {[existsgroup ${name}] != 0 || [existsgroup ${gid}] != 0} {
        return
    }

    if {${os.platform} eq "darwin"} {
        set dscl [findBinary dscl $portutil::autoconf::dscl_path]
        exec $dscl . -create /Groups/${name} Password ${passwd}
        exec $dscl . -create /Groups/${name} RealName ${realname}
        exec $dscl . -create /Groups/${name} PrimaryGroupID ${gid}
        if {${users} ne ""} {
            exec $dscl . -create /Groups/${name} GroupMembership ${users}
        }
    } else {
        # XXX addgroup is only available for darwin, add more support here
        ui_warn "addgroup is not implemented on ${os.platform}."
        ui_warn "The requested group was not created."
    }

    if {[info exists escalated]} {
        dropPrivileges
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
    global porturl

    set groupFile [getportresourcepath $porturl "port1.0/group/${group}-${version}.tcl"]

    if {[file exists $groupFile]} {
        uplevel "source $groupFile"
    } else {
        ui_warn "PortGroup ${group} ${version} could not be located. ${group}-${version}.tcl does not exist."
    }
}

# return filename of the archive for this port
proc get_portimage_name {} {
    global portdbpath subport version revision portvariants os.platform os.major portarchivetype
    set ret "${subport}-${version}_${revision}${portvariants}.${os.platform}_${os.major}.[join [get_canonical_archs] -].${portarchivetype}"
    # should really look up NAME_MAX here, but it's 255 for all OS X so far
    # (leave 10 chars for an extension like .rmd160 on the sig file)
    if {[string length $ret] > 245 && ${portvariants} != ""} {
        # try hashing the variants
        set ret "${subport}-${version}_${revision}+[rmd160 string ${portvariants}].${os.platform}_${os.major}.[join [get_canonical_archs] -].${portarchivetype}"
    }
    if {[string length $ret] > 245} {
        error "filename too long: $ret"
    }
    return $ret
}

# return path where a newly created image/archive for this port will be stored
proc get_portimage_path {} {
    global portdbpath subport
    return [file join ${portdbpath} software ${subport} [get_portimage_name]]
}

# return list of archive types that we can extract
proc supportedArchiveTypes {} {
    global supported_archive_types
    if {![info exists supported_archive_types]} {
        set supported_archive_types {}
        foreach type {tbz2 tbz tgz tar txz tlz xar zip cpgz cpio} {
            if {[catch {archiveTypeIsSupported $type}] == 0} {
                lappend supported_archive_types $type
            }
        }
    }
    return $supported_archive_types
}

# return path to a downloaded or installed archive for this port
proc find_portarchive_path {} {
    global portdbpath subport version revision portvariants force_archive_refresh
    set installed 0
    if {[registry_exists $subport $version $revision $portvariants]} {
        set installed 1
    }
    set archiverootname [file rootname [get_portimage_name]]
    foreach unarchive.type [supportedArchiveTypes] {
        set fullarchivename "${archiverootname}.${unarchive.type}"
        if {$installed && ![tbool force_archive_refresh]} {
            set fullarchivepath [file join $portdbpath software $subport $fullarchivename]
        } else {
            set fullarchivepath [file join $portdbpath incoming/verified $fullarchivename]
        }
        if {[file isfile $fullarchivepath]} {
            return $fullarchivepath
        }
    }
    return ""
}

# check if archive type is supported by current system
# returns an error code if it is not
proc archiveTypeIsSupported {type} {
    global os.platform os.version
    set errmsg ""
    switch -regex $type {
        cp(io|gz) {
            set pax "pax"
            if {[catch {set pax [findBinary $pax ${portutil::autoconf::pax_path}]} errmsg] == 0} {
                if {[regexp {z$} $type]} {
                    set gzip "gzip"
                    if {[catch {set gzip [findBinary $gzip ${portutil::autoconf::gzip_path}]} errmsg] == 0} {
                        return 0
                    }
                } else {
                    return 0
                }
            }
        }
        t(ar|bz|lz|xz|gz) {
            set tar "tar"
            if {[catch {set tar [findBinary $tar ${portutil::autoconf::tar_path}]} errmsg] == 0} {
                if {[regexp {z2?$} $type]} {
                    if {[regexp {bz2?$} $type]} {
                        set gzip "bzip2"
                    } elseif {[regexp {lz$} $type]} {
                        set gzip "lzma"
                    } elseif {[regexp {xz$} $type]} {
                        set gzip "xz"
                    } else {
                        set gzip "gzip"
                    }
                    if {[info exists portutil::autoconf::${gzip}_path]} {
                        set hint [set portutil::autoconf::${gzip}_path]
                    } else {
                        set hint ""
                    }
                    if {[catch {set gzip [findBinary $gzip $hint]} errmsg] == 0} {
                        return 0
                    }
                } else {
                    return 0
                }
            }
        }
        xar {
            set xar "xar"
            if {[catch {set xar [findBinary $xar ${portutil::autoconf::xar_path}]} errmsg] == 0} {
                return 0
            }
        }
        zip {
            set zip "zip"
            if {[catch {set zip [findBinary $zip ${portutil::autoconf::zip_path}]} errmsg] == 0} {
                set unzip "unzip"
                if {[catch {set unzip [findBinary $unzip ${portutil::autoconf::unzip_path}]} errmsg] == 0} {
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

# return the specified piece of metadata from the +CONTENTS file in the given archive
proc extract_archive_metadata {archive_location archive_type metadata_type} {
    set qflag ${portutil::autoconf::tar_q}
    set raw_contents ""

    switch -- $archive_type {
        xar -
        cpgz -
        cpio {
            set twostep 1
            global workpath
            if {[file isdirectory ${workpath}/.tmp]} {
                set tempdir [mkdtemp ${workpath}/.tmp/portarchiveXXXXXXXX]
            } else {
                set tempdir [mkdtemp /tmp/portarchiveXXXXXXXX]
            }
        }
    }

    switch -- $archive_type {
        tbz -
        tbz2 {
            set raw_contents [exec [findBinary tar ${portutil::autoconf::tar_path}] -xOj${qflag}f $archive_location ./+CONTENTS]
        }
        tgz {
            set raw_contents [exec [findBinary tar ${portutil::autoconf::tar_path}] -xOz${qflag}f $archive_location ./+CONTENTS]
        }
        tar {
            set raw_contents [exec [findBinary tar ${portutil::autoconf::tar_path}] -xO${qflag}f $archive_location ./+CONTENTS]
        }
        txz {
            set raw_contents [exec [findBinary tar ${portutil::autoconf::tar_path}] -xO${qflag}f $archive_location --use-compress-program [findBinary xz ""] ./+CONTENTS]
        }
        tlz {
            set raw_contents [exec [findBinary tar ${portutil::autoconf::tar_path}] -xO${qflag}f $archive_location --use-compress-program [findBinary lzma ""] ./+CONTENTS]
        }
        xar {
            system -W ${tempdir} "[findBinary xar ${portutil::autoconf::xar_path}] -xf $archive_location +CONTENTS"
        }
        zip {
            set raw_contents [exec [findBinary unzip ${portutil::autoconf::unzip_path}] -p $archive_location +CONTENTS]
        }
        cpgz {
            system -W ${tempdir} "[findBinary pax ${portutil::autoconf::pax_path}] -rzf $archive_location +CONTENTS"
        }
        cpio {
            system -W ${tempdir} "[findBinary pax ${portutil::autoconf::pax_path}] -rf $archive_location +CONTENTS"
        }
    }
    if {[info exists twostep]} {
        set fd [open "${tempdir}/+CONTENTS"]
        set raw_contents [read $fd]
        close $fd
        file delete -force $tempdir
    }
    if {$metadata_type == "contents"} {
        set contents {}
        set ignore 0
        set sep [file separator]
        foreach line [split $raw_contents \n] {
            if {$ignore} {
                set ignore 0
                continue
            }
            if {[string index $line 0] != "@"} {
                lappend contents "${sep}${line}"
            } elseif {$line == "@ignore"} {
                set ignore 1
            }
        }
        return $contents
    } elseif {$metadata_type == "portname"} {
        foreach line [split $raw_contents \n] {
            if {[lindex $line 0] == "@portname"} {
                return [lindex $line 1]
            }
        }
        return ""
    } else {
        return -code error "unknown metadata_type: $metadata_type"
    }
}

#
# merge function for universal builds
#

# private function
# merge_lipo base-path target-path relative-path architectures
# e.g. 'merge_lipo ${workpath}/pre-dest ${destroot} ${prefix}/bin/pstree i386 ppc
# will merge binary files with lipo which have to be in the same (relative) path
proc merge_lipo {base target file archs} {
    set exec-lipo [list [findBinary lipo $portutil::autoconf::lipo_path]]
    foreach arch ${archs} {
        lappend exec-lipo -arch ${arch} ${base}/${arch}${file}
    }
    eval exec ${exec-lipo} [list -create -output ${target}${file}]
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
        exec [findBinary diff $portutil::autoconf::diff_path] "-q" "${base}/${basearch}${file}" "${base}/${arch}${file}"
    }
    ui_debug "ba: '${basearch}'"
    file copy "${base}/${basearch}${file}" "${target}${file}"
}

# merges multiple "single-arch" destroots into the final destroot
# 'base' is the path where the different directories (one for each arch) are
# e.g. call 'merge ${workpath}/pre-dest' with having a destroot in ${workpath}/pre-dest/i386 and ${workpath}/pre-dest/ppc64 -- single arch -- each
proc merge {base} {
    global destroot configure.universal_archs

    # test which architectures are available, set one as base-architecture
    set archs ""
    set base_arch ""
    foreach arch ${configure.universal_archs} {
        if [file exists "${base}/${arch}"] {
            set archs [concat ${archs} ${arch}]
            set base_arch ${arch}
        }
    }
    if {"" == ${base_arch}} {
        return -code error [format [msgcat::mc "Cannot merge because directory '%s' contains no architecture directories."] ${base}]
    }
    ui_debug "merging architectures ${archs}, base_arch is ${base_arch}"

    # traverse the base-architecture directory
    set basepath "${base}/${base_arch}"
    fs-traverse file "${basepath}" {
        set fpath [string range "${file}" [string length "${basepath}"] [string length "${file}"]]
        if {${fpath} != ""} {
            # determine the type (dir/file/link)
            switch [file type ${basepath}${fpath}] {
                directory {
                    # just create directories
                    ui_debug "mrg: directory ${fpath}"
                    file mkdir "${destroot}${fpath}"
                }
                link {
                    # copy symlinks, TODO: check if targets match!
                    ui_debug "mrg: symlink ${fpath}"
                    file copy "${basepath}${fpath}" "${destroot}${fpath}"
                }
                default {
                    set filetype [exec [findBinary file $portutil::autoconf::file_path] "-b" "${basepath}${fpath}"]
                    switch -regexp ${filetype} {
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
    }
}

##
# Escape a string for safe use in regular expressions
#
# @param str the string to be quoted
# @return the escaped string
proc quotemeta {str} {
    regsub -all {(\W)} $str {\\\1} str
    return $str
}

##
# Recusively chown the given file or directory to the specified user.
#
# @param path the file/directory to be chowned
# @param user the user to chown file to
proc chown {path user} {
    lchown $path $user

    if {[file isdirectory $path]} {
        fs-traverse myfile ${path} {
            lchown $myfile $user
        }
    }

}

##
# Recusively chown the given file or directory to $macportsuser, using root privileges.
#
# @param path the file/directory to be chowned
proc chownAsRoot {path} {
    global euid egid macportsuser

    if { [getuid] == 0 } {
        if {[geteuid] != 0} {
            # if started with sudo but have dropped the privileges
            seteuid $euid
            setegid $egid
            ui_debug "euid/egid changed to: [geteuid]/[getegid]"
            chown  ${path} ${macportsuser}
            ui_debug "chowned $path to $macportsuser"
            setegid [uname_to_gid "$macportsuser"]
            seteuid [name_to_uid "$macportsuser"]
            ui_debug "euid/egid changed to: [geteuid]/[getegid]"
        } else {
            # if started with sudo but have elevated back to root already
            chown  ${path} ${macportsuser}
        }
    }
}

##
# Change attributes of file while running as root
#
# @param file the file in question
# @param attributes the attributes for the file
proc fileAttrsAsRoot {file attributes} {
    global euid egid macportsuser
    if {[getuid] == 0} {
        if {[geteuid] != 0} {
            # Started as root, but not root now
            seteuid $euid
            setegid $egid
            ui_debug "euid/egid changed to: [geteuid]/[getegid]"
            ui_debug "setting attributes on $file"
            eval file attributes {$file} $attributes
            setegid [uname_to_gid "$macportsuser"]
            seteuid [name_to_uid "$macportsuser"]
            ui_debug "euid/egid changed to: [geteuid]/[getegid]"
        } else {
            eval file attributes {$file} $attributes
        }
    } else {
        # not root, so can't set owner/group
        set permissions [lindex $attributes [expr [lsearch $attributes "-permissions"] + 1]]
        file attributes $file -permissions $permissions
    }
}

##
# Elevate privileges back to root.
#
# @param action the action for which privileges are being elevated
proc elevateToRoot {action} {
    global euid egid macportsuser

    if { [getuid] == 0 && [geteuid] != 0 } {
    # if started with sudo but have dropped the privileges
        ui_debug "Can't run $action on this port without elevated privileges. Escalating privileges back to root."
        seteuid $euid
        setegid $egid
        ui_debug "euid changed to: [geteuid]. egid changed to: [getegid]."
    } elseif { [getuid] != 0 } {
        return -code error "MacPorts requires root privileges for this action"
    }
}

##
# de-escalate privileges from root to those of $macportsuser.
#
proc dropPrivileges {} {
    global euid egid macportsuser workpath
    if { [geteuid] == 0 } {
        if { [catch {
                if {[name_to_uid "$macportsuser"] != 0} {
                    ui_debug "changing euid/egid - current euid: $euid - current egid: $egid"

                    #seteuid [name_to_uid [file attributes $workpath -owner]]
                    #setegid [name_to_gid [file attributes $workpath -group]]

                    setegid [uname_to_gid "$macportsuser"]
                    seteuid [name_to_uid "$macportsuser"]
                    ui_debug "egid changed to: [getegid]"
                    ui_debug "euid changed to: [geteuid]"
                }
            }]
        } {
            ui_debug "$::errorInfo"
            ui_error "Failed to de-escalate privileges."
        }
    } else {
        ui_debug "Privilege de-escalation not attempted as not running as root."
    }
}

proc validate_macportsuser {} {
    global macportsuser
    if {[getuid] == 0 && $macportsuser != "root" && 
        ([existsuser $macportsuser] == 0 || [existsgroup $macportsuser] == 0 )} {
        ui_warn "configured user/group $macportsuser does not exist, will build as root"
        set macportsuser "root"
    }
}

# dependency analysis helpers

### _libtest is private; subject to change without notice
# XXX - Architecture specific
# XXX - Rely on information from internal defines in cctools/dyld:
# define DEFAULT_FALLBACK_FRAMEWORK_PATH
# /Library/Frameworks:/Library/Frameworks:/Network/Library/Frameworks:/System/Library/Frameworks
# define DEFAULT_FALLBACK_LIBRARY_PATH /lib:/usr/local/lib:/lib:/usr/lib
#   -- Since /usr/local is bad, using /lib:/usr/lib only.
# Environment variables DYLD_FRAMEWORK_PATH, DYLD_LIBRARY_PATH,
# DYLD_FALLBACK_FRAMEWORK_PATH, and DYLD_FALLBACK_LIBRARY_PATH take precedence

proc _libtest {depspec {return_match 0}} {
    global env prefix frameworks_dir os.platform
    set depline [lindex [split $depspec :] 1]

    if {[info exists env(DYLD_FRAMEWORK_PATH)]} {
        lappend search_path $env(DYLD_FRAMEWORK_PATH)
    } else {
        lappend search_path ${frameworks_dir} /Library/Frameworks /Network/Library/Frameworks /System/Library/Frameworks
    }
    if {[info exists env(DYLD_FALLBACK_FRAMEWORK_PATH)]} {
        lappend search_path $env(DYLD_FALLBACK_FRAMEWORK_PATH)
    }
    if {[info exists env(DYLD_LIBRARY_PATH)]} {
        lappend search_path $env(DYLD_LIBRARY_PATH)
    }
    lappend search_path /lib /usr/lib ${prefix}/lib
    if {[info exists env(DYLD_FALLBACK_LIBRARY_PATH)]} {
        lappend search_path $env(DYLD_FALLBACK_LIBRARY_PATH)
    }

    set i [string first . $depline]
    if {$i < 0} {set i [string length $depline]}
    set depname [string range $depline 0 [expr $i - 1]]
    set depversion [string range $depline $i end]
    regsub {\.} $depversion {\.} depversion
    if {${os.platform} == "darwin"} {
        set depregex \^${depname}${depversion}\\.dylib\$
    } else {
        set depregex \^${depname}\\.so${depversion}\$
    }

    return [_mportsearchpath $depregex $search_path 0 $return_match]
}

### _bintest is private; subject to change without notice

proc _bintest {depspec {return_match 0}} {
    global env prefix
    set depregex [lindex [split $depspec :] 1]

    set search_path [split $env(PATH) :]

    set depregex \^$depregex\$

    return [_mportsearchpath $depregex $search_path 1 $return_match]
}

### _pathtest is private; subject to change without notice

proc _pathtest {depspec {return_match 0}} {
    global env prefix
    set depregex [lindex [split $depspec :] 1]

    # separate directory from regex
    set fullname $depregex

    regexp {^(.*)/(.*?)$} "$fullname" match search_path depregex

    if {[string index $search_path 0] != "/"} {
        # Prepend prefix if not an absolute path
        set search_path "${prefix}/${search_path}"
    }

    set depregex \^$depregex\$

    return [_mportsearchpath $depregex $search_path 0 $return_match]
}

# returns the name of the port that will actually be satisfying $depspec
proc _get_dep_port {depspec} {
    set speclist [split $depspec :]
    set portname [lindex $speclist end]
    set res [_portnameactive $portname]
    if {$res != 0} {
        return $portname
    }
    
    set depfile ""
    switch [lindex $speclist 0] {
        bin {
            set depfile [_bintest $depspec 1]
        }
        lib {
            set depfile [_libtest $depspec 1]
        }
        path {
            set depfile [_pathtest $depspec 1]
        }
    }
    if {$depfile == ""} {
        return $portname
    } else {
        set theport [registry_file_registered $depfile]
        if {$theport != 0} {
            return $theport
        } else {
            return ""
        }
    }
}

# returns the list of archs that the port is targeting
proc get_canonical_archs {} {
    global supported_archs os.arch configure.build_arch configure.universal_archs
    if {$supported_archs == "noarch"} {
        return "noarch"
    } elseif {[variant_exists universal] && [variant_isset universal]} {
        return [lsort -ascii ${configure.universal_archs}]
    } elseif {${configure.build_arch} != ""} {
        return ${configure.build_arch}
    } else {
        return ${os.arch}
    }
}

# returns the flags that should be passed to the compiler to choose arch(s)
proc get_canonical_archflags {{tool cc}} {
    if {![variant_exists universal] || ![variant_isset universal]} {
        if {[catch {option configure.${tool}_archflags} flags]} {
            return -code error "archflags do not exist for tool '$tool'"
        }
    } else {
        if {$tool == "cc"} {
            set tool c
        }
        if {[catch {option configure.universal_${tool}flags} flags]} {
            return -code error "universal archflags do not exist for tool '$tool'"
        }
    }
    return $flags
}

# check that the selected archs are supported
proc check_supported_archs {} {
    global supported_archs build_arch universal_archs configure.build_arch configure.universal_archs subport
    if {$supported_archs == "noarch"} {
        return 0
    } elseif {[variant_exists universal] && [variant_isset universal]} {
        if {[llength ${configure.universal_archs}] > 1 || $universal_archs == ${configure.universal_archs}} {
            return 0
        } else {
            ui_error "$subport cannot be installed for the configured universal_archs '$universal_archs' because it only supports the arch(s) '$supported_archs'."
            return 1
        }
    } elseif {$build_arch == "" || ${configure.build_arch} != ""} {
        return 0
    }
    ui_error "$subport cannot be installed for the configured build_arch '$build_arch' because it only supports the arch(s) '$supported_archs'."
    return 1
}

# check if the installed xcode version is new enough
proc _check_xcode_version {} {
    global os.subplatform macosx_version xcodeversion

    if {${os.subplatform} == "macosx"} {
        switch $macosx_version {
            10.4 {
                set min 2.0
                set ok 2.4.1
                set rec 2.5
            }
            10.5 {
                set min 3.0
                set ok 3.1
                set rec 3.1.4
            }
            10.6 {
                set min 3.2
                set ok 3.2
                set rec 3.2.6
            }
            10.7 {
                set min 4.1
                set ok 4.1
                set rec 4.6.2
            }
            default {
                set min 4.4
                set ok 4.4
                set rec 4.6.2
            }
        }
        if {$xcodeversion == "none"} {
            ui_warn "Xcode does not appear to be installed; most ports will likely fail to build."
            if {[file exists "/Applications/Install Xcode.app"]} {
                ui_warn "You downloaded Xcode from the Mac App Store but didn't install it. Run \"Install Xcode\" in the /Applications folder."
            }
        } elseif {[vercmp $xcodeversion $min] < 0} {
            ui_error "The installed version of Xcode (${xcodeversion}) is too old to use on the installed OS version. Version $rec or later is recommended on Mac OS X ${macosx_version}."
            return 1
        } elseif {[vercmp $xcodeversion $ok] < 0} {
            ui_warn "The installed version of Xcode (${xcodeversion}) is known to cause problems. Version $rec or later is recommended on Mac OS X ${macosx_version}."
        }

        # Xcode 4.3 requires the command-line utilities package to be
        # installed. 
        if {[vercmp $xcodeversion 4.3] >= 0 ||
            ($xcodeversion == "none" && [file exists "/Applications/Xcode.app"])} {
            if {![file exists "/usr/bin/make"]} {
                ui_warn "The Command Line Tools for Xcode don't appear to be installed; most ports will likely fail to build."
                ui_warn "See http://guide.macports.org/chunked/installing.xcode.html for more information."
            }
        }
        
    }
    return 0
}

# check if we can unarchive this port
proc _archive_available {} {
    global ports_source_only porturl portutil::archive_available_result

    if {[info exists archive_available_result]} {
        return $archive_available_result
    }

    if {[tbool ports_source_only]} {
        set archive_available_result 0
        return 0
    }

    if {[find_portarchive_path] != ""} {
        set archive_available_result 1
        return 1
    }

    set archiverootname [file rootname [get_portimage_name]]
    if {[file rootname [file tail $porturl]] == $archiverootname && [file extension $porturl] != ""} {
        set archive_available_result 1
        return 1
    }

    # check if there's an archive available on the server
    global archive_sites
    set mirrors macports_archives
    if {[lsearch $archive_sites macports_archives::*] == -1} {
        set mirrors [lindex [split [lindex $archive_sites 0] :] 0]
    }
    if {$mirrors == {}} {
        set archive_available_result 0
        return 0
    }
    set archivetype $portfetch::mirror_sites::archive_type($mirrors)
    set archivename "${archiverootname}.${archivetype}"
    # grab first site, should conventionally be the master mirror
    set sites_entry [lindex $portfetch::mirror_sites::sites($mirrors) 0]
    # look for and strip off any tag, which will start with the first colon after the
    # first slash after the ://
    set lastcolon [string last : $sites_entry]
    set aftersep [expr [string first : $sites_entry] + 3]
    set firstslash [string first / $sites_entry $aftersep]
    if {$firstslash != -1 && $firstslash < $lastcolon} {
        incr lastcolon -1
        set site [string range $sites_entry 0 $lastcolon]
    } else {
        set site $sites_entry
    }
    if {[string index $site end] != "/"} {
        append site "/[option archive.subdir]"
    } else {
        append site [option archive.subdir]
    }
    set url [portfetch::assemble_url $site $archivename]
    if {![catch {curl getsize $url} result]} {
        set archive_available_result 1
        return 1
    }

    set archive_available_result 0
    return 0
}
