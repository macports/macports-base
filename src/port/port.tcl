#!@TCLSH@
# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
#
# Copyright (c) 2004-2016 The MacPorts Project
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2002-2003 Apple Inc.
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

# Create a namespace for some local variables
namespace eval portclient::progress {
    ##
    # Indicate whether the term::ansi::send tcllib package is available and was
    # imported. "yes", if the package is available, "no" otherwise.
    variable hasTermAnsiSend no
}

if {![catch {package require term::ansi::send}]} {
    set portclient::progress::hasTermAnsiSend yes
}

package require Tclx
package require macports
package require Pextlib 1.0
package require portlist

# Standard procedures
proc print_usage {{verbose 1}} {
    global cmdname
    set syntax {
        [-bcdfknNopqRstuvy] [-D portdir|portname] [-F cmdfile] action [actionflags]
        [[portname|pseudo-portname|port-url] [@version] [+-variant]... [option=value]...]...
    }

    if {$verbose} {
        puts stderr "Usage: $cmdname$syntax"
        puts stderr "\"$cmdname help\" or \"man 1 port\" for more information."
    } else {
        puts stderr "$cmdname$syntax"
    }
}

# Produce error message and exit
proc fatal s {
    global argv0
    ui_error "$argv0: $s"
    exit 1
}

##
# Helper function to define constants
#
# Constants defined with const can simply be accessed in the same way as
# calling a proc.
#
# Example:
# const FOO 42
# puts [FOO]
#
# @param name variable name
# @param value constant variable value
proc const {name args} {
    proc $name {} [list return [expr $args]]
}

# Produce an error message, and exit, unless
# we're handling errors in a soft fashion, in which
# case we continue
proc fatal_softcontinue s {
    if {[macports::global_option_isset ports_force]} {
        ui_error $s
        return -code continue
    } else {
        fatal $s
    }
}


# Produce an error message, and break, unless
# we're handling errors in a soft fashion, in which
# case we continue
proc break_softcontinue { msg status name_status } {
    upvar $name_status status_var
    ui_error $msg
    if {[macports::ui_isset ports_processall]} {
        set status_var 0
        return -code continue
    } else {
        set status_var $status
        return -code break
    }
}

# show the URL for the ticket reporting instructions
proc print_tickets_url {args} {
    global macports::prefix
    if {${prefix} ne "/usr/local" && ${prefix} ne "/usr"} {
        set len [string length [macports::ui_prefix_default error]]
        ui_error [wrap "Follow https://guide.macports.org/#project.tickets if you believe there is a bug." -${len}]
    }
}

##
# Maps friendly field names to their real name
# Names which do not need mapping are not changed.
#
# @param field friendly name
# @return real name
proc map_friendly_field_names { field } {
    switch -- $field {
        variant -
        platform -
        maintainer -
        subport {
            set field "${field}s"
        }
        category {
            set field "categories"
        }
    }

    return $field
}


proc registry_installed {portname {portversion ""} {require_single yes} {only_active no}} {
    if {!$only_active} {
        set possible_matches [registry::entry imaged $portname]
    } else {
        set possible_matches [registry::entry installed $portname]
    }
    if {$portversion ne ""} {
        set matches [list]
        foreach p $possible_matches {
            # Ambiguous syntax for version, may or may not include the revision
            if {"[$p version]_[$p revision][$p variants]" eq $portversion || [$p version] eq $portversion} {
                lappend matches $p
            }
        }
    } else {
        set matches $possible_matches
    }

    if {!$require_single} {
        return $matches
    }

    if {[llength $matches] > 1} {
        global macports::ui_options
        # set portname again since the one we were passed may not have had the correct case
        set portname [[lindex $matches 0] name]
        set msg "The following versions of $portname are currently installed:"
        set portilist [list]
        foreach i $matches {
            if {[$i state] eq "installed"} {
                lappend portilist "  $portname @[$i version]_[$i revision][$i variants] (active)"
            } else {
                lappend portilist "  $portname @[$i version]_[$i revision][$i variants]"
            }
        }
        if {[info exists ui_options(questions_singlechoice)]} {
            set retindex [$macports::ui_options(questions_singlechoice) $msg "Choice_Q1" $portilist]
            return [lindex $matches $retindex]
        } else {
            ui_notice $msg
            foreach portstr $portilist {
                puts $portstr
            }
            return -code error "Registry error: Please specify the full version as recorded in the port registry."
        }
    } elseif {[llength $matches] == 0} {
        if {$portversion eq ""} {
            return -code error "Registry error: $portname not registered as installed."
        } else {
            return -code error "Registry error: $portname $portversion not registered as installed."
        }
    }
    return [lindex $matches 0]
}

# Add the entry to the given portlist, adding default values for name,
# porturl and options if not set.
proc add_to_portlist_with_defaults {listname portentry} {
    upvar $listname portlist
    global global_options

    if {![dict exists $portentry options]} {
        dict set portentry options [array get global_options]
    }
    # If neither portname nor url is specified, then default to the current port
    if {(![dict exists $portentry url] || [dict get $portentry url] eq "")
             && (![dict exists $portentry name] || [dict get $portentry name] eq "")} {
        set url file://.
        set portname [url_to_portname $url]
        dict set portentry url $url
        dict set portentry name $portname
        if {$portname eq ""} {
            ui_error "A default port name could not be supplied."
        }
    }

    # Form portlist entry and add to portlist
    add_to_portlist portlist $portentry
}

proc url_to_portname { url {quiet 0} } {
    # Save directory and restore the directory, since mportopen changes it
    set savedir [pwd]
    set portname ""
    if {[catch {set ctx [mportopen $url]} result]} {
        ui_debug "$::errorInfo"
        if {!$quiet} {
            ui_msg "Can't map the URL '$url' to a port description file (\"${result}\")."
            ui_msg "Please verify that the directory and portfile syntax are correct."
        }
    } else {
        set portname [dict get [mportinfo $ctx] name]
        mportclose $ctx
    }
    cd $savedir
    return $portname
}


# Supply a default porturl/portname if the portlist is empty
proc require_portlist { nameportlist {is_upgrade "no"} } {
    global private_options
    upvar $nameportlist portlist

    if {[llength $portlist] == 0 && (![info exists private_options(ports_no_args)] || $private_options(ports_no_args) eq "no")} {
        if {${is_upgrade} eq "yes"} {
            # $> port upgrade outdated
            # Error: No ports matched the given expression
            # is not very user friendly - if we're in the special case of
            # "upgrade", let's print a message that's a little easier to
            # understand and less alarming.
            ui_msg "Nothing to upgrade."
            return 0
        }
        ui_error "No ports matched the given expression"
        return 1
    }

    if {[llength $portlist] == 0} {
        set portlist [get_current_port]

        if {[llength $portlist] == 0} {
            # there was no port in current directory
            return 1
        }
    }

    return 0
}

# sort portlist so dependents come before their dependencies
proc portlist_sortdependents { portlist } {
    foreach p $portlist {
        # normalise port name to lower case
        set norm_name [string tolower [dict get $p name]]
        lappend entries($norm_name) $p
        if {![info exists dependents($norm_name)]} {
            set dependents($norm_name) [list]
            foreach result [registry::list_dependents [dict get $p name]] {
                lappend dependents($norm_name) [string tolower [lindex $result 2]]
            }
        }
    }
    set ret [list]
    foreach p $portlist {
        portlist_sortdependents_helper $p entries dependents seen ret
    }
    return $ret
}

proc portlist_sortdependents_helper {p up_entries up_dependents up_seen up_retlist} {
    upvar $up_seen seen
    if {![info exists seen($p)]} {
        set seen($p) 1
        upvar $up_entries entries $up_dependents dependents $up_retlist retlist
        foreach dependent $dependents([string tolower [dict get $p name]]) {
            if {[info exists entries($dependent)]} {
                foreach entry $entries($dependent) {
                    portlist_sortdependents_helper $entry entries dependents seen retlist
                }
            }
        }
        lappend retlist $p
    }
}

proc regex_pat_sanitize {s} {
    set sanitized [regsub -all {[\\(){}+$.^]} $s {\\&}]
    return $sanitized
}

##
# Makes sure we get the current terminal size
proc term_init_size {} {
    global env

    if {![info exists env(COLUMNS)] || ![info exists env(LINES)]} {
        if {[isatty stdout]} {
            set size [term_get_size stdout]

            if {![info exists env(LINES)] && [lindex $size 0] > 0} {
                set env(LINES) [lindex $size 0]
            }

            if {![info exists env(COLUMNS)] && [lindex $size 1] > 0} {
                set env(COLUMNS) [lindex $size 1]
            }
        }
    }
}

##
# Wraps a multi-line string at specified textwidth
#
# @see wrapline
#
# @param string input string
# @param maxlen text width (0 defaults to current terminal width)
# @param indent prepend to every line
# @return wrapped string
proc wrap {string maxlen {indent ""} {indentfirstline 1}} {
    global env

    if {$maxlen == 0} {
        if {![info exists env(COLUMNS)]} {
            # no width for wrapping
            return $string
        }
        set maxlen $env(COLUMNS)
    }

    set splitstring [list]
    set indentline $indentfirstline
    foreach line [split $string "\n"] {
        lappend splitstring [wrapline $line $maxlen $indent $indentline]
        set indentline 1
    }
    return [join $splitstring "\n"]
}

##
# Wraps a line at specified textwidth
#
# @see wrap
#
# @param line input line
# @param maxlen text width (0 defaults to current terminal width,
#        negative numbers reduce width from terminal's)
# @param indent prepend to every line
# @return wrapped string
proc wrapline {line maxlen {indent ""} {indentfirstline 1}} {
    global env

    if {$maxlen <= 0} {
        if {![info exists env(COLUMNS)]} {
            # no width for wrapping
            return $line
        }
        set maxlen [expr {$env(COLUMNS) + $maxlen}]
    }

    set string [split $line " "]
    if {$indentfirstline == 0} {
        set newline ""
        set maxlen [expr {$maxlen - [string length $indent]}]
    } else {
        set newline $indent
    }
    append newline [lindex $string 0]
    set joiner " "
    set first 1
    foreach word [lrange $string 1 end] {
        if {[string length $newline]+[string length $word] >= $maxlen} {
            lappend lines $newline
            set newline $indent
            set joiner ""
            # If indentfirstline is set to 0, reset maxlen to its
            # original length after appending the first line to lines.
            if {$first == 1 && $indentfirstline == 0} {
                set maxlen [expr {$maxlen + [string length $indent]}]
            }
            set first 0
        }
        append newline $joiner $word
        set joiner " "
    }
    lappend lines $newline
    return [join $lines "\n"]
}

##
# Wraps a line at a specified width with a label in front
#
# @see wrap
#
# @param label label for output
# @param string input string
# @param maxlen text width (0 defaults to current terminal width)
# @return wrapped string
proc wraplabel {label string maxlen {indent ""}} {
    append label ": [string repeat " " [expr {[string length $indent] - [string length "$label: "]}]]"
    return "$label[wrap $string $maxlen $indent 0]"
}

##########################################
# Port selection
##########################################
proc unique_results_to_portlist {infos} {
    global global_options
    set unique [dict create]
    set opts [dict create {*}[array get global_options]]
    foreach {name portinfo} $infos {
        set portentry [entry_for_portlist [dict create url [dict get $portinfo porturl] name $name options $opts]]

        if {[dict exists $unique [dict get $portentry fullname]]} continue
        dict set unique [dict get $portentry fullname] $portentry
    }
    return [dict values $unique]
}


proc get_matching_ports {pattern {casesensitive no} {matchstyle glob} {field name}} {
    if {[catch {set res [mportsearch $pattern $casesensitive $matchstyle $field]} result]} {
        ui_debug $::errorInfo
        fatal "search for portname $pattern failed: $result"
    }
    set results [unique_results_to_portlist $res]

    # Return the list of all ports, sorted
    return [portlist_sort $results]
}


proc get_all_ports {} {
    global all_ports_cache

    if {![info exists all_ports_cache]} {
         if {[catch {set res [mportlistall]} result]} {
            ui_debug $::errorInfo
            fatal "listing all ports failed: $result"
        }
        set results [unique_results_to_portlist $res]
        set all_ports_cache [portlist_sort $results]
    }
    return $all_ports_cache
}


proc get_current_ports {} {
    # This is just a synonym for get_current_port that
    # works with the regex in element
    return [get_current_port]
}


proc get_current_port {} {
    set url file://.
    set portname [url_to_portname $url]
    if {$portname eq ""} {
        ui_msg "To use the current port, you must be in a port's directory."
        return [list]
    }

    set results [list]
    add_to_portlist_with_defaults results [dict create url $url name $portname]
    return $results
}


proc get_installed_ports { {ignore_active yes} {active yes} } {
    if {[catch {registry::entry imaged} results]} {
        ui_debug $::errorInfo
        fatal "port installed failed: $results"
    }

    set portlist [list]
    foreach i $results {
        set ivariants [split_variants [$i variants]]
        if {${ignore_active} eq "yes" || (${active} eq "yes") == ([$i state] eq "installed")} {
            add_to_portlist_with_defaults portlist [dict create name [$i name] version [$i version]_[$i revision] variants $ivariants]
        }
    }

    # Return the list of ports, sorted
    return [portlist_sort $portlist]
}


proc get_uninstalled_ports {} {
    # Return all - installed
    set all [get_all_ports]
    set installed [get_installed_ports]
    return [portlist::opComplement $all $installed]
}


proc get_active_ports {} {
    return [get_installed_ports no yes]
}


proc get_inactive_ports {} {
    return [get_installed_ports no no]
}

proc get_actinact_ports {} {
    set inactive_ports [get_inactive_ports]
    set active_ports [get_active_ports]
    set results [list]

    set inact [dict create]
    foreach port $inactive_ports {
        dict lappend inact [dict get $port name] $port
    }

    foreach port $active_ports {
        set portname [dict get $port name]
        if {[dict exists $inact $portname]} {
            set inact_ports [dict get $inact $portname]
            if {$inact_ports ne ""} {
                lappend results {*}$inact_ports
                dict set inact $portname ""
            }
            lappend results $port
        }
    }
    return $results
}


proc get_outdated_ports {} {
    # Get the list of installed ports
    if { [catch {set ilist [registry::entry imaged]} result] } {
        ui_debug $::errorInfo
        fatal "getting installed ports failed: $result"
    }

    global macports::cxx_stdlib macports::os_platform macports::os_major
    # Now process the list, keeping only those ports that are outdated
    set results [list]
    if {${cxx_stdlib} eq "libc++"} {
        set wrong_stdlib libstdc++
    } else {
        set wrong_stdlib libc++
    }
    foreach i $ilist {

        # Get information about the installed port
        set portname            [$i name]
        set installed_compound  [$i version]_[$i revision]

        if {[$i state] eq "imaged"} continue

        # Get info about the port from the index
        if {[catch {set res [mportlookup $portname]} result]} {
            ui_debug $::errorInfo
            fatal "lookup of portname $portname failed: $result"
        }
        if {[llength $res] < 2} {
            if {[macports::ui_isset ports_debug]} {
                puts stderr "$portname ($installed_compound is installed; the port was not found in the port index)"
            }
            continue
        }
        array unset portinfo
        array set portinfo [lindex $res 1]

        # Get information about latest available version and revision
        set latest_version $portinfo(version)
        set latest_revision     0
        if {[info exists portinfo(revision)] && $portinfo(revision) > 0} {
            set latest_revision $portinfo(revision)
        }
        set latest_epoch        0
        if {[info exists portinfo(epoch)]} {
            set latest_epoch    $portinfo(epoch)
        }

        # Compare versions, first checking epoch, then version, then revision
        set comp_result 0
        if {[$i version] != $latest_version} {
            set comp_result [expr {[$i epoch] - $latest_epoch}]
            if { $comp_result == 0 } {
                set comp_result [vercmp [$i version] $latest_version]
            }
        }
        if { $comp_result == 0 } {
            set comp_result [expr {[$i revision] - $latest_revision}]
        }
        if {$comp_result == 0} {
            if {([$i os_platform] ni [list any "" 0] && [$i os_major] ni [list "" 0]
                && ([$i os_platform] ne ${os_platform}
                    || ([$i os_major] ne "any" && [$i os_major] != ${os_major})))
                || ([$i cxx_stdlib_overridden] == 0 && [$i cxx_stdlib] eq $wrong_stdlib)} {
                set comp_result -1
            }
        }

        # Add outdated ports to our results list
        if { $comp_result < 0 } {
            add_to_portlist_with_defaults results [dict create name $portname version $installed_compound variants [split_variants [$i variants]]]
        }
    }

    return [portlist_sort $results]
}


proc get_obsolete_ports {} {
    set ilist [get_installed_ports]
    set results [list]

    foreach i $ilist {
        if {[catch {mportlookup [dict get $i name]} result]} {
            ui_debug "$::errorInfo"
            break_softcontinue "lookup of portname $portname failed: $result" 1 status
        }

        if {[llength $result] < 2} {
            lappend results $i
        }
    }

    # Return the list of ports, already sorted
    return [portlist_sort $results]
}

# return ports that have registry property $propname set to $propval
proc get_ports_with_prop {propname propval} {
    if {[catch {set ilist [registry::entry search $propname $propval]} result]} {
        ui_debug $::errorInfo
        fatal "registry search failed: $result"
    }

    set results [list]
    foreach i $ilist {
        add_to_portlist_with_defaults results [dict create name [$i name] version [$i version]_[$i revision] variants [split_variants [$i variants]]]
    }

    # Return the list of ports, sorted
    return [portlist_sort $results]
}

proc get_requested_ports {} {
    return [get_ports_with_prop requested 1]
}

proc get_unrequested_ports {} {
    return [get_ports_with_prop requested 0]
}

proc get_leaves_ports {} {
    if {[catch {set ilist [registry::entry imaged]} result]} {
        ui_debug $::errorInfo
        fatal "getting installed ports failed: $result"
    }
    set results [list]
    foreach i $ilist {
        if {[$i dependents] eq ""} {
            add_to_portlist_with_defaults results [dict create name [$i name] version [$i version]_[$i revision] variants [split_variants [$i variants]]]
        }
    }
    return [portlist_sort [portlist::opComplement $results [get_requested_ports]]]
}

proc get_rleaves_ports {} {
    set ilist [get_unrequested_ports]
    set requested [get_requested_ports]
    set results [list]
    foreach i $ilist {
        set deplist [get_dependent_ports [dict get $i name] 1]
        if {$deplist eq "" || [portlist::opIntersection $deplist $requested] eq ""} {
            add_to_portlist results $i
        }
    }
    return $results
}

proc get_dependent_ports {portname recursive} {
    set deplist [registry::list_dependents $portname]
    # could return specific versions here using registry2.0 features
    set results [list]
    foreach dep $deplist {
        add_to_portlist_with_defaults results [dict create name [lindex $dep 2]]
    }

    # actually do this iteratively to avoid hitting Tcl's recursion limit
    if {$recursive} {
        while 1 {
            set rportlist [list]
            set newlist [list]
            foreach dep $deplist {
                set depname [lindex $dep 2]
                if {![info exists seen($depname)]} {
                    set seen($depname) 1
                    set rdeplist [registry::list_dependents $depname]
                    foreach rdep $rdeplist {
                        lappend newlist $rdep
                        add_to_portlist_with_defaults rportlist [dict create name [lindex $rdep 2]]
                    }
                }
            }
            if {[llength $rportlist] > 0} {
                set results [portlist::opUnion $results $rportlist]
                set deplist $newlist
            } else {
                break
            }
        }
    }

    return [portlist_sort $results]
}


proc get_rdepends_ports {portname} {
    global portDependenciesDict
    if {![info exists portDependenciesDict]} {
        # make a dictionary of all the port names and their (reverse) dependencies
        # much faster to build this once than to call mportsearch thousands of times
        set portDependenciesDict [dict create]
        set deptypes [list depends_fetch depends_extract depends_patch depends_build depends_lib depends_run depends_test]
        foreach {pname pinfo} [mportlistall] {
            foreach dtype $deptypes {
                if {[dict exists $pinfo $dtype]} {
                    foreach depspec [dict get $pinfo $dtype] {
                        dict lappend portDependenciesDict [string tolower [lindex [split $depspec :] end]] $pname
                    }
                }
            }
        }
    }

    set results [list]
    set portList [list [string tolower $portname]]
    while {[llength $portList] > 0} {
        set aPort [lindex $portList end]
        set portList [lreplace ${portList}[set portList {}] end end]
        if {[dict exists $portDependenciesDict $aPort]} {
            foreach possiblyNewPort [dict get $portDependenciesDict $aPort] {
                set lcport [string tolower $possiblyNewPort]
                if {![info exists seen($lcport)]} {
                    set seen($lcport) 1
                    lappend portList $lcport
                    add_to_portlist_with_defaults results [dict create name $possiblyNewPort]
                }
            }
        }
    }

    return [portlist_sort $results]
}


