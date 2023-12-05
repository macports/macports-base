#!/bin/sh
# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# Run the Tcl interpreter \
exec @TCLSH@ "$0" "$@"
# port.tcl
# $Id$
#
# Copyright (c) 2002-2007 The MacPorts Project.
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
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

catch {source \
    [file join "@TCL_PACKAGE_DIR@" macports1.0 macports_fastload.tcl]}
package require macports
package require Pextlib 1.0


# Standard procedures
proc print_usage {{verbose 1}} {
    global cmdname
    set syntax {
        [-bcdfknopqRstuvy] [-D portdir] [-F cmdfile] action [privopts] [actionflags]
        [[portname|pseudo-portname|port-url] [@version] [+-variant]... [option=value]...]...
    }

    if {$verbose} {
        puts stderr "Usage: $cmdname$syntax"
        puts stderr "\"$cmdname help\" or \"man 1 port\" for more information."
    } else {
        puts stderr "$cmdname$syntax"
    }
}

proc print_help {args} {
    global action_array

    print_usage 0

    # Generate and format the command list from the action_array
    set cmds ""
    set lineLen 0
    foreach cmd [lsort [array names action_array]] {
        if {$lineLen > 65} {
            set cmds "$cmds,\n"
            set lineLen 0
        }
        if {$lineLen == 0} {
            set new "$cmd"
        } else {
            set new ", $cmd"
        }
        incr lineLen [string length $new]
        set cmds "$cmds$new"
    }

    set cmdText "Supported commands
------------------
$cmds
"

    set text {
Pseudo-portnames
----------------
Pseudo-portnames are words that may be used in place of a portname, and
which expand to some set of ports. The common pseudo-portnames are:
all, current, active, inactive, installed, uninstalled, outdated and obsolete.
These pseudo-portnames expand to the set of ports named.

Additional pseudo-portnames start with...
variants:, variant:, description:, depends:, depends_lib:, depends_run:,
depends_build:, depends_fetch:, depends_extract:, portdir:, homepage:, epoch:,
platforms:, platform:, name:, long_description:, maintainers:, maintainer:,
categories:, category:, version:, and revision:.
These each select a set of ports based on a regex search of metadata
about the ports. In all such cases, a standard regex pattern following
the colon will be used to select the set of ports to which the
pseudo-portname expands.

Portnames that contain standard glob characters will be expanded to the
set of ports matching the glob pattern.
    
Port expressions
----------------
Portnames, port glob patterns, and pseudo-portnames may be logically
combined using expressions consisting of and, or, not, !, (, and ).
    
For more information
--------------------
See man pages: port(1), macports.conf(5), portfile(7), portgroup(7),
porthier(7), portstyle(7). Also, see http://www.macports.org.
    }

    puts "$cmdText$text"
}


# Produce error message and exit
proc fatal s {
    global argv0
    ui_error "$argv0: $s"
    exit 1
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

# Form a composite version as is sometimes used for registry functions
proc composite_version {version variations {emptyVersionOkay 0}} {
    # Form a composite version out of the version and variations
    
    # Select the variations into positive and negative
    set pos {}
    set neg {}
    foreach { key val } $variations {
        if {$val == "+"} {
            lappend pos $key
        } elseif {$val == "-"} {
            lappend neg $key
        }
    }

    # If there is no version, we have nothing to do
    set composite_version ""
    if {$version != "" || $emptyVersionOkay} {
        set pos_str ""
        set neg_str ""

        if {[llength $pos]} {
            set pos_str "+[join [lsort -ascii $pos] "+"]"
        }
        if {[llength $neg]} {
            set neg_str "-[join [lsort -ascii $neg] "-"]"
        }

        set composite_version "$version$pos_str$neg_str"
    }

    return $composite_version
}


proc split_variants {variants} {
    set result {}
    set l [regexp -all -inline -- {([-+])([[:alpha:]_]+[\w\.]*)} $variants]
    foreach { match sign variant } $l {
        lappend result $variant $sign
    }
    return $result
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
        maintainer {
            set field "${field}s"
        }
        category {
            set field "categories"
        }
    }

    return $field
}


proc registry_installed {portname {portversion ""}} {
    set ilist [registry::installed $portname $portversion]
    if { [llength $ilist] > 1 } {
        # set portname again since the one we were passed may not have had the correct case
        set portname [lindex [lindex $ilist 0] 0]
        if {![macports::ui_isset ports_quiet] && [isatty stdout]} {
            puts "The following versions of $portname are currently installed:"
        }
        foreach i [portlist_sortint $ilist] { 
            set iname [lindex $i 0]
            set iversion [lindex $i 1]
            set irevision [lindex $i 2]
            set ivariants [lindex $i 3]
            set iactive [lindex $i 4]
            if { $iactive == 0 } {
                puts "  $iname ${iversion}_${irevision}${ivariants}"
            } elseif { $iactive == 1 } {
                puts "  $iname ${iversion}_${irevision}${ivariants} (active)"
            }
        }
        return -code error "Registry error: Please specify the full version as recorded in the port registry."
    } else {
        return [lindex $ilist 0]
    }
}


proc add_to_portlist {listname portentry} {
    upvar $listname portlist
    global global_options global_variations

    # The portlist currently has the following elements in it:
    #   url             if any
    #   name
    #   version         (version_revision)
    #   variants array  (variant=>+-)
    #   requested_variants array  (variant=>+-)
    #   options array   (key=>value)
    #   fullname        (name/version_revision+-variants)

    array set port $portentry
    if {![info exists port(url)]}       { set port(url) "" }
    if {![info exists port(name)]}      { set port(name) "" }
    if {![info exists port(version)]}   { set port(version) "" }
    if {![info exists port(variants)]}  { set port(variants) "" }
    if {![info exists port(requested_variants)]}  { set port(requested_variants) "" }
    if {![info exists port(options)]}   { set port(options) [array get global_options] }

    # If neither portname nor url is specified, then default to the current port
    if { $port(url) == "" && $port(name) == "" } {
        set url file://.
        set portname [url_to_portname $url]
        set port(url) $url
        set port(name) $portname
        if {$portname == ""} {
            ui_error "A default port name could not be supplied."
        }
    }


    # Form the fully descriminated portname: portname/version_revison+-variants
    set port(fullname) "$port(name)/[composite_version $port(version) $port(variants)]"
    
    # Add it to our portlist
    lappend portlist [array get port]
}


proc add_ports_to_portlist {listname ports {overridelist ""}} {
    upvar $listname portlist

    array set overrides $overridelist

    # Add each entry to the named portlist, overriding any values
    # specified as overrides
    foreach portentry $ports {
        array set port $portentry
        if ([info exists overrides(version)])   { set port(version) $overrides(version) }
        if ([info exists overrides(variants)])  { set port(variants) $overrides(variants) }
        if ([info exists overrides(requested_variants)])  { set port(requested_variants) $overrides(requested_variants) }
        if ([info exists overrides(options)])   { set port(options) $overrides(options) }
        add_to_portlist portlist [array get port]
    }
}


proc url_to_portname { url {quiet 0} } {
    # Save directory and restore the directory, since mportopen changes it
    set savedir [pwd]
    set portname ""
    if {[catch {set ctx [mportopen $url]} result]} {
        if {!$quiet} {
            ui_msg "Can't map the URL '$url' to a port description file (\"${result}\")."
            ui_msg "Please verify that the directory and portfile syntax are correct."
        }
    } else {
        array set portinfo [mportinfo $ctx]
        set portname $portinfo(name)
        mportclose $ctx
    }
    cd $savedir
    return $portname
}


