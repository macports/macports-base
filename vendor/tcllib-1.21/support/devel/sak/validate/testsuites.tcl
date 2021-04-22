# -*- tcl -*-
# (C) 2008 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

package require  sak::animate
package require  sak::feedback
package require  sak::color

getpackage textutil::repeat textutil/repeat.tcl
getpackage interp interp/interp.tcl

namespace eval ::sak::validate::testsuites {
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

proc ::sak::validate::testsuites {modules mode stem tclv} {
    testsuites::run $modules $mode $stem $tclv
    testsuites::summary
    return
}

proc ::sak::validate::testsuites::run {modules mode stem tclv} {
    sak::feedback::init $mode $stem
    sak::feedback::first log  "\[ Testsuites \] =================================================="
    sak::feedback::first unc  "\[ Testsuites \] =================================================="
    sak::feedback::first fail "\[ Testsuites \] =================================================="
    sak::feedback::first miss "\[ Testsuites \] =================================================="
    sak::feedback::first none "\[ Testsuites \] =================================================="

    # Preprocessing of module names to allow better formatting of the
    # progress output, i.e. vertically aligned columns

    # Per module we can distinguish the following levels of
    # testsuite completeness:
    # - No package has a testsuite
    # - Some, but not all packages have a testsuite
    # - All packages have a testsuite.
    #
    # Validity of the testsuites is not done here. It requires
    # execution, see 'sak test run ...'.

    # Progress report per module: Packages it is working on.
    # Summary at module level:
    # - Number of packages, number of packages with testsuites,

    # Full log:
    # - Lists packages without testsuites.

    # Global preparation: Pull information about all packages and the
    # modules they belong to.

    Setup
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

	# Per module: Find all testsuites in the module and process
	# them. We determine the package(s) they may belong to.

	# Per package: Have they .test files claiming them? After
	# that, are .test files left over (i.e. without a package)?

	ProcessTestsuites $m
	ProcessPackages   $m
	ProcessUnclaimed
	ModuleSummary
    }

    Shutdown
    return
}

proc ::sak::validate::testsuites::summary {} {
    Summary
    return
}

# ###

proc ::sak::validate::testsuites::ProcessTestsuites {m} {
    !claims
    foreach f [glob -nocomplain [file join [At $m] *.test]] {
	ProcessTestsuite $f
    }
    return
}

proc ::sak::validate::testsuites::ProcessTestsuite {f} {
    variable testing
    =file $f

    if {[catch {
	Scan [get_input $f]
    } msg]} {
	+e $msg
    } else {
	foreach p $testing { +claim $p }
    }


    return
}

proc ::sak::validate::testsuites::Setup {} {
    variable ip [interp create]

    # Make it mostly empty (We keep the 'set' command).

    foreach n [interp eval $ip [list ::namespace children ::]] {
	if {[string equal $n ::tcl]} continue
	interp eval $ip [list namespace delete $n]
    }
    foreach c [interp eval $ip [list ::info commands]] {
	if {[string equal $c set]}       continue
	if {[string equal $c if]}        continue
	if {[string equal $c rename]}    continue
	if {[string equal $c namespace]} continue
	interp eval $ip [list ::rename $c {}]
    }

    if {![package vsatisfies [package present Tcl] 8.6]} {
	interp eval $ip [list ::namespace delete ::tcl]
    }
    interp eval $ip [list ::rename namespace {}]
    interp eval $ip [list ::rename rename    {}]

    foreach m {
	testing unknown useLocal useLocalKeep useAccel
    } {
	interp alias $ip $m {} ::sak::validate::testsuites::Process/$m $ip
    }
    return
}

proc ::sak::validate::testsuites::Shutdown {} {
    variable ip
    interp delete $ip
    return
}

