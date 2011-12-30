# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# portuninstall.tcl
# $Id$
#
# Copyright (c) 2004-2005, 2008-2011 The MacPorts Project
# Copyright (c) 2002 - 2003 Apple Inc.
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

package provide registry_uninstall 2.0

package require registry 1.0
package require registry2 2.0
package require registry_util 2.0

set UI_PREFIX "---> "

namespace eval registry_uninstall {

# takes a composite version spec rather than separate version,revision,variants
proc uninstall_composite {portname {v ""} {optionslist ""}} {
    if {$v == ""} {
        return [uninstall $portname "" "" 0 $optionslist]
    } elseif {[registry::decode_spec $v version revision variants]} {
        return [uninstall $portname $version $revision $variants $optionslist]
    }
    throw registry::invalid "Registry error: Invalid version '$v' specified for ${portname}. Please specify a version as recorded in the port registry."
}

proc uninstall {portname {version ""} {revision ""} {variants 0} {optionslist ""}} {
    global uninstall.force uninstall.nochecksum UI_PREFIX \
           macports::portimagefilepath
    array set options $optionslist
    if {[info exists options(subport)]} {
        # don't want this set when calling registry::run_target
        unset options(subport)
        set optionslist [array get options]
    }

    if {![info exists uninstall.force]} {
        set uninstall.force no
    }
    # If global forcing is on, make it the same as a local force flag.
    if {[info exists options(ports_force)] && [string is true -strict $options(ports_force)]} {
        set uninstall.force yes
    }
    # if no-exec is set for uninstall, set for deactivate too
    if {[info exists options(ports_uninstall_no-exec)]} {
        set options(ports_deactivate_no-exec) $options(ports_uninstall_no-exec)
    }

    set searchkeys $portname
    set composite_spec ""
    if {$version != ""} {
        lappend searchkeys $version
        set composite_spec $version
        # restriction imposed by underlying registry API (see entry.c):
        # if a revision is specified, so must variants be
        if {$revision != ""} {
            lappend searchkeys $revision $variants
            append composite_spec _${revision}${variants}
        }
    }
    set ilist [eval registry::entry imaged $searchkeys]
    if { [llength $ilist] > 1 } {
        # set portname again since the one we were passed may not have had the correct case
        set portname [[lindex $ilist 0] name]
        ui_msg "$UI_PREFIX [msgcat::mc "The following versions of $portname are currently installed:"]"
        foreach i [portlist_sortint $ilist] {
            set ispec "[$i version]_[$i revision][$i variants]"
            if { [string equal [$i state] installed] } {
                ui_msg "$UI_PREFIX [format [msgcat::mc "    %s @%s (active)"] [$i name] $ispec]"
            } else {
                ui_msg "$UI_PREFIX [format [msgcat::mc "    %s @%s"] [$i name] $ispec]"
            }
        }
        throw registry::invalid "Registry error: Please specify the full version as recorded in the port registry."
    } elseif { [llength $ilist] == 1 } {
        set port [lindex $ilist 0]
        set version [$port version]
        set revision [$port revision]
        set variants [$port variants]
        set composite_spec "${version}_${revision}${variants}"
    } else {
        if {$composite_spec != ""} {
            set composite_spec " @${composite_spec}"
        }
        throw registry::invalid "Registry error: ${portname}${composite_spec} not registered as installed"
    }

    # uninstall dependents if requested
    if {[info exists options(ports_uninstall_follow-dependents)] && $options(ports_uninstall_follow-dependents) eq "yes"} {
        # don't uninstall dependents' dependencies
        if {[info exists options(ports_uninstall_follow-dependencies)]} {
            set orig_follow_dependencies $options(ports_uninstall_follow-dependencies)
            unset options(ports_uninstall_follow-dependencies)
            set optionslist [array get options]
        }
        foreach depport [$port dependents] {
            # make sure it's still installed, since a previous dep uninstall may have removed it
            if {[registry::entry exists $depport] && ([$depport state] == "imaged" || [$depport state] == "installed")} {
                if {[info exists options(ports_uninstall_no-exec)] || ![registry::run_target $depport uninstall $optionslist]} {
                    registry_uninstall::uninstall [$depport name] [$depport version] [$depport revision] [$depport variants] $optionslist
                }
            }
        }
        if {[info exists orig_follow_dependencies]} {
            set options(ports_uninstall_follow-dependencies) $orig_follow_dependencies
            set optionslist [array get options]
        }
    } else {
        # check its dependents
        registry::check_dependents $port ${uninstall.force} "uninstall"
    }
    # if it's active, deactivate it
    if { [string equal [$port state] installed] } {
        if {[info exists options(ports_dryrun)] && [string is true -strict $options(ports_dryrun)]} {
            ui_msg "For $portname @${composite_spec}: skipping deactivate (dry run)"
        } else {
            if {[info exists options(ports_uninstall_no-exec)] || ![registry::run_target $port deactivate $optionslist]} {
                portimage::deactivate $portname $version $revision $variants [array get options]
            }
        }
    }

    set ref $port

    # note deps before we uninstall if we're going to uninstall them too
    if {[info exists options(ports_uninstall_follow-dependencies)] && [string is true -strict $options(ports_uninstall_follow-dependencies)]} {
        set deptypes {depends_fetch depends_extract depends_build depends_lib depends_run}
        set all_dependencies {}
        # look up deps from the saved portfile if possible
        if {![catch {set mport [mportopen_installed [$port name] [$port version] [$port revision] [$port variants] $optionslist]}]} {
            array set depportinfo [mportinfo $mport]
            mportclose_installed $mport
            foreach type $deptypes {
                if {[info exists depportinfo($type)]} {
                    foreach dep $depportinfo($type) {
                        lappend all_dependencies [lindex [split $dep :] end]
                    }
                }
            }
            # append those from the registry (could be different because of path deps)
            foreach dep [$port dependencies] {
                lappend all_dependencies [$dep name]
            }
        } else {
            # grab the deps from the dep map
            set depmaplist [registry::list_depends $portname $version $revision $variants]
            foreach dep $depmaplist {
                lappend all_dependencies [lindex $dep 0]
            }
            # and the ones from the current portfile
            if {![catch {mportlookup $portname} result] && [llength $result] >= 2} {
                array set depportinfo [lindex $result 1]
                set porturl $depportinfo(porturl)
                set variations {}
                set minusvariant [lrange [split [registry::property_retrieve $ref negated_variants] -] 1 end]
                set plusvariant [lrange [split $variants +] 1 end]
                foreach v $plusvariant {
                    lappend variations $v "+"
                }
                foreach v $minusvariant {
                    lappend variations $v "-"
                }
                if {![catch {set mport [mportopen $porturl [concat $optionslist subport $portname] [array get variations]]} result]} {
                    array unset depportinfo
                    array set depportinfo [mportinfo $mport]
                    mportclose $mport
                }
                foreach type $deptypes {
                    if {[info exists depportinfo($type)]} {
                        foreach dep $depportinfo($type) {
                            lappend all_dependencies [lindex [split $dep :] end]
                        }
                    }
                }
            }
        }
        array unset depportinfo
        set all_dependencies [lsort -unique $all_dependencies]
    }

    if {[info exists options(ports_dryrun)] && [string is true -strict $options(ports_dryrun)]} {
        ui_msg "For $portname @${composite_spec}: skipping uninstall (dry run)"
    } else {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Uninstalling %s @%s"] $portname $composite_spec]"

        # Get the full path to the image file
        set imagefile [registry::property_retrieve $ref location]
        file delete $imagefile
        # Try to delete the port's image dir; will fail if there are more image
        # files so just ignore the failure
        catch {file delete [::file dirname $imagefile]}

        registry::entry delete $port
    }
    
    # uninstall dependencies if requested
    if {[info exists options(ports_uninstall_follow-dependencies)] && [string is true -strict $options(ports_uninstall_follow-dependencies)]} {
        # don't uninstall dependencies' dependents
        if {[info exists options(ports_uninstall_follow-dependents)]} {
            unset options(ports_uninstall_follow-dependents)
            set optionslist [array get options]
        }
        while 1 {
            set remaining_list {}
            foreach dep $all_dependencies {
                if {![catch {set ilist [registry::installed $dep]}]} {
                    set remaining 0
                    foreach i $ilist {
                        set iversion [lindex $i 1]
                        set irevision [lindex $i 2]
                        set ivariants [lindex $i 3]
                        if {[llength [registry::list_dependents $dep $iversion $irevision $ivariants]] == 0} {
                            set regref [registry::open_entry $dep $iversion $irevision $ivariants [lindex $i 5]]
                            if {![registry::property_retrieve $regref requested] && ([info exists options(ports_uninstall_no-exec)] || ![registry::run_target $regref uninstall $optionslist])} {
                                registry_uninstall::uninstall $dep $iversion $irevision $ivariants $optionslist
                            }
                        } else {
                            set remaining 1
                        }
                    }
                    if {$remaining} {
                        lappend remaining_list $dep
                    }
                }
            }
            if {[llength $remaining_list] == 0 || [llength $remaining_list] == [llength $all_dependencies]} {
                break
            }
            set all_dependencies $remaining_list
        }
    }
    
    return 0
}

# End of registry_uninstall namespace
}
