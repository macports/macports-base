#!/usr/bin/env tclsh
## -*- tcl -*-
# MAIN PROGRAM
#
# Usage:
#       diff2.tcl file1 file2
#
# Output:
#       Puts out a list of lines describing the changes from file1 to file2
#	in a format similar to 'patch'. It not the same as patch, but could
#	be modified to be exactly the same.

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

set chunks 0
foreach chunk [::struct::list lcsInvert2 $x1 $x2 [llength $lines1] [llength $lines2]] {
    set chunks 1
    puts ===========================================
    puts $chunk
    puts -------------------------------------------

    ::struct::list assign [lindex $chunk 1] b1 e1
    ::struct::list assign [lindex $chunk 2] b2 e2

    switch -exact -- [lindex $chunk 0] {
	changed {
	    puts "< [join [lrange $lines1 $b1 $e1] "\n< "]"
	    puts "---"
	    puts "> [join [lrange $lines2 $b2 $e2] "\n> "]"
	}
	added   {
	    puts "> [join [lrange $lines2 $b2 $e2] "\n> "]"
	}
	deleted {
	    puts "< [join [lrange $lines1 $b1 $e1] "\n< "]"
	}
    }
}
if {$chunks} {
    puts ===========================================
}

exit
