# -*- tcl -*-
# (C) 2008 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

package require  sak::animate
package require  sak::feedback
package require  sak::color

getpackage textutil::repeat textutil/repeat.tcl
getpackage doctools         doctools/doctools.tcl

namespace eval ::sak::validate::syntax {
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

proc ::sak::validate::syntax {modules mode stem tclv} {
    syntax::run $modules $mode $stem $tclv
    syntax::summary
    return
}

proc ::sak::validate::syntax::run {modules mode stem tclv} {
    sak::feedback::init $mode $stem
    sak::feedback::first log  "\[ Syntax \] ======================================================"
    sak::feedback::first unc  "\[ Syntax \] ======================================================"
    sak::feedback::first fail "\[ Syntax \] ======================================================"
    sak::feedback::first warn "\[ Syntax \] ======================================================"
    sak::feedback::first miss "\[ Syntax \] ======================================================"
    sak::feedback::first none "\[ Syntax \] ======================================================"

    # Preprocessing of module names to allow better formatting of the
    # progress output, i.e. vertically aligned columns

    # Per module we can distinguish the following levels of
    # syntactic completeness and validity.

    # Rule completeness
    # - No package has pcx rules
    # - Some, but not all packages have pcx rules
    # - All packages have pcx rules
    #
    # Validity. Not of the pcx rules, but of the files in the
    # packages.
    # - Package has errors and warnings
    # - Package has errors, but no warnings.
    # - Package has no errors, but warnings.
    # - Package has neither errors nor warnings.

    # Progress report per module: Modules and packages it is working on.
    # Summary at module level:
    # - Number of packages, number of packages with pcx rules
    # - Number of errors, number of warnings.

    # Full log:
    # - Lists packages without pcx rules.
    # - Lists packages with errors/warnings.
    # - Lists the exact errors/warnings per package, and location.

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

	# Per module: Find all syntax definition (pcx) files inside
	# and process them. Further find all the Tcl files and process
	# them as well. We get errors, warnings, and determine the
	# package(s) they may belong to.

	# Per package: Have they pcx files claiming them? After that,
	# are pcx files left over (i.e. without a package)?

	ProcessAllPCX     $m
	ProcessPackages   $m
	ProcessUnclaimed
	ProcessTclSources $m $tclv
	ModuleSummary
    }

    Shutdown
    return
}

proc ::sak::validate::syntax::summary {} {
    Summary
    return
}

# ###

proc ::sak::validate::syntax::ProcessAllPCX {m} {
    !claims
    foreach f [glob -nocomplain [file join [At $m] *.pcx]] {
	ProcessOnePCX $f
    }
    return
}

proc ::sak::validate::syntax::ProcessOnePCX {f} {
    =file $f

    if {[catch {
	Scan [get_input $f]
    } msg]} {
	+e $msg
    } else {
        +claim $msg
    }

    return
}

proc ::sak::validate::syntax::ProcessPackages {m} {
    !used
    if {![HasPackages $m]} return

    foreach p [ThePackages $m] {
	+pkg $p
	if {[claimants $p]} {
	    +pcx $p
	} else {
	    nopcx $p
	}
    }
    return
}

proc ::sak::validate::syntax::ProcessUnclaimed {} {
    variable claims
    if {![array size claims]} return
    foreach p [lsort -dict [array names claims]] {
	foreach fx $claims($p) { +u $fx }
    }
    return
}

proc ::sak::validate::syntax::ProcessTclSources {m tclv} {
    variable tclchecker
    if {![llength $tclchecker]} return

    foreach t [modtclfiles $m] {
	# Ignore TeX files.
	if {[string equal [file extension $t] .tex]} continue

	=file $t
	set cmd [Command $t $tclv]
	if {[catch {Close [Process [open |$cmd r+]]} msg]} {
	    if {[string match {*child process exited abnormally*} $msg]} continue
	    +e $msg
	}
    }
    return
}

###

proc ::sak::validate::syntax::Setup {} {
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
	pcx::register unknown
    } {
	interp alias $ip $m {} ::sak::validate::syntax::PCX/[string map {:: _} $m] $ip
    }
    return
}

proc ::sak::validate::syntax::Shutdown {} {
    variable ip
    interp delete $ip
    return
}

proc ::sak::validate::syntax::Scan {data} {
    variable ip
    variable pcxpackage
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
    return $pcxpackage
}

proc ::sak::validate::syntax::PCX/pcx_register {ip pkg} {
    variable pcxpackage $pkg
    return
}

proc ::sak::validate::syntax::PCX/unknown {ip args} {
    return 0
}

###

