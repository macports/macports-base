# -*- tcl -*-
# (C) 2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

package require  sak::test::shell
package require  sak::registry
package require  sak::animate
package require  sak::color
# TODO: Rework this package to use the sak::feedback package

getpackage textutil::repeat textutil/repeat.tcl
getpackage fileutil         fileutil/fileutil.tcl
getpackage struct::matrix   struct/matrix.tcl

namespace eval ::sak::test::run {
    namespace import ::textutil::repeat::blank
    namespace import ::sak::color::*
}

# ###

proc ::sak::test::run {argv} {
    variable run::valgrind
    array set config {
	valgrind 0 raw 0 shells {} stem {} log 0
    }

    while {[string match -* [set opt [lindex $argv 0]]]} {
	switch -exact -- $opt {
	    -s - --shell {
		set sh [lindex $argv 1]
		if {![fileutil::test $sh efrx msg "Shell"]} {
		    sak::test::usage $msg
		}
		lappend config(shells) $sh
		set argv [lrange $argv 2 end]
	    }
	    -g - --valgrind {
		if {![llength $valgrind]} {
		    sak::test::usage valgrind not found in the PATH
		}
		incr config(valgrind)
		set argv [lrange $argv 1 end]
	    }
	    -v {
		set config(raw) 1
		set argv [lrange $argv 1 end]
	    }
	    -l - --log {
		set config(log) 1
		set config(stem) [lindex $argv 1]
		set argv         [lrange $argv 2 end]
	    }
	    default {
		sak::test::usage Unknown option "\"$opt\""
	    }
	}
    }

    if {$config(log)} {set config(raw) 0}

    if {![sak::util::checkModules argv]} return

    run::Do config $argv
    return
}

# ###

proc ::sak::test::run::Do {cv modules} {
    upvar 1 $cv config
    variable valgrind
    variable araw     $config(raw)
    variable alog     $config(log)
    # alog => !araw

    set shells $config(shells)
    if {![llength $shells]} {
	catch {set shells [sak::test::shell::list]}
    }
    if {![llength $shells]} {
	set shells [list [info nameofexecutable]]
    }

    if {$alog} {
	variable logext [open $config(stem).log         w]
	variable logsum [open $config(stem).summary     w]
	variable logfai [open $config(stem).failures    w]
	variable logski [open $config(stem).skipped     w]
	variable lognon [open $config(stem).none        w]
	variable logerd [open $config(stem).errdetails  w]
	variable logfad [open $config(stem).faildetails w]
	variable logtim [open $config(stem).timings     w]
    } else {
	variable logext stdout
    }

    # Preprocessing of module names and shell versions to allows
    # better formatting of the progress output, i.e. vertically
    # aligned columns

    if {!$araw} {
	variable maxml 0
	variable maxvl 0
	sak::animate::init
	foreach m $modules {
	    = "M  $m"
	    set l [string length $m]
	    if {$l > $maxml} {set maxml $l}
	}
	foreach sh $shells {
	    = "SH $sh"
	    set v [exec $sh << {puts [info patchlevel]; exit}]
	    set l [string length $v]
	    if {$l > $maxvl} {set maxvl $l}
	}
	=| "Starting ..."
    }

    set total 0
    set pass  0
    set fail  0
    set skip  0
    set err   0

    foreach sh $shells {
	foreach m $modules {
	    set cmd [Command config $m $sh]
	    sak::animate::init
	    if {$alog || $araw} {
		puts  $logext ============================================================
		flush $logext
	    }
	    if {[catch {Close [Process [open |$cmd r+]]} msg]} {
		incr err
		=| "~~ [mag]ERR   ${msg}[rst]"
		if {$alog || $araw} {
		    puts  $logext [mag]$msg[rst]
		    flush $logext
		}
	    }
	    #sak::animate::last Ok
	}
    }

    puts $logext "Passed  [format %6d $pass] of [format %6d $total]"
    puts $logext "Skipped [format %6d $skip] of [format %6d $total]"

    if {$fail} {
	puts $logext "Failed  [red][format %6d $fail][rst] of [format %6d $total]"
    } else {
	puts $logext "Failed  [format %6d $fail] of [format %6d $total]"
    }
    if {$err} {
	puts $logext "#Errors [mag][format %6d $err][rst]"
    } else {
	puts $logext "#Errors [format %6d $err]"
    }

    if {$alog} {
	variable xtimes
	array set times $xtimes

	struct::matrix M
	M add columns 6
	foreach k [lsort -dict [array names times]] {
	    #foreach {shell module testfile} $k break
	    foreach {testnum delta score} $times($k) break
	    M add row [linsert $k end $testnum $delta $score]
	}
	M sort rows -decreasing 5

	M insert row 0 {Shell Module Testsuite Tests Seconds uSec/Test}
	M insert row 1 {===== ====== ========= ===== ======= =========}
	M add    row   {===== ====== ========= ===== ======= =========}

	puts $logsum \nTimings...
	puts $logsum [M format 2string]
    }

    exit [expr {($err || $fail) ? 1 : 0}]
    return
}

