# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
#
# Copyright (c) 2007 - 2016 The MacPorts Project
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

package provide portlicensecheck 1.0
package require portutil 1.0

set org.macports.licensecheck [target_new org.macports.licensecheck portlicensecheck::licensecheck_main]
target_runtype ${org.macports.licensecheck} always
target_state ${org.macports.licensecheck} no
target_provides ${org.macports.licensecheck} licensecheck
target_requires ${org.macports.licensecheck} main
target_prerun ${org.macports.licensecheck} portlicensecheck::licensecheck_start

namespace eval portlicensecheck {
}

set_ui_prefix

set check_deptypes [list depends_build depends_lib]

proc portlicensecheck::all_licenses_except { args } {
    set remaining $licenses::good_licenses
    foreach arg $args {
        set remaining [lsearch -inline -all -not -exact $remaining $arg]
    }
    return $remaining
}

# return deps and license for given port
proc portlicensecheck::infoForPort {portName variantInfo} {
    set portSearchResult [mport_lookup $portName]
    if {[llength $portSearchResult] < 1} {
        puts stderr "Warning: port \"$portName\" not found"
        return {}
    }
    array set portInfo [lindex $portSearchResult 1]
    set portfile_path [getportdir $portInfo(porturl)]/Portfile
    set variant_string $variantInfo

    set dependencyList {}
    set mport [mport_open $portInfo(porturl) [list subport $portInfo(name)] $variantInfo]
    array unset portInfo
    array set portInfo [mport_info $mport]
    # Closing the mport is actually fairly expensive and not really necessary
    mport_close $mport

    foreach dependencyType $::check_deptypes {
        if {[info exists portInfo($dependencyType)] && $portInfo($dependencyType) ne ""} {
            foreach dependency $portInfo($dependencyType) {
                lappend dependencyList [string range $dependency [string last ":" $dependency]+1 end]
            }
        }
    }

    set ret [list $dependencyList $portInfo(license)]
    if {[info exists portInfo(installs_libs)]} {
        lappend ret $portInfo(installs_libs)
    } else {
        # when in doubt, assume code from the dep is incorporated
        lappend ret yes
    }
    if {[info exists portInfo(license_noconflict)]} {
        lappend ret $portInfo(license_noconflict)
    }

    return $ret
}

# return license with any trailing dash followed by a number and/or plus sign removed
set remove_version_re {[0-9.+]+}
proc portlicensecheck::remove_version {license} {
    set dash [string last - $license]
    if {$dash != -1 && [regexp $::remove_version_re [string range $license $dash+1 end]]} {
        return [string range $license 0 $dash-1]
    } else {
        return $license
    }
}

proc portlicensecheck::licensecheck_start {args} {
    global UI_PREFIX subport
    ui_notice "$UI_PREFIX [format [msgcat::mc "Checking license for %s"] ${subport}]"
}