proc ::sak::validate::syntax::Process {pipe} {
    variable current
    set dst log
    while {1} {
	if {[eof  $pipe]} break
	if {[gets $pipe line] < 0} break

	set tline [string trim $line]
	if {[string equal $tline ""]} continue

	if {[string match scanning:* $tline]} {
	    log $line
	    continue
	}
	if {[string match checking:* $tline]} {
	    log $line
	    continue
	}
	if {[regexp {^([^:]*):(\d+) \(([^)]*)\) (.*)$} $tline -> path at code detail]} {
	    = "$current $at $code"
	    set dst code,$code
	    if {[IsError $code]} {
		+e $line
	    } else {
		+w $line
	    }
	}
	log $line $dst
    }
    return $pipe
}

proc ::sak::validate::syntax::IsError {code} {
    variable codetype
    variable codec
    if {[info exists codec($code)]} {
	return $codec($code)
    }

    foreach {p t} $codetype {
	if {![string match $p $code]} continue
	set codec($code) $t
	return $t
    }

    # We assume that codetype contains a default * pattern as the last
    # entry, capturing all unknown codes.
    +e INTERNAL
    exit
}

proc ::sak::validate::syntax::Command {t tclv} {
    # Unix. Construction of the pipe to run the tclchecker against a
    # single tcl file.

    set     cmd [Driver $tclv]
    lappend cmd $t

    #lappend cmd >@ stdout 2>@ stderr
    #puts <<$cmd>>

    return $cmd
}

proc ::sak::validate::syntax::Close {pipe} {
    close $pipe
    return
}

proc ::sak::validate::syntax::Driver {tclv} {
    variable tclchecker
    set cmd $tclchecker

    if {$tclv ne {}} { lappend cmd -use Tcl-$tclv }

    # Make all syntax definition files we may have available to the
    # checker for higher accuracy of its output.
    foreach m [modules] { lappend cmd -pcx [At $m] }

    # Memoize
    proc ::sak::validate::syntax::Driver {tclv} [list return $cmd]
    return $cmd
}

###

proc ::sak::validate::syntax::=file {f} {
    variable current [file tail $f]
    = "$current ..."
    return
}

###

proc ::sak::validate::syntax::!claims {} {
    variable    claims
    array unset claims *
    return
}

proc ::sak::validate::syntax::+claim {pkg} {
    variable current
    variable claims
    lappend  claims($pkg) $current
    return
}

proc ::sak::validate::syntax::claimants {pkg} {
    variable claims
    expr { [info exists claims($pkg)] && [llength $claims($pkg)] }
}


###

proc ::sak::validate::syntax::!used {} {
    variable    used
    array unset used *
    return
}

proc ::sak::validate::syntax::+use {pkg} {
    variable used
    variable claims
    foreach fx $claims($pkg) { set used($fx) . }
    unset claims($pkg)
    return
}

###

