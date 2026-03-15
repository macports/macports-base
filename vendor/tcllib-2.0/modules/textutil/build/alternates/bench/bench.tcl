# -*- tcl -*-
# Benchmarking. CSV for charting. Entire range of uni(code)points.
#
# Package "wcswidth".
#
# (c) 2022 Andreas Kupries <andreas.kupries@gmail.com>

if {![package vsatisfies [package provide Tcl] 8.5 9]} {
    return
}

# ### ### ### ######### ######### ######### ###########################
## Setting up the environment ...

set code [file join [file dirname [info script]] wcswidth.tcl]
if {[llength $::argv]} { lassign $::argv code }

package forget textutil::wcswidth
catch {namespace delete ::textutil::wcswidth}
source $code

set max 1114111
#set iter 100000
#set iter 1000

# ### ### ### ######### ######### ######### ###########################

puts [join {Code Type Char} ,]

# Bytecompile procs, keep out of timing
time {::textutil::wcswidth_type 0} 1
time {::textutil::wcswidth_char 0} 1
    
for {set code 0} {$code <= $max} {incr code} {
    # Smooth result by using best (smallest time) of 10 runs. Reduced iter to keep overall iter at 1000
    lassign {Inf Inf} ustm uscm
    foreach _ {0 1 2 3 4 5 6 7 8 9} {
	set ust  [lindex [time {::textutil::wcswidth_type $code} 100] 0]
	set usc  [lindex [time {::textutil::wcswidth_char $code} 100] 0]
	set ustm [expr { min ($ustm, $ust) }]
	set uscm [expr { min ($uscm, $usc) }]
    }
    
    puts [join [list $code $ustm $uscm] ,]
}

# ### ### ### ######### ######### ######### ###########################
return