# ###

if {$::tcl_platform(platform) == "windows"} {

    proc ::sak::test::run::Command {cv m sh} {
	variable valgrind
	upvar 1 $cv config

	# Windows. Construction of the pipe to run a specific
	# testsuite against a single shell. There is no valgrind to
	# accomodate, and neither can we expect to have unix commands
	# like 'echo' and 'cat' available. 'echo' we can go without. A
	# 'cat' however is needed to merge stdout and stderr of the
	# testsuite for processing here. We use an emuluation written
	# in Tcl.

	set catfile cat[pid].tcl
	fileutil::writeFile $catfile {
	    catch {wm withdraw .}
	    while {![eof stdin]} {puts stdout [gets stdin]}
	    exit
	}

	set     cmd ""
	lappend cmd $sh
	lappend cmd [Driver] -modules [list $m]
	lappend cmd |& $sh $catfile
	#puts <<$cmd>>

	return $cmd
    }

    proc ::sak::test::run::Close {pipe} {
	close $pipe
	file delete cat[pid].tcl
	return
    }
} else {
    proc ::sak::test::run::Command {cv m sh} {
	variable valgrind
	upvar 1 $cv config

	# Unix. Construction of the pipe to run a specific testsuite
	# against a single shell. The command is constructed to work
	# when using valgrind, and works when not using it as well.

	set     script {}
	lappend script [list set argv [list -modules [list $m]]]
	lappend script {set argc 2}
	lappend script [list source [Driver]]
	lappend script exit

	set     cmd ""
	lappend cmd echo [join $script \n]
	lappend cmd |

	if {$config(valgrind)} {
	    foreach e $valgrind {lappend cmd $e}
	    if {$config(valgrind) > 1} {
		lappend cmd --num-callers=8
		lappend cmd --leak-resolution=high
		lappend cmd -v --leak-check=yes
		lappend cmd --show-reachable=yes
	    }
	}
	lappend cmd $sh
	#lappend cmd >@ stdout 2>@ stderr
	lappend cmd |& cat
	#puts <<$cmd>>

	return $cmd
    }

    proc ::sak::test::run::Close {pipe} {
	close $pipe
	return
    }
}

# ###

proc ::sak::test::run::Process {pipe} {
    variable araw
    variable alog
    variable logext
    while {1} {
	if {[eof  $pipe]} break
	if {[gets $pipe line] < 0} break
	if {$alog || $araw} {puts $logext $line ; flush $logext}
	set rline $line
	set line [string trim $line]
	if {[string equal $line ""]} continue
	Host;	Platform
	Cwd;	Shell
	Tcl
	Start;	End ; StartFile ; EndFile
	Module;	Testsuite
	NoTestsuite
	Support;Testing;Other
	Summary
	CaptureFailureSync            ; # xcollect 1 => 2
	CaptureFailureCollectBody     ; # xcollect 2 => 3 => 5
	CaptureFailureCollectActual   ; # xcollect 3 => 4
	CaptureFailureCollectExpected ; # xcollect 4 => 0
	CaptureFailureCollectError    ; # xcollect 5 => 0
	CaptureStackStart
	CaptureStack

	TestStart
	TestSkipped
	TestPassed
	TestFailed                    ; # xcollect => 1

	SetupError
	Aborted
	AbortCause

	Match||Skip||Sourced
	# Unknown lines are printed
	if {!$araw} {puts !$line}
    }
    return $pipe
}

