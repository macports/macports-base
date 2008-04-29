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

package provide portuninstall 2.0

package require registry2 2.0
package require registry_util 2.0

set UI_PREFIX "---> "

namespace eval portuninstall {

proc uninstall {portname {specifier ""} optionslist} {
	global uninstall.force uninstall.nochecksum UI_PREFIX
	array set options $optionslist

	if {[info exists options(ports_force)] && [string is true $options(ports_force)] } {
        set force 1
    } else {
        set force 0
    }

    if { [registry::decode_spec $specifier version revision variants] } {
        set ilist [registry::entry imaged $portname $version $revision $variants]
        set valid 1
    } else {
        set valid [string equal $specifier {}]
        set ilist [registry::entry imaged $portname]
    }

	if { [llength $ilist] > 1 } {
		ui_msg "$UI_PREFIX [format [msgcat::mc "The following versions of %s are currently installed:"] $portname]"
		foreach i $ilist { 
			set iname [lindex $i 0]
			set iactive [lindex $i 4]
            set ispec "[$i version]_[$i revision][$i variants]"
			if { [string equal [$i state] installed] } {
				ui_msg "$UI_PREFIX [format [msgcat::mc "	%s @%s (active)"] $iname $ispec]"
			} elseif { $iactive == 1 } {
				ui_msg "$UI_PREFIX [format [msgcat::mc "	%s @%s"] $iname $ispec]"
			}
		}
        if { $valid } {
            throw registry::invalid "Registry error: Please specify the full version as recorded in the port registry."
        } else {
            throw registry::invalid "Registry error: Invalid version specified. Please specify a version as recorded in the port registry."
        }
	} elseif { [llength $ilist] == 1 } {
        set port [lindex $ilist 0]
	} else {
        throw registry::invalid "Registry error: $portname not registered as installed"
    }

    if { [string equal [$port installtype] direct] } {
        # if port is installed directly, check its dependents
        registry::check_dependents $port $force
    } else {
        # if it's an image, deactivate it (and check dependents there)
        if { [string equal [$port state] installed] } {
            portimage::deactivate $portname ${version}_${revision}${variants} $optionslist
        }
	}

	ui_msg "$UI_PREFIX [format [msgcat::mc "Uninstalling %s @%s_%s%s"] $portname $version $revision $variants]"

    # pkg_uninstall isn't used anywhere as far as I can tell and I intend to add
    # some proper pre-/post- hooks to uninstall/deactivate.

	# Look to see if the port has registered an uninstall procedure
	#set uninstall [registry::property_retrieve $ref pkg_uninstall] 
	#if { $uninstall != 0 } {
	#	if {![catch {eval $uninstall} err]} {
	#		pkg_uninstall $portname ${version}_${revision}${variants}
	#	} else {
	#		global errorInfo
	#		ui_debug "$errorInfo"
	#		ui_error [format [msgcat::mc "Could not evaluate pkg_uninstall procedure: %s"] $err]
	#	}
	#}

	set contents [$port files]

    set bak_suffix .mp_[time seconds]
    set uninst_err 0
    set files [list]
    foreach file $contents {
        if { !([info exists uninstall.nochecksum]
                && [string is true $uninstall.nochecksum]) } {
            set sum1 [$port md5sum $file]
            if {![catch {set sum2 [md5 $file]}] && ![string match $sum1 $sum2]} {
                ui_info "$UI_PREFIX  [format [msgcat::mc "Original checksum does not match for %s, saving a copy to %s"] $file $file$bak_suffix]"
                file copy $file $file$bak_suffix
            }
        }

        # Normalize the file path to avoid removing the intermediate
        # symlinks (remove the empty directories instead)
        set theFile [compat filenormalize $file]
        lappend files $theFile

        # Split out the filename's subpaths and add them to the
        # list as well.
        set directory [file dirname $theFile]
        while { [lsearch -exact $files $directory] == -1 } { 
            lappend files $directory
            set directory [file dirname $directory]
        }
    }

    # Sort the list in reverse order, removing duplicates.
    # Since the list is sorted in reverse order, we're sure that directories
    # are after their elements.
    set theList [lsort -decreasing -unique $files]

    # Remove all elements.
    foreach file $theList {
        _uninstall_file $file
    }

    ui_info "$UI_PREFIX [format [msgcat::mc "Uninstall is removing %s from the port registry."] $portname]"
    registry::entry delete $port
    return 0
}

proc _uninstall_file {dstfile} {
	if { ![catch {set type [file type $dstfile]}] } {
        switch {$type} {
            case link {
                ui_debug "uninstalling link: $dstfile"
                file delete -- $dstfile
            }
            case directory {
                # 0 item means empty.
                if { [llength [readdir $dstfile]] == 0 } {
                    ui_debug "uninstalling directory: $dstfile"
                    file delete -- $dstfile
                } else {
                    ui_debug "$dstfile is not empty"
                }
            }
            case file {
                ui_debug "uninstalling file: $dstfile"
                file delete -- $dstfile
            }
            default {
                ui_debug "skip file of unknown type $type: $dstfile"
            }
        }
	} else {
		ui_debug "skip missing file: $dstfile"
	}
}

proc _uninstall_list {filelist} {
	foreach file $filelist {
		_uninstall_file $file
	}
}

# End of portuninstall namespace
}