proc get_dep_ports {portname recursive} {
    global global_variations
    # look up portname
    if {[catch {mportlookup $portname} result]} {
        ui_debug $::errorInfo
        if {[macports::ui_isset ports_processall]} {
            ui_error "lookup of portname $portname failed"
            return [list]
        } else {
            return -code error "lookup of portname $portname failed: $result"
        }
    } elseif {[llength $result] < 2} {
        if {[macports::ui_isset ports_processall]} {
            ui_error "Port $portname not found"
            return [list]
        } else {
            return -code error "Port $portname not found"
        }
    }
    lassign $result portname portinfo
    set porturl [dict get $portinfo porturl]
    set gvariations [dict create {*}[array get global_variations]]

    # open portfile
    if {[catch {set mport [mportopen $porturl [dict create subport $portname] $gvariations]} result]} {
        ui_debug $::errorInfo
        if {[macports::ui_isset ports_processall]} {
            ui_error "Unable to open port $portname: $result"
            return [list]
        } else {
            return -code error "Unable to open port $portname: $result"
        }
    }
    set portinfo [dict merge $portinfo [mportinfo $mport]]
    mportclose $mport

    # gather its deps
    set results [list]
    set deptypes [list depends_fetch depends_extract depends_patch depends_build depends_lib depends_run depends_test]

    set deplist [list]
    foreach type $deptypes {
        if {[dict exists $portinfo $type]} {
            foreach dep [dict get $portinfo $type] {
                add_to_portlist_with_defaults results [dict create name [lindex [split $dep :] end]]
                lappend deplist $dep
            }
        }
    }

    # actually do this iteratively to avoid hitting Tcl's recursion limit
    if {$recursive} {
        while 1 {
            set rportlist [list]
            set newlist [list]
            foreach dep $deplist {
                set depname [lindex [split $dep :] end]
                if {![info exists seen($depname)]} {
                    set seen($depname) 1

                    # look up the dep
                    if {[catch {mportlookup $depname} result]} {
                        ui_debug $::errorInfo
                        ui_error "lookup of portname $depname failed: $result"
                        continue
                    } elseif {[llength $result] < 2} {
                        ui_error "Port $depname not found"
                        continue
                    }
                    set portinfo [lindex $result 1]
                    set porturl [dict get $portinfo porturl]

                    # open its portfile
                    if {[catch {set mport [mportopen $porturl [dict create subport [dict get $portinfo name]] $gvariations]} result]} {
                        ui_debug $::errorInfo
                        ui_error "Unable to open port $depname: $result"
                        continue
                    }
                    set portinfo [dict merge $portinfo [mportinfo $mport]]
                    mportclose $mport

                    # collect its deps
                    set rdeplist [list]
                    foreach type $deptypes {
                        if {[dict exists $portinfo $type]} {
                            foreach rdep [dict get $portinfo $type] {
                                add_to_portlist_with_defaults results [dict create name [lindex [split $rdep :] end]]
                                lappend rdeplist $rdep
                            }
                        }
                    }

                    # add them to the lists
                    foreach rdep $rdeplist {
                        lappend newlist $rdep
                        add_to_portlist_with_defaults rportlist [dict create name [lindex [split $rdep :] end]]
                    }
                }
            }
            if {[llength $rportlist] > 0} {
                set results [portlist::opUnion $results $rportlist]
                set deplist $newlist
            } else {
                break
            }
        }
    }

    return [portlist_sort $results]
}

proc get_subports {portname} {
    global global_variations
    # look up portname
    if {[catch {mportlookup $portname} result]} {
        ui_debug $::errorInfo
        if {[macports::ui_isset ports_processall]} {
            ui_error "lookup of portname $portname failed"
            return [list]
        } else {
            return -code error "lookup of portname $portname failed: $result"
        }
    } elseif {[llength $result] < 2} {
        if {[macports::ui_isset ports_processall]} {
            ui_error "Port $portname not found"
            return [list]
        } else {
            return -code error "Port $portname not found"
        }
    }
    lassign $result portname portinfo
    set porturl [dict get $portinfo porturl]

    # open portfile
    if {[catch {set mport [mportopen $porturl [dict create subport $portname] [array get global_variations]]} result]} {
        ui_debug $::errorInfo
        if {[macports::ui_isset ports_processall]} {
            ui_error "Unable to open port $portname: $result"
            return [list]
        } else {
            return -code error "Unable to open port $portname: $result"
        }
    }
    set portinfo [dict merge $portinfo [mportinfo $mport]]
    mportclose $mport

    # gather its subports
    set results [list]

    if {[dict exists $portinfo subports]} {
        foreach subport [dict get $portinfo subports] {
            add_to_portlist_with_defaults results [dict create name $subport]
        }
    }

    return [portlist_sort $results]
}


##########################################
# Port expressions
##########################################
proc portExpr { resname } {
    upvar $resname reslist
    set result [seqExpr reslist]
    return $result
}


proc seqExpr { resname } {
    upvar $resname reslist

    # Evaluate a sequence of expressions a b c...
    # These act the same as a or b or c

    set result 1
    while {$result} {
        switch -- [lookahead] {
            ;       -
            )       -
            _EOF_   { break }
        }

        set blist [list]
        set result [orExpr blist]
        if {$result} {
            # Calculate the union of result and b
            set reslist [portlist::opUnion $reslist $blist]
        }
    }

    return $result
}


proc orExpr { resname } {
    upvar $resname reslist

    set a [andExpr reslist]
    while ($a) {
        switch -- [lookahead] {
            or {
                    advance
                    set blist [list]
                    if {![andExpr blist]} {
                        return 0
                    }

                    # Calculate a union b
                    set reslist [portlist::opUnion $reslist $blist]
                }
            default {
                    return $a
                }
        }
    }

    return $a
}


proc andExpr { resname } {
    upvar $resname reslist

    set a [unaryExpr reslist]
    while {$a} {
        switch -- [lookahead] {
            and {
                    advance

                    set blist [list]
                    # Handle "and not" as a direct operation, rather
                    # than first calculating everything that is not b.
                    if {[lookahead] eq "not"} {
                        advance
                        set complement 1
                    } else {
                        set complement 0
                    }

                    set b [unaryExpr blist]
                    if {!$b} {
                        return 0
                    }

                    if {$complement} {
                        # Calculate relative complement of b in a (AKA set difference)
                        set reslist [portlist::opComplement $reslist $blist]
                    } else {
                        # Calculate a intersect b
                        set reslist [portlist::opIntersection $reslist $blist]
                    }
                }
            default {
                    return $a
                }
        }
    }

    return $a
}


proc unaryExpr { resname } {
    upvar $resname reslist
    set result 0

    switch -- [lookahead] {
        !   -
        not {
                advance
                set blist [list]
                set result [unaryExpr blist]
                if {$result} {
                    set all [get_all_ports]
                    set reslist [portlist::opComplement $all $blist]
                }
            }
        default {
                set result [element reslist]
            }
    }

    return $result
}


proc element { resname } {
    upvar $resname reslist
    set el 0

    set url ""
    set name ""
    set version ""

    set token [lookahead]
    switch -regex -matchvar matchvar -- $token {
        ^\\)$               -
        ^\;                 -
        ^_EOF_$             { # End of expression/cmd/file
        }

        ^\\($               { # Parenthesized Expression
            advance
            set el [portExpr reslist]
            if {!$el || ![match ")"]} {
                set el 0
            }
        }

        ^(all)(@.*)?$         -
        ^(installed)(@.*)?$   -
        ^(uninstalled)(@.*)?$ -
        ^(active)(@.*)?$      -
        ^(inactive)(@.*)?$    -
        ^(actinact)(@.*)?$    -
        ^(leaves)(@.*)?$      -
        ^(rleaves)(@.*)?$      -
        ^(outdated)(@.*)?$    -
        ^(obsolete)(@.*)?$    -
        ^(requested)(@.*)?$   -
        ^(unrequested)(@.*)?$ -
        ^(current)(@.*)?$     {
            # A simple pseudo-port name
            advance

            # Break off the version component, if there is one
            set name [lindex $matchvar 1]
            set remainder [lindex $matchvar 2]

            add_multiple_ports reslist [get_${name}_ports] $remainder

            set el 1
        }

        ^(variants):(.*)         -
        ^(variant):(.*)          -
        ^(description):(.*)      -
        ^(portdir):(.*)          -
        ^(homepage):(.*)         -
        ^(epoch):(.*)            -
        ^(platforms):(.*)        -
        ^(platform):(.*)         -
        ^(name):(.*)             -
        ^(long_description):(.*) -
        ^(maintainers):(.*)      -
        ^(maintainer):(.*)       -
        ^(categories):(.*)       -
        ^(category):(.*)         -
        ^(version):(.*)          -
        ^(depends_lib):(.*)      -
        ^(depends_build):(.*)    -
        ^(depends_run):(.*)      -
        ^(depends_extract):(.*)  -
        ^(depends_fetch):(.*)    -
        ^(depends_patch):(.*)    -
        ^(depends_test):(.*)     -
        ^(replaced_by):(.*)      -
        ^(revision):(.*)         -
        ^(subport):(.*)          -
        ^(subports):(.*)         -
        ^(license):(.*)          { # Handle special port selectors
            advance

            set field [lindex $matchvar 1]
            set pat [lindex $matchvar 2]

            # Remap friendly names to actual names
            set field [map_friendly_field_names $field]

            add_multiple_ports reslist [get_matching_ports $pat no regexp $field]
            set el 1
        }

        ^(depends):(.*)     { # A port selector shorthand for depends_{lib,build,run,fetch,extract}
            advance

            set pat [lindex $matchvar 2]

            add_multiple_ports reslist [get_matching_ports $pat no regexp "depends_lib"]
            add_multiple_ports reslist [get_matching_ports $pat no regexp "depends_build"]
            add_multiple_ports reslist [get_matching_ports $pat no regexp "depends_run"]
            add_multiple_ports reslist [get_matching_ports $pat no regexp "depends_extract"]
            add_multiple_ports reslist [get_matching_ports $pat no regexp "depends_fetch"]
            add_multiple_ports reslist [get_matching_ports $pat no regexp "depends_patch"]
            add_multiple_ports reslist [get_matching_ports $pat no regexp "depends_test"]

            set el 1
        }

        ^(rdepends):(.*) {
            advance

            set portname [lindex $matchvar 2]

            add_multiple_ports reslist [get_rdepends_ports $portname]

            set el 1
        }

        ^(dependentof):(.*)  -
        ^(rdependentof):(.*) {
            advance

            set selector [lindex $matchvar 1]
            set portname [lindex $matchvar 2]

            set recursive [string equal $selector "rdependentof"]
            add_multiple_ports reslist [get_dependent_ports $portname $recursive]

            set el 1
        }

        ^(depof):(.*)       -
        ^(rdepof):(.*)      {
            advance

            set selector [lindex $matchvar 1]
            set portname [lindex $matchvar 2]

            set recursive [string equal $selector "rdepof"]
            add_multiple_ports reslist [get_dep_ports $portname $recursive]

            set el 1
        }

        ^(subportof):(.*)   {
            advance

            set selector [lindex $matchvar 1]
            set portname [lindex $matchvar 2]

            add_multiple_ports reslist [get_subports $portname]

            set el 1
        }

        [][?*]              { # Handle portname glob patterns
            advance; add_multiple_ports reslist [get_matching_ports $token no glob]
            set el 1
        }

        ^\\w+:.+            { # Handle a url by trying to open it as a port and mapping the name
            advance
            set name [url_to_portname $token]
            if {$name ne ""} {
                parsePortSpec version requested_variants options
                set tempentry [dict create \
                  url $token \
                  name $name \
                  version $version \
                  requested_variants $requested_variants \
                  variants $requested_variants \
                  options $options]
                if {$version ne ""} {
                    dict set tempentry metadata [dict create explicit_version 1]
                }
                add_to_portlist_with_defaults reslist $tempentry
                set el 1
            } else {
                ui_error "Can't open URL '$token' as a port"
                set el 0
            }
        }

        default             { # Treat anything else as a portspec (portname, version, variants, options
            # or some combination thereof).
            parseFullPortSpec url name version requested_variants options
            set tempentry [dict create \
              url $url \
              name $name \
              version $version \
              requested_variants $requested_variants \
              variants $requested_variants \
              options $options]
            if {$version ne ""} {
                dict set tempentry metadata [dict create explicit_version 1]
            }
            add_to_portlist_with_defaults reslist $tempentry
            set el 1
        }
    }

    return $el
}

proc add_ports_to_portlist_with_defaults {listname ports {overrides ""}} {
    upvar $listname portlist

    if {![dict exists $overrides options]} {
        global global_options
        set i 0
        set opts [dict create {*}[array get global_options]]
        foreach port $ports {
            if {![dict exists $port options]} {
                dict set port options $opts
                lset ports $i $port
            }
            incr i
        }
    }
    set i 0
    foreach port $ports {
        if {(![dict exists $port url] || [dict get $port url] eq "")
                && (![dict exists $port name] || [dict get $port name] eq "")} {
            set url file://.
            set portname [url_to_portname $url]
            dict set port url $url
            dict set port name $portname
            if {$portname eq ""} {
                ui_error "A default port name could not be supplied."
            }
            lset ports $i $port
        }
        incr i
    }

    add_ports_to_portlist portlist $ports $overrides
}

proc add_multiple_ports { resname ports {remainder ""} } {
    upvar $resname reslist

    parsePortSpec version variants options $remainder

    set overrides [dict create]
    if {$version ne ""} {
        dict set overrides version $version
        dict set overrides metadata [dict create explicit_version 1]]
    }
    if {[dict size $variants] > 0} {
        # we always record the requested variants separately,
        # but requested ones always override existing ones
        dict set overrides requested_variants $variants
        dict set overrides variants $variants
    }
    if {[dict size $options] > 0} {
        dict set overrides options $options
    }

    add_ports_to_portlist_with_defaults reslist $ports $overrides
}

proc parseFullPortSpec { urlname namename vername varname optname } {
    upvar $urlname porturl
    upvar $namename portname
    upvar $vername portversion
    upvar $varname portvariants
    upvar $optname portoptions

    set portname ""
    set portversion ""
    set portvariants ""
    set portoptions ""

    if { [moreargs] } {
        # Look first for a potential portname
        #
        # We need to allow a wide variety of tokens here, because of actions like "provides"
        # so we take a rather lenient view of what a "portname" is. We allow
        # anything that doesn't look like either a version, a variant, or an option
        set token [lookahead]

        set remainder ""
        if {![regexp {^(@|[-+]([[:alpha:]_]+[\w\.]*)|[[:alpha:]_]+[\w\.]*=)} $token match]} {
            advance
            regexp {^([^@]+)(@.*)?} $token match portname remainder

            # If the portname contains a /, then try to use it as a URL
            if {[string match "*/*" $portname]} {
                set url "file://$portname"
                set name [url_to_portname $url 1]
                if { $name ne "" } {
                    # We mapped the url to valid port
                    set porturl $url
                    set portname $name
                    # Continue to parse rest of portspec....
                } else {
                    # We didn't map the url to a port; treat it
                    # as a raw string for something like port contents
                    # or cd
                    set porturl ""
                    # Since this isn't a port, we don't try to parse
                    # any remaining portspec....
                    return
                }
            }
        }

        # Now parse the rest of the spec
        parsePortSpec portversion portvariants portoptions $remainder
    }
}

# check if the install prefix is writable
# should be called by actions that will modify it
proc prefix_unwritable {} {
    global macports::portdbpath
    if {[file writable $portdbpath]} {
        return 0
    } else {
        ui_error "Insufficient privileges to write to MacPorts install prefix."
        return 1
    }
}


proc parsePortSpec { vername varname optname {remainder ""} } {
    upvar $vername portversion
    upvar $varname portvariants
    upvar $optname portoptions
    global global_options

    set portversion ""
    set portoptions [dict create {*}[array get global_options]]
    set portvariants ""

    # Parse port version/variants/options
    set opt $remainder
    set adv 0
    set consumed 0
    for {set firstTime 1} {$opt ne "" || [moreargs]} {set firstTime 0} {

        # Refresh opt as needed
        if {$opt eq ""} {
            if {$adv} advance
            set opt [lookahead]
            set adv 1
            set consumed 0
        }

        # Version must be first, if it's there at all
        if {$firstTime && [string match {@*} $opt]} {
            # Parse the version

            # Strip the @
            set opt [string range $opt 1 end]

            # Handle the version
            set sepPos [string first "/" $opt]
            if {$sepPos >= 0} {
                # Version terminated by "/" to disambiguate -variant from part of version
                set portversion [string range $opt 0 [expr {$sepPos - 1}]]
                set opt [string range $opt [expr {$sepPos + 1}] end]
            } else {
                # Version terminated by "+", or else is complete
                set sepPos [string first "+" $opt]
                if {$sepPos >= 0} {
                    # Version terminated by "+"
                    set portversion [string range $opt 0 [expr {$sepPos - 1}]]
                    set opt [string range $opt $sepPos end]
                } else {
                    # Unterminated version
                    set portversion $opt
                    set opt ""
                }
            }
            set consumed 1
        } else {
            # Parse all other options

            # Look first for a variable setting: VARNAME=VALUE
            if {[regexp {^([[:alpha:]_]+[\w\.]*)=(.*)} $opt match key val] == 1} {
                # It's a variable setting
                dict set portoptions $key $val
                set opt ""
                set consumed 1
            } elseif {[regexp {^([-+])([[:alpha:]_]+[\w\.]*)} $opt match sign variant] == 1} {
                # It's a variant
                dict set portvariants $variant $sign
                set opt [string range $opt [expr {[string length $variant] + 1}] end]
                set consumed 1
            } else {
                # Not an option we recognize, so break from port option processing
                if { $consumed && $adv } advance
                break
            }
        }
    }
}


##########################################
# Action Handlers
##########################################

proc action_get_usage { action } {
    global action_array cmd_opts_array
    if {[dict exists $action_array $action]} {
        set cmds ""
        if {[dict exists $cmd_opts_array $action]} {
            foreach opt [dict get $cmd_opts_array $action] {
                if {[llength $opt] == 1} {
                    set name $opt
                    set optc 0
                } else {
                    lassign $opt name optc
                }

                append cmds " --$name"

                for {set i 1} {$i <= $optc} {incr i} {
                    append cmds " <arg$i>"
                }
            }
        }
        set args ""
        set needed [action_needs_portlist $action]
        if {[ACTION_ARGS_STRINGS] == $needed} {
            set args " <arguments>"
        } elseif {[ACTION_ARGS_PORTS] == $needed} {
            set args " <portlist>"
        }

        set ret "Usage: "
        set len [string length $action]
        append ret [wrap "$action$cmds$args" 0 [string repeat " " [expr {8 + $len}]] 0]
        append ret "\n"

        return $ret
    }

    return -1
}

proc action_usage { action portlist opts } {
    if {[llength $portlist] == 0} {
        print_usage
        return 0
    }

    foreach topic $portlist {
        set usage [action_get_usage $topic]
        if {$usage != -1} {
           puts -nonewline stderr $usage
        } else {
            ui_error "No usage for topic $topic"
            return 1
        }
    }
    return 0
}


proc action_help { action portlist opts } {
    global macports::prefix
    set manext ".gz"
    if {[llength $portlist] == 0} {
        set page "man1/port.1$manext"
    } else {
        set topic [lindex $portlist 0]

        # Look for an action with the requested argument
        set actions [find_action $topic]
        if {[llength $actions] == 1} {
            set page "man1/port-[lindex $actions 0].1${manext}"
        } else {
            if {[llength $actions] > 1} {
                ui_error "\"port help ${action}\" is ambiguous: \n  port help [join $actions "\n  port help "]"
                return 1
            }

            # No valid command specified
            set page ""
            # Try to find the manpage in sections 5 (configuration) and 7
            foreach section {5 7} {
                set page_candidate "man${section}/${topic}.${section}${manext}"
                set pagepath ${prefix}/share/man/${page_candidate}
                ui_debug "testing $pagepath..."
                if {[file exists $pagepath]} {
                    set page $page_candidate
                    break
                }
            }
        }
    }

    set pagepath ""
    if {$page ne ""} {
        set pagepath ${prefix}/share/man/$page
    }
    if {$page ne "" && ![file exists $pagepath]} {
        # command exists, but there doesn't seem to be a manpage for it; open
        # portundocumented.7
        set page "man7/portundocumented.7$manext"
        set pagepath ${prefix}/share/man/$page
    }

    if {$pagepath ne ""} {
        ui_debug "Opening man page '$pagepath'"

        # Restore our entire environment from start time.
        # man might want to evaluate TERM
        global env boot_env
        set env_save [array get env]
        array unset env *
        array set env $boot_env

        if [catch {system -nodup [list ${macports::autoconf::man_path} $pagepath]} result] {
            ui_debug "$::errorInfo"
            ui_error "Unable to show man page using ${macports::autoconf::man_path}: $result"
            return 1
        }

        # Restore internal MacPorts environment
        array unset env *
        array set env $env_save
    } else {
        ui_error "Sorry, no help for this topic is available."
        return 1
    }

    return 0
}


