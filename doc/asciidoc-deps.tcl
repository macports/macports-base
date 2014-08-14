#!/usr/bin/env tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4

if {[llength $::argv] == 0} {
    puts "Usage: ${::argv0} <*.txt>"
    exit 1
}

# Dependency storage
array set deps {}

# Gather includes
foreach file $::argv {
    if {![file exists $file]} {
        continue
    }
    set fd [open "$file" r]
    set cont [read $fd]
    close $fd
    set deplst [regexp -all -inline -- {include::([^\[]*)\[\]} $cont]
    if {[llength $deplst] > 0} {
        set deps($file) $deplst
    }
}

# Output
foreach {file deplst} [array get deps] {
    puts -nonewline "[file rootname $file].xml [file rootname $file].html:"
    foreach {match dep} $deplst {
        puts -nonewline " $dep"
    }
    puts ""
}

exit 0