proc portlicensecheck::licensecheck_main {args} {
    # Obtain licenses from '_resources/port1.0/licenses/licenses.tcl'.
    namespace eval ::licenses {
        set license_file [getdefaultportresourcepath "port1.0/licenses/licenses.tcl"]
        ui_debug "Loading license data from: '${license_file}'"
        if {[catch {source ${license_file}} result]} {
            ui_warn "Result from failed license data load attempt: $::errorInfo: result"
            return -code 1 "License data could not be loaded from: '${license_file}'."
        }
    }

    global UI_PREFIX subport portvariants PortInfo

    array set portSeen {}
    set result 0

    set top_info [infoForPort $subport $PortInfo(active_variants)]
    if {$top_info eq {}} {
        return 1
    }
    set top_license [lindex $top_info 1]
    foreach noconflict_port [lindex $top_info 3] {
        set noconflict_ports($noconflict_port) 1
    }
    set top_license_names {}
    # check that top-level port's license(s) are good
    foreach sublist $top_license {
        # each element may be a list of alternatives (i.e. only one need apply)
        set any_good 0
        set sub_names {}
        foreach full_lic $sublist {
            # chop off any trailing version number
            set lic [remove_version $full_lic]
            # add name to the list for later
            lappend sub_names $lic
            if {[info exists licenses::license_good([string tolower $lic])]} {
                set any_good 1
            }
        }
        lappend top_license_names $sub_names
        if {!$any_good} {
            ui_notice "\"$subport\" is not distributable because its license \"$lic\" is not known to be distributable"
            return 1
        }
    }

    # start with deps of top-level port
    set portPaths [dict create [lindex $top_info 0] [list]]
    set portList [lindex $top_info 0]
    foreach aPort $portList {
        dict set portPaths $aPort [list]
    }

    while {[llength $portList] > 0} {
        set aPort [lindex $portList 0]
        set portList [lreplace $portList 0 0]
        if {[info exists portSeen($aPort)] && $portSeen($aPort) eq 1} {
            continue
        }

        # mark as seen and remove from the list
        set portSeen($aPort) 1
        if {[info exists noconflict_ports($aPort)]} {
            continue
        }

        set aPortInfo [infoForPort $aPort $PortInfo(active_variants)]
        if {$aPortInfo eq {}} {
            continue
        }
        set aPortLicense [lindex $aPortInfo 1]
        set installs_libs [lindex $aPortInfo 2]
        if {!$installs_libs} {
            continue
        }
        set parentPath [list {*}[dict get $portPaths $aPort] $aPort]

        ui_debug "checking $aPort"

        foreach sublist $aPortLicense {
            set any_good 0
            set any_compatible 0
            # check that this dependency's license(s) are good
            foreach full_lic $sublist {
                set lic [remove_version [string tolower $full_lic]]
                if {[info exists licenses::license_good($lic)]} {
                    set any_good 1
                } else {
                    # no good being compatible with other licenses if it's not distributable itself
                    continue
                }

                # ... and that they don't conflict with the top-level port's
                set any_conflict 0
                foreach top_sublist [concat $top_license $top_license_names] {
                    set any_sub_compatible 0
                    foreach top_lic $top_sublist {
                        if {![info exists licenses::license_conflicts([string tolower $top_lic])]
                            || ([lsearch -sorted $licenses::license_conflicts([string tolower $top_lic]) $lic] == -1
                            && [lsearch -sorted $licenses::license_conflicts([string tolower $top_lic]) [string tolower $full_lic]] == -1)} {
                            set any_sub_compatible 1
                            break
                        }
                    }
                    if {!$any_sub_compatible} {
                        set any_conflict 1
                        break
                    }
                }
                if {!$any_conflict} {
                    set any_compatible 1
                    break
                }
            }

            if {!$any_good} {
                ui_warn "\"$subport\" is not distributable because its dependency \"$aPort\" has license \"$full_lic\" which is not known to be distributable: [join $parentPath " -> "]"
                set result 1
            } elseif {!$any_compatible} {
                ui_warn "\"$subport\" is not distributable because its license \"$top_lic\" conflicts with license \"$full_lic\": [join $parentPath " -> "]"
                set result 1
            }
        }

        # skip deps that are explicitly stated to not conflict
        array unset aPort_noconflict_ports
        foreach noconflict_port [lindex $aPortInfo 3] {
            set aPort_noconflict_ports($noconflict_port) 1
        }
        # add its deps to the list
        foreach possiblyNewPort [lindex $aPortInfo 0] {
            if {![info exists portSeen($possiblyNewPort)] && ![info exists aPort_noconflict_ports($possiblyNewPort)]} {
                lappend portList $possiblyNewPort
                dict set portPaths $possiblyNewPort $parentPath
            }
        }
    }

    if {$result eq 0} {
        ui_msg "\"$subport\" is distributable"
    }

    return $result
}

# given a variant string, return an array of variations
set split_variants_re {([-+])([[:alpha:]_]+[\w\.]*)}
proc portlicensecheck::split_variants {variants} {
    set result {}
    set l [regexp -all -inline -- $::split_variants_re $variants]
    foreach { match sign variant } $l {
        lappend result $variant $sign
    }
    return $result
}

# given an array of variations, return a variant string in normalized form
proc portlicensecheck::normalize_variants {variations} {
    array set varray $variations
    set variant_string ""
    foreach vname [lsort -ascii [array names varray]] {
        append variant_string $varray($vname)${vname}
    }
    return $variant_string
}