# ###

proc ::sak::test::run::Driver {} {
    variable base
    return [file join $base all.tcl]
}

# ###

proc ::sak::test::run::Host {} {
    upvar 1 line line ; variable xhost
    if {![regexp "^@@ Host (.*)$" $line -> xhost]} return
    # += $xhost
    set xhost [list Tests Results $xhost]
    #sak::registry::local set $xhost
    return -code continue
}

proc ::sak::test::run::Platform {} {
    upvar 1 line line ; variable xplatform
    if {![regexp "^@@ Platform (.*)$" $line -> xplatform]} return
    # += ($xplatform)
    variable xhost
    #sak::registry::local set $xhost Platform $xplatform
    return -code continue
}

proc ::sak::test::run::Cwd {} {
    upvar 1 line line ; variable xcwd
    if {![regexp "^@@ CWD (.*)$" $line -> xcwd]} return
    variable xhost
    set xcwd [linsert $xhost end $xcwd]
    #sak::registry::local set $xcwd
    return -code continue
}

proc ::sak::test::run::Shell {} {
    upvar 1 line line ; variable xshell
    if {![regexp "^@@ Shell (.*)$" $line -> xshell]} return
    # += [file tail $xshell]
    variable xcwd
    set xshell [linsert $xcwd end $xshell]
    #sak::registry::local set $xshell
    return -code continue
}

proc ::sak::test::run::Tcl {} {
    upvar 1 line line ; variable xtcl
    if {![regexp "^@@ Tcl (.*)$" $line -> xtcl]} return
    variable xshell
    variable maxvl
    += \[$xtcl\][blank [expr {$maxvl - [string length $xtcl]}]]
    #sak::registry::local set $xshell Tcl $xtcl
    return -code continue
}

proc ::sak::test::run::Match||Skip||Sourced {} {
    upvar 1 line line
    if {[string match "@@ Skip*"                  $line]} {return -code continue}
    if {[string match "@@ Match*"                 $line]} {return -code continue}
    if {[string match "Sourced * Test Files."     $line]} {return -code continue}
    if {[string match "Files with failing tests*" $line]} {return -code continue}
    if {[string match "Number of tests skipped*"  $line]} {return -code continue}
    if {[string match "\[0-9\]*"                  $line]} {return -code continue}
    return
}

proc ::sak::test::run::Start {} {
    upvar 1 line line
    if {![regexp "^@@ Start (.*)$" $line -> start]} return
    variable xshell
    #sak::registry::local set $xshell Start $start
    return -code continue
}

proc ::sak::test::run::End {} {
    upvar 1 line line
    if {![regexp "^@@ End (.*)$" $line -> end]} return
    variable xshell
    #sak::registry::local set $xshell End $end
    return -code continue
}

proc ::sak::test::run::StartFile {} {
    upvar 1 line line
    if {![regexp "^@@ StartFile (.*)$" $line -> start]} return
    variable xstartfile $start
    variable xtestnum 0
    #sak::registry::local set $xshell Start $start
    return -code continue
}

proc ::sak::test::run::EndFile {} {
    upvar 1 line line
    if {![regexp "^@@ EndFile (.*)$" $line -> end]} return
    variable xfile
    variable xstartfile
    variable xtimes
    variable xtestnum

    set k [lreplace $xfile 0 3]
    set k [lreplace $k 2 2 [file tail [lindex $k 2]]]
    set delta [expr {$end - $xstartfile}]

    if {$xtestnum == 0} {
	set score $delta
    } else {
	# average number of microseconds per test.
	set score [expr {int(($delta/double($xtestnum))*1000000)}]
	#set score [expr {$delta/double($xtestnum)}]
    }

    lappend xtimes $k [list $xtestnum $delta $score]

    variable alog
    if {$alog} {
	variable logtim
	puts $logtim [linsert [linsert $k end $xtestnum $delta $score] 0 TIME]
    }

    #sak::registry::local set $xshell End $end
    return -code continue
}

