# treeql.tcl
# A generic tree query language in snit
#
# Copyright 2004 Colin McCormack.
# You are permitted to use this code under the same license as tcl.
#
# 20040930 Colin McCormack - initial release to tcllib
#
# RCS: @(#) $Id: treeql.tcl,v 1.10 2006/09/19 23:36:18 andreas_kupries Exp $

package require Tcl 8.4

# Select the implementation based on the version of the Tcl core
# executing this code. For 8.5 we are using features like
# word-expansion to simplify the various evaluations.

set dir [file dirname [info script]]
if {[package vsatisfies [package provide Tcl] 8.5]} {
    source [file join $dir treeql85.tcl]
} else {
    source [file join $dir treeql84.tcl]
}

package provide treeql 1.3.1