proc action_log { action portlist opts } {
    if {[require_portlist portlist]} {
        return 1
    }
    global global_options macports::ui_priorities
    foreachport $portlist {
        # If we have a url, use that, since it's most specific
        # otherwise try to map the portname to a url
        if {$porturl eq ""} {
        # Verify the portname, getting portinfo to map to a porturl
            if {[catch {mportlookup $portname} result]} {
                ui_debug "$::errorInfo"
                break_softcontinue "lookup of portname $portname failed: $result" 1 status
            }
            if {[llength $result] < 2} {
                break_softcontinue "Port $portname not found" 1 status
            }
            lassign $result portname portinfo
            set porturl [dict get $portinfo porturl]
            set portdir [dict get $portinfo portdir]
        } elseif {$porturl ne "file://."} {
            # Extract the portdir from porturl and use it to search PortIndex.
            # Only the last two elements of the path (porturl) make up the
            # portdir.
            set portdir [file split [macports::getportdir $porturl]]
            set lsize [llength $portdir]
            set portdir \
                [file join [lindex $portdir [expr {$lsize - 2}]] \
                           [lindex $portdir [expr {$lsize - 1}]]]
            if {[catch {mportsearch $portdir no exact portdir} result]} {
                ui_debug "$::errorInfo"
                break_softcontinue "Portdir $portdir not found" 1 status
            }
            if {[llength $result] < 2} {
                break_softcontinue "Portdir $portdir not found" 1 status
            }
            set matchindex [lsearch -exact -nocase $result $portname]
            if {$matchindex != -1} {
                set portinfo [lindex $result [incr matchindex]]
            } else {
                ui_warn "Portdir $portdir doesn't seem to belong to portname $portname"
                set portinfo [lindex $result 1]
            }
            set portname [dict get $portinfo name]
        }
        set portpath [macports::getportdir $porturl]
        set logfile [file join [macports::getportlogpath $portpath $portname] "main.log"]
        if {[file exists $logfile]} {
            if {[catch {set fp [open $logfile r]} result]} {
                break_softcontinue "Could not open file $logfile: $result" 1 status
            }
            set data [read $fp]
            set data [split $data "\n"]

            if {[info exists global_options(ports_log_phase)]} {
                set phase $global_options(ports_log_phase);
            } else {
                set phase "\[a-z\]*"
            }

            if {[info exists global_options(ports_log_level)]} {
                set index [lsearch -exact ${ui_priorities} $global_options(ports_log_level)]
                if {$index == -1} {
                    set prefix ""
                } else {
                    set prefix [join [lrange ${ui_priorities} 0 $index] "|"]
                }
            } else {
                set prefix "\[a-z\]*"
            }
            set exp "^:($prefix|any):($phase|any) (.*)$"
            foreach line $data {
                if {[regexp $exp $line -> lpriority lphase lmsg] == 1} {
                    puts "[macports::ui_prefix_default $lpriority]$lmsg"
                }
            }

            close $fp
        } else {
            break_softcontinue "Log file for port $portname not found" 1 status
        }
    }
    return 0
}


proc action_info { action portlist opts } {
    set status 0
    if {[require_portlist portlist]} {
        return 1
    }

    set separator ""
    global global_variations global_options
    set gvariations [dict create {*}[array get global_variations]]
    foreachport $portlist {
        set index_only 0
        if {[dict exists $options ports_info_index] && [dict get $options ports_info_index]} {
            set index_only 1
        }
        puts -nonewline $separator
        set portinfo ""
        # If we have a url, use that, since it's most specific
        # otherwise try to map the portname to a url
        if {$porturl eq "" || $index_only} {
        # Verify the portname, getting portinfo to map to a porturl
            if {[catch {mportlookup $portname} result]} {
                ui_debug "$::errorInfo"
                break_softcontinue "lookup of portname $portname failed: $result" 1 status
            }
            if {[llength $result] < 2} {
                break_softcontinue "Port $portname not found" 1 status
            }
            lassign $result portname portinfo
            set porturl [dict get $portinfo porturl]
        }

        if {!$index_only} {
            # Add any global_variations to the variations
            # specified for the port (so we get e.g. dependencies right)
            set merged_variations [dict merge $gvariations $variations]

            if {![dict exists $options subport]} {
                dict set options subport $portname
            }

            if {[catch {set mport [mportopen $porturl $options $merged_variations]} result]} {
                ui_debug "$::errorInfo"
                break_softcontinue "Unable to open port: $result" 1 status
            }
            dict unset options subport
            set portinfo [dict merge $portinfo [mportinfo $mport]]
            mportclose $mport
        } elseif {$portinfo eq ""} {
            ui_warn "no PortIndex entry found for $portname"
            continue
        }
        dict unset options ports_info_index

        # Understand which info items are actually lists by specifying
        # separators for the output. The list items correspond to the
        # normal, --pretty, and --line output formats.
        set list_map [dict create {*}{
            categories      {", "  ", "  ","}
            depends_fetch   {", "  ", "  ","}
            depends_extract {", "  ", "  ","}
            depends_patch   {", "  ", "  ","}
            depends_build   {", "  ", "  ","}
            depends_lib     {", "  ", "  ","}
            depends_run     {", "  ", "  ","}
            depends_test    {", "  ", "  ","}
            maintainers     {", "  "\n"  ","}
            platforms       {", "  ", "  ","}
            variants        {", "  ", "  ","}
            conflicts       {", "  ", "  ","}
            subports        {", "  ", "  ","}
            patchfiles      {", "  ", "  ","}
        }]

        # Label map for pretty printing
        set pretty_label [dict create {*}{
            heading     ""
            variants    Variants
            depends_fetch "Fetch Dependencies"
            depends_extract "Extract Dependencies"
            depends_patch "Patch Dependencies"
            depends_build "Build Dependencies"
            depends_run "Runtime Dependencies"
            depends_lib "Library Dependencies"
            depends_test "Test Dependencies"
            description "Brief Description"
            long_description "Description"
            fullname    "Full Name: "
            homepage    Homepage
            platforms   Platforms
            maintainers Maintainers
            license     License
            conflicts   "Conflicts with"
            replaced_by "Replaced by"
            subports    "Sub-ports"
            patchfiles  "Patchfiles"
        }]

        # Wrap-length map for pretty printing
        set pretty_wrap [dict create {*}{
            heading 0
            replaced_by 22
            variants 22
            depends_fetch 22
            depends_extract 22
            depends_patch 22
            depends_build 22
            depends_run 22
            depends_lib 22
            depends_test 22
            description 22
            long_description 22
            homepage 22
            platforms 22
            license 22
            conflicts 22
            maintainers 22
            subports 22
            patchfiles 22
        }]

        # Interpret a convenient field abbreviation
        if {[dict exists $options ports_info_depends] && [dict get $options ports_info_depends] eq "yes"} {
            dict unset options ports_info_depends
            set all_depends_options [list ports_info_depends_fetch ports_info_depends_extract \
                ports_info_depends_patch ports_info_depends_build ports_info_depends_lib \
                ports_info_depends_run ports_info_depends_test]
            foreach depends_option $all_depends_options {
                dict set options $depends_option yes
            }
            # replace all occurrences of --depends with the expanded options
            while 1 {
                set order_pos [lsearch -exact $global_options(options_${action}_order) ports_info_depends]
                if {$order_pos != -1} {
                    set global_options(options_${action}_order) [lreplace $global_options(options_${action}_order) \
                        $order_pos $order_pos {*}$all_depends_options]
                } else {
                    break
                }
            }
        }

        # Set up our field separators
        set show_label 1
        set field_sep "\n"
        set pretty_print 0
        set list_map_index 0

        # For human-readable summary, which is the default with no options
        if {[llength [dict filter $options key ports_info_*]] == 0} {
            set pretty_print 1
            set list_map_index 1
        } elseif {[dict exists $options ports_info_pretty]} {
            set pretty_print 1
            set list_map_index 1
            dict unset options ports_info_pretty
        }

        # Tune for sort(1)
        if {[dict exists $options ports_info_line]} {
            dict unset options ports_info_line
            set noseparator 1
            set show_label 0
            set field_sep "\t"
            set list_map_index 2
        }

        # Figure out whether to show field name
        set quiet [macports::ui_isset ports_quiet]
        if {$quiet} {
            set show_label 0
        }
        # In pretty-print mode we also suppress messages, even though we show
        # most of the labels:
        if {$pretty_print} {
            set quiet 1
        }

        # Spin through action options, emitting information for any found
        set fields [list]

        # This contains all parameters in order given on command line
        set opts_action $global_options(options_${action}_order)
        # Get the display fields in order provided on command line
        #  ::struct::set intersect does not keep order of items
        set opts_todo [list]
        foreach elem $opts_action {
            if {[dict exists $options $elem]} {
                lappend opts_todo $elem
            }
        }

        set fields_tried [list]
        if {![llength $opts_todo]} {
            set opts_todo {
                ports_info_heading
                ports_info_replaced_by
                ports_info_subports
                ports_info_variants
                ports_info_skip_line
                ports_info_long_description ports_info_homepage
                ports_info_skip_line ports_info_depends_fetch
                ports_info_depends_extract
                ports_info_depends_patch
                ports_info_depends_build
                ports_info_depends_lib ports_info_depends_run
                ports_info_depends_test
                ports_info_conflicts
                ports_info_platforms ports_info_license
                ports_info_maintainers
            }
        }
        foreach { option } $opts_todo {
            set opt [string range $option 11 end]
            # Artificial field name for formatting
            if {$pretty_print && $opt eq "skip_line"} {
                lappend fields ""
                continue
            }
            # Artificial field names to reproduce prettyprinted summary
            if {$opt eq "heading"} {
                set inf "[dict get $portinfo name] @[dict get $portinfo version]"
                set ropt "heading"
                if {[dict exists $portinfo revision] && [dict get $portinfo revision] > 0} {
                    append inf "_[dict get $portinfo revision]"
                }
                if {[dict exists $portinfo categories]} {
                    append inf " ([join [dict get $portinfo categories] ", "])"
                }
            } elseif {$opt eq "fullname"} {
                set inf "[dict get $portinfo name] @"
                append inf [composite_version [dict get $portinfo version] [dict get $portinfo active_variants]]
                set ropt "fullname"
            } else {
                # Map from friendly name
                set ropt [map_friendly_field_names $opt]

                # If there's no such info, move on
                if {![dict exists $portinfo $ropt]} {
                    set inf ""
                } else {
                    set inf [dict get $portinfo $ropt]
                }
            }

            # Calculate field label
            set label ""
            if {$pretty_print} {
                if {[dict exists $pretty_label $ropt]} {
                    set label [dict get $pretty_label $ropt]
                } else {
                    set label $opt
                }
            } elseif {$show_label} {
                set label "$opt: "
            }

            if {$ropt in {"description" "long_description"}} {
                # These fields support newlines, we need to [join ...] to make
                # them newlines
                set inf [join $inf]
                # Flatten value to a single line unless we are pretty printing
                if {!$pretty_print} {
                    set inf [string map {"\n" {\n}} $inf]
                }
            }

            # Add "(" "or" ")" "and" for human-readable output
            if {$pretty_print && $ropt eq "license"} {
                set infresult [list]
                foreach {e} $inf {
                    if {[llength $e] > 1} {
                        if {[llength $infresult] > 0} { lappend infresult " and " }
                        lappend infresult "([join $e " or "])"
                    } else {
                        if {[llength $infresult] > 0} { lappend infresult " and " }
                        lappend infresult $e
                    }
                }
                set inf [concat {*}$infresult]
            }

            # Format list of maintainers
            if {$ropt eq "maintainers"} {
                set infresult [list]
                foreach maintainer [macports::unobscure_maintainers $inf] {
                    set parts [list]

                    if {[dict exists $maintainer email]} {
                        set item [expr {$pretty_print ? "Email: " : ""}]
                        append item [dict get $maintainer email]
                        lappend parts $item
                    }
                    if {[dict exists $maintainer github]} {
                        set item [expr {$pretty_print ? "GitHub: " : ""}]
                        append item [dict get $maintainer github]
                        lappend parts $item
                    }
                    if {[dict exists $maintainer keyword]} {
                        switch [dict get $maintainer keyword] {
                            nomaintainer {
                                lappend parts [expr {$pretty_print ? "none" : ""}]
                            }
                            openmaintainer {
                                set item [expr {$pretty_print ? "Policy: " : ""}]
                                append item "openmaintainer"
                                lappend parts $item
                            }
                        }
                    }

                    lappend infresult [join $parts [expr {$pretty_print ? ", " : " "}]]
                }
                set inf $infresult
            }

            # Format variants
            if {$pretty_print && $ropt eq "variants"} {
                set pi_vars $inf
                set inf [list]
                foreach v [lsort $pi_vars] {
                    set varmodifier ""
                    if {[dict exists $variations $v]} {
                        # selected by command line, prefixed with +/-
                        set varmodifier [dict get $variations $v]
                    } elseif {[info exists global_variations($v)]} {
                        # selected by variants.conf, prefixed with (+)/(-)
                        set varmodifier "($global_variations($v))"
                        # Retrieve additional information from the new key.
                    } elseif {[dict exists $portinfo vinfo $v is_default]} {
                        set varmodifier "\[[dict get $portinfo vinfo $v is_default]]"
                    }
                    lappend inf "$varmodifier$v"
                }
            }

            # Show full depspec only in verbose mode
            if {[string match "depend*" $ropt]
                        && ![macports::ui_isset ports_verbose]} {
                set pi_deps $inf
                set inf [list]
                foreach d $pi_deps {
                    lappend inf [lindex [split $d :] end]
                }
            }

            # End of special pretty-print formatting for certain fields

            if {[dict exists $list_map $ropt]} {
                set field [join $inf [lindex [dict get $list_map $ropt] $list_map_index]]
            } else {
                set field $inf
            }

            # Assemble the entry
            if {$pretty_print} {
                # The two special fields are considered headings and are
                # emitted immediately, rather than waiting. Also they are not
                # recorded on the list of fields tried
                if {$ropt eq "heading" || $ropt eq "fullname"} {
                    puts "$label$field"
                    continue
                }
            }
            lappend fields_tried $label
            if {$pretty_print} {
                if {$field eq ""} {
                    continue
                }
                if {$label eq ""} {
                    set wrap_len 0
                    if {[dict exists $pretty_wrap $ropt]} {
                        set wrap_len [dict get $pretty_wrap $ropt]
                    }
                    lappend fields [wrap $field 0 [string repeat " " $wrap_len]]
                } else {
                    set wrap_len [string length $label]
                    if {[dict exists $pretty_wrap $ropt]} {
                        set wrap_len [dict get $pretty_wrap $ropt]
                    }
                    lappend fields [wraplabel $label $field 0 [string repeat " " $wrap_len]]
                }

            } else { # Not pretty print
                lappend fields "$label$field"
            }
        }

        # Now output all that information:
        if {[llength $fields]} {
            puts [join $fields $field_sep]
        } else {
            if {$pretty_print && [llength $fields_tried]} {
                puts -nonewline "$portinfo(name) has no "
                puts [join $fields_tried ", "]
            }
        }
        if {![info exists noseparator]} {
            set separator "--\n"
        }
    }

    return $status
}


proc action_location { action portlist opts } {
    set status 0
    if {[require_portlist portlist]} {
        return 1
    }
    foreachport $portlist {
        if {[catch {set ref [registry_installed $portname [composite_version $portversion $variations]]} result]} {
            ui_debug $::errorInfo
            break_softcontinue "port location failed: $result" 1 status
        }

        ui_notice "Port [$ref name] [$ref version]_[$ref revision][$ref variants] is installed as an image in:"
        puts [$ref location]
    }

    return $status
}


proc action_notes { action portlist opts } {
    global macports::ui_prefix global_variations

    if {[require_portlist portlist]} {
        return 1
    }

    set status 0
    set gvariations [dict create {*}[array get global_variations]]
    foreachport $portlist {
        if {$porturl eq ""} {
            # Look up the port.
            if {[catch {mportlookup $portname} result]} {
                ui_debug $::errorInfo
                break_softcontinue "The lookup of '$portname' failed: $result" \
                                1 status
            }
            if {[llength $result] < 2} {
                break_softcontinue "The port '$portname' was not found" 1 status
            }

            # Retrieve the port's URL.
            lassign $result portname portinfo
            set porturl [dict get $portinfo porturl]
        }

        # Add any global_variations to the variations
        # specified for the port
        set merged_variations [dict merge $gvariations $variations]
        if {![dict exists $options subport]} {
            dict set options subport $portname
        }

        # Open the Portfile associated with this port.
        if {[catch {set mport [mportopen $porturl $options \
                                         $merged_variations]} \
                   result]} {
            ui_debug $::errorInfo
            break_softcontinue [concat "The URL '$porturl' could not be" \
                                       "opened: $result"] 1 status
        }
        set portinfo [mportinfo $mport]
        mportclose $mport

        # Retrieve the port's name once more to ensure it has the proper case.
        set portname [dict get $portinfo name]

        # Display the notes associated with this Portfile (if any).
        if {[dict exists $portinfo notes]} {
            ui_notice "$ui_prefix $portname has the following notes:"
            foreach note [dict get $portinfo notes] {
                puts [wrap $note 0 "  " 1]
            }
        } else {
            ui_notice "$ui_prefix $portname has no notes."
        }
    }
    return $status
}


proc action_provides { action portlist opts } {
    # In this case, portname is going to be used for the filename... since
    # that is the first argument we expect... perhaps there is a better way
    # to do this?
    if { ![llength $portlist] } {
        ui_error "Please specify a filename to check which port provides that file."
        return 1
    }
    foreach filename $portlist {
        set file [file normalize $filename]
        if {[file exists $file] || ![catch {file type $file}]} {
            if {![file isdirectory $file] || [file type $file] eq "link"} {
                set port [registry::file_registered $file]
                if { $port != 0 } {
                    if {![macports::ui_isset ports_quiet]} {
                        puts -nonewline "$file is provided by: "
                    }
                    puts $port
                } else {
                    if {![macports::ui_isset ports_quiet]} {
                        puts "$file is not provided by a MacPorts port."
                    }
                }
            } else {
                if {![macports::ui_isset ports_quiet]} {
                    puts "$file is a directory."
                }
            }
        } else {
            if {![macports::ui_isset ports_quiet]} {
                puts "$file does not exist."
            }
        }
    }

    return 0
}


proc action_activate { action portlist opts } {
    set status 0
    if {[require_portlist portlist] || [prefix_unwritable]} {
        return 1
    }
    foreachport $portlist {
        set composite_version [composite_version $portversion $variations]
        if {[catch {registry_installed $portname $composite_version} result]} {
            break_softcontinue "port activate failed: $result" 1 status
        }
        set regref $result
        if {![dict exists $options ports_activate_no-exec] &&
            [registry::run_target $regref activate $options]
        } then {
            continue
        }
        if {![macports::global_option_isset ports_dryrun]} {
            if {[catch {portimage::activate_composite $portname $composite_version $options} result]} {
                ui_debug $::errorInfo
                break_softcontinue "port activate failed: $result" 1 status
            }
        } else {
            ui_msg "Skipping activate $portname (dry run)"
        }
    }

    return $status
}


proc action_deactivate { action portlist opts } {
    set status 0
    if {[require_portlist portlist] || [prefix_unwritable]} {
        return 1
    }
    set portlist [portlist_sortdependents $portlist]
    foreachport $portlist {
        set composite_version [composite_version $portversion $variations]
        if {![dict exists $options ports_deactivate_no-exec]
            && ![catch {registry::entry installed $portname} ilist]
            && [llength $ilist] == 1} {

            set regref [lindex $ilist 0]
            if {($composite_version eq "" || $composite_version eq "[$regref version]_[$regref revision][$regref variants]")
                && [$regref installtype] eq "image" && [registry::run_target $regref deactivate $options]} {
                continue
            }
        }
        if {![macports::global_option_isset ports_dryrun]} {
            if { [catch {portimage::deactivate_composite $portname $composite_version $options} result] } {
                ui_debug $::errorInfo
                break_softcontinue "port deactivate failed: $result" 1 status
            }
        } else {
            ui_msg "Skipping deactivate $portname (dry run)"
        }
    }

    return $status
}