proc ::sak::test::run::Module {} {
    upvar 1 line line ; variable xmodule
    if {![regexp "^@@ Module (.*)$" $line -> xmodule]} return
    variable xshell
    variable xstatus ok
    variable maxml
    += ${xmodule}[blank [expr {$maxml - [string length $xmodule]}]]
    set xmodule [linsert $xshell end $xmodule]
    #sak::registry::local set $xmodule
    return -code continue
}

proc ::sak::test::run::Testsuite {} {
    upvar 1 line line ; variable xfile
    if {![regexp "^@@ Testsuite (.*)$" $line -> xfile]} return
    = <[file tail $xfile]>
    variable xmodule
    set xfile [linsert $xmodule end $xfile]
    #sak::registry::local set $xfile Aborted 0
    return -code continue
}

proc ::sak::test::run::NoTestsuite {} {
    upvar 1 line line
    if {![string match "Error:  No test files remain after*" $line]} return
    variable xstatus none
    = {No tests}
    return -code continue
}

proc ::sak::test::run::Support {} {
    upvar 1 line line
    if {![regexp "^- (.*)$" $line -> package]} return
    #= "S $package"
    foreach {pn pv} $package break
    variable xfile
    #sak::registry::local set [linsert $xfile end Support] $pn $pv
    return -code continue
}

proc ::sak::test::run::Testing {} {
    upvar 1 line line
    if {![regexp "^\\* (.*)$" $line -> package]} return
    #= "T $package"
    foreach {pn pv} $package break
    variable xfile
    #sak::registry::local set [linsert $xfile end Testing] $pn $pv
    return -code continue
}

proc ::sak::test::run::Other {} {
    upvar 1 line line
    if {![string match ">*" $line]} return
    return -code continue
}

proc ::sak::test::run::Summary {} {
    upvar 1 line line
    if {![regexp "^all\\.tcl:(.*)$" $line -> line]} return
    variable xmodule
    variable xstatus
    variable xvstatus
    foreach {_ t _ p _ s _ f} [split [string trim $line]] break
    #sak::registry::local set $xmodule Total   $t ; set t [format %5d $t]
    #sak::registry::local set $xmodule Passed  $p ; set p [format %5d $p]
    #sak::registry::local set $xmodule Skipped $s ; set s [format %5d $s]
    #sak::registry::local set $xmodule Failed  $f ; set f [format %5d $f]

    upvar 2 total _total ; incr _total $t
    upvar 2 pass  _pass  ; incr _pass  $p
    upvar 2 skip  _skip  ; incr _skip  $s
    upvar 2 fail  _fail  ; incr _fail  $f
    upvar 2 err   _err

    set t [format %5d $t]
    set p [format %5d $p]
    set s [format %5d $s]
    set f [format %5d $f]

    if {$xstatus == "ok" && $t == 0} {
	set xstatus none
    }

    set st $xvstatus($xstatus)

    if {$xstatus == "ok"} {
	# Quick return for ok suite.
	=| "~~ $st T $t P $p S $s F $f"
	return -code continue
    }

    # Clean out progress display using a non-highlighted
    # string. Prevents the char couint from being off. This is
    # followed by construction and display of the highlighted version.

    = "   $st T $t P $p S $s F $f"
    switch -exact -- $xstatus {
	none    {=| "~~ [yel]$st T $t[rst] P $p S $s F $f"}
	aborted {=| "~~ [whi]$st[rst] T $t P $p S $s F $f"}
	error   {
	    =| "~~ [mag]$st[rst] T $t P $p S $s F $f"
	    incr _err
	}
	fail    {=| "~~ [red]$st[rst] T $t P $p S $s [red]F $f[rst]"}
    }
    return -code continue
}

proc ::sak::test::run::TestStart {} {
    upvar 1 line line
    if {![string match {---- * start} $line]} return
    set testname [string range $line 5 end-6]
    = "---- $testname"
    variable xfile
    variable xtest [linsert $xfile end $testname]
    variable xtestnum
    incr     xtestnum
    return -code continue
}

proc ::sak::test::run::TestSkipped {} {
    upvar 1 line line
    if {![string match {++++ * SKIPPED:*} $line]} return
    regexp {^[^ ]* (.*)SKIPPED:.*$} $line -> testname
    set              testname [string trim $testname]
    variable xtest
    = "SKIP $testname"
    if {$xtest == {}} {
	variable xfile
	set xtest [linsert $xfile end $testname]
    }
    #sak::registry::local set $xtest Status Skip
    set xtest {}
    return -code continue
}

