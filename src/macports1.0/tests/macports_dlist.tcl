#!/usr/bin/env tclsh
# macports1.0/test_dlist.tcl
# $Id$
#
# Copyright (c) 2007 The MacPorts Project
# Copyright (c) 2003 Kevin Van Vechten <kevin@opendarwin.org>

# Test suite for macports_dlist package.

#lappend auto_path .
#package require macports_dlist 1.0
source macports_dlist.tcl

puts ""
puts "Testing ditem"

puts -nonewline "Checking ditem_create... "
if {[catch {ditem_create} ditem] || $ditem == ""} {
	puts "failed: $ditem"
} else {
	puts "ok"
}

puts -nonewline "Checking ditem_key... "
if {[catch {ditem_key $ditem provides "foo"} value] || $value != "foo"} {
	puts "failed: $value"
} else {
	puts "ok"
}

puts -nonewline "Checking ditem_append... "
if {[catch {ditem_append $ditem provides "bar"} value] || $value != {foo bar}} {
	puts "failed: $value"
} else {
	puts "ok"
}

puts -nonewline "Checking ditem_contains... "
set value2 ""
if {[catch {ditem_contains $ditem provides "foo"} value] || $value != 1 ||
	[catch {ditem_contains $ditem provides "zzz"} value2] || $value2 != 0} {
	puts "failed: ${value}\n${value2}"
} else {
	puts "ok"
}

puts ""
puts "Testing dlist"

puts -nonewline "Checking dlist_search... "
if {[catch {dlist_search [list $ditem] provides "bar"} value] || $value != $ditem} {
	puts "failed: $value"
} else {
	puts "ok"
}

puts -nonewline "Checking dlist_has_pending... "
if {[catch {dlist_has_pending [list $ditem] "foo"} value] || $value != 1} {
	puts "failed: $value"
} else {
	puts "ok"
}

puts -nonewline "Checking dlist_count_unmet... "
array set status [list foo 1 bar 0]
if {[catch {dlist_count_unmet [list] status "foo"} value] || $value != 0 ||
	[catch {dlist_count_unmet [list] status "bar"} value2] || $value2 != 1} {
	puts "failed: ${value}\n${value2}"
} else {
	puts "ok"
}

# Replicate Shantonu's Bug #354 to test dlist functionality.
# https://trac.macports.org/ticket/354
# A depends on B, C.
# B depends on C.
# C has no dependencies.

set A [ditem_create]
ditem_key $A provides A
ditem_append $A requires B
ditem_append $A requires C

set B [ditem_create]
ditem_key $B provides B
ditem_append $B requires C

set C [ditem_create]
ditem_key $C provides C

array set status [list]
puts -nonewline "Checking dlist_get_next... "
if {[catch {dlist_get_next [list $A $B $C] status} value] || $value != $C} {
	puts "failed: ${value}"
} else {
	puts "ok"
}

puts -nonewline "Checking dlist_eval... "
proc handler {ditem} { puts -nonewline "[ditem_key $ditem provides] " }
if {[catch {dlist_eval [list $A $B $C] {} handler} value] || $value != {}} {
	puts "failed: ${value}"
} else {
	puts "ok"
}

puts -nonewline "Checking dlist_append_dependents... "
if {[catch {dlist_append_dependents [list $A $B $C] $B {}} value] || $value != [list $B $C]} {
	puts "failed: ${value}"
} else {
	puts "ok"
}


