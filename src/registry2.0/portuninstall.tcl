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

namespace eval registry_uninstall {

variable UI_PREFIX {---> }

# generate list of all dependencies of the port
proc generate_deplist {port {optslist ""}} {

    set deptypes [list depends_fetch depends_extract depends_patch depends_build depends_lib depends_run depends_test]
    set all_dependencies [list]
    # look up deps from the saved portfile if possible
    if {![catch {set mport [mportopen_installed [$port name] [$port version] [$port revision] [$port variants] $optslist]}]} {
        set depportinfo [mportinfo $mport]
        mportclose $mport
        foreach type $deptypes {
            if {[dict exists $depportinfo $type]} {
                foreach dep [dict get $depportinfo $type] {
                    lappend all_dependencies [lindex [split $dep :] end]
                }
            }
        }
        # append those from the registry (could be different because of path deps)
        foreach dep [$port dependencies] {
            lappend all_dependencies [$dep name]
            #registry::entry close $dep
        }
    } else {
        # grab the deps from the dep map
        foreach dep [$port dependencies] {
            lappend all_dependencies [$dep name]
            #registry::entry close $dep
        }
        set portname [$port name]
        # and the ones from the current portfile
        if {![catch {mportlookup $portname} result] && [llength $result] >= 2} {
            set depportinfo [lindex $result 1]
            set porturl [dict get $depportinfo porturl]
            set variations [dict create]
            # Relies on all negated variants being at the end of requested_variants
            set minusvariant [lrange [split [$port requested_variants] -] 1 end]
            set plusvariant [lrange [split [$port variants] +] 1 end]
            foreach v $plusvariant {
                dict set variations $v "+"
            }
            foreach v $minusvariant {
                if {[string first "+" $v] == -1} {
                    dict set variations $v "-"
                } else {
                    ui_warn "Invalid negated variant for $portname @[$port version]_[$port revision][$port variants]: $v"
                }
                
            }
            dict set optslist subport $portname
            if {![catch {set mport [mportopen $porturl $optslist $variations]} result]} {
                set depportinfo [mportinfo $mport]
                mportclose $mport
            }
            foreach type $deptypes {
                if {[dict exists $depportinfo $type]} {
                    foreach dep [dict get $depportinfo $type] {
                        lappend all_dependencies [lindex [split $dep :] end]
                    }
                }
            }
        }
    }
    return [lsort -unique $all_dependencies]
}

proc cmp_regrefs {a b} {
    set byname [string compare -nocase [$a name] [$b name]]
    if {$byname != 0} {
        return $byname
    }
    set byvers [vercmp [$a version] [$b version]]
    if {$byvers != 0} {
        return $byvers
    }
    set byrevision [expr {[$a revision] - [$b revision]}]
    if {$byrevision != 0} {
        return $byrevision
    }
    return [string compare -nocase [$a variants] [$b variants]]
}

# takes a composite version spec rather than separate version,revision,variants
proc uninstall_composite {portname {v ""} {options ""}} {
    if {$v eq ""} {
        return [uninstall $portname "" "" 0 $options]
    } elseif {[registry::decode_spec $v version revision variants]} {
        return [uninstall $portname $version $revision $variants $options]
    }
    throw registry::invalid "Registry error: Invalid version '$v' specified for ${portname}. Please specify a version as recorded in the port registry."
}

proc uninstall {portname {version ""} {revision ""} {variants 0} {options ""}} {
    variable UI_PREFIX

    if {[dict exists $options subport]} {
        # don't want this set when calling registry::run_target
        dict unset options subport
    }
    if {[dict exists $options ports_force]} {
         set force [dict get $options ports_force]
    } else {
        set force no
    }
    # if no-exec is set for uninstall, set for deactivate too
    if {[dict exists $options ports_uninstall_no-exec]} {
        dict set options ports_deactivate_no-exec [dict get $options ports_uninstall_no-exec]
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
        set sortedlist [lsort -command cmp_regrefs $ilist]
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
                uninstall [$uport name] [$uport version] [$uport revision] [$uport variants] $options
            }
            #foreach i $ilist {
            #    registry::entry close $i
            #}
            return 0
        }
        #foreach i $ilist {
        #    registry::entry close $i
        #}
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
    if {[dict exists $options ports_uninstall_follow-dependents] && [dict get $options ports_uninstall_follow-dependents] eq "yes"} {
        # don't uninstall dependents' dependencies
        if {[dict exists $options ports_uninstall_follow-dependencies]} {
            set orig_follow_dependencies [dict get $options ports_uninstall_follow-dependencies]
            dict unset options ports_uninstall_follow-dependencies
        }
        foreach depport [$port dependents] {
            # make sure it's still installed, since a previous dep uninstall may have removed it
            if {[registry::entry exists $depport] && ([$depport state] eq "imaged" || [$depport state] eq "installed")} {
                if {[dict exists $options ports_uninstall_no-exec] || ![registry::run_target $depport uninstall $options]} {
                    uninstall [$depport name] [$depport version] [$depport revision] [$depport variants] $options
                }
            }
            #catch {registry::entry close $depport}
        }
        if {[info exists orig_follow_dependencies]} {
            dict set options ports_uninstall_follow-dependencies $orig_follow_dependencies
        }
    } else {
        # check its dependents
        set userinput [registry::check_dependents $port ${force} "uninstall"]
        if {$userinput eq "quit"} {
            #registry::entry close $port
            return 0
        }
    }
    # if it's active, deactivate it
    if {[$port state] eq "installed"} {
        if {[dict exists $options ports_dryrun] && [string is true -strict [dict get $options ports_dryrun]]} {
            ui_msg "For $portname @${composite_spec}: skipping deactivate (dry run)"
        } else {
            if {$userinput eq "forcedbyuser"} {
                dict set options ports_nodepcheck yes
            }
            if {[dict exists $options ports_uninstall_no-exec] || ![registry::run_target $port deactivate $options]} {
                portimage::deactivate $portname $version $revision $variants $options
            }
            if {$userinput eq "forcedbyuser"} {
                dict unset options ports_nodepcheck
            }
        }
    }