proc action_select { action portlist opts } {
    ui_debug "action_select \[$portlist] \[$opts]..."

    set commands [dict keys $opts ports_select_*]

    # Error out if no group is specified or command is not --summary.
    if {[llength $portlist] < 1 && [string map {ports_select_ ""} [lindex $commands 0]] ne "summary"} {
        ui_error "Incorrect usage. Correct synopsis is one of:"
        ui_msg   "  port select \[--list|--show\] <group>"
        ui_msg   "  port select \[--set\] <group> <version>"
        ui_msg   "  port select --summary"
        return 1
    }

    set group [lindex $portlist 0]

    # If no command (--set, --show, --list, --summary) is specified *but*
    #  more than one argument is specified, default to the set command.
    if {[llength $commands] < 1 && [llength $portlist] > 1} {
        set command set
        ui_debug [concat "Although no command was specified, more than " \
                         "one argument was specified.  Defaulting to the " \
                         "'set' command..."]
    # If no command (--set, --show, --list) is specified *and* less than two
    # argument are specified, default to the list command.
    } elseif {[llength $commands] < 1} {
        set command list
        ui_debug [concat "No command was specified. Defaulting to the " \
                         "'list' command..."]
    # Only allow one command to be specified at a time.
    } elseif {[llength $commands] > 1} {
        ui_error [concat "Multiple commands were specified. Only one " \
                         "command may be specified at a time."]
        return 1
    } else {
        set command [string map {ports_select_ ""} [lindex $commands 0]]
        ui_debug "The '$command' command was specified."
    }

    switch -- $command {
        list {
            if {[llength $portlist] > 1} {
                ui_warn [concat "The 'list' command does not expect any " \
                                "arguments. Extra arguments will be ignored."]
            }

            if {[catch {mportselect show $group} selected_version]} {
                ui_debug $::errorInfo
                ui_warn "Unable to get active selected version: $selected_version"
            }

            # On error mportselect returns with the code 'error'.
            if {[catch {mportselect $command $group} versions]} {
                ui_error "The 'list' command failed: $versions"
                return 1
            }

            ui_notice "Available versions for $group:"
            foreach v $versions {
                ui_notice -nonewline "\t"
                if {$selected_version eq $v} {
                    ui_msg "$v (active)"
                } else {
                    ui_msg "$v"
                }
            }
            return 0
        }
        set {
            if {[llength $portlist] < 2} {
                ui_error [concat "The 'set' command expects two " \
                                 "arguments: <group>, <version>"]
                return 1
            } elseif {[llength $portlist] > 2} {
                ui_warn [concat "The 'set' command only expects two " \
                                "arguments. Extra arguments will be " \
                                "ignored."]
            }
            set version [lindex $portlist 1]

            ui_msg -nonewline "Selecting '$version' for '$group' "
            if {[catch {mportselect $command $group $version} result]} {
                ui_msg "failed: $result"
                return 1
            }
            ui_msg "succeeded. '$version' is now active."
            return 0
        }
        show {
            if {[llength $portlist] > 1} {
                ui_warn [concat "The 'show' command does not expect any " \
                                "arguments. Extra arguments will be ignored."]
            }

            if {[catch {mportselect $command $group} selected_version]} {
                ui_error "The 'show' command failed: $selected_version"
                return 1
            }
            puts [concat "The currently selected version for '$group' is " \
                         "'$selected_version'."]
            return 0
        }
        summary {
            if {[llength $portlist] > 0} {
                ui_warn [concat "The 'summary' command does not expect any " \
                                "arguments. Extra arguments will be ignored."]
            }

            if {[catch {mportselect $command} portgroups]} {
                ui_error "The 'summary' command failed: $portgroups"
                return 1
            }

            set w1 4
            set w2 8
            set formatStr "%-*s  %-*s  %s"

            set groups [list]
            foreach pg $portgroups {
                set groupdesc [dict create name [string trim $pg]]

                if {[catch {mportselect list $pg} versions]} {
                    ui_warn "The list of options for the select group $pg could not be obtained: $versions"
                    continue
                }
                # remove "none", sort the list, append none at the end
                set noneidx [lsearch -exact $versions "none"]
                set versions [lsort [lreplace $versions $noneidx $noneidx]]
                lappend versions "none"
                dict set groupdesc versions $versions

                if {[catch {mportselect show $pg} selected_version]} {
                    ui_warn "The currently selected option for the select group $pg could not be obtained: $selected_version"
                    continue
                }
                dict set groupdesc selected $selected_version

                set w1 [expr {max($w1, [string length $pg])}]
                set w2 [expr {max($w2, [string length $selected_version])}]

                lappend groups $groupdesc
            }
            if {![macports::ui_isset ports_quiet]} {
                puts [format $formatStr $w1 "Name" $w2 "Selected" "Options"]
                puts [format $formatStr $w1 "====" $w2 "========" "======="]
            }
            foreach groupdesc $groups {
                puts [format $formatStr $w1 [dict get $groupdesc name] $w2 [dict get $groupdesc selected] [join [dict get $groupdesc versions] " "]]
            }
            return 0
        }
        default {
            ui_error "An unknown command '$command' was specified."
            return 1
        }
    }
}


proc action_selfupdate { action portlist opts } {
    if {[prefix_unwritable]} {
        return 1
    }
    global global_options ui_options
    set options [array get global_options]
    if {[dict exists $options ports_${action}_nosync] && [dict get $options ports_${action}_nosync] eq "yes"} {
        ui_warn "port selfupdate --nosync is deprecated, use --no-sync instead"
        dict set options ports_${action}_no-sync [dict get $options ports_${action}_nosync]
    }
    if {[info exists ui_options(ports_commandfiles)]} {
        dict set options ports_${action}_presync 1
    }
    if { [catch {macports::selfupdate $options selfupdate_status} result] } {
        ui_debug $::errorInfo
        ui_error $result
        if {![macports::ui_isset ports_verbose]} {
            ui_msg "Please run `port -v selfupdate' for details."
        } else {
            # Let's only print the ticket URL if the user has followed the
            # advice we printed earlier.
            print_tickets_url
        }
        fatal "port selfupdate failed: $result"
    }

    if {[dict get $selfupdate_status base_updated]} {
        # Base was upgraded, re-execute now to trigger sync if possible
        global argv
        if {[info exists ui_options(ports_commandfiles)]
            || {;} in $argv} {
            # Batch mode or multiple actions on the command line, just exit
            # since re-executing all actions may not be correct.
            if {[dict get $selfupdate_status needed_portindex]} {
                ui_msg "Not all sources could be fully synced using the old version of MacPorts."
                ui_msg "Please run selfupdate again now that MacPorts base has been updated."
            }
            return -999
        }

        if {![dict exists $options ports_selfupdate_no-sync] || ![dict get $options ports_selfupdate_no-sync]} {
            # When re-executing, strip the -f flag to prevent an endless loop
            set new_argv {}
            foreach arg $argv {
                if {[string match -nocase {-[a-z]*} $arg]} {
                    # map the -f flag to nothing
                    set arg [string map {f ""} $arg]
                    if {$arg eq "-"} {
                        # if -f was specified alone, just remove the flag completely
                        continue
                    }
                }
                lappend new_argv $arg
            }
            # If this returns at all, it failed. Just catch any error to avoid
            # printing a backtrace at the top level.
            catch {
                execl $::argv0 $new_argv
            }
            ui_error "Failed to re-execute selfupdate, please run 'sudo port selfupdate' manually."
        }
        return -999
    }

    if {[dict get $selfupdate_status synced]} {
        ui_msg "\nThe ports tree has been updated."
        set length_outdated [llength [get_outdated_ports]]
        if {$length_outdated == 0} {
            ui_msg "All installed ports are up to date."
        } else {
            ui_msg "\n$length_outdated [expr {$length_outdated == 1 ? "port is": "ports are"}] outdated. Run 'port outdated' for details."
            ui_msg "To upgrade your installed ports, you should run"
            ui_msg "  port upgrade outdated"
        }
    }

    return 0
}


proc action_setrequested { action portlist opts } {
    set status 0
    if {[require_portlist portlist] || [prefix_unwritable]} {
        return 1
    }
    # set or unset?
    set val [string equal $action "setrequested"]
    foreachport $portlist {
        set composite_version [composite_version $portversion $variations]
        if {![catch {registry::entry imaged $portname} result]} {
            foreach i $result {
                set fullvers [$i version]_[$i revision][$i variants]
                if {$composite_version eq "" || $composite_version eq $fullvers} {
                    ui_info "Setting requested flag for $portname @$fullvers to $val"
                    $i requested $val
                    set any_match 1
                }
            }
            if {![info exists any_match]} {
                break_softcontinue "[string trim "$portname $composite_version"] is not installed" 1 status
            }
        } else {
            ui_debug $::errorInfo
            break_softcontinue "$result" 1 status
        }
    }

    return $status
}

proc action_diagnose { action portlist opts } {
    macports::diagnose_main $opts
    return 0
}

proc action_reclaim { action portlist opts } {
    if {[prefix_unwritable]} {
        return 1
    }
    global macports::revupgrade_autorun

    set status [macports::reclaim_main $opts]

    if {$status == 0 &&
        ![dict exists $opts ports_upgrade_no-rev-upgrade] &&
        ${revupgrade_autorun}} {
        set status [action_revupgrade $action $portlist $opts]
    }

    return $status
}

proc action_snapshot { action portlist opts } {
    if {![dict exists $opts ports_snapshot_diff] && ![dict exists $opts ports_snapshot_list]
        && ![dict exists $opts ports_snapshot_help] && [prefix_unwritable]} {
        return 1
    }
    if {[catch {macports::snapshot_main $opts} result]} {
        ui_debug $::errorInfo
        return 1
    }
	return $result
}

proc action_restore { action portlist opts } {
    if {[prefix_unwritable]} {
        return 1
    }
    return [macports::restore_main $opts]
}

proc action_migrate { action portlist opts } {
    if {[prefix_unwritable]} {
        return 1
    }
    set result [macports::migrate_main $opts]
    if {$result == -999} {
        global ui_options argv
        if {[info exists ui_options(ports_commandfiles)]
            || {;} in $argv} {
            # Batch mode or multiple actions given, just exit since re-
            # executing all actions may not be correct (and we can't
            # really edit the args in a batch file anyway).
            ui_msg "Please run migrate again now that MacPorts base has been updated."
            return -999
        }
        # MacPorts base was upgraded, re-execute migrate with the --continue flag
        execl $::argv0 [list {*}$::argv "--continue"]
        ui_debug "Would have executed $::argv0 $::argv --continue"
        ui_error "Failed to re-execute MacPorts migration, please run 'sudo port migrate' manually."
    }
    if {$result == -1} {
        # snapshot error
        ui_error "Failed to create a snapshot and migration cannot proceed."
    }
    return $result
}

proc action_upgrade { action portlist opts } {
    if {[require_portlist portlist "yes"] || (![macports::global_option_isset ports_dryrun] && [prefix_unwritable])} {
        return 1
    }

    # shared depscache for all ports in the list
    array set depscache {}
    set status 0
    foreachport $portlist {
        if {![info exists depscache(port:$portname)]} {
            set status [macports::upgrade $portname "port:$portname" $requested_variations $options depscache]
            # status 2 means the port was not found in the index,
            # status 3 means the port is not installed
            if {$status != 0 && $status != 2 && $status != 3 && ![macports::ui_isset ports_processall]} {
                break
            }
        }
    }

    if {$status != 0 && $status != 2 && $status != 3} {
        print_tickets_url
    } elseif {$status == 0} {
        global macports::revupgrade_autorun
        if {![dict exists $opts ports_upgrade_no-rev-upgrade] && ${revupgrade_autorun} && ![macports::global_option_isset ports_dryrun]} {
            set status [action_revupgrade $action $portlist $opts]
        }
    }

    return $status
}

proc action_revupgrade { action portlist opts } {
    global macports::revupgrade_mode
    if {$revupgrade_mode eq "rebuild" && [prefix_unwritable]} {
        return 1
    }
    set status [macports::revupgrade $opts]
    switch $status {
        1 {
            print_tickets_url
        }
    }

    return $status
}


proc action_version { action portlist opts } {
    if {![macports::ui_isset ports_quiet]} {
        puts -nonewline "Version: "
    }
    puts [macports::version]
    return 0
}


proc action_platform { action portlist opts } {
    global macports::os_platform macports::os_major macports::os_arch
    if {![macports::ui_isset ports_quiet]} {
        puts -nonewline "Platform: "
    }
    puts "${os_platform} ${os_major} ${os_arch}"
    return 0
}


proc action_dependents { action portlist opts } {
    if {[require_portlist portlist]} {
        return 1
    }
    set ilist [list]

    set status 0
    foreachport $portlist {
        set composite_version [composite_version $portversion $variations]
        # choose the active version if there is one
        set ilist [registry_installed $portname $composite_version no yes]
        if {$ilist eq ""} {
            set ilist [registry_installed $portname $composite_version no no]
        }
        if {$ilist eq ""} {
            break_softcontinue "[string trim "$portname $composite_version"] is not installed" 1 status
        }
        set regref [lindex $ilist 0]
        set portname [$regref name]

        set deplist [portlist_sortregrefs [$regref dependents]]
        if { [llength $deplist] > 0 } {
            if {$action eq "rdependents"} {
                set toplist $deplist
                while 1 {
                    set newlist [list]
                    foreach dep $deplist {
                        set depname [$dep name]
                        if {![info exists seen($depname)]} {
                            set seen($depname) 1
                            set rdeplist [portlist_sortregrefs [$dep dependents]]
                            foreach rdep $rdeplist {
                                lappend newlist $rdep
                            }
                            set dependentsof($depname) $rdeplist
                        }
                    }
                    if {[llength $newlist] > 0} {
                        set deplist $newlist
                    } else {
                        break
                    }
                }
                set portstack [list $toplist]
                set pos_stack [list 0]
                array unset seen
                set rdependents_full [expr {[dict exists $options ports_rdependents_full] && [string is true -strict [dict get $options ports_rdependents_full]]}]
                ui_notice "The following ports are dependent on ${portname}:"
                while 1 {
                    set cur_portlist [lindex $portstack end]
                    set cur_pos [lindex $pos_stack end]
                    if {$cur_pos >= [llength $cur_portlist]} {
                        set portstack [lreplace ${portstack}[set portstack {}] end end]
                        set pos_stack [lreplace ${pos_stack}[set pos_stack {}] end end]
                        if {[llength $portstack] <= 0} {
                            break
                        } else {
                            continue
                        }
                    }
                    set cur_port [lindex $cur_portlist $cur_pos]
                    set cur_portname [$cur_port name]
                    set spaces [string repeat " " [expr {[llength $pos_stack] * 2}]]
                    if {![info exists seen($cur_portname)] || $rdependents_full} {
                        if {$rdependents_full || [macports::ui_isset ports_verbose]} {
                            puts "${spaces}${cur_portname} @[$cur_port version]_[$cur_port revision][$cur_port variants]"
                        } else {
                            puts "${spaces}${cur_portname}"
                        }
                        set seen($cur_portname) 1
                        incr cur_pos
                        lset pos_stack end $cur_pos
                        if {[info exists dependentsof($cur_portname)]} {
                            lappend portstack $dependentsof($cur_portname)
                            lappend pos_stack 0
                        }
                        continue
                    }
                    incr cur_pos
                    lset pos_stack end $cur_pos
                }
            } else {
                foreach dep $deplist {
                    set depportname [$dep name]
                    if {[info exists seen($depportname)] && ([macports::ui_isset ports_quiet] || ![macports::ui_isset ports_verbose])} {
                        continue
                    }
                    set seen($depportname) 1
                    if {[macports::ui_isset ports_quiet]} {
                        ui_msg "$depportname"
                    } elseif {![macports::ui_isset ports_verbose]} {
                        ui_msg "$depportname depends on $portname"
                    } else {
                        ui_msg "$depportname @[$dep version]_[$dep revision][$dep variants] depends on $portname (by port:)"
                    }
                }
            }
        } else {
            ui_notice "$portname has no dependents."
        }
    }
    return $status
}


proc action_deps { action portlist opts } {
    set status 0
    if {[require_portlist portlist]} {
        return 1
    }
    global global_variations
    set separator ""
    set labeldict [dict create depends_fetch Fetch depends_extract Extract depends_patch Patch depends_build Build depends_lib Library depends_run Runtime depends_test Test]
    set gvariations [dict create {*}[array get global_variations]]

    foreachport $portlist {
        set deptypes [list]
        if {!([dict exists $options ports_${action}_no-build] && [string is true -strict [dict get $options ports_${action}_no-build]])} {
            lappend deptypes depends_fetch depends_extract depends_patch depends_build
        }
        lappend deptypes depends_lib depends_run
        if {!([dict exists $options ports_${action}_no-test] && [string is true -strict [dict get $options ports_${action}_no-test]])} {
            lappend deptypes depends_test
        }

        set portinfo ""
        # If we have a url, use that, since it's most specific
        # otherwise try to map the portname to a url
        if {$porturl eq ""} {
        # Verify the portname, getting portinfo to map to a porturl
            if {[catch {mportlookup $portname} result]} {
                ui_debug "$::errorInfo"
                break_softcontinue "lookup of portname $portname failed: $result" 1 status
            }
            if {[llength $result] < 2} {
                break_softcontinue "Port $portname not found" 1 status
            }
            lassign $result portname portinfo
            set porturl [dict get $portinfo porturl]
        } elseif {$porturl ne "file://."} {
            # Extract the portdir from porturl and use it to search PortIndex.
            # Only the last two elements of the path (porturl) make up the
            # portdir.
            set portdir [file split [macports::getportdir $porturl]]
            set lsize [llength $portdir]
            set portdir \
                [file join [lindex $portdir [expr {$lsize - 2}]] \
                           [lindex $portdir [expr {$lsize - 1}]]]
            if {[catch {mportsearch $portdir no exact portdir} result]} {
                ui_debug "$::errorInfo"
                break_softcontinue "Portdir $portdir not found" 1 status
            }
            if {[llength $result] < 2} {
                break_softcontinue "Portdir $portdir not found" 1 status
            }
            set matchindex [lsearch -exact -nocase $result $portname]
            if {$matchindex != -1} {
                lassign [lrange $result $matchindex ${matchindex}+1] portname portinfo
            } else {
                ui_warn "Portdir $portdir doesn't seem to belong to portname $portname"
                lassign $result portname portinfo
            }
        }

        if {!([dict exists $options ports_${action}_index] && [dict get $options ports_${action}_index] eq "yes")} {
            # Add any global_variations to the variations
            # specified for the port, so we get dependencies right
            set merged_variations [dict merge $gvariations $variations]
            if {![dict exists $options subport]} {
                dict set options subport $portname
            }
            if {[catch {set mport [mportopen $porturl $options $merged_variations]} result]} {
                ui_debug "$::errorInfo"
                break_softcontinue "Unable to open port: $result" 1 status
            }
            set portinfo [dict merge $portinfo [mportinfo $mport]]
            mportclose $mport
        } elseif {$portinfo eq ""} {
            ui_warn "port ${action} --index does not work with the 'current' pseudo-port"
            continue
        }

        set deplist [list]
        set deps_output [list]
        set ndeps 0
        # get list of direct deps
        foreach type $deptypes {
            if {[dict exists $portinfo $type]} {
                if {$action eq "rdeps" || [macports::ui_isset ports_verbose]} {
                    foreach dep [dict get $portinfo $type] {
                        lappend deplist $dep
                    }
                } else {
                    foreach dep [dict get $portinfo $type] {
                        lappend deplist [lindex [split $dep :] end]
                    }
                }
                if {$action eq "deps"} {
                    set label "[dict get $labeldict $type] Dependencies"
                    lappend deps_output [wraplabel $label [join $deplist ", "] 0 [string repeat " " 22]]
                    incr ndeps [llength $deplist]
                    set deplist [list]
                }
            }
        }

        set version [dict get $portinfo version]
        set revision [dict get $portinfo revision]
        if {[dict exists $portinfo canonical_active_variants]} {
            set variants [dict get $portinfo canonical_active_variants]
        } else {
            set variants {}
        }

        puts -nonewline $separator
        if {$action eq "deps"} {
            if {$ndeps == 0} {
                ui_notice "$portname @${version}_${revision}${variants} has no dependencies."
            } else {
                ui_notice "Full Name: $portname @${version}_${revision}${variants}"
                puts [join $deps_output "\n"]
            }
            set separator "--\n"
            continue
        }

        set toplist $deplist
        set seen [dict create]
        set depsof [dict create]
        # gather all the deps
        while 1 {
            set newlist [list]
            foreach dep $deplist {
                set depname [lindex [split $dep :] end]
                if {![dict exists $seen $depname]} {
                    dict set seen $depname 1

                    # look up the dep
                    if {[catch {mportlookup $depname} result]} {
                        ui_debug "$::errorInfo"
                        break_softcontinue "lookup of portname $depname failed: $result" 1 status
                    }
                    if {[llength $result] < 2} {
                        break_softcontinue "Port $depname not found" 1 status
                    }
                    set portinfo [lindex $result 1]
                    set porturl [dict get $portinfo porturl]
                    dict set options subport [dict get $portinfo name]

                    # open the portfile if requested
                    if {!([dict exists $options ports_${action}_index] && [dict get $options ports_${action}_index] eq "yes")} {
                        if {[catch {set mport [mportopen $porturl $options $merged_variations]} result]} {
                            ui_debug "$::errorInfo"
                            break_softcontinue "Unable to open port: $result" 1 status
                        }
                        set portinfo [dict merge $portinfo [mportinfo $mport]]
                        mportclose $mport
                    }

                    # get list of the dep's deps
                    set rdeplist [list]
                    foreach type $deptypes {
                        if {[dict exists $portinfo $type]} {
                            foreach rdep [dict get $portinfo $type] {
                                lappend rdeplist $rdep
                                lappend newlist $rdep
                            }
                        }
                    }
                    dict set depsof $depname $rdeplist
                }
            }
            if {[llength $newlist] > 0} {
                set deplist $newlist
            } else {
                break
            }
        }
        set portstack [list $toplist]
        set pos_stack [list 0]
        set seen [dict create]
        if {[llength $toplist] > 0} {
            ui_notice "The following ports are dependencies of $portname @${version}_${revision}${variants}:"
        } else {
            ui_notice "$portname @${version}_${revision}${variants} has no dependencies."
        }
        set rdeps_full [expr {[dict exists $options ports_${action}_full] && [string is true -strict [dict get $options ports_${action}_full]]}]
        while 1 {
            set cur_portlist [lindex $portstack end]
            set cur_pos [lindex $pos_stack end]
            if {$cur_pos >= [llength $cur_portlist]} {
                set portstack [lreplace ${portstack}[set portstack {}] end end]
                set pos_stack [lreplace ${pos_stack}[set pos_stack {}] end end]
                if {[llength $portstack] <= 0} {
                    break
                } else {
                    # no longer processing the last port's deps
                    set prev_port [lindex [lindex $portstack end] [lindex $pos_stack end]-1]
                    set prev_portname [lindex [split $prev_port :] end]
                    dict set seen $prev_portname 1
                    continue
                }
            }
            set cur_port [lindex $cur_portlist $cur_pos]
            set cur_portname [lindex [split $cur_port :] end]
            set spaces [string repeat " " [expr {[llength $pos_stack] * 2}]]
            if {![dict exists $seen $cur_portname] || $rdeps_full} {
                set cyclic_marker ""
                if {[dict exists $seen $cur_portname] && [dict get $seen $cur_portname] == 2} {
                    # Dependency cycle, note it and don't process deps
                    # further to avoid looping infinitely.
                    set cyclic_marker " (cyclic dependency)"
                }
                if {[macports::ui_isset ports_verbose]} {
                    puts "${spaces}${cur_port}${cyclic_marker}"
                } else {
                    puts "${spaces}${cur_portname}${cyclic_marker}"
                }
                incr cur_pos
                lset pos_stack end $cur_pos
                if {$cyclic_marker eq ""} {
                    if {[dict exists $depsof $cur_portname]} {
                        # Mark as currently processing this port's deps
                        dict set seen $cur_portname 2
                        lappend portstack [dict get $depsof $cur_portname]
                        lappend pos_stack 0
                    } else {
                        # Just mark as seen
                        dict set seen $cur_portname 1
                    }
                }
                continue
            }
            incr cur_pos
            lset pos_stack end $cur_pos
        }
        set separator "--\n"
    }
    return $status
}


