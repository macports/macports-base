# -*- tcl -*-
# (C) 2008 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

package require  sak::animate
package require  sak::feedback
package require  sak::color

getpackage textutil::repeat textutil/repeat.tcl
getpackage doctools         doctools/doctools.tcl

namespace eval ::sak::validate::manpages {
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

proc ::sak::validate::manpages {modules mode stem tclv} {
    manpages::run $modules $mode $stem $tclv
    manpages::summary
    return
}

proc ::sak::validate::manpages::run {modules mode stem tclv} {
    sak::feedback::init $mode $stem
    sak::feedback::first log  "\[ Documentation \] ==============================================="
    sak::feedback::first unc  "\[ Documentation \] ==============================================="
    sak::feedback::first fail "\[ Documentation \] ==============================================="
    sak::feedback::first warn "\[ Documentation \] ==============================================="
    sak::feedback::first miss "\[ Documentation \] ==============================================="
    sak::feedback::first none "\[ Documentation \] ==============================================="

    # Preprocessing of module names to allow better formatting of the
    # progress output, i.e. vertically aligned columns

    # Per module we can distinguish the following levels of
    # documentation completeness and validity

    # Completeness:
    # - No package has documentation
    # - Some, but not all packages have documentation
    # - All packages have documentation.
    #
    # Validity, restricted to the set packages which have documentation:
    # - Documentation has errors and warnings
    # - Documentation has errors, but no warnings.
    # - Documentation has no errors, but warnings.
    # - Documentation has neither errors nor warnings.

    # Progress report per module: Packages it is working on.
    # Summary at module level:
    # - Number of packages, number of packages with documentation,
    # - Number of errors, number of warnings.

    # Full log:
    # - Lists packages without documentation.
    # - Lists packages with errors/warnings.
    # - Lists the exact errors/warnings per package, and location.

    # Global preparation: Pull information about all packages and the
    # modules they belong to.

    ::doctools::new dt -format desc -deprecated 1

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

	# Per module: Find all doctools manpages inside and process
	# them. We get errors, warnings, and determine the package(s)
	# they may belong to.

	# Per package: Have they doc files claiming them? After that,
	# are doc files left over (i.e. without a package)?

	ProcessPages    $m
	ProcessPackages $m
	ProcessUnclaimed
	ModuleSummary
    }

    dt destroy
    return
}

proc ::sak::validate::manpages::summary {} {
    Summary
    return
}

# ###

proc ::sak::validate::manpages::ProcessPages {m} {
    !claims
    dt configure -module $m
    foreach f [glob -nocomplain [file join [At $m] *.man]] {
	ProcessManpage $f
    }
    return
}

proc ::sak::validate::manpages::ProcessManpage {f} {
    =file              $f
    dt configure -file $f

    if {[catch {
	dt format [get_input $f]
    } msg]} {
	+e $msg
    } else {
	foreach {pkg _ _} $msg { +claim $pkg }
    }

    set warnings [dt warnings]
    if {![llength $warnings]} return

    foreach msg $warnings { +w $msg }
    return
}

proc ::sak::validate::manpages::ProcessPackages {m} {
    !used
    if {![HasPackages $m]} return

    foreach p [ThePackages $m] {
	+pkg $p
	if {[claimants $p]} {
	    +doc $p
	} else {
	    nodoc $p
	}
    }
    return
}

proc ::sak::validate::manpages::ProcessUnclaimed {} {
    variable claims
    if {![array size claims]} return
    foreach p [lsort -dict [array names claims]] {
	foreach fx $claims($p) { +u $fx }
    }
    return
}

###

proc ::sak::validate::manpages::=file {f} {
    variable current [file tail $f]
    = "$current ..."
    return
}

###

proc ::sak::validate::manpages::!claims {} {
    variable    claims
    array unset claims *
    return
}

proc ::sak::validate::manpages::+claim {pkg} {
    variable current
    variable claims
    lappend  claims($pkg) $current
    return
}

proc ::sak::validate::manpages::claimants {pkg} {
    variable claims
    expr { [info exists claims($pkg)] && [llength $claims($pkg)] }
}


###

proc ::sak::validate::manpages::!used {} {
    variable    used
    array unset used *
    return
}

proc ::sak::validate::manpages::+use {pkg} {
    variable used
    variable claims
    foreach fx $claims($pkg) { set used($fx) . }
    unset claims($pkg)
    return
}

###

proc ::sak::validate::manpages::MapPackages {} {
    variable    pkg
    array unset pkg *

    !
    += Package
    foreach {pname pdata} [ipackages] {
	= "$pname ..."
	foreach {pver pmodule} $pdata break
	lappend pkg($pmodule) $pname
    }
    !
    =| {Packages mapped ...}
    return
}

proc ::sak::validate::manpages::HasPackages {m} {
    variable pkg
    expr { [info exists pkg($m)] && [llength $pkg($m)] }
}

proc ::sak::validate::manpages::ThePackages {m} {
    variable pkg
    return [lsort -dict $pkg($m)]
}

###

proc ::sak::validate::manpages::+pkg {pkg} {
    variable mtotal ; incr mtotal
    variable total  ; incr total
    return
}

proc ::sak::validate::manpages::+doc {pkg} {
    variable mhavedoc ; incr mhavedoc
    variable havedoc  ; incr havedoc
    = "$pkg Ok"
    +use $pkg
    return
}

