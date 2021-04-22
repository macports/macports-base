# -*- tcl -*-
# (C) 2009 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

package require sak::color
package require sak::review

namespace eval ::sak::readme {
    namespace import ::sak::color::*
}

# ###

proc ::sak::readme::usage {} {
    package require sak::help
    puts stdout \n[sak::help::on readme]
    exit 1
}

proc ::sak::readme::run {theformat} {
    global package_name package_version

    set pname [string totitle $package_name]

    getpackage struct::set      struct/sets.tcl
    getpackage struct::matrix   struct/matrix.tcl
    getpackage textutil::adjust textutil/adjust.tcl

    # Future: Consolidate with ... review ...
    # Determine which packages are potentially changed, from the set
    # of modules touched since the last release, as per the fossil
    # repository's commit log.

    foreach {trunk   tuid} [sak::review::Leaf          trunk]   break ;# rid + uuid
    foreach {release ruid} [sak::review::YoungestOfTag release] break ;# datetime+uuid

    sak::review::AllParentsAfter $trunk $tuid $release $ruid -> rid uuid numparents {
	if {$numparents < 2} {
	    sak::review::FileSet $rid -> path action {
		lappend modifiedm [lindex [file split $path] 1]
	    }
	}
    }
    set modifiedm [lsort -unique $modifiedm]

    set issues {}

    # package -> list(version)
    set old_version    [loadoldv [location_PACKAGES]]
    array set releasep [loadpkglist [location_PACKAGES]]
    array set currentp [ipackages]

    array set changed {}
    foreach p [array names currentp] {
	foreach {vlist module} $currentp($p) break
	set currentp($p) $vlist
	set changed($p) [struct::set contains $modifiedm $module]
    }

    LoadNotes

    # Containers for results
    struct::matrix NEW ; NEW add columns 4 ; # module, package, version, notes
    struct::matrix CHG ; CHG add columns 5 ; # module, package, old/new version, notes
    struct::matrix ICH ; ICH add columns 5 ; # module, package, old/new version, notes
    struct::matrix CNT ; CNT add columns 5 ; # overview, counters
    struct::matrix LEG ; LEG add columns 3 ; # legend, fixed

    LEG add row {Change Details Comments}
    LEG add row {Major API {__incompatible__ API changes}}
    LEG add row {Minor EF  {Extended functionality, API}}
    LEG add row {{}    I   {Major rewrite, but no API change}}
    LEG add row {Patch B   {Bug fixes}}
    LEG add row {{}    EX  {New examples}}
    LEG add row {{}    P   {Performance enhancement}}
    LEG add row {None  T   {Testsuite changes}}
    LEG add row {{}    D   {Documentation updates}}
    
    set UCH {}

    NEW add row {Module Package {New Version} Comments}
    CHG add row [list Module Package "From $old_version" "To $package_version" Comments]
    ICH add row [list Module Package "From $old_version" "To $package_version" Comments]

    set newp {} ; set chgp {} ; set ichp {}
    set newm {} ; set chgm {} ; set ichm {} ; set uchm {}
    set nm 0
    set np 0

    # Process all packages in all modules ...
    foreach m [lsort -dict [modules]] {
	puts stderr ...$m
	incr nm

	foreach name [lsort -dict [Provided $m]] {
	    #puts stderr ......$p
	    incr np

	    # Define list of versions, if undefined so far.
	    if {![info exists currentp($name)]} {
		set currentp($name) {}
	    }

	    # Detect and process new packages.

	    if {![info exists releasep($name)]} {
		# New package.
		foreach v $currentp($name) {
		    puts stderr .........NEW
		    NEW add row [list $m $name $v [Note $m $name]]
		    lappend newm $m
		    lappend newp $name
		}
		continue
	    }

	    # The package is not new, but possibly changed. And even
	    # if the version has not changed it may have been, this is
	    # indicated by changed(), which is based on the ChangeLog.

	    set vequal [struct::set equal $releasep($name) $currentp($name)]
	    set note   [Note $m $name]

	    if {$vequal && ($note ne {})} {
		if {$note eq "---"} {
		    # The note declares the package as unchanged.
		    puts stderr .........UNCHANGED/1
		    lappend uchm $m
		    lappend UCH $name
		} else {
		    # Note for package without version changes => must be invisible
		    puts stderr .........INVISIBLE-CHANGE
		    Enter $m $name $note ICH
		    lappend ichm $m
		    lappend ichp $name
		}
		continue
	    }

	    if {!$changed($name) && $vequal} {
		# Versions are unchanged, changelog also indicates no
		# change. No particular attention here.
		
		puts stderr .........UNCHANGED/2
		lappend uchm $m
		lappend UCH $name
		continue
	    }

	    if {$changed($name) && !$vequal} {
		# Both changelog and version number indicate a
		# change. Small alert, have to classify the order of
		# changes. But not if there is a note, this is assumed
		# to be the classification.

		if {$note eq {}} {
		    set note "\t=== Classify changes."
		    lappend issues [list $m $name "Classify changes"]
		}
		Enter $m $name $note

		lappend chgm $m
		lappend chgp $name
		continue
	    }

	    #     Changed according to ChangeLog, Version is not. ALERT.
	    # or: Versions changed, but according to changelog nothing
	    #     in the code. ALERT.

	    # Suppress the alert if we have a note, and dispatch per
	    # the note's contents (some tags are special, instructions
	    # to us here).

	    if {($note eq {})} {
		if {$changed($name)} {
		    # Changed according to ChangeLog, Version is not. ALERT.
		    set note "\t<<< MISMATCH. Version ==, ChangeLog ++"
		} else {
		    set note "\t<<< MISMATCH. ChangeLog ==, Version ++"
		}

		lappend issues [list $m $name [string range $note 5 end]]
	    }

	    Enter $m $name $note
	    lappend chgm $m
	    lappend chgp $name
	}
    }

    # .... process the matrices and others results, make them presentable ...

    CNT add row {{} {} {} {} {}}
    
    set newp [llength [lsort -uniq $newp]]
    set newm [llength [lsort -uniq $newm]]
    if {$newp} {
	CNT add row [list $newp {new packages} in $newm modules]
    }

    set chgp [llength [lsort -uniq $chgp]]
    set chgm [llength [lsort -uniq $chgm]]
    if {$chgp} {
	CNT add row [list $chgp {changed packages} in $chgm modules]
    }

    set ichp [llength [lsort -uniq $ichp]]
    set ichm [llength [lsort -uniq $ichm]]
    if {$ichp} {
	CNT add row [list $ichp {internally changed packages} in $ichm modules]
    }

    set uchp [llength [lsort -uniq $UCH]]
    set uchm [llength [lsort -uniq $uchm]]
    if {$uchp} {
	CNT add row [list $uchp {unchanged packages} in $uchm modules]
    }

    CNT add row [list $np {packages, total} in $nm {modules, total}]

    Table CNT Overview {
	CNT delete row 0 ; # strip title row
    } {
	set align [lreplace $align 0 0 r]
	set align [lreplace $align 3 3 r]
    }
    
    Table LEG Legend {
	Sep LEG - 1
    } {
    }

    Table NEW "New in $pname $package_version" {
	Sep NEW - [Clean NEW 1 0]
    } {
	SepMD NEW {} [lrange [Clean NEW 1 0] 1 end-1]
    }

    Table CHG "Changes from $pname $old_version to $package_version" {
	Sep CHG - [Clean CHG 1 0]
    } {
	SepMD CHG {} [lrange [Clean CHG 1 0] 1 end-1]
    }

    Table ICH "Invisible changes (documentation, testsuites)" {
	Sep ICH - [Clean ICH 1 0]
    } {
	SepMD ICH {} [lrange [Clean ICH 1 0] 1 end-1]
    }

    if {[llength $UCH]} {
	Header Unchanged
	puts ""
	puts [Indent "    " [textutil::adjust::adjust \
				 [join [lsort -dict $UCH] {, }] -length 64]]
    }

    if {![llength $issues]} return

    puts stderr [=red "Issues found ([llength $issues])"]
    puts stderr "  Please run \"./sak.tcl review\" to resolve,"
    puts stderr "  then run \"./sak.tcl readme\" again."
    puts stderr Details:

    struct::matrix ISS ; ISS add columns 3
    foreach issue $issues {
	foreach {m p w} $issue break
	set m "  $m"
	ISS add row [list $m $p $w]
    }

    puts stderr [ISS format 2string]


    puts stderr [=red "Issues found ([llength $issues])"]
    puts stderr "  Please run \"./sak.tcl review\" to resolve,"
    puts stderr "  then run \"./sak.tcl readme\" again."
    return
}