    # note deps before we uninstall if we're going to uninstall them too (i.e. --follow-dependencies)
    if {[dict exists $options ports_uninstall_follow-dependencies] && [string is true -strict [dict get $options ports_uninstall_follow-dependencies]]} {
        set all_dependencies [generate_deplist $port $options]
    }

    if {[dict exists $options ports_dryrun] && [string is true -strict [dict get $options ports_dryrun]]} {
        ui_msg "For $portname @${composite_spec}: skipping uninstall (dry run)"
        # allow deps to not be excluded from the list below just because this port is still a dependent
        if {[dict exists $options ports_uninstall_follow-dependencies] && [string is true -strict [dict get $options ports_uninstall_follow-dependencies]]} {
            set uports [list [list $portname $version $revision $variants]]
        }
    } else {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Uninstalling %s @%s"] $portname $composite_spec]"

        # Get the full path to the port image
        set imagepath [$port location]
        set imagedir [file dirname $imagepath]
        if {[file isfile $imagepath]} {
            file delete $imagepath
            # Also delete extracted image dir if present
            set extracted_path [file rootname $imagepath]
            if {[file isdirectory $extracted_path]} {
                file delete -force $extracted_path
            }
        } else {
            # Image is a directory
            file delete -force $imagepath
            # Also delete any associated archives
            set imagename [file tail $imagepath]
            foreach archive [glob -nocomplain -directory $imagedir ${imagename}.*] {
                if {[file rootname [file tail $archive]] eq $imagename} {
                    file delete -force $archive
                }
            }
        }
        # Try to delete the port's image dir; will fail if there are more image
        # files so just ignore the failure
        catch {file delete $imagedir}

        # We want to delete the portfile if not referenced by any other ports
        set portfile [$port portfile]

        # and likewise the portgroups
        set portgroups [list]
        foreach pg [$port groups_used] {
            lappend portgroups [list [$pg name] [$pg version] [$pg size] [$pg sha256]]
            registry::portgroup close $pg
        }

        registry::write {
            registry::entry delete $port
        }

        global macports::registry.path
        set portfile_path [file join ${registry.path} registry portfiles ${portname}-${version}_${revision} $portfile]
        set other_entries [registry::entry search portfile $portfile name $portname version $version revision $revision]
        if {$other_entries eq {}} {
            file delete -force $portfile_path
            catch {file delete [file dirname $portfile_path]}
        }
        #foreach e $other_entries {
        #    registry::entry close $e
        #}

        set reg_portgroups_dir [file join ${registry.path} registry portgroups]
        foreach pg $portgroups {
            set pgname [lindex $pg 0]
            set pgversion [lindex $pg 1]
            set pgsize [lindex $pg 2]
            set pgsha256 [lindex $pg 3]
            set other_pgs [registry::portgroup search name $pgname version $pgversion size $pgsize sha256 $pgsha256]
            if {$other_pgs eq {}} {
                set pg_reg_dir [file join $reg_portgroups_dir ${pgsha256}-${pgsize}]
                file delete -force ${pg_reg_dir}/${pgname}-${pgversion}.tcl
                catch {file delete $pg_reg_dir}
            }
            foreach p $other_pgs {
                registry::portgroup close $p
            }
        }
    }

