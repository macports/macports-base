# all.tcl --
#
# This file contains a top-level script to run all of the Tcl
# tests.  Execute it by invoking "source all.test" when running tcltest
# in this directory.
#
# RCS: @(#) $Id: all.tcl,v 1.2 2002/04/02 02:29:43 hobbs Exp $

if {[lsearch [namespace children] ::tcltest] == -1} {
    package require tcltest
    namespace import ::tcltest::*
}

set ::tcltest::testSingleFile false
set ::tcltest::testsDirectory [file dir [info script]]

# We need to ensure that the testsDirectory is absolute
::tcltest::normalizePath ::tcltest::testsDirectory

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

package require Tclx 8.4

# source each of the specified tests
foreach file [lsort [::tcltest::getMatchingFiles]] {
    set tail [file tail $file]
    puts stdout $tail
    if {[catch {source $file} msg]} {
	puts stdout $msg
    }
}

# cleanup
puts stdout "\nTests ended at [eval $timeCmd]"
::tcltest::cleanupTests 1
return

if 0 {
    proc eq {a b} { cequal $a $b }
    proc eq1 {a b} { string equal $a $b }
    proc eq2 {a b} { foo $a $b}
    interp alias {} foo {} string equal
    set a [string repeat a 50]b
    set b [string repeat a 50]b
    set c [string repeat a 50]c
    eq $a $b
    eq1 $a $b
    eq2 $a $b
}
