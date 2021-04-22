# -*- tcl -*-
# (C) 2008 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

package require  sak::animate
package require  sak::feedback
package require  sak::color

getpackage textutil::repeat textutil/repeat.tcl
getpackage interp           interp/interp.tcl
getpackage struct::set      struct/sets.tcl
getpackage struct::list     struct/list.tcl

namespace eval ::sak::validate::versions {
    namespace import ::textutil::repeat::blank
    namespace import ::sak::color::*
    namespace import ::sak::feedback::!
    namespace import ::sak::feedback::>>
    namespace import ::sak::feedback::+=
    namespace import ::sak::feedback::=
    namespace import ::sak::feedback::=|
    namespace import ::sak::feedback::log
    namespace import ::sak::feedback::summary
    rename summary sum
}

# ###

proc ::sak::validate::versions {modules mode stem tclv} {
    versions::run $modules $mode $stem $tclv
    versions::summary
    return
}

proc ::sak::validate::versions::run {modules mode stem tclv} {
    sak::feedback::init $mode $stem
    sak::feedback::first log  "\[ Versions \] ===================================================="
    sak::feedback::first warn "\[ Versions \] ===================================================="
    sak::feedback::first fail "\[ Versions \] ===================================================="

    # Preprocessing of module names to allow better formatting of the
    # progress output, i.e. vertically aligned columns

    # Per module
    # - List modules without package index (error)
    # - List packages provided missing from pkgIndex.tcl
    # - List packages in the pkgIndex.tcl, but not provided.
    # - List packages where provided and indexed versions differ.

    Count $modules
    MapPackages

    InitCounters
    foreach m $modules {
	# Skip tcllibc shared library, not a module.
	if {[string equal $m tcllibc]} continue

	InitModuleCounters
	!
	log "@@ Module $m"
	Head $m

	if {![llength [glob -nocomplain [file join [At $m] pkgIndex.tcl]]]} {
	    +e "No package index"
	} else {
	    # Compare package provided to ifneeded.

	    struct::list assign \
		[struct::set intersect3 [Indexed $m] [Provided $m]] \
		compare only_indexed only_provided

	    foreach p [lsort -dict $only_indexed ] { +w "Indexed/No Provider:  $p" }
	    foreach p [lsort -dict $only_provided] { +w "Provided/Not Indexed: $p" }

	    foreach p [lsort -dict $compare] {
		set iv [IndexedVersions  $m $p]
		set pv [ProvidedVersions $m $p]
		if {[struct::set equal $iv $pv]} continue

		struct::list assign \
		    [struct::set intersect3 $pv $iv] \
		    __ pmi imp

		+w "Indexed </> Provided: $p \[<$imp </> $pmi\]"
	    }
	}
	ModuleSummary
    }
    return
}

proc ::sak::validate::versions::summary {} {
    Summary
    return
}

# ###

proc ::sak::validate::versions::MapPackages {} {
    variable    pkg
    array unset pkg *

    !
    += Package
    foreach {pname pdata} [ipackages] {
	= "$pname ..."
	foreach {pvlist pmodule} $pdata break
	lappend pkg(mi,$pmodule) $pname
	lappend pkg(vi,$pmodule,$pname) $pvlist

	foreach {pname pvlist} [ppackages $pmodule] {
	    lappend pkg(mp,$pmodule) $pname
	    lappend pkg(vp,$pmodule,$pname) $pvlist
	}
    }
    !
    =| {Packages mapped ...}
    return
}

proc ::sak::validate::versions::Provided {m} {
    variable pkg
    if {![info exists pkg(mp,$m)]} { return {} }
    return [lsort -dict $pkg(mp,$m)]
}

proc ::sak::validate::versions::Indexed {m} {
    variable pkg
    if {![info exists pkg(mi,$m)]} { return {} }
    return [lsort -dict $pkg(mi,$m)]
}

proc ::sak::validate::versions::ProvidedVersions {m p} {
    variable pkg
    return [lsort -dict $pkg(vp,$m,$p)]
}

proc ::sak::validate::versions::IndexedVersions {m p} {
    variable pkg
    return [lsort -dict $pkg(vi,$m,$p)]
}

###

proc ::sak::validate::versions::+e {msg} {
    variable merrors ; incr merrors
    variable errors  ; incr errors
    log "@@ ERROR $msg"
    return
}

proc ::sak::validate::versions::+w {msg} {
    variable mwarnings ; incr mwarnings
    variable warnings  ; incr warnings
    log "@@ WARN  $msg"
    return
}

proc ::sak::validate::versions::Count {modules} {
    variable maxml 0
    !
    foreach m [linsert $modules 0 Module] {
	= "M $m"
	set l [string length $m]
	if {$l > $maxml} {set maxml $l}
    }
    =| "Validate versions (indexed vs. provided) ..."
    return
}

proc ::sak::validate::versions::Head {m} {
    variable maxml
    += ${m}[blank [expr {$maxml - [string length $m]}]]
    return
}

###

proc ::sak::validate::versions::InitModuleCounters {} {
    variable merrors    0
    variable mwarnings  0
    return
}

proc ::sak::validate::versions::ModuleSummary {} {
    variable merrors
    variable mwarnings

    set err "E [F $merrors]"
    set wrn "W [F $mwarnings]"

    if {$mwarnings} { set wrn [=yel $wrn] ; >> warn }
    if {$merrors}   { set err [=red $err] ; >> fail }

    =| "~~ $err $wrn"
    return
}

###

proc ::sak::validate::versions::InitCounters {} {
    variable errors    0
    variable warnings  0
    return
}

proc ::sak::validate::versions::Summary {} {
    variable errors
    variable warnings

    set err   [F $errors]
    set wrn   [F $warnings]

    if {$errors}    { set err [=red $err] }
    if {$warnings}  { set wrn [=yel $wrn] }

    sum ""
    sum "Versions statistics"
    sum "#Errors:       $err"
    sum "#Warnings:     $wrn"
    return
}

###

proc ::sak::validate::versions::F {n} { format %6d $n }

###

proc ::sak::validate::versions::At {m} {
    global distribution
    return [file join $distribution modules $m]
}

# ###

namespace eval ::sak::validate::versions {
    # Max length of module names and patchlevel information.
    variable maxml 0

    # Counters across all modules
    variable errors    0 ; # Number of errors found (= modules without pkg index)
    variable warnings  0 ; # Number of warings

    # Same counters, per module.
    variable merrors    0
    variable mwarnings  0

    # Map from modules to packages and their versions.
    variable  pkg
    array set pkg {}
}

##
# ###

package provide sak::validate::versions 1.0