# Supply a default porturl/portname if the portlist is empty
proc require_portlist { nameportlist } {
    global private_options
    upvar $nameportlist portlist

    if {[llength $portlist] == 0 && (![info exists private_options(ports_no_args)] || $private_options(ports_no_args) == "no")} {
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


# Execute the enclosed block once for every element in the portlist
# When the block is entered, the variables portname, portversion, options, and variations
# will have been set
proc foreachport {portlist block} {
    # Restore cwd after each port, since mportopen changes it, and relative
    # urls will break on subsequent passes
    set savedir [pwd]
    foreach portspec $portlist {
        uplevel 1 "array set portspec { $portspec }"
        uplevel 1 {
            set porturl $portspec(url)
            set portname $portspec(name)
            set portversion $portspec(version)
            array unset variations
            array set variations $portspec(variants)
            array unset requested_variations
            array set requested_variations $portspec(requested_variants)
            array unset options
            array set options $portspec(options)
        }
        uplevel 1 $block
        if {[file exists $savedir]} {
            cd $savedir
        } else {
            cd ~
        }
    }
}


proc portlist_compare { a b } {
    array set a_ $a
    array set b_ $b
    set namecmp [string compare -nocase $a_(name) $b_(name)]
    if {$namecmp != 0} {
        return $namecmp
    }
    set avr_ [split $a_(version) "_"]
    set bvr_ [split $b_(version) "_"]
    set vercmp [rpm-vercomp [lindex $avr_ 0] [lindex $bvr_ 0]]
    if {$vercmp != 0} {
        return $vercmp
    }
    set ar_ [lindex $avr_ 1]
    set br_ [lindex $bvr_ 1]
    if {$ar_ < $br_} {
        return -1
    } elseif {$ar_ > $br_} {
        return 1
    } else {
        return 0
    }
}

# Sort two ports in NVR (name@version_revision) order
proc portlist_sort { list } {
    return [lsort -command portlist_compare $list]
}

proc portlist_compareint { a b } {
    array set a_ [list "name" [lindex $a 0] "version" "[lindex $a 1]_[lindex $a 2]"]
    array set b_ [list "name" [lindex $b 0] "version" "[lindex $b 1]_[lindex $b 2]"]
    return [portlist_compare [array get a_] [array get b_]]
}

# Same as portlist_sort, but with numeric indexes {name version revision}
proc portlist_sortint { list } {
    return [lsort -command portlist_compareint $list]
}

proc regex_pat_sanitize { s } {
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

    set splitstring {}
    foreach line [split $string "\n"] {
        lappend splitstring [wrapline $line $maxlen $indent $indentfirstline]
    }
    return [join $splitstring "\n"]
}

##
# Wraps a line at specified textwidth
#
# @see wrap
#
# @param line input line
# @param maxlen text width (0 defaults to current terminal width)
# @param indent prepend to every line
# @return wrapped string
proc wrapline {line maxlen {indent ""} {indentfirstline 1}} {
    global env

    if {$maxlen == 0} {
        if {![info exists env(COLUMNS)]} {
            # no width for wrapping
            return $string
        }
        set maxlen $env(COLUMNS)
    }

    set string [split $line " "]
    if {$indentfirstline == 0} {
        set newline ""
        set maxlen [expr $maxlen - [string length $indent]]
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
                set maxlen [expr $maxlen + [string length $indent]]
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
    append label ": [string repeat " " [expr [string length $indent] - [string length "$label: "]]]"
    return "$label[wrap $string $maxlen $indent 0]"
}

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


##########################################
# Port selection
##########################################
proc get_matching_ports {pattern {casesensitive no} {matchstyle glob} {field name}} {
    if {[catch {set res [mportsearch $pattern $casesensitive $matchstyle $field]} result]} {
        global errorInfo
        ui_debug "$errorInfo"
        fatal "search for portname $pattern failed: $result"
    }

    set results {}
    foreach {name info} $res {
        array unset portinfo
        array set portinfo $info

        #set variants {}
        #if {[info exists portinfo(variants)]} {
        #   foreach variant $portinfo(variants) {
        #       lappend variants $variant "+"
        #   }
        #}
        # For now, don't include version or variants with all ports list
        #"$portinfo(version)_$portinfo(revision)"
        #$variants
        add_to_portlist results [list url $portinfo(porturl) name $name]
    }

    # Return the list of all ports, sorted
    return [portlist_sort $results]
}


proc get_all_ports {} {
    global all_ports_cache

    if {![info exists all_ports_cache]} {
         if {[catch {set res [mportlistall]} result]} {
            global errorInfo
            ui_debug "$errorInfo"
            fatal "listing all ports failed: $result"
        }
        set results {}
        foreach {name info} $res {
            array unset portinfo
            array set portinfo $info
            add_to_portlist results [list url $portinfo(porturl) name $name]
        }

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
    if {$portname == ""} {
        ui_msg "To use the current port, you must be in a port's directory."
        ui_msg "(you might also see this message if a pseudo-port such as"
        ui_msg "outdated or installed expands to no ports)."
        return [list]
    }

    set results {}
    add_to_portlist results [list url $url name $portname]
    return $results
}


proc get_installed_ports { {ignore_active yes} {active yes} } {
    set ilist {}
    if { [catch {set ilist [registry::installed]} result] } {
        if {$result != "Registry error: No ports registered as installed."} {
            global errorInfo
            ui_debug "$errorInfo"
            fatal "port installed failed: $result"
        }
    }

    set results {}
    foreach i $ilist {
        set iname [lindex $i 0]
        set iversion [lindex $i 1]
        set irevision [lindex $i 2]
        set ivariants [split_variants [lindex $i 3]]
        set iactive [lindex $i 4]

        if { ${ignore_active} == "yes" || (${active} == "yes") == (${iactive} != 0) } {
            add_to_portlist results [list name $iname version "${iversion}_${irevision}" variants $ivariants]
        }
    }

    # Return the list of ports, sorted
    return [portlist_sort $results]
}


proc get_uninstalled_ports {} {
    # Return all - installed
    set all [get_all_ports]
    set installed [get_installed_ports]
    return [opComplement $all $installed]
}


proc get_active_ports {} {
    return [get_installed_ports no yes]
}


proc get_inactive_ports {} {
    return [get_installed_ports no no]
}


proc get_outdated_ports {} {
    global macports::registry.installtype
    set is_image_mode [expr 0 == [string compare "image" ${macports::registry.installtype}]]

    # Get the list of installed ports
    set ilist {}
    if { [catch {set ilist [registry::installed]} result] } {
        if {$result != "Registry error: No ports registered as installed."} {
            global errorInfo
            ui_debug "$errorInfo"
            fatal "port installed failed: $result"
        }
    }

    # Now process the list, keeping only those ports that are outdated
    set results {}
    if { [llength $ilist] > 0 } {
        foreach i $ilist {

            # Get information about the installed port
            set portname            [lindex $i 0]
            set installed_version   [lindex $i 1]
            set installed_revision  [lindex $i 2]
            set installed_compound  "${installed_version}_${installed_revision}"
            set installed_variants  [lindex $i 3]

            set is_active           [lindex $i 4]
            if { $is_active == 0 && $is_image_mode } continue

            set installed_epoch     [lindex $i 5]

            # Get info about the port from the index
            if {[catch {set res [mportlookup $portname]} result]} {
                global errorInfo
                ui_debug "$errorInfo"
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
            set latest_compound     "${latest_version}_${latest_revision}"
            set latest_epoch        0
            if {[info exists portinfo(epoch)]} { 
                set latest_epoch    $portinfo(epoch)
            }

            # Compare versions, first checking epoch, then version, then revision
            set comp_result [expr $installed_epoch - $latest_epoch]
            if { $comp_result == 0 } {
                set comp_result [rpm-vercomp $installed_version $latest_version]
                if { $comp_result == 0 } {
                    set comp_result [rpm-vercomp $installed_revision $latest_revision]
                }
            }

            # Add outdated ports to our results list
            if { $comp_result < 0 } {
                add_to_portlist results [list name $portname version $installed_compound variants [split_variants $installed_variants]]
            }
        }
    }

    return $results
}


proc get_obsolete_ports {} {
    set ilist [get_installed_ports]
    set results {}

    foreach i $ilist {
        array set port $i

        if {[catch {mportlookup $port(name)} result]} {
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

        set blist {}
        set result [orExpr blist]
        if {$result} {
            # Calculate the union of result and b
            set reslist [opUnion $reslist $blist]
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
                    set blist {}
                    if {![andExpr blist]} {
                        return 0
                    }
                        
                    # Calculate a union b
                    set reslist [opUnion $reslist $blist]
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
                    
                    set blist {}
                    set b [unaryExpr blist]
                    if {!$b} {
                        return 0
                    }
                    
                    # Calculate a intersect b
                    set reslist [opIntersection $reslist $blist]
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
                set blist {}
                set result [unaryExpr blist]
                if {$result} {
                    set all [get_all_ports]
                    set reslist [opComplement $all $blist]
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
    array unset requested_variants
    array unset options
    
    set token [lookahead]
    switch -regex -- $token {
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

        ^all(@.*)?$         -
        ^installed(@.*)?$   -
        ^uninstalled(@.*)?$ -
        ^active(@.*)?$      -
        ^inactive(@.*)?$    -
        ^outdated(@.*)?$    -
        ^obsolete(@.*)?$    -
        ^current(@.*)?$     {
            # A simple pseudo-port name
            advance

            # Break off the version component, if there is one
            regexp {^(\w+)(@.*)?} $token matchvar name remainder

            add_multiple_ports reslist [get_${name}_ports] $remainder

            set el 1
        }

        ^variants:          -
        ^variant:           -
        ^description:       -
        ^portdir:           -
        ^homepage:          -
        ^epoch:             -
        ^platforms:         -
        ^platform:          -
        ^name:              -
        ^long_description:  -
        ^maintainers:       -
        ^maintainer:        -
        ^categories:        -
        ^category:          -
        ^version:           -
        ^depends_lib:       -
        ^depends_build:     -
        ^depends_run:       -
        ^depends_extract:   -
        ^depends_fetch:     -
        ^revision:          { # Handle special port selectors
            advance

            # Break up the token, because older Tcl switch doesn't support -matchvar
            regexp {^(\w+):(.*)} $token matchvar field pat

            # Remap friendly names to actual names
            set field [map_friendly_field_names $field]

            add_multiple_ports reslist [get_matching_ports $pat no regexp $field]
            set el 1
        }

        ^depends:           { # A port selector shorthand for depends_{lib,build,run,fetch,extract}
            advance

            # Break up the token, because older Tcl switch doesn't support -matchvar
            regexp {^(\w+):(.*)} $token matchvar field pat

            add_multiple_ports reslist [get_matching_ports $pat no regexp "depends_lib"]
            add_multiple_ports reslist [get_matching_ports $pat no regexp "depends_build"]
            add_multiple_ports reslist [get_matching_ports $pat no regexp "depends_run"]
            add_multiple_ports reslist [get_matching_ports $pat no regexp "depends_extract"]
            add_multiple_ports reslist [get_matching_ports $pat no regexp "depends_fetch"]

            set el 1
        }

        [][?*]              { # Handle portname glob patterns
            advance; add_multiple_ports reslist [get_matching_ports $token no glob]
            set el 1
        }

        ^\\w+:.+            { # Handle a url by trying to open it as a port and mapping the name
            advance
            set name [url_to_portname $token]
            if {$name != ""} {
                parsePortSpec version requested_variants options
                add_to_portlist reslist [list url $token \
                  name $name \
                  version $version \
                  requested_variants [array get requested_variants] \
                  variants [array get requested_variants] \
                  options [array get options]]
            } else {
                ui_error "Can't open URL '$token' as a port"
                set el 0
            }
            set el 1
        }

        default             { # Treat anything else as a portspec (portname, version, variants, options
            # or some combination thereof).
            parseFullPortSpec url name version requested_variants options
            add_to_portlist reslist [list url $url \
              name $name \
              version $version \
              requested_variants [array get requested_variants] \
              variants [array get requested_variants] \
              options [array get options]]
            set el 1
        }
    }

    return $el
}


proc add_multiple_ports { resname ports {remainder ""} } {
    upvar $resname reslist
    
    set version ""
    array unset variants
    array unset options
    parsePortSpec version variants options $remainder
    
    array unset overrides
    if {$version != ""} { set overrides(version) $version }
    if {[array size variants]} {
        # we always record the requested variants separately,
        # but requested ones always override existing ones
        set overrides(requested_variants) [array get variants]
        set overrides(variants) [array get variants]
    }
    if {[array size options]} { set overrides(options) [array get options] }

    add_ports_to_portlist reslist $ports [array get overrides]
}


proc opUnion { a b } {
    set result {}
    
    array unset onetime
    
    # Walk through each array, adding to result only those items that haven't
    # been added before
    foreach item $a {
        array set port $item
        if {[info exists onetime($port(fullname))]} continue
        set onetime($port(fullname)) 1
        lappend result $item
    }

    foreach item $b {
        array set port $item
        if {[info exists onetime($port(fullname))]} continue
        set onetime($port(fullname)) 1
        lappend result $item
    }
    
    return $result
}


proc opIntersection { a b } {
    set result {}
    
    # Rules we follow in performing the intersection of two port lists:
    #
    #   a/, a/          ==> a/
    #   a/, b/          ==>
    #   a/, a/1.0       ==> a/1.0
    #   a/1.0, a/       ==> a/1.0
    #   a/1.0, a/2.0    ==>
    #
    #   If there's an exact match, we take it.
    #   If there's a match between simple and descriminated, we take the later.
    
    # First create a list of the fully descriminated names in b
    array unset bfull
    set i 0
    foreach bitem $b {
        array set port $bitem
        set bfull($port(fullname)) $i
        incr i
    }
    
    # Walk through each item in a, matching against b
    foreach aitem $a {
        array set port $aitem
        
        # Quote the fullname and portname to avoid special characters messing up the regexp
        set safefullname [regex_pat_sanitize $port(fullname)]
        
        set simpleform [expr { "$port(name)/" == $port(fullname) }]
        if {$simpleform} {
            set pat "^${safefullname}"
        } else {
            set safename [regex_pat_sanitize $port(name)]
            set pat "^${safefullname}$|^${safename}/$"
        }
        
        set matches [array names bfull -regexp $pat]
        foreach match $matches {
            if {$simpleform} {
                set i $bfull($match)
                lappend result [lindex $b $i]
            } else {
                lappend result $aitem
            }
        }
    }
    
    return $result
}


proc opComplement { a b } {
    set result {}
    
    # Return all elements of a not matching elements in b
    
    # First create a list of the fully descriminated names in b
    array unset bfull
    set i 0
    foreach bitem $b {
        array set port $bitem
        set bfull($port(fullname)) $i
        incr i
    }
    
    # Walk through each item in a, taking all those items that don't match b
    #
    # Note: -regexp may not be present in all versions of Tcl we need to work
    #       against, in which case we may have to fall back to a slower alternative
    #       for those cases. I'm not worrying about that for now, however. -jdb
    foreach aitem $a {
        array set port $aitem
        
        # Quote the fullname and portname to avoid special characters messing up the regexp
        set safefullname [regex_pat_sanitize $port(fullname)]
        
        set simpleform [expr { "$port(name)/" == $port(fullname) }]
        if {$simpleform} {
            set pat "^${safefullname}"
        } else {
            set safename [regex_pat_sanitize $port(name)]
            set pat "^${safefullname}$|^${safename}/$"
        }
        
        set matches [array names bfull -regexp $pat]

        # We copy this element to result only if it didn't match against b
        if {![llength $matches]} {
            lappend result $aitem
        }
    }
    
    return $result
}


proc parseFullPortSpec { urlname namename vername varname optname } {
    upvar $urlname porturl
    upvar $namename portname
    upvar $vername portversion
    upvar $varname portvariants
    upvar $optname portoptions
    
    set portname ""
    set portversion ""
    array unset portvariants
    array unset portoptions
    
    if { [moreargs] } {
        # Look first for a potential portname
        #
        # We need to allow a wide variaty of tokens here, because of actions like "provides"
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
                if { $name != "" } {
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

    
proc parsePortSpec { vername varname optname {remainder ""} } {
    upvar $vername portversion
    upvar $varname portvariants
    upvar $optname portoptions
    
    global global_options
    
    set portversion ""
    array unset portoptions
    array set portoptions [array get global_options]
    array unset portvariants
    
    # Parse port version/variants/options
    set opt $remainder
    set adv 0
    set consumed 0
    for {set firstTime 1} {$opt != "" || [moreargs]} {set firstTime 0} {
    
        # Refresh opt as needed
        if {$opt == ""} {
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
                set portversion [string range $opt 0 [expr $sepPos-1]]
                set opt [string range $opt [expr $sepPos+1] end]
            } else {
                # Version terminated by "+", or else is complete
                set sepPos [string first "+" $opt]
                if {$sepPos >= 0} {
                    # Version terminated by "+"
                    set portversion [string range $opt 0 [expr $sepPos-1]]
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
                set portoptions($key) "\"$val\""
                set opt ""
                set consumed 1
            } elseif {[regexp {^([-+])([[:alpha:]_]+[\w\.]*)} $opt match sign variant] == 1} {
                # It's a variant
                set portvariants($variant) $sign
                set opt [string range $opt [expr [string length $variant]+1] end]
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

    if {[info exists action_array($action)]} {
        set cmds ""
        if {[info exists cmd_opts_array($action)]} {
            foreach opt $cmd_opts_array($action) {
                if {[llength $opt] == 1} {
                    set name $opt
                    set optc 0
                } else {
                    set name [lindex $opt 0]
                    set optc [lindex $opt 1]
                }

                append cmds " --$name"

                for {set i 1} {$i <= $optc} {incr i} {
                    append cmds " <arg$i>"
                }
            }
        }
        set args ""
        set needed [action_needs_portlist $action]
        if {[action_args_const strings] == $needed} {
            set args " <arguments>"
        } elseif {[action_args_const strings] == $needed} {
            set args " <portlist>"
        }

        set ret "Usage: "
        set len [string length $action]
        append ret [wrap "$action$cmds$args" 0 [string repeat " " [expr 8 + $len]] 0]
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
    set helpfile "$macports::prefix/var/macports/port-help.tcl"

    if {[llength $portlist] == 0} {
        print_help
        return 0
    }

    if {[file exists $helpfile]} {
        if {[catch {source $helpfile} err]} {
            puts stderr "Error reading helpfile $helpfile: $err"
            return 1
        }
    } else {
        puts stderr "Unable to open help file $helpfile"
        return 1
    }

    foreach topic $portlist {
        if {![info exists porthelp($topic)]} {
            puts stderr "No help for topic $topic"
            return 1
        }

        set usage [action_get_usage $topic]
        if {$usage != -1} {
           puts -nonewline stderr $usage
        } else {
            ui_error "No usage for topic $topic"
            return 1
        }

        puts stderr $porthelp($topic)
    }

    return 0
}


proc action_log { action portlist opts } {
    global global_options 
    set logfile "$macports::prefix/var/macports/logs/"
    #puts "$opts"
    if {[llength $portlist] == 0} {
        print_help
        return 0
    }
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
            array unset portinfo
            array set portinfo [lindex $result 1]
            set porturl $portinfo(porturl)
            set portdir $portinfo(portdir)
        } elseif {$porturl ne "file://."} {
            # Extract the portdir from porturl and use it to search PortIndex.
            # Only the last two elements of the path (porturl) make up the
            # portdir.
            set portdir [file split [macports::getportdir $porturl]]
            set lsize [llength $portdir]
            set portdir \
                [file join [lindex $portdir [expr $lsize - 2]] \
                           [lindex $portdir [expr $lsize - 1]]]
            if {[catch {mportsearch $portdir no exact portdir} result]} {
                ui_debug "$::errorInfo"
                break_softcontinue "Portdir $portdir not found" 1 status
            }
            if {[llength $result] < 2} {
                break_softcontinue "Portdir $portdir not found" 1 status
            }
            array unset portinfo
            array set portinfo [lindex $result 1]
        }
        if {[catch {set mport [mportopen $porturl [array get options] [array get merged_variations]]} result]} {
            ui_debug "$::errorInfo"
            break_softcontinue "Unable to open port: $result" 1 status
         }
         array unset portinfo
         array set portinfo [mportinfo $mport]

         append logfile $portinfo(name)
         append logfile "/main.log"
         mportclose $mport                        
         if {[file exists $logfile]} {
            set fp [open $logfile r]
            set data [read $fp]
            set data [split $data "\n"]

            if {[info exists global_options(ports_log_phase)]} {
                set stage $global_options(ports_log_phase);
            } else {
                set stage "\[a-z\]*"
            }

            if {[info exists global_options(ports_log_verbosity)]} {
                set prefix $global_options(ports_log_verbosity);
            } else {
                set prefix "\[a-z\]*"
            }
            set match ""
            foreach line $data {
                set exp "^:($prefix|any):($stage|any) .*$"
                regexp $exp $line match
                if {$match == $line} {
                    regsub "^:\[a-z\]*:\[a-z\]* "  $line "" line
                    puts $line
                }
            }
            
            close $fp
        } else {
            ui_msg "Log file not found"
        }
    }
    return 0
}


proc action_info { action portlist opts } {
    global global_variations
    set status 0
    if {[require_portlist portlist]} {
        return 1
    }

    set separator ""
    foreachport $portlist {
        puts -nonewline $separator
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
            array unset portinfo
            array set portinfo [lindex $result 1]
            set porturl $portinfo(porturl)
            set portdir $portinfo(portdir)
        } elseif {$porturl ne "file://."} {
            # Extract the portdir from porturl and use it to search PortIndex.
            # Only the last two elements of the path (porturl) make up the
            # portdir.
            set portdir [file split [macports::getportdir $porturl]]
            set lsize [llength $portdir]
            set portdir \
                [file join [lindex $portdir [expr $lsize - 2]] \
                           [lindex $portdir [expr $lsize - 1]]]
            if {[catch {mportsearch $portdir no exact portdir} result]} {
                ui_debug "$::errorInfo"
                break_softcontinue "Portdir $portdir not found" 1 status
            }
            if {[llength $result] < 2} {
                break_softcontinue "Portdir $portdir not found" 1 status
            }
            array unset portinfo
            array set portinfo [lindex $result 1]
        }

        if {!([info exists options(ports_info_index)] && $options(ports_info_index) eq "yes")} {
            # Add any global_variations to the variations
            # specified for the port (so we get e.g. dependencies right)
            array unset merged_variations
            array set merged_variations [array get variations]
            foreach { variation value } [array get global_variations] { 
                if { ![info exists merged_variations($variation)] } { 
                    set merged_variations($variation) $value 
                } 
            }
 
            if {[catch {set mport [mportopen $porturl [array get options] [array get merged_variations]]} result]} {
                ui_debug "$::errorInfo"
                break_softcontinue "Unable to open port: $result" 1 status
            }
            array unset portinfo
            array set portinfo [mportinfo $mport]
            mportclose $mport
            if {[info exists portdir]} {
                set portinfo(portdir) $portdir
            }
        } elseif {![info exists portinfo]} {
            ui_warn "port info --index does not work with 'current' pseudo-port"
            continue
        }
        array unset options ports_info_index

        # Understand which info items are actually lists
        # (this could be overloaded to provide a generic formatting code to
        # allow us to, say, split off the prefix on libs)
        array set list_map "
            categories      1
            depends_fetch   1
            depends_extract 1
            depends_build   1
            depends_lib     1
            depends_run     1
            maintainers     1
            platforms       1
            variants        1
            conflicts       1
        "

        # Label map for pretty printing
        array set pretty_label {
            heading     ""
            variants    Variants
            depends_fetch "Fetch Dependencies"
            depends_extract "Extract Dependencies"
            depends_build "Build Dependencies"
            depends_run "Runtime Dependencies"
            depends_lib "Library Dependencies"
            description "Brief Description"
            long_description "Description"
            fullname    "Full Name: "
            homepage    Homepage
            platforms   Platforms
            maintainers Maintainers
            license     License
            conflicts   "Conflicts with"
            replaced_by "Replaced by"
        }

        # Wrap-length map for pretty printing
        array set pretty_wrap {
            heading 0
            replaced_by 22
            variants 22
            depends_fetch 22
            depends_extract 22
            depends_build 22
            depends_run 22
            depends_lib 22
            description 22
            long_description 22
            homepage 22
            platforms 22
            license 22
            conflicts 22
            maintainers 22
        }

        # Interpret a convenient field abbreviation
        if {[info exists options(ports_info_depends)] && $options(ports_info_depends) == "yes"} {
            array unset options ports_info_depends
            set options(ports_info_depends_fetch) yes
            set options(ports_info_depends_extract) yes
            set options(ports_info_depends_build) yes
            set options(ports_info_depends_lib) yes
            set options(ports_info_depends_run) yes
        }
                
        # Set up our field separators
        set show_label 1
        set field_sep "\n"
        set subfield_sep ", "
        set pretty_print 0
        
        # For human-readable summary, which is the default with no options
        if {![array size options]} {
            set pretty_print 1
        } elseif {[info exists options(ports_info_pretty)]} {
            set pretty_print 1
            array unset options ports_info_pretty
        }

        # Tune for sort(1)
        if {[info exists options(ports_info_line)]} {
            array unset options ports_info_line
            set show_label 0
            set field_sep "\t"
            set subfield_sep ","
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
        set fields {}
        set opts_todo [array names options ports_info_*]
        set fields_tried {}
        if {![llength $opts_todo]} {
            set opts_todo {ports_info_heading
                ports_info_replaced_by
                ports_info_variants 
                ports_info_skip_line
                ports_info_long_description ports_info_homepage 
                ports_info_skip_line ports_info_depends_fetch
                ports_info_depends_extract ports_info_depends_build
                ports_info_depends_lib ports_info_depends_run
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
                set inf "$portinfo(name) @$portinfo(version)"
                set ropt "heading"
                if {[info exists portinfo(revision)] && $portinfo(revision) > 0} {
                    append inf ", Revision $portinfo(revision)"
                }
                if {[info exists portinfo(categories)]} {
                    append inf " ([join $portinfo(categories) ", "])"
                }
            } elseif {$opt eq "fullname"} {
                set inf "$portinfo(name) @"
                append inf [composite_version $portinfo(version) $portinfo(active_variants)]
                set ropt "fullname"
            } else {
                # Map from friendly name
                set ropt [map_friendly_field_names $opt]
                
                # If there's no such info, move on
                if {![info exists portinfo($ropt)]} {
                    set inf ""
                } else {
                    set inf [join $portinfo($ropt)]
                }
            }

            # Calculate field label
            set label ""
            if {$pretty_print} {
                if {[info exists pretty_label($ropt)]} {
                    set label $pretty_label($ropt)
                } else {
                    set label $opt
                }
            } elseif {$show_label} {
                set label "$opt: "
            }
            
            # Format the data
            if { $ropt eq "maintainers" } {
                set inf [unobscure_maintainers $inf]
            }
            #     ... special formatting for certain fields when prettyprinting
            if {$pretty_print} {
                if {$ropt eq "variants"} {
                    # Use the new format for variants iff it exists in
                    # PortInfo. This key currently does not exist outside of
                    # trunk (1.8.0).
                    array unset vinfo
                    if {[info exists portinfo(vinfo)]} {
                        array set vinfo $portinfo(vinfo)
                    }

                    set pi_vars $inf
                    set inf {}
                    foreach v [lsort $pi_vars] {
                        set varmodifier ""
                        if {[info exists variations($v)]} {
                            # selected by command line, prefixed with +/-
                            set varmodifier $variations($v)
                        } elseif {[info exists global_variations($v)]} {
                            # selected by variants.conf, prefixed with (+)/(-)
                            set varmodifier "($global_variations($v))"
                            # Retrieve additional information from the new key.
                        } elseif {[info exists vinfo]} {
                            array unset variant
                            array set variant $vinfo($v)
                            if {[info exists variant(is_default)]} {
                                set varmodifier "\[+]"
                            }
                        }
                        lappend inf "$varmodifier$v"
                    }
                } elseif {[string match "depend*" $ropt] 
                          && ![macports::ui_isset ports_verbose]} {
                    set pi_deps $inf
                    set inf {}
                    foreach d $pi_deps {
                        lappend inf [lindex [split $d :] end]
                    }
                }
            } 
            #End of special pretty-print formatting for certain fields
            if [info exists list_map($ropt)] {
                set field [join $inf $subfield_sep]
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
                if {![string length $field]} {
                    continue
                }
                if {![string length $label]} {
                    set wrap_len 0
                    if {[info exists pretty_wrap($ropt)]} {
                        set wrap_len $pretty_wrap($ropt)
                    }
                    lappend fields [wrap $field 0 [string repeat " " $wrap_len]]
                } else {
                    set wrap_len [string length $label]
                    if {[info exists pretty_wrap($ropt)]} {
                        set wrap_len $pretty_wrap($ropt)
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
        set separator "--\n"
    }
    
    return $status
}


proc action_location { action portlist opts } {
    set status 0
    if {[require_portlist portlist]} {
        return 1
    }
    foreachport $portlist {
        if { [catch {set ilist [registry_installed $portname [composite_version $portversion [array get variations]]]} result] } {
            global errorInfo
            ui_debug "$errorInfo"
            break_softcontinue "port location failed: $result" 1 status
        } else {
            # set portname again since the one we were passed may not have had the correct case
            set portname [lindex $ilist 0]
            set version [lindex $ilist 1]
            set revision [lindex $ilist 2]
            set variants [lindex $ilist 3]
        }

        set ref [registry::open_entry $portname $version $revision $variants]
        if { [string equal [registry::property_retrieve $ref installtype] "image"] } {
            set imagedir [registry::property_retrieve $ref imagedir]
            if {![macports::ui_isset ports_quiet]} {
                puts "Port $portname ${version}_${revision}${variants} is installed as an image in:"
            }
            puts $imagedir
        } else {
            break_softcontinue "Port $portname is not installed as an image." 1 status
        }
    }
    
    return $status
}


proc action_notes { action portlist opts } {
    if {[require_portlist portlist]} {
        return 1
    }

    set status 0
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
            array unset portinfo
            array set portinfo [lindex $result 1]
            set porturl $portinfo(porturl)
        }
        
        # Add any global_variations to the variations
        # specified for the port
        array unset merged_variations
        array set merged_variations [array get variations]
        foreach { variation value } [array get global_variations] { 
            if { ![info exists merged_variations($variation)] } { 
                set merged_variations($variation) $value 
            } 
        }

        # Open the Portfile associated with this port.
        if {[catch {set mport [mportopen $porturl [array get options] \
                                         [array get merged_variations]]} \
                   result]} {
            ui_debug $::errorInfo
            break_softcontinue [concat "The URL '$porturl' could not be" \
                                       "opened: $result"] 1 status
        }
        array unset portinfo
        array set portinfo [mportinfo $mport]
        mportclose $mport

        # Return the notes associated with this Portfile.
        if {[info exists portinfo(notes)]} {
            set portnotes $portinfo(notes)
        } else {
            set portnotes {}
        }

        # Retrieve the port's name once more to ensure it has the proper case.
        set portname $portinfo(name)

        # Display the notes.
        if {![macports::ui_isset ports_quiet]} {
            if {$portnotes ne {}} {
                puts "$portname has the following notes:"
                puts [wrap $portnotes 0 "  " 1]
            } else {
                puts "$portname has no notes."
            }
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
        if {[file exists $file]} {
            if {![file isdirectory $file]} {
                set port [registry::file_registered $file]
                if { $port != 0 } {
                    puts "$file is provided by: $port"
                } else {
                    puts "$file is not provided by a MacPorts port."
                }
            } else {
                puts "$file is a directory."
            }
        } else {
            puts "$file does not exist."
        }
    }
    registry::close_file_map
    
    return 0
}


proc action_activate { action portlist opts } {
    set status 0
    if {[require_portlist portlist]} {
        return 1
    }
    foreachport $portlist {
        if {![macports::global_option_isset ports_dryrun]} {
            if { [catch {portimage::activate $portname [composite_version $portversion [array get variations]] [array get options]} result] } {
                global errorInfo
                ui_debug "$errorInfo"
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
    if {[require_portlist portlist]} {
        return 1
    }
    foreachport $portlist {
        if {![macports::global_option_isset ports_dryrun]} {
            if { [catch {portimage::deactivate $portname [composite_version $portversion [array get variations]] [array get options]} result] } {
                global errorInfo
                ui_debug "$errorInfo"
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

    # Error out if no group is specified.
    if {[llength $portlist] < 1} {
        ui_error "port select \[--list|--set|--show] <group> \[<version>]"
        return 1
    }
    set group [lindex $portlist 0]

    set commands [array names [array set {} $opts]]
    # If no command (--set, --show, --list) is specified *but* more than one
    # argument is specified, default to the set command.
    if {[llength $commands] < 1 && [llength $portlist] > 1} {
        set command set
        ui_debug [concat "Although no command was specified, more than " \
                         "one argument was specified.  Defaulting to the " \
                         "'set' command..."]
    # If no command (--set, --show, --list) is specified *and* less than two
    # argument are specified, default to the show command.
    } elseif {[llength $commands] < 1} {
        set command show
        ui_debug [concat "No command was specified. Defaulting to the " \
                         "'show' command..."]
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

            # On error mportselect returns with the code 'error'.
            if {[catch {mportselect $command $group} versions]} {
                ui_error "The 'list' command failed: $versions"
                return 1
            }

            puts "Available Versions:"
            foreach v $versions {
                puts "\t$v"
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

            puts -nonewline "Selecting '$version' for '$group' "
            if {[catch {mportselect $command $group $version} result]} {
                puts "failed: $result"
                return 1
            }
            puts "succeeded. '$version' is now active."
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
        default {
            ui_error "An unknown command '$command' was specified."
            return 1
        }
    }
}


proc action_selfupdate { action portlist opts } {
    global global_options
    if { [catch {macports::selfupdate [array get global_options]} result ] } {
        global errorInfo
        ui_debug "$errorInfo"
        fatal "port selfupdate failed: $result"
    }
    
    return 0
}


proc action_upgrade { action portlist opts } {
    if {[require_portlist portlist]} {
        return 1
    }
    # shared depscache for all ports in the list
    array set depscache {}
    set status 0
    foreachport $portlist {
        if {![info exists depscache(port:$portname)]} {
            set status [macports::upgrade $portname "port:$portname" [array get requested_variations] [array get options] depscache]
            if {$status != 0 && ![macports::ui_isset ports_processall]} {
                return $status
            }
        }
    }

    return $status
}


proc action_version { action portlist opts } {
    puts "Version: [macports::version]"
    return 0
}


proc action_platform { action portlist opts } {
#   global os.platform os.major os.arch 
    global tcl_platform
    set os_platform [string tolower $tcl_platform(os)]
    set os_version $tcl_platform(osVersion)
    set os_arch $tcl_platform(machine)
    if {$os_arch == "Power Macintosh"} { set os_arch "powerpc" }
    if {$os_arch == "i586" || $os_arch == "i686"} { set os_arch "i386" }
    set os_major [lindex [split $tcl_platform(osVersion) .] 0]
#   puts "Platform: ${os.platform} ${os.major} ${os.arch}"
    puts "Platform: ${os_platform} ${os_major} ${os_arch}"
    return 0
}


proc action_dependents { action portlist opts } {
    if {[require_portlist portlist]} {
        return 1
    }
    set ilist {}

    registry::open_dep_map

    set status 0
    foreachport $portlist {
        set composite_version [composite_version $portversion [array get variations]]
        if { [catch {set ilist [registry::installed $portname $composite_version]} result] } {
            global errorInfo
            ui_debug "$errorInfo"
            break_softcontinue "$result" 1 status
        } else {
            # set portname again since the one we were passed may not have had the correct case
            set portname [lindex [lindex $ilist 0] 0]
        }
        
        set deplist [registry::list_dependents $portname]
        if { [llength $deplist] > 0 } {
            set dl [list]
            # Check the deps first
            foreach dep $deplist {
                set depport [lindex $dep 2]
                if {![macports::ui_isset ports_verbose]} {
                    ui_msg "$depport depends on $portname"
                } else {
                    ui_msg "$depport depends on $portname (by [lindex $dep 1]:)"
                }
            }
        } else {
            ui_msg "$portname has no dependents!"
        }
    }
    return $status
}


proc action_uninstall { action portlist opts } {
    set status 0
    if {[macports::global_option_isset port_uninstall_old]} {
        # if -u then uninstall all inactive ports
        # (union these to any other ports user has in the port list)
        set portlist [opUnion $portlist [get_inactive_ports]]
    } else {
        # Otherwise the user hopefully supplied a portlist, or we'll default to the existing directory
        if {[require_portlist portlist]} {
            return 1
        }
    }

    foreachport $portlist {
        if {![registry::entry_exists_for_name $portname]} {
            ui_info "$portname is already uninstalled"
            continue
        }
        if { [catch {portuninstall::uninstall $portname [composite_version $portversion [array get variations]] [array get options]} result] } {
            global errorInfo
            ui_debug "$errorInfo"
            break_softcontinue "port uninstall failed: $result" 1 status
        }
    }

    return $status
}


proc action_installed { action portlist opts } {
    global private_options
    set status 0
    set restrictedList 0
    set ilist {}
    
    if { [llength $portlist] || (![info exists private_options(ports_no_args)] || $private_options(ports_no_args) == "no")} {
        set restrictedList 1
        foreachport $portlist {
            set composite_version [composite_version $portversion [array get variations]]
            if { [catch {set ilist [concat $ilist [registry::installed $portname $composite_version]]} result] } {
                if {![string match "* not registered as installed." $result]} {
                    global errorInfo
                    ui_debug "$errorInfo"
                    break_softcontinue "port installed failed: $result" 1 status
                }
            }
        }
    } else {
        if { [catch {set ilist [registry::installed]} result] } {
            if {$result != "Registry error: No ports registered as installed."} {
                global errorInfo
                ui_debug "$errorInfo"
                ui_error "port installed failed: $result"
                set status 1
            }
        }
    }
    if { [llength $ilist] > 0 } {
        if {![macports::ui_isset ports_quiet]} {
            puts "The following ports are currently installed:"
        }
        foreach i [portlist_sortint $ilist] {
            set iname [lindex $i 0]
            set iversion [lindex $i 1]
            set irevision [lindex $i 2]
            set ivariants [lindex $i 3]
            set iactive [lindex $i 4]
            if { $iactive == 0 } {
                puts "  $iname @${iversion}_${irevision}${ivariants}"
            } elseif { $iactive == 1 } {
                puts "  $iname @${iversion}_${irevision}${ivariants} (active)"
            }
        }
    } elseif { $restrictedList } {
        puts "None of the specified ports are installed."
    } else {
        puts "No ports are installed."
    }
    
    return $status
}


proc action_outdated { action portlist opts } {
    global macports::registry.installtype private_options
    set is_image_mode [expr 0 == [string compare "image" ${macports::registry.installtype}]]

    set status 0

    # If port names were supplied, limit ourselves to those ports, else check all installed ports
    set ilist {}
    set restrictedList 0
    if { [llength $portlist] || (![info exists private_options(ports_no_args)] || $private_options(ports_no_args) == "no")} {
        set restrictedList 1
        foreach portspec $portlist {
            array set port $portspec
            set portname $port(name)
            set composite_version [composite_version $port(version) $port(variants)]
            if { [catch {set ilist [concat $ilist [registry::installed $portname $composite_version]]} result] } {
                if {![string match "* not registered as installed." $result]} {
                    global errorInfo
                    ui_debug "$errorInfo"
                    break_softcontinue "port outdated failed: $result" 1 status
                }
            }
        }
    } else {
        if { [catch {set ilist [registry::installed]} result] } {
            if {$result != "Registry error: No ports registered as installed."} {
                global errorInfo
                ui_debug "$errorInfo"
                ui_error "port installed failed: $result"
                set status 1
            }
        }
    }

    set num_outdated 0
    if { [llength $ilist] > 0 } {   
        foreach i $ilist { 
        
            # Get information about the installed port
            set portname [lindex $i 0]
            set installed_version [lindex $i 1]
            set installed_revision [lindex $i 2]
            set installed_compound "${installed_version}_${installed_revision}"

            set is_active [lindex $i 4]
            if { $is_active == 0 && $is_image_mode } {
                continue
            }
            set installed_epoch [lindex $i 5]

            # Get info about the port from the index
            if {[catch {set res [mportlookup $portname]} result]} {
                global errorInfo
                ui_debug "$errorInfo"
                break_softcontinue "search for portname $portname failed: $result" 1 status
            }
            if {[llength $res] < 2} {
                if {[macports::ui_isset ports_debug]} {
                    puts "$portname ($installed_compound is installed; the port was not found in the port index)"
                }
                continue
            }
            array unset portinfo
            array set portinfo [lindex $res 1]
            
            # Get information about latest available version and revision
            if {![info exists portinfo(version)]} {
                ui_warn "$portname has no version field"
                continue
            }
            set latest_version $portinfo(version)
            set latest_revision 0
            if {[info exists portinfo(revision)] && $portinfo(revision) > 0} { 
                set latest_revision $portinfo(revision)
            }
            set latest_compound "${latest_version}_${latest_revision}"
            set latest_epoch 0
            if {[info exists portinfo(epoch)]} { 
                set latest_epoch $portinfo(epoch)
            }
            
            # Compare versions, first checking epoch, then version, then revision
            set comp_result [expr $installed_epoch - $latest_epoch]
            if { $comp_result == 0 } {
                set comp_result [rpm-vercomp $installed_version $latest_version]
                if { $comp_result == 0 } {
                    set comp_result [rpm-vercomp $installed_revision $latest_revision]
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
                
                    if { $num_outdated == 0 && ![macports::ui_isset ports_quiet]} {
                        puts "The following installed ports are outdated:"
                    }
                    incr num_outdated

                    puts [format "%-30s %-24s %1s" $portname "$installed_compound $relation $latest_compound" $flag]
                }
                
            }
        }
        
        if { $num_outdated == 0 && ![macports::ui_isset ports_quiet]} {
            puts "No installed ports are outdated."
        }
    } elseif { $restrictedList } {
        if {![macports::ui_isset ports_quiet]} {
            puts "None of the specified ports are outdated."
        }
    } else {
        if {![macports::ui_isset ports_quiet]} {
            puts "No ports are installed."
        }
    }
    
    return $status
}


proc action_contents { action portlist opts } {
    set status 0
    if {[require_portlist portlist]} {
        return 1
    }
    foreachport $portlist {
        if { ![catch {set ilist [registry::installed $portname]} result] } {
            # set portname again since the one we were passed may not have had the correct case
            set portname [lindex [lindex $ilist 0] 0]
        }
        set files [registry::port_registered $portname]
        if { $files != 0 } {
            if { [llength $files] > 0 } {
                if {![macports::ui_isset ports_quiet]} {
                    puts "Port $portname contains:"
                }
                foreach file $files {
                    puts "  $file"
                }
            } else {
                if {![macports::ui_isset ports_quiet]} {
                    puts "Port $portname does not contain any file or is not active."
                }
            }
        } else {
            if {![macports::ui_isset ports_quiet]} {
                puts "Port $portname is not installed."
            }
        }
    }
    registry::close_file_map

    return $status
}

proc action_variants { action portlist opts } {
    global global_variations
    set status 0
    if {[require_portlist portlist]} {
        return 1
    }
    foreachport $portlist {
        if {$porturl eq ""} {
            # look up port
            if {[catch {mportlookup $portname} result]} {
                global errorInfo
                ui_debug "$errorInfo"
                break_softcontinue "lookup of portname $portname failed: $result" 1 status
            }
            if {[llength $result] < 2} {
                break_softcontinue "Port $portname not found" 1 status
            }

            array unset portinfo
            array set portinfo [lindex $result 1]

            set porturl $portinfo(porturl)
            set portdir $portinfo(portdir)
        }

        if {!([info exists options(ports_variants_index)] && $options(ports_variants_index) eq "yes")} {
            if {[catch {set mport [mportopen $porturl [array get options] [array get variations]]} result]} {
                ui_debug "$::errorInfo"
                break_softcontinue "Unable to open port: $result" 1 status
            }
            array unset portinfo
            array set portinfo [mportinfo $mport]
            mportclose $mport
            if {[info exists portdir]} {
                set portinfo(portdir) $portdir
            }
        } elseif {![info exists portinfo]} {
            ui_warn "port variants --index does not work with 'current' pseudo-port"
            continue
        }

        # set portname again since the one we were passed may not have had the correct case
        set portname $portinfo(name)

        # if this fails the port doesn't have any variants
        if {![info exists portinfo(variants)]} {
            if {![macports::ui_isset ports_quiet]} {
                puts "$portname has no variants"
            }
        } else {
            array unset vinfo
            # Use the new format if it exists.
            if {[info exists portinfo(vinfo)]} {
                array set vinfo $portinfo(vinfo)
            # Otherwise fall back to the old format.
            } elseif {[info exists portinfo(variant_desc)]} {
                array set vdescriptions $portinfo(variant_desc)
            }

            # print out all the variants
            if {![macports::ui_isset ports_quiet]} {
                puts "$portname has the variants:"
            }
            foreach v [lsort $portinfo(variants)] {
                unset -nocomplain vconflicts vdescription vrequires
                # Retrieve variants' information from the new format.
                if {[info exists vinfo]} {
                    array unset variant
                    array set variant $vinfo($v)

                    # Retrieve conflicts, description, is_default, and
                    # vrequires.
                    if {[info exists variant(conflicts)]} {
                        set vconflicts $variant(conflicts)
                    }
                    if {[info exists variant(description)]} {
                        set vdescription $variant(description)
                    }

                    # XXX Keep these varmodifiers in sync with action_info, or create a wrapper for it
                    if {[info exists variations($v)]} {
                        set varmodifier "  $variations($v)"
                    } elseif {[info exists global_variations($v)]} {
                        # selected by variants.conf, prefixed with (+)/(-)
                        set varmodifier "($global_variations($v))"
                    } elseif {[info exists variant(is_default)]} {
                        set varmodifier "\[+]"
                    } else {
                        set varmodifier "   "
                    }
                    if {[info exists variant(requires)]} {
                        set vrequires $variant(requires)
                    }
                # Retrieve variants' information from the old format,
                # which only consists of the description.
                } elseif {[info exists vdescriptions($v)]} {
                    set vdescription $vdescriptions($v)
                }

                if {[info exists vdescription]} {
                    puts [wraplabel "$varmodifier$v" [string trim $vdescription] 0 [string repeat " " [expr 5 + [string length $v]]]]
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
    global private_options global_options
    set status 0
    if {![llength $portlist] && [info exists private_options(ports_no_args)] && $private_options(ports_no_args) == "yes"} {
        ui_error "You must specify a search pattern"
        return 1
    }

    # Copy global options as we are going to modify the array
    array set options [array get global_options]

    if {[info exists options(ports_search_depends)] && $options(ports_search_depends) == "yes"} {
        array unset options ports_search_depends
        set options(ports_search_depends_fetch) yes
        set options(ports_search_depends_extract) yes
        set options(ports_search_depends_build) yes
        set options(ports_search_depends_lib) yes
        set options(ports_search_depends_run) yes
    }

    # Array to hold given filters
    array set filters {}
    # Default matchstyle
    set filter_matchstyle "none"
    set filter_case no
    foreach { option } [array names options ports_search_*] {
        set opt [string range $option 13 end]

        if { $options($option) != "yes" } {
            continue
        }
        switch -- $opt {
            exact -
            glob -
            regex {
                set filter_matchstyle $opt
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

        set filters($opt) "yes"
    }
    # Set default search filter if none was given
    if { [array size filters] == 0 } {
        set filters(name) "yes"
        set filters(description) "yes"
    }

    set separator ""
    foreach portname $portlist {
        puts -nonewline $separator

        set searchstring $portname
        set matchstyle $filter_matchstyle
        if {$matchstyle == "none"} {
            # Guess if the given string was a glob expression, if not do a substring search
            if {[string first "*" $portname] == -1 && [string first "?" $portname] == -1} {
                set searchstring "*$portname*"
            }
            set matchstyle glob
        }

        set res {}
        set portfound 0
        foreach { opt } [array get filters] {
            # Map from friendly name
            set opt [map_friendly_field_names $opt]

            if {[catch {eval set matches \[mportsearch \$searchstring $filter_case $matchstyle $opt\]} result]} {
                global errorInfo
                ui_debug "$errorInfo"
                break_softcontinue "search for name $portname failed: $result" 1 status
            }

            set tmp {}
            foreach {name info} $matches {
                add_to_portlist tmp [concat [list name $name] $info]
            }
            set res [opUnion $res $tmp]
        }
        set res [portlist_sort $res]

        set joiner ""
        foreach info $res {
            array unset portinfo
            array set portinfo $info

            # XXX is this the right place to verify an entry?
            if {![info exists portinfo(name)]} {
                puts stderr "Invalid port entry, missing portname"
                continue
            }
            if {![info exists portinfo(description)]} {
                puts stderr "Invalid port entry for $portinfo(name), missing description"
                continue
            }
            if {![info exists portinfo(version)]} {
                puts stderr "Invalid port entry for $portinfo(name), missing version"
                continue
            }

            if {[macports::ui_isset ports_quiet]} {
                puts $portinfo(name)
            } else {
                if {[info exists options(ports_search_line)]
                        && $options(ports_search_line) == "yes"} {
                    puts "$portinfo(name)\t$portinfo(version)\t$portinfo(categories)\t$portinfo(description)"
                } else {
                    puts -nonewline $joiner

                    puts -nonewline "$portinfo(name) @$portinfo(version)"
                    if {[info exists portinfo(categories)]} {
                        puts -nonewline " ([join $portinfo(categories) ", "])"
                    }
                    puts ""
                    puts [wrap [join $portinfo(description)] 0 [string repeat " " 4]]
                }
            }

            set joiner "\n"
            set portfound 1
        }
        if { !$portfound } {
            if {![macports::ui_isset ports_quiet]} {
                ui_msg "No match for $portname found"
            }
        } elseif {[llength $res] > 1} {
            if {(![info exists global_options(ports_search_line)]
                    || $global_options(ports_search_line) != "yes")
                    && ![macports::ui_isset ports_quiet]} {
                ui_msg "\nFound [llength $res] ports."
            }
        }

        set separator "--\n"
    }

    array unset options
    array unset filters

    return $status
}


proc action_list { action portlist opts } {
    global private_options
    set status 0
    
    # Default to list all ports if no portnames are supplied
    if { ![llength $portlist] && [info exists private_options(ports_no_args)] && $private_options(ports_no_args) == "yes"} {
        add_to_portlist portlist [list name "-all-"]
    }
    
    foreachport $portlist {
        if {$portname == "-all-"} {
           if {[catch {set res [mportlistall]} result]} {
                global errorInfo
                ui_debug "$errorInfo"
                break_softcontinue "listing all ports failed: $result" 1 status
            }
        } else {
            set search_string [regex_pat_sanitize $portname]
            if {[catch {set res [mportsearch ^$search_string\$ no]} result]} {
                global errorInfo
                ui_debug "$errorInfo"
                break_softcontinue "search for portname $search_string failed: $result" 1 status
            }
        }

        foreach {name array} $res {
            array unset portinfo
            array set portinfo $array
            set outdir ""
            if {[info exists portinfo(portdir)]} {
                set outdir $portinfo(portdir)
            }
            puts [format "%-30s @%-14s %s" $portinfo(name) $portinfo(version) $outdir]
        }
    }
    
    return $status
}


proc action_echo { action portlist opts } {
    # Simply echo back the port specs given to this command
    foreachport $portlist {
        set opts {}
        foreach { key value } [array get options] {
            lappend opts "$key=$value"
        }
        
        set composite_version [composite_version $portversion [array get variations] 1]
        if { $composite_version != "" } {
            set ver_field "@$composite_version"
        } else {
            set ver_field ""
        }
        puts [format "%-30s %s %s" $portname $ver_field  [join $opts " "]]
    }
    
    return 0
}


proc action_portcmds { action portlist opts } {
    # Operations on the port's directory and Portfile
    global env boot_env
    global current_portdir

    array set local_options $opts
    
    set status 0
    if {[require_portlist portlist]} {
        return 1
    }
    foreachport $portlist {
        # If we have a url, use that, since it's most specific, otherwise try to map the portname to a url
        if {$porturl == ""} {
        
            # Verify the portname, getting portinfo to map to a porturl
            if {[catch {set res [mportlookup $portname]} result]} {
                global errorInfo
                ui_debug "$errorInfo"
                break_softcontinue "lookup of portname $portname failed: $result" 1 status
            }
            if {[llength $res] < 2} {
                break_softcontinue "Port $portname not found" 1 status
            }
            array set portinfo [lindex $res 1]
            set porturl $portinfo(porturl)
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
                
                ed - edit {
                    # Edit the port's portfile with the user's editor
                    
                    # Restore our entire environment from start time.
                    # We need it to evaluate the editor, and the editor
                    # may want stuff from it as well, like TERM.
                    array unset env_save; array set env_save [array get env]
                    array unset env *; unsetenv *; array set env [array get boot_env]
                    
                    # Find an editor to edit the portfile
                    set editor ""
                    if {[info exists local_options(ports_edit_editor)]} {
                        set editor [join $local_options(ports_edit_editor)]
                    } elseif {[info exists local_options(ports_ed_editor)]} {
                        set editor [join $local_options(ports_ed_editor)]
                    } else {
                        foreach ed { VISUAL EDITOR } {
                            if {[info exists env($ed)]} {
                                set editor $env($ed)
                                break
                            }
                        }
                    }
                    
                    # Invoke the editor, with a reasonable canned default.
                    if { $editor == "" } { set editor "/usr/bin/vi" }
                    if {[catch {eval exec >/dev/stdout </dev/stdin $editor $portfile} result]} {
                        global errorInfo
                        ui_debug "$errorInfo"
                        break_softcontinue "unable to invoke editor $editor: $result" 1 status
                    }
                    
                    # Restore internal MacPorts environment
                    array unset env *; unsetenv *; array set env [array get env_save]
                }

                dir {
                    # output the path to the port's directory
                    puts $portdir
                }

                work {
                    # output the path to the port's work directory
                    set workpath [macports::getportworkpath_from_portdir $portdir]
                    if {[file exists $workpath]} {
                        puts $workpath
                    }
                }

                cd {
                    # Change to the port's directory, making it the default
                    # port for any future commands
                    set current_portdir $portdir
                }

                url {
                    # output the url of the port's directory, suitable to feed back in later as a port descriptor
                    puts $porturl
                }

                file {
                    # output the path to the port's portfile
                    puts $portfile
                }

                gohome {
                    set homepage ""

                    # Get the homepage as read from PortIndex
                    if {[info exists portinfo(homepage)]} {
                        set homepage $portinfo(homepage)
                    }

                    # If not available, get the homepage for the port by opening the Portfile
                    if {$homepage == "" && ![catch {set ctx [mportopen $porturl]} result]} {
                        array set portinfo [mportinfo $ctx]
                        if {[info exists portinfo(homepage)]} {
                            set homepage $portinfo(homepage)
                        }
                        mportclose $ctx
                    }

                    # Try to open a browser to the homepage for the given port
                    if { $homepage != "" } {
                        system "${macports::autoconf::open_path} '$homepage'"
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
        global errorInfo
        ui_debug "$errorInfo"
        ui_msg "port sync failed: $result"
        set status 1
    }
    
    return $status
}


proc action_target { action portlist opts } {
    global global_variations
    set status 0
    if {[require_portlist portlist]} {
        return 1
    }
    foreachport $portlist {
        set target $action

        # If we have a url, use that, since it's most specific
        # otherwise try to map the portname to a url
        if {$porturl == ""} {
            # Verify the portname, getting portinfo to map to a porturl
            if {[catch {set res [mportlookup $portname]} result]} {
                global errorInfo
                ui_debug "$errorInfo"
                break_softcontinue "lookup of portname $portname failed: $result" 1 status
            }
            if {[llength $res] < 2} {
                # don't error for ports that are installed but not in the tree
                if {[registry::entry_exists_for_name $portname]} {
                    ui_warn "Skipping $portname (not in the ports tree)"
                    continue
                } else {
                    break_softcontinue "Port $portname not found" 1 status
                }
            }
            array unset portinfo
            array set portinfo [lindex $res 1]
            set porturl $portinfo(porturl)
        }
        
        # use existing variants iff none were explicitly requested
        if {[array get requested_variations] == "" && [array get variations] != ""} {
            array unset requested_variations
            array set requested_variations [array get variations]
            set filtered_variations [mport_filtervariants [array get variations] no]
        } else {
            set filtered_variations [mport_filtervariants [array get requested_variations] yes]
        }
        # Filter out implicit variants from the explicitly set/unset variants.
        # Except we need to keep them for some targets to work right...
        switch -exact $target {
            distfiles -
            mirror {}
            default {
                array unset requested_variations
                array set requested_variations $filtered_variations
            }
        }
        
        # Add any global_variations to the variations
        # specified for the port
        foreach { variation value } [array get global_variations] {
            if { ![info exists requested_variations($variation)] } {
                set requested_variations($variation) $value
            }
        }

        # If version was specified, save it as a version glob for use
        # in port actions (e.g. clean).
        if {[string length $portversion]} {
            set options(ports_version_glob) $portversion
        }
        if {[catch {set workername [mportopen $porturl [array get options] [array get requested_variations]]} result]} {
            global errorInfo
            ui_debug "$errorInfo"
            break_softcontinue "Unable to open port: $result" 1 status
        }
        if {[catch {set result [mportexec $workername $target]} result]} {
            global errorInfo
            mportclose $workername
            ui_debug "$errorInfo"
            break_softcontinue "Unable to execute port: $result" 1 status
        }

        mportclose $workername
        
        # Process any error that wasn't thrown and handled already
        if {$result} {
            break_softcontinue "Status $result encountered during processing." 1 status
        }
    }
    
    return $status
}


proc action_exit { action portlist opts } {
    # Return a semaphore telling the main loop to quit
    return -999
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


proc match s {
    if {[lookahead] == $s} {
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
# Use action_args_const to translate them
global action_array
proc action_args_const {arg} {
    switch -- $arg {
        none {
            return 0
        }
        strings {
            return 1
        }
        default -
        ports {
            return 2
        }
    }
}
array set action_array [list \
    usage       [list action_usage          [action_args_const strings]] \
    help        [list action_help           [action_args_const strings]] \
    \
    echo        [list action_echo           [action_args_const ports]] \
    \
    info        [list action_info           [action_args_const ports]] \
    location    [list action_location       [action_args_const ports]] \
    notes       [list action_notes          [action_args_const ports]] \
    provides    [list action_provides       [action_args_const strings]] \
    log         [list action_log            [action_args_const ports]] \
    \
    activate    [list action_activate       [action_args_const ports]] \
    deactivate  [list action_deactivate     [action_args_const ports]] \
    \
    select      [list action_select         [action_args_const strings]] \
    \
    sync        [list action_sync           [action_args_const none]] \
    selfupdate  [list action_selfupdate     [action_args_const none]] \
    \
    upgrade     [list action_upgrade        [action_args_const ports]] \
    \
    version     [list action_version        [action_args_const none]] \
    platform    [list action_platform       [action_args_const none]] \
    \
    uninstall   [list action_uninstall      [action_args_const ports]] \
    \
    installed   [list action_installed      [action_args_const ports]] \
    outdated    [list action_outdated       [action_args_const ports]] \
    contents    [list action_contents       [action_args_const ports]] \
    dependents  [list action_dependents     [action_args_const ports]] \
    deps        [list action_info           [action_args_const ports]] \
    variants    [list action_variants       [action_args_const ports]] \
    \
    search      [list action_search         [action_args_const strings]] \
    list        [list action_list           [action_args_const ports]] \
    \
    ed          [list action_portcmds       [action_args_const ports]] \
    edit        [list action_portcmds       [action_args_const ports]] \
    cat         [list action_portcmds       [action_args_const ports]] \
    dir         [list action_portcmds       [action_args_const ports]] \
    work        [list action_portcmds       [action_args_const ports]] \
    cd          [list action_portcmds       [action_args_const ports]] \
    url         [list action_portcmds       [action_args_const ports]] \
    file        [list action_portcmds       [action_args_const ports]] \
    gohome      [list action_portcmds       [action_args_const ports]] \
    \
    fetch       [list action_target         [action_args_const ports]] \
    checksum    [list action_target         [action_args_const ports]] \
    extract     [list action_target         [action_args_const ports]] \
    patch       [list action_target         [action_args_const ports]] \
    configure   [list action_target         [action_args_const ports]] \
    build       [list action_target         [action_args_const ports]] \
    destroot    [list action_target         [action_args_const ports]] \
    install     [list action_target         [action_args_const ports]] \
    clean       [list action_target         [action_args_const ports]] \
    test        [list action_target         [action_args_const ports]] \
    lint        [list action_target         [action_args_const ports]] \
    submit      [list action_target         [action_args_const ports]] \
    trace       [list action_target         [action_args_const ports]] \
    livecheck   [list action_target         [action_args_const ports]] \
    distcheck   [list action_target         [action_args_const ports]] \
    mirror      [list action_target         [action_args_const ports]] \
    load        [list action_target         [action_args_const ports]] \
    unload      [list action_target         [action_args_const ports]] \
    distfiles   [list action_target         [action_args_const ports]] \
    \
    archive     [list action_target         [action_args_const ports]] \
    unarchive   [list action_target         [action_args_const ports]] \
    dmg         [list action_target         [action_args_const ports]] \
    mdmg        [list action_target         [action_args_const ports]] \
    dpkg        [list action_target         [action_args_const ports]] \
    mpkg        [list action_target         [action_args_const ports]] \
    pkg         [list action_target         [action_args_const ports]] \
    portpkg     [list action_target         [action_args_const ports]] \
    rpm         [list action_target         [action_args_const ports]] \
    srpm        [list action_target         [action_args_const ports]] \
    \
    quit        [list action_exit           [action_args_const none]] \
    exit        [list action_exit           [action_args_const none]] \
]

proc find_action_proc { action } {
    global action_array
    
    set action_proc ""
    if { [info exists action_array($action)] } {
        set action_proc [lindex $action_array($action) 0]
    }
    
    return $action_proc
}

# Returns whether an action expects text arguments at all,
# expects text arguments or wants an expanded list of ports
# Return value:
#   0 none        Does not expect any text argument
#   1 strings     Expects some strings as text argument
#   2 ports       Wants an expanded list of ports as text argument
# Use action_args_const to translate them
proc action_needs_portlist { action } {
    global action_array

    set ret 0
    if {[info exists action_array($action)]} {
        set ret [lindex $action_array($action) 1]
    }

    return $ret
}

# cmd_opts_array specifies which arguments the commands accept
# Commands not listed here do not accept any arguments
# Syntax if {option argn}
# Where option is the name of the option and argn specifies how many arguments
# this argument takes
global cmd_opts_array
array set cmd_opts_array {
    edit        {{editor 1}}
    ed          {{editor 1}}
    info        {category categories depends_fetch depends_extract
                 depends_build depends_lib depends_run
                 depends description epoch fullname heading homepage index license
                 line long_description
                 maintainer maintainers name platform platforms portdir pretty
                 replaced_by revision variant variants version}
    search      {case-sensitive category categories depends_fetch
                 depends_extract depends_build depends_lib depends_run
                 depends description epoch exact glob homepage line
                 long_description maintainer maintainers name platform
                 platforms portdir regex revision variant variants version}
    selfupdate  {nosync}
    uninstall   {follow-dependents}
    variants    {index}
    clean       {all archive dist work logs}
    mirror      {new}
    lint        {nitpick}
    select      {list set show}
    log         {{phase 1} {verbosity 1}}
    upgrade     {force enforce-variants no-replace}
}

global cmd_implied_options
array set cmd_implied_options {
    deps   {ports_info_fullname yes ports_info_depends yes ports_info_pretty yes}
}
                                 

##
# Checks whether the given option is valid
#
# œparam action for which action
# @param option the option to check
# @param upoptargc reference to upvar for storing the number of arguments for
#                  this option
proc cmd_option_exists { action option {upoptargc ""}} {
    global cmd_opts_array
    upvar 1 $upoptargc optargc

    # This could be so easy with lsearch -index,
    # but that's only available as of Tcl 8.5

    if {![info exists cmd_opts_array($action)]} {
        return 0
    }

    foreach item $cmd_opts_array($action) {
        if {[llength $item] == 1} {
            set name $item
            set argc 0
        } else {
            set name [lindex $item 0]
            set argc [lindex $item 1]
        }

        if {$name == $option} {
            set optargc $argc
            return 1
        }
    }

    return 0
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
    global cmdname cmd_opts_array
    
    while {[moreargs]} {
        set arg [lookahead]
        
        if {[string index $arg 0] != "-"} {
            break
        } elseif {[string index $arg 1] == "-"} {
            # Process long arguments
            switch -- $arg {
                -- { # This is the options terminator; do no further option processing
                    advance; break
                }
                default {
                    set key [string range $arg 2 end]
                    set kargc 0
                    if {![cmd_option_exists $action $key kargc]} {
                        return -code error "${action} does not accept --${key}"
                    }
                    if {$kargc == 0} {
                        set global_options(ports_${action}_${key}) yes
                    } else {
                        set args {}
                        while {[moreargs] && $kargc > 0} {
                            advance
                            lappend args [lookahead]
                            set kargc [expr $kargc - 1]
                        }
                        if {$kargc > 0} {
                            return -code error "--${key} expects [expr $kargc + [llength $args]] parameters!"
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
                        set ui_options(ports_verbose) no
                        set ui_options(ports_debug) no
                    }
                    p {
                        # Ignore errors while processing within a command
                        set ui_options(ports_processall) yes
                    }
                    f {
                        set global_options(ports_force) yes
                    }
                    o {
                        set global_options(ports_ignore_older) yes
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
                            cd [lookahead]
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
}


proc process_cmd { argv } {
    global cmd_argc cmd_argv cmd_argn
    global global_options global_options_base private_options ui_options
    global current_portdir
    global cmd_implied_options
    set cmd_argv $argv
    set cmd_argc [llength $argv]
    set cmd_argn 0

    set action_status 0

    # Process an action if there is one
    while {($action_status == 0 || [macports::ui_isset ports_processall]) && [moreargs]} {
        set action [lookahead]
        advance
        
        # Handle command separator
        if { $action == ";" } {
            continue
        }
        
        # Handle a comment
        if { [string index $action 0] == "#" } {
            while { [moreargs] } { advance }
            break
        }
        
        # Always start out processing an action in current_portdir
        cd $current_portdir
        
        # Reset global_options from base before each action, as we munge it just below...
        array unset global_options
        array set global_options $global_options_base
        
        if {[info exists cmd_implied_options($action)]} {
            array set global_options $cmd_implied_options($action)
        }

        # Find an action to execute
        set action_proc [find_action_proc $action]
        if { $action_proc == "" } {
            puts "Unrecognized action \"$action\""
            set action_status 1
            break
        }

        # Parse options that will be unique to this action
        # (to avoid abiguity with -variants and a default port, either -- must be
        # used to terminate option processing, or the pseudo-port current must be specified).
        if {[catch {parse_options $action ui_options global_options} result]} {
            global errorInfo
            ui_debug "$errorInfo"
            ui_error $result
            set action_status 1
            break
        }

        # What kind of arguments does the command expect?
        set expand [action_needs_portlist $action]

        # Parse action arguments, setting a special flag if there were none
        # We otherwise can't tell the difference between arguments that evaluate
        # to the empty set, and the empty set itself.
        set portlist {}
        switch -- [lookahead] {
            ;       -
            _EOF_ {
                set private_options(ports_no_args) yes
            }
            default {
                if {[action_args_const none] == $expand} {
                    ui_error "$action does not accept string arguments"
                    set action_status 1
                    break
                } elseif {[action_args_const strings] == $expand} {
                    while { [moreargs] && ![match ";"] } {
                        lappend portlist [lookahead]
                        advance
                    }
                } elseif {[action_args_const ports] == $expand} {
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

        # semaphore to exit
        if {$action_status == -999} break
    }
    
    return $action_status
}


proc complete_portname { text state } { 
    global complete_choices complete_position
    
    if {$state == 0} {
        set complete_position 0
        set complete_choices {}

        # Build a list of ports with text as their prefix
        if {[catch {set res [mportsearch "${text}*" false glob]} result]} {
            global errorInfo
            ui_debug "$errorInfo"
            fatal "search for portname $pattern failed: $result"
        }
        foreach {name info} $res {
            lappend complete_choices $name
        }
    }
    
    set word [lindex $complete_choices $complete_position]
    incr complete_position
    
    return $word
}


proc complete_action { text state } {   
    global action_array
    global complete_choices complete_position

    if {$state == 0} {
        set complete_position 0
        set complete_choices [array names action_array "[string tolower $text]*"]
    }

    set word [lindex $complete_choices $complete_position]
    incr complete_position

    return $word
}


proc attempt_completion { text word start end } {
    # If the word starts with '~', or contains '.' or '/', then use the build-in
    # completion to complete the word
    if { [regexp {^~|[/.]} $word] } {
        return ""
    }

    # Decide how to do completion based on where we are in the string
    set prefix [string range $text 0 [expr $start - 1]]
    
    # If only whitespace characters preceed us, or if the
    # previous non-whitespace character was a ;, then we're
    # an action (the first word of a command)
    if { [regexp {(^\s*$)|(;\s*$)} $prefix] } {
        return complete_action
    }
    
    # Otherwise, do completion on portname
    return complete_portname
}


proc get_next_cmdline { in out use_readline prompt linename } {
    upvar $linename line
    
    set line ""
    while { $line == "" } {

        if {$use_readline} {
            set len [readline read -attempted_completion attempt_completion line $prompt]
        } else {
            puts -nonewline $out $prompt
            flush $out
            set len [gets $in line]
        }

        if { $len < 0 } {
            return -1
        }
        
        set line [string trim $line]

        if { $use_readline && $line != "" } {
            rl_history add $line
        }
    }
    
    return [llength $line]
}


proc process_command_file { in } {
    global current_portdir

    # Initialize readline
    set isstdin [string match $in "stdin"]
    set name "port"
    set use_readline [expr $isstdin && [readline init $name]]
    set history_file [file normalize "${macports::macports_user_dir}/history"]

    # Read readline history
    if {$use_readline && [file isdirectory $macports::macports_user_dir]} {
        rl_history read $history_file
        rl_history stifle 100
    }

    # Be noisy, if appropriate
    set noisy [expr $isstdin && ![macports::ui_isset ports_quiet]]
    if { $noisy } {
        puts "MacPorts [macports::version]"
        puts "Entering interactive mode... (\"help\" for help, \"quit\" to quit)"
    }

    # Main command loop
    set exit_status 0
    while { $exit_status == 0 || [macports::ui_isset ports_processall] } {

        # Calculate our prompt
        if { $noisy } {
            set shortdir [eval file join [lrange [file split $current_portdir] end-1 end]]
            set prompt "\[$shortdir\] > "
        } else {
            set prompt ""
        }

        # Get a command line
        if { [get_next_cmdline $in stdout $use_readline $prompt line] <= 0  } {
            puts ""
            break
        }

        # Process the command
        set exit_status [process_cmd $line]
        
        # Check for semaphore to exit
        if {$exit_status == -999} {
            set exit_status 0
            break
        }
    }

    # Create macports user directory if it does not exist yet
    if {$use_readline && ![file isdirectory $macports::macports_user_dir]} {
        file mkdir $macports::macports_user_dir
    }
    # Save readine history
    if {$use_readline && [file isdirectory $macports::macports_user_dir]} {
        rl_history write $history_file
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
        if {$file == "-"} {
            set in stdin
        } else {
            if {[catch {set in [open $file]} result]} {
                fatal "Failed to open command file; $result"
            }
        }

        set exit_status [process_command_file $in]

        if {$in != "stdin"} {
            close $in
        }

        # Exit on first failure unless -p was given
        if {$exit_status != 0 && ![macports::ui_isset ports_processall]} {
            return $exit_status
        }
    }

    return $exit_status
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
global env boot_env
array set boot_env [array get env]

global argv0
global cmdname
set cmdname [file tail $argv0]

# Setp cmd_argv to match argv
global argc argv
global cmd_argc cmd_argv cmd_argn
set cmd_argv $argv
set cmd_argc $argc
set cmd_argn 0

# make sure we're using a sane umask
umask 022

# If we've been invoked as portf, then the first argument is assumed
# to be the name of a command file (i.e., there is an implicit -F
# before any arguments).
if {[moreargs] && $cmdname == "portf"} {
    lappend ui_options(ports_commandfiles) [lookahead]
    advance
}

# Parse global options that will affect all subsequent commands
if {[catch {parse_options "global" ui_options global_options} result]} {
    puts "Error: $result"
    print_usage
    exit 1
}

# Get arguments remaining after option processing
set remaining_args [lrange $cmd_argv $cmd_argn end]

# Initialize mport
# This must be done following parse of global options, as some options are
# evaluated by mportinit.
if {[catch {mportinit ui_options global_options global_variations} result]} {
    global errorInfo
    puts "$errorInfo"
    fatal "Failed to initialize MacPorts, $result"
}

# If we have no arguments remaining after option processing then force
# interactive mode
if { [llength $remaining_args] == 0 && ![info exists ui_options(ports_commandfiles)] } {
    lappend ui_options(ports_commandfiles) -
}

# Set up some global state for our code
global current_portdir
set current_portdir [pwd]

# Freeze global_options into global_options_base; global_options
# will be reset to global_options_base prior to processing each command.
global global_options_base
set global_options_base [array get global_options]

# First process any remaining args as action(s)
global exit_status
set exit_status 0
if { [llength $remaining_args] > 0 } {

    # If there are remaining arguments, process those as a command
    set exit_status [process_cmd $remaining_args]
}

# Process any prescribed command files, including standard input
if { ($exit_status == 0 || [macports::ui_isset ports_processall]) && [info exists ui_options(ports_commandfiles)] } {
    set exit_status [process_command_files $ui_options(ports_commandfiles)]
}

# Return with exit_status
exit $exit_status