proc ::sak::test::run::TestPassed {} {
    upvar 1 line line
    if {![string match {++++ * PASSED} $line]} return
    set             testname [string range $line 5 end-7]
    variable xtest
    = "PASS $testname"
    if {$xtest == {}} {
	variable xfile
	set xtest [linsert $xfile end $testname]
    }
    #sak::registry::local set $xtest Status Pass
    set xtest {}
    return -code continue
}

proc ::sak::test::run::TestFailed {} {
    upvar 1 line line
    if {![string match {==== * FAILED} $line]} return
    set        testname [lindex [split [string range $line 5 end-7]] 0]
    = "FAIL $testname"
    variable xtest
    if {$xtest == {}} {
	variable xfile
	set xtest [linsert $xfile end $testname]
    }
    #sak::registry::local set $xtest Status Fail
    ## CAPTURE INIT
    variable xcollect  1
    variable xbody     ""
    variable xactual   ""
    variable xexpected ""
    variable xstatus   fail
    # Ignore failed status if we already have it, or an error
    # status. The latter is more important to show. We do override
    # status 'aborted'.
    if {$xstatus == "ok"}      {set xstatus fail}
    if {$xstatus == "aborted"} {set xstatus fail}
    return -code continue
}

proc ::sak::test::run::CaptureFailureSync {} {
    variable xcollect
    if {$xcollect != 1} return
    upvar 1 line line
    if {![string match {==== Contents*} $line]} return
    set xcollect 2
    return -code continue
}

proc ::sak::test::run::CaptureFailureCollectBody {} {
    variable xcollect
    if {$xcollect != 2} return
    upvar 1 rline line
    variable xbody
    if {[string match {---- Result was*} $line]} {
	set xcollect 3
	return -code continue
    } elseif {[string match {---- Test generated error*} $line]} {
	set xcollect 5
	return -code continue
    }

    variable xbody
    append   xbody $line \n
    return -code continue
}

proc ::sak::test::run::CaptureFailureCollectActual {} {
    variable xcollect
    if {$xcollect != 3} return
    upvar 1 rline line
    if {![string match {---- Result should*} $line]} {
	variable xactual
	append   xactual $line \n
    } else {
	set xcollect 4
    }
    return -code continue
}

proc ::sak::test::run::CaptureFailureCollectExpected {} {
    variable xcollect
    if {$xcollect != 4} return
    upvar 1 rline line
    if {![string match {==== *} $line]} {
	variable xexpected
	append   xexpected $line \n
    } else {
	variable alog
	if {$alog} {
	    variable logfad
	    variable xtest
	    variable xbody
	    variable xactual
	    variable xexpected

	    puts  $logfad "==== [lrange $xtest end-1 end] FAILED ========="
	    puts  $logfad "==== Contents of test case:\n"
	    puts  $logfad $xbody

	    puts  $logfad "---- Result was:"
	    puts  $logfad [string range $xactual 0 end-1]

	    puts  $logfad "---- Result should have been:"
	    puts  $logfad [string range $xexpected 0 end-1]

	    puts  $logfad "==== [lrange $xtest end-1 end] ====\n\n"
	    flush $logfad
	}
	set xcollect 0
	#sak::registry::local set $xtest Body     $xbody
	#sak::registry::local set $xtest Actual   $xactual
	#sak::registry::local set $xtest Expected $xexpected
	set xtest {}
    }
    return -code continue
}

proc ::sak::test::run::CaptureFailureCollectError {} {
    variable xcollect
    if {$xcollect != 5} return
    upvar 1 rline line
    variable xbody
    if {[string match {---- errorCode*} $line]} {
	set xcollect 4
	return -code continue
    }

    variable xactual
    append   xactual $line \n
    return -code continue
}

proc ::sak::test::run::Aborted {} {
    upvar 1 line line
    if {![string match {Aborting the tests found *} $line]} return
    variable xfile
    variable xstatus
    # Ignore aborted status if we already have it, or some other error
    # status (like error, or fail). These are more important to show.
    if {$xstatus == "ok"} {set xstatus aborted}
    = Aborted
    #sak::registry::local set $xfile Aborted {}
    return -code continue
}