proc action_uninstall { action portlist opts } {
    set status 0
    if {[macports::global_option_isset port_uninstall_old]} {
        # if -u then uninstall all inactive ports
        # (union these to any other ports user has in the port list)
        set portlist [portlist::opUnion $portlist [get_inactive_ports]]
    } else {
        # Otherwise the user hopefully supplied a portlist, or we'll default to the existing directory
        if {[require_portlist portlist]} {
            return 1
        }
    }
    if {![macports::global_option_isset ports_dryrun] && [prefix_unwritable]} {
        return 1
    }

    set portlist [portlist_sortdependents $portlist]

    foreachport $portlist {
        if {[registry::entry imaged $portname] eq ""} {
            # if the code path arrives here the port either isn't installed, or
            # it doesn't exist at all. We can't be sure, but we can check the
            # portindex whether a port by that name exists (in which case not
            # uninstalling it is probably no problem). If there is no port by
            # that name, alert the user in case of typos.
            ui_info "$portname is not installed"
            if {[catch {set res [mportlookup $portname]} result] || [llength $res] == 0} {
                ui_warn "no such port: $portname, skipping uninstall"
            }
            continue
        }
        set composite_version [composite_version $portversion $variations]
        if {![dict exists $options ports_uninstall_no-exec]
            && ![catch {registry_installed $portname $composite_version} regref]} {

            if {[registry::run_target $regref uninstall $options]} {
                continue
            }
        }

        if { [catch {registry_uninstall::uninstall_composite $portname $composite_version $options} result] } {
            ui_debug $::errorInfo
            break_softcontinue "port uninstall failed: $result" 1 status
        }
    }

    return $status
}


proc action_installed { action portlist opts } {
    global private_options
    set status 0
    set restrictedList 0
    set ilist [list]

    if { [llength $portlist] || (![info exists private_options(ports_no_args)] || $private_options(ports_no_args) eq "no")} {
        set restrictedList 1
        foreachport $portlist {
            set composite_version [composite_version $portversion $variations]
            if {[catch {lappend ilist {*}[registry_installed $portname $composite_version no no]} result]} {
                ui_debug $::errorInfo
                break_softcontinue "port installed failed: $result" 1 status
            }
        }
    } else {
        if {[catch {set ilist [registry::entry imaged]} result]} {
            ui_debug $::errorInfo
            ui_error "port installed failed: $result"
            set status 1
        }
    }
    if { [llength $ilist] > 0 } {
        ui_notice "The following ports are currently installed:"
        foreach i [portlist_sortregrefs $ilist] {
            set extra ""
            if {[macports::ui_isset ports_verbose]} {
                set rvariants [$i requested_variants]
                if {$rvariants != 0} {
                    append extra " requested_variants='$rvariants'"
                }
                set os_platform [$i os_platform]
                set os_major [$i os_major]
                if {$os_platform != 0 && $os_platform ne "" && $os_major != 0 && $os_major ne ""} {
                    append extra " platform='$os_platform $os_major'"
                }
                set archs [$i archs]
                if {$archs != 0 && $archs ne ""} {
                    append extra " archs='$archs'"
                }
                set date [$i date]
                if {$date ne ""} {
                    append extra " date='[clock format $date -format "%Y-%m-%dT%H:%M:%S%z"]'"
                }
            }
            set activestr ""
            if {[$i state] eq "installed"} {
                set activestr " (active)"
            }
            puts "  [$i name] @[$i version]_[$i revision][$i variants]${activestr}${extra}"
        }
    } elseif { $restrictedList } {
        ui_notice "None of the specified ports are installed."
    } else {
        ui_notice "No ports are installed."
    }

    return $status
}


proc action_outdated { action portlist opts } {
    global private_options macports::cxx_stdlib macports::os_platform \
           macports::os_major
    set status 0

    # If port names were supplied, limit ourselves to those ports, else check all installed ports
    set ilist [list]
    set restrictedList 0
    if { [llength $portlist] || (![info exists private_options(ports_no_args)] || $private_options(ports_no_args) eq "no")} {
        set restrictedList 1
        foreach portspec $portlist {
            set portname [dict get $portspec name]
            set composite_version [composite_version [dict get $portspec version] [dict get $portspec variants]]
            if {[catch {lappend ilist {*}[registry_installed $portname $composite_version no yes]} result]} {
                ui_debug $::errorInfo
                break_softcontinue "port outdated failed: $result" 1 status
            }
        }
    } elseif {[catch {set ilist [registry::entry installed]} result]} {
        ui_debug $::errorInfo
        ui_error "port outdated failed: $result"
        set status 1
    }

    set num_outdated 0
    if { [llength $ilist] > 0 } {
        if {${cxx_stdlib} eq "libc++"} {
            set wrong_stdlib libstdc++
        } else {
            set wrong_stdlib libc++
        }
        foreach i [portlist_sortregrefs $ilist] {

            # Get information about the installed port
            set portname [$i name]
            set installed_version [$i version]
            set installed_revision [$i revision]
            set installed_compound "${installed_version}_${installed_revision}"
            set installed_epoch [$i epoch]

            # Get info about the port from the index
            if {[catch {set res [mportlookup $portname]} result]} {
                ui_debug $::errorInfo
                break_softcontinue "search for portname $portname failed: $result" 1 status
            }
            if {[llength $res] < 2} {
                if {[macports::ui_isset ports_debug]} {
                    puts "$portname ($installed_compound is installed; the port was not found in the port index)"
                }
                continue
            }
            lassign $res portname portinfo

            # Get information about latest available version and revision
            if {![dict exists $portinfo version]} {
                ui_warn "$portname has no version field"
                continue
            }
            set latest_version [dict get $portinfo version]
            set latest_revision 0
            if {[dict exists $portinfo revision] && [dict get $portinfo revision] > 0} {
                set latest_revision [dict get $portinfo revision]
            }
            set latest_compound "${latest_version}_${latest_revision}"
            set latest_epoch 0
            if {[dict exists $portinfo epoch]} {
                set latest_epoch [dict get $portinfo epoch]
            }

            # Compare versions, first checking epoch, then version, then revision
            set epoch_comp_result [expr {$installed_epoch - $latest_epoch}]
            set comp_result [vercmp $installed_version $latest_version]
            if { $comp_result == 0 } {
                set comp_result [expr {$installed_revision - $latest_revision}]
            }
            set reason ""
            if {$epoch_comp_result != 0 && $installed_version != $latest_version} {
                if {($comp_result >= 0 && $epoch_comp_result < 0) || ($comp_result <= 0 && $epoch_comp_result > 0)} {
                    set reason { (epoch $installed_epoch $relation $latest_epoch)}
                }
                set comp_result $epoch_comp_result
            } elseif {$comp_result == 0} {
                set os_platform_installed [$i os_platform]
                set os_major_installed [$i os_major]
                if {$os_platform_installed ni [list any "" 0] && $os_major_installed ni [list "" 0]
                    && ($os_platform_installed ne ${os_platform}
                        || ($os_major_installed ne "any" && $os_major_installed != ${os_major}))} {
                    set comp_result -1
                    set reason { (platform $os_platform_installed $os_major_installed != ${os_platform} ${os_major})}
                } else {
                    set cxx_stdlib_installed [$i cxx_stdlib]
                    if {[$i cxx_stdlib_overridden] == 0 && $cxx_stdlib_installed eq $wrong_stdlib} {
                        set comp_result -1
                        set reason { (C++ stdlib $cxx_stdlib_installed != ${cxx_stdlib})}
                    }
                }
            }

            # Report outdated (or, for verbose, predated) versions
            if { $comp_result != 0 } {

                # Form a relation between the versions
                set flag ""
                if { $comp_result > 0 } {
                    set relation ">"
                    set flag "!"
                } else {
                    set relation "<"
                }

                # Emit information
                if {$comp_result < 0 || [macports::ui_isset ports_verbose]} {

                    if {$num_outdated == 0} {
                        ui_notice "The following installed ports are outdated:"
                    }
                    incr num_outdated

                    puts [format "%-30s %-24s %1s" $portname "$installed_compound $relation $latest_compound [subst $reason]" $flag]
                }

            }
        }

        if {$num_outdated == 0} {
            ui_notice "No installed ports are outdated."
        }
    } elseif { $restrictedList } {
        ui_notice "None of the specified ports are outdated."
    } else {
        ui_notice "No ports are installed."
    }

    return $status
}


proc action_contents { action portlist opts } {
    set status 0
    if {[require_portlist portlist]} {
        return 1
    }
    global global_options
    if {[info exists global_options(ports_contents_size)]} {
        set units {}
        if {[info exists global_options(ports_contents_units)]} {
            set units [complete_size_units $global_options(ports_contents_units)]
        }
        set outstring {[format "%12s $file" [filesize $file $units]]}
    } else {
        set outstring {  $file}
    }

    foreachport $portlist {
        set composite_version [composite_version $portversion $variations]
        set ilist ""
        if {[catch {set ilist [registry_installed $portname $composite_version no yes]} result]} {
            ui_debug $::errorInfo
            break_softcontinue "port contents failed: $result" 1 status
        }
        if {$ilist ne ""} {
            set regref [lindex $ilist 0]
        } elseif {[catch {set regref [registry_installed $portname $composite_version yes no]} result]} {
            ui_debug $::errorInfo
            break_softcontinue "port contents failed: $result" 1 status
        }
        if {[$regref state] eq "installed"} {
            set files [$regref files]
        } else {
            set files [$regref imagefiles]
        }
        if {$files != 0 && [llength $files] > 0} {
            ui_notice "Port [$regref name] @[$regref version]_[$regref revision][$regref variants] contains:"
            foreach file $files {
                puts [subst $outstring]
            }
        } else {
            ui_notice "Port [$regref name] @[$regref version]_[$regref revision][$regref variants] does not have any files registered."
        }
    }

    return $status
}

# expand abbreviations of size units
proc complete_size_units {units} {
    if {$units eq "K" || $units eq "Ki"} {
        return "KiB"
    } elseif {$units eq "k"} {
        return "kB"
    } elseif {$units eq "Mi"} {
        return "MiB"
    } elseif {$units eq "M"} {
        return "MB"
    } elseif {$units eq "Gi"} {
        return "GiB"
    } elseif {$units eq "G"} {
        return "GB"
    } else {
        return $units
    }
}

# Show space used by the given ports' files
proc action_space {action portlist opts} {
    require_portlist portlist
    global global_options

    set units {}
    if {[info exists global_options(ports_space_units)]} {
        set units [complete_size_units $global_options(ports_space_units)]
    }
    set spaceall 0.0
    foreachport $portlist {
        set space 0.0
        set regref [lindex [registry::entry installed $portname] 0]
        if {$regref eq ""} {
            puts stderr "Port $portname is not active."
            continue
        }
        if {$portversion ne "" && $portversion ne "[$regref version]_[$regref revision]"} {
            ui_warn "Active version of [$regref name] is not $portversion but [$regref version]_[$regref revision]"
        }
        set files [$regref files]
        if {$files != 0 && [llength $files] > 0} {
            set seen_ino [dict create]
            foreach file $files {
                catch {
                    file lstat $file statinfo
                    if {$statinfo(nlink) == 1 || ![dict exists $seen_ino $statinfo(ino)]} {
                        set space [expr {$space + $statinfo(size)}]
                    }
                    if {$statinfo(nlink) != 1} {
                        dict set seen_ino $statinfo(ino) 1
                    }
                }
            }
            if {![dict exists $options ports_space_total] || [dict get $options ports_space_total] ne "yes"} {
                set msg "[bytesize $space $units] $portname"
                if { $portversion ne {} } {
                    append msg " @[$regref version]_[$regref revision][$regref variants]"
                }
                puts $msg
            }
            set spaceall [expr {$space + $spaceall}]
        } else {
            puts stderr "Port $portname does not have any files registered."
        }
    }
    if {[llength $portlist] > 1 || ([dict exists $options ports_space_total] && [dict get $options ports_space_total] eq "yes")} {
        puts "[bytesize $spaceall $units] total"
    }
    return 0
}

proc action_variants { action portlist opts } {
    set status 0
    if {[require_portlist portlist]} {
        return 1
    }
    global global_variations
    set gvariations [dict create {*}[array get global_variations]]
    foreachport $portlist {
        set portinfo ""
        if {$porturl eq ""} {
            # look up port
            if {[catch {mportlookup $portname} result]} {
                ui_debug $::errorInfo
                break_softcontinue "lookup of portname $portname failed: $result" 1 status
            }
            if {[llength $result] < 2} {
                break_softcontinue "Port $portname not found" 1 status
            }

            lassign $result portname portinfo

            set porturl [dict get $portinfo porturl]
        }

        if {!([dict exists $options ports_variants_index] && [dict get $options ports_variants_index] eq "yes")} {
            # Add any global_variations to the variations specified for
            # the port (default variants may change based on this)
            set merged_variations [dict merge $gvariations $variations]
            if {![dict exists $options subport]} {
                dict set options subport $portname
            }
            if {[catch {set mport [mportopen $porturl $options $merged_variations]} result]} {
                ui_debug "$::errorInfo"
                break_softcontinue "Unable to open port: $result" 1 status
            }
            set portinfo [dict merge $portinfo [mportinfo $mport]]
            mportclose $mport
        } elseif {$portinfo eq ""} {
            ui_warn "port variants --index does not work with 'current' pseudo-port"
            continue
        }

        # set portname again since the one we were passed may not have had the correct case
        set portname [dict get $portinfo name]

        # if this fails the port doesn't have any variants
        if {![dict exists $portinfo variants]} {
            ui_notice "$portname has no variants"
        } else {
            # print out all the variants
            ui_notice "$portname has the variants:"
            foreach v [lsort [dict get $portinfo variants]] {
                unset -nocomplain vconflicts vdescription vrequires
                set varmodifier "   "
                # Retrieve variants' information from the new format.
                if {[dict exists $portinfo vinfo $v]} {
                    set variant [dict get $portinfo vinfo $v]

                    # Retrieve conflicts, description, is_default, and
                    # vrequires.
                    if {[dict exists $variant conflicts]} {
                        set vconflicts [dict get $variant conflicts]
                    }
                    if {[dict exists $variant description]} {
                        set vdescription [dict get $variant description]
                    }

                    # XXX Keep these varmodifiers in sync with action_info, or create a wrapper for it
                    if {[dict exists $variations $v]} {
                        set varmodifier "  [dict get $variations $v]"
                    } elseif {[dict exists $gvariations $v]} {
                        # selected by variants.conf, prefixed with (+)/(-)
                        set varmodifier "([dict get $gvariations $v])"
                    } elseif {[dict exists $variant is_default]} {
                        set varmodifier "\[[dict get $variant is_default]\]"
                    }
                    if {[dict exists $variant requires]} {
                        set vrequires [dict get $variant requires]
                    }
                }

                if {[info exists vdescription]} {
                    puts [wraplabel "$varmodifier$v" [string trim $vdescription] 0 [string repeat " " [expr {5 + [string length $v]}]]]
                } else {
                    puts "$varmodifier$v"
                }
                if {[info exists vconflicts]} {
                    puts "     * conflicts with [string trim $vconflicts]"
                }
                if {[info exists vrequires]} {
                    puts "     * requires [string trim $vrequires]"
                }
            }
        }
    }

    return $status
}


proc action_search { action portlist opts } {
    global global_options private_options
    if {![llength $portlist] && [info exists private_options(ports_no_args)] && $private_options(ports_no_args) eq "yes"} {
        ui_error "You must specify a search pattern"
        return 1
    }
    set status 0

    # Copy global options as we are going to modify the array
    set options [dict create {*}[array get global_options]]

    if {[dict exists $options ports_search_depends] && [dict get $options ports_search_depends] eq "yes"} {
        dict unset options ports_search_depends
        dict set options ports_search_depends_fetch yes
        dict set options ports_search_depends_extract yes
        dict set options ports_search_depends_patch yes
        dict set options ports_search_depends_build yes
        dict set options ports_search_depends_lib yes
        dict set options ports_search_depends_run yes
        dict set options ports_search_depends_test yes
    }

    # Dictionary to hold given filters
    set filters [dict create]
    # Default matchstyle
    set filter_matchstyle "none"
    set filter_case no
    foreach option [dict keys $options ports_search_*] {
        set opt [string range $option 13 end]

        if {[dict get $options $option] ne "yes"} {
            continue
        }
        switch -- $opt {
            exact -
            glob {
                set filter_matchstyle $opt
                continue
            }
            regex {
                set filter_matchstyle regexp
                continue
            }
            case-sensitive {
                set filter_case yes
                continue
            }
            line {
                continue
            }
        }

        dict set filters $opt yes
    }
    # Set default search filter if none was given
    if {[dict size $filters] == 0} {
        dict set filters name yes
        dict set filters description yes
    }

    set separator ""
    foreach portname $portlist {
        puts -nonewline $separator

        set searchstring $portname
        set matchstyle $filter_matchstyle
        if {$matchstyle eq "none"} {
            # Guess if the given string was a glob expression, if not do a substring search
            if {[string first "*" $portname] == -1 && [string first "?" $portname] == -1} {
                set searchstring "*$portname*"
            }
            set matchstyle glob
        }

        set res [list]
        set portfound 0
        foreach opt [dict keys $filters] {
            # Map from friendly name
            set opt [map_friendly_field_names $opt]

            if {[catch {set matches [mportsearch $searchstring $filter_case $matchstyle $opt]} result]} {
                ui_debug $::errorInfo
                break_softcontinue "search for name $portname failed: $result" 1 status
            }

            set tmp [list]
            foreach {name info} $matches {
                add_to_portlist_with_defaults tmp [dict create name $name {*}$info]
            }
            set res [portlist::opUnion $res $tmp]
        }
        set res [portlist_sort $res]

        set joiner ""
        foreach portinfo $res {
            # XXX is this the right place to verify an entry?
            if {![dict exists $portinfo name]} {
                puts stderr "Invalid port entry, missing portname"
                continue
            }
            set res_name [dict get $portinfo name]
            if {![dict exists $portinfo description]} {
                puts stderr "Invalid port entry for $res_name, missing description"
                continue
            }
            set res_description [dict get $portinfo description]
            if {![dict exists $portinfo version]} {
                puts stderr "Invalid port entry for $res_name, missing version"
                continue
            }
            set res_version [dict get $portinfo version]

            if {[macports::ui_isset ports_quiet]} {
                puts $res_name
            } else {
                if {[dict exists $options ports_search_line]
                        && [dict get $options ports_search_line] eq "yes"} {
                    # check for ports without category, e.g. replaced_by stubs
                    if {[dict exists $portinfo categories]} {
                        puts "${res_name}\t${res_version}\t[dict get $portinfo categories]\t$res_description"
                    } else {
                        # keep two consecutive tabs in order to provide consistent columns' content
                        puts "${res_name}\t${res_version}\t\t$res_description"
                    }
                } else {
                    puts -nonewline $joiner

                    puts -nonewline "$res_name @$res_version"
                    if {[dict exists $portinfo revision] && [dict get $portinfo revision] > 0} {
                        puts -nonewline "_[dict get $portinfo revision]"
                    }
                    if {[dict exists $portinfo categories]} {
                        puts -nonewline " ([join [dict get $portinfo categories] ", "])"
                    }
                    puts ""
                    puts [wrap [join $res_description] 0 [string repeat " " 4]]
                }
            }

            set joiner "\n"
            set portfound 1
        }
        if { !$portfound } {
            ui_notice "No match for $portname found"
        } elseif {[llength $res] > 1} {
            if {(![info exists global_options(ports_search_line)]
                    || $global_options(ports_search_line) ne "yes")} {
                ui_notice "\nFound [llength $res] ports."
            }
        }

        set separator "--\n"
    }

    return $status
}


