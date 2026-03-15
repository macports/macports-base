# -*- tcl -*-
# Implementation of 'doc'.

# Available variables
# * argv  - Cmdline arguments
# * base  - Location of sak.tcl = Top directory of Tcllib distribution
# * cbase - Location of all files relevant to this command.
# * sbase - Location of all files supporting the SAK.

if {![llength $argv]} {
    set format * 
} else {
    set format [lindex $argv 0]*
    set argv   [lrange $argv 1 end]
}

package require sak::util
if {![sak::util::checkModules argv]} return

set matches 0
foreach f {
    html nroff tmml text wiki latex dvi ps pdf list validate imake ishow index
} {
    if {![string match $format $f]} continue
    incr matches
}
if {!$matches} {
    puts "  No format matching \"$format\""
    return
}

# ###

package require sak::doc

foreach f {
    html nroff tmml text wiki latex dvi ps pdf list validate imake ishow index
} {
    if {![string match $format $f]} continue
    sak::doc::$f $argv
}

##
# ###
