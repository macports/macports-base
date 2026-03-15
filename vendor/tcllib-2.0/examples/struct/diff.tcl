#!/usr/bin/env tclsh
## -*- tcl -*-
# MAIN PROGRAM
#
# Usage:
#       diff.tcl file1 file2
#
# Output:
#       Puts out a list of lines consisting of:
#               n1<TAB>n2<TAB>line
#
#       where n1 is a line number in the first file, and n2 is a line number in the second file.
#       The line is the text of the line.  If a line appears in the first file but not the second,
#       n2 is omitted, and conversely, if it appears in the second file but not the first, n1
#       is omitted.

package require struct

# Open the files and read the lines into memory

set                      f1 [open [lindex $argv 0] r]
set lines1 [split [read $f1] \n]
close                   $f1

set                      f2 [open [lindex $argv 1] r]
set lines2 [split [read $f2] \n]
close                   $f2

set i 0
set j 0

::struct::list assign [::struct::list longestCommonSubsequence $lines1 $lines2] x1 x2

foreach p $x1 q $x2 {
    while { $i < $p } {
	set l [lindex $lines1 $i]
	puts "[incr i]\t\t$l"
    }
    while { $j < $q } {
	set m [lindex $lines2 $j]
	puts "\t[incr j]\t$m"
    }
    set l [lindex $lines1 $i]
    puts "[incr i]\t[incr j]\t$l"
}
while { $i < [llength $lines1] } {
    set l [lindex $lines1 $i]
    puts "[incr i]\t\t$l"
}
while { $j < [llength $lines2] } {
    set m [lindex $lines2 $j]
    puts "\t[incr j]\t$m"
}

exit