proc action_list { action portlist opts } {
    global private_options
    set status 0

    # Default to list all ports if no portnames are supplied
    if {![llength $portlist] && [info exists private_options(ports_no_args)] && $private_options(ports_no_args) eq "yes"} {
        add_to_portlist_with_defaults portlist [dict create name "-all-"]
    }

    foreachport $portlist {
        if {$portname eq "-all-"} {
           if {[catch {set res [mportlistall]} result]} {
                ui_debug $::errorInfo
                break_softcontinue "listing all ports failed: $result" 1 status
            }
        } else {
            if {$portversion ne "" && ![info exists warned_for_version]} {
                ui_warn "The 'list' action only shows the currently available version of each port. To see installed versions, use the 'installed' action."
                set warned_for_version 1
            }
            set search_string [regex_pat_sanitize $portname]
            if {[catch {set res [mportsearch ^$search_string\$ no]} result]} {
                ui_debug $::errorInfo
                break_softcontinue "search for portname $search_string failed: $result" 1 status
            }
        }

        foreach {name portinfo} $res {
            set outdir ""
            if {[dict exists $portinfo portdir]} {
                set outdir [dict get $portinfo portdir]
            }
            puts [format "%-30s @%-14s %s" [dict get $portinfo name] [dict get $portinfo version] $outdir]
        }
    }

    return $status
}


proc action_echo { action portlist opts } {
    global global_options
    # Simply echo back the port specs given to this command
    set gopts [dict create {*}[array get global_options]]
    foreachport $portlist {
        if {![macports::ui_isset ports_quiet]} {
            set opts [list]
            dict for {key value} $options {
                if {![dict exists $gopts $key]} {
                    lappend opts "$key=$value"
                }
            }

            set composite_version [composite_version $portversion $variations 1]
            if { $composite_version ne "" } {
                set ver_field "@$composite_version"
            } else {
                set ver_field ""
            }
            puts [format "%-30s %s %s" $portname $ver_field  [join $opts " "]]
        } else {
            puts "$portname"
        }
    }

    return 0
}


proc action_portcmds { action portlist opts } {
    # Operations on the port's directory and Portfile

    set status 0
    if {[require_portlist portlist]} {
        return 1
    }
    foreachport $portlist {
        set portinfo ""
        # If we have a url, use that, since it's most specific, otherwise try to map the portname to a url
        if {$porturl eq ""} {

            # Verify the portname, getting portinfo to map to a porturl
            if {[catch {set res [mportlookup $portname]} result]} {
                ui_debug $::errorInfo
                break_softcontinue "lookup of portname $portname failed: $result" 1 status
            }
            if {[llength $res] < 2} {
                break_softcontinue "Port $portname not found" 1 status
            }
            lassign $res portname portinfo
            set porturl [dict get $portinfo porturl]
        }


        # Calculate portdir, porturl, and portfile from initial porturl
        set portdir [file normalize [macports::getportdir $porturl]]
        set porturl "file://${portdir}";    # Rebuild url so it's fully qualified
        set portfile "${portdir}/Portfile"

        # Now execute the specific action
        if {[file readable $portfile]} {
            switch -- $action {
                cat {
                    # Copy the portfile to standard output
                    set f [open $portfile RDONLY]
                    while { ![eof $f] } {
                        puts -nonewline [read $f 4096]
                    }
                    close $f
                }

                edit {
                    # Edit the port's portfile with the user's editor

                    # Restore our entire environment from start time.
                    # We need it to evaluate the editor, and the editor
                    # may want stuff from it as well, like TERM.
                    global env boot_env
                    set env_save [array get env]
                    array unset env *
                    array set env $boot_env

                    # Find an editor to edit the portfile
                    set editor ""
                    set editor_var "ports_${action}_editor"
                    if {[dict exists $opts $editor_var]} {
                        set editor [join [dict get $opts $editor_var]]
                    } else {
                        foreach ed { MP_EDITOR VISUAL EDITOR } {
                            if {[info exists env($ed)]} {
                                set editor $env($ed)
                                break
                            }
                        }
                    }

                    # Use a reasonable canned default if no editor specified or set in env
                    if { $editor eq "" } { set editor "/usr/bin/vi" }

                    # Invoke the editor
                    if {[catch {exec -ignorestderr >@stdout <@stdin {*}$editor $portfile} result]} {
                        ui_debug $::errorInfo
                        break_softcontinue "unable to invoke editor $editor: $result" 1 status
                    }

                    # Restore internal MacPorts environment
                    array unset env *
                    array set env $env_save
                }

                dir {
                    # output the path to the port's directory
                    puts $portdir
                }

                work {
                    # output the path to the port's work directory
                    set workpath [macports::getportworkpath_from_portdir $portdir $portname]
                    if {[file exists $workpath]} {
                        puts $workpath
                    }
                }

                cd {
                    # Change to the port's directory, making it the default
                    # port for any future commands
                    set ::current_portdir $portdir
                }

                url {
                    # output the url of the port's directory, suitable to feed back in later as a port descriptor
                    puts $porturl
                }

                file {
                    # output the path to the port's portfile
                    puts $portfile
                }

                logfile {
                    set logfile [file join [macports::getportlogpath $portdir $portname] "main.log"]
                    if {[file isfile $logfile]} {
                        puts $logfile
                    } else {
                        ui_error "Log file for port $portname not found"
                    }
                }

                gohome {
                    set homepage ""

                    # Get the homepage as read from PortIndex
                    if {[dict exists $portinfo homepage]} {
                        set homepage [dict get $portinfo homepage]
                    }

                    # If not available, get the homepage for the port by opening the Portfile
                    if {$homepage eq "" && ![catch {set ctx [mportopen $porturl]} result]} {
                        set portinfo [dict merge $portinfo [mportinfo $ctx]]
                        if {[dict exists $portinfo homepage]} {
                            set homepage [dict get $portinfo homepage]
                        }
                        mportclose $ctx
                    }

                    # Try to open a browser to the homepage for the given port
                    if { $homepage ne "" } {
                        if {[catch {system "${macports::autoconf::open_path} '$homepage'"} result]} {
                            ui_debug $::errorInfo
                            break_softcontinue "unable to invoke browser using ${macports::autoconf::open_path}: $result" 1 status
                        }
                    } else {
                        ui_error [format "No homepage for %s" $portname]
                    }
                }
            }
        } else {
            break_softcontinue "Could not read $portfile" 1 status
        }
    }

    return $status
}


proc action_sync { action portlist opts } {
    global global_options
    set status 0
    if {[catch {mportsync [array get global_options]} result]} {
        ui_debug $::errorInfo
        ui_msg "port sync failed: $result"
        set status 1
    }

    return $status
}


proc action_target { action portlist opts } {
    if {[require_portlist portlist]} {
        return 1
    }
    if {($action eq "install" || $action eq "archive") && ![macports::global_option_isset ports_dryrun] && [prefix_unwritable]} {
        return 1
    }
    set status 0
    global global_variations macports::ui_options
    set gvariations [dict create {*}[array get global_variations]]
    foreachport $portlist {
        set portinfo ""
        # If we have a url, use that, since it's most specific
        # otherwise try to map the portname to a url
        if {$porturl eq ""} {
            # Verify the portname, getting portinfo to map to a porturl
            if {[catch {set res [mportlookup $portname]} result]} {
                ui_debug $::errorInfo
                break_softcontinue "lookup of portname $portname failed: $result" 1 status
            }
            if {[llength $res] < 2} {
                # don't error for ports that are installed but not in the tree
                if {[registry::entry imaged $portname] ne ""} {
                    ui_warn "Skipping $portname (not in the ports tree)"
                    continue
                } else {
                    break_softcontinue "Port $portname not found" 1 status
                }
            }
            lassign $res portname portinfo
            set porturl [dict get $portinfo porturl]
        }

        # If version was specified, it can be a version glob for use
        # with the clean action. For other actions, error out if we're
        # being asked for a version we can't provide.
        if {[string length $portversion]} {
            if {$action eq "clean"} {
                dict set options ports_version_glob $portversion
            } elseif {[dict exists $portmetadata explicit_version] && [dict exists $portinfo version] \
                    && $portversion ne "[dict get $portinfo version]_[dict get $portinfo revision]" && $portversion ne [dict get $portinfo version]} {
                break_softcontinue "$portname version $portversion is not available (current version is [dict get $portinfo version]_[dict get $portinfo revision])" 1 status
            }
        }

        # use existing variants iff none were explicitly requested
        if {$requested_variations eq "" && $variations ne ""} {
            set requested_variations $variations
        }

        # Add any global_variations to the variations
        # specified for the port
        set requested_variations [dict merge $gvariations $requested_variations]

        if {$action eq "install"} {
            if {[dict exists $portinfo replaced_by] && ![dict exists $options ports_install_no-replace]} {
                ui_notice "$portname is replaced by [dict get $portinfo replaced_by]"
                set portname [dict get $portinfo replaced_by]
                if {[catch {mportlookup $portname} result]} {
                    ui_debug $::errorInfo
                    break_softcontinue "lookup of portname $portname failed: $result" 1 status
                } elseif {[llength $result] < 2} {
                    break_softcontinue "Port $portname not found" 1 status
                }
                lassign $result portname portinfo
                set porturl [dict get $portinfo porturl]
            }
            if {[dict exists $portinfo known_fail] && [string is true -strict [dict get $portinfo known_fail]]
                && ![dict exists $options ports_install_allow-failing]} {
                if {[info exists ui_options(questions_yesno)]} {
                    set retvalue [$ui_options(questions_yesno) "$portname is known to fail." "KnownFail" {} {n} 0 "Try to install anyway?"]
                    if {$retvalue != 0} {
                        break_softcontinue "$portname is known to fail" 1 status
                    }
                } else {
                    break_softcontinue "$portname is known to fail (use --allow-failing to try to install anyway)" 1 status
                }
            }
            if {[dict exists $options ports_install_allow-failing]} {
                dict set options ignore_known_fail 1
            }
            # mark the port as explicitly requested
            if {![dict exists $options ports_install_unrequested]} {
                dict set options ports_requested 1
            }
            # we actually activate as well
            set target activate
        } elseif {$action eq "archive"} {
            set target install
        } else {
            set target $action
        }
        if {![dict exists $options subport]} {
            dict set options subport $portname
        }
        if {[catch {set workername [mportopen $porturl $options $requested_variations]} result]} {
            ui_debug $::errorInfo
            break_softcontinue "Unable to open port $portname: $result" 1 status
        }
        if {[catch {mportexec $workername $target} result]} {
            ui_debug $::errorInfo
            mportclose $workername
            break_softcontinue "Unable to execute port $portname: $result" 1 status
        }

        mportclose $workername

        # Process any error that wasn't thrown and handled already
        if {$result} {
            print_tickets_url
            break_softcontinue "Processing of port $portname failed" 1 status
        }
    }

    if {$status == 0 && $action eq "install" && ![macports::global_option_isset ports_dryrun]} {
        global macports::revupgrade_autorun
        if {![dict exists $opts ports_nodeps] && ![dict exists $opts ports_install_no-rev-upgrade] && ${revupgrade_autorun}} {
            set status [action_revupgrade $action $portlist $opts]
        }
    }

    return $status
}


proc action_mirror { action portlist opts } {
    global macports::portdbpath
    # handle --new option here so we only delete the db once
    set mirror_filemap_path [file join $portdbpath distfiles_mirror.db]
    if {[dict exists $opts ports_mirror_new]
        && [string is true -strict [dict get $opts ports_mirror_new]]
        && [file exists $mirror_filemap_path]} {
            # Trash the map file if it existed.
            file delete -force $mirror_filemap_path
    }

    action_target $action $portlist $opts
}

proc action_exit { action portlist opts } {
    # Return a semaphore telling the main loop to quit
    return -1
}


##########################################
# Command Parsing
##########################################
proc moreargs {} {
    global cmd_argn cmd_argc
    return [expr {$cmd_argn < $cmd_argc}]
}


proc lookahead {} {
    global cmd_argn cmd_argc cmd_argv
    if {$cmd_argn < $cmd_argc} {
        return [lindex $cmd_argv $cmd_argn]
    } else {
        return _EOF_
    }
}


proc advance {} {
    global cmd_argn
    incr cmd_argn
}


proc match {s} {
    if {[lookahead] eq $s} {
        advance
        return 1
    }
    return 0
}

# action_array specifies which action to run on the given command
# and if the action wants an expanded portlist.
# The value is a list of the form {action expand},
# where action is a string and expand a value:
#   0 none        Does not expect any text argument
#   1 strings     Expects some strings as text argument
#   2 ports       Wants an expanded list of ports as text argument

# Define global constants
const ACTION_ARGS_NONE 0
const ACTION_ARGS_STRINGS 1
const ACTION_ARGS_PORTS 2

set action_array [dict create \
    usage       [list action_usage          [ACTION_ARGS_STRINGS]] \
    help        [list action_help           [ACTION_ARGS_STRINGS]] \
    \
    echo        [list action_echo           [ACTION_ARGS_PORTS]] \
    \
    info        [list action_info           [ACTION_ARGS_PORTS]] \
    location    [list action_location       [ACTION_ARGS_PORTS]] \
    notes       [list action_notes          [ACTION_ARGS_PORTS]] \
    provides    [list action_provides       [ACTION_ARGS_STRINGS]] \
    log         [list action_log            [ACTION_ARGS_PORTS]] \
    \
    activate    [list action_activate       [ACTION_ARGS_PORTS]] \
    deactivate  [list action_deactivate     [ACTION_ARGS_PORTS]] \
    \
    select      [list action_select         [ACTION_ARGS_STRINGS]] \
    \
    sync        [list action_sync           [ACTION_ARGS_NONE]] \
    selfupdate  [list action_selfupdate     [ACTION_ARGS_NONE]] \
    \
    setrequested   [list action_setrequested  [ACTION_ARGS_PORTS]] \
    unsetrequested [list action_setrequested  [ACTION_ARGS_PORTS]] \
    setunrequested [list action_setrequested  [ACTION_ARGS_PORTS]] \
    \
    upgrade     [list action_upgrade        [ACTION_ARGS_PORTS]] \
    rev-upgrade [list action_revupgrade     [ACTION_ARGS_NONE]] \
    reclaim     [list action_reclaim        [ACTION_ARGS_NONE]] \
    diagnose    [list action_diagnose       [ACTION_ARGS_NONE]] \
    \
    version     [list action_version        [ACTION_ARGS_NONE]] \
    platform    [list action_platform       [ACTION_ARGS_NONE]] \
    \
    uninstall   [list action_uninstall      [ACTION_ARGS_PORTS]] \
    \
    mirror      [list action_mirror         [ACTION_ARGS_PORTS]] \
    \
    installed   [list action_installed      [ACTION_ARGS_PORTS]] \
    outdated    [list action_outdated       [ACTION_ARGS_PORTS]] \
    contents    [list action_contents       [ACTION_ARGS_PORTS]] \
    space       [list action_space          [ACTION_ARGS_PORTS]] \
    dependents  [list action_dependents     [ACTION_ARGS_PORTS]] \
    rdependents [list action_dependents     [ACTION_ARGS_PORTS]] \
    deps        [list action_deps           [ACTION_ARGS_PORTS]] \
    rdeps       [list action_deps           [ACTION_ARGS_PORTS]] \
    variants    [list action_variants       [ACTION_ARGS_PORTS]] \
    \
    search      [list action_search         [ACTION_ARGS_STRINGS]] \
    list        [list action_list           [ACTION_ARGS_PORTS]] \
    \
    edit        [list action_portcmds       [ACTION_ARGS_PORTS]] \
    cat         [list action_portcmds       [ACTION_ARGS_PORTS]] \
    dir         [list action_portcmds       [ACTION_ARGS_PORTS]] \
    work        [list action_portcmds       [ACTION_ARGS_PORTS]] \
    cd          [list action_portcmds       [ACTION_ARGS_PORTS]] \
    url         [list action_portcmds       [ACTION_ARGS_PORTS]] \
    file        [list action_portcmds       [ACTION_ARGS_PORTS]] \
    logfile     [list action_portcmds       [ACTION_ARGS_PORTS]] \
    gohome      [list action_portcmds       [ACTION_ARGS_PORTS]] \
    \
    fetch       [list action_target         [ACTION_ARGS_PORTS]] \
    checksum    [list action_target         [ACTION_ARGS_PORTS]] \
    extract     [list action_target         [ACTION_ARGS_PORTS]] \
    patch       [list action_target         [ACTION_ARGS_PORTS]] \
    configure   [list action_target         [ACTION_ARGS_PORTS]] \
    build       [list action_target         [ACTION_ARGS_PORTS]] \
    destroot    [list action_target         [ACTION_ARGS_PORTS]] \
    install     [list action_target         [ACTION_ARGS_PORTS]] \
    clean       [list action_target         [ACTION_ARGS_PORTS]] \
    test        [list action_target         [ACTION_ARGS_PORTS]] \
    lint        [list action_target         [ACTION_ARGS_PORTS]] \
    livecheck   [list action_target         [ACTION_ARGS_PORTS]] \
    distcheck   [list action_target         [ACTION_ARGS_PORTS]] \
    bump        [list action_target         [ACTION_ARGS_PORTS]] \
    load        [list action_target         [ACTION_ARGS_PORTS]] \
    unload      [list action_target         [ACTION_ARGS_PORTS]] \
    reload      [list action_target         [ACTION_ARGS_PORTS]] \
    distfiles   [list action_target         [ACTION_ARGS_PORTS]] \
    \
    archivefetch [list action_target         [ACTION_ARGS_PORTS]] \
    archive     [list action_target         [ACTION_ARGS_PORTS]] \
    unarchive   [list action_target         [ACTION_ARGS_PORTS]] \
    dmg         [list action_target         [ACTION_ARGS_PORTS]] \
    mdmg        [list action_target         [ACTION_ARGS_PORTS]] \
    mpkg        [list action_target         [ACTION_ARGS_PORTS]] \
    pkg         [list action_target         [ACTION_ARGS_PORTS]] \
    \
    snapshot    [list action_snapshot       [ACTION_ARGS_STRINGS]] \
    restore     [list action_restore        [ACTION_ARGS_STRINGS]] \
    migrate     [list action_migrate        [ACTION_ARGS_STRINGS]] \
    \
    quit        [list action_exit           [ACTION_ARGS_NONE]] \
    exit        [list action_exit           [ACTION_ARGS_NONE]] \
]

# Actions which are only valid in shell mode
set shellmode_action_list [list cd exit quit]

# Expand "action".
# Returns a list of matching actions.
proc find_action { action } {
    global action_array action_list ui_options shellmode_action_list
    if {![dict exists $action_array $action]} {
        # list of actions that are valid for this mode
        if {![info exists action_list]} {
            if {![info exists ui_options(ports_commandfiles)]} {
                set action_list [lsearch -regexp -all -inline -not [dict keys $action_array] ^[join $shellmode_action_list {$|^}]$]
            } else {
                set action_list [dict keys $action_array]
            }
        }
        return [lsearch -glob -inline -all $action_list [string tolower $action]*]
    }

    return $action
}

proc get_action_proc { action } {
    global action_array
    set action_proc ""
    if {[dict exists $action_array $action]} {
        set action_proc [lindex [dict get $action_array $action] 0]
    }

    return $action_proc
}

# Returns whether an action expects text arguments at all,
# expects text arguments or wants an expanded list of ports
# Return values are constants:
#   [ACTION_ARGS_NONE]     Does not expect any text argument
#   [ACTION_ARGS_STRINGS]  Expects some strings as text argument
#   [ACTION_ARGS_PORTS]    Wants an expanded list of ports as text argument
proc action_needs_portlist { action } {
    global action_array
    set ret 0
    if {[dict exists $action_array $action]} {
        set ret [lindex [dict get $action_array $action] 1]
    }

    return $ret
}