proc ::sak::validate::syntax::MapPackages {} {
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

proc ::sak::validate::syntax::HasPackages {m} {
    variable pkg
    expr { [info exists pkg($m)] && [llength $pkg($m)] }
}

proc ::sak::validate::syntax::ThePackages {m} {
    variable pkg
    return [lsort -dict $pkg($m)]
}

###

proc ::sak::validate::syntax::+pkg {pkg} {
    variable mtotal ; incr mtotal
    variable total  ; incr total
    return
}

proc ::sak::validate::syntax::+pcx {pkg} {
    variable mhavepcx ; incr mhavepcx
    variable havepcx  ; incr havepcx
    = "$pkg Ok"
    +use $pkg
    return
}

proc ::sak::validate::syntax::nopcx {pkg} {
    = "$pkg Bad"
    log "@@ WARN  No syntax definition: $pkg"
    return
}

###

proc ::sak::validate::syntax::+w {msg} {
    variable mwarnings ; incr mwarnings
    variable warnings  ; incr warnings
    variable current
    foreach {a b c} [split $msg \n] break
    log "@@ WARN  $current: [Trim $a] [Trim $b] [Trim $c]"
    return
}

proc ::sak::validate::syntax::+e {msg} {
    variable merrors ; incr merrors
    variable errors  ; incr errors
    variable current
    log "@@ ERROR $current $msg"
    return
}

proc ::sak::validate::syntax::+u {f} {
    variable used
    if {[info exists used($f)]} return
    variable munclaimed ; incr munclaimed
    variable unclaimed  ; incr unclaimed
    set used($f) .
    log "@@ WARN  Unclaimed syntax definition file: $f"
    return
}

###

proc ::sak::validate::syntax::Count {modules} {
    variable maxml 0
    !
    foreach m [linsert $modules 0 Module] {
	= "M $m"
	set l [string length $m]
	if {$l > $maxml} {set maxml $l}
    }
    =| "Validate syntax (code, and API definitions) ..."
    return
}

proc ::sak::validate::syntax::Head {m} {
    variable maxml
    += ${m}[blank [expr {$maxml - [string length $m]}]]
    return
}

###

proc ::sak::validate::syntax::InitModuleCounters {} {
    variable mtotal     0
    variable mhavepcx   0
    variable munclaimed 0
    variable merrors    0
    variable mwarnings  0
    return
}

proc ::sak::validate::syntax::ModuleSummary {} {
    variable mtotal
    variable mhavepcx
    variable munclaimed
    variable merrors
    variable mwarnings
    variable tclchecker

    set complete [F $mhavepcx]/[F $mtotal]
    set not      "! [F [expr {$mtotal - $mhavepcx}]]"
    set err      "E [F $merrors]"
    set warn     "W [F $mwarnings]"
    set unc      "U [F $munclaimed]"

    if {$munclaimed} {
	set unc [=cya $unc]
	>> unc
    }
    if {!$mhavepcx && $mtotal} {
	set complete [=red $complete]
	set not      [=red $not]
	>> none
    } elseif {$mhavepcx < $mtotal} {
	set complete [=yel $complete]
	set not      [=yel $not]
	>> miss
    }
    if {[llength $tclchecker]} {
	if {$merrors} {
	    set err  " [=red $err]"
	    set warn " [=yel $warn]"
	    >> fail
	} elseif {$mwarnings} {
	    set err " $err"
	    set warn " [=yel $warn]"
	    >> warn
	} else {
	    set err  " $err"
	    set warn " $warn"
	}
    } else {
	set err  ""
	set warn ""
    }

    =| "~~ $complete $not $unc$err$warn"
    return
}

###

proc ::sak::validate::syntax::InitCounters {} {
    variable total     0
    variable havepcx   0
    variable unclaimed 0
    variable errors    0
    variable warnings  0
    return
}

proc ::sak::validate::syntax::Summary {} {
    variable total
    variable havepcx
    variable unclaimed
    variable errors
    variable warnings
    variable tclchecker

    set tot   [F $total]
    set doc   [F $havepcx]
    set udc   [F [expr {$total - $havepcx}]]

    set unc   [F $unclaimed]
    set per   [format %6.2f [expr {$havepcx*100./$total}]]
    set uper  [format %6.2f [expr {($total - $havepcx)*100./$total}]]
    set err   [F $errors]
    set wrn   [F $warnings]

    if {$errors}    { set err [=red $err] }
    if {$warnings}  { set wrn [=yel $wrn] }
    if {$unclaimed} { set unc [=cya $unc] }

    if {!$havepcx && $total} {
	set doc [=red $doc]
	set udc [=red $udc]
    } elseif {$havepcx < $total} {
	set doc [=yel $doc]
	set udc [=yel $udc]
    }

    if {[llength $tclchecker]} {
	set sfx " ($tclchecker)"
    } else {
	set sfx " ([=cya {No tclchecker available}])"
    }

    sum ""
    sum "Syntax statistics$sfx"
    sum "#Packages:     $tot"
    sum "#Syntax def:   $doc (${per}%)"
    sum "#No syntax:    $udc (${uper}%)"
    sum "#Unclaimed:    $unc"
    if {[llength $tclchecker]} {
	sum "#Errors:       $err"
	sum "#Warnings:     $wrn"
    }
    return
}

###

proc ::sak::validate::syntax::F {n} { format %6d $n }

proc ::sak::validate::syntax::Trim {text} {
    regsub {^[^:]*:} $text {} text
    return [string trim $text]
}

###

proc ::sak::validate::syntax::At {m} {
    global distribution
    return [file join $distribution modules $m]
}

# ###

namespace eval ::sak::validate::syntax {
    # Max length of module names and patchlevel information.
    variable maxml 0

    # Counters across all modules
    variable total     0 ; # Number of packages overall.
    variable havepcx   0 ; # Number of packages with syntax definition (pcx) files.
    variable unclaimed 0 ; # Number of PCX files not claimed by a specific package.
    variable errors    0 ; # Number of errors found in all code.
    variable warnings  0 ; # Number of warnings found in all code.

    # Same counters, per module.
    variable mtotal     0
    variable mhavepcx   0
    variable munclaimed 0
    variable merrors    0
    variable mwarnings  0

    # Name of currently processed syntax definition or code file
    variable current ""

    # Map from packages to files claiming to define the syntax of their API.
    variable  claims
    array set claims {}

    # Set of files taken by packages, as array
    variable  used
    array set used {}

    # Map from modules to packages contained in them
    variable  pkg
    array set pkg {}

    # Transient storage used while collecting packages per syntax definition.
    variable pcxpackage {}
    variable ip         {}

    # Location of the tclchecker used to perform syntactic validation.
    variable tclchecker [auto_execok tclchecker]

    # Patterns for separation of errors from warnings
    variable codetype {
	warn*        0
	nonPort*     0
	pkgUnchecked 0
	pkgVConflict 0
	*            1
    }
    variable codec ; array  set codec {}
}

##
# ###

package provide sak::validate::syntax 1.0
