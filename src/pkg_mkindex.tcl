#!/usr/bin/env tclsh
if {$argc < 1} {
	puts "Usage: $argv0 <directory list>"
	exit
}
foreach dir $argv {
	pkg_mkIndex $dir *.tcl *.dylib
}