proc ::sak::readme::Table {obj title {pretxt {}} {premd {}}} {
    upvar 1 theformat theformat
    if {[$obj rows] < 2} return
    Header $title

    puts ""
    switch -exact -- $theformat {
	txt {
	    uplevel 1 $pretxt
	    puts [Indent "    " [Detrail [$obj format 2string]]]
	}
	md {
	    upvar 1 align align
	    # Column alignment setup.
	    set align [lrepeat [$obj columns] l]
	    
	    uplevel 1 $premd
	    # Header row, then separator, then the remainder.
	    puts |[join [$obj get row 0] |]|
	    puts |[join [string map {
		c ---
		l :---
		r ---:
	    } $align] |]|
	    set n [$obj rows]
	    for {set i 1} {$i < $n} {incr i} {
		puts |[join [$obj get row $i] |]|
	    }
	}
	default {
	    error "Bad format"
	    exit 1
	}
    }
    puts ""
    return
}

proc ::sak::readme::Header {s {sep =}} {
    puts $s
    puts [string repeat $sep [string length $s]]
    return
}

proc ::sak::readme::Enter {m name note {mat CHG}} {
    upvar 1 currentp currentp releasep releasep

    # To handle multiple versions we match the found versions up by
    # major version. We assume that we have only one version per major
    # version. This allows us to detect changes within each major
    # version, new major versions, etc.

    array set om {} ; foreach v $releasep($name) {set om([lindex [split $v .] 0]) $v}
    array set cm {} ; foreach v $currentp($name) {set cm([lindex [split $v .] 0]) $v}

    set all [lsort -dict [struct::set union [array names om] [array names cm]]]

    sakdebug {
	puts @@@@@@@@@@@@@@@@
	parray om
	parray cm
	puts all\ $all
	puts @@@@@@@@@@@@@@@@
    }

    foreach v $all {
	if {[info exists om($v)]} {set ov $om($v)} else {set ov ""}
	if {[info exists cm($v)]} {set cv $cm($v)} else {set cv ""}
	$mat add row [list $m $name $ov $cv $note]
    }
    return
}

