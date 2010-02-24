# receipt_sqlite.tcl
# $Id$
#
# Copyright (c) 2010 The MacPorts Project
# Copyright (c) 2004 Will Barton <wbb4@opendarwin.org>
# Copyright (c) 2002 Apple Inc.
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

package provide receipt_sqlite 1.0

package require macports 1.0
package require registry2 2.0
package require registry_util 2.0

##
# registry2.0 wrapper code that matches old receipt_flat interface
##
namespace eval receipt_sqlite {

# return list of active ports, or active version of port 'name' if specified
proc active {name} {
    if {$name != ""} {
        set ports [registry::entry installed $name]
    } else {
        set ports [registry::entry installed]
    }
    set rlist [list]
    foreach port $ports {
        lappend rlist [list [$port name] [$port version] [$port revision] [$port variants] [string equal [$port state] "installed"] [$port epoch]]
    }
    return $rlist
}

##
# Open an existing entry and return a reference.
proc open_entry {name version revision variants epoch} {
    return [registry::entry open $name $version $revision $variants $epoch]
}

# Check to see if an entry exists
proc entry_exists {name version {revision 0} {variants ""}} {
	set searchcmd "registry::entry search"
    foreach key {name version revision variants} {
        append searchcmd " $key [set $key]"
    }
    if {![catch {[eval $searchcmd]}]} {
        return 1
    }
	return 0
}

# Check to see if an entry exists
proc entry_exists_for_name {name} {
	if {![catch {registry::entry search name $name}]} {
	    return 1
	}
	return 0
}

##
# determine if a file is registered in the file map, and if it is,
# get its port.
#
# - file	the file to test
# returns 0 if the file is not registered, the name of the port otherwise.
#
proc file_registered {file} {
    set port [registry::entry owner $file]
	if {$port != ""} {
		return [$port name]
	} else {
		return 0
	}
}

##
# determine if a port is registered in the file map, and if it is,
# get its installed (activated) files.
#
# - port	the port to test
# returns 0 if the port is not registered, the list of its files otherwise.
proc port_registered {name} {
	if {![catch {set ports [registry::entry search name $name state installed]}]} {
	    # should never return more than one port
	    set port [lindex $ports 0]
		return [$port files]
	} else {
        return 0
    }
}

##
# Retrieve a property from a registry entry.
#
# ref			reference to the entry.
# property		key for the property to retrieve.
proc property_retrieve {ref property} {
    switch $property {
        active {
            set ret [string equal [$ref state] "installed"]
        }
        imagedir {
            set ret [$ref location]
        }
        default {
            set ret [$ref $property]
        }
    }
    return $ret
}

# Return installed ports
#
# If version is "", return all ports of that name.
# Otherwise, return only ports that exactly match this version.
# What we call version here is version_revision+variants.
proc installed {{name ""} {version ""}} {
    global macports::registry.installtype
	
	if { $name == "" && $version == "" } {
	    if {${macports::registry.installtype} == "image"} {
	        set ports [registry::entry imaged]
	    } else {
	        set ports [registry::entry installed]
	    }
	} else {
	    set searchcmd "registry::entry search"
	    registry::decode_spec $version version revision variants
	    foreach key {name version revision variants} {
            if {[info exists $key] && [set $key] != ""} {
                append searchcmd " $key [set $key]"
            }
	    }
	    if {[catch {set ports [eval $searchcmd]}]} {
	        set ports [list]
	    }
	}

    set rlist [list]
    foreach port $ports {
        lappend rlist [list [$port name] [$port version] [$port revision] [$port variants] [string equal [$port state] "installed"] [$port epoch]]
    }
	return $rlist
}

proc close_file_map {args} {
}

proc open_dep_map {args} {
}

# List all the ports that depend on this port
proc list_dependents {name version revision variants} {
	set rlist [list]
	set searchcmd "registry::entry search"
    foreach key {name version revision variants} {
        if {[set $key] != ""} {
            append searchcmd " $key [set $key]"
        }
    }
    if {[catch {set ports [eval $searchcmd]}]} {
        set ports [list]
    }
    foreach port $ports {
        set dependents [$port dependents]
        foreach dependent $dependents {
            lappend rlist [list [$port name] port [$dependent name]]
        }
    }
	
	return $rlist
}

# End of receipt_sqlite namespace
}
