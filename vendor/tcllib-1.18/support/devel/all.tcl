# all.tcl --
#
# This file contains a top-level script to run all of the Tcl
# tests.  Execute it by invoking "tclsh all.test" in this directory.
#
# To test a subset of the modules, invoke it by 'tclsh all.test -modules "<module list>"'
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
# All rights reserved.
# 
# RCS: @(#) $Id: all.tcl,v 1.7 2009/12/08 21:00:51 andreas_kupries Exp $

catch {wm withdraw .}

set old_auto_path $auto_path

if {[lsearch [namespace children] ::tcltest] == -1} {
    namespace eval ::tcltest {}
    proc ::tcltest::processCmdLineArgsAddFlagsHook {} {
	return [list -modules]
    }
    proc ::tcltest::processCmdLineArgsHook {argv} {
	array set foo $argv
	catch {set ::modules $foo(-modules)}
    }
    proc ::tcltest::cleanupTestsHook {{c {}}} {
	if { [string equal $c ""] } {
	    # Ignore calls in the master.
	    return
	}

	# When called from a slave copy the information found in the
	# slave to here and update our own data.

	# Get total/pass/skip/fail counts
	array set foo [$c eval {array get ::tcltest::numTests}]
	foreach index {Total Passed Skipped Failed} {
	    incr ::tcltest::numTests($index) $foo($index)
	}
	incr ::tcltest::numTestFiles

	# Append the list of failFiles if necessary
	set f [$c eval {
	    set ff $::tcltest::failFiles
	    if {($::tcltest::currentFailure) && \
		    ([lsearch -exact $ff $testFileName] == -1)} {
		set res [file join $::tcllibModule $testFileName]
	    } else {
		set res ""
	    }
	    set res
	}] ; # {}
	if { ![string equal $f ""] } {
	    lappend ::tcltest::failFiles $f
	}

	# Get the "skipped because" information
	unset foo
	array set foo [$c eval {array get ::tcltest::skippedBecause}]
	foreach constraint [array names foo] {
	    if { ![info exists ::tcltest::skippedBecause($constraint)] } {
		set ::tcltest::skippedBecause($constraint) $foo($constraint)
	    } else {
		incr ::tcltest::skippedBecause($constraint) $foo($constraint)
	    }
	}

	# Clean out the state in the slave
	$c eval {
	    foreach index {Total Passed Skipped Failed} {
		set ::tcltest::numTests($index) 0
	    }
	    set ::tcltest::failFiles {}
	    foreach constraint [array names ::tcltest::skippedBecause] {
		unset ::tcltest::skippedBecause($constraint)
	    }
	}
    }

    package require tcltest
    namespace import ::tcltest::*
}

set ::tcltest::testSingleFile false
set ::tcltest::testsDirectory [file dirname \
	[file dirname [file dirname [info script]]]]

# We need to ensure that the testsDirectory is absolute
if {[catch {::tcltest::normalizePath ::tcltest::testsDirectory}]} {
    # The version of tcltest we have here does not support
    # 'normalizePath', so we have to do this on our own.

    set oldpwd [pwd]
    catch {cd $::tcltest::testsDirectory}
    set ::tcltest::testsDirectory [pwd]
    cd $oldpwd
}
set root $::tcltest::testsDirectory

proc Note {k v} {
    puts  stdout [list @@ $k $v]
    flush stdout
    return
}
proc Now {} {return [clock seconds]}

puts stdout ""
Note Host       [info hostname]
Note Platform   $tcl_platform(os)-$tcl_platform(osVersion)-$tcl_platform(machine)
Note CWD        $::tcltest::testsDirectory
Note Shell      [info nameofexecutable]
Note Tcl        [info patchlevel]

# Host  => Platform | Identity of the Test environment.
# Shell => Tcl      |
# CWD               | Identity of the Tcllib under test.

if {[llength $::tcltest::skip]}       {Note SkipTests  $::tcltest::skip}
if {[llength $::tcltest::match]}      {Note MatchTests $::tcltest::match}
if {[llength $::tcltest::skipFiles]}  {Note SkipFiles  $::tcltest::skipFiles}
if {[llength $::tcltest::matchFiles]} {Note MatchFiles $::tcltest::matchFiles}

set auto_path $old_auto_path
set auto_path [linsert $auto_path 0 [file join $root modules]]
set old_apath $auto_path

##
## Take default action if the modules are not specified
##

if {![info exists modules]} then {
    foreach module [glob [file join $root modules]/*/*.test] {
	set tmp([lindex [file split $module] end-1]) 1
    }
    set modules [lsort -dict [array names tmp]]
    unset tmp
}

Note Start [Now]

foreach module $modules {
    set ::tcltest::testsDirectory [file join $root modules $module]

    if { ![file isdirectory $::tcltest::testsDirectory] } {
	puts stdout "unknown module $module"
    }

    set auto_path $old_apath
    set auto_path [linsert $auto_path 0 $::tcltest::testsDirectory]

    # For each module, make a slave interp and source that module's
    # tests into the slave. This isolates the test suites from one
    # another.

    Note Module [file tail $module]

    set c [interp create]
    interp alias $c pSet {} set
    interp alias $c Note {} Note

    $c eval {
	# import the auto_path from the parent interp,
	# so "package require" works

	set ::auto_path    [pSet ::auto_path]
	set ::argv0        [pSet ::argv0]
	set ::tcllibModule [pSet module]

	# The next command allows the execution of 'tk' constrained
	# tests, if Tk is present (for example when this code is run
	# run by 'wish').

	# Under wish 8.2/8.3 we have to explicitly load Tk into the
	# slave, the package management is not able to.

	if {![package vsatisfies [package provide Tcl] 8.4]} {
	    catch {
		load {} Tk
		wm withdraw .
	    }
	} else {
	    catch {
		package require Tk
		wm withdraw .
	    }
	}

	package require tcltest

	# Re-import, the loading of an older tcltest package reset it
	# to the standard set of paths.
	set ::auto_path [pSet ::auto_path]

	namespace import ::tcltest::*
	set ::tcltest::testSingleFile false
	set ::tcltest::testsDirectory [pSet ::tcltest::testsDirectory]

	# configure not present in tcltest 1.x
	if {[catch {::tcltest::configure -verbose bstep}]} {
	    set ::tcltest::verbose psb
	}
    }

    interp alias \
	    $c ::tcltest::cleanupTestsHook \
	    {} ::tcltest::cleanupTestsHook $c

    # source each of the specified tests
    foreach file [lsort [::tcltest::getMatchingFiles]] {
	set tail [file tail $file]
	Note Testsuite [string map [list "$root/" ""] $file]
	Note StartFile [Now]
	$c eval {
	    if {[catch {source [pSet file]} msg]} {
		puts stdout "@+"
		puts stdout @|[join [split $errorInfo \n] "\n@|"]
		puts stdout "@-"
	    }
	}
	Note EndFile [Now]
    }
    interp delete $c
    puts stdout ""
}

# cleanup
Note End [Now]
::tcltest::cleanupTests 1
# FRINK: nocheck
# Use of 'exit' ensures proper termination of the test system when
# driven by a 'wish' instead of a 'tclsh'. Otherwise 'wish' would
# enter its regular event loop and no tests would complete.
exit

