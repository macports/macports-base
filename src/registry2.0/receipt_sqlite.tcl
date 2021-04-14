# receipt_sqlite.tcl
#
# Copyright (c) 2010-2011 The MacPorts Project
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
##
# Return a list of active ports, or the active version of port \a name, if
# specified.
#
# @param name
#        Empty string to return a list of all ports or the name of a port to
#        return only the active version of a single port.
# @return A list of matching ports where each entry is a list of (name,
#         version, revision, variants, 1 or 0 indicating whether a port's state
#         is "installed", epoch).
proc active {name} {
    if {$name ne ""} {
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
# Open an existing entry in the registry uniquely identified by name, version,
# revision, variants and epoch and return a reference.
#
# @param name
#        The name of the port to be opened.
# @param version
#        The version of the port to be opened.
# @param revision
#        The revision of the port to be opened.
# @param variants
#        The canonical variant string of the port to be opened.
# @param epoch
#        The epoch of the port to be opened.
# @return A reference to the requested port on success. Raises an error on
#         failure (e.g. if the port isn't found or allocating the reference
#         fails).
proc open_entry {name version revision variants epoch} {
    return [registry::entry open $name $version $revision $variants $epoch]
}

##
# Check whether a registry entry exists.
#
# @param name
#        The name to be searched in the registry.
# @param version
#        The version to be searched in the registry.
# @param revision
#        The revision to be searched in the registry. Defaults to 0.
# @param variants
#        The canonical variant string to be searched in the registry. Defaults
#        to an empty string.
# @return 1, if the port exists, 0 otherwise.
proc entry_exists {name version {revision 0} {variants ""}} {
    if {![catch {set ports [registry::entry search name $name version $version revision $revision variants $variants]}] && [llength $ports] > 0} {
        return 1
    }
    return 0
}

##
# Check whether a registry entry with the given name exists.
#
# @param name
#        The name to be searched in the registry.
# @return 1 if a port with the given name exists in the registry, 0 otherwise.
proc entry_exists_for_name {name} {
    if {![catch {set ports [registry::entry search name $name]}] && [llength $ports] > 0} {
        return 1
    }
    return 0
}

##
# Determine if a file is registered in the file map, and if it is, get the name
# of the port it is registered to.
#
# @param file
#        The full path to the file to be tested.
# @param cs
#        Boolean value indicating a case-sensitive check.
# @return 0 if the file is not registered to any port. The name of the port
#         otherwise.
proc file_registered {file cs} {
    set port [registry::entry owner $file $cs]
    if {$port ne ""} {
        return [$port name]
    } else {
        return 0
    }
}

##
# Determine if a port is registered in the file map, and if it is, get its
# installed (activated) files.
#
# @param name
#        The name of the port to be tested.
# @return 0 if no port with the given name is active. An empty string, if no
#         port with the given name is active, but a port with the given name is
#         imaged (i.e. installed, but inactive). A list of files if the given
#         port is installed and active.
proc port_registered {name} {
    if {![catch {set ports [registry::entry installed $name]}] && [llength $ports] > 0} {
        # should never return more than one port
        set port [lindex $ports 0]
        return [$port files]
    } elseif {![catch {set ports [registry::entry imaged $name]}] && [llength $ports] > 0} {
        return ""
    } else {
        return 0
    }
}

##
# Retrieve a property from a registry entry.
#
# @param ref
#        Reference to the registry entry.
# @param property
#        Name of the property to retrieve.
# @return Return value depends on the property queried. Returns 0 if an error
#         occured while trying to access the property (but note that 0 may be
#         a perfectly valid value for the key you're querying).
proc property_retrieve {ref property} {
    switch $property {
        active {
            set ret [string equal [$ref state] "installed"]
        }
        default {
            if {[catch {set ret [$ref $property]}]} {
                # match behaviour of receipt_flat
                set ret 0
            }
        }
    }
    return $ret
}

##
# Store a property in a registry entry.
#
# @param ref
#        Reference to the registry entry.
# @param property
#        Name of the property to set.
# @param value
#        New value for the given key in the reference.
proc property_store {ref property value} {
    switch $property {
        active {
            if {!$value} {
                $ref state "imaged"
            } else {
                $ref state "installed"
            }
        }
        default {
            $ref $property $value
        }
    }
}

##
# Return all installed ports (active and inactive). Optionally filter by name
# and version.
#
# @param name
#        The name of the port you're looking for. Defaults to an empty string,
#        which will return all installed ports.
# @param version
#        A version string in either of the forms "$version_$revision$variants"
#        or "$version". Defaults to an empty string, which will return ports
#        regardless of version constraints.
# @return A list of ports in the form given by #active.
proc installed {{name ""} {version ""}} {
    # If version is "", return all ports of that name. Otherwise, return only
    # ports that exactly match this version. What we call version here is
    # version_revision+variants.
    # The syntax for that can be ambiguous if there's an underscore and dash in
    # version for example, so we don't attempt to split up the composite
    # version into its components, we just compare the whole thing.
    if {$name eq "" && $version eq ""} {
        set ports [registry::entry imaged]
    } elseif {$name ne "" && $version eq ""} {
        set ports [registry::entry imaged $name]
    } else {
        set ports [list]
        set possible_ports [registry::entry imaged $name]
        foreach p $possible_ports {
            if {"[$p version]_[$p revision][$p variants]" eq $version || [$p version] eq $version} {
                lappend ports $p
            }
        }
    }

    set rlist [list]
    foreach port $ports {
        lappend rlist [list [$port name] [$port version] [$port revision] [$port variants] [string equal [$port state] "installed"] [$port epoch]]
    }
    return $rlist
}

##
# Does nothing.
proc close_file_map {args} {
}

##
# Does nothing.
proc open_dep_map {args} {
}

##
# List all ports that a given port (identified by the parameters) depends on.
# Each of the parameters can be passed as an empty string to ignore them in the
# search. You should however at least specify name.
#
# @param name
#        The name of the port of interest.
# @param version
#        The version of the port of interest.
# @param revision
#        The revision of the port of interest.
# @param variants
#        The canonical variants string of the port of interest.
# @return A sorted list without duplicates where each entry is of the form
#         (dependency, "port", port), where dependency is the name of the
#         dependency and port is the name of the port that matched the search
#         criteria.
proc list_depends {name version revision variants} {
    set rlist [list]
    set searchkeys [list]
    foreach key {name version revision} {
        if {[set $key] ne ""} {
            lappend searchkeys $key [set $key]
        }
    }
    if {$variants != 0} {
        lappend searchkeys "variants" $variants
    }
    if {[catch {set ports [registry::entry search {*}$searchkeys]}]} {
        set ports [list]
    }
    foreach port $ports {
        foreach dep [$port dependencies] {
            lappend rlist [list [$dep name] port [$port name]]
        }
    }

    return [lsort -unique $rlist]
}

# List all the ports that depend on this port
##
# List all ports that depend on a given port (identified by the parameters).
# Each of the parameters can be passed as an empty string to ignore them in the
# search. In practice, you'll always pass at least the name parameter
# non-empty.
#
# @param name
#        The name of the port of interest.
# @param version
#        The version of the port of interest.
# @param revision
#        The revision of the port of interest.
# @param variants
#        The canonical variants string of the port of interest.
# @return A sorted list without duplicates where each entry is of the form
#         (port, "port", dependent), where dependent is the name of the
#         dependent port and port is the name of the port that matched the
#         search criteria.
proc list_dependents {name version revision variants} {
    set rlist [list]
    set searchkeys [list]
    foreach key {name version revision} {
        if {[set $key] ne ""} {
            lappend searchkeys $key [set $key]
        }
    }
    if {$variants != 0} {
        lappend searchkeys "variants" $variants
    }
    if {[catch {set ports [registry::entry search {*}$searchkeys]}]} {
        set ports [list]
    }
    foreach port $ports {
        set dependents [$port dependents]
        foreach dependent $dependents {
            lappend rlist [list [$port name] port [$dependent name]]
        }
    }

    return [lsort -unique $rlist]
}

##
# Add a new registry entry from a given list of keys of values. The list should
# at least contain the keys
#  \li \c name The name of the port
#  \li \c epoch The epoch of the port
#  \li \c version The version of the port
#  \li \c revision The revision of the port
#  \li \c variants The canonical variants string of the port
#  \li \c date The date of installation of this port, probably the current date
#      and time
#  \li \c requested 0 or 1 depending on whether this port is a requested port
#  \li \c location The absolute path to the binary archive of the port
#  \li \c state The current state of the port, currently either "imaged" or
#      "installed"
#  \li \c installtype The type of installation of this port. For new ports,
#      always "image"
#  \li \c imagefiles A list of files installed by this port
#  \li \c files A list of filenames as which the imagefiles should be activated
#      if state is "installed"
#  \li \c requested_variants The canonical representation of the requested variants
#  \li \c os_platform The platform on which the port was installed
#  \li \c os_major The major version of the OS on which the port was installed
#  \li \c archs A list of architectures of this port
#  \li \c depends A list of ports on which the new port depends
#  \li \c portfile The Portfile used to install this port (note: actual
#      contents, not the path!)
proc create_entry_l {proplist} {
    array set props $proplist
    registry::write {
        set regref [registry::entry create $props(name) $props(version) $props(revision) $props(variants) $props(epoch)]
        $regref date $props(date)
        $regref requested $props(requested)
        $regref location $props(location)
        $regref state $props(state)
        $regref installtype $props(installtype)
        if {$props(installtype) eq "image"} {
            $regref map $props(imagefiles)
            if {$props(state) eq "installed"} {
                if {[llength $props(imagefiles)] != [llength $props(files)]} {
                    # deal with this mess, just drop the extras...
                    set i 0
                    set ilist [list]; set flist [list]
                    while {$i < [llength $props(imagefiles)] && $i < [llength $props(files)]} {
                        lappend ilist [lindex $props(imagefiles) $i]
                        lappend flist [lindex $props(files) $i]
                        incr i
                    }
                    $regref activate $ilist $flist
                } else {
                    $regref activate $props(imagefiles) $props(files)
                }
            }
        } else {
            $regref map $props(files)
        }
        foreach key {requested_variants os_platform os_major archs} {
            if {$props($key) != 0} {
                $regref $key $props($key)
            } else {
                $regref $key ""
            }
        }
        foreach dep_portname $props(depends) {
            $regref depends $dep_portname
        }
        $regref portfile $props(portfile)
    }
}

# End of receipt_sqlite namespace
}
