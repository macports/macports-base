#!/usr/bin/env tclsh
if {$argc != 1} {
	puts "Usage: $argv0 <directory>"
	exit
}
pkg_mkIndex [lindex $argv 0] *.tcl
