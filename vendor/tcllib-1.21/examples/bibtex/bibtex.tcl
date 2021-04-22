#!/usr/bin/env tclsh
## -*- tcl -*-
#####
#
# "BibTeX parser" -- Example Application.
# http://wiki.tcl.tk/13719
#
# Tcl code harvested on:   7 Mar 2005, 23:55 GMT
# Wiki page last updated: ???
#
#####


# bibtex.tcl --
#
#      A basic parser for BibTeX bibliography databases.
#
# Copyright (c) 2005 Neil Madden.
# License: Tcl/BSD style.

package require Tcl 8.4
package require bibtex

proc readfile file {
   set fd [open $file]
   set cn [read $fd]
   close $fd
   return $cn
}

proc progress {token percent} {
    set str [format "Processing: \[%3d%%\]" $percent]
    puts -nonewline "\r$str"
    flush stdout
    return
}

proc count {token type key data} {
    #puts "== $token $type $key"

    global count total
    if {[info exists count($type)]} {
	 incr count($type)
    } else {
	 set count($type) 1
    }
    incr total
    return
}

# ### ### ### ######### ######### #########

puts -nonewline "Processing: \[  0%\]"; flush stdout

array set count { }
set total 0

bibtex::parse \
	-recordcommand   count    \
	-progresscommand progress \
	[readfile [lindex $argv 0]]

puts ""
puts "Summary ======"
puts "Total: $total"
parray count

# ### ### ### ######### ######### #########
# EOF
exit