proc ::sak::readme::Clean {m start col} {
    set n [$m rows]
    set marks [list $start]
    set last {}
    set lastm -1
    set sq 0

    for {set i $start} {$i < $n} {incr i} {
	set str [$m get cell $col $i]

	if {$str eq $last} {
	    set sq 1
	    $m set cell $col $i {}
	    if {$lastm >= 0} {
		#puts stderr "@ $i / <$last> / <$str> / ++ $lastm"
		lappend marks $lastm
		set lastm -1
	    } else {
		#puts stderr "@ $i / <$last> / <$str> /"
	    }
	} else {
	    set last $str
	    set lastm $i
	    if {$sq} {
		#puts stderr "@ $i / <$last> / <$str> / ++ $i /saved"
		lappend marks $i
		set sq 0
	    } else {
		#puts stderr "@ $i / <$last> / <$str> / saved"
	    }
	}
    }
    return [lsort -uniq -increasing -integer $marks]
}

proc ::sak::readme::Sep {m char marks} {
    #puts stderr "$m = $marks"

    set n [$m columns]
    set sep {}
    for {set i 0} {$i < $n} {incr i} {
	lappend sep [string repeat $char [expr {2+[$m columnwidth $i]}]]
    }

    foreach k [linsert [lsort -decreasing -integer -uniq $marks] 0 end] {
	$m insert row $k $sep
    }
    return
}

proc ::sak::readme::SepMD {m char marks} {
    #puts stderr "$m = $marks"

    set n [$m columns]
    set sep [lreplace [lrepeat $n {}] end end $char]

    foreach k [linsert [lsort -decreasing -integer -uniq $marks] 0 end] {
	$m insert row $k $sep
    }
    return
}

proc ::sak::readme::Indent {pfx text} {
    return ${pfx}[join [split $text \n] \n$pfx]
}

proc ::sak::readme::Detrail {text} {
    set res {}
    foreach line [split $text \n] {
	lappend res [string trimright $line]
    }
    return [join $res \n]
}

proc ::sak::readme::Note {m p} {
    # Look for a note, and present to caller, if any.
    variable notes
    #parray notes
    set k [list $m $p]
    #puts <$k>
    if {[info exists notes($k)]} {
	return [join $notes($k) { }]
    }
    return ""
}

proc ::sak::readme::Provided {m} {
    set result {}
    foreach {p ___} [ppackages $m] {
	lappend result $p
    }
    return $result
}

proc ::sak::readme::LoadNotes {} {
    global distribution
    variable  notes
    array set notes {}

    catch {
	set f [file join $distribution .NOTE]
	set f [open $f r]
	while {![eof $f]} {
	    if {[gets $f line] < 0} continue
	    set line [string trim $line]
	    if {$line == {}} continue
	    foreach {k t} $line break
	    set notes($k) $t
	}
	close $f
    } msg
    return
}

proc ::sak::readme::loadoldv {fname} {
    set f [open $fname r]
    foreach line [split [read $f] \n] {
	set line [string trim $line]
	if {[string match @* $line]} {
	    foreach {__ __ v} $line break
	    close $f
	    return $v
	}
    }
    close $f
    return -code error {Version not found}
}

##
# ###

namespace eval ::sak::readme {
    variable review {}
}

package provide sak::readme 1.0
