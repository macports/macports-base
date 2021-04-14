# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# portuninstall.tcl
#
# Copyright (c) 2004-2005, 2008-2011, 2014-2015 The MacPorts Project
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

# generate list of all dependencies of the port
proc generate_deplist {port {optslist ""}} {

    set deptypes {depends_fetch depends_extract depends_build depends_lib depends_run depends_test}
    set all_dependencies [list]
    # look up deps from the saved portfile if possible
    if {![catch {set mport [mportopen_installed [$port name] [$port version] [$port revision] [$port variants] $optslist]}]} {
        array set depportinfo [mportinfo $mport]
        mportclose $mport
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
        set portname [$port name]
        set depmaplist [registry::list_depends $portname [$port version] [$port revision] [$port variants]]
        foreach dep $depmaplist {
            lappend all_dependencies [lindex $dep 0]
        }
        # and the ones from the current portfile
        if {![catch {mportlookup $portname} result] && [llength $result] >= 2} {
            array set depportinfo [lindex $result 1]
            set porturl $depportinfo(porturl)
            set variations [list]
            # Relies on all negated variants being at the end of requested_variants
            set minusvariant [lrange [split [registry::property_retrieve $port requested_variants] -] 1 end]
            set plusvariant [lrange [split [$port variants] +] 1 end]
            foreach v $plusvariant {
                lappend variations $v "+"
            }
            foreach v $minusvariant {
                if {[string first "+" $v] == -1} {
                    lappend variations $v "-"
                } else {
                    ui_warn "Invalid negated variant for $portname @[$port version]_[$port revision][$port variants]: $v"
                }
                
            }
            if {![catch {set mport [mportopen $porturl [concat $optslist subport $portname] [array get variations]]} result]} {
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
    set all_dependencies [lsort -unique $all_dependencies]
    return $all_dependencies
}

# takes a composite version spec rather than separate version,revision,variants
proc uninstall_composite {portname {v ""} {optionslist ""}} {
    if {$v eq ""} {
        return [uninstall $portname "" "" 0 $optionslist]
    } elseif {[registry::decode_spec $v version revision variants]} {
        return [uninstall $portname $version $revision $variants $optionslist]
    }
    throw registry::invalid "Registry error: Invalid version '$v' specified for ${portname}. Please specify a version as recorded in the port registry."
}

proc uninstall {portname {version ""} {revision ""} {variants 0} {optionslist ""}} {
    global uninstall.force UI_PREFIX macports::registry.path
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
    if {$version ne ""} {
        lappend searchkeys $version
        set composite_spec $version
        # restriction imposed by underlying registry API (see entry.c):
        # if a revision is specified, so must variants be
        if {$revision ne ""} {
            lappend searchkeys $revision $variants
            append composite_spec _${revision}${variants}
        }
    }
    set ilist [registry::entry imaged {*}$searchkeys]
    if { [llength $ilist] > 1 } {
        # set portname again since the one we were passed may not have had the correct case
        set portname [[lindex $ilist 0] name]
        set msg "The following versions of $portname are currently installed:"
        if {[macports::ui_isset ports_noninteractive]} {
            ui_msg "$UI_PREFIX [msgcat::mc $msg]"
        }
        set sortedlist [portlist_sortint $ilist]
        foreach i $sortedlist {
            set portstr [format "%s @%s_%s%s" [$i name] [$i version] [$i revision] [$i variants]]
            if {[$i state] eq "installed"} {
                append portstr [msgcat::mc " (active)"]
            }

            if {[info exists macports::ui_options(questions_multichoice)]} {
                lappend portilist "$portstr"
            } else {
                ui_msg "$UI_PREFIX     $portstr"
            }
        }
        if {[info exists macports::ui_options(questions_multichoice)]} {
            set retstring [$macports::ui_options(questions_multichoice) $msg "Choice_Q2" $portilist]
            foreach index $retstring {
                set uport [lindex $sortedlist $index]
                uninstall [$uport name] [$uport version] [$uport revision] [$uport variants]
            }
            return 0
        }
        throw registry::invalid "Registry error: Please specify the full version as recorded in the port registry."
    } elseif { [llength $ilist] == 1 } {
        set port [lindex $ilist 0]
        set version [$port version]
        set revision [$port revision]
        set variants [$port variants]
        set composite_spec "${version}_${revision}${variants}"
    } else {
        if {$composite_spec ne ""} {
            set composite_spec " @${composite_spec}"
        }
        throw registry::invalid "Registry error: ${portname}${composite_spec} not registered as installed"
    }

    set userinput {}
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
            if {[registry::entry exists $depport] && ([$depport state] eq "imaged" || [$depport state] eq "installed")} {
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
        set userinput [registry::check_dependents $port ${uninstall.force} "uninstall"]
        if {$userinput eq "quit"} {
            return 0
        }
    }
    # if it's active, deactivate it
    if {[$port state] eq "installed"} {
        if {[info exists options(ports_dryrun)] && [string is true -strict $options(ports_dryrun)]} {
            ui_msg "For $portname @${composite_spec}: skipping deactivate (dry run)"
        } else {
            if {$userinput eq "forcedbyuser"} {
                set options(ports_nodepcheck) "yes"
            }
            if {[info exists options(ports_uninstall_no-exec)] || ![registry::run_target $port deactivate [array get options]]} {
                if {$userinput eq "forcedbyuser"} {
                    portimage::deactivate $portname $version $revision $variants [array get options]
                    unset options(ports_nodepcheck) 
                } else {
                    portimage::deactivate $portname $version $revision $variants [array get options]
                }
            }
        }
    }

    # note deps before we uninstall if we're going to uninstall them too (i.e. --follow-dependencies)
    if {[info exists options(ports_uninstall_follow-dependencies)] && [string is true -strict $options(ports_uninstall_follow-dependencies)]} {
        set all_dependencies [registry_uninstall::generate_deplist $port $optionslist]
    }

    if {[info exists options(ports_dryrun)] && [string is true -strict $options(ports_dryrun)]} {
        ui_msg "For $portname @${composite_spec}: skipping uninstall (dry run)"
        # allow deps to not be excluded from the list below just because this port is still a dependent
        if {[info exists options(ports_uninstall_follow-dependencies)] && [string is true -strict $options(ports_uninstall_follow-dependencies)]} {
            set uports [list [list $portname $version $revision $variants]]
        }
    } else {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Uninstalling %s @%s"] $portname $composite_spec]"

        # Get the full path to the image file
        set ref $port
        set imagefile [registry::property_retrieve $ref location]
        file delete $imagefile
        # Try to delete the port's image dir; will fail if there are more image
        # files so just ignore the failure
        catch {file delete [::file dirname $imagefile]}

        # We want to delete the portfile if not referenced by any other ports
        set portfile [$ref portfile]

        # and likewise the portgroups
        set portgroups [list]
        foreach pg [$ref groups_used] {
            lappend portgroups [list [$pg name] [$pg version] [$pg size] [$pg sha256]]
        }

        registry::write {
            registry::entry delete $port
        }

        set portfile_path [file join ${registry.path} registry portfiles ${portname}-${version}_${revision} $portfile]
        if {[registry::entry search portfile $portfile name $portname version $version revision $revision] eq {}} {
            file delete -force $portfile_path
            catch {file delete [file dirname $portfile_path]}
        }

        set reg_portgroups_dir [file join ${registry.path} registry portgroups]
        foreach pg $portgroups {
            set pgname [lindex $pg 0]
            set pgversion [lindex $pg 1]
            set pgsize [lindex $pg 2]
            set pgsha256 [lindex $pg 3]
            if {[registry::portgroup search name $pgname version $pgversion size $pgsize sha256 $pgsha256] eq {}} {
                set pg_reg_dir [file join $reg_portgroups_dir ${pgsha256}-${pgsize}]
                file delete -force ${pg_reg_dir}/${pgname}-${pgversion}.tcl
                catch {file delete $pg_reg_dir}
            }
        }
    }

    if {![info exists uports]} {
        set uports [list]
    }
    # create list of all dependencies that will be uninstalled, if requested
    if {[info exists options(ports_uninstall_follow-dependencies)] && [string is true -strict $options(ports_uninstall_follow-dependencies)]} {
        set alldeps $all_dependencies
        set portilist [list]
        for {set j 0} {$j < [llength $alldeps]} {incr j} {
            set dep [lindex $alldeps $j]
            set uninstalling_this_dep 0
            if {![catch {set ilist [registry::installed $dep]}]} {
                foreach i $ilist {
                    lassign $i dep iversion irevision ivariants
                    if {[list $dep $iversion $irevision $ivariants] in $uports} {
                        continue
                    }
                    set regref [registry::open_entry $dep $iversion $irevision $ivariants [lindex $i 5]]
                    if {![registry::property_retrieve $regref requested]} {
                        set all_dependents_uninstalling 1
                        foreach depdt [$regref dependents] {
                            if {[list [$depdt name] [$depdt version] [$depdt revision] [$depdt variants]] ni $uports} {
                                set all_dependents_uninstalling 0
                                break
                            }
                        }
                        if {$all_dependents_uninstalling} {
                            lappend uports [list $dep $iversion $irevision $ivariants]
                            lappend portilist $dep@${iversion}_${irevision}${ivariants}
                            set uninstalling_this_dep 1
                        }
                    }
                }
            }
            if {$uninstalling_this_dep} {
                set deprefs [registry::entry imaged $dep]
                foreach depref $deprefs {
                    set depdeps [registry_uninstall::generate_deplist $depref $optionslist]
                    foreach d $depdeps {
                        if {$d ni [lrange $alldeps $j+1 end]} {
                            lappend alldeps $d 
                        }
                    }
                }
            }
        }
        ## User Interaction Question
        # show a list of all dependencies to be uninstalled with a timeout when --follow-dependencies is specified
        if {[info exists macports::ui_options(questions_yesno)] && [llength $uports] > 0 && !([info exists options(ports_dryrun)] && [string is true -strict $options(ports_dryrun)])} {
            $macports::ui_options(questions_yesno) "The following dependencies will be uninstalled:" "Timeout_1" $portilist {y} 10
        }
        unset options(ports_uninstall_follow-dependencies)
    }

    # uninstall all dependencies in order from uports
    foreach dp $uports {
        lassign $dp iname iversion irevision ivariants
        if {![catch {registry::open_entry $iname $iversion $irevision $ivariants ""} regref]} {
            if {[info exists options(ports_dryrun)] && [string is true -strict $options(ports_dryrun)]} {
                if {$iname ne $portname} {
                    ui_msg "For $iname @${iversion}_${irevision}${ivariants}: skipping uninstall (dry run)"
                }
            } else {
                if {[info exists options(ports_uninstall_no-exec)] || ![registry::run_target $regref uninstall [array get options]]} {
                    registry_uninstall::uninstall $iname $iversion $irevision $ivariants [array get options]
                }
            }
        }
    }

    return 0
}

# End of registry_uninstall namespace
}