proc ::sak::test::run::AbortCause {} {
    upvar 1 line line
    if {
	![string match {Requiring *} $line] &&
	![string match {Error in *} $line]
    } return ; # {}
    variable xfile
    = $line
    #sak::registry::local set $xfile Aborted $line
    return -code continue
}

proc ::sak::test::run::CaptureStackStart {} {
    upvar 1 line line
    if {![string match {@+*} $line]} return
    variable xstackcollect 1
    variable xstack        {}
    variable xstatus       error
    = {Error, capturing stacktrace}
    return -code continue
}

proc ::sak::test::run::CaptureStack {} {
    variable xstackcollect
    if {!$xstackcollect} return
    upvar 1 line line
    variable xstack
    if {![string match {@-*} $line]} {
	append xstack [string range $line 2 end] \n
    } else {
	set xstackcollect 0
	variable xfile
	variable alog
	#sak::registry::local set $xfile Stacktrace $xstack
	if {$alog} {
	    variable logerd
	    puts  $logerd "[lindex $xfile end] StackTrace"
	    puts  $logerd "========================================"
	    puts  $logerd $xstack
	    puts  $logerd "========================================\n\n"
	    flush $logerd
	}
    }
    return -code continue
}

proc ::sak::test::run::SetupError {} {
    upvar 1 line line
    if {![string match {SETUP Error*} $line]} return
    variable xstatus error
    = {Setup error}
    return -code continue
}

# ###

proc ::sak::test::run::+= {string} {
    variable araw
    if {$araw} return
    variable aprefix
    append   aprefix " " $string
    sak::animate::next $aprefix
    return
}

proc ::sak::test::run::= {string} {
    variable araw
    if {$araw} return
    variable aprefix
    sak::animate::next "$aprefix $string"
    return
}

proc ::sak::test::run::=| {string} {
    variable araw
    if {$araw} return
    variable aprefix
    sak::animate::last "$aprefix $string"
    variable alog
    if {$alog} {
	variable logsum
	variable logfai
	variable logski
	variable lognon
	variable xstatus
	puts $logsum "$aprefix $string" ; flush $logsum
	switch -exact -- $xstatus {
	    error   -
	    fail    {puts $logfai "$aprefix $string" ; flush $logfai}
	    none    {puts $lognon "$aprefix $string" ; flush $lognon}
	    aborted {puts $logski "$aprefix $string" ; flush $logski}
	}
    }
    set aprefix ""
    return
}

# ###

namespace eval ::sak::test::run {
    variable base     [file join $::distribution support devel]
    variable valgrind [auto_execok valgrind]

    # State of test processing.

    variable xstackcollect 0
    variable xstack    {}
    variable xcollect  0
    variable xbody     {}
    variable xactual   {}
    variable xexpected {}
    variable xhost     {}
    variable xplatform {}
    variable xcwd      {}
    variable xshell    {}
    variable xmodule   {}
    variable xfile     {}
    variable xtest     {}
    variable xstartfile {}
    variable xtimes     {}

    variable xstatus ok

    # Animation prefix of test processing, and flag controlling the
    # nature of logging (raw vs animation).

    variable aprefix   {}
    variable araw      0

    # Max length of module names and patchlevel information.

    variable maxml 0
    variable maxvl 0

    # Map from internal stati to the displayed human readable
    # strings. This includes the trailing whitespace needed for
    # vertical alignment.

    variable  xvstatus
    array set xvstatus {
	ok      {     }
	none    {None }
	aborted {Skip }
	error   {ERR  }
	fail    {FAILS}
    }
}

##
# ###

package provide sak::test::run 1.0

if 0 {
    # Bad valgrind, ok no valgrind
    if {$config(valgrind)} {
	foreach e $valgrind {lappend cmd $e}
	lappend cmd --num-callers=8
	lappend cmd --leak-resolution=high
	lappend cmd -v --leak-check=yes
	lappend cmd --show-reachable=yes
    }
    lappend cmd $sh
    lappend cmd [Driver] -modules $modules
}