# cmd_opts_array specifies which arguments the commands accept
# Commands not listed here do not accept any arguments
# Syntax is {option argn}
# Where option is the name of the option and argn specifies how many arguments
# this argument takes
set cmd_opts_array [dict create {*}{
    edit        {{editor 1}}
    info        {category categories conflicts depends_fetch depends_extract
                 depends_patch
                 depends_build depends_lib depends_run depends_test
                 depends description epoch fullname heading homepage index license
                 line long_description
                 maintainer maintainers name patchfiles platform platforms portdir
                 pretty replaced_by revision subports variant variants version}
    contents    {size {units 1}}
    deps        {index no-build no-test}
    rdeps       {index no-build no-test full}
    rdependents {full}
    search      {case-sensitive category categories depends_fetch
                 depends_extract depends_patch
                 depends_build depends_lib depends_run depends_test
                 depends description epoch exact glob homepage line
                 long_description maintainer maintainers name platform
                 platforms portdir regex revision variant variants version}
    selfupdate  {migrate no-sync nosync rsync}
    space       {{units 1} total}
    activate    {no-exec}
    deactivate  {no-exec}
    install     {allow-failing no-replace no-rev-upgrade unrequested}
    uninstall   {follow-dependents follow-dependencies no-exec}
    variants    {index}
    clean       {all archive dist work logs}
    mirror      {new}
    lint        {nitpick}
    select      {list set show summary}
    log         {{phase 1} {level 1}}
    upgrade     {force enforce-variants no-replace no-rev-upgrade}
    rev-upgrade {id-loadcmd-check}
    diagnose    {quiet}
    reclaim     {enable-reminders disable-reminders}
    fetch       {no-mirrors}
    bump        {patch}
    snapshot    {create list {diff 1} all {delete 1} help {note 1}}
    restore     {{snapshot-id 1} all last}
    migrate     {continue all}
}]

##
# Checks whether the given option is valid
#
# @param action for which action
# @param option the prefix of the option to check
# @return list of pairs {name argc} for all matching options
proc cmd_option_matches {action option} {
    # This could be so easy with lsearch -index,
    # but that's only available as of Tcl 8.5

    global cmd_opts_array
    if {![dict exists $cmd_opts_array $action]} {
        return [list]
    }

    set result [list]

    foreach item [dict get $cmd_opts_array $action] {
        if {[llength $item] == 1} {
            set name $item
            set argc 0
        } else {
            set name [lindex $item 0]
            set argc [lindex $item 1]
        }

        if {$name eq $option} {
            set result [list [list $name $argc]]
            break
        } elseif {[string first $option $name] == 0} {
            lappend result [list $name $argc]
        }
    }

    return $result
}

# Parse global options
#
# Note that this is called several times:
#   (1) Initially, to parse options that will be constant across all commands
#       (options that come prior to any command, frozen into global_options_base)
#   (2) Following each command (to parse options that will be unique to that command
#       (the global_options array is reset to global_options_base prior to each command)
#
proc parse_options { action ui_options_name global_options_name } {
    upvar $ui_options_name ui_options
    upvar $global_options_name global_options

    set options_order(${action}) {}

    while {[moreargs]} {
        set arg [lookahead]

        if {[string index $arg 0] ne "-"} {
            break
        } elseif {[string index $arg 1] eq "-"} {
            # Process long arguments
            switch -- $arg {
                -- { # This is the options terminator; do no further option processing
                    advance; break
                }
                default {
                    set key [string range $arg 2 end]
                    set kopts [cmd_option_matches $action $key]
                    if {[llength $kopts] == 0} {
                        return -code error "${action} does not accept --${key}"
                    } elseif {[llength $kopts] > 1} {
                        set errlst [list]
                        foreach e $kopts {
                            lappend errlst "--[lindex $e 0]"
                        }
                        return -code error "\"port ${action} --${key}\" is ambiguous: \n  port ${action} [join $errlst "\n  port ${action} "]"
                    }
                    set key   [lindex $kopts 0 0]
                    set kargc [lindex $kopts 0 1]
                    if {$kargc == 0} {
                        set global_options(ports_${action}_${key}) yes
                        lappend options_order(${action}) ports_${action}_${key}
                    } else {
                        set args [list]
                        while {[moreargs] && $kargc > 0} {
                            advance
                            lappend args [lookahead]
                            set kargc [expr {$kargc - 1}]
                        }
                        if {$kargc > 0} {
                            return -code error "--${key} expects [expr {$kargc + [llength $args]}] parameters!"
                        }
                        set global_options(ports_${action}_${key}) $args
                    }
                }
            }
        } else {
            # Process short arg(s)
            set opts [string range $arg 1 end]
            foreach c [split $opts {}] {
                switch -- $c {
                    v {
                        set ui_options(ports_verbose) yes
                    }
                    d {
                        set ui_options(ports_debug) yes
                        # debug implies verbose
                        set ui_options(ports_verbose) yes
                    }
                    q {
                        set ui_options(ports_quiet) yes
                        # quiet implies noninteractive
                        set ui_options(ports_noninteractive) yes
                        # quiet implies no warning for outdated PortIndex
                        set ui_options(ports_no_old_index_warning) 1
                    }
                    p {
                        # Ignore errors while processing within a command
                        set ui_options(ports_processall) yes
                    }
                    N {
                        # Interactive mode is available or not
                        set ui_options(ports_noninteractive) yes
                    }
                    f {
                        set global_options(ports_force) yes
                    }
                    o {
                        set global_options(ports_ignore_different) yes
                    }
                    n {
                        set global_options(ports_nodeps) yes
                    }
                    u {
                        set global_options(port_uninstall_old) yes
                    }
                    R {
                        set global_options(ports_do_dependents) yes
                    }
                    s {
                        set global_options(ports_source_only) yes
                    }
                    b {
                        set global_options(ports_binary_only) yes
                    }
                    c {
                        set global_options(ports_autoclean) yes
                    }
                    k {
                        set global_options(ports_autoclean) no
                    }
                    t {
                        set global_options(ports_trace) yes
                    }
                    y {
                        set global_options(ports_dryrun) yes
                    }
                    F {
                        # Name a command file to process
                        advance
                        if {[moreargs]} {
                            lappend ui_options(ports_commandfiles) [lookahead]
                        }
                    }
                    D {
                        advance
                        if {[moreargs]} {
                            set global_options(ports_dir) [lookahead]
                        }
                        break
                    }
                    default {
                        print_usage; exit 1
                    }
                }
            }
        }

        advance
    }
    set global_options(options_${action}_order) $options_order(${action})
}

# acquire exclusive registry lock for actions that need it
# returns 1 if locked, 0 otherwise
proc lock_reg_if_needed {action} {
    switch -- $action {
        activate -
        deactivate -
        setrequested -
        unsetrequested -
        setunrequested -
        upgrade -
        uninstall -
        install {
            registry::exclusive_lock
            return 1
        }
    }
    return 0
}

proc process_cmd { argv } {
    global cmd_argc cmd_argv cmd_argn \
           global_options global_options_base private_options \
           ui_options ui_options_base \
           mp_global_options_base mp_ui_options_base \
           current_portdir
    set cmd_argv $argv
    set cmd_argc [llength $argv]
    set cmd_argn 0

    set action_status 0

    # Process an action if there is one
    while {($action_status == 0 || [macports::ui_isset ports_processall]) && [moreargs]} {
        set action [lookahead]
        advance

        # Handle command separator
        if { $action eq ";" } {
            continue
        }

        # Handle a comment
        if { [string index $action 0] eq "#" } {
            while { [moreargs] } { advance }
            break
        }

        try {
            set locked [lock_reg_if_needed $action]
        } trap {POSIX SIG SIGINT} {} {
            set action_status 1
            break
        } trap {POSIX SIG SIGTERM} {} {
            set action_status 1
            break
        }
        # Always start out processing an action in current_portdir
        cd $current_portdir

        # Reset global_options from base before each action, as we munge it just below...
        array unset global_options
        array set global_options $global_options_base
        array unset ui_options
        array set ui_options $ui_options_base

        # Find an action to execute
        set actions [find_action $action]
        if {[llength $actions] == 1} {
            set action [lindex $actions 0]
            set action_proc [get_action_proc $action]
        } else {
            if {[llength $actions] > 1} {
                ui_error "\"port ${action}\" is ambiguous: \n  port [join $actions "\n  port "]"
            } else {
                ui_error "Unrecognized action \"port $action\""
            }
            set action_status 1
            break
        }

        # Parse options that will be unique to this action
        # (to avoid ambiguity with -variants and a default port, either -- must be
        # used to terminate option processing, or the pseudo-port current must be specified).
        if {[catch {parse_options $action ui_options global_options} result]} {
            ui_debug $::errorInfo
            ui_error $result
            set action_status 1
            break
        }

        # Merge new options into the macports API options
        array unset mp_global_options
        array set mp_global_options $mp_global_options_base
        array set mp_global_options [array get global_options]
        macports::set_global_options [array get mp_global_options]

        array unset mp_ui_options
        array set mp_ui_options $mp_ui_options_base
        array set mp_ui_options [array get ui_options]
        macports::set_ui_options [array get mp_ui_options]

        # Some options could change verbosity, so re-init ui channels
        macports::ui_init_all

        # What kind of arguments does the command expect?
        set expand [action_needs_portlist $action]

        # (Re-)initialize private_options(ports_no_args) to no, because it might still be yes
        # from the last command in batch mode. If we don't do this, port will fail to
        # distinguish arguments that expand to empty lists from no arguments at all:
        # > installed
        # > list outdated
        # will then behave like
        # > list
        # if outdated expands to the empty list. See #44091, which was filed about this.
        set private_options(ports_no_args) "no"

        # Parse action arguments, setting a special flag if there were none
        # We otherwise can't tell the difference between arguments that evaluate
        # to the empty set, and the empty set itself.
        set portlist [list]
        switch -- [lookahead] {
            ;       -
            _EOF_ {
                set private_options(ports_no_args) "yes"
            }
            default {
                if {[ACTION_ARGS_NONE] == $expand} {
                    ui_error "$action does not accept string arguments"
                    set action_status 1
                    break
                } elseif {[ACTION_ARGS_STRINGS] == $expand} {
                    while { [moreargs] && ![match ";"] } {
                        lappend portlist [lookahead]
                        advance
                    }
                } elseif {[ACTION_ARGS_PORTS] == $expand} {
                    # Parse port specifications into portlist
                    if {![portExpr portlist]} {
                        ui_error "Improper expression syntax while processing parameters"
                        set action_status 1
                        break
                    }
                }
            }
        }

        # execute the action
        set action_status [$action_proc $action $portlist [array get global_options]]

        # unlock if needed
        if {$locked} {
            registry::exclusive_unlock
        }

        # Print notifications of just-activated ports.
        portclient::notifications::display

        # semaphore to exit
        if {$action_status < 0} break
    }

    return $action_status
}


proc complete_portname { text state } {
	global complete_position complete_choices
    if {$state == 0} {
        set complete_position 0
        set complete_choices [list]

        # Build a list of ports with text as their prefix
        if {[catch {set res [mportsearch "${text}*" false glob]} result]} {
            ui_debug $::errorInfo
            fatal "search for portname $text failed: $result"
        }
        foreach {name info} $res {
            lappend complete_choices $name
        }
    }

    set word [lindex $complete_choices $complete_position]
    incr complete_position

    return $word
}


# return text action beginning with $text
proc complete_action { text state } {
    global complete_position complete_choices action_array
    if {$state == 0} {
        set complete_position 0
        set complete_choices [dict keys $action_array [string tolower $text]*]
    }

    set word [lindex $complete_choices $complete_position]
    incr complete_position

    return $word
}

proc attempt_completion { text word start end } {
    # If the word starts with '~', or contains '.' or '/', then use the built-in
    # completion to complete the word
    if { [regexp {^~|[/.]} $word] } {
        return ""
    }

    # Decide how to do completion based on where we are in the string
    set prefix [string range $text 0 [expr {$start - 1}]]

    # If only whitespace characters precede us, or if the
    # previous non-whitespace character was a ;, then we're
    # an action (the first word of a command)
    if { [regexp {(^\s*$)|(;\s*$)} $prefix] } {
        return complete_action
    }

    # Otherwise, do completion on portname
    return complete_portname
}


proc get_next_cmdline { in out use_readline prompt linename history_file } {
    upvar $linename line
    global macports::macports_user_dir

    set line ""
    while { $line eq "" } {
        # Don't restart syscalls interrupted by signals while potentially
        # blocking on user input. Unfortunately, readline seems to try
        # again when syscalls fail with EINTR, so ctrl-c will not
        # actually raise an error until after the line is read.
        signal error {TERM INT}
        if {$use_readline} {
            set len [readline read -attempted_completion attempt_completion line $prompt]
        } else {
            puts -nonewline $out $prompt
            flush $out
            set len [gets $in line]
        }
        # Re-enable syscall restarting
        signal -restart error {TERM INT}
        if { $len < 0 } {
            return -1
        }

        set line [string trim $line]

        if { $use_readline && $line ne "" } {
            # Create macports user directory if it does not exist yet
            if {![file isdirectory $macports_user_dir]} {
                file mkdir $macports_user_dir

                # Also write the history file if this is the case (this sets
                # the cookie at the top of the file and perhaps other things)
                rl_history write $history_file
            }

            # Add history item to memory...
            rl_history add $line
            # ... and then append that item to the history file
            rl_history append $history_file
        }
    }

    return [llength $line]
}


proc process_command_file { in } {
    global current_portdir macports::macports_user_dir

    # Initialize readline
    set isstdin [expr {$in eq "stdin"}]
    set use_readline [expr {$isstdin && [readline init "port"]}]
    set history_file [file normalize ${macports_user_dir}/history]

    # Read readline history
    if {$use_readline && [file isdirectory $macports_user_dir]} {
        rl_history read $history_file
        rl_history stifle 100
    }

    # Be noisy, if appropriate
    set noisy [expr {$isstdin && ![macports::ui_isset ports_quiet]}]
    if { $noisy } {
        puts "MacPorts [macports::version]"
        puts "Entering shell mode... (\"help\" for help, \"quit\" to quit)"
    }

    # Main command loop
    set exit_status 0
    while { $exit_status == 0 || $isstdin || [macports::ui_isset ports_processall] } {

        # Calculate our prompt
        if { $noisy } {
            set shortdir [file join {*}[lrange [file split $current_portdir] end-1 end]]
            set prompt "\[$shortdir\] > "
        } else {
            set prompt ""
        }

        # Get a command line
        if { [get_next_cmdline $in stdout $use_readline $prompt line $history_file] <= 0  } {
            puts ""
            break
        }

        # Process the command
        set exit_status [process_cmd $line]

        # Check for semaphore to exit
        if {$exit_status < 0} {
            break
        }
    }

    # Say goodbye
    if { $noisy } {
        puts "Goodbye"
    }

    return $exit_status
}


proc process_command_files { filelist } {
    set exit_status 0

    # For each file in the command list, process commands
    # in the file
    foreach file $filelist {
        if {$file eq "-"} {
            set in stdin
        } else {
            if {[catch {set in [open $file]} result]} {
                fatal "Failed to open command file; $result"
            }
        }

        set exit_status [process_command_file $in]

        if {$in ne "stdin"} {
            close $in
        }

        # Exit on first failure unless -p was given. -999 overrides and always exits immediately.
        if {($exit_status != 0 && ![macports::ui_isset ports_processall]) || $exit_status == -999} {
            return $exit_status
        }
    }

    return $exit_status
}

namespace eval portclient::progress {
    ##
    # Maximum width of the progress bar or indicator when displaying it.
    variable maxWidth 50

    ##
    # The start time of the last progress callback as returned by [clock time].
    # Since only one progress indicator is active at a time, this variable is
    # shared between the different variants of progress functions.
    variable startTime

    ##
    # Delay in milliseconds after the start of the operation before deciding
    # that showing a progress bar makes sense.
    variable showTimeThreshold 500

    ##
    # Percentage value between 0 and 1 that must not have been reached yet when
    # $showTimeThreshold has passed for a progress bar to be shown. If the
    # operation has proceeded above e.g. 75% after 500ms we won't bother
    # displaying a progress indicator anymore -- the operation will be finished
    # in well below a second anyway.
    variable showPercentageThreshold 0.75

    ##
    # Boolean indication whether the progress indicator should be shown or is
    # still hidden because the current operation didn't need enough time for
    # a progress indicator to make sense, yet.
    variable show no

    ##
    # Initialize the progress bar display delay; call this from the start
    # action of the progress functions.
    proc initDelay {} {
        variable show
        variable startTime

        set startTime [clock milliseconds]
        set show no
    }

    ##
    # Determine whether a progress bar should be shown for the current
    # operation in its current state. You must have called initDelay for the
    # current operation before calling this method.
    #
    # @param cur
    #        Current progress in abstract units.
    # @param total
    #        Total number of abstract units to be processed, if known. Pass
    #        0 if unknown.
    # @return
    #        "yes", if the progress indicator should be shown, "no" otherwise.
    proc showProgress {cur total} {
        variable show
        variable startTime
        variable showTimeThreshold
        variable showPercentageThreshold

        if {![info exists startTime]} {
            # update called without start; normally that's an error, but let's
            # be liberal in what we accept and make the start implicit.
            initDelay
        }

        if {$show eq "yes"} {
            return yes
        } else {
            if {[expr {[clock milliseconds] - $startTime}] > $showTimeThreshold &&
                ($total == 0 || [expr {double($cur) / double($total)}] < $showPercentageThreshold)} {
                set show yes
            }
            return $show
        }
    }

    proc barWidth {reservedCols} {
        global env
        variable maxWidth

        if {![info exists env(COLUMNS)]} {
            return $maxWidth
        }

        if {$reservedCols > $env(COLUMNS)} {
            return [expr {min($maxWidth, $env(COLUMNS)}]
        } else {
            return [expr {min($maxWidth, $env(COLUMNS) - $reservedCols)}]
        }
    }

    ##
    # Progress callback for generic operations executed by macports 1.0.
    #
    # @param action
    #        One of "start", "update", "intermission" or "finish", where start
    #        will be called before any number of update calls, interrupted by
    #        any number of intermission calls (called because other output is
    #        being produced), followed by one call to finish.
    # @param args
    #        A list of variadic args that differ for each action. For "start",
    #        "intermission" and "finish", the args are empty and unused. For
    #        "update", args contains $cur and $total, where $cur is the current
    #        number of units processed and $total is the total number of units
    #        to be processed. If the total is not known, it is 0.
    proc generic {action args} {
        variable maxWidth

        switch -nocase -- $action {
            start {
                initDelay
            }
            update {
                lassign $args now total
                if {[showProgress $now $total] eq "yes"} {
                    set barPrefix "      "
                    set barPrefixLen [string length $barPrefix]
                    if {$total != 0} {
                        progressbar $now $total [barWidth $barPrefixLen] $barPrefix
                    } else {
                        unprogressbar [barWidth $barPrefixLen] $barPrefix
                    }
                }
            }
            intermission -
            finish {
                # erase to start of line
                ::term::ansi::send::esol
                # return cursor to start of line
                puts -nonewline "\r"
                flush stdout
            }
        }

        return 0
    }

    ##
    # Progress callback for downloads executed by macports 1.0.
    #
    # This is essentially a curl progress callback.
    #
    # @param action
    #        One of "start", "update" or "finish", where start will be called
    #        before any number of update calls, followed by one call to finish.
    # @param args
    #        A list of variadic args that differ for each action. For "start",
    #        contains a single argument "ul" or "dl" indicating whether this is
    #        an up- or download. For "update", contains the arguments
    #        ("ul"|"dl") $total $now $speed where ul/dl are as for start, and
    #        total, now and speed are doubles indicating the total transfer
    #        size, currently transferred amount and average speed per second in
    #        bytes. Unused for "finish".
    proc download {action args} {
        variable maxWidth

        switch -nocase -- $action {
            start {
                initDelay
            }
            update {
                lassign $args type total now speed
                if {[showProgress $now $total] eq "yes"} {
                    set barPrefix "      "
                    set barPrefixLen [string length $barPrefix]
                    if {$total != 0} {
                        set barSuffix [format "        speed: %-13s" "[bytesize $speed {} "%.1f"]/s"]
                        set barSuffixLen [string length $barSuffix]
                        set barWidth [barWidth [expr {$barPrefixLen + $barSuffixLen}]]

                        progressbar $now $total $barWidth $barPrefix $barSuffix
                    } else {
                        set barSuffix [format " %-10s     speed: %-13s" [bytesize $now {} "%6.1f"] "[bytesize $speed {} "%.1f"]/s"]
                        set barSuffixLen [string length $barSuffix]
                        set barWidth [barWidth [expr {$barPrefixLen + $barSuffixLen}]]

                        unprogressbar $barWidth $barPrefix $barSuffix
                    }
                }
            }
            finish {
                # erase to start of line
                ::term::ansi::send::esol
                # return cursor to start of line
                puts -nonewline "\r"
                flush stdout
            }
        }

        return 0
    }

    ##
    # Draw a progress bar using unicode block drawing characters
    #
    # @param current
    #        The current progress value.
    # @param total
    #        The progress value representing 100%.
    # @param width
    #        The width in characters of the progress bar. This includes percentage
    #        output, which takes up 8 characters.
    # @param prefix
    #        Prefix to be printed in front of the progress bar.
    # @param suffix
    #        Suffix to be printed after the progress bar.
    proc progressbar {current total width {prefix ""} {suffix ""}} {
        # Subtract the width of the percentage output, also subtract the two
        # characters [ and ] bounding the progress bar.
        set percentageWidth 8
        set barWidth      [expr {entier($width) - $percentageWidth - 2}]

        # Map the range (0, $total) to (0, 4 * $width) where $width is the maximum
        # number of characters to be printed for the progress bar. Multiply the
        # upper bound with 8 because we have 8 sub-states per character.
        set barProgress   [expr {entier(round(($current * $barWidth * 8) / $total))}]

        set barInteger    [expr {$barProgress / 8}]
        #set barRemainder  [expr {$barProgress % 8}]

        # Finally, also provide a percentage value to print behind the progress bar
        set percentage [expr {double($current) * 100 / double($total)}]

        # clear the current line, enable reverse video
        set progressbar "\033\[7m"
        for {set i 0} {$i < $barInteger} {incr i} {
            # U+2588 FULL BLOCK doesn't match the other blocks in some fonts :/
            # Two half blocks work better in some fonts, but not in others (because
            # they leave ugly spaces). So, one or the other choice isn't better or
            # worse and even just using full blocks looks ugly in a few fonts.

            # Use pure ASCII until somebody fixes most of the default terminal fonts :/
            append progressbar " "
        }
        # back to normal output
        append progressbar "\033\[0m"

        #switch $barRemainder {
        #    0 {
        #        if {$barInteger < $barWidth} {
        #            append progressbar " "
        #        }
        #    }
        #    1 {
        #        # U+258F LEFT ONE EIGHTH BLOCK
        #        append progressbar "\u258f"
        #    }
        #    2 {
        #        # U+258E LEFT ONE QUARTER BLOCK
        #        append progressbar "\u258e"
        #    }
        #    3 {
        #        # U+258D LEFT THREE EIGHTHS BLOCK
        #        append progressbar "\u258d"
        #    }
        #    3 {
        #        # U+258D LEFT THREE EIGHTHS BLOCK
        #        append progressbar "\u258d"
        #    }
        #    4 {
        #        # U+258C LEFT HALF BLOCK
        #        append progressbar "\u258c"
        #    }
        #    5 {
        #        # U+258B LEFT FIVE EIGHTHS BLOCK
        #        append progressbar "\u258b"
        #    }
        #    6 {
        #        # U+258A LEFT THREE QUARTERS BLOCK
        #        append progressbar "\u258a"
        #    }
        #    7 {
        #        # U+2589 LEFT SEVEN EIGHTHS BLOCK
        #        append progressbar "\u2589"
        #    }
        #}

        # Fill the progress bar with spaces
        for {set i $barInteger} {$i < $barWidth} {incr i} {
            append progressbar " "
        }

        # Format the percentage using the space that has been reserved for it
        set percentagesuffix [format " %[expr {$percentageWidth - 3}].1f %%" $percentage]

        puts -nonewline "\r${prefix}\[${progressbar}\]${percentagesuffix}${suffix}"
        flush stdout
    }


    ##
    # Internal state of the progress indicator; unless you're hacking the
    # unprogressbar code you should never touch this.
    variable unprogressState 0

    ##
    # Draw a progress indicator
    #
    # @param width
    #        The width in characters of the progress indicator.
    # @param prefix
    #        Prefix to be printed in front of the progress indicator.
    # @param suffix
    #        Suffix to be printed after the progress indicator.
    proc unprogressbar {width {prefix ""} {suffix ""}} {
        variable unprogressState

        # Subtract the two characters [ and ] bounding the progress indicator
        # from the width.
        set barWidth [expr {int($width) - 2}]

        # Number of states of the progress bar, or rather: the number of
        # characters before the sequence repeats.
        set numStates 4

        set unprogressState [expr {($unprogressState + 1) % $numStates}]

        set progressbar ""
        for {set i 0} {$i < $barWidth} {incr i} {
            if {[expr {$i % $numStates}] == $unprogressState} {
                # U+2022 BULLET
                append progressbar "\u2022"
            } else {
                append progressbar " "
            }
        }

        puts -nonewline "\r${prefix}\[${progressbar}\]${suffix}"
        flush stdout
    }
}

namespace eval portclient::notifications {
    ##
    # Ports whose notifications to display; these were either installed
    # or requested to be installed.
    variable notificationsToPrint [dict create]

