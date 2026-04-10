#!/usr/bin/tclsh

# ------------------------------------------------------------------------
#
# file.perf.tcl --
#
#  This file provides performance tests for comparison of tcl-speed
#  of file commands and subsystem.
#
# ------------------------------------------------------------------------
#
# Copyright (c) 2024 Serg G. Brester (aka sebres)
#
# See the file "license.terms" for information on usage and redistribution
# of this file.
#


if {![namespace exists ::tclTestPerf]} {
  source -encoding utf-8 [file join [file dirname [info script]] test-performance.tcl]
}


namespace eval ::tclTestPerf-File {

namespace path {::tclTestPerf}

proc _get_new_file_path_obj [list [list p [info script]]] {
  # always generate new string object here (ensure it is not a "cached" object of type path):
  string trimright "$p "; # costs of object "creation" smaller than 1 microsecond
}

# regression tests for bug-02d5d65d70adab97 (fix for [02d5d65d70adab97]):
proc test-file-access-regress {{reptime 1000}} {
  _test_run -no-result $reptime {
    setup   { set fn [::tclTestPerf-File::_get_new_file_path_obj] }
    # file exists on "cached" file path:
    { file exists $fn }
    # file exists on not "cached" (fresh generated) file path:
    { set fn [::tclTestPerf-File::_get_new_file_path_obj]; file exists $fn }

    setup   { set fn [::tclTestPerf-File::_get_new_file_path_obj] }
    # file attributes on "cached" file path:
    { file attributes $fn -readonly }
    # file attributes on not "cached" (fresh generated) file path:
    { set fn [::tclTestPerf-File::_get_new_file_path_obj]; file attributes $fn -readonly }

    setup   { set fn [::tclTestPerf-File::_get_new_file_path_obj] }
    # file stat on "cached" file path:
    { file stat $fn st }
    # file stat on not "cached" (fresh generated) file path:
    { set fn [::tclTestPerf-File::_get_new_file_path_obj]; file stat $fn st }

    setup   { set fn [::tclTestPerf-File::_get_new_file_path_obj] }
    # touch on "cached" file path:
    { close [open $fn rb] }
    # touch on not "cached" (fresh generated) file path:
    { set fn [::tclTestPerf-File::_get_new_file_path_obj]; close [open $fn rb] }
  }
}

proc test {{reptime 1000}} {
  test-file-access-regress $reptime

  puts \n**OK**
}

}; # end of ::tclTestPerf-File

# ------------------------------------------------------------------------

# if calling direct:
if {[info exists ::argv0] && [file tail $::argv0] eq [file tail [info script]]} {
  array set in {-time 500}
  array set in $argv
  ::tclTestPerf-File::test $in(-time)
}