    if {![info exists uports]} {
        set uports [list]
    }
    # create list of all dependencies that will be uninstalled, if requested
    if {[dict exists $options ports_uninstall_follow-dependencies] && [string is true -strict [dict get $options ports_uninstall_follow-dependencies]]} {
        set alldeps $all_dependencies
        set portilist [list]
        for {set j 0} {$j < [llength $alldeps]} {incr j} {
            set dep [lindex $alldeps $j]
            set uninstalling_this_dep 0
            if {![catch {set ilist [registry::entry imaged $dep]}]} {
                foreach i $ilist {
                    if {[list [$i name] [$i version] [$i revision] [$i variants]] in $uports} {
                        #registry::entry close $i
                        continue
                    }
                    if {![$i requested]} {
                        set all_dependents_uninstalling 1
                        set depdts [$i dependents]
                        foreach depdt $depdts {
                            if {[list [$depdt name] [$depdt version] [$depdt revision] [$depdt variants]] ni $uports} {
                                set all_dependents_uninstalling 0
                                break
                            }
                        }
                        #foreach depdt $depdts {
                        #    registry::entry close $depdt
                        #}
                        if {$all_dependents_uninstalling} {
                            lappend uports [list [$i name] [$i version] [$i revision] [$i variants]]
                            lappend portilist [$i name]@[$i version]_[$i revision][$i variants]
                            set uninstalling_this_dep 1
                        }
                    }
                    #registry::entry close $i
                }
            }
            if {$uninstalling_this_dep} {
                set deprefs [registry::entry imaged $dep]
                foreach depref $deprefs {
                    set depdeps [generate_deplist $depref $options]
                    foreach d $depdeps {
                        if {$d ni [lrange $alldeps $j+1 end]} {
                            lappend alldeps $d 
                        }
                    }
                    #registry::entry close $depref
                }
            }
        }
        ## User Interaction Question
        # show a list of all dependencies to be uninstalled with a timeout when --follow-dependencies is specified
        if {[info exists macports::ui_options(questions_yesno)] && [llength $uports] > 0 && !([dict exists $options ports_dryrun] && [string is true -strict [dict get $options ports_dryrun]])} {
            $macports::ui_options(questions_yesno) "The following dependencies will be uninstalled:" "Timeout_1" $portilist {y} 10
        }
        dict unset options ports_uninstall_follow-dependencies
    }

    # uninstall all dependencies in order from uports
    foreach dp $uports {
        lassign $dp iname iversion irevision ivariants
        if {![catch {registry::entry open $iname $iversion $irevision $ivariants ""} regref]} {
            if {[dict exists $options ports_dryrun] && [string is true -strict [dict get $options ports_dryrun]]} {
                if {$iname ne $portname} {
                    ui_msg "For $iname @${iversion}_${irevision}${ivariants}: skipping uninstall (dry run)"
                }
            } else {
                if {[dict exists $options ports_uninstall_no-exec] || ![registry::run_target $regref uninstall $options]} {
                    uninstall $iname $iversion $irevision $ivariants $options
                }
            }
            #registry::entry close $regref
        }
    }

    return 0
}

# End of registry_uninstall namespace
}