    ##
    # Notifications issues by the MacPorts ports system
    variable systemNotifications
    set systemNotifications {}

    ##
    # Add a port to the list for printing notifications.
    #
    # @param name
    #        The name of the port.
    # @param note
    #        A list of notes to be stored for the given port.
    proc append {name notes} {
        variable notificationsToPrint

        dict set notificationsToPrint $name $notes
    }

    ##
    # Add a system notification to print later.
    #
    # @param note
    #        A note to store and display later.
    proc system_append {note} {
        variable systemNotifications

        lappend systemNotifications $note
    }

    ##
    # Print port notifications.
    #
    proc display {} {
        variable notificationsToPrint
        variable systemNotifications

        # Display notes at the end of the activation phase.
        if {[dict size $notificationsToPrint] > 0} {
            ui_notice "--->  Some of the ports you installed have notes:"
            foreach name [lsort [dict keys $notificationsToPrint]] {
                ui_notice "  $name has the following notes:"

                foreach note [dict get $notificationsToPrint $name] {
                    ui_notice [wrap $note 0 "    "]
                }

                # Clear notes that have been displayed
                dict unset notificationsToPrint $name
            }
        }

        if {[llength $systemNotifications] > 0} {
            ui_notice "--->  Note:"
            while {[llength $systemNotifications] > 0} {
                set systemNotifications [lassign $systemNotifications note]
                ui_notice [wrap $note 0 "    "]

                if {[llength $systemNotifications] > 0} {
                    ui_notice {}
                    ui_notice "---"
                    ui_notice {}
                }
            }
        }
    }
}

# Create namespace for questions
namespace eval portclient::questions {

    package require Tclx
    ##
    # Function that handles printing of a timeout.
    #
    # @param time
    #        The amount of time for which a timeout is to occur.
    # @param def
    #        The default action to be taken in the occurrence of a timeout.
    proc ui_timeout {def timeout} {
        fconfigure stdin -blocking 0

        signal error {TERM INT}
        while {$timeout >= 0} {
            try {
                set inp [read stdin]
            } on error {_ eOptions} {
                # An error occurred, print a newline so the error message
                # doesn't occur on the prompt line and re-throw
                puts ""
                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
            }
            if {$inp eq "\n"} {
                return $def
            }
            puts -nonewline "\r"
            puts -nonewline [format "Continuing in %02d s. Press Ctrl-C to exit: " $timeout]
            flush stdout
            after 1000
            incr timeout -1
        }
        puts ""
        fconfigure stdin -blocking 1
        signal -restart error {TERM INT}
        return $def
    }

    ##
    # Main function that displays numbered choices for a multiple choice question.
    #
    # @param msg
    #        The question specific message that is to be printed before asking the question.
    # @param ???name???
    #        May be a qid will be of better use instead as the client does not do anything port specific.
    # @param ports
    #        The list of ports for which the question is being asked.
    proc ui_choice {msg name ports} {
        # Print the main message
        puts $msg

        # Find maximum number length
        set maxlen [string length [llength $ports]]

        # Print portname or port list suitably
        set i 1
        foreach port $ports {
            puts [format " %*d) %s" $maxlen $i $port]
            incr i
        }
    }

    ##
    # Displays a question with 'yes' and 'no' as options.
    # Waits for user input indefinitely unless a timeout is specified.
    # Shows the list of port passed to it without any numbers.
    #
    # @param msg
    #        The question specific message that is to be printed before asking the question.
    # @param ???name???
    #        May be a qid will be of better use instead as the client does not do anything port specific.
    # @param ports
    #        The port/list of ports for which the question is being asked.
    # @param def
    #        The default answer to the question.
    # @param timeout
    #          The amount of time for which a timeout is to occur.
    # @param question
    #        Custom question message. Defaults to "Continue?".
    proc ui_ask_yesno {msg name ports def {timeout 0} {question "Continue?"}} {
        # Set number default to the given letter default
        if {$def eq "y"} {
            set default 0
        } else {
            set default 1
        }

        puts -nonewline $msg
        set leftmargin " "

        # Print portname or port list suitably
        if {[llength $ports] == 1} {
            puts -nonewline " "
            puts [string map {@ " @"} [lindex $ports 0]]
        } elseif {[llength $ports] == 0} {
            puts -nonewline " "
        } else {
            puts ""
            foreach port $ports {
                puts -nonewline $leftmargin
                puts [string map {@ " @"} $port]
            }
        }

        # Check if timeout is set or not
        if {$timeout > 0} {
            # Run ui_timeout and skip the rest of the stuff here
            return [ui_timeout $default $timeout]
        }

        # Check for the default and print accordingly
        if {$def eq "y"} {
            puts -nonewline "${question} \[Y/n\]: "
            flush stdout
        } else {
            puts -nonewline "${question} \[y/N\]: "
            flush stdout
        }

        # User input (probably requires some input error checking code)
        while 1 {
            signal error {TERM INT}
            try {
                set input [gets stdin]
            } on error {_ eOptions} {
                # An error occurred, print a newline so the error message
                # doesn't occur on the prompt line and re-throw
                puts ""
                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
            }
            signal -restart error {TERM INT}
            if {$input in {y Y}} {
                return 0
            } elseif {$input in {n N}} {
                return 1
            } elseif {$input eq ""} {
                return $default
            } else {
                puts "Please enter either 'y' or 'n'."
            }
        }
    }

    ##
    # Displays a question with a list of numbered choices and asks the user to enter a number to specify their choice.
    # Waits for user input indefinitely.
    #
    # @param msg
    #        The question specific message that is to be printed before asking the question.
    # @param ???name???
    #        May be a qid will be of better use instead as the client does not do anything port specific.
    # @param ports
    #        The port/list of ports for which the question is being asked.
    proc ui_ask_singlechoice {msg name ports} {
        ui_choice $msg $name $ports

        # User Input (single input restriction)
        while 1 {
            puts -nonewline "Enter a number to select an option: "
            flush stdout
            signal error {TERM INT}
            try {
                set input [gets stdin]
            } on error {_ eOptions} {
                # An error occurred, print a newline so the error message
                # doesn't occur on the prompt line and re-throw
                puts ""
                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
            }
            signal -restart error {TERM INT}
            if {[string is wideinteger -strict $input] && $input <= [llength $ports] && $input > 0} {
                return [expr {$input - 1}]
            } else {
                puts "Please enter an index from the above list."
            }
        }
    }

    ##
    # Displays a question with a list of numbered choices and asks the user to enter a space separated string of numbers to specify their choice.
    # Waits for user input indefinitely.
    #
    # @param msg
    #        The question specific message that is to be printed before asking the question.
    # @param ???name???
    #        May be a qid will be of better use instead as the client does not do anything port specific.
    # @param ports
    #        The list of ports for which the question is being asked.
    proc ui_ask_multichoice {msg name ports} {

        ui_choice $msg $name $ports

        # User Input (with Multiple input parsing)
        while 1 {
            if {[llength $ports] > 1} {
                set option_range "1-[llength $ports]"
            } else {
                set option_range "1"
            }
            puts -nonewline "Enter option(s) \[$option_range/all\]: "
            flush stdout
            signal error {TERM INT}
            try {
                set input [gets stdin]
            } on error {_ eOptions} {
                # An error occurred, print a newline so the error message
                # doesn't occur on the prompt line and re-throw
                puts ""
                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
            }
            signal -restart error {TERM INT}
            # check if input is non-empty and otherwise fine
            if {$input eq ""} {
                return [list]
            }

            if {[string equal -nocase $input "all"]} {
                set count 0
                set options_seq [list]
                foreach port $ports {
                    lappend options_seq $count
                    incr count
                }
                return $options_seq    
            }

            if {[llength $input] > [llength $ports]} {
                puts "Extra indices present. Please enter option(s) only once."
                continue
            }

            set selected_opt [list]

            set err_flag 1
            set range_re {(\d+)-(\d+)}
            foreach num $input {
                if {[string is wideinteger -strict $num] && $num <= [llength $ports] && $num > 0} {
                    lappend selected_opt [expr {$num -1}]
                } elseif {[regexp $range_re $input _ start end]
                          && $start <= [llength $ports]
                          && $start > 0
                          && $end <= [llength $ports]
                          && $end > 0
                } then {
                    if {$start > $end} {
                        set tmp $start
                        set start $end
                        set end $tmp
                    }
                    for {set x $start} {$x <= $end} {incr x} {
                        lappend selected_opt [expr {$x -1}]
                    }
                } else {
                    puts "Please enter numbers separated by a space which are indices from the above list."
                    set err_flag 0
                    break
                }
            }
            if {$err_flag == 1} {
                return $selected_opt
            }
        }
    }

    ##
    # Displays alternative actions a user has to select by typing the text
    # within the square brackets of the desired action name.
    # Waits for user input indefinitely.
    #
    # @param msg
    #        The question specific message that is to be printed before asking the question.
    # @param ???name???
    #        May be a qid will be of better use instead as the client does not do anything port specific.
    # @param alts
    #        An array of action-text.
    # @param def
    #        The default action. If empty, the first action is set as default
    proc ui_ask_alternative {msg name alts def} {
        puts $msg
        upvar $alts alternatives

        if {$def eq ""} {
            # Default to first action
            set def [lindex [array names alternatives] 0]
        }

        set alt_names []
        foreach key [array names alternatives] {
            set key_match [string first $key $alternatives($key)]
            append alt_name [string range $alternatives($key) 0 [expr {$key_match - 1}]] \
                            \[ [expr {$def eq $key ? [string toupper $key] : $key}] \] \
                            [string range $alternatives($key) [expr {$key_match + [string length $key]}] end]
            lappend alt_names $alt_name
            unset alt_name
        }

        while 1 {
            puts -nonewline "[join $alt_names /]: "
            flush stdout
            signal error {TERM INT}
            try {
                set input [gets stdin]
            } on error {_ eOptions} {
                # An error occurred, print a newline so the error message
                # doesn't occur on the prompt line and re-throw
                puts ""
                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
            }
            set input [string tolower $input]
            if {[info exists alternatives($input)]} {
                return $input
            } elseif {$input eq ""} {
                return $def
            } else {
                puts "Please enter one of the alternatives"
            }
        }
    }
}

##########################################
# Main
##########################################

# Global arrays passed to the macports1.0 layer
array set ui_options        {}
array set global_options    {}
array set global_variations {}

# Global options private to this script
array set private_options {}

# Make sure we get the size of the terminal
# We do this here to save it in the boot_env, in case we determined it manually
term_init_size

# Save off a copy of the environment before mportinit monkeys with it
set boot_env [array get env]

set cmdname [file tail $argv0]

# Setp cmd_argv to match argv
set cmd_argv $argv
set cmd_argc $argc
set cmd_argn 0

# make sure we're using a sane umask
umask 022

# If we've been invoked as portf, then the first argument is assumed
# to be the name of a command file (i.e., there is an implicit -F
# before any arguments).
if {[moreargs] && $cmdname eq "portf"} {
    lappend ui_options(ports_commandfiles) [lookahead]
    advance
}

# Parse global options that will affect all subsequent commands
if {[catch {parse_options "global" ui_options global_options} result]} {
    puts "Error: $result"
    print_usage
    exit 1
}

if {[isatty stdout]
    && $portclient::progress::hasTermAnsiSend eq "yes"
    && (![info exists ui_options(ports_quiet)] || $ui_options(ports_quiet) ne "yes")} {
    set ui_options(progress_download) portclient::progress::download
    set ui_options(progress_generic)  portclient::progress::generic
}

if {[isatty stdin]
    && [isatty stdout]
    && (![info exists ui_options(ports_quiet)] || $ui_options(ports_quiet) ne "yes")
    && (![info exists ui_options(ports_noninteractive)] || $ui_options(ports_noninteractive) ne "yes")} {
    set ui_options(questions_yesno) portclient::questions::ui_ask_yesno
    set ui_options(questions_singlechoice) portclient::questions::ui_ask_singlechoice
    set ui_options(questions_multichoice) portclient::questions::ui_ask_multichoice
    set ui_options(questions_alternative) portclient::questions::ui_ask_alternative
}

set ui_options(notifications_append) portclient::notifications::append
set ui_options(notifications_system) portclient::notifications::system_append

# Get arguments remaining after option processing
set remaining_args [lrange $cmd_argv $cmd_argn end]

# If we have no arguments remaining after option processing then force
# shell mode
if { [llength $remaining_args] == 0 && ![info exists ui_options(ports_commandfiles)] } {
    lappend ui_options(ports_commandfiles) -
} elseif {[lookahead] in {"selfupdate" "migrate"}} {
    # tell mportinit not to tell the user they should selfupdate and skip the migration check
    set ui_options(ports_no_old_index_warning) 1
    set global_options(ports_no_migration_check) 1
} elseif {[lookahead] eq "sync"} {
    # tell mportinit not to tell the user they should selfupdate
    set ui_options(ports_no_old_index_warning) 1
}

# Initialize mport
# This must be done following parse of global options, as some options are
# evaluated by mportinit.
if {[catch {mportinit ui_options global_options global_variations} result]} {
    puts $::errorInfo
    fatal "Failed to initialize MacPorts, $result"
}

# Re-execute if running under Rosetta 2 and not building for x86_64.
# We know we are a universal binary if this is needed since mportinit
# would have errored if not.
if {${macports::os_major} >= 20 && ${macports::os_platform} eq "darwin" &&
    ${macports::build_arch} ne "x86_64" &&
    ![info exists global_options(ports_no_migration_check)] &&
    ![catch {sysctl sysctl.proc_translated} translated] && $translated
} then {
    ui_warn "MacPorts started under Rosetta 2, re-executing natively"
    execl /usr/bin/arch [list -arm64 $::argv0 {*}$::argv]
    ui_debug "Would have executed $::argv0 $::argv"
    ui_warn "Failed to re-execute MacPorts... just continuing"
}

# Change to port directory if requested
if {[info exists global_options(ports_dir)]} {
    set dir $global_options(ports_dir)
    if {[string first "/" $dir] == -1} {
        set portname $dir
        if {[catch {mportlookup $portname} result]} {
            ui_debug $::errorInfo
            fatal "lookup of portname $portname failed: $result"
        }
        if {[llength $result] < 2} {
            ui_error "port -D failed to look up $portname: no such port"
            exit 1
        }
        unset portname
        set portinfo [lindex $result 1]
        set dir [macports::getportdir [dict get $portinfo porturl]]
        unset portinfo
    }
    if {[catch {cd $dir} result]} {
        ui_debug "cd $dir: $::errorCode"
        ui_error "port -D could not change directory to $dir: [lindex $::errorCode 2]"
        exit 1
    }
    unset dir
}

# Set up some global state for our code
set current_portdir [pwd]

# Remove question settings from ui_options - these are only used via 
# macports::ui_options and could be removed internally, and we don't
# want to re-add them if so.
unset -nocomplain ui_options(questions_yesno)
unset -nocomplain ui_options(questions_singlechoice)
unset -nocomplain ui_options(questions_multichoice)
unset -nocomplain ui_options(questions_alternative)

# Freeze global_options into global_options_base; global_options
# will be reset to global_options_base prior to processing each command.
set global_options_base [array get global_options]
set ui_options_base [array get ui_options]
# Also save those used by the macports API
set mp_global_options_base [macports::get_global_options]
set mp_ui_options_base [macports::get_ui_options]

# First process any remaining args as action(s)
set exit_status 0
if { [llength $remaining_args] > 0 } {
    try {
        # If there are remaining arguments, process those as a command
        set exit_status [process_cmd $remaining_args]
    } trap {POSIX SIG SIGINT} {} {
        ui_debug "process_cmd aborted: $::errorInfo"
        ui_error [msgcat::mc "Aborted: SIGINT received."]
        set exit_status 2
        set aborted_by_signal yes
    } trap {POSIX SIG SIGTERM} {} {
        ui_debug "process_cmd aborted: $::errorInfo"
        ui_error [msgcat::mc "Aborted: SIGTERM received."]
        set exit_status 2
        set aborted_by_signal yes
    } on error {eMessage} {
        ui_debug "process_cmd failed: $::errorInfo"
        ui_error [msgcat::mc "process_cmd failed: %s" $eMessage]
        set exit_status 1
    }
}

# Process any prescribed command files, including standard input
if { ($exit_status == 0 || [macports::ui_isset ports_processall]) && [info exists ui_options(ports_commandfiles)]
        && ![info exists aborted_by_signal]} {
    try {
        set exit_status [process_command_files $ui_options(ports_commandfiles)]
    } trap {POSIX SIG SIGINT} {} {
        ui_debug "process_command_files aborted: $::errorInfo"
        ui_error [msgcat::mc "Aborted: SIGINT received."]
        set exit_status 2
    } trap {POSIX SIG SIGTERM} {} {
        ui_debug "process_command_files aborted: $::errorInfo"
        ui_error [msgcat::mc "Aborted: SIGTERM received."]
        set exit_status 2
    } on error {eMessage} {
        ui_debug "process_command_files failed: $::errorInfo"
        ui_error [msgcat::mc "process_command_files failed: %s" $eMessage]
        set exit_status 1
    }
}
if {$exit_status == -1} {
    set exit_status 0
}
if {$exit_status == 0} {
    # Check the last time 'reclaim' was run and run it
    macports::reclaim_check_and_run
}
# Hard exit, usually because base was updated, so we don't want to do
# anything on the way out. Hence do this after the reclaim check.
if {$exit_status == -999} {
    set exit_status 0
}

# shut down macports1.0
mportshutdown

# Return with exit_status
exit $exit_status
