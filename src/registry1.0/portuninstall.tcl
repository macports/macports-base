# et:ts=4
# portuninstall.tcl
# $Id$
#
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
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

package provide portuninstall 1.0

package require registry 1.0
package require macports 1.0

set UI_PREFIX "---> "

namespace eval portuninstall {

proc uninstall {portname {v ""} optionslist} {
	global uninstall.force uninstall.nochecksum UI_PREFIX
	global macports::portimagefilepath macports::os_platform macports::os_arch
	array set options $optionslist

	set ilist [registry::installed $portname $v]
	if { [llength $ilist] > 1 } {
	    set portname [lindex [lindex $ilist 0] 0]
		ui_msg "$UI_PREFIX [msgcat::mc "The following versions of $portname are currently installed:"]"
		foreach i $ilist { 
			set iname [lindex $i 0]
			set iversion [lindex $i 1]
			set irevision [lindex $i 2]
			set ivariants [lindex $i 3]
			set iactive [lindex $i 4]
			if { $iactive == 0 } {
				ui_msg "$UI_PREFIX [format [msgcat::mc "	%s @%s_%s%s"] $iname $iversion $irevision $ivariants]"
			} elseif { $iactive == 1 } {
				ui_msg "$UI_PREFIX [format [msgcat::mc "	%s @%s_%s%s (active)"] $iname $iversion $irevision $ivariants]"
			}
		}
		return -code error "Registry error: Please specify the full version as recorded in the port registry."
	} else {
	    # set portname again since the one we were passed may not have had the correct case
	    set portname [lindex [lindex $ilist 0] 0]
		set version [lindex [lindex $ilist 0] 1]
		set revision [lindex [lindex $ilist 0] 2]
		set variants [lindex [lindex $ilist 0] 3]
		set active [lindex [lindex $ilist 0] 4]
		set epoch [lindex [lindex $ilist 0] 5]
	}

	# determine if it's the only installed port with that name or not.
	if {$v == ""} {
		set nb_versions_installed 1
	} else {
		set ilist [registry::installed $portname ""]
		set nb_versions_installed [llength $ilist]
	}

	set ref [registry::open_entry $portname $version $revision $variants]

	# If global forcing is on, make it the same as a local force flag.
	if {[info exists options(ports_force)] && [string equal -nocase $options(ports_force) "yes"] } {
		set uninstall.force "yes"
	}

	# Check and make sure no ports depend on this one
	registry::open_dep_map	
	set deplist [registry::list_dependents $portname]
	if { [llength $deplist] > 0 } {
		set dl [list]
		# Check the deps first
		foreach dep $deplist { 
			set depport [lindex $dep 2]
			ui_debug "$depport depends on this port"
			if {[registry::entry_exists_for_name $depport]} {
				lappend dl $depport
			}
		}
		# Now see if we need to error
		if { [llength $dl] > 0 } {
			if {[info exists options(ports_uninstall_follow-dependents)] && $options(ports_uninstall_follow-dependents) eq "yes"} {
				foreach depport $dl {
					# make sure it's still installed, since a previous dep uninstall may have removed it
					if {[registry::entry_exists_for_name $depport]} {
						portuninstall::uninstall $depport "" [array get options]
					}
				}
			} else {
                # will need to change this when we get version/variant dependencies
                if {$nb_versions_installed == 1 || $active == 1} {
                    ui_msg "$UI_PREFIX [format [msgcat::mc "Unable to uninstall %s %s_%s%s, the following ports depend on it:"] $portname $version $revision $variants]"
                    foreach depport $dl {
                        ui_msg "$UI_PREFIX [format [msgcat::mc "	%s"] $depport]"
                    }
                    if { [info exists uninstall.force] && [string equal ${uninstall.force} "yes"] } {
                        ui_warn "Uninstall forced.  Proceeding despite dependencies."
                    } else {
                        return -code error "Please uninstall the ports that depend on $portname first."
                    }
                }
			}
		}
	}

	if {[registry::property_retrieve $ref active] == 1} {
		#return -code error [msgcat::mc "Registry Error: ${portname} ${version}_${revision}${variants} is active."]
		registry::deactivate $portname ${version}_${revision}${variants} $optionslist
	}

	ui_msg "$UI_PREFIX [format [msgcat::mc "Uninstalling %s @%s_%s%s"] $portname $version $revision $variants]"

	# Look to see if the port has registered an uninstall procedure
	set uninstall [registry::property_retrieve $ref pkg_uninstall] 
	if { $uninstall != 0 } {
		if {![catch {eval $uninstall} err]} {
			pkg_uninstall $portname ${version}_${revision}${variants}
		} else {
			global errorInfo
			ui_debug "$errorInfo"
			ui_error [format [msgcat::mc "Could not evaluate pkg_uninstall procedure: %s"] $err]
		}
	}

	# Remove the port from the deps_map if only one version was installed.
	# This is a temporary fix for a deeper problem that is that the dependency
	# map doesn't take the port version into account (but should).
	# Fixing it means transitionning to a new dependency map format.
	if {$nb_versions_installed == 1} {
		registry::unregister_dependencies $portname
	}

	set macport_filename "${portname}-${epoch}-${version}_${revision}${variants}.${macports::os_platform}.${macports::os_arch}.macport"
	set macport_file [file join ${macports::portimagefilepath} $portname $macport_filename]
	file delete $macport_file
	ui_info "$UI_PREFIX [format [msgcat::mc "Uninstall is removing %s from the port registry."] $portname]"
	registry::delete_entry $ref
}

# End of portuninstall namespace
}