proc ::sak::validate::testsuites::Scan {data} {
    variable ip
    while {1} {
	if {[catch {
	    $ip eval $data
	} msg]} {
	    if {[string match {can't read "*": no such variable} $msg]} {
		regexp  {can't read "(.*)": no such variable} $msg -> var
		log "@@ + variable \"$var\""
		$ip eval [list set $var {}]
		continue
	    }
	    return -code error $msg
	}
	break
    }
    return
}

proc ::sak::validate::testsuites::Process/useTcllibC {ip args} {
    return 0
}

proc ::sak::validate::testsuites::Process/unknown {ip args} {
    return 0
}

proc ::sak::validate::testsuites::Process/testing {ip script} {
    variable testing {}
    $ip eval $script
    return -code return
}

proc ::sak::validate::testsuites::Process/useLocal {ip f p args} {
    variable testing
    lappend  testing $p
    return
}

proc ::sak::validate::testsuites::Process/useLocalKeep {ip f p args} {
    variable testing
    lappend  testing $p
    return
}

proc ::sak::validate::testsuites::Process/useAccel {ip _ f p} {
    variable testing
    lappend  testing $p
    return
}

proc ::sak::validate::testsuites::ProcessPackages {m} {
    !used
    if {![HasPackages $m]} return

    foreach p [ThePackages $m] {
	+pkg $p
	if {[claimants $p]} {
	    +tests $p
	} else {
	    notests $p
	}
    }
    return
}

proc ::sak::validate::testsuites::ProcessUnclaimed {} {
    variable claims
    if {![array size claims]} return
    foreach p [lsort -dict [array names claims]] {
	foreach fx $claims($p) { +u $fx }
    }
    return
}

###

proc ::sak::validate::testsuites::=file {f} {
    variable current [file tail $f]
    = "$current ..."
    return
}

###

proc ::sak::validate::testsuites::!claims {} {
    variable    claims
    array unset claims *
    return
}

proc ::sak::validate::testsuites::+claim {pkg} {
    variable current
    variable claims
    lappend  claims($pkg) $current
    return
}

proc ::sak::validate::testsuites::claimants {pkg} {
    variable claims
    expr { [info exists claims($pkg)] && [llength $claims($pkg)] }
}


###

proc ::sak::validate::testsuites::!used {} {
    variable    used
    array unset used *
    return
}

proc ::sak::validate::testsuites::+use {pkg} {
    variable used
    variable claims
    foreach fx $claims($pkg) { set used($fx) . }
    unset claims($pkg)
    return
}

###

proc ::sak::validate::testsuites::MapPackages {} {
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

proc ::sak::validate::testsuites::HasPackages {m} {
    variable pkg
    expr { [info exists pkg($m)] && [llength $pkg($m)] }
}

proc ::sak::validate::testsuites::ThePackages {m} {
    variable pkg
    return [lsort -dict $pkg($m)]
}

###

proc ::sak::validate::testsuites::+pkg {pkg} {
    variable mtotal ; incr mtotal
    variable total  ; incr total
    return
}

proc ::sak::validate::testsuites::+tests {pkg} {
    variable mhavetests ; incr mhavetests
    variable havetests  ; incr havetests
    = "$pkg Ok"
    +use $pkg
    return
}

proc ::sak::validate::testsuites::notests {pkg} {
    = "$pkg Bad"
    log "@@ WARN  No testsuite: $pkg"
    return
}

###

proc ::sak::validate::testsuites::+e {msg} {
    variable merrors ; incr merrors
    variable errors  ; incr errors
    variable current
    log "@@ ERROR $current $msg"
    return
}

proc ::sak::validate::testsuites::+u {f} {
    variable used
    if {[info exists used($f)]} return
    variable munclaimed ; incr munclaimed
    variable unclaimed  ; incr unclaimed
    set used($f) .
    log "@@ NOTE  Unclaimed testsuite $f"
    return
}

###

proc ::sak::validate::testsuites::Count {modules} {
    variable maxml 0
    !
    foreach m [linsert $modules 0 Module] {
	= "M $m"
	set l [string length $m]
	if {$l > $maxml} {set maxml $l}
    }
    =| "Validate testsuites (existence) ..."
    return
}

proc ::sak::validate::testsuites::Head {m} {
    variable maxml
    += ${m}[blank [expr {$maxml - [string length $m]}]]
    return
}

###

proc ::sak::validate::testsuites::InitModuleCounters {} {
    variable mtotal     0
    variable mhavetests 0
    variable munclaimed 0
    variable merrors    0
    return
}

proc ::sak::validate::testsuites::ModuleSummary {} {
    variable mtotal
    variable mhavetests
    variable munclaimed
    variable merrors

    set complete [F $mhavetests]/[F $mtotal]
    set not      "! [F [expr {$mtotal - $mhavetests}]]"
    set err      "E [F $merrors]"
    set unc      "U [F $munclaimed]"

    if {$munclaimed} {
	set unc [=cya $unc]
	>> unc
    }
    if {!$mhavetests && $mtotal} {
	set complete [=red $complete]
	set not      [=red $not]
	>> none
    } elseif {$mhavetests < $mtotal} {
	set complete [=yel $complete]
	set not      [=yel $not]
	>> miss
    }
    if {$merrors} {
	set err [red]$err[rst]
	>> fail
    }

    =| "~~ $complete $not $unc $err"
    return
}

###

proc ::sak::validate::testsuites::InitCounters {} {
    variable total     0
    variable havetests 0
    variable unclaimed 0
    variable errors    0
    return
}

proc ::sak::validate::testsuites::Summary {} {
    variable total
    variable havetests
    variable unclaimed
    variable errors

    set tot   [F $total]
    set tst   [F $havetests]
    set uts   [F [expr {$total - $havetests}]]
    set unc   [F $unclaimed]
    set per   [format %6.2f [expr {$havetests*100./$total}]]
    set uper  [format %6.2f [expr {($total - $havetests)*100./$total}]]
    set err   [F $errors]

    if {$errors}    { set err [=red $err] }
    if {$unclaimed} { set unc [=cya $unc] }

    if {!$havetests && $total} {
	set tst [=red $tst]
	set uts [=red $uts]
    } elseif {$havetests < $total} {
	set tst [=yel $tst]
	set uts [=yel $uts]
    }

    sum ""
    sum "Testsuite statistics"
    sum "#Packages:     $tot"
    sum "#Tested:       $tst (${per}%)"
    sum "#Untested:     $uts (${uper}%)"
    sum "#Unclaimed:    $unc"
    sum "#Errors:       $err"
    return
}

###

proc ::sak::validate::testsuites::F {n} { format %6d $n }

###

proc ::sak::validate::testsuites::At {m} {
    global distribution
    return [file join $distribution modules $m]
}

# ###

namespace eval ::sak::validate::testsuites {
    # Max length of module names and patchlevel information.
    variable maxml 0

    # Counters across all modules
    variable total     0 ; # Number of packages overall.
    variable havetests 0 ; # Number of packages with testsuites.
    variable unclaimed 0 ; # Number of testsuites not claimed by a specific package.
    variable errors    0 ; # Number of errors found with all testsuites.

    # Same counters, per module.
    variable mtotal     0
    variable mhavetests 0
    variable munclaimed 0
    variable merrors    0

    # Name of currently processed testsuite
    variable current ""

    # Map from packages to files claiming to test them.
    variable  claims
    array set claims {}

    # Set of files taken by packages, as array
    variable  used
    array set used {}

    # Map from modules to packages contained in them
    variable  pkg
    array set pkg {}

    # Transient storage used while collecting packages per testsuite.
    variable testing {}
    variable ip      {}
}

##
# ###

package provide sak::validate::testsuites 1.0
