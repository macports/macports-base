# -*- tcl -*-
# (C) 2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

getpackage pregistry registry/registry.tcl

namespace eval ::sak::registry {}

proc ::sak::registry::local {args} {
    return [uplevel 1 [linsert $args 0 [Setup]]]
    # return <$_local {expand}$args>
}

proc ::sak::registry::Setup {} {
    variable _local
    variable state
    variable statedir

    if {![file exists $statedir]} {
	file mkdir $statedir
    }

    if {$_local == {}} {
	set _local [pregistry %AUTO% \
		-tie [list file $state]]
    }

    return $_local
}

proc ::sak::registry::Refresh {} {
    variable _local
    $_local destroy
    set _local {}
    Setup
    return
}

namespace eval ::sak::registry {
    variable _here    [file dirname [info script]]

    variable statedir [file join ~ .Tcllib]
    variable state    [file join $statedir Registry]
    variable _local   {}
}

##
# ###

package provide sak::registry 1.0

# ###
## Data structures
#
## Core is a tree (struct::tree), keys are lists, mapping to a node,
## starting from the root. Attributes are node attributes. A prefix is
## used to distinguish them from the attributes used for internal
## purposes.
