# et:ts=4
# registry_util.tcl
#
# Copyright (c) 2007 Chris Pickel
# Copyright (c) 2010-2011, 2014 The MacPorts Project
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
# 3. Neither the name of The MacPorts Project nor the names of its contributors
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

package provide registry_util 2.0

package require registry2 2.0

namespace eval registry {

## Decodes a version specifier into its component values. Values will be
## returned into the variables named by `version`, `revision`, and `variants`,
## with `revision` and `variants` possibly being set to the empty string if none
## were specified.
##
## This accept a full specifier such as `1.2.1_3+cool-lame` (to disable MP3
## support) or a bare version, such as `1.2.1`. If a revision is not specified,
## then the returned revision and variants will be empty.
##
## @param [in] specifier a specifier, as described above
## @param [out] version  name of a variable to return version into
## @param [out] revision name of a variable to return revision into
## @param [out] variants name of a variable to return variants into
## @return               true if `specifier` is a valid specifier, else false
proc decode_spec {specifier version revision variants} {
    upvar 1 $version ver $revision rev $variants var
    return [regexp {^([^+]+?)(_(\d+)(([-+][^-+]*[^-+[:digit:]_][^-+]*)*))?$} $specifier - ver - rev var]
}

## Checks that the given port has no dependent ports. If it does, throws an
## error if force wasn't set (emits a message if it is).
##
## @param [in] port  a registry::entry to check
## @param [in] force if true, continue even if there are dependents
proc check_dependents {port force {action "uninstall/deactivate"}} {
    global UI_PREFIX
    if {[$port state] eq "installed" || [llength [registry::entry imaged [$port name]]] == 1} {
        # Check if any installed ports depend on this one
        set deplist [$port dependents]
        if {$action eq "deactivate"} {
            set active_deplist [list]
            # Check if any active ports depend on this one
            foreach p $deplist {
                if {[$p state] eq "installed"} {
                    lappend active_deplist $p
                }
            }
            set deplist $active_deplist
        }
        if { [llength $deplist] > 0 } {
            ## User Interaction Question
            # ask if user wants to uninstall a port and thereby break its dependents
            if {[info exists macports::ui_options(questions_yesno)] && ![string is true -strict $force]} { 
                set portulist [list]
                foreach depport $deplist {
                    lappend portulist [$depport name]@[$depport version]_[$depport revision]
                }
                ui_msg "Note: It is not recommended to uninstall/deactivate a port that has dependents as it breaks the dependents."
                set retvalue [$macports::ui_options(questions_yesno) "The following ports will break:" "breakDeps" $portulist {n} 0]
                if {$retvalue == 0} {
                    set force "yes"
                } else {
                    return quit
                }
            } else {	
                ui_msg "$UI_PREFIX [format [msgcat::mc "Unable to %s %s @%s_%s%s, the following ports depend on it:"] $action [$port name] [$port version] [$port revision] [$port variants]]"
                foreach depport $deplist {
                    ui_msg "$UI_PREFIX [format [msgcat::mc "	%s @%s_%s%s"] [$depport name] [$depport version] [$depport revision] [$depport variants]]"
                }
            }
            if { [string is true -strict $force] } {
                ui_warn "[string totitle $action] forced.  Proceeding despite dependencies."
                return forcedbyuser
            } else {
                throw registry::uninstall-error "Please uninstall the ports that depend on [$port name] first."
            }
        }
    }
}

## runs the given target of the given port using its stored portfile
## @return   true if successful, false otherwise
proc run_target {port target options} {
    set portspec "[$port name] @[$port version]_[$port revision][$port variants]"
    if {[$port portfile] eq ""} {
        ui_debug "no portfile in registry for $portspec"
        return 0
    }

    if {![catch {set mport [mportopen_installed [$port name] [$port version] [$port revision] [$port variants] $options]}]} {
        set failed 0
        if {[catch {mportexec $mport $target} result]} {
            ui_debug $::errorInfo
            set failed 1
        } elseif {$result != 0} {
            set failed 1
        }
        if {$failed} {
            catch {mportclose $mport}
            ui_warn "Failed to execute portfile from registry for $portspec"
            switch $target {
                activate {
                    if {[$port state] eq "installed"} {
                        return 1
                    }
                }
                deactivate {
                    if {[$port state] eq "imaged"} {
                        return 1
                    }
                }
                uninstall {
                    if {![registry::entry exists $port]} {
                        return 1
                    }
                }
            }
        } else {
            global macports::keeplogs
            if {(![info exists keeplogs] || !$keeplogs) && $target ne "activate"} {
                catch {mportexec $mport clean}
            }
            mportclose $mport
            return 1
        }
    } else {
        ui_debug $::errorInfo
        ui_warn "Failed to open Portfile from registry for $portspec"
    }
    return 0
}

}
