# all.tcl --
#
# This file contains a top-level script to run all of the Tcl
# tests.  Execute it by invoking "source all.test" when running tcltest
# in this directory.
#
# RCS: @(#) $Id: all.tcl,v 1.2 2002/03/29 05:06:52 hobbs Exp $

package require Tclx

if {[lsearch [namespace children] ::tcltest] == -1} {
    package require tcltest
    namespace import ::tcltest::*
}

set ::tcltest::testSingleFile false
set ::tcltest::testsDirectory [file dir [info script]]

# We need to ensure that the testsDirectory is absolute
::tcltest::normalizePath ::tcltest::testsDirectory
::tcltest::configure -testdir [file dirname [file normalize [info script]]]
::tcltest::configure {*}$argv

# Skip these tests on a per-build basis
if {[info exists env(SKIPFILES)]} {
	lappend ::tcltest::skipFiles {*}$env(SKIPFILES)
}

puts stdout "Tests running in interp:       [info nameofexecutable]"
puts stdout "Tests running with pwd:        [pwd]"
puts stdout "Tests running in working dir:  $::tcltest::testsDirectory"
if {[llength $::tcltest::skip] > 0} {
    puts stdout "Skipping tests that match:            $::tcltest::skip"
}
if {[llength $::tcltest::match] > 0} {
    puts stdout "Only running tests that match:        $::tcltest::match"
}

if {[llength $::tcltest::skipFiles] > 0} {
    puts stdout "Skipping test files that match:       $::tcltest::skipFiles"
}
if {[llength $::tcltest::matchFiles] > 0} {
    puts stdout "Only sourcing test files that match:  $::tcltest::matchFiles"
}

set timeCmd {clock format [clock seconds]}
puts stdout "Tests began at [eval $timeCmd]"

package require Tclx 8.6


# Hook to determine if any of the tests failed. Then we can exit with
# proper exit code: 0=all passed, 1=one or more failed
proc tcltest::cleanupTestsHook {} {
	variable numTests
	set ::exitCode [expr {$numTests(Failed) > 0}]
}


# source each of the specified tests
foreach file [lsort [::tcltest::getMatchingFiles]] {
	set tail [file tail $file]
	puts stdout $tail
	if {[catch {source $file} msg]} {
		puts stdout $msg
	}
}
# TODO: convert above to use ::tcltest::runAllTests?s

# cleanup
puts stdout "\nTests ended at [eval $timeCmd]"
::tcltest::cleanupTests 1

if {$exitCode == 1} {
	puts "====== FAIL ====="
	exit $exitCode
} else {
	puts "====== SUCCESS ====="
}