proc ::sak::validate::manpages::nodoc {pkg} {
    = "$pkg Bad"
    log "@@ WARN  No documentation: $pkg"
    return
}

###

proc ::sak::validate::manpages::+w {msg} {
    variable mwarnings ; incr mwarnings
    variable warnings  ; incr warnings
    variable current
    foreach {a b c} [split $msg \n] break
    log "@@ WARN  $current: [Trim $a] [Trim $b] [Trim $c]"
    return
}

proc ::sak::validate::manpages::+e {msg} {
    variable merrors ; incr merrors
    variable errors  ; incr errors
    variable current
    log "@@ ERROR $current $msg"
    return
}

proc ::sak::validate::manpages::+u {f} {
    variable used
    if {[info exists used($f)]} return
    variable munclaimed ; incr munclaimed
    variable unclaimed  ; incr unclaimed
    set used($f) .
    log "@@ WARN  Unclaimed documentation file: $f"
    return
}

###

proc ::sak::validate::manpages::Count {modules} {
    variable maxml 0
    !
    foreach m [linsert $modules 0 Module] {
	= "M $m"
	set l [string length $m]
	if {$l > $maxml} {set maxml $l}
    }
    =| "Validate documentation (existence, errors, warnings) ..."
    return
}

proc ::sak::validate::manpages::Head {m} {
    variable maxml
    += ${m}[blank [expr {$maxml - [string length $m]}]]
    return
}

###

proc ::sak::validate::manpages::InitModuleCounters {} {
    variable mtotal     0
    variable mhavedoc   0
    variable munclaimed 0
    variable merrors    0
    variable mwarnings  0
    return
}

proc ::sak::validate::manpages::ModuleSummary {} {
    variable mtotal
    variable mhavedoc
    variable munclaimed
    variable merrors
    variable mwarnings

    set complete [F $mhavedoc]/[F $mtotal]
    set not      "! [F [expr {$mtotal - $mhavedoc}]]"
    set err      "E [F $merrors]"
    set warn     "W [F $mwarnings]"
    set unc      "U [F $munclaimed]"

    if {$munclaimed} {
	set unc [=cya $unc]
	>> unc
    }
    if {!$mhavedoc && $mtotal} {
	set complete [=red $complete]
	set not      [=red $not]
	>> none
    } elseif {$mhavedoc < $mtotal} {
	set complete [=yel $complete]
	set not      [=yel $not]
	>> miss
    }
    if {$merrors} {
	set err  [=red $err]
	set warn [=yel $warn]
	>> fail
    } elseif {$mwarnings} {
	set warn [=yel $warn]
	>> warn
    }

    =| "~~ $complete $not $unc $err $warn"
    return
}

###

proc ::sak::validate::manpages::InitCounters {} {
    variable total     0
    variable havedoc   0
    variable unclaimed 0
    variable errors    0
    variable warnings  0
    return
}

proc ::sak::validate::manpages::Summary {} {
    variable total
    variable havedoc
    variable unclaimed
    variable errors
    variable warnings

    set tot   [F $total]
    set doc   [F $havedoc]
    set udc   [F [expr {$total - $havedoc}]]

    set unc   [F $unclaimed]
    set per   [format %6.2f [expr {$havedoc*100./$total}]]
    set uper  [format %6.2f [expr {($total - $havedoc)*100./$total}]]
    set err   [F $errors]
    set wrn   [F $warnings]

    if {$errors}    { set err [=red $err] }
    if {$warnings}  { set wrn [=yel $wrn] }
    if {$unclaimed} { set unc [=cya $unc] }

    if {!$havedoc && $total} {
	set doc [=red $doc]
	set udc [=red $udc]
    } elseif {$havedoc < $total} {
	set doc [=yel $doc]
	set udc [=yel $udc]
    }

    sum ""
    sum "Documentation statistics"
    sum "#Packages:     $tot"
    sum "#Documented:   $doc (${per}%)"
    sum "#Undocumented: $udc (${uper}%)"
    sum "#Unclaimed:    $unc"
    sum "#Errors:       $err"
    sum "#Warnings:     $wrn"
    return
}

###

proc ::sak::validate::manpages::F {n} { format %6d $n }

proc ::sak::validate::manpages::Trim {text} {
    regsub {^[^:]*:} $text {} text
    return [string trim $text]
}

###

proc ::sak::validate::manpages::At {m} {
    global distribution
    return [file join $distribution modules $m]
}

# ###

namespace eval ::sak::validate::manpages {
    # Max length of module names and patchlevel information.
    variable maxml 0

    # Counters across all modules
    variable total     0 ; # Number of packages overall.
    variable havedoc   0 ; # Number of packages with documentation.
    variable unclaimed 0 ; # Number of manpages not claimed by a specific package.
    variable errors    0 ; # Number of errors found in all documentation.
    variable warnings  0 ; # Number of warnings found in all documentation.

    # Same counters, per module.
    variable mtotal     0
    variable mhavedoc   0
    variable munclaimed 0
    variable merrors    0
    variable mwarnings  0

    # Name of currently processed manpage
    variable current ""

    # Map from packages to files claiming to document them.
    variable  claims
    array set claims {}

    # Set of files taken by packages, as array
    variable  used
    array set used {}

    # Map from modules to packages contained in them
    variable  pkg
    array set pkg {}
}

##
# ###

package provide sak::validate::manpages 1.0
